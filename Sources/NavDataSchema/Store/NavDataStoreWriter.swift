public import SwiftData

import Foundation

/**
 Writes a decoded navigation dataset into a SwiftData store.

 This is the only implementation of the shape a nav data store takes, and both things that
 produce one use it: the app, importing a downloaded JSON document, and the macOS tool that
 publishes a store built ahead of time. Two implementations would drift, and the difference
 between them would only show up in a cockpit.

 The store it writes is expected to be empty. A dataset is replaced by writing a new generation
 beside the one in use, never by clearing rows out of it.

 ## Executor Constraints

 A `@ModelActor`'s serial executor is its `NSManagedObjectContext`'s dispatch queue, and SwiftData
 enqueues jobs onto that executor with `-[NSManagedObjectContext performBlockAndWait:]`.
 Enqueueing therefore blocks the *calling* thread until the executor is free, so every caller —
 the main actor included — stalls for as long as this actor stays busy. Persistence work is
 split into bounded batches separated by `await` so it never occupies the executor without
 suspending, and progress leaves through a stream rather than through state a caller would have
 to await.
 */
@ModelActor
public actor NavDataStoreWriter {
  /**
   Maximum number of rows written per save.

   Each save holds the store's write lock for its full commit, so the import is split into
   bounded transactions rather than one that spans the whole dataset. The bound is generous
   because the writer works through its own persistent store coordinator against a WAL-journaled
   store, where readers are never blocked by a write in flight; the only cost a long transaction
   imposes is on this actor's own executor, which a smaller bound would trade for many more
   commits.
   */
  private static let saveBatchRowLimit = 10000

  /**
   Writes an entire dataset, reporting how far through it has got.

   Progress is pushed into a stream rather than handed to a callback, because a callback would
   have to cross back into the caller's isolation on an actor whose executor this work occupies.

   - Parameters:
     - document: The decoded dataset to write.
     - release: The release the dataset was published in, recorded as the store's cycle.
     - continuation: Yielded a fraction from 0 to 1 as airports are written, and finished when
       the dataset is fully written.
   - Returns: How many airports were written. An airport missing the elevation or coordinates
     every correction needs is skipped.
   */
  @discardableResult
  public func write(
    _ document: NavDataDocument,
    release: NavDataReleaseManifest,
    reportingTo continuation: AsyncStream<Float>.Continuation
  ) async throws -> Int {
    defer { continuation.finish() }

    let written = try await writeAirports(document.airports) { processed in
      _ = continuation.yield(Float(processed) / Float(document.airports.count))
    }
    try writeCycle(release)
    return written
  }

  private func writeAirports(
    _ airports: [AirportDTO],
    progress: (Int) -> Void
  ) async throws -> Int {
    var processed = 0,
      written = 0,
      rowsSinceLastSave = 0

    // An airport carries nested approach and fix inserts, so batches are bounded by total
    // inserted rows rather than airport count.
    for dto in airports {
      processed += 1
      guard let airport = dto.makeAirport() else { continue }
      modelContext.insert(airport)
      written += 1
      rowsSinceLastSave += rowCount(of: airport)

      if rowsSinceLastSave >= Self.saveBatchRowLimit {
        try modelContext.save()
        rowsSinceLastSave = 0
        progress(processed)
        await Task.yield()
      }
    }

    if modelContext.hasChanges { try modelContext.save() }
    progress(processed)
    return written
  }

  /// How many rows inserting one airport writes: the airport, its approaches, and their fixes.
  private func rowCount(of airport: Airport) -> Int {
    airport.approaches.reduce(1 + airport.approaches.count) { $0 + $1.fixes.count }
  }

  private func writeCycle(_ release: NavDataReleaseManifest) throws {
    modelContext.insert(
      NavDataCycle(
        airacCycle: release.airacCycle,
        effectiveDate: release.cycleEffective,
        expirationDate: release.cycleExpires,
        sha256: release.data.sha256,
        importedAt: .now
      )
    )
    try modelContext.save()
  }
}

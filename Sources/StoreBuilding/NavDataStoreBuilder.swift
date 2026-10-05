public import Foundation
public import Logging
import NavDataSchema

import CryptoKit
import StreamingLZMAXZ
import SwiftData

/**
 Builds the SwiftData store the app downloads, from the dataset the Navdata release publishes.

 It is written through ``NavDataSchema/NavDataStoreWriter``, the same code the app's own import
 path runs, so the store this produces and the store the app would have built are the same store.
 */
public struct NavDataStoreBuilder: Sendable {
  private let logger: Logger

  /**
   Creates a builder logging to `logger`.

   - Parameter logger: Where to report progress.
   */
  public init(logger: Logger) {
    self.logger = logger
  }

  /**
   Builds a store from a release, and describes it.

   - Parameters:
     - release: The release to build the store from.
     - outputLocation: The directory to write the store and its manifest into.
   - Returns: The files written.
   */
  public func build(_ release: NavDataRelease, outputLocation: URL) async throws -> Output {
    let cycle = release.cycle
    logger.info("Decoded \(release.document.airports.count) airports for cycle \(cycle)")
    try FileManager.default.createDirectory(at: outputLocation, withIntermediateDirectories: true)

    let workspace = outputLocation.appending(path: "build-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: workspace) }

    let (assembled, written) = try await assemble(release, in: workspace)
    let store = outputLocation.appending(path: "\(cycle).store")

    // VACUUM INTO writes one fully materialized file. Copying the store instead would leave its
    // most recent rows in the write-ahead log beside it, and a store shipped without that sidecar
    // opens perfectly and reads as empty.
    try compact(assembled, into: store)

    let counts = try rowCounts(of: store)
    guard counts.airports == UInt(written) else {
      throw Errors.storeIsIncomplete(expected: written, found: counts.airports)
    }

    let compressed = try compress(store, cycle: cycle, in: outputLocation)
    logger.notice(
      """
      Built \(compressed.lastPathComponent): \(bytes(of: store) / 1_048_576) MB uncompressed, \
      \(bytes(of: compressed) / 1_048_576) MB compressed, \(counts.airports) airports, \
      \(counts.approaches) approaches, \(counts.fixes) fixes
      """
    )

    return .init(
      store: compressed,
      manifest: try writeManifest(
        for: compressed,
        release: release,
        counts: counts,
        outputLocation: outputLocation
      )
    )
  }

  /// Compresses the store as an XZ container, which the app streams back out as it downloads.
  private func compress(_ store: URL, cycle: String, in outputLocation: URL) throws -> URL {
    let compressed = outputLocation.appending(path: "\(cycle).store.lzma")
    try Data(contentsOf: store, options: .mappedIfSafe).xzCompressed().write(to: compressed)
    return compressed
  }

  private func bytes(of url: URL) -> Int {
    (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
  }

  /// Writes the dataset into a store of its own, returning the store and how many airports it got.
  private func assemble(
    _ release: NavDataRelease,
    in workspace: URL
  ) async throws -> (store: URL, airports: Int) {
    let layout = StoreLayout(baseDirectory: workspace)
    let container = try NavDataContainer.makeContainer(
      layout: layout,
      generation: 0,
      allowsSave: true
    )
    let (progress, continuation) = AsyncStream<Float>.makeStream(
      of: Float.self,
      bufferingPolicy: .bufferingNewest(1)
    )

    async let written = NavDataStoreWriter(modelContainer: container)
      .write(release.document, release: release.manifest, reportingTo: continuation)
    for await completed in progress {
      logger.debug("Writing store: \(Int(completed * 100))%")
    }

    return (layout.navStoreURL(generation: 0), try await written)
  }

  private func compact(_ source: URL, into destination: URL) throws {
    try? FileManager.default.removeItem(at: destination)

    let process = Process()
    process.executableURL = URL(filePath: "/usr/bin/sqlite3")
    process.arguments = [source.path, "VACUUM INTO '\(destination.path)';"]
    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
      throw Errors.compactionFailed(status: process.terminationStatus)
    }
  }

  /**
   Opens the built store exactly as the app does, and counts what is in it.

   Read-only, through the app's own configuration: a store this binary can write but the app
   cannot open read-only is the failure worth catching here rather than on a device.
   */
  private func rowCounts(of store: URL) throws -> NavDataStoreManifest.Counts {
    let workspace = store.deletingLastPathComponent().appending(path: "verify-\(UUID().uuidString)")
    let layout = StoreLayout(baseDirectory: workspace)
    defer { try? FileManager.default.removeItem(at: workspace) }

    try layout.createDirectories()
    try FileManager.default.copyItem(at: store, to: layout.navStoreURL(generation: 0))

    let context = ModelContext(
      try NavDataContainer.makeContainer(layout: layout, generation: 0, allowsSave: false)
    )
    return .init(
      airports: UInt(try context.fetchCount(FetchDescriptor<Airport>())),
      approaches: UInt(try context.fetchCount(FetchDescriptor<Approach>())),
      fixes: UInt(try context.fetchCount(FetchDescriptor<Fix>()))
    )
  }

  private func writeManifest(
    for store: URL,
    release: NavDataRelease,
    counts: NavDataStoreManifest.Counts,
    outputLocation: URL
  ) throws -> URL {
    let payload = try Data(contentsOf: store, options: .mappedIfSafe)
    let digest = SHA256.hash(data: payload).map { unsafe String(format: "%02x", $0) }.joined()

    let manifest = NavDataStoreManifest(
      cycle: release.cycle,
      effective: release.manifest.cycleEffective,
      expires: release.manifest.cycleExpires,
      schemaFingerprint: NavDataSchema.fingerprint,
      schemaVersion: NavDataSchema.version,
      store: .init(filename: store.lastPathComponent, bytes: UInt(payload.count), sha256: digest),
      counts: counts
    )

    let url = outputLocation.appending(path: "\(release.cycle).json")
    try NavDataStoreManifest.encoder().encode(manifest).write(to: url)
    return url
  }

  /// Reasons a store could not be built.
  public enum Errors: Swift.Error, LocalizedError {
    /// Compacting the store into a single file failed.
    case compactionFailed(status: Int32)

    /// The built store holds fewer airports than were written into it.
    case storeIsIncomplete(expected: Int, found: UInt)

    public var errorDescription: String? { "Couldn’t build the navigation data store." }

    public var failureReason: String? {
      switch self {
        case .compactionFailed(let status):
          "sqlite3 exited with status \(status) while compacting the store."
        case let .storeIsIncomplete(expected, found):
          "The store holds \(found) airports; \(expected) were written."
      }
    }
  }

  /// The files a built store is written to.
  public struct Output: Sendable {
    /// The compressed store.
    public let store: URL

    /// The manifest describing it.
    public let manifest: URL
  }
}

import CryptoKit
import Foundation
import Gzip
import Logging
import NavDataSchema
import StoreBuilding
import StreamingLZMAXZ
import SwiftData
import Testing

/**
 Builds a store from Missoula's RNAV (GPS) Y RWY 12, extracted verbatim from a release, and reads
 it back the way the app will: decompressed from what was published and opened read-only.
 */
@Suite
struct `Store builder` {
  /// Writes the fixture out as a release would publish it, and reads it back as one.
  private static func publishFixtureRelease(in workspace: URL) throws -> NavDataRelease {
    let fixture = try #require(
      Bundle.module.url(forResource: "KMSO", withExtension: "json", subdirectory: "Fixtures")
    )
    let json = try Data(contentsOf: fixture)
    let compressed = try json.gzipped()
    let digest = SHA256.hash(data: compressed).map { unsafe String(format: "%02x", $0) }.joined()

    try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
    let dataURL = workspace.appending(path: "cta-navdata.json.gz"),
      manifestURL = workspace.appending(path: "manifest.json")
    try compressed.write(to: dataURL)
    try Data(
      """
      {"airacCycle": "2609", "cycleEffective": "2026-09-03", "cycleExpires": "2026-10-01",
       "generatedAt": "2026-09-02T13:20:27+00:00",
       "data": {"filename": "cta-navdata.json.gz", "bytes": \(compressed.count),
                "uncompressedBytes": \(json.count), "sha256": "\(digest)"}}
      """.utf8
    )
    .write(to: manifestURL)

    return try NavDataRelease.read(manifestAt: manifestURL, dataAt: dataURL)
  }

  /// Decompresses a published store into a fresh layout and opens it as the app does.
  private static func openPublished(_ compressed: URL, in workspace: URL) throws -> ModelContext {
    let layout = StoreLayout(baseDirectory: workspace.appending(path: "app"))
    try layout.createDirectories()
    try Data(contentsOf: compressed).xzDecompressed().write(to: layout.navStoreURL(generation: 1))
    return ModelContext(
      try NavDataContainer.makeContainer(layout: layout, generation: 1, allowsSave: false)
    )
  }

  @Test
  func `builds a store the app can open read-only`() async throws {
    let workspace = URL.temporaryDirectory.appending(path: "StoreBuilderTests-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: workspace) }

    let release = try Self.publishFixtureRelease(in: workspace)
    let output = try await NavDataStoreBuilder(logger: Logger(label: "test"))
      .build(release, outputLocation: workspace.appending(path: "out"))

    let manifest = try NavDataStoreManifest.decoder()
      .decode(NavDataStoreManifest.self, from: Data(contentsOf: output.manifest))
    #expect(manifest.cycle == "2026-09-03")
    #expect(output.store.lastPathComponent == "2026-09-03.store.lzma")
    #expect(manifest.store.filename == output.store.lastPathComponent)
    #expect(manifest.matchesSchema)
    #expect(manifest.counts == .init(airports: 1, approaches: 1, fixes: 18))

    let context = try Self.openPublished(output.store, in: workspace)
    let airport = try #require(try context.fetch(FetchDescriptor<Airport>()).first)
    #expect(airport.siteNumber == "12453.A")
    #expect(airport.approaches.first?.fixes.count == 18)
    #expect(try context.fetch(FetchDescriptor<NavDataCycle>()).first?.airacCycle == "2609")
  }
}

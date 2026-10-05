import Foundation
import NavDataSchema
import Testing

@Suite
struct `Store manifest` {
  private static let effective = Date(timeIntervalSince1970: 1_788_393_600)
  private static let expires = effective.addingTimeInterval(28 * 24 * 3600)

  private static func manifest(fingerprint: String = NavDataSchema.fingerprint)
    -> NavDataStoreManifest
  {
    .init(
      cycle: NavDataStoreManifest.cycleName(effective: effective),
      effective: effective,
      expires: expires,
      schemaFingerprint: fingerprint,
      schemaVersion: NavDataSchema.version,
      store: .init(filename: "2026-09-03.store.lzma", bytes: 1, sha256: "00"),
      counts: .init(airports: 1, approaches: 1, fixes: 18)
    )
  }

  @Test
  func `is named for its effective date`() {
    #expect(Self.manifest().cycle == "2026-09-03")
  }

  @Test
  func `is in force from the instant it takes effect`() {
    #expect(Self.manifest().isEffective(at: Self.effective))
  }

  @Test
  func `is not in force before it takes effect`() {
    #expect(!Self.manifest().isEffective(at: Self.effective.addingTimeInterval(-1)))
  }

  /// The window is half-open, so the instant a cycle expires belongs to its successor alone.
  @Test
  func `is not in force at the instant it expires`() {
    #expect(Self.manifest().isEffective(at: Self.expires.addingTimeInterval(-1)))
    #expect(!Self.manifest().isEffective(at: Self.expires))
  }

  @Test
  func `matches only the schema this build reads`() {
    #expect(Self.manifest().matchesSchema)
    #expect(!Self.manifest(fingerprint: "stale").matchesSchema)
  }

  @Test
  func `round-trips through its own encoder and decoder`() throws {
    let encoded = try NavDataStoreManifest.encoder().encode(Self.manifest())
    let decoded = try NavDataStoreManifest.decoder().decode(
      NavDataStoreManifest.self,
      from: encoded
    )

    #expect(decoded.effective == Self.effective)
    #expect(decoded.expires == Self.expires)
    #expect(decoded.counts == Self.manifest().counts)
  }
}

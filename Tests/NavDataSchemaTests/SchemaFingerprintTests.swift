import NavDataSchema
import Testing

/**
 The fingerprint is what a client compares against a published manifest before downloading a
 store, so a change to it must be deliberate: pinning it here makes every change to the models'
 shape show up as a failing test, prompting a new ``NavDataSchema/version`` decision and a fresh
 publish.
 */
@Suite
struct `Schema fingerprint` {
  private static let pinned = "5d0c9b079dc45c76b4cff183557b85fb66556dcc80063ed5362d54836405cddc"

  @Test
  func `matches the pinned shape of the models`() {
    #expect(NavDataSchema.fingerprint == Self.pinned)
  }
}

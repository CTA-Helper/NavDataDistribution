import Foundation
public import SwiftData

/**
 One leg of a published approach, with the altitude and segment classification a cold
 temperature correction needs.

 A leg appears once per transition it is flown on, so the same fix can occur several times
 in an approach; ``transition`` and ``sequence`` place it. Legs with no ``identifier`` are
 path terminators (a climb or a heading to intercept) that the app names from ``legType``.
 */
@Model
public final class Fix {
  /// The fix the leg ends at, or `nil` for a path terminator that ends at no fix.
  public var identifier: String?
  /// The transition the leg is flown on, or `nil` for the common route.
  public var transition: String?
  /// The leg's position within its transition, as ARINC 424 numbers it.
  public var sequence: UInt
  /// The ARINC 424 path terminator, or `nil` for a code this schema does not recognize.
  public var legType: LegType?
  /// The fix's role in the approach, or `nil` when it plays none ENR 1.8 names.
  public var role: FixRole?
  /// The approach segment the fix falls in.
  public var segment: Segment
  /// What the fix publishes, whose case decides which altitude a correction moves.
  public var publishedAltitude: PublishedAltitude
  /// Whether the fix is a flyover rather than a fly-by waypoint.
  public var flyover: Bool
  /**
   Whether ENR 1.8 applies a correction to this fix's published altitude at all (the nav
   data's `correctable` flag: false for glidepath altitudes, the runway threshold at the
   MAP, and the climb/intermediate altitudes of a missed approach).
   */
  public var isCorrectable: Bool

  /// The approach this leg belongs to.
  public var approach: Approach?

  /**
   Creates a leg.

   - Parameters:
     - identifier: The fix the leg ends at, or `nil` for a path terminator.
     - transition: The transition the leg is flown on.
     - sequence: The leg's ARINC 424 sequence number.
     - legType: The ARINC 424 path terminator, if recognized.
     - role: The fix's role in the approach, if any.
     - segment: The approach segment the fix falls in.
     - publishedAltitude: What the fix publishes.
     - flyover: Whether the fix is a flyover waypoint.
     - isCorrectable: Whether ENR 1.8 corrects the fix's published altitude.
   */
  public init(
    identifier: String?,
    transition: String?,
    sequence: UInt,
    legType: LegType?,
    role: FixRole?,
    segment: Segment,
    publishedAltitude: PublishedAltitude,
    flyover: Bool,
    isCorrectable: Bool
  ) {
    self.identifier = identifier
    self.transition = transition
    self.sequence = sequence
    self.legType = legType
    self.role = role
    self.segment = segment
    self.publishedAltitude = publishedAltitude
    self.flyover = flyover
    self.isCorrectable = isCorrectable
  }
}

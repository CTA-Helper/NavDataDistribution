/**
 How a fix's single published altitude constrains the aircraft, from the ARINC 424 altitude
 description code.

 A block is not one of these: the ARINC `between` description, whose second altitude is a true
 lower bound rather than the glidepath altitude the others carry, is
 ``PublishedAltitude/block(ceilingFt:floorFt:)``, so no restriction here can be left without
 the second altitude it needs.
 */
public enum AltitudeRestriction: String, Codable, Sendable {
  // These cases decode from the nav data JSON, whose keys are exactly these camelCase names,
  // so their raw values are intentionally the case names.
  // swiftlint:disable raw_value_for_camel_cased_codable_enum
  /// Cross at the published altitude.
  case at
  /// Cross at or above the published altitude.
  case atOrAbove
  /// Cross at or below the published altitude.
  case atOrBelow
  /// A glidepath altitude, coded as the aircraft follows the glideslope/glidepath.
  case glideslope
  /// The altitude at which the glideslope/glidepath is intercepted.
  case glideslopeIntercept
  /// A step-down fix altitude flown with VNAV.
  case stepDownVNAV = "stepDownVnav"
  /**
   Cross at or above the second published altitude (ARINC 424 code `C`).

   No fix in the published data codes it, so it is decoded for forward compatibility. Under
   code `C` the second altitude is the operative bound, but which altitude the generator puts
   where is unconfirmed, so verify against a real record before relying on either.
   */
  case atOrAboveSecond
  // swiftlint:enable raw_value_for_camel_cased_codable_enum
}

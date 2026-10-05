/**
 A fix's role in an approach, as classified from its ARINC 424 waypoint description
 (AIP ENR 1.8 identifies segments by these named fixes).
 */
public enum FixRole: String, Codable, Sendable {
  /// An initial approach fix.
  case initialApproachFix = "iaf"
  /// An initial approach fix with a holding pattern.
  case initialApproachFixHolding = "iafHolding"
  /// The intermediate fix.
  case intermediateFix = "if"
  /// The final approach course fix.
  case finalApproachCourseFix = "facf"
  /// The final approach fix.
  case finalApproachFix = "faf"
  /// The missed approach point.
  case missedApproachPoint = "map"
  /// A step-down fix.
  case stepdown
  // Decodes from the nav data JSON key "missedHolding", so the raw value is the case name.
  // swiftlint:disable raw_value_for_camel_cased_codable_enum
  /// The missed approach holding fix.
  case missedHolding
  // swiftlint:enable raw_value_for_camel_cased_codable_enum
}

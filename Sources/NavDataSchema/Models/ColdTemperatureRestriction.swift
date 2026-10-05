/**
 An airport's Cold Temperature Airport restriction, from the FAA Cold Temperature Airports
 list: below ``restrictionTemperatureC`` a correction is mandatory on the
 ``affectedSegments`` (AIP ENR 1.8 4, 5.a).
 */
public struct ColdTemperatureRestriction: Codable, Hashable, Sendable {
  /// The temperature at or below which a correction is mandatory, in degrees Celsius.
  public var restrictionTemperatureC: Int
  /// The segments a correction is mandatory on.
  public var affectedSegments: Set<Segment>

  /**
   Creates a restriction.

   - Parameters:
     - restrictionTemperatureC: The restriction temperature, in degrees Celsius.
     - affectedSegments: The segments a correction is mandatory on.
   */
  public init(restrictionTemperatureC: Int, affectedSegments: Set<Segment>) {
    self.restrictionTemperatureC = restrictionTemperatureC
    self.affectedSegments = affectedSegments
  }
}

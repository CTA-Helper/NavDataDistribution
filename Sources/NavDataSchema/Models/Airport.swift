import Foundation
public import SwiftData

/**
 An airport with coded approach procedures, and the datum every correction subtracts: its
 elevation.

 The ``siteNumber`` is the primary key. None of an airport's codes can be: the FAA reassigns
 them, and did so as recently as cycle 2607, when Palm Beach became `DJT`/`KDJT`. Anything
 that has to outlive a cycle — a favorite, a recently opened airport — is pinned to the site
 number, which the FAA does not move.
 */
@Model
public final class Airport {
  // Each identifier is unique across every US landing facility, and the codes are checked
  // where they appear — SwiftData holds a constraint against the value, so the airports with
  // no ICAO code do not collide with one another.
  #Unique<Airport>([\.siteNumber], [\.faaIdentifier], [\.icaoIdentifier])

  /**
   The FAA landing facility site number and type code, e.g. `"03555.A"` — or `"00218.12A"`,
   carrying the sequence the FAA assigns when it inserts a facility rather than renumbering
   its neighbours. About a third of them do.

   The sequence is part of the key, not noise to be normalized away: `00218.7A` and
   `00218.12A` are different airports that collide the moment it is dropped. Match the whole
   string; never parse it into parts.
   */
  public var siteNumber: String
  /// The FAA location identifier, e.g. `"MSO"`. Every airport in the database has one.
  public var faaIdentifier: String
  /// The ICAO code, e.g. `"KMSO"` — `nil` for the quarter of airports that have none.
  public var icaoIdentifier: String?
  /// The airport's name, e.g. `"Missoula Montana"`.
  public var name: String
  /// The city the airport serves.
  public var city: String?
  /// The two-letter postal code of the state the airport is in.
  public var state: String?
  /// The full name of the state the airport is in.
  public var stateName: String?
  /// Airport elevation, in feet MSL.
  public var elevationFt: Int
  /// The airport reference point's latitude, in degrees.
  public var latitude: Double
  /// The airport reference point's longitude, in degrees.
  public var longitude: Double
  /// The airport's Cold Temperature Airport restriction, or `nil` when it is not on the list.
  public var coldTemperature: ColdTemperatureRestriction?

  /// The airport's coded approach procedures.
  @Relationship(deleteRule: .cascade, inverse: \Approach.airport)
  public var approaches: [Approach] = []

  /**
   Creates an airport with no approaches.

   - Parameters:
     - siteNumber: The FAA landing facility site number and type code.
     - faaIdentifier: The FAA location identifier.
     - icaoIdentifier: The ICAO code, or `nil` where there is none.
     - name: The airport's name.
     - city: The city the airport serves.
     - state: The two-letter postal code of the airport's state.
     - stateName: The full name of the airport's state.
     - elevationFt: Airport elevation, in feet MSL.
     - latitude: The airport reference point's latitude, in degrees.
     - longitude: The airport reference point's longitude, in degrees.
     - coldTemperature: The airport's Cold Temperature Airport restriction, if any.
   */
  public init(
    siteNumber: String,
    faaIdentifier: String,
    icaoIdentifier: String?,
    name: String,
    city: String?,
    state: String?,
    stateName: String?,
    elevationFt: Int,
    latitude: Double,
    longitude: Double,
    coldTemperature: ColdTemperatureRestriction?
  ) {
    self.siteNumber = siteNumber
    self.faaIdentifier = faaIdentifier
    self.icaoIdentifier = icaoIdentifier
    self.name = name
    self.city = city
    self.state = state
    self.stateName = stateName
    self.elevationFt = elevationFt
    self.latitude = latitude
    self.longitude = longitude
    self.coldTemperature = coldTemperature
  }
}

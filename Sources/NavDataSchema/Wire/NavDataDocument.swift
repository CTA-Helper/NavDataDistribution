import Foundation

/**
 The decoded `cta-navdata.json.gz` document — a data-transfer view that decodes the JSON,
 then builds the persisted ``Airport`` / ``Approach`` / ``Fix`` models.

 The enums decode leniently through the DTO: an unrecognized altitude description or role is
 mapped to a safe default (or dropped) rather than throwing, so one odd record can never
 fail the import of the whole database.
 */
public struct NavDataDocument: Decodable, Sendable {
  /// Every airport the release publishes.
  public let airports: [AirportDTO]
}

/// The wire form of an ``Airport``.
public struct AirportDTO: Decodable, Sendable {
  /// The FAA landing facility site number and type code.
  public let siteNumber: String
  /// The FAA location identifier.
  public let faaIdentifier: String
  /// The ICAO code, where there is one.
  public let icaoIdentifier: String?
  /// The airport's name.
  public let name: String
  /// The city the airport serves.
  public let city: String?
  /// The two-letter postal code of the airport's state.
  public let state: String?
  /// The full name of the airport's state.
  public let stateName: String?
  /// Airport elevation, in feet MSL.
  public let elevationFt: Int?
  /// The airport reference point's latitude, in degrees.
  public let latitude: Double?
  /// The airport reference point's longitude, in degrees.
  public let longitude: Double?
  /// The airport's Cold Temperature Airport restriction, if any.
  public let coldTemperature: ColdTemperatureRestriction?
  /// The airport's coded approaches.
  public let approaches: [ApproachDTO]

  private enum CodingKeys: String, CodingKey {
    case siteNumber, faaIdentifier, icaoIdentifier, name, city, state, stateName
    case elevationFt = "elevation"
    case latitude, longitude, coldTemperature, approaches
  }
}

/// The wire form of an ``Approach``.
public struct ApproachDTO: Decodable, Sendable {
  /// The ARINC 424 identifier.
  public let identifier: String
  /// The name as charted.
  public let name: String
  /// The runway served, if any.
  public let runway: String?
  /// The approach plate's URL, as the wire spells it.
  public let chartURL: String?
  /// The altitude each correction method starts from, in its wire shape.
  public let referenceAltitudes: ReferenceAltitudesDTO
  /// The procedure's legs.
  public let fixes: [FixDTO]

  private enum CodingKeys: String, CodingKey {
    case identifier, name, runway
    case chartURL = "chartUrl"
    case referenceAltitudes, fixes
  }
}

/**
 The wire form of ``ReferenceAltitudes``: the JSON codes each reference altitude in feet under
 the key `altitude`, beside a source naming where it came from. Decoding into a DTO keeps that
 wire shape off the persisted model, where the pairing becomes a single ``ReferenceAltitude``
 that can no longer name a source without the altitude it published.
 */
public struct ReferenceAltitudesDTO: Decodable, Sendable {
  /// The initial segment's reference.
  public let initial: ReferenceDTO
  /// The intermediate segment's reference.
  public let intermediate: ReferenceDTO
  /// The final segment's reference.
  public let final: ReferenceDTO
  /// The missed approach segment's reference.
  public let missed: ReferenceDTO
  /// The All Segments Method's reference.
  public let allSegments: ReferenceDTO

  /// The persisted form of these references.
  public var model: ReferenceAltitudes {
    ReferenceAltitudes(
      initial: initial.model,
      intermediate: intermediate.model,
      final: final.model,
      missed: missed.model,
      allSegments: allSegments.model
    )
  }
}

/// The wire form of one ``ReferenceAltitude``.
public struct ReferenceDTO: Decodable, Sendable {
  /// The reference altitude in feet, where the wire codes one.
  public let altitudeFt: Int?
  /// Where the wire says the reference comes from.
  public let source: Source

  /// The persisted form of this reference.
  public var model: ReferenceAltitude {
    switch source {
      case .intermediateFix: published(from: .intermediateFix)
      case .finalApproachFix: published(from: .finalApproachFix)
      case .missedHolding: published(from: .missedHolding)
      case .pilotEntered: .pilotEntered
      case .unavailable: .unavailable
    }
  }

  /**
   The published reference, or ``ReferenceAltitude/unavailable`` when the wire named the fix
   the reference comes from but coded no altitude for it.
   */
  private func published(from source: PublishedReferenceSource) -> ReferenceAltitude {
    guard let altitudeFt else { return .unavailable }
    return .published(ft: altitudeFt, source: source)
  }

  /**
   Where the wire says a reference altitude comes from. ``pilotEntered`` and ``unavailable``
   are the two that never publish an altitude, and become ``ReferenceAltitude`` cases in their
   own right rather than a source paired with a missing one.
   */
  public enum Source: String, Decodable, Sendable {
    /// The intermediate fix altitude.
    case intermediateFix = "if"
    /// The final approach fix altitude.
    case finalApproachFix = "faf"
    // These decode from the nav data JSON, whose values are exactly these camelCase names, so
    // their raw values are intentionally the case names.
    // swiftlint:disable raw_value_for_camel_cased_codable_enum
    /// The missed approach holding altitude.
    case missedHolding
    /// The DA or MDA the pilot enters.
    case pilotEntered
    /// No reference could be resolved.
    case unavailable
    // swiftlint:enable raw_value_for_camel_cased_codable_enum
  }

  private enum CodingKeys: String, CodingKey {
    case altitudeFt = "altitude"
    case source
  }
}

/**
 A leg's position within its procedure, as the wire codes it.

 ARINC 424 numbers legs from 10 upward, so a negative value is corrupt data rather than a
 procedure the app does not recognize. Decoding it fails the import, because the alternative —
 dropping the leg — would show the pilot an approach missing one of the fixes it flies.
 */
public struct SequenceNumber: Decodable, Sendable {
  /// The sequence number.
  public let value: UInt

  public init(from decoder: any Decoder) throws {
    let coded = try decoder.singleValueContainer().decode(Int.self)
    guard let value = UInt(exactly: coded) else {
      throw DecodingError.dataCorrupted(
        .init(
          codingPath: decoder.codingPath,
          debugDescription: "A leg's sequence number cannot be negative; this one codes \(coded)."
        )
      )
    }
    self.value = value
  }
}

/// The wire form of a ``Fix``.
public struct FixDTO: Decodable, Sendable {
  /// The fix the leg ends at, if any.
  public let identifier: String?
  /// The transition the leg is flown on.
  public let transition: String?
  /// The leg's ARINC 424 sequence number.
  public let sequence: SequenceNumber
  /// The ARINC 424 path terminator code.
  public let legType: String
  /// The fix's role, as the wire codes it.
  public let role: String?
  /// The approach segment the fix falls in.
  public let segment: Segment
  /// The primary coded altitude, in feet.
  public let altitudeFt: Int?
  /// The second coded altitude, in feet.
  public let altitude2Ft: Int?
  /// How the coded altitudes constrain the aircraft.
  public let altitudeDescription: AltitudeDescription
  /// Whether the fix is a flyover waypoint.
  public let flyover: Bool
  /// Whether ENR 1.8 corrects the fix's published altitude.
  public let correctable: Bool

  private enum CodingKeys: String, CodingKey {
    case identifier, transition, sequence, legType, role, segment
    case altitudeFt = "altitude"
    case altitude2Ft = "altitude2"
    case altitudeDescription, flyover, correctable
  }
}

extension AirportDTO {
  /**
   Build the persisted airport, or `nil` if it lacks the elevation and coordinates every
   correction and the nearest query need (no airport in the published data does).
   */
  public func makeAirport() -> Airport? {
    guard let elevationFt, let latitude, let longitude else { return nil }

    let airport = Airport(
      siteNumber: siteNumber,
      faaIdentifier: faaIdentifier,
      icaoIdentifier: icaoIdentifier,
      name: name,
      city: city,
      state: state,
      stateName: stateName,
      elevationFt: elevationFt,
      latitude: latitude,
      longitude: longitude,
      coldTemperature: coldTemperature
    )
    airport.approaches = approaches.map { $0.makeApproach() }
    return airport
  }
}

extension ApproachDTO {
  /// Build the persisted approach and its fixes.
  public func makeApproach() -> Approach {
    let approach = Approach(
      identifier: identifier,
      name: name,
      runway: runway,
      chartURL: chartURL.flatMap(URL.init(string:)),
      referenceAltitudes: referenceAltitudes.model
    )
    approach.fixes = fixes.map { $0.makeFix() }
    return approach
  }
}

extension FixDTO {
  /// Build the persisted fix.
  public func makeFix() -> Fix {
    Fix(
      identifier: identifier,
      transition: transition,
      sequence: sequence.value,
      legType: LegType(rawValue: legType),
      role: role.flatMap(FixRole.init(rawValue:)),
      segment: segment,
      publishedAltitude: altitudeDescription.publishedAltitude(
        altitudeFt: altitudeFt,
        altitude2Ft: altitude2Ft
      ),
      flyover: flyover,
      isCorrectable: correctable
    )
  }
}

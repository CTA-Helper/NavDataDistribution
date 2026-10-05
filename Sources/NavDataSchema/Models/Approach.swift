public import Foundation
public import SwiftData

/// A published instrument approach procedure and its fixes.
@Model
public final class Approach {
  /// The ARINC 424 identifier, e.g. `"R12-Y"`.
  public var identifier: String
  /// The name as charted, e.g. `"RNAV (GPS) Y RWY 12"`.
  public var name: String
  /// The runway served, e.g. `"12"`, or `nil` for a circling-only procedure.
  public var runway: String?
  /// The approach plate's URL, or `nil` when no chart matched.
  public var chartURL: URL?
  /// The altitude each correction method enters the calculation with.
  public var referenceAltitudes: ReferenceAltitudes

  /// The airport the procedure serves.
  public var airport: Airport?

  /// The procedure's legs, one per transition each is flown on.
  @Relationship(deleteRule: .cascade, inverse: \Fix.approach)
  public var fixes: [Fix] = []

  /**
   Creates an approach with no fixes.

   - Parameters:
     - identifier: The ARINC 424 identifier.
     - name: The name as charted.
     - runway: The runway served, or `nil` for a circling-only procedure.
     - chartURL: The approach plate's URL, or `nil` when no chart matched.
     - referenceAltitudes: The altitude each correction method starts from.
   */
  public init(
    identifier: String,
    name: String,
    runway: String?,
    chartURL: URL?,
    referenceAltitudes: ReferenceAltitudes
  ) {
    self.identifier = identifier
    self.name = name
    self.runway = runway
    self.chartURL = chartURL
    self.referenceAltitudes = referenceAltitudes
  }
}

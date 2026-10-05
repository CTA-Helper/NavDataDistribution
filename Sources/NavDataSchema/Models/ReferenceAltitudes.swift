/**
 The altitude each correction method enters the cold temperature calculation with.

 The four individual segments follow AIP ENR 1.8 5.f.2.1; ``allSegments`` is the single
 reference the All Segments Method uses for the whole approach from the IAF to the FAF
 (ENR 1.8 5.f.1). A segment whose reference the coded procedure did not publish carries a
 ``ReferenceAltitude`` case saying why — ``ReferenceAltitude/unavailable`` or
 ``ReferenceAltitude/pilotEntered``.
 */
public struct ReferenceAltitudes: Codable, Hashable, Sendable {
  /// The initial segment's reference.
  public var initial: ReferenceAltitude
  /// The intermediate segment's reference.
  public var intermediate: ReferenceAltitude
  /// The final segment's reference.
  public var final: ReferenceAltitude
  /// The missed approach segment's reference.
  public var missed: ReferenceAltitude
  /// The All Segments Method's single reference, from the IAF to the FAF.
  public var allSegments: ReferenceAltitude

  /**
   Creates a set of references.

   - Parameters:
     - initial: The initial segment's reference.
     - intermediate: The intermediate segment's reference.
     - final: The final segment's reference.
     - missed: The missed approach segment's reference.
     - allSegments: The All Segments Method's reference.
   */
  public init(
    initial: ReferenceAltitude,
    intermediate: ReferenceAltitude,
    final: ReferenceAltitude,
    missed: ReferenceAltitude,
    allSegments: ReferenceAltitude
  ) {
    self.initial = initial
    self.intermediate = intermediate
    self.final = final
    self.missed = missed
    self.allSegments = allSegments
  }
}

/**
 An ARINC 424 path terminator: how a leg is flown, and what ends it.

 Most legs end at a named fix. The ones that end at an altitude, an intercept or a manual
 termination code no fix to name, so the leg type is what describes them.
 */
public enum LegType: String, Codable, Sendable {
  /// `AF`: a DME arc to a fix.
  case arcToFix = "AF"
  /// `CA`: a course to an altitude.
  case courseToAltitude = "CA"
  /// `CD`: a course to a DME distance.
  case courseToDME = "CD"
  /// `CF`: a course to a fix.
  case courseToFix = "CF"
  /// `CI`: a course to intercept the next leg.
  case courseToIntercept = "CI"
  /// `CR`: a course to a VOR radial.
  case courseToRadial = "CR"
  /// `DF`: direct to a fix.
  case directToFix = "DF"
  /// `FA`: a track from a fix to an altitude.
  case fixToAltitude = "FA"
  /// `FC`: a track from a fix for a distance.
  case trackFromFixForDistance = "FC"
  /// `FD`: a track from a fix to a DME distance.
  case trackFromFixToDME = "FD"
  /// `FM`: a track from a fix to a manual termination.
  case fromFixToManualTermination = "FM"
  /// `HA`: a hold to an altitude.
  case holdToAltitude = "HA"
  /// `HF`: a hold to a fix, flown once.
  case holdToFix = "HF"
  /// `HM`: a hold to a manual termination.
  case holdToManualTermination = "HM"
  /// `IF`: the initial fix of a procedure or transition.
  case initialFix = "IF"
  /// `PI`: a procedure turn.
  case procedureTurn = "PI"
  /// `RF`: a constant-radius arc to a fix.
  case radiusToFix = "RF"
  /// `TF`: a track to a fix.
  case trackToFix = "TF"
  /// `VA`: a heading to an altitude.
  case headingToAltitude = "VA"
  /// `VD`: a heading to a DME distance.
  case headingToDME = "VD"
  /// `VI`: a heading to intercept the next leg.
  case headingToIntercept = "VI"
  /// `VM`: a heading to a manual termination.
  case headingToManualTermination = "VM"
  /// `VR`: a heading to a VOR radial.
  case headingToRadial = "VR"
}

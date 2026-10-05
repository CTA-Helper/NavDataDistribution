public import Foundation
public import SwiftData

/**
 The AIRAC cycle a store's nav data was built from. A single row records which cycle the store
 holds and which published release it came from.
 */
@Model
public final class NavDataCycle {
  /// The AIRAC cycle identifier, e.g. `"2609"`.
  public var airacCycle: String
  /// When the cycle takes effect.
  public var effectiveDate: Date
  /// When the cycle expires, which is when its successor takes effect.
  public var expirationDate: Date
  /// The SHA-256 of the published data file the store was built from.
  public var sha256: String
  /// When the data file was written into the store.
  public var importedAt: Date

  /**
   Creates a cycle record.

   - Parameters:
     - airacCycle: The AIRAC cycle identifier.
     - effectiveDate: When the cycle takes effect.
     - expirationDate: When the cycle expires.
     - sha256: The SHA-256 of the published data file the store was built from.
     - importedAt: When the data file was written into the store.
   */
  public init(
    airacCycle: String,
    effectiveDate: Date,
    expirationDate: Date,
    sha256: String,
    importedAt: Date
  ) {
    self.airacCycle = airacCycle
    self.effectiveDate = effectiveDate
    self.expirationDate = expirationDate
    self.sha256 = sha256
    self.importedAt = importedAt
  }
}

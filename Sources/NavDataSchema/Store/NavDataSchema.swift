public import SwiftData

import CryptoKit
import Foundation

/**
 The models making up the published navigation dataset, and the identity of the store shape they
 form.

 The dataset is replaced wholesale every 28-day cycle, so the store holds nothing else: it
 arrives as a prebuilt file and is installed by switching to that file, and anything the pilot
 chose — favorites, recents — lives outside it, keyed by ``Airport/siteNumber``.
 */
public enum NavDataSchema {
  /// Every model describing downloaded navigation data.
  public static let models: [any PersistentModel.Type] = [
    Airport.self,
    Approach.self,
    Fix.self,
    NavDataCycle.self
  ]

  /// The schema these models form.
  public static let schema = Schema(models)

  /**
   The version of the store's contents this package writes and reads.

   The ``fingerprint`` catches a change to the store's shape. This catches a change to what the
   rows *mean* under the same shape — a field the builder starts filling differently — and is
   raised by hand when that happens.
   */
  public static let version = 1

  /**
   A digest of the schema's shape, identifying the store layout this binary can read.

   A prebuilt store is written by a different binary than the one that reads it, so the two have
   to agree on the schema before the file is opened. Opening first and hoping is not equivalent:
   SwiftData answers a near-miss by migrating the store rather than by refusing it, which turns a
   mismatch into a silent slow migration instead of a clean fall back to the import path.
   */
  public static var fingerprint: String { schema.shapeFingerprint }
}

extension Schema {
  /**
   A digest over this schema's entities, attributes and relationships.

   Rendered explicitly rather than by encoding `Schema` itself, so the digest changes only when
   the store's shape changes and not when an unrelated detail of SwiftData's own encoding does.
   */
  var shapeFingerprint: String {
    let digest = SHA256.hash(data: Data(canonicalShapeDescription.utf8))
    return digest.map { unsafe String(format: "%02x", $0) }.joined()
  }

  private var canonicalShapeDescription: String {
    entities.sorted { $0.name < $1.name }.map(\.canonicalShapeDescription).joined(separator: "\n")
  }
}

extension Schema.Entity {
  fileprivate var canonicalShapeDescription: String {
    ([name] + attributeDescriptions + relationshipDescriptions).joined(separator: "|")
  }

  private var attributeDescriptions: [String] {
    attributes.sorted { $0.name < $1.name }
      .map { "\($0.name):\($0.valueType):\($0.isOptional ? "optional" : "required")" }
  }

  private var relationshipDescriptions: [String] {
    relationships.sorted { $0.name < $1.name }
      .map {
        let rule = String(describing: $0.deleteRule)
        return "\($0.name)->\($0.destination):\(rule):\($0.isOptional ? "optional" : "required")"
      }
  }
}

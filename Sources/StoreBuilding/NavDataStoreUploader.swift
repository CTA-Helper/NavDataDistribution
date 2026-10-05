import Foundation
public import Logging

/**
 Publishes a built nav data store and its manifest to R2.

 The app asks for a cycle by name, so the two files are keyed by cycle rather than by anything
 mutable. The manifest goes up **after** the store: a client that finds a manifest can rely on the
 store it names being there, whereas the reverse ordering would advertise a file still uploading.
 */
public struct NavDataStoreUploader: Sendable {
  /// Where CTA Helper looks for published nav data in the bucket.
  public static let defaultKeyPrefix = "navdata"

  private let config: R2Configuration
  private let keyPrefix: String
  private let logger: Logger

  /**
   Creates an uploader.

   - Parameters:
     - config: The bucket to publish to.
     - keyPrefix: The folder in the bucket to publish into, with or without a trailing slash.
     - logger: Where to report progress.
   */
  public init(
    config: R2Configuration,
    keyPrefix: String = defaultKeyPrefix,
    logger: Logger
  ) {
    self.config = config
    self.keyPrefix = keyPrefix.hasSuffix("/") ? String(keyPrefix.dropLast()) : keyPrefix
    self.logger = logger
  }

  /**
   Whether a cycle's manifest is already published, and so the cycle needs no rebuilding.

   - Parameter cycle: The cycle to look for.
   */
  public func isPublished(cycle: String) async throws -> Bool {
    try await R2Uploader(config: config, logger: logger)
      .objectExists(at: key(for: "\(cycle).json"))
  }

  /**
   Uploads a cycle's store and manifest.

   - Parameters:
     - output: The files ``NavDataStoreBuilder`` produced.
     - cycle: The cycle they belong to.
   */
  public func upload(_ output: NavDataStoreBuilder.Output, cycle: String) async throws {
    let uploader = R2Uploader(config: config, logger: logger)

    try await uploader.uploadFile(
      at: output.store,
      key: key(for: output.store.lastPathComponent),
      contentType: "application/x-xz"
    )

    // Only now is the manifest true.
    try await uploader.uploadFile(
      at: output.manifest,
      key: key(for: output.manifest.lastPathComponent),
      contentType: "application/json"
    )

    logger.notice("Published cycle \(cycle) to \(manifestURL(cycle: cycle))")
  }

  private func key(for filename: String) -> String { "\(keyPrefix)/\(filename)" }

  private func manifestURL(cycle: String) -> String {
    let base =
      config.publicURL.hasSuffix("/") ? String(config.publicURL.dropLast()) : config.publicURL
    return "\(base)/\(key(for: "\(cycle).json"))"
  }
}

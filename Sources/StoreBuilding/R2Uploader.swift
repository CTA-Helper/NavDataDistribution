public import Foundation
import Logging

import SwiftR2

/// Uploads files to Cloudflare R2.
actor R2Uploader {
  /// The size of each part of a multipart upload, and the size below which a file goes up whole.
  private static let partSize = 10 * 1024 * 1024
  private static let maxConcurrentParts = 2
  private static let maxPartRetries = 3
  private static let requestTimeout: TimeInterval = 300

  private let config: R2Configuration
  private let logger: Logger
  private let client: R2Client
  private let uploadManager: MultipartUploadManager

  init(config: R2Configuration, logger: Logger) {
    self.config = config
    self.logger = logger

    client = R2Client(
      configuration: R2ClientConfiguration(
        accountId: config.accountID,
        accessKeyId: config.accessKeyID,
        secretAccessKey: config.secretAccessKey,
        timeoutInterval: Self.requestTimeout
      )
    )
    uploadManager = MultipartUploadManager(
      client: client,
      configuration: MultipartUploadConfiguration(
        partSize: Self.partSize,
        maxConcurrentUploads: Self.maxConcurrentParts,
        retryFailedParts: true,
        maxRetryAttempts: Self.maxPartRetries
      )
    )
  }

  /**
   Uploads a file, in parts when it is large.

   - Parameters:
     - localURL: The file to upload.
     - key: The object key to store it under.
     - contentType: The object's media type.
   */
  func uploadFile(at localURL: URL, key: String, contentType: String) async throws {
    let fileSize =
      try FileManager.default.attributesOfItem(atPath: localURL.path)[.size] as? Int ?? 0
    logger.info("Uploading \(key) (\(fileSize) bytes) to R2…")

    do {
      if fileSize <= Self.partSize {
        _ = try await client.putObject(
          bucket: config.bucketName,
          key: key,
          body: try Data(contentsOf: localURL),
          contentType: contentType
        )
      } else {
        _ = try await uploadManager.upload(
          bucket: config.bucketName,
          key: key,
          fileURL: localURL,
          contentType: contentType
        )
      }
      logger.notice("Uploaded \(key) to R2")
    } catch {
      logger.error("R2 upload failed: \(error)")
      throw R2UploadError.uploadFailed(filename: localURL.lastPathComponent)
    }
  }

  /**
   Whether the bucket holds an object at a key.

   - Parameter key: The object key to look for.
   */
  func objectExists(at key: String) async throws -> Bool {
    do {
      _ = try await client.headObject(bucket: config.bucketName, key: key)
      return true
    } catch SwiftR2.R2Error.notFound {
      return false
    }
  }
}

/// Where to upload published stores, and the credentials to do it with.
public struct R2Configuration: Sendable {
  private static let environmentKeys = (
    accountID: "R2_ACCOUNT_ID",
    accessKeyID: "R2_ACCESS_KEY_ID",
    secretAccessKey: "R2_SECRET_ACCESS_KEY",
    bucketName: "R2_BUCKET_NAME",
    publicURL: "R2_PUBLIC_URL"
  )

  let accountID: String
  let accessKeyID: String
  let secretAccessKey: String
  let bucketName: String
  let publicURL: String

  /**
   Reads the configuration from `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`,
   `R2_BUCKET_NAME` and `R2_PUBLIC_URL`.

   - Parameter environment: The environment to read.
   - Throws: ``R2UploadError/missingEnvironment(_:)`` naming the first variable not set.
   */
  public init(environment: [String: String] = ProcessInfo.processInfo.environment) throws {
    func value(_ key: String) throws -> String {
      guard let value = environment[key], !value.isEmpty else {
        throw R2UploadError.missingEnvironment(key)
      }
      return value
    }

    accountID = try value(Self.environmentKeys.accountID)
    accessKeyID = try value(Self.environmentKeys.accessKeyID)
    secretAccessKey = try value(Self.environmentKeys.secretAccessKey)
    bucketName = try value(Self.environmentKeys.bucketName)
    publicURL = try value(Self.environmentKeys.publicURL)
  }
}

/// Reasons a store could not be published to R2.
public enum R2UploadError: Swift.Error, LocalizedError {
  /// An environment variable the configuration needs is not set.
  case missingEnvironment(String)

  /// A file failed to upload.
  case uploadFailed(filename: String)

  public var errorDescription: String? { "Couldn’t upload to R2." }

  public var failureReason: String? {
    switch self {
      case .missingEnvironment(let key): "The environment variable \(key) is not set."
      case .uploadFailed(let filename): "Uploading “\(filename)” failed."
    }
  }
}

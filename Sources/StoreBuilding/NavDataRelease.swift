public import Foundation
public import NavDataSchema

import CryptoKit
import Gzip

/**
 A `CTA-Helper/Navdata` release, checked against its manifest and decoded.

 The release is the input every store is built from, so it is held to the digest and sizes its
 manifest publishes before a single row is written: a truncated download would otherwise become
 a plausible-looking store missing airports.
 */
public struct NavDataRelease: Sendable {
  /// Where the newest release's assets are served from.
  public static let latestReleaseURL = URL(
    string: "https://github.com/CTA-Helper/Navdata/releases/latest/download"
  )!

  private static let manifestFilename = "manifest.json"

  /// What the release says about itself.
  public let manifest: NavDataReleaseManifest

  /// The decoded dataset.
  public let document: NavDataDocument

  /// The name the store built from this release is published under.
  public var cycle: String { NavDataStoreManifest.cycleName(effective: manifest.cycleEffective) }

  /**
   Reads a release from files on disk.

   - Parameters:
     - manifestURL: The release's `manifest.json`.
     - dataURL: The release's gzipped data file.
   - Returns: The release, verified against its manifest and decoded.
   - Throws: ``Errors`` if the data file is not the file the manifest describes.
   */
  public static func read(manifestAt manifestURL: URL, dataAt dataURL: URL) throws -> Self {
    let manifest = try NavDataReleaseManifest.decoder()
      .decode(NavDataReleaseManifest.self, from: Data(contentsOf: manifestURL))
    let compressed = try Data(contentsOf: dataURL, options: .mappedIfSafe)
    try verify(compressed, against: manifest.data)

    let json = try compressed.gunzipped()
    guard UInt(json.count) == manifest.data.uncompressedBytes else {
      throw Errors.sizeMismatch(expected: manifest.data.uncompressedBytes, actual: UInt(json.count))
    }

    return .init(
      manifest: manifest,
      document: try JSONDecoder().decode(NavDataDocument.self, from: json)
    )
  }

  /**
   Downloads the newest published release and reads it.

   - Parameter directory: Where to save the downloaded assets.
   - Returns: The release, verified against its manifest and decoded.
   */
  public static func downloadLatest(into directory: URL) async throws -> Self {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let manifestURL = try await download(manifestFilename, into: directory)
    let manifest = try NavDataReleaseManifest.decoder()
      .decode(NavDataReleaseManifest.self, from: Data(contentsOf: manifestURL))
    let dataURL = try await download(manifest.data.filename, into: directory)
    return try read(manifestAt: manifestURL, dataAt: dataURL)
  }

  private static func download(_ filename: String, into directory: URL) async throws -> URL {
    let (downloaded, response) = try await URLSession.shared.download(
      from: latestReleaseURL.appending(path: filename)
    )
    if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
      throw Errors.httpError(filename: filename, statusCode: http.statusCode)
    }

    let destination = directory.appending(path: filename)
    try? FileManager.default.removeItem(at: destination)
    try FileManager.default.moveItem(at: downloaded, to: destination)
    return destination
  }

  private static func verify(
    _ compressed: Data,
    against file: NavDataReleaseManifest.DataFile
  ) throws {
    guard UInt(compressed.count) == file.bytes else {
      throw Errors.sizeMismatch(expected: file.bytes, actual: UInt(compressed.count))
    }
    let digest = SHA256.hash(data: compressed).map { unsafe String(format: "%02x", $0) }.joined()
    guard digest.caseInsensitiveCompare(file.sha256) == .orderedSame else {
      throw Errors.checksumMismatch(expected: file.sha256, actual: digest)
    }
  }

  /// Reasons a release could not be read.
  public enum Errors: Swift.Error, LocalizedError {
    /// The release server answered a download with a non-success status.
    case httpError(filename: String, statusCode: Int)

    /// A file was not the size the manifest published.
    case sizeMismatch(expected: UInt, actual: UInt)

    /// The data file did not hash to the digest the manifest published.
    case checksumMismatch(expected: String, actual: String)

    public var errorDescription: String? { "Couldn’t read the Navdata release." }

    public var failureReason: String? {
      switch self {
        case let .httpError(filename, statusCode):
          "Downloading \(filename) returned HTTP status \(statusCode)."
        case let .sizeMismatch(expected, actual):
          "The file was \(actual) bytes; the manifest publishes \(expected)."
        case let .checksumMismatch(expected, actual):
          "The data file hashed to \(actual); the manifest publishes \(expected)."
      }
    }
  }
}

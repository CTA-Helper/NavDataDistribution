public import Foundation

/**
 The `manifest.json` published beside each `CTA-Helper/Navdata` release: what cycle the release's
 `cta-navdata.json.gz` holds, and the digest and sizes to check a download of it against.
 */
public struct NavDataReleaseManifest: Decodable, Sendable {
  /// The AIRAC cycle identifier, e.g. `"2609"`.
  public let airacCycle: String
  /// When the cycle takes effect.
  public let cycleEffective: Date
  /// When the cycle expires.
  public let cycleExpires: Date
  /// When the release was generated.
  public let generatedAt: Date
  /// The data file the release publishes.
  public let data: DataFile

  /**
   Creates a manifest.

   - Parameters:
     - airacCycle: The AIRAC cycle identifier.
     - cycleEffective: When the cycle takes effect.
     - cycleExpires: When the cycle expires.
     - generatedAt: When the release was generated.
     - data: The data file the release publishes.
   */
  public init(
    airacCycle: String,
    cycleEffective: Date,
    cycleExpires: Date,
    generatedAt: Date,
    data: DataFile
  ) {
    self.airacCycle = airacCycle
    self.cycleEffective = cycleEffective
    self.cycleExpires = cycleExpires
    self.generatedAt = generatedAt
    self.data = data
  }

  /**
   A `JSONDecoder` configured for the manifest's ISO-8601 dates (`cycleEffective` is a plain
   date, `generatedAt` a full timestamp), so both parse.
   */
  public static func decoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
      let string = try decoder.singleValueContainer().decode(String.self)
      if let date = flexibleDate(from: string) { return date }
      throw DecodingError.dataCorrupted(
        .init(codingPath: decoder.codingPath, debugDescription: "Unrecognized date: \(string)")
      )
    }
    return decoder
  }

  private static func flexibleDate(from string: String) -> Date? {
    let withTime = ISO8601DateFormatter()
    if let date = withTime.date(from: string) { return date }
    let dateOnly = ISO8601DateFormatter()
    dateOnly.formatOptions = [.withFullDate]
    return dateOnly.date(from: string)
  }

  /// The gzipped document a release publishes.
  public struct DataFile: Decodable, Sendable {
    /// The file's name within the release.
    public let filename: String
    /// The compressed size, in bytes.
    public let bytes: UInt
    /// The decompressed size, in bytes.
    public let uncompressedBytes: UInt
    /// The compressed file's SHA-256 digest, as hexadecimal.
    public let sha256: String

    /**
     Creates a data file description.

     - Parameters:
       - filename: The file's name within the release.
       - bytes: The compressed size.
       - uncompressedBytes: The decompressed size.
       - sha256: The compressed file's SHA-256 digest.
     */
    public init(filename: String, bytes: UInt, uncompressedBytes: UInt, sha256: String) {
      self.filename = filename
      self.bytes = bytes
      self.uncompressedBytes = uncompressedBytes
      self.sha256 = sha256
    }
  }
}

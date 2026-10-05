import ArgumentParser
import Foundation
import Logging
import StoreBuilding

/**
 Builds the prebuilt SwiftData store CTA Helper downloads, from a `CTA-Helper/Navdata` release.

 Reads the release from disk or downloads the newest one, writes it into a store through the
 package's own writer, compacts and verifies the store, compresses it to
 `<effective-date>.store.lzma` and describes it in `<effective-date>.json`. With `--upload` it then
 publishes both to R2.
 */
@main
struct NavDataStoreBuilderCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "navdata-store-builder",
    abstract: "Builds the prebuilt CTA Helper nav data store from a Navdata release."
  )

  @Option(help: "A local release manifest.json. Downloads the newest release when omitted.")
  var manifest: String?

  @Option(help: "A local cta-navdata.json.gz. Downloads the newest release when omitted.")
  var data: String?

  @Option(help: "Directory to write the store and its manifest to.")
  var output = FileManager.default.currentDirectoryPath

  @Flag(help: "Publish the store and its manifest to R2, with credentials from R2_* variables.")
  var upload = false

  @Flag(help: "Exit without building when the cycle's manifest is already published to R2.")
  var skipIfPublished = false

  func validate() throws {
    guard (manifest == nil) == (data == nil) else {
      throw ValidationError("Pass --manifest and --data together, or neither.")
    }
    guard upload || !skipIfPublished else {
      throw ValidationError("--skip-if-published only applies with --upload.")
    }
  }

  func run() async throws {
    do {
      try await build()
    } catch {
      report(error)
      throw ExitCode.failure
    }
  }

  /**
   Writes everything known about a failure to standard error.

   ArgumentParser reports a thrown error with `localizedDescription` alone, which drops the
   failure reason — the part naming the HTTP status behind a refused download, for instance.
   */
  private func report(_ error: any Swift.Error) {
    var lines = [error.localizedDescription]
    if let error = error as? any LocalizedError, let reason = error.failureReason {
      lines.append(reason)
    }
    lines.append(String(describing: error))
    FileHandle.standardError.write(Data("Error: \(lines.joined(separator: "\n  "))\n".utf8))
  }

  private func build() async throws {
    LoggingSystem.bootstrap { label in
      var handler = StreamLogHandler.standardOutput(label: label)
      handler.logLevel = .info
      return handler
    }
    let logger = Logger(label: "codes.tim.navdata-store-builder")
    let outputURL = URL(filePath: output, directoryHint: .isDirectory)

    let release = try await loadRelease(downloadingInto: outputURL.appending(path: "release"))
    let uploader =
      try upload ? NavDataStoreUploader(config: R2Configuration(), logger: logger) : nil

    if skipIfPublished, let uploader, try await uploader.isPublished(cycle: release.cycle) {
      logger.notice("Cycle \(release.cycle) is already published; nothing to do.")
      return
    }

    let built = try await NavDataStoreBuilder(logger: logger).build(
      release,
      outputLocation: outputURL
    )
    logger.notice("Wrote \(built.store.path) and \(built.manifest.path)")

    try await uploader?.upload(built, cycle: release.cycle)
  }

  private func loadRelease(downloadingInto directory: URL) async throws -> NavDataRelease {
    guard let manifest, let data else {
      return try await NavDataRelease.downloadLatest(into: directory)
    }
    return try NavDataRelease.read(
      manifestAt: URL(filePath: manifest),
      dataAt: URL(filePath: data)
    )
  }
}

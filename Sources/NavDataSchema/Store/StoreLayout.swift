public import Foundation

/**
 Where the nav data stores live.

 Nav data is replaced whole every cycle, and the replacement is a new file rather than a rewrite
 of the old one: each install writes the next *generation*, and the app switches to it by
 recording which generation is current. Nothing ever overwrites a store a container might still
 have open, and an install that never finishes leaves a file nobody points at.

 Paths are resolved from a base directory rather than assumed, so tests and the store builder can
 write real stores in a directory of their own. Only ``applicationSupport`` reaches for the app's
 own container.
 */
public struct StoreLayout: Sendable {
  private static let navDataDirectoryName = "NavData"
  private static let navStorePrefix = "navdata-"
  private static let navStoreSuffix = ".store"

  /// The layout rooted in the app's Application Support directory.
  public static var applicationSupport: Self { .init(baseDirectory: .applicationSupportDirectory) }

  /// The directory the stores live under.
  public let baseDirectory: URL

  /**
   The single store SwiftData opened by default before nav data was kept in generations.

   Retained so an install predating generations can have it removed once a generation is in
   place.
   */
  public var legacyStoreURL: URL {
    baseDirectory.appending(path: "default.store")
  }

  private var navDataDirectory: URL {
    baseDirectory.appending(path: Self.navDataDirectoryName)
  }

  /**
   Creates a layout rooted at `baseDirectory`.

   - Parameter baseDirectory: The directory to keep the stores under.
   */
  public init(baseDirectory: URL) {
    self.baseDirectory = baseDirectory
  }

  /**
   Deletes a store and the write-ahead log and shared-memory files SQLite keeps beside it.

   - Parameter url: The store to delete.
   */
  public static func removeStore(at url: URL) {
    for path in [url.path, "\(url.path)-wal", "\(url.path)-shm"] {
      try? FileManager.default.removeItem(atPath: path)
    }
  }

  /**
   The store holding a given generation of the dataset.

   - Parameter generation: Which generation to address.
   - Returns: That generation's store, whether or not it exists yet.
   */
  public func navStoreURL(generation: Int) -> URL {
    navDataDirectory.appending(path: "\(Self.navStorePrefix)\(generation)\(Self.navStoreSuffix)")
  }

  /**
   Whether a generation has a store on disk.

   - Parameter generation: Which generation to look for.
   - Returns: Whether that generation's store file is there.
   */
  public func navStoreExists(generation: Int) -> Bool {
    FileManager.default.fileExists(atPath: navStoreURL(generation: generation).path)
  }

  /// Every generation with a store on disk, in ascending order.
  public func navStoreGenerations() -> [Int] {
    let contents =
      (try? FileManager.default.contentsOfDirectory(atPath: navDataDirectory.path)) ?? []
    return
      contents
      .compactMap { name in
        guard name.hasPrefix(Self.navStorePrefix), name.hasSuffix(Self.navStoreSuffix) else {
          return nil
        }
        return Int(name.dropFirst(Self.navStorePrefix.count).dropLast(Self.navStoreSuffix.count))
      }
      .sorted()
  }

  /**
   Deletes every store except the one in use.

   Called at launch, when nothing holds a superseded generation open. An install that failed
   part-way leaves a store nobody points at, and this is what reclaims it.

   - Parameter generation: The generation to keep.
   */
  public func removeNavStores(exceptGeneration generation: Int) {
    for stale in navStoreGenerations() where stale != generation {
      Self.removeStore(at: navStoreURL(generation: stale))
    }
  }

  /// Creates the directory the stores live in, if it is not there already.
  public func createDirectories() throws {
    try FileManager.default.createDirectory(at: navDataDirectory, withIntermediateDirectories: true)
  }
}

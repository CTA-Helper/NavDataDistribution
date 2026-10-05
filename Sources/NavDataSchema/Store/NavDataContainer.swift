public import Foundation
public import SwiftData

/**
 Opens nav data stores, for the builder that writes them and the app that reads them alike.

 Every store is opened through one named configuration. SwiftData records the container's schema
 and configuration in each store it writes, so a store written through a configuration of a
 different shape reads back as one needing migration — and a store opened read-only cannot be
 migrated. Opening through this one factory is what keeps the builder's store and the app's
 reader in agreement.
 */
public enum NavDataContainer {
  /// The name of the configuration every nav data store is opened through.
  public static let configurationName = "navData"

  /**
   Opens the store holding a generation of the dataset.

   A writable container creates the store's directory first. A read-only one cannot create the
   file it is pointed at, so the generation must already be on disk.

   - Parameters:
     - layout: Where the stores live.
     - generation: Which generation to open.
     - allowsSave: Whether the container may write to the store.
   - Returns: A container over that generation's store.
   */
  public static func makeContainer(
    layout: StoreLayout,
    generation: Int,
    allowsSave: Bool
  ) throws -> ModelContainer {
    if allowsSave { try layout.createDirectories() }
    return try makeContainer(
      storeAt: layout.navStoreURL(generation: generation),
      allowsSave: allowsSave
    )
  }

  /**
   Opens the store at a given file.

   - Parameters:
     - url: The store file.
     - allowsSave: Whether the container may write to the store.
   - Returns: A container over that store.
   */
  public static func makeContainer(storeAt url: URL, allowsSave: Bool) throws -> ModelContainer {
    let configuration = ModelConfiguration(
      configurationName,
      schema: NavDataSchema.schema,
      url: url,
      allowsSave: allowsSave
    )
    return try ModelContainer(for: NavDataSchema.schema, configurations: configuration)
  }

  /**
   Opens a throwaway store held only in memory, for tests, previews and UI test runs.

   It is writable: seeding a test or a preview means inserting airports.
   */
  public static func makeInMemoryContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(
      configurationName,
      schema: NavDataSchema.schema,
      isStoredInMemoryOnly: true
    )
    return try ModelContainer(for: NavDataSchema.schema, configurations: configuration)
  }
}

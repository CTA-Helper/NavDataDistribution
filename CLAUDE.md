# NavDataDistribution

## Models

- Don't put `CodingKeys` on a SwiftData-stored type: SwiftData stores `Codable`
  composites by property name, and a rename silently round-trips back as `nil`.
  The wire keys belong on a DTO in `Wire/NavDataDocument.swift`.
- Store a value that pairs with a discriminator as an enum with associated
  values (`PublishedAltitude`, `ReferenceAltitude`), so a second altitude with no
  first, or a source naming a fix that published nothing, cannot be represented.
- Don't reference an enum with associated values from a `#Predicate` — it's
  unsupported. Anything filtered or sorted on stays a plain stored scalar.
- The package holds stored properties and what the builder needs. App-only
  behaviour — `Measurement` accessors, App Intents, view helpers — lives in the
  app as extensions.
- Any change to a model's shape changes `NavDataSchema.fingerprint`: re-pin it in
  `SchemaFingerprintTests` and publish a fresh store.

## Wire shape

- Decode the release JSON into a DTO under its bare wire names, and map it to
  the suffixed model. `CodingKeys` on a DTO is fine — a DTO is never stored.
- Normalize once, at import: a wire field that pairs a value with a
  discriminator becomes the model's enum with associated values in
  `AltitudeDescription.publishedAltitude(altitudeFt:altitude2Ft:)` and
  `ReferenceDTO.model`.
- Decode leniently where a bad record costs one leg, and strictly where it costs
  a correction: an unrecognized altitude description or role reads as a safe
  default, but a negative sequence number fails the import.

## Stores

- Open every store through `NavDataContainer` — one named configuration
  (`"navData"`) for the builder, the app and the tests alike.
- Run `sqlite3 VACUUM INTO` before shipping a store; a copied store loses
  whatever is still in its write-ahead log.
- Never await a busy `@ModelActor` from the main actor; `NavDataStoreWriter`
  reports progress through an `AsyncStream`.

# NavDataDistribution

The shared SwiftData schema for [CTA Helper][cta]'s navigation data, and the
macOS tool that builds the prebuilt store the app downloads.

- **`NavDataSchema`** (library): the `@Model` types, the wire DTOs of the
  [Navdata][navdata] release, the store writer, the store layout, and the
  manifest describing each published store.
- **`navdata-store-builder`** (executable): turns a Navdata release into
  `<effective-date>.store.lzma` and `<effective-date>.json`, and optionally
  publishes both to R2.

## Usage

```console
swift run navdata-store-builder --output out
swift run navdata-store-builder \
  --manifest manifest.json --data cta-navdata.json.gz --output out
```

`--upload` publishes the store, then its manifest, reading `R2_ACCOUNT_ID`,
`R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET_NAME` and
`R2_PUBLIC_URL` from the environment.

[cta]: https://github.com/CTA-Helper
[navdata]: https://github.com/CTA-Helper/Navdata

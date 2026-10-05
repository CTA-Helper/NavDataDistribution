# NavDataDistribution

The shared SwiftData schema for [CTA Helper][cta]'s navigation data, and the
macOS tool that builds the prebuilt store the app downloads.

## The pipeline

CTA Helper's nav data is produced in two stages, one per repository:

1. **Stage A — [Navdata][navdata]** (Python, Linux). Each AIRAC cycle it merges
   the FAA sources into `cta-navdata.json.gz` and publishes it, with a
   `manifest.json`, as a GitHub release tagged with the cycle's effective date.
2. **Stage B — this package** (Swift, macOS). It decodes that release, writes it
   into a SwiftData store, compacts and compresses the store, and publishes it
   to Cloudflare R2 with a manifest of its own.

The app downloads the stage B store and swaps it in whole, importing the JSON on
the device only when no store is published for the cycle. Stage B runs on a Mac
because SwiftData exists only on Apple platforms.

## Products

- **`NavDataSchema`** (library): the `@Model` types, the wire DTOs of the
  Navdata release, the store writer, the store layout, the container factory,
  and the manifest describing each published store. The app links it, so the
  store the builder writes and the store the app opens share one schema;
  `NavDataSchema.fingerprint` digests that schema, and the app passes over a
  store whose fingerprint is not its own.
- **`navdata-store-builder`** (executable): turns a Navdata release into
  `<effective-date>.store.lzma` and `<effective-date>.json`, and optionally
  publishes both to R2.

## Building a store locally

```console
swift run navdata-store-builder --output out
```

With no inputs the builder downloads the newest Navdata release. To build from
release files already on disk, pass both:

```console
swift run navdata-store-builder \
  --manifest manifest.json --data cta-navdata.json.gz --output out
```

Either way `out/` ends up with the store, compressed as XZ, and its manifest.
The builder writes the store through `NavDataStoreWriter`, compacts it with
`VACUUM INTO`, and reopens it read-only, exactly as the app does, to check that
every airport it wrote is there before compressing it. To try the result in the
app, serve `out/` over HTTP and launch a debug build with
`-navDataBaseURL <url>`:

```console
python3 -m http.server --directory out 8000
```

## Publishing

[`publish.yml`](.github/workflows/publish.yml) runs hourly from 10:00 to 23:00
UTC, starting an hour after Navdata's own run, and on demand with an optional
cycle to publish. It:

1. finds the newest Navdata release, or takes the dispatched cycle;
2. stops, in a Linux job before any Mac starts, if
   `<R2_PUBLIC_URL>/navdata/<cycle>.json` already answers, so an hourly run
   costs a couple of requests until there is a new cycle;
3. downloads the release, then builds and uploads the store with
   `navdata-store-builder --upload --key-prefix navdata`;
4. fetches the published manifest and store back from the public URL.

A failed run opens an issue, or comments on the open one for that cycle. Until
it is fixed the app stays on the cycle it has, or falls back to importing the
Navdata release itself.

### R2 layout

Each cycle is keyed by its effective date:

```text
navdata/
  2026-09-03.json         store manifest
  2026-09-03.store.lzma   XZ-compressed SwiftData store
  2026-10-01.json
  2026-10-01.store.lzma
```

There is no "latest" pointer. The app works out from the date which cycle is
effective, asks for that cycle's manifest by name, and walks back a cycle or two
when it is not published yet. The store goes up before its manifest, so a
manifest that answers always names a store that is there.

The manifest gives the cycle's `effective` and `expires` dates, the schema's
`schemaFingerprint` and `schemaVersion`, the store's `filename`, `bytes` and
`sha256`, and its airport, approach and fix `counts`.

### Secrets

The workflow needs these repository secrets, which `--upload` reads from the
environment:

| Secret | Purpose |
| --- | --- |
| `R2_ACCOUNT_ID` | Cloudflare account that owns the bucket |
| `R2_ACCESS_KEY_ID` | R2 API token with write access to the bucket |
| `R2_SECRET_ACCESS_KEY` | Secret for that token |
| `R2_BUCKET_NAME` | Bucket to publish into |
| `R2_PUBLIC_URL` | Public base URL of the bucket, without the key prefix |

## Development

```console
swift build
swift test
swiftlint --strict
swift format lint --strict -r Package.swift Sources Tests
```

Changing the shape of a model changes `NavDataSchema.fingerprint`: re-pin it in
`SchemaFingerprintTests`, and publish a fresh store so the app finds one that
matches. [`CLAUDE.md`](CLAUDE.md) holds the rules the models and the wire
decoding follow.

[cta]: https://github.com/CTA-Helper
[navdata]: https://github.com/CTA-Helper/Navdata

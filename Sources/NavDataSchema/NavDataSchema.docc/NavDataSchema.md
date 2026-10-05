# ``NavDataSchema``

The SwiftData schema of CTA Helper's navigation data, shared by the app and the tool that builds
the store it downloads.

## Overview

CTA Helper's nav data reaches the app in two stages. The `CTA-Helper/Navdata` repository
publishes each AIRAC cycle as a JSON release. The `navdata-store-builder` tool in this package
decodes that release into the models here, writes them into a SwiftData store with
``NavDataStoreWriter``, and publishes the compacted store alongside a ``NavDataStoreManifest``.
The app downloads that store and opens it read-only through ``NavDataContainer``.

Because both sides compile the same models, a store built on a Mac opens on a phone without
migration. ``NavDataSchema/NavDataSchema/fingerprint`` digests the schema's shape; the manifest
carries it, and the app passes over a store whose fingerprint differs from its own.

## Topics

### Models

- ``Airport``
- ``Approach``
- ``Fix``
- ``NavDataCycle``

### Stored values

- ``ColdTemperatureRestriction``
- ``Segment``
- ``AltitudeRestriction``
- ``FixRole``
- ``LegType``
- ``PublishedAltitude``
- ``ReferenceAltitude``
- ``ReferenceAltitudes``
- ``PublishedReferenceSource``

### Reading a Navdata release

- ``NavDataReleaseManifest``
- ``NavDataDocument``
- ``AirportDTO``
- ``ApproachDTO``
- ``FixDTO``
- ``ReferenceAltitudesDTO``
- ``ReferenceDTO``
- ``SequenceNumber``
- ``AltitudeDescription``

### Building and opening stores

- ``NavDataSchema/NavDataSchema``
- ``NavDataContainer``
- ``NavDataStoreWriter``
- ``StoreLayout``
- ``NavDataStoreManifest``

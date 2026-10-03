# Changelog

This file records public releases. The addon package currently declares
`0.1.0` in `packaging/brick_wild/VERSION` and its source manifest. No public
release tag or release notes have been established in this checkout.

## Unreleased

- Renamed the public facade, addon path, tools, and JSON schema namespace to
  BrickWild. Existing scripts and serialized requests/documents need migration.
- Raised the public API version to 2 for this breaking rename.
- Added public contribution and development documentation.
- Documented the incomplete asset-pack checkout and tested Godot target.
- Added the `windmill` kind: post mills, tower mills, smock mills, American
  farm windpumps and Dutch polder mills, behind one family and one set of three
  numbers. See `docs/WINDMILLS.md`. Its generator clamps those three to what the
  requested mill type can really be built as, so `describe_kind()` publishes
  `"clamps": true` for it and the envelope is the promise.
- `BuildingLibrary` gained `dimension_fields()`, `clamps()` and
  `surface_count()`, so a family whose spec names its dimensions differently
  (a windmill's are a sail span and a body) or carries more than four surfaces
  declares that in its own row instead of being special-cased by the harness.
- Added `tools/render_windmills.gd` and the `lane:windmill` suite.

Before the first public release, record the shipped version, release date,
notable changes, compatibility notes, and any migration steps here, then tag
the release. `BrickWild.API_VERSION` is a separate compatibility number; see
`README.md` and `docs/PUBLIC_API_TRANSPORT.md`.

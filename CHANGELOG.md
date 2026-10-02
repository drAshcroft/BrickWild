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

Before the first public release, record the shipped version, release date,
notable changes, compatibility notes, and any migration steps here, then tag
the release. `BrickWild.API_VERSION` is a separate compatibility number; see
`README.md` and `docs/PUBLIC_API_TRANSPORT.md`.

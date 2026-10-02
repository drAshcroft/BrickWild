# Contributing to BrickWild

Thank you for helping improve BrickWild. Please read the
[code of conduct](CODE_OF_CONDUCT.md) and [development setup](DEVELOPMENT.md).

## Before opening a pull request

1. Search existing issues and pull requests for the same problem.
2. For a bug, include the Godot version, operating system, request kind,
   seed, dimensions, and the smallest reproduction you can share.
3. Keep changes focused. Explain any generated geometry, public API, or
   serialized format change in the pull request.
4. Run the matching bounded QA lane from `DEVELOPMENT.md`. Report the command,
   exit code, and result. State clearly when missing asset packs prevent a test.
5. Keep a `.gd.uid` sidecar with any moved or added GDScript file that has one.

Changes to an existing public request field or response key need special
care. `BrickWild.API_VERSION` governs the public API contract;
`docs/PUBLIC_API_TRANSPORT.md` describes serialization. Additive fields can
retain the API version. Removing, renaming, or changing a field's meaning
requires a version decision and migration notes.

Original code contributions are submitted under the repository's Apache-2.0
license. Do not submit models, textures, fonts, or copied code without their
source, license, and redistribution rights. Third-party assets keep their own
licenses; see `README.md` and the pack READMEs.

Use the issue templates for bugs and feature requests. For sensitive security
reports, follow [SECURITY.md](SECURITY.md).

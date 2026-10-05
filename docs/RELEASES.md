# Releases: what other projects should use

This repository is edited all day, often by several agents at once. A project
that reads `C:\Projects\BigGlade` directly gets whatever state the tree is in
that minute: half a refactor, a renamed class, an installer that moved. That
has broken VoxelGames twice and drifted Dm_View's generator tag once.

So other projects do not read the working tree. They read a **release**: one
commit, frozen, verified, never rewritten.

## Make a release

```powershell
# 1. bump the version in all three places, and commit
#    packaging/brick_wild/VERSION
#    packaging/brick_wild/plugin.cfg            version="..."
#    tools/brick_wild_addon_manifest.json       "package_version"
# 2. freeze it (background it; two Godot imports, roughly 10-20 minutes)
.\tools\release_brick_wild.ps1 > artifacts\release.log 2>&1
#    or a specific commit or tag
.\tools\release_brick_wild.ps1 -Ref <commit-or-tag>
```

The tool checks the commit out into a temporary git worktree, so uncommitted
edits are never in a release. It copies in the licensed prop packs git does not
track, installs the addon, then proves the frozen copy works the way a
consumer receives it: the release's own `install.ps1` into an empty Godot
project, an editor import, and `tools/brick_wild_addon_smoke.gd` (every family
generated, meshed, instantiated and round-tripped through JSON; every prop
resource present). The frozen `project/` is imported and smoked as well. Only a
release that passed is moved into place, and only then do `LATEST` and
`current` move.

Re-running for a commit that is already released does nothing. Releasing a
different commit under an existing version is refused: bump the version.

## What a release contains

```
releases/                       git-ignored (it holds the licensed packs)
  .gdignore                     this project's Godot never imports it
  LATEST                        brick_wild-0.1.0
  current/                      junction to the newest verified release
  brick_wild-0.1.0/
    addons/brick_wild/          for projects that EMBED BrickWild (read-only)
    install.ps1                 standalone installer for that tree
    brick_wild-0.1.0.zip        the addon, Godot Asset Library layout
    project/                    for tools that RUN BrickWild
    release.json                commit, date, file count, verification
    build.log                   the Godot output of the verification
```

## Use a release from another project

**Embedding the addon** (VoxelGames). Install from the release, not the repo:

```powershell
C:\Projects\BigGlade\releases\brick_wild-0.1.0\install.ps1 -TargetProject C:\path\to\game
godot --headless --path C:\path\to\game --editor --quit    # register class_name
```

`install.ps1` needs nothing from this repository, verifies every file's hash,
removes files the previous release managed and this one dropped, and leaves
anything else in `addons/brick_wild` alone. Pin the version in the consumer's
own staging script; upgrading is changing that one string.

**Running BrickWild as a tool** (Dm_View, PaperFjord). Point `--path` at the
frozen project instead of the repository:

```
godot --headless --path C:/Projects/BigGlade/releases/brick_wild-0.1.0/project \
    --script res://tools/export_village_plan.gd -- ...
```

Use the versioned folder to pin. Use `releases/current/project` only for a
tool that should follow the newest verified release automatically.

## Retiring a release

Delete its folder. Nothing else refers to it except a consumer pinned to it.
Do not edit files inside a release; `install.ps1` refuses a release whose
files no longer match their recorded hashes.

## The addon manifest

`tools/brick_wild_addon_manifest.json` lists **directories**, not files. Every
`.gd` in a script tree ships with its `.uid`. Before this, the manifest was a
hand-kept list of 200 files and fell behind every time a family grew: the
bridge and tree families were never packaged. A new `src/` directory still
needs one line in `script_trees`; `tools/test_brick_wild_addon_installer.ps1`
fails until it has one.

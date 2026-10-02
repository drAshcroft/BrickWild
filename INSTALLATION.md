# Install BrickWild

BrickWild currently has two useful installation paths:

1. Open the source project to explore buildings in the Blueprint Studio.
2. Copy the runtime addon into an existing Godot project.

The tested engine is **Godot 4.5.2**. The standard build is sufficient; Mono,
C#, and GDExtension are not required.

## Run the Blueprint Studio

Install [Godot 4.5.2](https://godotengine.org/download/archive/4.5.2-stable/)
and Git, then clone the repository:

```powershell
git clone https://github.com/drAshcroft/BrickWild.git
cd BrickWild
godot --editor --path .
```

If `godot` is not on `PATH`, open Godot, choose **Import**, and select
`project.godot` from the checkout. Let the first import finish, then run the
project. Its main scene is `scenes/studio.tscn`.

The Studio lets you choose a building family, dimensions, style, purpose, and
seed; orbit the generated scene; and inspect the corresponding plan or
elevation. A repeated request with the same values produces the same result
within one BrickWild release.

## Install the addon in another project

> [!WARNING]
> The addon installer currently requires a complete local asset checkout. A
> fresh public clone does not contain three required prop packs. See
> [Current public preview limit](#current-public-preview-limit) before using
> these steps.

The installer has been verified on Windows. From the BrickWild repository,
preview the managed changes and then install:

```powershell
.\tools\install_big_glade_addon.ps1 `
  -TargetProject C:\path\to\YourGodotProject `
  -DryRun

.\tools\install_big_glade_addon.ps1 `
  -TargetProject C:\path\to\YourGodotProject
```

The destination must already contain `project.godot`. The installer writes the
package to exactly `res://addons/big_glade`. It can be run again to update the
managed files and leaves unrelated files in that directory untouched.

After the first installation, run the destination project once in the editor
so Godot imports models and registers the packaged `class_name` scripts:

```powershell
godot --headless --path C:\path\to\YourGodotProject --editor --quit
```

The editor plugin is intentionally empty and does not need to be enabled. The
runtime API is provided by registered GDScript classes; no autoload is needed.

### Create a building

Attach a script like this to a `Node3D`:

```gdscript
extends Node3D

func _ready() -> void:
	var request := BuildingRequest.house(
		42, &"cottage", &"smith", 9.0, 12.0, 2.6
	)
	var generated := BigGlade.generate(request)
	if generated.is_ok():
		add_child(BigGlade.instantiate(generated, false, true))
	else:
		push_error(str(generated.errors))
```

BrickWild is the repository name. `BigGlade` is the current compatibility name
of the public facade, and `addons/big_glade` is the stable package path.

Use `BigGlade.build_mesh(generated)` for an `ArrayMesh`,
`BigGlade.placement(generated)` for measured bounds and entrance data, or
`BigGlade.generate_document(request)` when the result must cross a JSON or
process boundary. See [the package README](packaging/big_glade/README.md) and
[public transport contract](docs/PUBLIC_API_TRANSPORT.md) for details.

## Current public preview limit

The public repository currently tracks the Fantasy Props MegaKit. The Dungeon
Kit, Nature Kit, and Stylized Nature MegaKit model files and license texts are
not in the public checkout. BrickWild's local catalogue and complete addon
expect all four exact packs.

Consequently, a fresh public clone can inspect the code and open the source
project, but it cannot yet:

- produce the complete distributable addon with the current installer;
- run tests that re-measure or load all catalogue assets; or
- reproduce every fully furnished scene used by maintainers.

The maintainers must publish an authorized, versioned asset bundle or a
reproducible fetch/import process before the addon can be advertised as a
one-command public installation. Do not download similarly named packs and
assume their filenames, revisions, or licenses match the catalogue.

## Troubleshooting

### `Identifier not declared`

Run one editor import pass so Godot registers every `class_name`:

```text
godot --headless --path . --editor --quit
```

### The installer reports a missing source file

The checkout does not have the complete prop-pack closure, or a required
runtime file is absent. Review the public preview limit above. The installer
stops rather than creating a partial package.

### A newer Godot version reports script or rendering differences

Reproduce with Godot 4.5.2 first. That is the only version currently covered
by the project test lanes.

### macOS or Linux

The source project and direct Godot commands are platform-neutral, but the
PowerShell installer has only been verified on Windows. PowerShell 7 may work
elsewhere; it is not yet a supported installation path.

For source builds, tests, rendering, and contribution workflow, continue with
[Developing BrickWild](DEVELOPMENT.md).

# BrickWild Godot addon

BrickWild generates deterministic churches, castles, furnished houses, medieval
shops/civic buildings, grand hotels, and temples from a seed and size request. The
tested target is Godot 4.5.2; newer versions have not been verified.

Install the addon at exactly `res://addons/big_glade`. From the BrickWild source
repository, the Windows-tested installer is:

```powershell
.\tools\install_big_glade_addon.ps1 -TargetProject C:\path\to\GodotProject
```

The source checkout must contain the dungeon, nature, wild, and fantasy prop
packs. A fresh public clone currently lacks the first three; see the root
`DEVELOPMENT.md` for this release blocker.

Run the project once as an editor after first installation so Godot imports the
prop models and registers the addon's `class_name` scripts:

```powershell
godot --headless --path C:\path\to\GodotProject --editor --quit
```

The runtime API does not require an autoload. The editor plugin is intentionally
empty, so enabling it is optional.

```gdscript
var request := BuildingRequest.house(42, &"cottage", &"smith", 9.0, 12.0, 2.6)
var generated := BigGlade.generate(request)
if generated.is_ok():
	var placement: Dictionary = BigGlade.placement(generated)
	var building: Node3D = BigGlade.instantiate(generated, false, true)
	add_child(building)
```

For a workplace, use for example
`BuildingRequest.shop(42, &"blacksmith", &"longhall", 11.0, 14.0, 2.8)`.
For the palatial landmark hotel, use
`BuildingRequest.hotel(42, &"grand_budapest", 48.0, 24.0, 3.6)`.

Use `BigGlade.build_mesh(generated)` when only an `ArrayMesh` is needed. Calling
`BigGlade.generate(request)` produces the family representation without first
creating scene nodes. `placement()` returns measured bounds, footprint and the
local -Z front; the third `instantiate()` argument enables shell-only collision.

The installer owns only files listed in `.big_glade_install_manifest.json`.
Updating the addon removes obsolete files from that prior managed set while
leaving unrelated files under `addons/big_glade` untouched.

The four local Quaternius packs (Fantasy Props MegaKit, Dungeon Kit, Nature Kit,
and Stylized Nature MegaKit) identify CC0 terms in their local license texts.
License texts for the ignored packs are not in the public checkout. Verify the
exact pack provenance and include those texts before redistribution. The
installer copies the local catalogue's complete asset closure and requires
those packs in the source checkout.

`example.gd` is a ready-to-attach Node3D script that creates a furnished smith's
cottage. `PUBLIC_API_TRANSPORT.md` documents lossless request/document JSON,
structured QA, seeded compatibility, and the repository's headless export tools.
The installed runtime also includes world-family buildings and village planning.
Each runtime script ships with its UID sidecar; source Studio and test scripts
are excluded. The package has no dependency on the source project's directories.

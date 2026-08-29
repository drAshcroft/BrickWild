# BigGlade Godot addon

BigGlade generates deterministic churches, castles, furnished houses, medieval
shops/civic buildings, grand hotels, and temples from a seed and size request. It targets
Godot 4.5 or newer.

Install the addon at exactly `res://addons/big_glade`. From the BigGlade source
repository, the supported installer is:

```powershell
.\tools\install_big_glade_addon.ps1 -TargetProject C:\path\to\GodotProject
```

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

The bundled Fantasy Props MegaKit models are CC0 by Quaternius. Their original
license and README are included under `assets/props/fantasy`.

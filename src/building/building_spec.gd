class_name BuildingSpec
extends RefCounted
## Fully describes one generated building. Everything is derived from `rng`
## so the same seed always rebuilds the identical structure.

var seed: int
var rng: RandomNumberGenerator

# Style
var style: StringName            # &"european" | &"east_asian"
var subtype: String              # e.g. "townhouse", "barn", "tower" / "pagoda", "teahouse"

# Footprint (units = meters)
var width: float                 # along X
var depth: float                 # along Z
var floors: int
var floor_height: float
var roof_pitch: float            # radians-ish multiplier, per floor height

# Walls
var wall_material: int           # index into style palette
var timber_color: Color
var wall_color: Color
var plaster_worn: float          # 0..1, chance of exposed timber pattern density

# Roof
var roof_type: StringName        # &"gable", &"hip", &"hipped_gable", &"tiered", &"pyramidal"
var roof_overhang: float
var roof_color: Color
var roof_tiers: int              # >1 for pagodas

# Details
var chimney: bool
var dormer_count: int
var porch: bool
var upturned_eaves: float        # 0..1, east-asian eave curvature amount
var window_cols: int
var door_side: int               # 0=N 1=E 2=S 3=W

func _init(p_seed: int) -> void:
	seed = p_seed
	rng = RandomNumberGenerator.new()
	rng.seed = seed

func randf(a := 0.0, b := 1.0) -> float:
	return rng.randf_range(a, b)

func randi_range(a: int, b: int) -> int:
	return rng.randi_range(a, b)

func pick(arr: Array):
	return arr[rng.randi_range(0, arr.size() - 1)]

class_name TimberHallGenerator
extends RefCounted
## Deterministic generator for WLD-008 hall archetypes.

static func generate(kind: StringName, seed: int, width: float, length: float,
		height: float) -> TimberHallSpec:
	var spec := TimberHallSpec.new()
	spec.kind = kind
	spec.seed = seed
	spec.width = width
	spec.length = length
	spec.height = height
	spec.wings = kind == &"phoenix_pavilion"
	if spec.wings:
		spec.wing_w = maxf(8.0, width * 0.2)
		# Keep the pond wholly beyond the front stair, leaving a readable water
		# apron between the viewer and the hall rather than burying it under the plinth.
		var water_depth: float = maxf(length * 0.75, 5.0)
		var stair_front: float = -length / 2.0 - 4.81
		spec.water = Rect2(Vector2(-width * 0.62, stair_front - water_depth),
			Vector2(width * 1.24, water_depth))
	spec.platform_h = maxf(PLATFORM_HEIGHT, 0.8)
	spec.wall_t = clampf(height * 0.035, 0.35, 0.6)
	spec.column_r = clampf(height * 0.021, 0.32, 0.5)
	spec.column_h = height * 0.48
	spec.roof_overhang = maxf(width * 0.09, spec.column_h * 0.3)
	spec.roof_rise = maxf(height * 0.5, 6.0)
	spec.dais_h = clampf(height * 0.06, 0.6, 1.2)
	spec.image_h = clampf(height * 0.22, 2.8, 5.0)
	spec.columns = TimberHallGeometry.column_records(spec)
	spec.windows = TimberHallGeometry.window_records(spec)
	spec.variant_name = "The Phoenix Pavilion" if spec.wings else "The Great Hall of the East"
	return spec

const PLATFORM_HEIGHT := 0.8

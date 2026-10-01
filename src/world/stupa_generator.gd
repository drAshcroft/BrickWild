class_name StupaGenerator
extends RefCounted
## WLD-017: Sanchi-derived solid mound and circumambulatory paths.

const FAMILY := &"stupa"
const KIND := &"saints_mound"


static func generate(kind: StringName, seed: int, width: float, length: float,
		height: float) -> StupaSpec:
	var spec := StupaSpec.new()
	spec.seed = seed
	spec.width = width
	spec.length = length
	spec.height = height
	spec.variant_name = "Saint's Mound"
	# Keep the proportions stable at the canonical 40 x 40 x 17 scale.
	var scale := minf(width, length) / 40.0
	spec.dome_radius = 8.0 * scale
	spec.dome_base_y = 4.0 * scale
	spec.dome_rise = minf(8.0 * scale, height - 9.0 * scale)
	spec.drum_radius = 10.0 * scale
	spec.drum_y = spec.dome_base_y
	spec.ground_ring_inner = 11.0 * scale
	spec.ground_ring_outer = 14.0 * scale
	spec.drum_ring_inner = 8.4 * scale
	spec.drum_ring_outer = 10.0 * scale
	spec.torana_radius = minf(17.0 * scale, minf(width, length) * 0.46)
	return spec

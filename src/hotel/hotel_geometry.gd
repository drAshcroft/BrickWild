class_name HotelGeometry
extends RefCounted
## Canonical landmark proportions shared by the builder and hotel QA.

const MIN_WIDTH := 30.0
const MAX_WIDTH := 80.0
const MIN_LENGTH := 16.0
const MAX_LENGTH := 42.0
const MIN_FLOOR_H := 3.0
const MAX_FLOOR_H := 4.5
const TOWER_INSET_FRACTION := 0.075
const CUPOLA_R_FRACTION := 0.042
const FACADE_PROJECTION := 0.28
## How far the balconies and entrance canopy stand out beyond the facade plane.
const FACADE_REACH := 1.3
## Cupola finial height above the wall head.
const FINIAL_RISE := 6.1


static func wall_top(spec: HotelSpec) -> float:
	return spec.height * spec.storeys


static func centre_width(spec: HotelSpec) -> float:
	return spec.width * spec.centre_fraction


static func tower_x(spec: HotelSpec) -> float:
	return spec.width * (0.5 - TOWER_INSET_FRACTION)


static func cupola_radius(spec: HotelSpec) -> float:
	return clampf(spec.width * CUPOLA_R_FRACTION, 1.35, 2.5)


static func front_z(spec: HotelSpec) -> float:
	return -spec.length * 0.5 - FACADE_PROJECTION


static func total_height(spec: HotelSpec) -> float:
	return wall_top(spec) + spec.roof_rise + 4.0


## The roof the hotel builder lays, in its own frame: the ridge runs along X, so
## the house-roof frame is turned a quarter turn, and the origin is the wall
## head. HotelBuilder emits from this and the blueprint reads it.
static func roof_layout(spec: HotelSpec) -> Dictionary:
	return {"transform": Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(0, wall_top(spec), 0)),
		"faces": RoofShape.faces(spec.length + 1.0, spec.width + 1.0, spec.roof_rise),
		"rise": spec.roof_rise}


static func facade_bay_positions(spec: HotelSpec) -> Array[float]:
	var out: Array[float] = []
	var margin := maxf(2.2, spec.width * 0.045)
	var run := spec.width - margin * 2.0
	for i in range(spec.facade_bays):
		out.append(-run * 0.5 + run * (float(i) + 0.5) / spec.facade_bays)
	return out

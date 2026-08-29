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


static func facade_bay_positions(spec: HotelSpec) -> Array[float]:
	var out: Array[float] = []
	var margin := maxf(2.2, spec.width * 0.045)
	var run := spec.width - margin * 2.0
	for i in range(spec.facade_bays):
		out.append(-run * 0.5 + run * (float(i) + 0.5) / spec.facade_bays)
	return out

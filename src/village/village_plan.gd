class_name VillagePlan
extends RefCounted
## The one thing everyone agrees about, exactly as HousePlan is for a house.
## SitePlanner/LotPlanner/Programmer fill it, VillageDresser adds props and
## plants to it, VillageBuilder/VillageAssembler read it to make a mesh, and
## VillageQA judges it in metres and polygons -- WITHOUT loading a model.
## VILLAGES §11.
##
## Plain data, like HousePlan: nothing here decides anything. No scene tree
## node and no renderable surface type belongs in this file -- the whole
## point of a plan is that it can be built, checked and compared without a
## renderer.

var spec: VillageSpec

## The ground the village stands on, in metres, centred on the origin. The
## SITE PLANNER owns this: `VillageSpec.site` is only a rough envelope sized
## before any road exists, and planning must not write to the spec (the
## purity rule), so the planned footprint lives here.
var site: Rect2 = Rect2()

## The slot reserved for the landmark (church, temple or keep) BEFORE any
## house lot is cut -- VILLAGES §2.1, "the site planner puts the landmark for
## it first, because everything else is arranged around it". Empty until the
## planner has run. {"poly": PackedVector2Array, "kind": StringName,
## "front": PackedVector2Array (the edge facing the common)}
var landmark_site: Dictionary = {}

## A road is a polyline with a class. {"points": PackedVector2Array,
## "class": StringName ("through"/"street"/"lane"/"path"/"track"),
## "width": float}
var roads: Array[Dictionary] = []

## A lot is a polygon with a road frontage. {"poly": PackedVector2Array,
## "front": PackedVector2Array (the two points of the frontage edge),
## "road": int (index into roads, -1 if none yet), "class": StringName
## (VIL-004's lot class: cottage/townhouse/shop/farm/church/manor),
## "landmark": bool (true for the ONE lot that is the reserved landmark
## slot -- the church stands on the ground the site planner kept for it, so
## that lot alone is allowed to overlap `landmark_site`)}
var lots: Array[Dictionary] = []

## A building on a lot. {"lot": int (index into `lots`), "request":
## BuildingRequest, "placement": Dictionary (BrickWild.placement() result --
## the MEASURED bounds/footprint/door the lot was sized from), "transform":
## Transform3D (the scene root's placement: rotated so the building's local
## -Z faces its lot's front edge), "door": Vector3 (the placement door in
## WORLD space, i.e. `transform * placement["door"]`), "kind": StringName
## (the request's family) and "class": StringName (the lot class)}
var buildings: Array[Dictionary] = []

## A common/green/square. {"poly": PackedVector2Array, "kind": StringName
## ("common"/"square")}
var commons: Array[Dictionary] = []

## The edge of the settlement. Empty polygon when `enclosure == none`.
var enclosure: PackedVector2Array = PackedVector2Array()
## Fraction of authored enclosure retained by an external site brief. Native
## villages keep the historical complete edge.
var enclosure_kept_fraction: float = 1.0

## Where a road crosses the enclosure. {"pos": Vector2, "road": int}.
## Named `gate_crossings` (not `gates`) because `gates()` below is the typed
## accessor the acceptance criteria asks for, and GDScript does not allow a
## method and a field to share a name.
var gate_crossings: Array[Dictionary] = []

## A water body on the site. {"poly": PackedVector2Array, "kind": StringName
## ("pond"/"stream"/"river"/"coast")}
var water: Array[Dictionary] = []

## Persistent bridges and fords, after the final roads have been trimmed.
## {road:int, water:int, water_kind:StringName, kind:StringName (bridge/ford),
## points:PackedVector2Array (the route including bends), width:float}.
## Separate from dressing: clearing props must never erase a crossing.
var water_crossings: Array[Dictionary] = []

## Strip fields, orchards, pasture outside the enclosure. {"poly":
## PackedVector2Array, "kind": StringName ("field"/"orchard"/"pasture")}
var fields: Array[Dictionary] = []

## Non-plant dressing: barrels, benches, stalls, fences, the well, and so
## on. {"key": String, "pos": Vector2, "yaw": float, "host": int (building
## index, -1 for the common/road), "zone": Rect2}
var props: Array[Dictionary] = []

## Trees, hedges and ground cover. {"key": String, "pos": Vector2,
## "canopy": float, "trunk": float}
var plants: Array[Dictionary] = []


func _init(p_spec: VillageSpec = null) -> void:
	spec = p_spec


# --------------------------------------------------------------- road helpers

func roads_of_class(cls: StringName) -> Array[int]:
	var out: Array[int] = []
	for i in range(roads.size()):
		if roads[i]["class"] == cls:
			out.append(i)
	return out


# ---------------------------------------------------------------- lot helpers

## The lot a building sits on, or -1 if the building index is out of range.
func lot_of_building(building: int) -> int:
	if building < 0 or building >= buildings.size():
		return -1
	return int(buildings[building]["lot"])


# ----------------------------------------------------------- building helpers

func buildings_of_kind(kind: StringName) -> Array[int]:
	var out: Array[int] = []
	for i in range(buildings.size()):
		if buildings[i]["kind"] == kind:
			out.append(i)
	return out


func has_kind(kind: StringName) -> bool:
	return not buildings_of_kind(kind).is_empty()


# --------------------------------------------------------------- gate helpers

## All gate positions, or the gates on one road when `road` >= 0.
func gates(road: int = -1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for g in gate_crossings:
		if road < 0 or int(g["road"]) == road:
			out.append(g)
	return out


## True once the site planner has reserved the landmark slot.
func landmark_reserved() -> bool:
	return landmark_site.has("poly") and (landmark_site["poly"] as PackedVector2Array).size() >= 3


# ---------------------------------------------------------------------- purity

## True when `other` describes the same village: same spec inputs and every
## list equal element-for-element. This is the whole of the purity rule --
## `VillageQA.ScaleCheck` plans the same spec twice and asserts this.
func equals(other: VillagePlan) -> bool:
	if other == null:
		return false
	if not _spec_equal(spec, other.spec):
		return false
	if site != other.site:
		return false
	if not _value_equal(landmark_site, other.landmark_site):
		return false
	return (
		_array_of_dict_equal(roads, other.roads)
		and _array_of_dict_equal(lots, other.lots)
		and _array_of_dict_equal(buildings, other.buildings)
		and _array_of_dict_equal(commons, other.commons)
		and _poly_equal(enclosure, other.enclosure)
		and is_equal_approx(enclosure_kept_fraction, other.enclosure_kept_fraction)
		and _array_of_dict_equal(gate_crossings, other.gate_crossings)
		and _array_of_dict_equal(water, other.water)
		and _array_of_dict_equal(water_crossings, other.water_crossings)
		and _array_of_dict_equal(fields, other.fields)
		and _array_of_dict_equal(props, other.props)
		and _array_of_dict_equal(plants, other.plants)
	)


static func _spec_equal(a: VillageSpec, b: VillageSpec) -> bool:
	if a == null or b == null:
		return a == b
	return (
		a.seed == b.seed and a.population == b.population and a.culture == b.culture
		and a.purpose == b.purpose and is_equal_approx(a.wealth, b.wealth)
		and a.compact_display == b.compact_display
		and a.enclosure == b.enclosure and a.water == b.water
		and a.households == b.households and a.form == b.form
		and a.variant_name == b.variant_name and a.site == b.site
		and _array_of_dict_equal(a.programme, b.programme)
		and a.site_brief == b.site_brief and a.regime == b.regime
		and a.tongue == b.tongue and a.source_culture == b.source_culture
		and a.plant_palette == b.plant_palette
		and _value_equal(a.kept_buildings, b.kept_buildings)
		and is_equal_approx(a.enclosure_kept_fraction, b.enclosure_kept_fraction)
		and _value_equal(a.terrain_envelope, b.terrain_envelope)
		and is_equal_approx(a.requested_site_m, b.requested_site_m)
	)


static func _array_of_dict_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if not _value_equal(a[i], b[i]):
			return false
	return true


static func _value_equal(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for k in a.keys():
			if not b.has(k):
				return false
			if not _value_equal(a[k], b[k]):
				return false
		return true
	if a is PackedVector2Array and b is PackedVector2Array:
		return _poly_equal(a, b)
	if a is BuildingRequest and b is BuildingRequest:
		return _request_equal(a, b)
	if (a is float or a is int) and (b is float or b is int):
		return is_equal_approx(float(a), float(b))
	return a == b


## Two `BuildingRequest`s describe the same building. Compared field by
## field, not by reference: a plan made twice from the same spec holds two
## distinct request objects, and `equals()` is about the village, not about
## object identity.
static func _request_equal(a: BuildingRequest, b: BuildingRequest) -> bool:
	return (
		a.kind == b.kind and a.seed == b.seed and a.style == b.style
		and a.purpose == b.purpose and a.storeys == b.storeys
		and is_equal_approx(a.width, b.width) and is_equal_approx(a.length, b.length)
		and is_equal_approx(a.height, b.height)
	)


static func _poly_equal(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if not a[i].is_equal_approx(b[i]):
			return false
	return true

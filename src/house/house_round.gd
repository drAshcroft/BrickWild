class_name HouseRound
extends RefCounted
## HS-ROUNDHOUSE: the `roundhouse` (formerly `mud_hut`) is ONE round room under a
## cone of thatch.
##
##   - the plan is a single room whose floor is a regular 12-gon (a room outline,
##     the same device a castle's drum tower uses), inside a ring of thick wall
##     (the style row's `wall_t`, 0.62 m);
##   - the roof is a true cone over that ring: 12 facets running from the eave to
##     an apex, lowered so the thatch rests on the OUTER edge of the wall head
##     and hangs past it (`eave_drop`); the apex carries a smoke vent, a hole in
##     the thatch with a collar round it and a small hat on posts over it;
##   - the fire burns on the middle of the floor, under that vent: a ring of
##     kerb stones round a bed of ash (`plan.roundhouse["hearth"]`). There is no
##     chimney and no wall hearth;
##   - one low door in the front facet and a few small, high windows.
## A roundhouse that carries a trade, or belongs to a shop or a world family, is
## left to the ordinary (rectangular) planner and keeps its old square cone.

const BASE_HOUSE_SPEC := preload("house_spec.gd")
const SIDES := 12
## Diameter of the outside of the wall ring. Never narrower than a door and a pier
## either side will fit on one facet.
const MIN_D := 8.0
const MAX_D := 10.0
const DOOR_W := 0.9
const WINDOW_W := 0.5
const WINDOW_SILL := 1.15
const WINDOW_HEAD := 1.75
## Kerb of the fire, a square of stones on the floor.
const HEARTH_SIZE := 1.2
const KEEP_CLEAR := 0.3
## The smoke vent: a round hole at the apex, the collar of thatch bundles round
## it, and the hat on four posts over it.
const VENT_R := 0.38
const VENT_SIDES := 12
const COLLAR_R := 0.62
const COLLAR_H := 0.3
const HAT_R := 0.95
const HAT_H := 0.4
## Highest the vent stands above the apex of the cone (collar + posts + hat).
const VENT_TOP := 0.7


static func applies(spec: HouseSpec, world_family: StringName = &"") -> bool:
	return plain(spec, world_family) and spec.storeys <= 1


## A plain roundhouse before its size is brought to a hut's: `clamp_size` asks
## this, because it is what makes the storeys one.
static func plain(spec: HouseSpec, world_family: StringName = &"") -> bool:
	return spec != null and spec.style == &"roundhouse" \
		and spec.get_script() == BASE_HOUSE_SPEC and spec.trade == &"none" \
		and world_family == &"" \
		and not spec.has_method("room_program") and not spec.has_method("custom_room_rects") \
		and not spec.has_method("landmark_footprint")


## Is this plan a round hut: its one room carries the flag `layout` wrote.
static func plan_applies(plan: HousePlan) -> bool:
	return plan != null and plan.rooms.size() >= 1 \
		and bool(plan.rooms[0].get("round_walls", false))


## Bring a request to a roundhouse's proportions: one storey, a circle (width ==
## length == the diameter of the outside of the wall), no cellar. Pure
## arithmetic: no random draw. Said once, here, so the planner, the roof and the
## bound agree on the diameter.
static func clamp_size(spec: HouseSpec) -> void:
	if not plain(spec):
		return
	var d := clampf(minf(spec.width, spec.length), MIN_D, MAX_D)
	spec.width = d
	spec.length = d
	spec.storeys = 1
	spec.cellars = 0


## The clear floor: a regular 16-gon with a facet centred on -Z (the front), so
## the front door sits in the middle of a facet and not on a corner.
static func outline(spec: HouseSpec) -> PackedVector2Array:
	var t := HouseGeometry.wall_thickness(spec)
	var rv := spec.width * 0.5 - t / cos(PI / float(SIDES))
	var out := PackedVector2Array()
	for k in range(SIDES):
		var a := -PI * 0.5 + (float(k) + 0.5) * TAU / float(SIDES)
		out.append(Vector2(cos(a), sin(a)) * rv)
	return out


## Distance from the centre to the middle of a floor facet (the inside face of the
## wall).
static func apothem(spec: HouseSpec) -> float:
	var t := HouseGeometry.wall_thickness(spec)
	return spec.width * 0.5 * cos(PI / float(SIDES)) - t


## The one room. Returns false (adds nothing) when the request is not a plain
## roundhouse.
static func layout(p: HousePlan, spec: HouseSpec) -> bool:
	if not applies(spec, p.world_family):
		return false
	var poly := outline(spec)
	var functions: Array[StringName] = [&"entry", &"circulation", &"dining",
		&"common_living", &"cooking"]
	p.rooms.append({"kind": &"hall", "rect": Poly.bounding_rect(poly), "outline": poly,
		"storey": 0, "wall_thickness": HouseGeometry.wall_thickness(spec),
		"round_walls": true, "domestic_role": &"living_hall",
		"domestic_functions": functions, "meal_room": true, "shared_cooking": true,
		"domestic_layout_storey": 0})
	p.domestic_layout = {
		"status": &"planned", "style": spec.style, "requested_rooms": 1,
		"planned_rooms": 1, "ground_activities": [&"hall"],
		"merged_activities": [&"kitchen", &"bedroom"], "capacity_expanded": false,
		"omitted_rooms": 0, "omitted_activities": [], "rejected_candidates": [],
		"reason": "", "hall_role": &"living_hall", "shared_cooking": true,
		"roundhouse": true,
	}
	return true


## The door and the windows, on the facets of the ring. Positions are on the
## INSIDE face of the wall and `normal` points out of it, which is how every
## other exterior opening is recorded.
static func plan_openings(p: HousePlan, spec: HouseSpec) -> void:
	var inner := apothem(spec)
	# facet k is centred at angle -90 + k * 22.5 degrees; k == 0 is the front.
	p.doors.append({"a": 0, "b": -1, "pos": _facet_pos(inner, 0), "normal": _facet_normal(0),
		"width": DOOR_W, "exterior": true, "front": true, "storey": 0})
	for k in [2, 4, 8, 10]:
		p.windows.append({"room": 0, "pos": _facet_pos(inner, k), "normal": _facet_normal(k),
			"width": WINDOW_W, "sill": WINDOW_SILL, "head": WINDOW_HEAD, "storey": 0})


static func _facet_normal(k: int) -> Vector2:
	var a := -PI * 0.5 + float(k) * TAU / float(SIDES)
	return Vector2(cos(a), sin(a))


static func _facet_pos(inner: float, k: int) -> Vector2:
	return _facet_normal(k) * inner


## After the furnisher: nothing hangs from an open cone (a chandelier needs a
## ceiling to hang from, and this roof is the ceiling), and the household sleeps
## at the wall. The furnisher's wall rule walks the sides of a rectangle and
## finds no facet of a sixteen-sided room long enough for a bed, so the bed is
## seated here, head to the wall on the rear, east or west facet (never the
## door's or a window's).
const BED_KEY := "Bed_Twin1"


static func seat(plan: HousePlan) -> void:
	if not plan_applies(plan):
		return
	_seat_bed(plan)
	for i in range(plan.furniture.size() - 1, -1, -1):
		if str(plan.furniture[i].get("key", "")) == "Chandelier":
			plan.furniture.remove_at(i)
			# `host` and `support` rows are indices into the list: close the gap.
			for item in plan.furniture:
				var h := int(item.get("host", -1))
				if h == i:
					item["host"] = -1
				elif h > i:
					item["host"] = h - 1


static func _seat_bed(plan: HousePlan) -> void:
	for f in plan.furniture:
		if str(f.get("cat", "")) == "bed":
			return
	var inner := apothem(plan.spec)
	var order: Array = [6, 3, 9] if posmod(plan.spec.seed, 2) == 0 else [3, 9, 6]
	var depth := PropCatalog.footprint(BED_KEY).y
	# the largest bed that fits, as close to the wall as it will go
	for scale in HouseFurnishGeometry.scales(BED_KEY):
		for setback in [0.0, 0.1, 0.2, 0.3, 0.45]:
			for k: int in order:
				var inward := -_facet_normal(k)
				var centre := _facet_pos(inner, k) 					+ inward * (depth * float(scale) * 0.5 + HouseGeometry.WALL_GAP + float(setback))
				var yaw := HouseFurnishGeometry.yaw_facing(inward)
				for side in [1.0, -1.0]:
					var cand := HouseFurnishGeometry.candidate(BED_KEY, centre, yaw, side, float(scale))
					cand["activity_group"] = "sleep"
					if not HouseFurnishGeometry.inside_candidate(plan, 0, cand) 							or _bed_collides(plan, cand):
						continue
					var blocked: Array[Rect2] = []
					var zones: Array[Rect2] = []
					HouseFurnishGeometry.commit(plan, 0, cand, blocked, zones)
					# the bed is there now: its two complaints are answered
					var rows: Array = plan.compromises.get(0, [])
					for gone in ["activity:sleep", "activity:sleep:bed"]:
						rows.erase(gone)
					return


static func _bed_collides(plan: HousePlan, cand: Dictionary) -> bool:
	var body := Rect2(cand["rect"])
	var zone := Rect2(cand["zone"])
	for z in plan.zones:
		if Rect2(z["rect"]).intersects(body):
			return true
	for f in plan.furniture:
		# mounted pieces and things stood on a host do not take floor
		if bool(f.get("mounted", false)) or int(f.get("host", -1)) >= 0:
			continue
		var other := Rect2(f["rect"])
		if other.intersects(body) or other.intersects(zone):
			return true
	for d in plan.doors:
		if HouseGeometry.door_clear_rect(d, 1.0).intersects(body) 				or HouseGeometry.door_clear_rect(d, -1.0).intersects(body):
			return true
	return false


## After the openings: the fire on the middle of the floor, the vent over it,
## and the floor round the fire kept clear. No chimney, no wall hearth, no focus
## in a wall.
static func prepare(p: HousePlan, spec: HouseSpec) -> void:
	p.roundhouse = {}
	if not plan_applies(p):
		return
	p.hearth = {}
	p.focus = {}
	spec.chimney = false
	spec.dormers = false
	var kerb := Rect2(-Vector2.ONE * HEARTH_SIZE * 0.5, Vector2.ONE * HEARTH_SIZE)
	p.zones.append({"room": 0, "rect": kerb.grow(KEEP_CLEAR), "why": "open hearth"})
	p.roundhouse = {"room": 0, "hearth": kerb, "smoke": Vector2.ZERO, "vent": true,
		"sides": SIDES}


## How far the cone's frame is dropped below the wall head so the thatch rests on
## the OUTER edge of the wall and hangs past it, instead of floating a hand above
## it. `rise` is the nominal rise (wall head to apex); the apex stays there,
## because the cone is built `drop` taller from `drop` lower.
static func eave_drop(spec: HouseSpec, rise: float) -> float:
	var half := spec.width * 0.5
	var eave := half + HouseGeometry.roof_span_out(spec)
	var q := 1.0 - half / eave
	return maxf((rise * q - RoofShape.DEPTH * 0.5) / (1.0 - q), 0.0)


## The smoke vent as a roof opening, in the roof's own local XZ frame, whose
## origin is the plan centre (the roof of a round hut is not turned).
static func vent_opening(plan: HousePlan) -> Dictionary:
	if not plan_applies(plan) or plan.roundhouse.is_empty() \
			or not bool(plan.roundhouse.get("vent", false)):
		return {}
	var poly := PackedVector2Array()
	for k in range(VENT_SIDES):
		var a := TAU * float(k) / float(VENT_SIDES)
		poly.append(Vector2(cos(a), sin(a)) * VENT_R)
	return {"id": "roundhouse_vent", "kind": &"open", "storey": 0, "face": -1,
		"room": 0, "polygon": poly}

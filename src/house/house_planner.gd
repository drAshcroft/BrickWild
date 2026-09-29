class_name HousePlanner
extends RefCounted
## Turns a HouseSpec into rooms, doors and windows.
##
## Three passes, in the order an architect would take them:
##   1. SUBDIVIDE  the interior into rooms, splitting the biggest room each
##      time, so the rooms come out roughly even rather than one hall and five
##      cupboards.
##   2. NAME them, by how public they are. The front of the house is public and
##      the back is private, which is the oldest rule in domestic planning: the
##      hall takes the front door, the kitchen sits next to it, bedrooms go as
##      far from the door as the plan allows, and whatever is left over and too
##      small to live in becomes the store.
##   3. CONNECT them. Doors go on a spanning tree rooted at the hall, expanded
##      through public rooms first, so a bedroom ends up a leaf and nobody has
##      to walk through someone's bedroom to reach the kitchen.
##
## Then windows, on exterior walls only, enough of them to light each room.
## Every one of those rules is checked afterwards by HousePlanCheck -- this
## file tries to build it right, that file refuses to believe it did.

static func plan(spec: HouseSpec) -> HousePlan:
	var p := HousePlan.new()
	p.spec = spec
	HousePlanRooms.subdivide(p, spec)
	HousePlanRooms.name_rooms(p, spec)
	HousePlanOpenings.place_doors(p, spec)
	HousePlanOpenings.place_windows(p, spec)
	HousePlanOpenings.glaze_remaining(p, spec)
	demote_unlit(p)
	if spec.storeys > 1:
		HousePlanLevels.clone_upper_storeys(p, spec)
	if spec.cellars > 0:
		HousePlanLevels.dig_cellars(p, spec)
	HousePlanFeatures.choose_hearth(p, spec)
	HousePlanFeatures.choose_focus(p, spec)
	_reserve_upper_flue(p, spec)
	return p


## The hearth fixes the ground-supported stack after the ground windows are
## fitted. Reserve that same flue on every upper facade, then restore daylight
## through the usual opening fitter. It is never moved away from its fire.
static func _reserve_upper_flue(p: HousePlan, spec: HouseSpec) -> void:
	if not spec.chimney or spec.storeys <= 1 or p.hearth_room() < 0:
		return
	var affected: Array[int] = []
	for i in range(p.windows.size() - 1, -1, -1):
		var w := p.windows[i]
		if flue_blocks(p, w["pos"], w["normal"], HousePlan.record_storey(w), float(w["width"])):
			var room := int(w["room"])
			if not affected.has(room):
				affected.append(room)
			p.windows.remove_at(i)
	if not affected.is_empty():
		HousePlanOpenings.place_windows(p, spec, affected)
		HousePlanOpenings.glaze_remaining(p, spec, affected)


static func flue_blocks(p: HousePlan, pos: Vector2, normal: Vector2,
		storey: int, width := HouseGeometry.WINDOW_W) -> bool:
	if storey <= 0 or not p.spec.chimney or p.hearth_room() < 0:
		return false
	var tangent := Vector2(normal.y, -normal.x).abs()
	var centre := pos + normal * (HouseGeometry.wall_thickness(p.spec) + 0.05)
	var size := tangent * (width + 0.25) + normal.abs() * 0.5
	return HouseGeometry.chimney_rect(p).intersects(Rect2(centre - size * 0.5, size))


## A room that could not be given a window is not a room anybody lives in.
##
## _demote_windowless catches the rooms with no outside wall at all; this one
## catches the rest -- a kitchen whose only stretch of outside wall is taken up
## by the back door has nowhere left to put a window, and calling it a kitchen
## anyway would leave the daylight check failing forever. It becomes the store,
## and the store's kind goes to a room that does have daylight.
static func demote_unlit(p: HousePlan, only: Array[int] = []) -> void:
	var rooms: Array[int] = only if not only.is_empty() else HousePlanRooms.all_rooms(p)
	for i in rooms:
		if not HouseGeometry.is_habitable(p.kind_of(i)) or not p.windows_of(i).is_empty():
			continue
		var swap := -1
		for j in rooms:
			if p.kind_of(j) == &"store" and not p.windows_of(j).is_empty() 					and HouseGeometry.room_suits(p, j, p.kind_of(i)):
				swap = j
				break
		if swap >= 0:
			var mine: StringName = p.kind_of(i)
			p.rooms[i]["kind"] = &"store"
			p.rooms[swap]["kind"] = mine
		else:
			p.rooms[i]["kind"] = &"store"

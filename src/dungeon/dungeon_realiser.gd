class_name DungeonRealiser
extends RefCounted
## A dungeon planner's plan in, a realised dungeon out: every room in metres,
## with its carve programme, its doorways placed along their walls, and the
## sockets a consumer dresses.
##
## The planner (C:\Projects\dungeon, tools/export_plan.gd) says which rooms
## touch, on which wall, behind which lock. It does not say how big a cell is,
## how high a ceiling stands, or where along a wall a door goes. This decides
## all three, once, so the consumer (VoxelGames first) carves what it is told
## instead of guessing. See docs/DUNGEONS.md for the contract.

const SCHEMA := "brickwild.dungeon.rooms"
const SCHEMA_VERSION := 1
## The planner exports this reads.
const PLAN_SCHEMA := "dmv.dungeon.plan"


## `{"ok", "errors", "warnings", "document"}`. Pure: the same payload and
## geometry give the same document, byte for byte.
static func realise(payload: Dictionary, geo: DungeonGeometry = null) -> Dictionary:
	if geo == null:
		geo = DungeonGeometry.new()
	var errors: Array[String] = []
	var warnings: Array[String] = []
	if payload.has("schema") and String(payload["schema"]) != PLAN_SCHEMA:
		errors.append("not a dungeon plan: schema %s" % payload["schema"])
	for key in ["rooms", "links"]:
		if not payload.get(key) is Array:
			errors.append("the plan has no %s" % key)
	if not errors.is_empty():
		return {"ok": false, "errors": errors, "warnings": warnings, "document": {}}

	var request: Dictionary = payload.get("request", {})
	var theme: Dictionary = payload.get("theme", {})
	var vg: Dictionary = payload.get("voxelgames", {})
	var theme_id := String(theme.get("id", request.get("theme", "")))
	var resolved := DungeonStyles.resolve(theme_id, String(vg.get("surface_theme", "")))
	if not bool(resolved["own"]):
		warnings.append("theme '%s' has no style of its own; built as %s"
			% [theme_id, resolved["id"]])
	var spaces: Dictionary = payload.get("spaces", {})
	if spaces.is_empty():
		warnings.append("the plan carries no spaces; every archetype is inferred from role and span")
	var plan_seed := int(payload.get("plan_seed", request.get("seed", 0)))

	var by_key := {}
	for room: Dictionary in payload["rooms"]:
		by_key[String(room["key"])] = room
	var ends := doorways(payload, geo)
	var rooms: Array = []
	for room: Dictionary in payload["rooms"]:
		var key := String(room["key"])
		rooms.append(DungeonRoomPlanner.plan_room(room, spaces.get(key, {}),
			ends.get(key, []), resolved["style"], theme, geo, plan_seed))

	var links: Array = []
	for link: Dictionary in payload["links"]:
		var row := {"portal": String(link.get("portal", "")), "from": String(link["from"]),
			"to": String(link["to"]), "kind": String(link.get("kind", "door")),
			"lock": (link.get("lock", {}) as Dictionary).duplicate(true)}
		for extra in ["one_way", "shares_lock_with"]:
			if link.has(extra):
				row[extra] = link[extra]
		links.append(row)

	var document := {
		"schema": SCHEMA, "schema_version": SCHEMA_VERSION,
		"source": {"schema": String(payload.get("schema", "")),
			"schema_version": int(payload.get("schema_version", 0)),
			"planner_version": String(payload.get("planner_version", "")),
			"request": request.duplicate(true), "plan_seed": plan_seed,
			"archetype": String(payload.get("archetype", "")),
			"entrance_key": String(payload.get("entrance_key", "")),
			"goal_key": String(payload.get("goal_key", ""))},
		"style": {"id": String(resolved["id"]), "label": String(resolved["style"]["label"]),
			"own": bool(resolved["own"]), "theme": theme_id},
		"geometry": geo.to_dict(),
		"rooms": rooms,
		"links": links,
		"requires": (payload.get("requires", []) as Array).duplicate(true),
	}
	return {"ok": true, "errors": errors, "warnings": warnings, "document": document}


## `{room key: [{portal, other, wall, along, kind, lock, rise}]}`. Both ends of
## every link, each in the middle of the stretch the two rooms share (or toward
## the other room, when they do not touch), then spread along each wall so no
## two doorways merge. VoxelGames' dungeon_builder.gd did exactly this; the
## numbers are the same, so a realised plan puts its doors where they were.
static func doorways(payload: Dictionary, geo: DungeonGeometry) -> Dictionary:
	var rooms := {}
	for room: Dictionary in payload["rooms"]:
		rooms[String(room["key"])] = room
	var walls := {}
	var out := {}
	var index := 0
	for link: Dictionary in payload["links"]:
		var a: Dictionary = rooms.get(String(link["from"]), {})
		var b: Dictionary = rooms.get(String(link["to"]), {})
		if a.is_empty() or b.is_empty():
			index += 1
			continue
		var wall_a := StringName(String(link.get("wall", "")))
		if wall_a == &"":
			wall_a = DungeonGeometry.exit_toward(_cell(a), _cell(b))
		var wall_b := DungeonGeometry.opposite(wall_a)
		var rise := _rises(link, a, b)
		for end in [[a, b, wall_a, rise.x, index * 2], [b, a, wall_b, rise.y, index * 2 + 1]]:
			var room: Dictionary = end[0]
			var key := String(room["key"])
			var entry := {"portal": String(link.get("portal", "")),
				"other": String((end[1] as Dictionary)["key"]), "wall": String(end[2]),
				"along": _ideal_along(room, end[1], end[2], geo),
				"kind": String(link.get("kind", "door")),
				"lock": (link.get("lock", {}) as Dictionary).duplicate(true),
				"rise": end[3], "order": end[4]}
			if not out.has(key):
				out[key] = []
			(out[key] as Array).append(entry)
			var slot := "%s|%s" % [key, end[2]]
			if not walls.has(slot):
				walls[slot] = []
			(walls[slot] as Array).append(entry)
		index += 1
	for slot in walls:
		var on_wall: Array = walls[slot]
		if on_wall.size() > 1:
			var parts := String(slot).split("|")
			_spread(on_wall, geo.wall_reach(_span(rooms[parts[0]]), StringName(parts[1])), geo)
	for key in out:
		for entry: Dictionary in out[key]:
			entry.erase("order")
	return out


## How far each end's threshold climbs: the lower room's stair goes up and the
## upper room's comes down; between rooms on one floor both go up and over.
static func _rises(link: Dictionary, a: Dictionary, b: Dictionary) -> Vector2:
	var kind := String(link.get("kind", "door"))
	if kind != "stairs" and kind != "drop":
		return Vector2.ZERO
	var la := int(a.get("level", 0))
	var lb := int(b.get("level", 0))
	var r := DungeonGeometry.STAIR_RISE
	if la == lb:
		return Vector2(r, r)
	# The plan does not say whether a higher level is up or down. A higher number
	# is taken as higher; either way the two ends agree.
	return Vector2(r, -r) if la < lb else Vector2(-r, r)


static func _ideal_along(room: Dictionary, other: Dictionary, wall: StringName,
		geo: DungeonGeometry) -> float:
	var axis := 1 if DungeonGeometry.is_x_wall(wall) else 0
	var r0 := int(room["cell"][axis])
	var r1 := r0 + int(room["span"][axis])
	var o0 := int(other["cell"][axis])
	var o1 := o0 + int(other["span"][axis])
	var lo := maxi(r0, o0)
	var hi := mini(r1, o1)
	var mid := float(lo + hi) * 0.5 if hi > lo \
		else clampf(float(o0 + o1) * 0.5, float(r0), float(r1))
	var t := (mid - float(r0 + r1) * 0.5) / (float(int(room["span"][axis])) * 0.5)
	return clampf(t, -1.0, 1.0) * geo.wall_reach(_span(room), wall)


static func _spread(ends: Array, reach: float, geo: DungeonGeometry) -> void:
	ends.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		if not is_equal_approx(float(x["along"]), float(y["along"])):
			return float(x["along"]) < float(y["along"])
		return int(x["order"]) < int(y["order"]))
	var gap := geo.door_gap
	if float(ends.size() - 1) * gap > reach * 2.0:
		gap = reach * 2.0 / float(ends.size() - 1)
	for i in range(1, ends.size()):
		var least: float = float(ends[i - 1]["along"]) + gap
		if float(ends[i]["along"]) < least:
			ends[i]["along"] = least
	var over: float = float(ends[ends.size() - 1]["along"]) - reach
	if over > 0.0:
		for end: Dictionary in ends:
			end["along"] = float(end["along"]) - over


static func _cell(room: Dictionary) -> Vector2i:
	return Vector2i(int(room["cell"][0]), int(room["cell"][1]))


static func _span(room: Dictionary) -> Vector2i:
	return Vector2i(int(room["span"][0]), int(room["span"][1]))

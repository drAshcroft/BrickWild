class_name DungeonRoomPlanner
extends RefCounted
## One planner room, made into architecture: a carve programme, its doorways,
## and the sockets a consumer dresses.
##
## The room is a plan, not a mesh, for the same reason a house is: it is cheap
## to check headless, and the consumer decides what stone and what props mean.
## The grammar words -- the ceilings, walls and floors -- are the planner's own
## (spatial/architecture_grammar.gd), so the two repositories speak one
## vocabulary; the planner declares them, this is where they are decided.

## What each spatial archetype may be built as. A role can narrow it further
## (an entrance never opens onto a pit).
const GRAMMAR := {
	&"great_hall": {"ceilings": [&"vaulted", &"enormous", &"domed"],
		"walls": [&"columns", &"alcove", &"solid"], "floors": [&"flat", &"stepped", &"flooded"]},
	&"shaft": {"ceilings": [&"enormous"], "walls": [&"solid", &"alcove"], "floors": [&"pit"]},
	&"chasm": {"ceilings": [&"vaulted", &"enormous", &"collapsed"],
		"walls": [&"solid", &"collapsed"], "floors": [&"pit"]},
	&"courtyard": {"ceilings": [&"enormous", &"vaulted"], "walls": [&"columns", &"solid"],
		"floors": [&"flat", &"flooded"]},
	&"cavern": {"ceilings": [&"vaulted", &"collapsed", &"domed"],
		"walls": [&"solid", &"collapsed"], "floors": [&"flat", &"broken", &"flooded"]},
	&"tower": {"ceilings": [&"domed", &"enormous"], "walls": [&"solid", &"alcove"],
		"floors": [&"flat", &"stepped"]},
	&"atrium": {"ceilings": [&"domed", &"vaulted"], "walls": [&"columns", &"solid"],
		"floors": [&"flat", &"stepped", &"flooded"]},
	&"gallery": {"ceilings": [&"vaulted", &"flat"], "walls": [&"columns", &"alcove"],
		"floors": [&"flat"]},
	&"narrow_tunnel": {"ceilings": [&"vaulted", &"flat"], "walls": [&"alcove", &"solid"],
		"floors": [&"flat", &"flooded"]},
	&"bridge_space": {"ceilings": [&"enormous", &"vaulted"], "walls": [&"solid"],
		"floors": [&"pit"]},
	&"chamber": {"ceilings": [&"vaulted", &"flat", &"domed"],
		"walls": [&"solid", &"alcove", &"columns"], "floors": [&"flat", &"stepped", &"flooded"]},
	&"corridor": {"ceilings": [&"vaulted", &"flat"], "walls": [&"solid", &"alcove"],
		"floors": [&"flat", &"flooded"]},
}

## Roles whose floor must not be a pit or a step: where the player arrives.
const SAFE_FLOOR_ROLES := [&"entrance"]
## Roles that earn a dais and a set piece.
const DAIS_ROLES := [&"boss", &"goal", &"arena", &"miniboss"]
const SET_PIECE_ROLES := [&"boss", &"goal", &"hub", &"arena", &"miniboss"]

## Fixture kinds that hang on a wall rather than stand on the floor.
const WALL_FIXTURES := [&"switch", &"mode_lever", &"lever", &"shutter", &"brazier",
	&"crystal", &"light_beam"]

## The gate a doorway's lock is dressed as. An unknown kind is SHUT (the
## planner's rule), so it gets a sealed gate rather than an open arch.
const GATES := {"": &"open_arch", "item": &"locked_door", "switch": &"portcullis",
	"timed": &"portcullis", "monster": &"sealed_gate", "breakable": &"cracked_wall",
	"tool": &"tool_gate", "ability": &"tool_gate", "barred": &"barred_gate",
	"stations": &"portcullis", "symbol": &"rune_door", "knowledge": &"rune_door"}

const LEDGE := 3.0          # walkable ring left round a pit
const PIT_DEPTH := 6.0
const PIT_TREAD := 0.35
const PIT_STAIR_WIDTH := 2.0
const COLUMN_R := 0.7
const COLUMN_STEP := 6.0
const NICHE := Vector3(2.2, 2.6, 1.2)  # width, height, depth
const NICHE_SILL := 0.6
const NICHE_STEP := 4.5
const DAIS_RISE := 0.45
const DAIS_DEPTH := 4.0
## How far a shape that meets the floor reaches through it: a fill standing on the floor (a
## dais, a stair) roots this far below it, and a carve opening beneath it (a pit, a stair down)
## rises this far above it. A consumer that writes the carve as distances (VoxelGames) combines
## shapes with min() and max(), which is exact only outside them: a dais that stopped at the
## floor meshed at 0.1 m instead of 0.45, and a pit whose top was the floor's own plane left a
## voxel of nothing-in-particular across its mouth that quantised to rock.
const ROOT := 1.0
const APPROACH_DEPTH := 5.0  # clear floor kept inside each doorway
## How far a doorway's torches hang beyond the tunnel's edge: clear of the
## consumer's arch (VoxelGames' is nearly four metres wide). Niches and wall
## fixtures keep off that stone.
const LIGHT_OFFSET := 1.7
const WATER_LEVEL := 0.25
## The weight of a grammar word a style does not name.
const UNNAMED := 0.2


## Plan one room. `doorways` are this room's ends of its links, already placed
## along their walls by the realiser.
static func plan_room(room: Dictionary, space: Dictionary, doorways: Array,
		style: Dictionary, theme: Dictionary, geo: DungeonGeometry, plan_seed: int) -> Dictionary:
	var key := String(room["key"])
	var role := StringName(String(room.get("role", "room")))
	var span := Vector2i(int(room["span"][0]), int(room["span"][1]))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d|%s" % [plan_seed, key])

	var archetype := StringName(String(space.get("archetype", "")))
	var source := "planner"
	if archetype == &"" or not GRAMMAR.has(archetype):
		source = "inferred" if archetype == &"" else "inferred (unknown %s)" % archetype
		archetype = infer_archetype(role, span)
	var grammar := _choose(archetype, role, style, doorways, rng)

	var half := geo.chamber_half(span)
	var ceiling := geo.chamber_ceiling(span)
	if grammar["ceiling"] == &"enormous":
		ceiling = minf(ceiling * 1.6, geo.max_enormous_y)
	var shorter := minf(half.x, half.y)
	var rise := 0.0
	if grammar["ceiling"] in [&"vaulted", &"domed", &"collapsed"]:
		rise = minf(shorter, ceiling * 0.45)
	var springing := ceiling - rise

	var ops: Array = []
	ops.append(DungeonCarve.box(&"carve", "chamber", Vector3(0, springing * 0.5, 0),
		Vector3(half.x * 2.0, springing, half.y * 2.0)))
	var long_x := half.x >= half.y
	match grammar["ceiling"]:
		&"vaulted", &"collapsed":
			if long_x:
				ops.append(DungeonCarve.cylinder(&"carve", "vault", Vector3(0, springing, 0), "x",
					half.x * 2.0, Vector2(rise, half.y)))
			else:
				ops.append(DungeonCarve.cylinder(&"carve", "vault", Vector3(0, springing, 0), "z",
					half.y * 2.0, Vector2(half.x, rise)))
		&"domed":
			ops.append(DungeonCarve.ellipsoid(&"carve", "dome", Vector3(0, springing, 0),
				Vector3(half.x, rise, half.y)))

	var doors_out: Array = []
	var approaches: Array[Rect2] = []
	for d: Dictionary in doorways:
		var wall := StringName(String(d["wall"]))
		var along := float(d["along"])
		var mouth := geo.mouth(span, wall, along)
		var n := DungeonGeometry.normal(wall)
		var t := Vector2(-n.y, n.x).abs()  # along the wall
		var door_rise := float(d.get("rise", 0.0))
		var portal := String(d["portal"])
		var tunnel_top := geo.tunnel_height + maxf(door_rise, 0.0)
		var centre := mouth + n * (geo.tunnel_reach * 0.5 - 0.25)
		var size2 := t * geo.tunnel_half * 2.0 + n.abs() * (geo.tunnel_reach + 0.5)
		ops.append(DungeonCarve.box(&"carve", "tunnel:" + portal,
			Vector3(centre.x, tunnel_top * 0.5, centre.y), Vector3(size2.x, tunnel_top, size2.y)))
		if door_rise != 0.0:
			_stair(ops, portal, mouth, n, t, door_rise, geo)
		approaches.append(_rect_around(mouth - n * APPROACH_DEPTH * 0.5,
			t * (geo.tunnel_half * 2.0 + 2.0) + n.abs() * APPROACH_DEPTH))
		var lock: Dictionary = d.get("lock", {})
		var lock_kind := String(lock.get("kind", ""))
		doors_out.append({
			"portal": portal, "other": String(d["other"]), "wall": String(wall),
			"along": snappedf(along, 0.001), "kind": String(d.get("kind", "door")),
			"mouth": [snappedf(mouth.x, 0.001), 0.0, snappedf(mouth.y, 0.001)],
			"facing": String(DungeonGeometry.opposite(wall)),
			"width": geo.tunnel_half * 2.0, "height": geo.tunnel_height,
			"rise": door_rise, "lock": lock.duplicate(true),
			"gate": String(GATES.get(lock_kind, &"sealed_gate")),
			"frame": "arch",
		})

	var pit := Rect2()
	if grammar["floor"] == &"pit":
		pit = Rect2(-half.x + LEDGE, -half.y + LEDGE, (half.x - LEDGE) * 2.0, (half.y - LEDGE) * 2.0)
		ops.append(DungeonCarve.box(&"carve", "pit", Vector3(0, (ROOT - PIT_DEPTH) * 0.5, 0),
			Vector3(pit.size.x, PIT_DEPTH + ROOT, pit.size.y)))
		if archetype in [&"chasm", &"bridge_space"]:
			var bridge := Vector3(pit.size.x + 0.2, PIT_DEPTH, 3.0) if long_x \
				else Vector3(3.0, PIT_DEPTH, pit.size.y + 0.2)
			ops.append(DungeonCarve.box(&"fill", "bridge", Vector3(0, -PIT_DEPTH * 0.5, 0), bridge))
		_pit_stair(ops, pit, long_x)

	var keep_clear: Array[Rect2] = approaches.duplicate()
	var dais := Rect2()
	var dais_wall := &""
	if grammar["floor"] == &"stepped":
		dais_wall = _free_wall(doorways, rng)
		if dais_wall != &"":
			dais = _dais_rect(half, dais_wall)
			ops.append(DungeonCarve.box(&"fill", "dais", Vector3(dais.get_center().x,
				(DAIS_RISE - ROOT) * 0.5, dais.get_center().y),
				Vector3(dais.size.x, DAIS_RISE + ROOT, dais.size.y)))
			keep_clear.append(dais.grow(0.5))

	if grammar["walls"] == &"columns" and grammar["floor"] != &"pit":
		_columns(ops, half, springing, keep_clear)
	if grammar["walls"] == &"alcove":
		_niches(ops, half, doors_out, geo, archetype)
	if grammar["walls"] == &"collapsed" or grammar["ceiling"] == &"collapsed" \
			or grammar["floor"] == &"broken":
		_rubble(ops, half, keep_clear, pit, rng)

	var sockets := _sockets(room, role, archetype, half, doors_out, ops, dais, pit, style,
		theme, space, geo, rng)
	var out := {
		"key": key, "label": String(room.get("label", "")), "role": String(role),
		"level": int(room.get("level", 0)), "cell": room["cell"], "span": room["span"],
		"archetype": String(archetype), "archetype_source": source,
		"grammar": {"ceiling": String(grammar["ceiling"]), "walls": String(grammar["walls"]),
			"floor": String(grammar["floor"])},
		"size": {"half": [half.x, half.y], "ceiling": snappedf(ceiling, 0.001),
			"springing": snappedf(springing, 0.001)},
		"bands": (style["bands"] as Dictionary).duplicate(),
		"accent": String(style["accent"]),
		"doorways": doors_out,
		"carve": ops,
		"sockets": sockets,
	}
	if grammar["floor"] == &"flooded":
		out["water"] = {"level": WATER_LEVEL, "rect": [-half.x, -half.y, half.x * 2.0, half.y * 2.0]}
	return out


## A room the planner gave no spatial archetype (VoxelGames' older plan files).
static func infer_archetype(role: StringName, span: Vector2i) -> StringName:
	var area := span.x * span.y
	var lean := maxi(span.x, span.y) >= 2 * mini(span.x, span.y)
	match role:
		&"hub", &"boss", &"arena":
			return &"great_hall"
		&"goal":
			return &"atrium"
		&"corridor":
			return &"gallery" if lean and area >= 3 else &"narrow_tunnel"
	if area >= 6:
		return &"great_hall"
	return &"narrow_tunnel" if lean else &"chamber"


static func _choose(archetype: StringName, role: StringName, style: Dictionary,
		doorways: Array, rng: RandomNumberGenerator) -> Dictionary:
	var g: Dictionary = GRAMMAR[archetype]
	var floors: Array = (g["floors"] as Array).duplicate()
	if role in SAFE_FLOOR_ROLES:
		floors = floors.filter(func(f): return f != &"pit" and f != &"stepped")
		if floors.is_empty():
			floors = [&"flat"]
	if role in DAIS_ROLES and &"pit" not in floors:
		floors = [&"stepped"]
	if doorways.size() >= 4:
		floors = floors.filter(func(f): return f != &"stepped")
		if floors.is_empty():
			floors = [&"flat"]
	return {
		"ceiling": _weighted(g["ceilings"], style["ceilings"], rng),
		"walls": _weighted(g["walls"], style["walls"], rng),
		"floor": _weighted(floors, style["floors"], rng),
	}


## Pick from `allowed`, weighted by the style's preferences; what a style does
## not name is possible but rare.
static func _weighted(allowed: Array, weights: Dictionary, rng: RandomNumberGenerator) -> StringName:
	var total := 0.0
	for a in allowed:
		total += float(weights.get(a, UNNAMED))
	var roll := rng.randf() * total
	for a in allowed:
		roll -= float(weights.get(a, UNNAMED))
		if roll <= 0.0:
			return a
	return allowed[allowed.size() - 1]


static func _stair(ops: Array, portal: String, mouth: Vector2, n: Vector2, t: Vector2,
		rise: float, geo: DungeonGeometry) -> void:
	var steps := int(round(absf(rise) / DungeonGeometry.STAIR_RISER))
	var start := 1.0
	var tread := (geo.tunnel_reach - start - 0.5) / float(steps)
	for i in range(steps):
		var d0 := start + float(i) * tread
		var run := geo.tunnel_reach + 0.5 - d0
		var c := mouth + n * (d0 + run * 0.5)
		var s := t * geo.tunnel_half * 2.0 + n.abs() * run
		var h := float(i + 1) * DungeonGeometry.STAIR_RISER
		if rise > 0.0:
			ops.append(DungeonCarve.box(&"fill", "step:%s#%d" % [portal, i],
				Vector3(c.x, (h - ROOT) * 0.5, c.y), Vector3(s.x, h + ROOT, s.y)))
		else:
			ops.append(DungeonCarve.box(&"carve", "step:%s#%d" % [portal, i],
				Vector3(c.x, (ROOT - h) * 0.5, c.y), Vector3(s.x, h + ROOT, s.y)))


## A flight down one long wall of a pit, from the ledge to the bottom. A pit is a place to fall
## into, never a place to be stuck in: VoxelGames' dungeon rooms do not respawn a fallen player.
static func _pit_stair(ops: Array, pit: Rect2, long_x: bool) -> void:
	var steps := int(round(PIT_DEPTH / DungeonGeometry.STAIR_RISER))
	var length := pit.size.x if long_x else pit.size.y
	var tread := minf(PIT_TREAD, length * 0.8 / float(steps))
	for k in range(steps):
		var top := -float(k + 1) * DungeonGeometry.STAIR_RISER
		var bottom := -PIT_DEPTH - ROOT
		# Down from the pit's east (or south) end, against its south (or east) wall.
		var u := (pit.end.x if long_x else pit.end.y) - (float(k) + 0.5) * tread
		var v := (pit.end.y if long_x else pit.end.x) - PIT_STAIR_WIDTH * 0.5
		var c := Vector3(u, (top + bottom) * 0.5, v) if long_x else Vector3(v, (top + bottom) * 0.5, u)
		var s := Vector3(tread, top - bottom, PIT_STAIR_WIDTH) if long_x \
			else Vector3(PIT_STAIR_WIDTH, top - bottom, tread)
		ops.append(DungeonCarve.box(&"fill", "pitstep#%d" % k, c, s))


static func _rect_around(c: Vector2, size: Vector2) -> Rect2:
	return Rect2(c - size * 0.5, size)


static func _free_wall(doorways: Array, rng: RandomNumberGenerator) -> StringName:
	var used := {}
	for d: Dictionary in doorways:
		used[StringName(String(d["wall"]))] = true
	var free: Array = []
	for w in DungeonGeometry.WALLS:
		if not used.has(w):
			free.append(w)
	if free.is_empty():
		return &""
	return free[rng.randi_range(0, free.size() - 1)]


static func _dais_rect(half: Vector2, wall: StringName) -> Rect2:
	var m := 1.0
	match wall:
		DungeonGeometry.EAST:
			return Rect2(half.x - DAIS_DEPTH, -half.y + m, DAIS_DEPTH, (half.y - m) * 2.0)
		DungeonGeometry.WEST:
			return Rect2(-half.x, -half.y + m, DAIS_DEPTH, (half.y - m) * 2.0)
		DungeonGeometry.SOUTH:
			return Rect2(-half.x + m, half.y - DAIS_DEPTH, (half.x - m) * 2.0, DAIS_DEPTH)
	return Rect2(-half.x + m, -half.y, (half.x - m) * 2.0, DAIS_DEPTH)


static func _columns(ops: Array, half: Vector2, height: float, keep_clear: Array[Rect2]) -> void:
	var inset := Vector2(minf(half.x * 0.5, half.x - 3.0), minf(half.y * 0.5, half.y - 3.0))
	if inset.x < 2.0 or inset.y < 2.0:
		return
	var long_x := half.x >= half.y
	var length := inset.x if long_x else inset.y
	var count := maxi(int(floor(length * 2.0 / COLUMN_STEP)) + 1, 2)
	var i := 0
	for side in [-1.0, 1.0]:
		for k in range(count):
			var u := -length + float(k) * (length * 2.0 / float(count - 1))
			var p := Vector2(u, side * inset.y) if long_x else Vector2(side * inset.x, u)
			var foot := Rect2(p - Vector2.ONE * (COLUMN_R + 0.8), Vector2.ONE * (COLUMN_R + 0.8) * 2.0)
			if keep_clear.any(func(r: Rect2): return r.intersects(foot)):
				continue
			ops.append(DungeonCarve.cylinder(&"fill", "column#%d" % i,
				Vector3(p.x, height * 0.5, p.y), "y", height + 0.2, Vector2(COLUMN_R, COLUMN_R)))
			i += 1


static func _niches(ops: Array, half: Vector2, doors: Array, geo: DungeonGeometry,
		archetype: StringName) -> void:
	var sill := 0.0 if archetype in [&"gallery", &"great_hall"] else NICHE_SILL
	var i := 0
	for wall in DungeonGeometry.WALLS:
		var length := (half.y if DungeonGeometry.is_x_wall(wall) else half.x) * 2.0
		var count := int(floor((length - 3.0) / NICHE_STEP))
		var n := DungeonGeometry.normal(wall)
		var t := Vector2(-n.y, n.x).abs()
		for k in range(count):
			var u := -length * 0.5 + 1.5 + NICHE_STEP * (float(k) + 0.5) \
				+ ((length - 3.0) - NICHE_STEP * float(count)) * 0.5
			var clash := false
			for d: Dictionary in doors:
				if String(d["wall"]) == String(wall) \
						and absf(float(d["along"]) - u) < geo.tunnel_half + LIGHT_OFFSET + 0.5 + NICHE.x * 0.5:
					clash = true
			if clash:
				continue
			var wall_pt := _on_wall(half, wall, u)
			var c := wall_pt + n * (NICHE.z * 0.5 - 0.05)
			var s := t * NICHE.x + n.abs() * (NICHE.z + 0.1)
			ops.append(DungeonCarve.box(&"carve", "niche#%d" % i,
				Vector3(c.x, sill + NICHE.y * 0.5, c.y), Vector3(s.x, NICHE.y, s.y)))
			i += 1


static func _on_wall(half: Vector2, wall: StringName, along: float) -> Vector2:
	match wall:
		DungeonGeometry.EAST: return Vector2(half.x, along)
		DungeonGeometry.WEST: return Vector2(-half.x, along)
		DungeonGeometry.SOUTH: return Vector2(along, half.y)
	return Vector2(along, -half.y)


static func _rubble(ops: Array, half: Vector2, keep_clear: Array[Rect2], pit: Rect2,
		rng: RandomNumberGenerator) -> void:
	var placed := 0
	for attempt in range(12):
		if placed >= 3:
			break
		var p := Vector2(rng.randf_range(-half.x + 2.0, half.x - 2.0),
			rng.randf_range(-half.y + 2.0, half.y - 2.0))
		var r := Vector3(rng.randf_range(1.2, 2.2), rng.randf_range(0.8, 1.4), rng.randf_range(1.2, 2.2))
		var foot := Rect2(Vector2(p.x - r.x, p.y - r.z), Vector2(r.x, r.z) * 2.0).grow(0.8)
		if keep_clear.any(func(k: Rect2): return k.intersects(foot)):
			continue
		if pit.has_area() and pit.grow(1.0).intersects(foot):
			continue
		ops.append(DungeonCarve.ellipsoid(&"fill", "rubble#%d" % placed, Vector3(p.x, 0.0, p.y), r))
		keep_clear.append(foot)
		placed += 1


## Where the consumer puts things: the planner's fixtures, the lights, and one
## set piece in a room that earns it. Every socket is ON a surface -- the
## room check samples the carve to prove it.
static func _sockets(room: Dictionary, role: StringName, archetype: StringName, half: Vector2,
		doors: Array, ops: Array, dais: Rect2, pit: Rect2, style: Dictionary, theme: Dictionary,
		space: Dictionary, geo: DungeonGeometry, rng: RandomNumberGenerator) -> Dictionary:
	var lights: Array = []
	for d: Dictionary in doors:
		var wall := StringName(String(d["wall"]))
		var n := DungeonGeometry.normal(wall)
		var t := Vector2(-n.y, n.x).abs()
		var m := Vector2(float(d["mouth"][0]), float(d["mouth"][2]))
		for side in [-1.0, 1.0]:
			var p: Vector2 = m + t * side * (geo.tunnel_half + LIGHT_OFFSET) - n * 0.15
			lights.append({"kind": String(style["light"]), "position": [p.x, 2.2, p.y],
				"wall": String(wall), "beside": String(d["portal"])})

	var floor_spots := _floor_spots(half, doors, ops, dais, pit, geo)
	var wall_spots := _wall_spots(half, doors, ops, geo)
	var fixtures: Array = []
	var fi := 0
	var wi := 0
	for fx: Dictionary in (room.get("fixtures", []) as Array):
		var kind := StringName(String(fx.get("kind", "")))
		var on_wall := kind in WALL_FIXTURES or String(kind).ends_with("_board")
		var spot: Dictionary = {}
		if on_wall and wi < wall_spots.size():
			spot = wall_spots[wi]; wi += 1
		elif fi < floor_spots.size():
			spot = floor_spots[fi]; fi += 1
		elif wi < wall_spots.size():
			spot = wall_spots[wi]; wi += 1
		if spot.is_empty():
			continue
		fixtures.append(spot.merged({"id": String(fx.get("id", "")), "kind": String(kind)}))

	var set_pieces: Array = []
	if role in SET_PIECE_ROLES or String(space.get("landmark", "")) != "":
		var pieces: Array = style["set_pieces"]
		var what := String(pieces[rng.randi_range(0, pieces.size() - 1)])
		if role == &"boss" and String(theme.get("boss_aesthetic", "")) != "":
			what = "boss:" + String(theme["boss_aesthetic"])
		var at := Vector3.ZERO
		if dais.has_area():
			at = Vector3(dais.get_center().x, DAIS_RISE, dais.get_center().y)
		elif not pit.has_area() and DungeonCarve.solid_at(ops, Vector3(0, -0.1, 0)) \
				and not DungeonCarve.solid_at(ops, Vector3(0, 0.5, 0)):
			at = Vector3.ZERO
		elif fi < floor_spots.size():
			var s: Array = floor_spots[fi]["position"]
			at = Vector3(float(s[0]), float(s[1]), float(s[2]))
		else:
			at = Vector3(INF, 0, 0)
		if at.x != INF:
			set_pieces.append({"kind": what, "position": [at.x, at.y, at.z], "on": "floor"})
	return {"fixtures": fixtures, "lights": lights, "set_pieces": set_pieces}


## Floor spots in a deterministic order: a ring a third of the way in, then the
## middle; never in a doorway's approach, a pit, a column or rubble.
static func _floor_spots(half: Vector2, doors: Array, ops: Array, dais: Rect2, pit: Rect2,
		geo: DungeonGeometry) -> Array:
	var out: Array = []
	var rings: Array = [half * 0.66, half * 0.33, half - Vector2.ONE * 1.5]
	if pit.has_area():
		rings = [half - Vector2.ONE * LEDGE * 0.5]
	for ring: Vector2 in rings:
		for p in _rect_ring(ring, 16):
			if _blocked_floor(p, doors, ops, geo):
				continue
			var y := DAIS_RISE if dais.has_point(p) else 0.0
			out.append({"position": [snappedf(p.x, 0.01), y, snappedf(p.y, 0.01)], "on": "floor"})
	return out


## `count` points evenly round the rectangle of half-extents `h`, starting east.
static func _rect_ring(h: Vector2, count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var corners: Array[Vector2] = [Vector2(h.x, 0), Vector2(h.x, h.y), Vector2(-h.x, h.y),
		Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, 0)]
	var perimeter := 4.0 * (h.x + h.y)
	for k in range(count):
		var s := perimeter * float(k) / float(count)
		for i in range(corners.size() - 1):
			var seg := corners[i].distance_to(corners[i + 1])
			if s <= seg:
				out.append(corners[i].lerp(corners[i + 1], s / maxf(seg, 0.001)))
				break
			s -= seg
	return out


static func _blocked_floor(p: Vector2, doors: Array, ops: Array, geo: DungeonGeometry) -> bool:
	for d: Dictionary in doors:
		var m := Vector2(float(d["mouth"][0]), float(d["mouth"][2]))
		if p.distance_to(m) < APPROACH_DEPTH + 0.5:
			return true
	for dy in [0.6, 1.5]:
		for o in [Vector2.ZERO, Vector2(0.7, 0), Vector2(-0.7, 0), Vector2(0, 0.7), Vector2(0, -0.7)]:
			var q: Vector2 = p + o
			var base := DAIS_RISE if DungeonCarve.solid_at(ops, Vector3(q.x, DAIS_RISE - 0.05, q.y)) else 0.0
			if not DungeonCarve.solid_at(ops, Vector3(q.x, base - 0.1, q.y)):
				return true
			if DungeonCarve.solid_at(ops, Vector3(q.x, base + float(dy), q.y)):
				return true
	return false


## Wall spots at hand height, between doorways and niches.
static func _wall_spots(half: Vector2, doors: Array, ops: Array, geo: DungeonGeometry) -> Array:
	var out: Array = []
	for wall in DungeonGeometry.WALLS:
		var n := DungeonGeometry.normal(wall)
		var length := (half.y if DungeonGeometry.is_x_wall(wall) else half.x) * 2.0
		for u in [0.0, -length * 0.25, length * 0.25]:
			var clash := false
			for d: Dictionary in doors:
				if String(d["wall"]) == String(wall) \
						and absf(float(d["along"]) - float(u)) < geo.tunnel_half + LIGHT_OFFSET + 1.0:
					clash = true
			if clash:
				continue
			var w := _on_wall(half, wall, float(u))
			var face := w - n * 0.05
			if not DungeonCarve.solid_at(ops, Vector3(w.x + n.x * 0.3, 1.2, w.y + n.y * 0.3)):
				continue  # a niche, or the wall is not there
			if DungeonCarve.solid_at(ops, Vector3(face.x - n.x * 0.5, 1.2, face.y - n.y * 0.5)):
				continue  # something stands in front of it
			out.append({"position": [snappedf(face.x, 0.01), 1.2, snappedf(face.y, 0.01)],
				"on": "wall", "wall": String(wall)})
	return out

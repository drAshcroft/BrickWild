class_name HousePlan
extends RefCounted
## The floor plan: which rooms there are, where the doors and windows are, and
## what furniture stands in each room.
##
## Plain data. HousePlanner fills the rooms, doors and windows; HouseFurnisher
## fills the furniture; HouseBuilder turns it into a mesh; the checks in qa/
## read it and judge it. Nothing here decides anything -- it is the thing all
## of them agree about.
##
## Rooms partition the interior rectangle exactly, so a room's `rect` includes
## half of each partition it shares. HouseGeometry.room_floor_rect() is the
## clear floor inside that, and is what furniture is placed in.

var spec: HouseSpec

## Optional wider-world family identity.  Courtyard houses deliberately keep
## using HousePlan so the ordinary shell, furnisher and nav checks remain the
## single source of truth; these fields carry only the family contract that
## is not meaningful for a cottage (WLD-001).
var world_family: StringName = &""
var world_subkind: StringName = &""
var view_through: bool = false
var blind_entry: bool = false
var canal_wall: StringName = &""
var water_plane: float = 0.0
var world_meta: Dictionary = {}

## How an ordinary dwelling was partitioned. `status` is `planned` when the
## activity layout met the room-size contracts, or `fallback` with a reason
## when the legacy partition was needed. Family plans leave this empty.
var domestic_layout: Dictionary = {}

## {"kind": StringName, "rect": Rect2, "storey": int,
##  "outline": PackedVector2Array (optional),
##  "wall_kinds": [StringName] (optional),
##  "wall_portals": {wall index: {start, end}} (optional)}
##
## `outline` is the TRUTH about a room's shape when it is there, and `rect`
## stays as its bounding box so every rectangle-shaped rule still has something
## to measure. A room WITHOUT one is the four-sided case, which is every room
## in every house: the outline exists for the shapes a rectangle cannot say --
## a round tower, an octagonal chapter house, a pagoda (GEO-002).
##
## A room may carry `secret: true` when ordinary visitors should not enter it;
## `is_private_room()` is the single query for that designation.
##
## An outline is the CLEAR FLOOR, not a partition centre-line. A rectangular
## room is cut out of the interior and shares half of each partition with its
## neighbour; a polygonal room is not produced by cutting, so there is no
## shared partition to give half of, and what you draw is what you walk on.
var rooms: Array[Dictionary] = []
## {"a": int, "b": int (-1 outdoors), "pos": Vector2, "normal": Vector2,
##  "width": float, "exterior": bool, "storey": int, "secret": bool}
var doors: Array[Dictionary] = []
## {"room": int, "pos": Vector2, "normal": Vector2, "width": float,
##  "sill": float, "head": float, "storey": int}
var windows: Array[Dictionary] = []
## {"key": String, "room": int, "pos": Vector3, "yaw": float, "rect": Rect2,
##  "zone": Rect2, "host": int, "cat": String, "storey": int}
var furniture: Array[Dictionary] = []
## Walkable textile overlays: {id, table, room, storey, rect}. They never
## enter furniture obstruction lists; the builder lifts them 2 mm above floor.
var rugs: Array[Dictionary] = []
## Outdoor props with facade host, measured bounds and independent identity.
## These never participate in room furnishing or room compromise removal.
var exterior: Array[Dictionary] = []
var exterior_omissions: Array[String] = []
## The yard beyond the facade (HouseYard, EVAL-B06). `yard` is measured catalogue
## props on the ground, each {id, key, pos, yaw, scale, role, host, group,
## bounds, rect, storey, mounted} with host "front" | "side" | "rear" | "porch"
## | "chimney" | "path" -- the shape of `exterior`, so HouseExterior.bounds_of()
## and the assembler read both. `yard_pieces` is what the catalogue has no model
## for and the builder emits as component_box rows on host "yard":
## {id, kind, role, host, group, rect, parts: [{role, surf, size, centre, basis}]}.
var yard: Array[Dictionary] = []
var yard_pieces: Array[Dictionary] = []
## The holes in the plan: {"rect": Rect2, "storey": int,
##  "outline": PackedVector2Array (optional)}.
##
## A court is FLOOR to the walk grid, SKY to the roof, and OUTSIDE to the
## daylight rule -- a window onto a courtyard is a window. The rooms and the
## courts together tile the footprint: what a court takes is not floor nobody
## owns, it is floor that belongs to the weather (GEO-003).
##
## It is what a monastery, an inn with a yard and a caravanserai are, and none
## of them can be said with rooms alone.
var courts: Array[Dictionary] = []
## Vertical circulation. `a`/`b` are the lower/upper room IDs; `storey` and
## `to_storey` identify the two levels. Rectangles are plan-space footprints on
## each landing, so a layered nav check can use them without a 3D rasterizer.
## {"a": int, "b": int, "storey": int, "to_storey": int,
##  "pos": Vector2, "lower_pos": Vector2, "upper_pos": Vector2,
##  "rect": Rect2, "lower_rect": Rect2, "upper_rect": Rect2,
##  "width": float, "run": float}
var stairs: Array[Dictionary] = []
## Cellar hatches. A sealed trapdoor is a physical opening and a recorded
## special access, but it is not an ordinary keyed door-graph edge.
## {upper_room, lower_room, upper_storey, lower_storey, rect, sealed}
var trapdoors: Array[Dictionary] = []
## Structural columns authored once for both emitter and QA. Wall-plan rows
## use {room, wall, storey, pos: Vector2, size: Vector2 (x/z), height, kind};
## world-family rows use {pos: Vector3, radius, height, role}. Columns are part
## of both the built shell and the walk/sightline model, rather than decoration
## inferred by the emitter.
var columns: Array[Dictionary] = []
## Things a room should have had and does not, because keeping them would have
## blocked the way through the house: {room: [category, ...]}.
##
## A generator that quietly drops furniture is hiding a defect; one that writes
## down what it dropped and why is reporting a compromise. The furnishing check
## reads this and downgrades exactly those complaints to warnings, so a real
## missing bed still fails.
var compromises: Dictionary = {}
## AUTHORED holes in the roof: a compluvium over an atrium, an oculus, an open
## court sky. One shared schema with the dormer openings the roof descriptor
## fits for itself (HOUSE-EXT-007):
##
##   {"id": String, "kind": StringName, "storey": int, "face": int,
##    "polygon": PackedVector2Array, "room": int}
## Authored compluvia/oculi may use a `rect` shorthand instead of polygon;
## HouseGeometry.roof_openings derives the polygon (oculus becomes a circle)
## without mutating the plan. A domus compluvium may also carry `impluvium`
## for CourtCheck.water's opt-in pool rule.
##
## `polygon` is the outline of the HOLE in the roof's own local XZ frame, and
## `face` indexes the roof descriptor's faces (-1 for a hole that is not on a
## sloped face). `room` is -1 when the hole belongs to no room, which is every
## dormer -- a dormer lights an attic, not a planned room.
##
## Dormers are NOT stored here. They are fitted from the roof descriptor by
## HouseGeometry.roof_layout, which recomputes rather than caches so a caller
## that edits a generated spec cannot retain holes belonging to a former roof.
## HouseGeometry.roof_openings(plan) is the MERGED view -- authored plus
## fitted -- and is what every consumer should read.
##
## INT-018 owns the compluvium/oculus/court-sky kinds and fills this list.
## HOUSE-EXT-007 owns only the dormer/sloped-polygon subset and the schema.
var roof_openings: Array[Dictionary] = []
## Where the fire is: {"room": int, "wall": int, "breast": Dictionary}, or empty when the house has
## no hearth room at all. The wall index is into HouseGeometry.room_walls().
##
## One owner for the position, the way ChurchGeometry owns the massing:
## HousePlanner decides it, HouseBuilder raises the stack on it and
## HouseFurnisher stands the hearth against it, so the fire and the flue are
## never on different walls again.
var hearth: Dictionary = {}
## Floor the PLAN keeps clear, before anything is placed:
## [{"room": int, "rect": Rect2, "why": String}].
##
## A furniture zone is the floor one piece needs to be usable and belongs to
## that piece. This is the other kind: floor that is kept clear because of what
## the room is for, and would be kept clear if the room were empty. A great
## hall keeps the screens passage inside its door clear so the way in is not
## through the middle of dinner (CAS-010); a temple keeps its processional
## axis. The furnisher treats these as occupied ground and the nav check
## requires them walkable, so a passage that was planned is a passage that is
## there.
var zones: Array[Dictionary] = []
## A raised platform in a room: {"room": int, "rect": Rect2, "rise": float}.
## Empty in a house; a castle's great hall has one at its upper end, with the
## high table on it and the lord behind that (CAS-010).
##
## A dais is a STEP, not a wall. The walk grid takes it as floor -- you walk
## up onto a dais -- and the only thing that is different about it is that
## the furniture standing on it is a hand's breadth higher than the rest.
var dais: Dictionary = {}


## What the house is arranged around: {"room": int, "cat": String,
## "pos": Vector2, "facing": float, "faces_door": bool}, or empty.
##
## The temple's axis (gate -> altar -> idol) is a focus with rules about it; a
## hall's hearth, a shop's counter, a smithy's forge, a throne are the same
## idea. The planner names the room, the category and where it should stand;
## the furnisher pins that piece there, records where it actually put it, and
## scores tables and seats toward it; HouseFurnishCheck's `focus` rule reads
## the record back and proves the piece is there and, when `faces_door` is
## set, that it looks at the way in. (INT-002)
var focus: Dictionary = {}


## The keep-clear zones of one room.
func zones_of(room: int) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for z in zones:
		if int(z.get("room", -1)) == room:
			out.append(Rect2(z["rect"]))
	return out


## The room the dais is in, or -1 when there is none.
func dais_room() -> int:
	return int(dais.get("room", -1)) if not dais.is_empty() else -1


## The floor of the dais, or an empty rect when there is none.
func dais_rect() -> Rect2:
	return dais.get("rect", Rect2()) if not dais.is_empty() else Rect2()


## How far the dais stands above the floor of its room, in metres.
func dais_rise() -> float:
	return float(dais.get("rise", 0.0)) if not dais.is_empty() else 0.0


## Is `p` standing on the dais?
func on_dais(room: int, p: Vector2) -> bool:
	return room == dais_room() and dais_rect().has_point(p)


## The room the chimney serves, or -1 when no hearth was planned.
func hearth_room() -> int:
	return int(hearth.get("room", -1)) if not hearth.is_empty() else -1


## The wall of that room the fire and the flue share, or -1.
func hearth_wall() -> int:
	return int(hearth.get("wall", -1)) if not hearth.is_empty() else -1


## The room the focus stands in, or -1 when the plan has none.
func focus_room() -> int:
	return int(focus.get("room", -1)) if not focus.is_empty() else -1


## The prop category that IS the focus: "hearth", "counter", "anvil", ...
func focus_cat() -> String:
	return String(focus.get("cat", "")) if not focus.is_empty() else ""


## Where it stands, in plan space (X, Z).
func focus_pos() -> Vector2:
	return Vector2(focus.get("pos", Vector2(INF, INF))) if not focus.is_empty() \
		else Vector2(INF, INF)


## The yaw it looks along; HouseFurnishScore._facing_of() turns it into a vector.
func focus_facing() -> float:
	return float(focus.get("facing", 0.0)) if not focus.is_empty() else 0.0


## Must the focus look at the door people come in by? A counter does, a
## fireplace does not.
func focus_faces_door() -> bool:
	return bool(focus.get("faces_door", false)) if not focus.is_empty() else false


## Was `cat` given up in this room for the sake of getting about?
func was_dropped(room: int, cat: String) -> bool:
	return compromises.has(room) and cat in compromises[room]


func note_compromise(room: int, cat: String) -> void:
	if not compromises.has(room):
		compromises[room] = []
	if not cat in compromises[room]:
		compromises[room].append(cat)


func room_count() -> int:
	return rooms.size()


func kind_of(i: int) -> StringName:
	return rooms[i]["kind"]


## The room's shape in plan. A room with no `outline` is its rectangle, so
## every caller can ask for a polygon and never test for one.
func outline_of(i: int) -> PackedVector2Array:
	return room_outline(rooms[i])


## The same, for a room record that is not in a plan yet.
static func room_outline(room: Dictionary) -> PackedVector2Array:
	var o = room.get("outline")
	if o != null and (o as PackedVector2Array).size() >= 3:
		return o
	return Poly.from_rect(room["rect"])


## The court's shape in plan, its rectangle when it has no outline.
func court_outline(i: int) -> PackedVector2Array:
	return room_outline(courts[i])


## The courts open on one storey. A court is open from its own storey up: a
## range round a yard has the yard on every floor it rises through.
func courts_on(storey: int) -> Array[int]:
	var out: Array[int] = []
	for i in range(courts.size()):
		if record_storey(courts[i]) <= storey:
			out.append(i)
	return out


## Which rooms have a door onto court `ci`.
func rooms_onto_court(ci: int) -> Array[int]:
	var out: Array[int] = []
	var poly: PackedVector2Array = court_outline(ci)
	for d in doors:
		var room: int = int(d["a"])
		if room < 0 or room >= rooms.size() or room in out:
			continue
		if record_storey(d) < record_storey(courts[ci]):
			continue
		var pos: Vector2 = d["pos"]
		var n: Vector2 = d["normal"]
		for side in [1.0, -1.0]:
			if Poly.contains_point(poly,
					pos + n * side * (HouseGeometry.wall_thickness(spec) + 0.05), 0.01):
				out.append(room)
				break
	return out


## Is any part of this plan open to the sky?
func has_court() -> bool:
	return not courts.is_empty()


## Is this room something a rectangle cannot describe?
func is_polygonal(i: int) -> bool:
	var o = rooms[i].get("outline")
	return o != null and (o as PackedVector2Array).size() >= 3


## Storey index for any plan record, with zero as the compatibility default for
## hand-authored one-storey plans from before vertical houses existed.
static func record_storey(record: Dictionary) -> int:
	return int(record.get("storey", 0))


func storey_of_room(i: int) -> int:
	return record_storey(rooms[i])


func rooms_on_storey(storey: int) -> Array[int]:
	var out: Array[int] = []
	for i in range(rooms.size()):
		if storey_of_room(i) == storey:
			out.append(i)
	return out


func rooms_of(kind: StringName) -> Array[int]:
	var out: Array[int] = []
	for i in range(rooms.size()):
		if rooms[i]["kind"] == kind:
			out.append(i)
	return out


func has_kind(kind: StringName) -> bool:
	return not rooms_of(kind).is_empty()


## Doors that open into room `i`, exterior ones included.
func doors_of(i: int) -> Array[int]:
	var out: Array[int] = []
	for d in range(doors.size()):
		if doors[d]["a"] == i or doors[d]["b"] == i:
			out.append(d)
	return out


func windows_of(i: int) -> Array[int]:
	var out: Array[int] = []
	for w in range(windows.size()):
		if windows[w]["room"] == i:
			out.append(w)
	return out


func furniture_of(i: int) -> Array[int]:
	var out: Array[int] = []
	for f in range(furniture.size()):
		if furniture[f]["room"] == i:
			out.append(f)
	return out


## The way in. There is exactly one front door; the checks insist on it.
func entrance() -> int:
	for d in range(doors.size()):
		if bool(doors[d].get("secret", false)):
			continue
		if doors[d]["exterior"] and doors[d].get("front", false):
			return d
	for d in range(doors.size()):
		if doors[d]["exterior"] and not bool(doors[d].get("secret", false)):
			return d
	return -1


func entrance_room() -> int:
	var d: int = entrance()
	return doors[d]["a"] if d >= 0 else -1


## Room-to-room graph as {room: [rooms]}, following doors only. This is what
## "can you get from the front door to the back bedroom" is answered with.
func door_graph(has_keys := true, include_secret := true) -> Dictionary:
	var g := {}
	for i in range(rooms.size()):
		g[i] = []
	for d in doors:
		if not include_secret and bool(d.get("secret", false)):
			continue
		if bool(d.get("locked", false)) and not has_keys:
			continue
		var a: int = d["a"]
		var b: int = d["b"]
		if b < 0 or a < 0:
			continue
		if storey_of_room(a) != storey_of_room(b):
			continue
		g[a].append(b)
		g[b].append(a)
	# A COURT is a way through. Two ranges that both open onto the same yard
	# are joined by it: you walk out of one door, across the paving and in at
	# the other, which is how a cloister works and the only reason a plan of
	# four ranges round a hole is a building rather than four buildings.
	for ci in range(courts.size()):
		var onto: Array[int] = rooms_onto_court(ci)
		for x in onto:
			for y in onto:
				if x != y:
					g[x].append(y)
	for stair in stairs:
		# A rejected stair is retained as plan provenance so the checker can
		# explain why vertical circulation failed. It is not a connection.
		# Older/custom plans without the field keep their historical behavior.
		if not bool(stair.get("satisfied", true)):
			continue
		var a: int = int(stair["a"])
		var b: int = int(stair["b"])
		if a < 0 or b < 0 or a >= rooms.size() or b >= rooms.size():
			continue
		g[a].append(b)
		g[b].append(a)
	return g


## Rooms reachable from `start` through doors, optionally refusing to pass
## THROUGH rooms of one kind (a single StringName) or several (an Array of
## StringNames). The refused kinds can still be the destination, just not a
## room walked through to get somewhere else.
func reachable_rooms(start: int, no_pass_kind: Variant = &"",
		has_keys := true, include_secret := true) -> Dictionary:
	var no_pass: Array = no_pass_kind if no_pass_kind is Array else [no_pass_kind]
	var seen := {start: true}
	var stack: Array[int] = [start]
	var g: Dictionary = door_graph(has_keys, include_secret)
	while not stack.is_empty():
		var cur: int = stack.pop_back()
		if cur != start and kind_of(cur) in no_pass:
			continue          # you may enter it, but not walk on through
		for nb in g[cur]:
			if not seen.has(nb):
				seen[nb] = true
				stack.append(nb)
	return seen


func is_private_room(i: int) -> bool:
	if i < 0 or i >= rooms.size():
		return false
	return bool(rooms[i].get("secret", false))


func secret_room_indices() -> Array[int]:
	var out: Array[int] = []
	for i in range(rooms.size()):
		if bool(rooms[i].get("secret", false)):
			out.append(i)
	return out


func has_trapdoor_access(room: int) -> bool:
	for trapdoor in trapdoors:
		if int(trapdoor.get("lower_room", -1)) == room:
			return true
	return false


func total_floor_area() -> float:
	var a := 0.0
	for i in range(rooms.size()):
		a += HouseGeometry.room_area(self, i)
	return a

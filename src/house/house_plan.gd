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

## {"kind": StringName, "rect": Rect2}
var rooms: Array[Dictionary] = []
## {"a": int, "b": int (-1 outdoors), "pos": Vector2, "normal": Vector2,
##  "width": float, "exterior": bool}
var doors: Array[Dictionary] = []
## {"room": int, "pos": Vector2, "normal": Vector2, "width": float,
##  "sill": float, "head": float}
var windows: Array[Dictionary] = []
## {"key": String, "room": int, "pos": Vector3, "yaw": float, "rect": Rect2,
##  "zone": Rect2, "host": int, "cat": String}
var furniture: Array[Dictionary] = []
## Things a room should have had and does not, because keeping them would have
## blocked the way through the house: {room: [category, ...]}.
##
## A generator that quietly drops furniture is hiding a defect; one that writes
## down what it dropped and why is reporting a compromise. The furnishing check
## reads this and downgrades exactly those complaints to warnings, so a real
## missing bed still fails.
var compromises: Dictionary = {}


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
		if doors[d]["exterior"] and doors[d].get("front", false):
			return d
	for d in range(doors.size()):
		if doors[d]["exterior"]:
			return d
	return -1


func entrance_room() -> int:
	var d: int = entrance()
	return doors[d]["a"] if d >= 0 else -1


## Room-to-room graph as {room: [rooms]}, following doors only. This is what
## "can you get from the front door to the back bedroom" is answered with.
func door_graph() -> Dictionary:
	var g := {}
	for i in range(rooms.size()):
		g[i] = []
	for d in doors:
		var a: int = d["a"]
		var b: int = d["b"]
		if b < 0 or a < 0:
			continue
		g[a].append(b)
		g[b].append(a)
	return g


## Rooms reachable from `start` through doors, optionally refusing to pass
## THROUGH rooms of a given kind (they can still be the destination).
func reachable_rooms(start: int, no_pass_kind := &"") -> Dictionary:
	var seen := {start: true}
	var stack: Array[int] = [start]
	var g: Dictionary = door_graph()
	while not stack.is_empty():
		var cur: int = stack.pop_back()
		if no_pass_kind != &"" and cur != start and kind_of(cur) == no_pass_kind:
			continue          # you may enter it, but not walk on through
		for nb in g[cur]:
			if not seen.has(nb):
				seen[nb] = true
				stack.append(nb)
	return seen


func total_floor_area() -> float:
	var a := 0.0
	for i in range(rooms.size()):
		a += HouseGeometry.room_area(self, i)
	return a

class_name ShopSpec
extends HouseSpec
## A medieval workplace or civic building that uses the proven house plan,
## shell, furnishing, and navigation representation. `business` decides the
## room programme and defining fittings; the inherited style decides the shell.

var business: StringName = &"general_store"


## Four measured rectangles keep the barracks office compact while preserving
## enough frontage for a table and two benches in the mess.
func custom_room_rects(inner: Rect2) -> Array[Rect2]:
	if business == &"palace":
		# The entry room, throne axis, and two private rear branches are one
		# authored topology. Keeping these rectangles stable lets the planner
		# wire the treasury and royal chamber directly to the throne room.
		var entry_depth := inner.size.y * 0.24
		var throne_depth := inner.size.y * 0.48
		var rear_depth := inner.size.y - entry_depth - throne_depth
		var half_width := inner.size.x * 0.5
		return [
			Rect2(inner.position, Vector2(inner.size.x, entry_depth)),
			Rect2(Vector2(inner.position.x, inner.position.y + entry_depth),
				Vector2(inner.size.x, throne_depth)),
			Rect2(Vector2(inner.position.x, inner.position.y + entry_depth + throne_depth),
				Vector2(half_width, rear_depth)),
			Rect2(Vector2(inner.position.x + half_width,
				inner.position.y + entry_depth + throne_depth),
				Vector2(inner.size.x - half_width, rear_depth)),
		]
	if business == &"prison":
		return prison_room_rects(inner)
	if business != &"barracks":
		return []
	var office_w := minf(inner.size.x * 0.37, 7.0)
	var front_d := inner.size.y * 0.19
	var front := Rect2(inner.position, Vector2(office_w, front_d))
	var mess := Rect2(Vector2(inner.position.x + office_w, inner.position.y),
		Vector2(inner.size.x - office_w, front_d))
	var rear_d := (inner.size.y - front_d) * 0.5
	var rear_start := inner.position.y + front_d
	var dorm := Rect2(Vector2(inner.position.x, rear_start), Vector2(inner.size.x, rear_d))
	var armoury := Rect2(Vector2(inner.position.x, rear_start + rear_d),
		Vector2(inner.size.x, inner.end.y - (rear_start + rear_d)))
	return [front, mess, dorm, armoury]


## Parallel corridors open directly from the front guardroom. Each cell bay
## shares one long wall with a corridor and measures two to three metres on
## both sides.
func prison_room_rects(inner: Rect2) -> Array[Rect2]:
	const AISLE := 1.55
	var columns := 0
	var cell_w := 0.0
	for count in range(1, 16):
		var candidate := (inner.size.x - AISLE * float(count + 1)) / float(count)
		if candidate >= 2.15 and candidate <= 3.0:
			columns = count
			cell_w = candidate
	if columns == 0:
		return []
	var guard_depth := maxf(2.8, inner.size.x / 3.4 + 0.15)
	var cell_run := inner.size.y - guard_depth
	if cell_run < 2.0:
		return []
	var min_rows := ceili(cell_run / 3.0)
	var max_rows := floori(cell_run / 2.15)
	var rows := clampi(roundi(cell_run / 2.55), min_rows, max_rows)
	var cell_d := cell_run / float(rows)
	if cell_d < 2.15 or cell_d > 3.0:
		return []
	var out: Array[Rect2] = [Rect2(inner.position, Vector2(inner.size.x, guard_depth))]
	var x := inner.position.x
	var rear := Rect2(inner.position.x, inner.position.y + guard_depth,
		inner.size.x, cell_run)
	var aisles: Array[Rect2] = []
	var cells: Array[Rect2] = []
	for col in range(columns + 1):
		aisles.append(Rect2(Vector2(x, rear.position.y), Vector2(AISLE, cell_run)))
		x += AISLE
		if col >= columns:
			continue
		for row in range(rows):
			cells.append(Rect2(Vector2(x, rear.position.y + cell_d * row),
				Vector2(cell_w, cell_d)))
		x += cell_w
	out.append_array(aisles)
	out.append_array(cells)
	return out


## The front door must open directly into the compact office, even though the
## adjoining mess rectangle is closer to the building centre.
func preferred_front_room_index() -> int:
	return 0 if business in [&"barracks", &"prison", &"palace"] else -1

## Rooms are ordered from the public front toward private/service space.
## The first room replaces the house planner's temporary hall after doors,
## windows, and (when needed) stairs have been laid out.
##
## `focus` is what the front room is arranged around and what the customer
## sees first: the prop category, and whether it must look at the door
## (a counter and a bar do; a forge is against its chimney wall and a
## carpenter's bench is under its window, so those do not). ShopPlanner turns
## it into `HousePlan.focus`; HouseFurnishCheck's `focus` rule proves it is
## there and facing the right way. (INT-002)
const BUSINESSES := {
	&"barracks": {"label": "Barracks / Guardhouse",
		"rooms": [&"office", &"dormitory", &"armoury", &"mess"], "max_rooms": 4,
		"door_w": 1.2, "focus": {"cat": "workbench", "faces_door": false}},
	&"library": {"label": "Library / Archive",
		"rooms": [&"reading_room", &"stacks", &"scriptorium", &"office"], "max_rooms": 4,
		"door_w": 1.2, "focus": {"cat": "lectern", "faces_door": false}},
	&"prison": {"label": "Prison / Dungeon",
		"rooms": [&"guardroom", &"corridor", &"cell"], "max_rooms": 64,
		"door_w": 1.2, "focus": {"cat": "table", "faces_door": false}},
	&"palace": {"label": "Throne Hall / Palace",
		"rooms": [&"antechamber", &"throne_room", &"treasury", &"royal_chamber"],
		"max_rooms": 4, "door_w": 1.2,
		"focus": {"cat": "seat", "faces_door": false}},
	&"blacksmith": {"label": "Blacksmith", "rooms": [&"workshop", &"store", &"office"],
		"door_w": 2.4, "focus": {"cat": "anvil", "faces_door": true}},
	&"stable": {"label": "Stable", "rooms": [&"stable", &"tack_room", &"store", &"office"],
		"door_w": 1.5, "focus": {"cat": "stall", "faces_door": true}},
	&"restaurant": {"label": "Restaurant / Cookshop", "rooms": [&"dining_room", &"kitchen", &"store", &"office"],
		"door_w": 1.0, "focus": {"cat": "counter", "faces_door": true}},
	&"tavern": {"label": "Tavern", "rooms": [&"dining_room", &"kitchen", &"store", &"office"],
		"door_w": 1.0, "focus": {"cat": "counter", "faces_door": true}},
	# The gallery is the inn's corridor (LAY-012): with two guest rooms and no
	# public room between them the planner hangs the second off the first, and
	# the only way to the far bed is through somebody else's -- which is what
	# LAY-007's privacy rule forbids and what the hotel's own gallery
	# (LAY-008) answers. `corridor_at` is the room count below which it is not
	# worth one: an inn with a single guest room needs no corridor, and
	# spending a room on one there would cost it the guest room itself.
	# ShopPlanner._open_up_lodging() holds the invariant either way.
	&"inn": {"label": "Inn", "rooms": [&"dining_room", &"kitchen", &"gallery", &"guest_room", &"guest_room", &"store"],
		"corridor": &"gallery", "corridor_at": 5,
		"door_w": 1.0, "focus": {"cat": "counter", "faces_door": true}},
	&"bakery": {"label": "Bakery", "rooms": [&"sales_floor", &"kitchen", &"workshop", &"store"],
		"door_w": 1.0, "front_open": {"width": 1.6}, "focus": {"cat": "counter", "faces_door": true}},
	&"butcher": {"label": "Butcher", "rooms": [&"sales_floor", &"workshop", &"store"],
		"door_w": 1.0, "front_open": {"width": 1.6}, "focus": {"cat": "counter", "faces_door": true}},
	&"apothecary": {"label": "Apothecary", "rooms": [&"sales_floor", &"workshop", &"store"],
		"door_w": 1.0, "front_open": {"width": 1.4}, "focus": {"cat": "counter", "faces_door": true}},
	&"general_store": {"label": "General Store", "rooms": [&"sales_floor", &"store", &"office"],
		"door_w": 1.0, "front_open": {"width": 1.6}, "focus": {"cat": "counter", "faces_door": true}},
	&"tailor": {"label": "Tailor", "rooms": [&"sales_floor", &"workshop", &"store"],
		"door_w": 1.0, "front_open": {"width": 1.4}, "focus": {"cat": "counter", "faces_door": true}},
	&"carpenter": {"label": "Carpenter", "rooms": [&"workshop", &"sales_floor", &"store"],
		"door_w": 1.2, "focus": {"cat": "workbench", "faces_door": false}},
	&"town_hall": {"label": "Town Hall", "rooms": [&"council_chamber", &"office", &"records", &"store"],
		"door_w": 1.2, "focus": {"cat": "table", "faces_door": false}},
	&"guildhall": {"label": "Guildhall", "rooms": [&"meeting_hall", &"office", &"records", &"store"],
		"door_w": 1.2, "focus": {"cat": "table", "faces_door": false}},
	&"market_hall": {"label": "Market Hall", "rooms": [&"market_hall"],
		"max_rooms": 1, "door_w": 2.0, "focus": {"cat": "counter", "faces_door": true}},
	&"alchemist_laboratory": {"label": "Alchemist Laboratory",
		"rooms": [&"laboratory", &"store", &"office"], "max_rooms": 3,
		"door_w": 1.2, "focus": {"cat": "workbench", "faces_door": false}},
	&"bathhouse": {"label": "Bathhouse",
		"rooms": [&"changing_room", &"bath_hall", &"staff_room"], "max_rooms": 3,
		"door_w": 1.2, "focus": {"cat": "bench", "faces_door": false}},
	&"hospice": {"label": "Hospice",
		"rooms": [&"ward", &"dispensary", &"office"], "max_rooms": 3,
		"door_w": 1.2, "focus": {"cat": "bed", "faces_door": false}},
	&"school": {"label": "School",
		"rooms": [&"schoolroom", &"masters_office", &"store"], "max_rooms": 3,
		"door_w": 1.2, "focus": {"cat": "lectern", "faces_door": false}},
}


## The width of the front door leaf: a horse needs 1.2 m and more, a forge
## opens to the street through 2.4 m so the customer stands outside, a shop
## has a metre. HousePlanner reads it through front_door_width().
func door_w() -> float:
	return float(BUSINESSES[business].get("door_w", HouseGeometry.DOOR_W))


func front_door_width() -> float:
	return door_w()


## The shopfront: a hatch cut in the street wall beside the door, from
## counter height to the door head, {"width": float}; empty for a business
## that has none. ShopPlanner cuts it, HouseBuilder frames it like a window.
func front_open() -> Dictionary:
	return BUSINESSES[business].get("front_open", {})


## The front room's defining fitting: {"cat": String, "faces_door": bool}.
func focus() -> Dictionary:
	return BUSINESSES[business].get("focus", {})


func room_program(count: int) -> Array[StringName]:
	var row: Dictionary = BUSINESSES[business]
	if business == &"palace":
		var palace: Array[StringName] = [&"antechamber", &"throne_room", &"treasury", &"royal_chamber"]
		return palace.slice(0, count)
	if business == &"prison":
		var rects := prison_room_rects(HouseGeometry.interior_rect(self))
		var aisle_count := 0
		var cell_count := 0
		for rect in rects:
			if absf(rect.size.x - 1.55) < 0.01:
				aisle_count += 1
			elif rect.size.x <= 3.0 and rect.size.y <= 3.0:
				cell_count += 1
		var program: Array[StringName] = [&"hall"]
		for _aisle in range(aisle_count):
			program.append(&"corridor")
		for _cell in range(cell_count):
			program.append(&"cell")
		return program.slice(0, count)
	var source: Array = row["rooms"]
	# a corridor is only worth a room when the trade has rooms to spare for
	# it; below that it would displace the very room it exists to serve
	var at: int = int(row.get("corridor_at", 0))
	if at > 0 and count < at:
		source = source.duplicate()
		source.erase(row["corridor"])
	var out: Array[StringName] = [&"hall"]
	for i in range(1, mini(count, source.size())):
		out.append(source[i])
	while out.size() < count:
		out.append(&"store")
	return out


func front_room() -> StringName:
	return BUSINESSES[business]["rooms"][0]

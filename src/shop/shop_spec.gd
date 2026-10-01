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
	if business == &"thieves_den":
		# Three adjoining bays make the hidden route unambiguous: street sales
		# floor -> secret store -> private dormitory. There is no geometric
		# bypass around the concealed partition.
		var bay_w := inner.size.x / 3.0
		return [
			Rect2(inner.position, Vector2(bay_w, inner.size.y)),
			Rect2(inner.position + Vector2(bay_w, 0.0), Vector2(bay_w, inner.size.y)),
			Rect2(inner.position + Vector2(bay_w * 2.0, 0.0),
				Vector2(inner.size.x - bay_w * 2.0, inner.size.y)),
		]
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


## Column widths for the prison cell block: the cell count and the width of
## each of the `count + 1` aisles. An empty Dictionary means the width cannot
## hold a cell block at all.
##
## 1. A standard 1.55 m aisle with 2.25-3.0 m cells, exactly (the original
##    rule, so every width that already had a layout keeps its seed output).
## 2. Otherwise the aisle flexes between 1.4 and 1.8 m, as a warder would
##    widen a passage by a hand to make the bays come out.
## 3. Otherwise (the dead bands near 8, 11.5, 16 and 20 m, where the bays will
##    not tile) the most cells that fit are laid at the width that keeps the
##    aisles nearest 1.55 m, and any remainder is given to the two OUTER
##    aisles, which run along the walls and can be as wide as the building
##    needs without making a cell too large.
static func prison_columns(width: float) -> Dictionary:
	const AISLE := 1.55
	const CELL_MIN := 2.25  # the floor loses 0.2 m to the walls; cells must keep 2.0 m clear
	const CELL_MAX := 3.0
	var best := 0
	for count in range(1, 16):
		var candidate := (width - AISLE * float(count + 1)) / float(count)
		if candidate >= CELL_MIN and candidate <= CELL_MAX:
			best = count
	if best > 0:
		return _prison_columns_uniform(best, (width - AISLE * float(best + 1)) / float(best), AISLE)
	var flex_best := 0
	var flex_aisle := AISLE
	for count in range(1, 16):
		var lo := maxf(1.4, (width - CELL_MAX * float(count)) / float(count + 1))
		var hi := minf(1.8, (width - CELL_MIN * float(count)) / float(count + 1))
		if lo <= hi:
			flex_best = count
			flex_aisle = clampf(AISLE, lo, hi)
	if flex_best > 0:
		return _prison_columns_uniform(flex_best,
			(width - flex_aisle * float(flex_best + 1)) / float(flex_best), flex_aisle)
	var most := 0
	for count in range(1, 16):
		if CELL_MIN * float(count) + 1.4 * float(count + 1) <= width + 0.0001:
			most = count
	if most == 0:
		return {}
	var cell_w := clampf((width - AISLE * float(most + 1)) / float(most), CELL_MIN, CELL_MAX)
	var spare := width - cell_w * float(most) - AISLE * float(most + 1)
	if spare < 0.0:
		return _prison_columns_uniform(most, cell_w,
			(width - cell_w * float(most)) / float(most + 1))
	var aisles: Array[float] = []
	for i in range(most + 1):
		aisles.append(AISLE + (spare * 0.5 if i == 0 or i == most else 0.0))
	return {"cells": most, "cell_w": cell_w, "aisles": aisles}


static func _prison_columns_uniform(count: int, cell_w: float, aisle: float) -> Dictionary:
	var aisles: Array[float] = []
	for i in range(count + 1):
		aisles.append(aisle)
	return {"cells": count, "cell_w": cell_w, "aisles": aisles}


## The prison split into its three kinds: {"guard": Rect2, "aisles": Array[Rect2],
## "cells": Array[Rect2]}. Empty when the footprint cannot hold a guardroom, a
## corridor and at least three cells.
func prison_layout(inner: Rect2) -> Dictionary:
	var cols := prison_columns(inner.size.x)
	if cols.is_empty():
		return {}
	var columns: int = cols["cells"]
	var cell_w: float = cols["cell_w"]
	var aisle_w: Array = cols["aisles"]
	var guard_depth := maxf(2.8, inner.size.x / 3.4 + 0.15)
	var cell_run := inner.size.y - guard_depth
	if cell_run < 2.0:
		return {}
	var min_rows := ceili(cell_run / 3.0)
	var max_rows := floori(cell_run / 2.25)
	if max_rows < 1:
		return {}
	var rows := clampi(roundi(cell_run / 2.55), min_rows, max_rows)
	var cell_d := cell_run / float(rows)
	if cell_d < 2.25 or cell_d > 3.0 or columns * rows < 3:
		return {}
	var top := inner.position.y + guard_depth
	var x := inner.position.x
	var aisles: Array[Rect2] = []
	var cells: Array[Rect2] = []
	for col in range(columns + 1):
		aisles.append(Rect2(Vector2(x, top), Vector2(float(aisle_w[col]), cell_run)))
		x += float(aisle_w[col])
		if col >= columns:
			continue
		for row in range(rows):
			cells.append(Rect2(Vector2(x, top + cell_d * row), Vector2(cell_w, cell_d)))
		x += cell_w
	return {"guard": Rect2(inner.position, Vector2(inner.size.x, guard_depth)),
		"aisles": aisles, "cells": cells}


## Parallel corridors open directly from the front guardroom. Each cell bay
## shares one long wall with a corridor and measures two to three metres on
## both sides. Order: guardroom, every aisle, every cell.
func prison_room_rects(inner: Rect2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var layout := prison_layout(inner)
	if layout.is_empty():
		return out
	out.append(layout["guard"])
	out.append_array(layout["aisles"])
	out.append_array(layout["cells"])
	return out


## The front door must open directly into the compact office, even though the
## adjoining mess rectangle is closer to the building centre.
func preferred_front_room_index() -> int:
	return 0 if business in [&"barracks", &"prison", &"palace", &"thieves_den"] else -1

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
		"door_w": 1.2, "focus": {}},
	&"bathhouse": {"label": "Bathhouse",
		"rooms": [&"changing_room", &"bath_hall", &"staff_room"], "max_rooms": 3,
		"door_w": 1.2, "focus": {}},
	&"hospice": {"label": "Hospice",
		"rooms": [&"ward", &"dispensary", &"office"], "max_rooms": 3,
		"door_w": 1.2, "focus": {}},
	&"school": {"label": "School",
		"rooms": [&"schoolroom", &"masters_office", &"store"], "max_rooms": 3,
		"door_w": 1.2, "focus": {"cat": "lectern", "faces_door": false}},
	&"thieves_den": {"label": "Thieves' Den",
		"rooms": [&"sales_floor", &"store", &"dormitory"], "max_rooms": 3,
		"door_w": 1.0, "front_open": {"width": 1.6},
		"focus": {"cat": "counter", "faces_door": true}},
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
		var layout := prison_layout(HouseGeometry.interior_rect(self))
		var aisle_count := (layout["aisles"] as Array).size() if not layout.is_empty() else 0
		var cell_count := (layout["cells"] as Array).size() if not layout.is_empty() else 0
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

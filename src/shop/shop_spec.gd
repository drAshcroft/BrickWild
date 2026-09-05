class_name ShopSpec
extends HouseSpec
## A medieval workplace or civic building that uses the proven house plan,
## shell, furnishing, and navigation representation. `business` decides the
## room programme and defining fittings; the inherited style decides the shell.

var business: StringName = &"general_store"

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
	&"blacksmith": {"label": "Blacksmith", "rooms": [&"workshop", &"store", &"office"],
		"door_w": 2.4, "focus": {"cat": "anvil", "faces_door": true}},
	&"stable": {"label": "Stable", "rooms": [&"stable", &"tack_room", &"store", &"office"],
		"door_w": 1.5, "focus": {"cat": "stall", "faces_door": true}},
	&"restaurant": {"label": "Restaurant / Cookshop", "rooms": [&"dining_room", &"kitchen", &"store", &"office"],
		"door_w": 1.0, "focus": {"cat": "counter", "faces_door": true}},
	&"tavern": {"label": "Tavern", "rooms": [&"dining_room", &"kitchen", &"store", &"office"],
		"door_w": 1.0, "focus": {"cat": "counter", "faces_door": true}},
	&"inn": {"label": "Inn", "rooms": [&"dining_room", &"kitchen", &"guest_room", &"guest_room", &"store"],
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
	var source: Array = BUSINESSES[business]["rooms"]
	var out: Array[StringName] = [&"hall"]
	for i in range(1, mini(count, source.size())):
		out.append(source[i])
	while out.size() < count:
		out.append(&"store")
	return out


func front_room() -> StringName:
	return BUSINESSES[business]["rooms"][0]

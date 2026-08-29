class_name ShopSpec
extends HouseSpec
## A medieval workplace or civic building that uses the proven house plan,
## shell, furnishing, and navigation representation. `business` decides the
## room programme and defining fittings; the inherited style decides the shell.

var business: StringName = &"general_store"

## Rooms are ordered from the public front toward private/service space.
## The first room replaces the house planner's temporary hall after doors,
## windows, and (when needed) stairs have been laid out.
const BUSINESSES := {
	&"blacksmith": {"label": "Blacksmith", "rooms": [&"workshop", &"store", &"office"]},
	&"stable": {"label": "Stable", "rooms": [&"stable", &"tack_room", &"store", &"office"]},
	&"restaurant": {"label": "Restaurant / Cookshop", "rooms": [&"dining_room", &"kitchen", &"store", &"office"]},
	&"tavern": {"label": "Tavern", "rooms": [&"dining_room", &"kitchen", &"store", &"office"]},
	&"inn": {"label": "Inn", "rooms": [&"dining_room", &"kitchen", &"guest_room", &"guest_room", &"store"]},
	&"bakery": {"label": "Bakery", "rooms": [&"sales_floor", &"kitchen", &"workshop", &"store"]},
	&"butcher": {"label": "Butcher", "rooms": [&"sales_floor", &"workshop", &"store"]},
	&"apothecary": {"label": "Apothecary", "rooms": [&"sales_floor", &"workshop", &"store"]},
	&"general_store": {"label": "General Store", "rooms": [&"sales_floor", &"store", &"office"]},
	&"tailor": {"label": "Tailor", "rooms": [&"sales_floor", &"workshop", &"store"]},
	&"carpenter": {"label": "Carpenter", "rooms": [&"workshop", &"sales_floor", &"store"]},
	&"town_hall": {"label": "Town Hall", "rooms": [&"council_chamber", &"office", &"records", &"store"]},
	&"guildhall": {"label": "Guildhall", "rooms": [&"meeting_hall", &"office", &"records", &"store"]},
}


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

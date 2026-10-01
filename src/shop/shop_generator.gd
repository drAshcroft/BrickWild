class_name ShopGenerator
extends RefCounted
## Generates a deterministic medieval workplace, then plans and furnishes it.

const FIRST_WORDS := ["Bell", "Boar", "Copper", "Crown", "Fox", "King",
	"Lantern", "Oak", "Plough", "Raven", "Rose", "Wheel"]
const SECOND_WORDS := ["and Anvil", "and Cask", "and Crown", "and Hearth",
	"and Horseshoe", "and Quill", "at the Bridge", "by the Gate", "on Market Row"]


static func generate(spec: ShopSpec, p_seed: int, with_furniture := true) -> HousePlan:
	spec.seed = p_seed
	spec.rng.seed = p_seed
	spec.storeys = clampi(spec.storeys, 1, 3)
	var style: Dictionary = HouseSpec.STYLES[spec.style]
	var r := spec.rng

	spec.roof_pitch = r.randf_range(float(style["roof_pitch"][0]), float(style["roof_pitch"][1]))
	spec.porch = r.randf() < float(style["porch"])
	spec.chimney = r.randf() < float(style["chimney"])
	# a smithy or a bakehouse is its fire: the flue is not a dice roll
	if spec.business in [&"blacksmith", &"bakery", &"library"]:
		spec.chimney = true
	# Guardrooms have an office, dormitory, armoury and mess, with no fire
	# planned in any of them. A chimney without a hearth is an unsupported stack.
	if spec.business in [&"barracks", &"market_hall"]:
		spec.chimney = false
	if spec.business in [&"prison", &"palace", &"thieves_den"]:
		spec.chimney = false
	if spec.business == &"palace":
		spec.back_door = false
		spec.storeys = 1
		spec.cellars = 0
	if spec.business == &"prison":
		spec.storeys = 1
		spec.cellars = 1
	spec.window_shutters = r.randf() < float(style["shutters"])
	spec.timber_frame = r.randf() < float(style["timber"])
	spec.stud_pitch = r.randf_range(float(style["studs"][0]), float(style["studs"][1]))
	spec.frame_braces = spec.timber_frame and r.randf() < float(style["braces"])
	spec.frame_rail = spec.timber_frame and r.randf() < float(style["rail"])
	spec.clutter = r.randf_range(float(style["clutter"][0]), float(style["clutter"][1]))
	if spec.business == &"prison":
		spec.clutter = 0.0

	var inner: Rect2 = HouseGeometry.interior_rect(spec)
	if spec.business == &"prison":
		spec.room_count = spec.prison_room_rects(inner).size()
	elif spec.business == &"palace":
		spec.room_count = 4
	else:
		spec.room_count = HouseSpec.rooms_for(inner.size.x * inner.size.y)
	spec.room_count = mini(spec.room_count, int(ShopSpec.BUSINESSES[spec.business].get("max_rooms", 6)))
	spec.program = spec.room_program(spec.room_count)
	spec.back_door = spec.business not in [&"prison", &"palace", &"thieves_den"] \
		and spec.room_count >= 3 and r.randf() < 0.7
	spec.wall_color = Color(style["wall"][0]).lerp(Color(style["wall"][1]), r.randf())
	spec.trim_color = Color(style["trim"][0]).lerp(Color(style["trim"][1]), r.randf())
	spec.roof_color = Color(style["roof"][0]).lerp(Color(style["roof"][1]), r.randf())
	spec.floor_color = Color(style["floor"][0]).lerp(Color(style["floor"][1]), r.randf())
	spec.variant_name = "%s %s" % [FIRST_WORDS[r.randi() % FIRST_WORDS.size()],
		SECOND_WORDS[r.randi() % SECOND_WORDS.size()]]

	var plan := ShopPlanner.plan(spec)
	if with_furniture:
		HouseFurnisher.furnish(plan, spec)
		if spec.business == &"palace":
			ShopPlanner.place_palace_banners(plan)
	for placement in plan.furniture:
		var room: int = int(placement.get("room", -1))
		placement["storey"] = plan.storey_of_room(room) if room >= 0 \
			and room < plan.rooms.size() else 0
	return plan

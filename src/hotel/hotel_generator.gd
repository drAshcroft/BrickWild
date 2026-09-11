class_name HotelGenerator
extends RefCounted
## Seeded landmark proportions and furnishing over the authored hotel plan.

const NAMES := ["Grand Rose Hotel", "The Zubrowka Palace", "Imperial Alpine Hotel",
	"The Pink Crown", "Grand Foxglove Hotel", "The Royal Mendl"]


static func generate(spec: HotelSpec, p_seed: int, with_furniture := true) -> HousePlan:
	spec.seed = p_seed
	spec.rng.seed = p_seed
	spec.storeys = 3
	spec.width = clampf(spec.width, HotelGeometry.MIN_WIDTH, HotelGeometry.MAX_WIDTH)
	spec.length = clampf(spec.length, HotelGeometry.MIN_LENGTH, HotelGeometry.MAX_LENGTH)
	spec.height = clampf(spec.height, HotelGeometry.MIN_FLOOR_H, HotelGeometry.MAX_FLOOR_H)
	var style: Dictionary = HotelSpec.HOTEL_STYLES[spec.style]
	var r := spec.rng
	spec.facade_bays = _odd(clampi(int(spec.width / r.randf_range(2.8, 3.5)), 11, 21))
	spec.centre_fraction = r.randf_range(0.31, 0.37)
	spec.roof_rise = r.randf_range(style["roof_rise"][0], style["roof_rise"][1])
	spec.ornament = r.randf_range(style["ornament"][0], style["ornament"][1])
	spec.dormer_count = _odd(clampi(int(spec.width / 5.2), 7, 13))
	spec.balconies = 3
	spec.cupolas = true
	spec.roof_pitch = spec.roof_rise / maxf(spec.length, 1.0)
	spec.porch = false
	spec.chimney = false
	spec.window_shutters = false
	spec.timber_frame = false
	spec.stud_pitch = 1.0
	spec.frame_braces = false
	spec.frame_rail = false
	spec.clutter = r.randf_range(0.58, 0.78)
	spec.room_count = HotelPlanner.rooms_on_level(spec, 0)
	spec.program = HotelPlanner.GROUND_KINDS.duplicate()
	spec.wall_color = Color(style["wall"][0]).lerp(Color(style["wall"][1]), r.randf())
	spec.trim_color = Color(style["trim"][0]).lerp(Color(style["trim"][1]), r.randf())
	spec.roof_color = Color(style["roof"][0]).lerp(Color(style["roof"][1]), r.randf())
	spec.floor_color = Color(style["floor"][0]).lerp(Color(style["floor"][1]), r.randf())
	spec.variant_name = NAMES[r.randi_range(0, NAMES.size() - 1)]

	var plan := HotelPlanner.plan(spec)
	if with_furniture:
		HouseFurnisher.furnish(plan, spec)
	for placement in plan.furniture:
		var room: int = int(placement.get("room", -1))
		placement["storey"] = plan.storey_of_room(room) if room >= 0 \
			and room < plan.rooms.size() else 0
	return plan


static func _odd(value: int) -> int:
	return value if value % 2 == 1 else value + 1

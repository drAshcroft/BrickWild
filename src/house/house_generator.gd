class_name HouseGenerator
extends RefCounted
## Fills a HouseSpec's derived fields, plans the rooms and furnishes them.
##
## Everything a builder could otherwise be tempted to decide mid-build happens
## here: how many rooms the floor area can carry, which of them the trade needs,
## how heavily to dress them. HouseBuilder.build() then reads a finished plan
## and only emits geometry, so the QA suites judge the same plan the mesh came
## from rather than a second, luckier one.

const FIRST_WORDS := ["Alder", "Bramble", "Copper", "Ember", "Fern", "Hollow",
	"Larkspur", "Millstone", "Nettle", "Rook", "Thistle", "Willow"]
const SECOND_WORDS := ["barrow", "brook", "coombe", "croft", "gate", "hearth",
	"hollow", "mill", "row", "stile", "thatch", "well"]
const SUFFIXES := ["", "", " Cottage", " House", " Lodge", " Steading"]


## Generate the spec's derived fields, then plan and furnish. Returns the plan,
## which is what the builder and every check take from here on.
static func generate(spec: HouseSpec, p_seed: int) -> HousePlan:
	spec.seed = p_seed
	spec.rng.seed = p_seed
	var s: Dictionary = HouseSpec.STYLES[spec.style]
	var r := spec.rng

	spec.roof_pitch = r.randf_range(float(s["roof_pitch"][0]), float(s["roof_pitch"][1]))
	spec.porch = _chance(r, s["porch"])
	spec.chimney = _chance(r, s["chimney"])
	spec.window_shutters = _chance(r, s["shutters"])
	spec.clutter = r.randf_range(float(s["clutter"][0]), float(s["clutter"][1]))

	var inner: Rect2 = HouseGeometry.interior_rect(spec)
	var area: float = inner.size.x * inner.size.y
	spec.room_count = HouseSpec.rooms_for(area)
	spec.program = _program_for(spec)
	# a back door is only worth having when there is a room at the back to put
	# it in, and something to go out to
	spec.back_door = spec.room_count >= 3 and _chance(r, 0.55)

	spec.wall_color = Color(s["wall"][0]).lerp(Color(s["wall"][1]), r.randf())
	spec.trim_color = Color(s["trim"][0]).lerp(Color(s["trim"][1]), r.randf())
	spec.roof_color = Color(s["roof"][0]).lerp(Color(s["roof"][1]), r.randf())
	spec.floor_color = Color(s["floor"][0]).lerp(Color(s["floor"][1]), r.randf())

	spec.variant_name = "%s%s%s" % [_pick(r, FIRST_WORDS), _pick(r, SECOND_WORDS),
		_pick(r, SUFFIXES)]

	var plan: HousePlan = HousePlanner.plan(spec)
	HouseFurnisher.furnish(plan, spec)
	return plan


## The room program: the standard sequence, with the trade's own room promoted
## so a smith gets a workshop before a second bedroom.
static func _program_for(spec: HouseSpec) -> Array[StringName]:
	var out: Array[StringName] = []
	var trade_room: StringName = HouseSpec.TRADES[spec.trade]["room"]
	for kind in HouseSpec.PROGRAM:
		out.append(kind)
	if trade_room != &"" and spec.room_count >= 2:
		out.erase(trade_room)
		out.insert(mini(2, out.size()), trade_room)
	return out


static func _chance(r: RandomNumberGenerator, p) -> bool:
	return r.randf() < float(p)


static func _pick(r: RandomNumberGenerator, arr: Array):
	return arr[r.randi_range(0, arr.size() - 1)]

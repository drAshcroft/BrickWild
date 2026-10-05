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

## How deep a veranda reaches out from the wall it stands on, in metres. Wide
## enough to sit and work in, shallow enough that a five-metre house still has
## a yard behind the posts.
const VERANDA_DEPTH_RANGE := [1.35, 1.85]


## Generate the spec's derived fields, then plan and furnish. Returns the plan,
## which is what the builder and every check take from here on.
static func generate(spec: HouseSpec, p_seed: int, with_furniture := true) -> HousePlan:
	spec.seed = p_seed
	spec.rng.seed = p_seed
	spec.storeys = clampi(spec.storeys, 1, 3)
	spec.cellars = clampi(spec.cellars, 0, 1)
	var s: Dictionary = HouseSpec.STYLES[spec.style]
	var r := spec.rng
	# A style row may ask for a storey floor (HOUSE-RICH). A rich house is read
	# as banded storeys, and a single storey has no band to read. It comes from
	# the style table rather than from the stream, so it is deterministic and no
	# other style carries one.
	spec.storeys = maxi(spec.storeys, int(s.get("min_storeys", 1)))

	spec.roof_pitch = r.randf_range(float(s["roof_pitch"][0]), float(s["roof_pitch"][1]))
	spec.roof_pitch *= HouseGeometry.art_pitch_scale(spec)
	spec.porch = GeneratorRandom.chance(r, s["porch"])
	spec.chimney = GeneratorRandom.chance(r, s["chimney"])
	spec.window_shutters = GeneratorRandom.chance(r, s["shutters"])
	spec.timber_frame = GeneratorRandom.chance(r, s["timber"])
	spec.stud_pitch = r.randf_range(float(s["studs"][0]), float(s["studs"][1]))
	spec.frame_braces = spec.timber_frame and GeneratorRandom.chance(r, s["braces"])
	spec.frame_rail = spec.timber_frame and GeneratorRandom.chance(r, s["rail"])
	spec.clutter = r.randf_range(float(s["clutter"][0]), float(s["clutter"][1]))

	# exterior architectural variety
	var plinth_range: Array = s.get("plinth", [0.35, 0.55])
	spec.plinth_height = r.randf_range(float(plinth_range[0]), float(plinth_range[1]))
	spec.stone_ground_floor = spec.storeys > 1 and GeneratorRandom.chance(r, float(s.get("stone_ground", 0.15)))
	spec.jetty = spec.storeys > 1 and GeneratorRandom.chance(r, float(s.get("jetty", 0.5)))
	spec.jetty_depth = r.randf_range(0.24, 0.32)
	spec.roof_material = StringName(s.get("roof_material", &"shingle"))
	# A style row may ask for a thicker wall than a timber frame needs. It is
	# set BEFORE planning so the interior, the openings and the emitted
	# masonry are all measured against the same wall.
	var wall_t := float(s.get("wall_t", 0.0))
	spec.wall_thickness_override = wall_t if wall_t > 0.0 else -1.0
	spec.roof_span_out = float(s.get("span_out", -1.0))
	spec.roof_along_out = float(s.get("along_out", -1.0))
	var roof_types: Array = s.get("roof_types", [&"gable", &"half_hipped"])
	spec.roof_type = GeneratorRandom.pick(r, roof_types)
	# Read the same roll for a rotated footprint without shifting the historic
	# RNG stream for subsequent framing, colours and furniture choices.
	var dormer_rng := RandomNumberGenerator.new()
	dormer_rng.state = r.state
	var wants_dormers := GeneratorRandom.chance(dormer_rng, float(s.get("dormers", 0.4)))
	if spec.storeys > 1 or spec.length >= 12.0:
		r.randf()
	spec.dormers = (spec.storeys > 1 or maxf(spec.width, spec.length) >= 12.0) and wants_dormers
	spec.dormer_count = clampi(int(maxf(spec.width, spec.length) / 5.0), 1, 3) if spec.dormers else 0
	var framing_patterns: Array = s.get("framing", [&"square_panel", &"arch_brace"])
	spec.framing_pattern = GeneratorRandom.pick(r, framing_patterns)
	var trusses: Array = s.get("truss", [&"king_post", &"queen_post"])
	spec.gable_truss = GeneratorRandom.pick(r, trusses)
	spec.bargeboards = GeneratorRandom.chance(r, float(s.get("bargeboards", 0.85)))
	spec.window_mullions = true
	spec.window_hoods = GeneratorRandom.chance(r, 0.6)
	spec.chimney_style = s.get("chimney_style", &"stepped")
	var pots_range: Array = s.get("pots", [1, 2])
	spec.chimney_pots = r.randi_range(int(pots_range[0]), int(pots_range[1]))

	# HOUSE-RICH ornament. A style row with no "cornice" key is an ordinary house
	# and takes NO draw here: four rolls behind one `if` is what keeps adding
	# rich from moving a single existing seed's plan, roof or furniture.
	if s.has("cornice"):
		spec.cornice = GeneratorRandom.chance(r, float(s["cornice"]))
		var bands: Array = s.get("string_courses", [0, 0])
		spec.string_courses = r.randi_range(int(bands[0]), int(bands[1]))
		spec.pediments = GeneratorRandom.chance(r, float(s.get("pediments", 0.0)))
		spec.ridge_finial = GeneratorRandom.chance(r, float(s.get("ridge_finial", 0.0)))

	# HOUSE-CULTURE: the vernacular switchboard. Same guard, same reason as the
	# four rolls above -- a row with no "culture" key is a European house and
	# takes no draw here at all, so adding five styles moved nothing.
	if s.has("culture"):
		spec.parapet = GeneratorRandom.chance(r, float(s.get("parapet", 0.0)))
		spec.veranda = GeneratorRandom.chance(r, float(s.get("veranda", 0.0)))
		spec.eave_sweep = GeneratorRandom.chance(r, float(s.get("eave_sweep", 0.0)))
		spec.thatch_roll = GeneratorRandom.chance(r, float(s.get("thatch_roll", 0.0)))
		spec.corner_piers = GeneratorRandom.chance(r, float(s.get("corner_piers", 0.0)))
		spec.veranda_depth = r.randf_range(VERANDA_DEPTH_RANGE[0], VERANDA_DEPTH_RANGE[1])
		# A cone has no eave to stand a wall on: its skirt runs out to the plan
		# rectangle, so a parapet round it would wall off the hut's own base.
		# Said here, where the roof type has already been drawn, rather than
		# leaving an emitter to work out why it should refuse.
		spec.parapet = spec.parapet and spec.roof_type != &"conical"

	var inner: Rect2 = HouseGeometry.interior_rect(spec)
	var area: float = inner.size.x * inner.size.y
	spec.room_count = HouseSpec.rooms_for(area)
	spec.program = _program_for(spec)
	# a back door is only worth having when there is a room at the back to put
	# it in, and something to go out to
	spec.back_door = spec.room_count >= 3 and GeneratorRandom.chance(r, 0.55)

	spec.wall_color = Color(s["wall"][0]).lerp(Color(s["wall"][1]), r.randf())
	spec.trim_color = Color(s["trim"][0]).lerp(Color(s["trim"][1]), r.randf())
	spec.roof_color = Color(s["roof"][0]).lerp(Color(s["roof"][1]), r.randf())
	spec.floor_color = Color(s["floor"][0]).lerp(Color(s["floor"][1]), r.randf())

	spec.variant_name = "%s%s%s" % [GeneratorRandom.pick(r, FIRST_WORDS), GeneratorRandom.pick(r, SECOND_WORDS),
		GeneratorRandom.pick(r, SUFFIXES)]

	var plan: HousePlan = HousePlanner.plan(spec)
	if with_furniture:
		HouseFurnisher.furnish(plan, spec)
	# HouseFurnisher deliberately works from room IDs and legacy 2D rectangles.
	# Stamp the explicit level on its records here so consumers can already
	# distinguish stacked placements without changing that independent placer.
	for placement in plan.furniture:
		var room: int = int(placement.get("room", -1))
		placement["storey"] = plan.storey_of_room(room) if room >= 0 \
			and room < plan.rooms.size() else 0
	HouseExterior.dress(plan)
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

class_name CastleGenerator
extends RefCounted
## Fills a CastleSpec's derived fields from (style, seed) while respecting the
## user-locked footprint and wall height. Also assigns a human-readable name.
##
## Every decision that could make the builder produce impossible geometry is
## taken HERE and clamped against CastleGeometry, for the same reason
## ChurchGenerator does it: CastleBuilder.build() must be a pure function of the
## spec it is handed. A builder that rewrites its own input blinds the QA suite
## to exactly the cases that forced the rewrite.

const FIRST_WORDS := ["Aber", "Black", "Grey", "High", "Iron", "Old", "Raven",
	"Red", "Stone", "Thorn", "White", "Wolf"]
const SECOND_WORDS := ["burgh", "cairn", "cliffe", "fell", "garde", "holt",
	"march", "mere", "moor", "reach", "stead", "watch"]
const SUFFIXES := [" Castle", " Keep", " Hall", " Manor", " Hold", " Court",
	" Fortress", ""]

## Suffixes that suit each tier, so a cottage is not christened a fortress.
const TIER_SUFFIXES := {
	&"house": [" Cottage", " House", " Croft", " Farm"],
	&"manor": [" Manor", " Hall", " Court", " Grange"],
	&"castle": [" Castle", " Keep", " Hold", " Tower"],
	&"fortress": [" Fortress", " Citadel", " Castle", " Bastion"],
}


static func generate(spec: CastleSpec, p_seed: int) -> void:
	# A spec may be regenerated after a caller changes style or plan override.
	# The fallback belongs to one failed terraced fit only.
	spec.terraced_fallback = false
	spec.seed = p_seed
	spec.rng.seed = p_seed
	var s: Dictionary = CastleSpec.STYLES[spec.style]
	var r := spec.rng
	spec.curved_edges = bool(s.get("curved_edges", false))

	spec.tier = spec.tier_override if spec.tier_override != &"" \
		else CastleSpec.tier_for(spec.width, spec.length)
	var enclosed: bool = spec.tier == &"castle" or spec.tier == &"fortress"

	# ---- the plan ----
	# Drawn from CastleSpec.plan_for, which has a generator of its own: the
	# shape of the enceinte must not consume `spec.rng`, or choosing a hexagon
	# would silently redesign every tower, gate and keep after it.
	var plan: Dictionary = CastleSpec.plan_for(spec.style, spec.tier, p_seed)
	spec.plan_kind = spec.plan_override if spec.plan_override != &"" \
		else plan["kind"]
	if spec.plan_override == &"" and CastleSpec.tower_house_for(spec.style, spec.tier,
			p_seed, spec.width, spec.length, spec.height):
		spec.plan_kind = &"tower_house"
	# Keep this plan confined to compact Norman castle sites. The canonical
	# castle sweep uses 40m and 60m widths, so those established fixtures retain
	# their current plans while Marksburg-scale sites can select it naturally.
	if spec.plan_kind == &"bergfried" and (spec.tier != &"castle" \
			or spec.style != &"norman" or spec.width < 42.0 or spec.width > 55.0 \
			or spec.length < 42.0 or spec.length > 60.0):
		spec.plan_kind = &"rect"
	spec.sides = 4
	if spec.plan_kind in [&"polygon", &"terraced"]:
		spec.sides = clampi(spec.sides_override if spec.sides_override > 0 \
			else int(plan["sides"]), CastleGeometry.POLY_MIN_SIDES,
			CastleGeometry.POLY_MAX_SIDES)
	elif spec.plan_kind == &"bergfried":
		spec.sides = clampi(spec.sides_override if spec.sides_override > 0 \
			else int(plan["sides"]), 4, 6)
	# a tower house is a proportion before it is a plan: a site not twice as
	# tall as it is wide is a house, whatever was asked for
	if spec.plan_kind == &"tower_house" and (enclosed
			or spec.height < 2.0 * maxf(spec.width, spec.length)):
		spec.plan_kind = &"rect"
	# a ridge needs a walled tier and a site long enough to string ranges on
	if spec.plan_kind == &"ridge" and (not enclosed
			or maxf(spec.width, spec.length) < 3.0 * CastleGeometry.RIDGE_RANGE_W_MIN):
		spec.plan_kind = &"rect"
	# a ridge castle has no enceinte: nothing below that is about the curtain,
	# the gate or the bailey applies to it
	enclosed = CastleGeometry.is_enclosed(spec)
	var short_side: float = minf(spec.width, spec.length)

	# ---- walls ----
	spec.curtain = enclosed
	if spec.plan_kind == &"water" and enclosed:
		spec.ditch_width = clampf(spec.width * 0.16, 8.0, 25.0)
	spec.batter = float(s["batter"])
	spec.wall_thickness = clampf(spec.height * 0.22, 0.8, minf(5.0, short_side * 0.1))
	spec.battlements = GeneratorRandom.chance(r, s["battlements"])
	spec.merlon_h = clampf(spec.height * 0.09, 0.5, 1.6)
	spec.merlon_profile = s.get("merlon_profile", &"block")
	if spec.merlon_profile == &"spike":
		spec.merlon_h *= 3.0
	spec.roof_pitch = r.randf_range(float(s["roof_pitch"][0]), float(s["roof_pitch"][1]))

	# ---- towers ----
	spec.tower_shape = s["tower_shape"]
	spec.tower_roof = GeneratorRandom.pick(r, s["tower_roof"])
	spec.tower_height = spec.height * r.randf_range(1.15, 1.55)
	spec.tower_size = clampf(short_side * r.randf_range(0.055, 0.085), 2.0, 8.0)
	spec.corner_towers = enclosed or (spec.tier == &"manor" and GeneratorRandom.chance(r, 0.5))
	spec.side_towers = GeneratorRandom.pick(r, s["side_towers"]) if enclosed else 0
	# one tower bigger than the rest (CAS-002), on its own generator so the
	# rest of the design does not move
	var great: Dictionary = CastleSpec.great_tower_for(spec.style, spec.tier, p_seed,
		CastleGeometry.plan_sides(spec) if enclosed else 0)
	spec.great_tower = int(great["vertex"])
	spec.great_tower_scale = float(great["scale"])
	_fit_towers(spec)

	# ---- gate ----
	spec.gatehouse = enclosed
	spec.gate_width = clampf(spec.width * r.randf_range(0.16, 0.26), 3.5, 20.0)
	spec.gate_depth = spec.wall_thickness + r.randf_range(3.0, 6.0)
	spec.gate_towers = enclosed and GeneratorRandom.chance(r, s["gate_towers"])
	spec.barbican = spec.tier == &"fortress" and GeneratorRandom.chance(r, s["barbican"])

	# ---- inner ward: a fortress is a castle with a second enceinte ----
	spec.inner_ward = false
	spec.ward_gap = 0.0
	if spec.tier == &"fortress" and spec.plan_kind != &"motte_bailey":
		_fit_inner_ward(spec, r)
	if spec.plan_kind == &"terraced" and enclosed:
		spec.terrace_rise = maxf(spec.terrace_rise, 3.0)
		force_inner_ward(spec, minf(spec.width, spec.length) * 0.16)
		if not spec.inner_ward:
			spec.terraced_fallback = true
			spec.plan_kind = &"polygon"
	var motte_size := Vector2.ZERO
	if spec.plan_kind == &"motte_bailey" and enclosed:
		_fit_motte(spec, r)
		motte_size = Vector2(spec.keep_w, spec.keep_l)

	# ---- what stands inside, or IS the building ----
	spec.keep = enclosed
	spec.keep_shape = GeneratorRandom.pick(r, s["keep_shape"])
	spec.hall = true
	spec.chapel = false
	spec.wings = 0
	spec.courtyard = false
	spec.chimneys = 0
	match spec.tier:
		&"house":
			spec.wings = 1 if GeneratorRandom.chance(r, 0.55) else 0
			spec.chimneys = GeneratorRandom.pick(r, [1, 1, 2]) if int(s["chimneys"][0]) > 0 else 0
			spec.chimneys = mini(spec.chimneys, CastleGeometry.max_chimneys(spec))
		&"manor":
			spec.wings = GeneratorRandom.pick(r, s["wings"])
			spec.courtyard = spec.wings >= 2 and GeneratorRandom.chance(r, 0.5)
			spec.chimneys = mini(GeneratorRandom.pick(r, s["chimneys"]),
				CastleGeometry.max_chimneys(spec))
		_:
			_fit_bailey_buildings(spec, r)
	if spec.plan_kind == &"tower_house":
		_fit_tower_house(spec, r)
	if CastleGeometry.is_motte(spec):
		# the keep is on the mound, not in the bailey
		spec.keep = false
		# Bailey fitting still consumes its normal draws for the hall/chapel,
		# but its long narrow keep cap cannot replace the occupied mound oval.
		spec.keep_w = motte_size.x
		spec.keep_l = motte_size.y
		spec.keep_shape = &"shell"
		_fit_motte_keep(spec)
	if CastleGeometry.is_ridge(spec):
		_fit_ridge(spec, r)
		if spec.style == &"dark":
			spec.great_tower = -1
			spec.great_tower_scale = 1.0
		else:
			var great_r: Dictionary = CastleSpec.great_tower_for(spec.style, spec.tier, p_seed,
				CastleGeometry.spine(spec).size())
			spec.great_tower = int(great_r["vertex"])
			spec.great_tower_scale = float(great_r["scale"])
	if CastleGeometry.is_sky(spec):
		_fit_sky(spec)
	if spec.plan_kind == &"terraced" and spec.keep:
		spec.keep_height = maxf(spec.keep_height,
			CastleGeometry.gate_height(spec, 1) + 10.0)
	if spec.plan_kind == &"bergfried":
		_fit_bergfried(spec)

	# ---- openings ----
	spec.window_style = s["windows"]
	spec.dormers = GeneratorRandom.chance(r, s["dormers"])
	spec.window_w = {"slit": 0.32, "square": 1.0, "mullioned": 1.3, "arched": 0.9
		}[String(spec.window_style)]
	spec.window_h = {"slit": 1.5, "square": 1.1, "mullioned": 1.9, "arched": 1.7
		}[String(spec.window_style)]
	_fit_inner_gate_forebuilding(spec)

	# ---- palette ----
	spec.stone_color = Color(s["stone"][0]).lerp(Color(s["stone"][1]), r.randf())
	spec.roof_color = Color(s["roof"][0]).lerp(Color(s["roof"][1]), r.randf())
	spec.trim_color = spec.stone_color.darkened(0.18)

	spec.variant_name = "%s%s%s" % [GeneratorRandom.pick(r, FIRST_WORDS), GeneratorRandom.pick(r, SECOND_WORDS),
		GeneratorRandom.pick(r, TIER_SUFFIXES[spec.tier])]


## Re-settle everything that depends on the SHAPE of the enceinte, for a spec
## that has already been generated. Forcing a plan kind on afterwards -- which
## the landmark suite does, because a real castle's plan is not a coin flip --
## changes how long every run of wall is and how much ground the ward encloses,
## and a spec whose towers no longer fit the edges they stand on is exactly the
## input CastleBuilder must never be handed.
##
## It clamps and never randomizes, so it cannot move a design that was already
## fitted, and it is deliberately NOT called from generate(): the fitting there
## runs in its own order and this must not perturb it.
static func refit(spec: CastleSpec) -> void:
	# Calling refit on a polygon explicitly treats it as an ordinary polygon.
	# The terraced branch below can set the marker again if this fit fails.
	if spec.plan_kind != &"terraced":
		spec.terraced_fallback = false
	if spec.plan_kind == &"bergfried":
		_fit_bergfried(spec)
		return
	if spec.plan_kind == &"terraced" and CastleGeometry.is_enclosed(spec):
		spec.terrace_rise = maxf(spec.terrace_rise, 3.0)
		spec.terraced_fallback = false
		force_inner_ward(spec, maxf(spec.ward_gap,
			minf(spec.width, spec.length) * 0.16))
		if not spec.inner_ward:
			# Keep the requested footprint. A terraced plan whose second ring
			# cannot leave room for a walkable ward is an ordinary polygonal ward,
			# never a terraced plan with a missing ring.
			spec.terraced_fallback = true
			spec.plan_kind = &"polygon"
		if spec.keep:
			spec.keep_height = maxf(spec.keep_height,
				CastleGeometry.gate_height(spec, 1) + 10.0)
	if spec.plan_kind == &"tower_house" and not CastleGeometry.is_enclosed(spec):
		var r := RandomNumberGenerator.new()
		r.seed = spec.seed
		_fit_tower_house(spec, r)
		return
	if CastleGeometry.is_ridge(spec):
		var r2 := RandomNumberGenerator.new()
		r2.seed = spec.seed
		_fit_ridge(spec, r2)
		return
	if not CastleGeometry.is_enclosed(spec):
		return
	if CastleGeometry.is_motte(spec):
		spec.inner_ward = false
		spec.ward_gap = 0.0
		var r3 := RandomNumberGenerator.new()
		r3.seed = spec.seed
		if spec.motte_height <= 0.0:
			_fit_motte(spec, r3)
		_fit_motte_keep(spec)
		spec.keep = false
	_fit_towers(spec)
	if spec.inner_ward:
		_fit_ward_gap(spec)
	var b: Rect2 = CastleGeometry.bailey_rect(spec)
	if not CastleGeometry.is_motte(spec):
		# the keep in the bailey; a motte's shell keep is on the mound and
		# was fitted to it above
		var cap: Vector2 = CastleGeometry.max_keep_size(spec)
		spec.keep_w = minf(spec.keep_w, cap.x)
		spec.keep_l = minf(spec.keep_l, cap.y)
		if spec.keep_shape == &"round" or spec.keep_shape == &"shell" \
				or spec.keep_shape == &"tiered":
			var side: float = minf(spec.keep_w, spec.keep_l)
			spec.keep_w = side
			spec.keep_l = side
		spec.keep = spec.keep_w >= 3.0 and spec.keep_l >= 3.0
		if not spec.keep:
			spec.keep_w = 0.0
			spec.keep_l = 0.0
			spec.keep_height = 0.0
		else:
			spec.keep_height = maxf(spec.keep_height,
				CastleGeometry.tower_height(spec, CastleGeometry.inner_ring(spec)) * 1.2)
	spec.hall_w = minf(spec.hall_w, b.size.x * 0.3)
	spec.hall_l = minf(spec.hall_l, CastleGeometry.max_range_length(spec))
	spec.hall = spec.hall_l >= 4.0 and spec.hall_w >= 3.5
	spec.chapel = spec.chapel and spec.hall 			and b.size.x > spec.hall_w * 2.0 + CastleGeometry.BAILEY_CLEAR * 2.0
	spec.gate_width = minf(spec.gate_width, CastleGeometry.max_gate_width(spec, 0))
	_fit_inner_gate_forebuilding(spec)


## A raised keep stair must not occupy the inner gate passage. Slide the keep
## within its existing bailey/hall clearances by the smallest measured amount
## that leaves the complete forebuilding footprint clear of gate 1.
static func _fit_inner_gate_forebuilding(spec: CastleSpec) -> void:
	if not spec.inner_ward or not spec.keep or CastleGeometry.is_motte(spec):
		return
	var gate: AABB = CastleGeometry.gatehouse_aabb(spec, 1)
	if gate.size.x <= 0.0:
		return
	var plan: HousePlan = preload("castle_keep_plan.gd").generate(spec, false)
	var fore: Dictionary = preload("castle_access_geometry.gd").forebuilding_for_plan(spec, plan)
	if fore.is_empty():
		return
	var gate_rect := Rect2(gate.position.x, gate.position.z, gate.size.x, gate.size.z)
	var current: Rect2 = fore.footprint
	if not current.grow(0.22).intersects(gate_rect):
		return
	var original_offset: float = spec.keep_offset
	var original_x: float = CastleGeometry.keep_offset_x(spec)
	var yard: Rect2 = CastleGeometry.bailey_rect(spec)
	var room: float = yard.size.x * 0.5 - spec.keep_w * 0.5 - CastleGeometry.BAILEY_CLEAR
	# Estimate both side clearances independent of the current sign; an offset
	# away from a side range is often the only legal direction.
	var positive_room: float = room - (spec.hall_w if spec.chapel else 0.0)
	var negative_room: float = room - (spec.hall_w if spec.hall else 0.0)
	for index in range(1, int(ceil((maxf(positive_room, negative_room) \
			+ absf(original_offset)) / 0.25)) + 1):
		var distance := float(index) * 0.25
		for candidate in [original_offset + distance, original_offset - distance]:
			if candidate > positive_room + 0.001 or candidate < -negative_room - 0.001:
				continue
			spec.keep_offset = candidate
			var shifted := current
			shifted.position.x += CastleGeometry.keep_offset_x(spec) - original_x
			# The emitted forebuilding roof and slab are about 0.20m wider
			# than the planner footprint. Reserve that measured envelope here.
			if not shifted.grow(0.22).intersects(gate_rect):
				return
	spec.keep_offset = original_offset


## Shrink the towers until a pair of them fits on the same wall with a run of
## masonry left between. A tower sized off the short side alone still collided
## once the batter spread its foot, which is why this measures the base.
static func _fit_towers(spec: CastleSpec) -> void:
	if not spec.corner_towers:
		return
	for _pass in range(6):
		var s: float = CastleGeometry.tower_base_half(spec, 0)
		# the worst edge has the great tower at one end and an ordinary one
		# at the other
		var gi: int = CastleGeometry.great_tower_index(spec)
		var sg: float = CastleGeometry.tower_base_half_at(spec, 0, gi) if gi >= 0 else s
		var need: float = 2.0 * s + 2.0 * sg + CastleGeometry.MIN_WALL_RUN
		var have: float = minf(spec.width, spec.length)
		if CastleGeometry.is_polygonal(spec):
			# two vertex towers share every edge, and an octagon's edge is under
			# half the site width: sized off the site alone they would meet in
			# the middle of every run.
			need = 1.25 * s + 1.25 * sg + CastleGeometry.MIN_WALL_RUN
			have = minf(have, CastleGeometry.min_edge_length(spec, 0))
		if need <= have:
			break
		spec.tower_size = maxf(spec.tower_size * (have / need) * 0.98, 1.0)
	# an inner ring's towers are smaller again; make sure they fit their ring too
	if spec.inner_ward:
		for _pass2 in range(6):
			var si: float = CastleGeometry.tower_base_half(spec, 1)
			var rect: Rect2 = CastleGeometry.enceinte_rect(spec, 1)
			var need2: float = 4.0 * si + CastleGeometry.MIN_WALL_RUN
			var have2: float = minf(rect.size.x, rect.size.y)
			if CastleGeometry.is_polygonal(spec):
				need2 = 2.5 * si + CastleGeometry.MIN_WALL_RUN
				have2 = minf(have2, CastleGeometry.min_edge_length(spec, 1))
			if need2 <= have2:
				break
			spec.tower_size = maxf(spec.tower_size * (have2 / need2) * 0.98, 1.0)


## A second enceinte is only worth having when there is room to walk between the
## two, and the inner ward is still big enough to hold a keep. Otherwise the
## fortress is simply a large castle.
static func _fit_inner_ward(spec: CastleSpec, r: RandomNumberGenerator) -> void:
	var short_side: float = minf(spec.width, spec.length)
	force_inner_ward(spec, short_side * r.randf_range(0.10, 0.16))


## Turn a design concentric with a starting gap, then settle it. Public because
## the landmark suite forces Krak des Chevaliers to be concentric and must go
## through the same fitting the generator does -- a second copy of this logic in
## the suite is a second chance for it to disagree with the builder.
static func force_inner_ward(spec: CastleSpec, wanted_gap := 0.0) -> void:
	var short_side: float = minf(spec.width, spec.length)
	if wanted_gap <= 0.0:
		wanted_gap = short_side * 0.13
	spec.gatehouse = true
	spec.ward_gap = clampf(wanted_gap,
		CastleGeometry.gate_depth(spec, 0) + 3.0, short_side * 0.28)
	spec.inner_ward = true
	_fit_ward_gap(spec)
	_fit_towers(spec)


## Widen the gap between the two enceintes until the inner ring's towers clear
## the outer ring's, then check the inner ward is still worth having. The two
## chase each other -- a wider gap means a smaller inner ring, which means
## smaller towers, which means a narrower gap will do -- so this iterates.
static func _fit_ward_gap(spec: CastleSpec) -> void:
	var short_side: float = minf(spec.width, spec.length)
	for _pass in range(6):
		var need: float = CastleGeometry.min_ward_gap(spec)
		if spec.ward_gap >= need:
			break
		spec.ward_gap = minf(need, short_side * 0.35)
		_fit_towers(spec)
	var rect: Rect2 = CastleGeometry.enceinte_rect(spec, 1)
	var room: float = 4.0 * spec.wall_thickness + 8.0
	if rect.size.x < room or rect.size.y < room \
			or spec.ward_gap < CastleGeometry.min_ward_gap(spec):
		# no room for a second ring: a fortress this small is simply a castle
		spec.inner_ward = false
		spec.ward_gap = 0.0


## Size the keep, hall and chapel to the ward that has to hold them. Every one
## of these is clamped against CastleGeometry rather than guessed, so the
## builder never has to discover mid-build that its bailey is full.
static func _fit_bailey_buildings(spec: CastleSpec, r: RandomNumberGenerator) -> void:
	var b: Rect2 = CastleGeometry.bailey_rect(spec)
	var cap: Vector2 = CastleGeometry.max_keep_size(spec)
	spec.keep_w = clampf(b.size.x * r.randf_range(0.3, 0.45), 4.0, cap.x)
	spec.keep_l = clampf(b.size.y * r.randf_range(0.16, 0.26), 4.0, cap.y)
	if spec.keep_shape == &"round" or spec.keep_shape == &"shell" \
			or spec.keep_shape == &"tiered":
		# these are drums or towers in plan, so they are square on the ground
		var side: float = minf(spec.keep_w, spec.keep_l)
		spec.keep_w = side
		spec.keep_l = side
	spec.keep_height = spec.height * r.randf_range(1.7, 2.3)
	if spec.keep_shape == &"tiered":
		# a tenshu is wide for its height; the tall-tower proportion belongs to
		# a Norman donjon, not to this
		spec.keep_height = spec.height * r.randf_range(1.5, 1.9)
		spec.keep_w = minf(spec.keep_w * 1.35, cap.x)
		spec.keep_l = minf(spec.keep_l * 1.35, cap.y)
		var side2: float = minf(spec.keep_w, spec.keep_l)
		spec.keep_w = side2
		spec.keep_l = side2
	# The keep is the thing you see from a mile off. Left to its own range it
	# could come out shorter than the mural towers around it, and a donjon
	# peering over its own curtain reads as a shed.
	spec.keep_height = maxf(spec.keep_height,
		CastleGeometry.tower_height(spec, CastleGeometry.inner_ring(spec)) * 1.2)
	spec.keep = spec.keep_w >= 3.0 and spec.keep_l >= 3.0
	if not spec.keep:
		spec.keep_w = 0.0
		spec.keep_l = 0.0
		spec.keep_height = 0.0

	spec.hall_w = clampf(b.size.x * r.randf_range(0.18, 0.26), 3.5, b.size.x * 0.3)
	spec.hall_l = clampf(b.size.y * r.randf_range(0.3, 0.5), 4.0,
		CastleGeometry.max_range_length(spec))
	spec.hall_height = spec.height * r.randf_range(0.7, 0.95)
	spec.hall = spec.hall_l >= 4.0 and spec.hall_w >= 3.5
	# The chapel mirrors the hall on the far side, so the bailey has to be wide
	# enough for both plus a courtyard between them.
	spec.chapel = spec.hall and GeneratorRandom.chance(r, 0.6) \
		and b.size.x > spec.hall_w * 2.0 + CastleGeometry.BAILEY_CLEAR * 2.0
	spec.chimneys = 0


## A Bergfried is deliberately slender; the adjacent Palas carries the greater
## occupied volume. Keep the pair inside the ward with a reserved access gap.
static func _fit_bergfried(spec: CastleSpec) -> void:
	if not CastleGeometry.is_enclosed(spec):
		return
	spec.sides = clampi(spec.sides, 4, 6)
	# The keep is the singular fighting tower in this composition; an additional
	# great corner tower would consume the Palas' roof height and volume budget.
	spec.great_tower = -1
	spec.great_tower_scale = 1.0
	_fit_towers(spec)
	spec.inner_ward = false
	spec.ward_gap = 0.0
	spec.keep = true
	spec.hall = true
	spec.chapel = false
	spec.keep_shape = &"square"
	var ward: Rect2 = CastleGeometry.bailey_rect(spec)
	var max_side: float = minf(10.0, ward.size.x * 0.20)
	var side: float = clampf(minf(max_side, ward.size.y * 0.20), 5.0, 10.0)
	spec.keep_w = side
	spec.keep_l = side
	spec.keep_height = maxf(spec.height * 1.5, side * 3.2)
	# The Palas is broad and low, beside the tower. Leave the access stair's
	# full outward run between the tower door and the hall facade.
	var access_gap: float = CastleGeometry.bergfried_access_gap(spec)
	var available: float = ward.size.x - side - access_gap
	var palas_span: float = minf(20.0, maxf(8.0, available))
	spec.hall_w = minf(palas_span, available)
	spec.hall_l = minf(20.0, ward.size.y * 0.72)
	# On a polygon the ward narrows toward both ends. Search the real inner
	# polygon, shrinking the Palas gradually only when its base corners cannot
	# be placed alongside the keep inside those sloping walls.
	for _attempt in range(28):
		if CastleGeometry.bergfried_pair_fits(spec):
			break
		spec.hall_l = maxf(8.0, spec.hall_l - 0.5)
		spec.hall_w = maxf(8.0, spec.hall_w - 0.5)
	if not CastleGeometry.bergfried_pair_fits(spec):
		# Smallest credible side-by-side composition for a tight polygonal ward.
		spec.keep_w = 5.0
		spec.keep_l = 5.0
		spec.keep_height = maxf(spec.height * 1.5, 16.0)
		spec.hall_w = 8.0
		spec.hall_l = 8.0
	var keep_volume: float = spec.keep_w * spec.keep_l * spec.keep_height
	var roof_clear_height: float = spec.keep_height \
		- minf(spec.hall_w, spec.hall_l) * spec.roof_pitch * 0.5 - 1.0
	spec.hall_height = minf(maxf(4.0, roof_clear_height), maxf(4.0,
		2.8 * keep_volume / maxf(spec.hall_w * spec.hall_l, 1.0)))
	spec.keep = spec.keep_w <= 10.0 and spec.keep_l <= 10.0
	spec.curtain = true
	spec.corner_towers = true
	spec.gatehouse = true
	spec.gate_towers = true
	spec.side_towers = 0


## The motte and bailey (CAS-005): the mound's height by tier and its slope
## by seed, the shell keep sized to the site, and both shrunk until the
## bailey in front keeps its depth and the mound its footprint.
static func _fit_motte(spec: CastleSpec, r: RandomNumberGenerator) -> void:
	var short_side: float = minf(spec.width, spec.length)
	spec.motte_batter = r.randf_range(30.0, 40.0)
	spec.motte_height = r.randf_range(6.0, 10.0) if spec.tier == &"castle" \
		else r.randf_range(10.0, 15.0)
	spec.motte_height = minf(spec.motte_height, short_side * 0.2)
	spec.shell_thickness = clampf(spec.wall_thickness * 0.8, 0.8, 3.0)
	var d: float = clampf(short_side * r.randf_range(0.22, 0.32), 6.0, 40.0)
	spec.keep_w = d
	spec.keep_l = d * r.randf_range(0.85, 1.0)
	spec.keep_shape = &"shell"
	spec.keep = false
	_fit_motte_keep(spec)


## Settle the keep's height and pull the mound in until it fits the site:
## the bailey keeps MOTTE_MIN_BAILEY of depth and the mound stays inside the
## site's width.
static func _fit_motte_keep(spec: CastleSpec) -> void:
	var minimum := CastleGeometry.MOTTE_CLEAR_SIDE + 2.0 * spec.shell_thickness
	spec.keep_w = maxf(spec.keep_w, minimum)
	spec.keep_l = maxf(spec.keep_l, minimum)
	spec.keep_height = maxf(spec.keep_height,
		CastleGeometry.wall_height(spec, 0) * CastleGeometry.KEEP_DOMINANCE + 1.0 - spec.motte_height)
	spec.keep_height = maxf(spec.keep_height, spec.height * 0.6)
	for _pass in range(12):
		var rb: float = CastleGeometry.motte_base_radius(spec)
		var fits: bool = 2.0 * rb <= spec.width * 0.95 \
			and spec.length - rb * (2.0 - CastleGeometry.MOTTE_TOE) >= CastleGeometry.MOTTE_MIN_BAILEY
		if fits:
			break
		# Keep a usable occupied floor. If the mound is too broad, lower its
		# batter before squeezing away the doorway and both stair landings.
		spec.keep_w = maxf(spec.keep_w * 0.9, minimum)
		spec.keep_l = maxf(spec.keep_l * 0.9, minimum)
		spec.motte_height *= 0.92
	spec.keep_height = maxf(spec.keep_height, spec.height * 0.6)


## The ridge castle (CAS-007): ranges 8-14 m wide and as tall as the wall
## height, towers wide enough to stand proud of the ranges that dive into
## them, no curtain, no gate, no keep, no bailey buildings.
static func _fit_ridge(spec: CastleSpec, r: RandomNumberGenerator) -> void:
	var short_side: float = minf(spec.width, spec.length)
	spec.hall_w = clampf(short_side * 0.3, CastleGeometry.RIDGE_RANGE_W_MIN,
		CastleGeometry.RIDGE_RANGE_W_MAX)
	spec.hall_w = minf(spec.hall_w, short_side * 0.45)
	spec.hall_l = 0.0
	spec.hall_height = spec.height
	spec.hall = true
	spec.keep = false
	spec.keep_w = 0.0
	spec.keep_l = 0.0
	spec.keep_height = 0.0
	spec.chapel = false
	spec.curtain = false
	spec.gatehouse = false
	spec.gate_towers = false
	spec.barbican = false
	spec.inner_ward = false
	spec.ward_gap = 0.0
	spec.corner_towers = true
	spec.side_towers = 0
	spec.tower_storeys = CastleGeometry.ridge_storeys(spec)
	spec.ridge_points = r.randi_range(3, 6)
	spec.tower_size = clampf(spec.hall_w * 0.55, 2.0, 8.0)
	spec.tower_height = maxf(spec.tower_height, spec.height * 1.25)
	# A forced ridge also has to work at the smallest castle footprint. Pull
	# the drums in until adjacent spine vertices leave a real range between
	# their battered feet.
	for _pass in range(6):
		var pts: PackedVector2Array = CastleGeometry.spine(spec)
		var nearest := INF
		for i in range(pts.size() - 1):
			nearest = minf(nearest, pts[i].distance_to(pts[i + 1]))
		var diameter: float = CastleGeometry.tower_base_half(spec, 0) * 2.0
		var available: float = nearest - CastleGeometry.MIN_WALL_RUN
		if diameter <= available or available <= 0.0:
			break
		spec.tower_size = maxf(1.0, spec.tower_size * available / diameter * 0.98)
	if spec.style == &"dark":
		# The ridge still has a tower at every bend; one additional, singular
		# keep rises from its middle as the silhouette's needle.
		spec.keep = true
		spec.keep_shape = &"spire"
		spec.keep_w = minf(spec.hall_w * 0.9, 10.0)
		spec.keep_l = spec.keep_w
		spec.keep_height = maxf(spec.height * 2.0, spec.tower_height * 1.45)
		spec.chapel = false


## The tower house (CAS-006): storeys by height, the type by proportion --
## Bologna when the shaft is slender enough and its base small enough, else
## Scottish -- and a jog by seed. No wings, no annexe, no chimney stacks, no
## porch: the way in is a door a storey up.
static func _fit_tower_house(spec: CastleSpec, r: RandomNumberGenerator) -> void:
	var base: float = maxf(spec.width, spec.length)
	spec.tower_storeys = clampi(int(spec.height / 4.5), 4, 6)
	spec.tower_type = &"bologna" if (base <= 10.0 and spec.height >= 4.0 * base) \
		else &"scottish"
	spec.jog = GeneratorRandom.pick(r, [&"none", &"l", &"l", &"z"])
	if spec.style == &"wizard":
		spec.jog = &"none"
		spec.battlements = false
	spec.wings = 0
	spec.courtyard = false
	spec.chimneys = 0
	spec.corner_towers = false
	# thick enough at the top for the foot to be half as thick again and still
	# leave an interior
	spec.wall_thickness = clampf(spec.wall_thickness, 0.6, minf(spec.width, spec.length) * 0.15)
	spec.merlon_h = clampf(spec.height * 0.03, 0.5, 1.2)


static func _fit_sky(spec: CastleSpec) -> void:
	# Its towers and arched routes are the plan. A conventional curtain, gate,
	# keep and bailey would turn the floating network back into a ground castle.
	spec.curtain = false
	spec.battlements = false
	spec.corner_towers = false
	spec.side_towers = 0
	spec.great_tower = -1
	spec.gatehouse = false
	spec.gate_towers = false
	spec.barbican = false
	spec.inner_ward = false
	spec.ward_gap = 0.0
	spec.keep = false
	spec.hall = false
	spec.chapel = false
	spec.wings = 0
	spec.courtyard = false
	spec.chimneys = 0

# ---------------------------------------------------------------- the yard

## What stands in the bailey besides the keep, the hall and the chapel
## (CAS-012; CRITIQUE 2.5, 3.2).
##
## A castle was a village that happened to have a wall round it. The bailey
## here was an empty yard with three big blocks in it, which is a picture of a
## castle nobody worked in: no stable for the horses that got you there, no
## kitchen away from the hall it feeds, no smithy, no store, no well.
##
## Each entry is a SHOP -- the shop family already knows how to plan a stable,
## a cookshop, a smithy and a store, so the bailey does not invent building
## kinds of its own:
##
##   {"business": StringName, "spec": ShopSpec, "rect": Rect2, "yaw": float}
##
## `rect` is the plan footprint in castle space and `yaw` turns the shop's own
## front (-Z, like every family here) to face the yard. Empty for anything
## that is not a walled castle: a manor has no bailey to fill.
static func bailey_buildings(spec: CastleSpec) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not CastleGeometry.is_enclosed(spec):
		return out
	var yard: Rect2 = _yard_rect(spec)
	if yard.size.x < 6.0 or yard.size.y < 6.0:
		return out
	var taken: Array[Rect2] = CastleGeometry.bailey_obstacles(spec)
	taken.append(CastleGeometry.gate_axis_strip(spec))

	var roster: Array = BAILEY_ROSTER.get(spec.tier, [])
	var r := RandomNumberGenerator.new()
	r.seed = spec.seed ^ 0x42_41_49_4C
	for row in roster:
		var placed: Dictionary = _place_in_yard(spec, yard, taken, row, r)
		if placed.is_empty():
			continue
		taken.append(Rect2(placed["rect"]).grow(CastleGeometry.BAILEY_CLEAR))
		out.append(placed)
	return out


## Which trades a bailey holds, by tier. A castle keeps the horses and feeds
## itself; a fortress adds the forge and the store, because a garrison that
## size cannot send out for either.
const BAILEY_ROSTER := {
	&"castle": [
		{"business": &"stable", "w": 8.0, "l": 5.5},
		{"business": &"restaurant", "w": 7.0, "l": 5.0},
	],
	&"fortress": [
		{"business": &"stable", "w": 9.0, "l": 6.0},
		{"business": &"restaurant", "w": 7.5, "l": 5.5},
		{"business": &"blacksmith", "w": 7.0, "l": 5.5},
		{"business": &"general_store", "w": 6.5, "l": 5.0},
	],
}
## How far in from the curtain a yard building stands. It is BAILEY_CLEAR
## itself: the layout keeps the same distance the massing rule measures, so
## the two cannot drift apart.
const YARD_MARGIN := CastleGeometry.BAILEY_CLEAR
## And how far the well keeps from anything built.
const WELL_CLEAR := 6.0


## One building, against whichever side wall has room for it, marching back
## from the gate. Empty when nothing fits.
##
## Along the SIDES on purpose: the middle of a bailey is the way from the gate
## to the keep and the place a garrison musters, and a yard built across the
## middle is a yard you cannot cross.
static func _place_in_yard(spec: CastleSpec, yard: Rect2, taken: Array[Rect2],
		row: Dictionary, r: RandomNumberGenerator) -> Dictionary:
	var clear: float = CastleGeometry.BAILEY_CLEAR
	var w: float = maxf(float(row["w"]), 8.0)
	var l: float = maxf(float(row["l"]), 7.0)
	# shrink to fit a small ward rather than refuse to stand in one
	var room_x: float = yard.size.x / 2.0 - YARD_MARGIN * 2.0
	if room_x < w or yard.size.y - 2.0 * YARD_MARGIN < l:
		return {} # A quarter-turned public Shop request needs at least 7x8m.
	for side in ([-1.0, 1.0] if r.randf() < 0.5 else [1.0, -1.0]):
		var z: float = yard.position.y + YARD_MARGIN + l / 2.0
		while z + l / 2.0 <= yard.end.y - YARD_MARGIN:
			var x: float = (yard.end.x - YARD_MARGIN - w / 2.0) if side > 0.0 \
				else (yard.position.x + YARD_MARGIN + w / 2.0)
			var rect := Rect2(Vector2(x - w / 2.0, z - l / 2.0), Vector2(w, l))
			if not _hits(rect.grow(clear), taken):
				# The front is local -Z; turned a quarter, it looks ACROSS the
				# yard rather than up it, which is the way a building beside a
				# courtyard faces.
				return {"business": row["business"], "rect": rect,
					"yaw": PI / 2.0 if side > 0.0 else -PI / 2.0}
			z += 0.5
	return {}


## The ground a yard building may stand on.
##
## `bailey_rect` is the largest rectangle inside the ward, which is where a
## RANGE goes -- built against the wall on purpose. A free-standing building
## has to keep off the wall instead, and on a polygonal enceinte the curtain
## slants inside that rectangle by its own thickness, so the box is pulled in
## by a wall before anything is measured against it.
static func _yard_rect(spec: CastleSpec) -> Rect2:
	var yard: Rect2 = CastleGeometry.bailey_rect(spec)
	if CastleGeometry.is_polygonal(spec):
		var r: int = CastleGeometry.inner_ring(spec)
		yard = yard.grow(-CastleGeometry.wall_thickness(spec, r))
	return yard


## The well: in the open yard, clear of everything built and off the way in.
## Empty when the bailey has nowhere to sink one.
static func bailey_well(spec: CastleSpec) -> Dictionary:
	if not CastleGeometry.is_enclosed(spec):
		return {}
	var yard: Rect2 = _yard_rect(spec)
	var taken: Array[Rect2] = CastleGeometry.bailey_obstacles(spec)
	taken.append(CastleGeometry.gate_axis_strip(spec))
	for b in bailey_buildings(spec):
		taken.append(Rect2(b["rect"]).grow(WELL_CLEAR))
	var best := Vector2.INF
	var best_d := INF
	var mid: Vector2 = yard.get_center()
	var step := 0.75
	var z: float = yard.position.y + step
	while z < yard.end.y:
		var x: float = yard.position.x + step
		while x < yard.end.x:
			var here := Rect2(Vector2(x - 1.0, z - 1.0), Vector2(2.0, 2.0))
			if not _hits(here, taken):
				var d: float = Vector2(x, z).distance_to(mid)
				if d < best_d:
					best_d = d
					best = Vector2(x, z)
			x += step
		z += step
	return {} if not best.is_finite() else {"pos": best, "radius": 0.9}


static func _hits(rect: Rect2, taken: Array[Rect2]) -> bool:
	for t in taken:
		if t.intersects(rect):
			return true
	return false


## The ShopSpec a bailey building is planned from, generated and ready.
static func bailey_shop(spec: CastleSpec, entry: Dictionary) -> ShopSpec:
	var out := ShopSpec.new()
	out.business = entry["business"]
	out.material = &"stone"
	out.style = &"longhall"
	var rect: Rect2 = entry["rect"]
	# Match the quarter-turned public request used by CastleInteriors.yard.
	out.width = rect.size.y
	out.length = rect.size.x
	out.height = CastleBuilder.YARD_WALL_H
	ShopGenerator.generate(out, spec.seed ^ int(String(entry["business"]).hash()))
	return out

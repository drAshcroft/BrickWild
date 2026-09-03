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
	spec.seed = p_seed
	spec.rng.seed = p_seed
	var s: Dictionary = CastleSpec.STYLES[spec.style]
	var r := spec.rng

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
	spec.sides = 4
	if spec.plan_kind == &"polygon":
		spec.sides = clampi(spec.sides_override if spec.sides_override > 0 \
			else int(plan["sides"]), CastleGeometry.POLY_MIN_SIDES,
			CastleGeometry.POLY_MAX_SIDES)
	var short_side: float = minf(spec.width, spec.length)

	# ---- walls ----
	spec.curtain = enclosed
	spec.batter = float(s["batter"])
	spec.wall_thickness = clampf(spec.height * 0.22, 0.8, minf(5.0, short_side * 0.1))
	spec.battlements = _chance(r, s["battlements"])
	spec.merlon_h = clampf(spec.height * 0.09, 0.5, 1.6)
	spec.roof_pitch = r.randf_range(float(s["roof_pitch"][0]), float(s["roof_pitch"][1]))

	# ---- towers ----
	spec.tower_shape = s["tower_shape"]
	spec.tower_roof = _pick(r, s["tower_roof"])
	spec.tower_height = spec.height * r.randf_range(1.15, 1.55)
	spec.tower_size = clampf(short_side * r.randf_range(0.055, 0.085), 2.0, 8.0)
	spec.corner_towers = enclosed or (spec.tier == &"manor" and _chance(r, 0.5))
	spec.side_towers = _pick(r, s["side_towers"]) if enclosed else 0
	_fit_towers(spec)

	# ---- gate ----
	spec.gatehouse = enclosed
	spec.gate_width = clampf(spec.width * r.randf_range(0.16, 0.26), 3.5, 20.0)
	spec.gate_depth = spec.wall_thickness + r.randf_range(3.0, 6.0)
	spec.gate_towers = enclosed and _chance(r, s["gate_towers"])
	spec.barbican = spec.tier == &"fortress" and _chance(r, s["barbican"])

	# ---- inner ward: a fortress is a castle with a second enceinte ----
	spec.inner_ward = false
	spec.ward_gap = 0.0
	if spec.tier == &"fortress":
		_fit_inner_ward(spec, r)

	# ---- what stands inside, or IS the building ----
	spec.keep = enclosed
	spec.keep_shape = _pick(r, s["keep_shape"])
	spec.hall = true
	spec.chapel = false
	spec.wings = 0
	spec.courtyard = false
	spec.chimneys = 0
	match spec.tier:
		&"house":
			spec.wings = 1 if _chance(r, 0.55) else 0
			spec.chimneys = _pick(r, [1, 1, 2]) if int(s["chimneys"][0]) > 0 else 0
			spec.chimneys = mini(spec.chimneys, CastleGeometry.max_chimneys(spec))
		&"manor":
			spec.wings = _pick(r, s["wings"])
			spec.courtyard = spec.wings >= 2 and _chance(r, 0.5)
			spec.chimneys = mini(_pick(r, s["chimneys"]),
				CastleGeometry.max_chimneys(spec))
		_:
			_fit_bailey_buildings(spec, r)

	# ---- openings ----
	spec.window_style = s["windows"]
	spec.dormers = _chance(r, s["dormers"])
	spec.window_w = {"slit": 0.32, "square": 1.0, "mullioned": 1.3, "arched": 0.9
		}[String(spec.window_style)]
	spec.window_h = {"slit": 1.5, "square": 1.1, "mullioned": 1.9, "arched": 1.7
		}[String(spec.window_style)]

	# ---- palette ----
	spec.stone_color = Color(s["stone"][0]).lerp(Color(s["stone"][1]), r.randf())
	spec.roof_color = Color(s["roof"][0]).lerp(Color(s["roof"][1]), r.randf())
	spec.trim_color = spec.stone_color.darkened(0.18)

	spec.variant_name = "%s%s%s" % [_pick(r, FIRST_WORDS), _pick(r, SECOND_WORDS),
		_pick(r, TIER_SUFFIXES[spec.tier])]


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
	if not CastleGeometry.is_enclosed(spec):
		return
	_fit_towers(spec)
	if spec.inner_ward:
		_fit_ward_gap(spec)
	var b: Rect2 = CastleGeometry.bailey_rect(spec)
	var cap: Vector2 = CastleGeometry.max_keep_size(spec)
	spec.keep_w = minf(spec.keep_w, cap.x)
	spec.keep_l = minf(spec.keep_l, cap.y)
	if spec.keep_shape == &"round" or spec.keep_shape == &"shell" 			or spec.keep_shape == &"tiered":
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


## Shrink the towers until a pair of them fits on the same wall with a run of
## masonry left between. A tower sized off the short side alone still collided
## once the batter spread its foot, which is why this measures the base.
static func _fit_towers(spec: CastleSpec) -> void:
	if not spec.corner_towers:
		return
	for _pass in range(6):
		var s: float = CastleGeometry.tower_base_half(spec, 0)
		var need: float = 4.0 * s + CastleGeometry.MIN_WALL_RUN
		var have: float = minf(spec.width, spec.length)
		if CastleGeometry.is_polygonal(spec):
			# two vertex towers share every edge, and an octagon's edge is under
			# half the site width: sized off the site alone they would meet in
			# the middle of every run.
			need = 2.5 * s + CastleGeometry.MIN_WALL_RUN
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
	spec.chapel = spec.hall and _chance(r, 0.6) \
		and b.size.x > spec.hall_w * 2.0 + CastleGeometry.BAILEY_CLEAR * 2.0
	spec.chimneys = 0


static func _chance(r: RandomNumberGenerator, p) -> bool:
	return r.randf() < float(p)


static func _pick(r: RandomNumberGenerator, arr: Array):
	return arr[r.randi_range(0, arr.size() - 1)]

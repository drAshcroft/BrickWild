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
	if spec.plan_override == &"" and CastleSpec.tower_house_for(spec.style, spec.tier,
			p_seed, spec.width, spec.length, spec.height):
		spec.plan_kind = &"tower_house"
	spec.sides = 4
	if spec.plan_kind == &"polygon":
		spec.sides = clampi(spec.sides_override if spec.sides_override > 0 \
			else int(plan["sides"]), CastleGeometry.POLY_MIN_SIDES,
			CastleGeometry.POLY_MAX_SIDES)
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
	spec.gate_towers = enclosed and _chance(r, s["gate_towers"])
	spec.barbican = spec.tier == &"fortress" and _chance(r, s["barbican"])

	# ---- inner ward: a fortress is a castle with a second enceinte ----
	spec.inner_ward = false
	spec.ward_gap = 0.0
	if spec.tier == &"fortress" and spec.plan_kind != &"motte_bailey":
		_fit_inner_ward(spec, r)
	if spec.plan_kind == &"motte_bailey" and enclosed:
		_fit_motte(spec, r)

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
	if spec.plan_kind == &"tower_house":
		_fit_tower_house(spec, r)
	if CastleGeometry.is_motte(spec):
		# the keep is on the mound, not in the bailey
		spec.keep = false
		spec.keep_w = spec.keep_w if spec.keep_w > 0.0 else 8.0
		_fit_motte_keep(spec)
	if CastleGeometry.is_ridge(spec):
		_fit_ridge(spec, r)
		var great_r: Dictionary = CastleSpec.great_tower_for(spec.style, spec.tier, p_seed,
			CastleGeometry.spine(spec).size())
		spec.great_tower = int(great_r["vertex"])
		spec.great_tower_scale = float(great_r["scale"])

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
	spec.chapel = spec.hall and _chance(r, 0.6) \
		and b.size.x > spec.hall_w * 2.0 + CastleGeometry.BAILEY_CLEAR * 2.0
	spec.chimneys = 0


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
	spec.keep_height = maxf(spec.keep_height,
		CastleGeometry.wall_height(spec, 0) * CastleGeometry.KEEP_DOMINANCE + 1.0 - spec.motte_height)
	spec.keep_height = maxf(spec.keep_height, spec.height * 0.6)
	for _pass in range(12):
		var rb: float = CastleGeometry.motte_base_radius(spec)
		var fits: bool = 2.0 * rb <= spec.width * 0.95 \
			and spec.length - rb * (2.0 - CastleGeometry.MOTTE_TOE) >= CastleGeometry.MOTTE_MIN_BAILEY
		if fits:
			break
		spec.keep_w *= 0.9
		spec.keep_l *= 0.9
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


## The tower house (CAS-006): storeys by height, the type by proportion --
## Bologna when the shaft is slender enough and its base small enough, else
## Scottish -- and a jog by seed. No wings, no annexe, no chimney stacks, no
## porch: the way in is a door a storey up.
static func _fit_tower_house(spec: CastleSpec, r: RandomNumberGenerator) -> void:
	var base: float = maxf(spec.width, spec.length)
	spec.tower_storeys = clampi(int(spec.height / 4.5), 4, 6)
	spec.tower_type = &"bologna" if (base <= 10.0 and spec.height >= 4.0 * base) \
		else &"scottish"
	spec.jog = _pick(r, [&"none", &"l", &"l", &"z"])
	spec.wings = 0
	spec.courtyard = false
	spec.chimneys = 0
	spec.corner_towers = false
	# thick enough at the top for the foot to be half as thick again and still
	# leave an interior
	spec.wall_thickness = clampf(spec.wall_thickness, 0.6, minf(spec.width, spec.length) * 0.15)
	spec.merlon_h = clampf(spec.height * 0.03, 0.5, 1.2)


static func _chance(r: RandomNumberGenerator, p) -> bool:
	return r.randf() < float(p)


static func _pick(r: RandomNumberGenerator, arr: Array):
	return arr[r.randi_range(0, arr.size() - 1)]


# ------------------------------------------------------------- the interior

## The great hall as a plan (CAS-010; CRITIQUE 3.2).
##
## The keep, the hall and the chapel are logged masses with nothing inside
## them. This gives the hall an inside, in the representation the whole house
## harness already understands: a single-room HousePlan, so HousePlanCheck can
## judge it, HouseFurnisher can furnish it by the same rules a farmhouse gets,
## HouseNavCheck can walk it, and CastleBuilder can raise it (CAS-013) without
## a second furnishing engine growing up beside the first.
##
## What a great hall IS -- and every one of these is a rule the house harness
## already has a name for:
##
##   the DAIS at the upper end, a step up, the lord end of the room
##   the HIGH TABLE on it, looking down the hall -- plan.focus (INT-002)
##   the LORD BENCH behind the high table, and nobody in front of it
##   the TRESTLE ROWS down the length, benches drawn up to them (INT-001)
##   the HEARTH on a long wall, which the flue rises on (LAY-001)
##   the SCREENS PASSAGE inside the door: floor the plan keeps clear, so the
##     way in is not through the middle of dinner
##
## The plan is in the hall OWN frame -- centred on the origin, the way every
## HouseSpec is -- and `hall_aabb` says where that frame sits in the castle.
## Empty when the castle has no hall range, or when the range is not the size
## of a hall at all -- see MIN_HALL_SIDE and MAX_HALL_SIDE.
static func hall_plan(spec: CastleSpec) -> HousePlan:
	var plan := HousePlan.new()
	if not spec.hall:
		return plan
	var box: AABB = CastleGeometry.hall_aabb(spec)
	if box.size.x <= 0.0 or box.size.z <= 0.0:
		return plan
	var hs: HouseSpec = _hall_spec(spec, box)
	var floor_rect: Rect2 = HouseGeometry.interior_rect(hs)
	var across: float = minf(floor_rect.size.x, floor_rect.size.y)
	var along: float = maxf(floor_rect.size.x, floor_rect.size.y)
	if across < MIN_HALL_SIDE or across > MAX_HALL_SIDE or along > MAX_HALL_RUN:
		return plan
	if floor_rect.size.x * floor_rect.size.y < MIN_HALL_AREA:
		return plan
	plan.spec = hs
	plan.rooms = [{"kind": &"great_hall", "rect": floor_rect, "storey": 0}]

	# The hall runs along its longer side: the door at the lower end, the dais
	# at the upper. `up` points from the one to the other.
	var lengthwise: bool = floor_rect.size.y >= floor_rect.size.x
	var up := Vector2(0, 1) if lengthwise else Vector2(1, 0)
	var run: float = floor_rect.size.y if lengthwise else floor_rect.size.x
	_hall_door(plan, floor_rect, up)
	_hall_windows(plan, floor_rect, up, hs)

	# The dais at the upper end: deep enough to stand the high table and the
	# bench behind it on, and never less than the fifth of the hall that makes
	# it read as an end rather than a step in the floor.
	var depth: float = maxf(run * DAIS_SHARE, minf(DAIS_MIN_D, run * 0.4))
	var dais := Rect2(floor_rect.position, floor_rect.size)
	if lengthwise:
		dais.position.y = floor_rect.end.y - depth
		dais.size.y = depth
	else:
		dais.position.x = floor_rect.end.x - depth
		dais.size.x = depth
	plan.dais = {"room": 0, "rect": dais, "rise": DAIS_RISE}

	# The screens passage: a strip inside the door that stays floor. A short
	# hall gets a shorter one -- two metres of passage in a six metre hall
	# would be a third of the room -- and it is never less than a way through.
	var screens: float = clampf(run * SCREENS_SHARE, HouseGeometry.PATH_MIN + 0.5,
		SCREENS_MAX)
	var strip := Rect2(floor_rect.position, floor_rect.size)
	if lengthwise:
		strip.size.y = screens
	else:
		strip.size.x = screens
	plan.zones = [{"room": 0, "rect": strip, "why": "screens passage"}]

	# The fire on a long wall, where the flue can rise up the outside face.
	plan.hearth = {"room": 0, "wall": (2 if lengthwise else 0)}
	# And the high table on the dais, looking down the hall at the door. It
	# stands toward the FRONT of the dais rather than in the middle of it,
	# because the lord sits behind it and a bench needs room to be pushed back
	# into -- put the table on the centre line and the bench ends up with its
	# back half a metre inside the end wall, and does not get placed at all.
	#
	# A hall narrower than the high table is long has to stand the table
	# LENGTHWISE, and a table standing lengthwise cannot look down the hall at
	# anything. Ask for the view only where the room can give it: the table
	# across the hall, and a way past it either side.
	var faces: bool = across >= _longest_table() + HouseGeometry.PATH_MIN * 2.0
	plan.focus = {"room": 0, "cat": "table",
		"pos": dais.get_center() - up * (depth * HIGH_TABLE_SET_IN),
		"facing": atan2(up.x, up.y), "faces_door": faces}
	HouseFurnisher.furnish(plan, hs)
	return plan


## What a range has to measure to be furnished as a great hall.
##
## Below the minimum it is a lean-to with a roof on. Above the maximum it is
## not a hall either: a great hall is ONE ROOM under ONE ROOF, spanned by a
## truss, and the widest ever built is Westminster at 20.7 m. A fortress
## range is sixty metres across and a hundred and fifty long, which is a
## courtyard block the massing happens to draw as one mass -- furnishing it
## with a high table and a row of trestles would be a lie about the building,
## and an expensive one: the walk grid alone would be six hundred thousand
## cells.
##
## Either way the range still gets its mass. What it does not get is an
## inside.
const MIN_HALL_SIDE := 3.0
const MIN_HALL_AREA := 16.0
const MAX_HALL_SIDE := 25.0
const MAX_HALL_RUN := 80.0
## How much of the hall length the dais takes, how deep it is at the least,
## and how far it rises. The rise is a step: WalkGrid.MAX_STEP is 0.6, so a
## person walks up onto it, which is the whole point of a dais.
const DAIS_SHARE := 0.22
const DAIS_MIN_D := 1.9
const DAIS_RISE := 0.4
## How far in from the middle of the dais the high table stands, as a fraction
## of the dais depth, to leave the lord somewhere to sit.
const HIGH_TABLE_SET_IN := 0.18
## And the strip inside the door that stays clear.
const SCREENS_SHARE := 0.18
const SCREENS_MAX := 2.4
## A hall is lit by hall windows: tall, wide, and one to a bay. A cottage
## casement (0.95 x 1.05 m) in a room seventy metres long is an arrow slit --
## fifty of them still leave the floor under a twentieth of its area in glass,
## which is what the plan check calls too dark to live in.
const WINDOW_W := 1.4
const WINDOW_SILL := 1.1
const WINDOW_H := 3.4
const WINDOW_PITCH := 3.2


## The keep as a plan (CAS-011; CRITIQUE 3.2).
##
## A keep is the one castle building the house harness already knew how to
## describe: stacked storeys of one room each with a stair against the wall,
## which is `HouseSpec.storeys` and `HousePlanner._add_stair` and nothing new.
## What it needed was a programme of its own -- see KeepSpec -- because a keep
## puts its hall UP a stair over a blind store, which is the one thing the
## house rules forbid.
##
##   storey 0   the store: entered from the bailey, and BLIND. No windows at
##              the foot of a keep; that is the whole point of a keep.
##   storey 1   the hall
##   storey 2   a chamber, on a four-storey keep
##   the top    the lord's chamber, with a bed and a fire of its own
##
## The plan is in the keep's own frame, centred on the origin the way every
## HouseSpec is; `CastleGeometry.keep_aabb` says where that frame sits.
## Empty when the castle has no keep, or when the keep is too small to stack.
static func keep_plan(spec: CastleSpec) -> HousePlan:
	var plan := HousePlan.new()
	if not spec.keep:
		return plan
	var box: AABB = CastleGeometry.keep_aabb(spec)
	if box.size.x <= 0.0 or box.size.z <= 0.0:
		return plan
	var levels: int = clampi(int(box.size.y / KEEP_STOREY_H), 3,
		HouseGeometry.MAX_STOREYS)
	var hs: KeepSpec = _keep_spec(spec, box, levels)
	var floor_rect: Rect2 = HouseGeometry.interior_rect(hs)
	if minf(floor_rect.size.x, floor_rect.size.y) < MIN_KEEP_SIDE \
			or floor_rect.size.x * floor_rect.size.y < MIN_KEEP_AREA:
		return plan
	if maxf(floor_rect.size.x, floor_rect.size.y) > MAX_KEEP_SIDE:
		return plan
	plan.spec = hs

	for level in range(levels):
		plan.rooms.append({"kind": hs.kind_on(level), "rect": floor_rect,
			"storey": level})

	# The way in is at the foot, in the middle of the front wall. A forebuilding
	# would put it on the first floor instead (CAS-004); there is none yet, so
	# the keep is entered at the ground the way a hall house is.
	plan.doors = [{"a": 0, "b": -1,
		"pos": Vector2(floor_rect.get_center().x, floor_rect.position.y),
		"normal": Vector2(0, -1), "width": HouseGeometry.DOOR_W,
		"exterior": true, "front": true, "storey": 0}]

	# Blind at the foot, lit above: one window to each long wall of every room
	# people live in.
	for level2 in range(1, levels):
		if not HouseGeometry.is_habitable(hs.kind_on(level2)):
			continue
		# The lord's chamber keeps ONE WALL BLIND, the one facing the fire.
		# That is where the bed goes, and a bed wants solid wall over its head:
		# windows down all four sides left every keep in the sweep with its
		# lord sleeping under one, which the feng shui rule reports every time
		# and is right to.
		var blind: int = 3 if hs.kind_on(level2) == &"lords_chamber" else -1
		_keep_windows(plan, floor_rect, level2, hs, blind)

	# One stairwell, the same well on every landing, against a wall and out of
	# the line of the door (LAY-005) -- the house planner's own placer.
	for level3 in range(levels - 1):
		HousePlanner._add_stair(plan, level3, level3 + 1, level3, level3 + 1)

	# The fire is the lord's, at the top, on the wall the flue rises up.
	plan.hearth = {"room": levels - 1, "wall": 2}
	HouseFurnisher.furnish(plan, hs)
	return plan


## How much height one storey of a keep wants, and the least a keep may
## measure inside before it is a turret rather than a tower.
const KEEP_STOREY_H := 3.6
const MIN_KEEP_SIDE := 3.2
const MIN_KEEP_AREA := 12.0
## And the most. The biggest keep ever built is the White Tower at
## 36 x 32 m; a fortress in this generator throws up a "keep" mass sixty
## metres across with four thousand square metres to a floor, which is a
## block the massing happens to draw as one volume rather than a tower
## anybody lives up. It keeps its mass; what it does not get is an inside.
const MAX_KEEP_SIDE := 36.0
## How far apart a keep sets its windows along a wall. Wider than the hall
## pitch on purpose: the gap between two of them is where the bed goes.
const KEEP_WINDOW_PITCH := 5.0


## A KeepSpec describing the keep's own box, so every house helper measures it
## the way it measures a house, and the colours come out as castle masonry.
static func _keep_spec(spec: CastleSpec, box: AABB, levels: int) -> KeepSpec:
	var out := KeepSpec.new(spec.seed ^ 0x4B_45_45_50)
	out.style = &"townhouse"
	out.width = box.size.x
	out.length = box.size.z
	out.height = clampf(box.size.y / float(levels), 2.6, 4.5)
	out.storeys = levels
	out.room_count = levels
	out.program = out.room_program(levels)
	out.variant_name = "%s: the keep" % spec.variant_name
	out.wall_color = spec.stone_color
	out.trim_color = spec.trim_color
	out.roof_color = spec.roof_color
	out.floor_color = spec.stone_color.darkened(0.35)
	out.clutter = 0.5
	return out


## A window to each long wall of one storey, clear of the corners.
static func _keep_windows(plan: HousePlan, floor_rect: Rect2, level: int,
		hs: KeepSpec, blind_wall := -1) -> void:
	var head: float = minf(WINDOW_SILL + WINDOW_H, hs.height - 0.2)
	if head - WINDOW_SILL < 0.4:
		return
	# FEW AND TALL, not many and small. A keep floor is twelve metres across at
	# the least, so one cottage casement to a wall leaves it too dark to live
	# in -- but a ribbon of them along every wall is worse: it still does not
	# glaze the floor, and it leaves nowhere to put a bed that is not under a
	# window. Castle windows, five metres apart, do both jobs at once.
	var margin: float = HouseGeometry.DOOR_CORNER_MARGIN + WINDOW_W
	for axis in [0, 1]:
		var run: float = floor_rect.size.x if axis == 0 else floor_rect.size.y
		var usable: float = run - margin * 2.0
		if usable <= WINDOW_W:
			continue
		var count: int = maxi(int(usable / KEEP_WINDOW_PITCH), 1)
		for k in range(count):
			var t: float = (float(k) + 0.5) / float(count)
			for side in [-1.0, 1.0]:
				# HouseGeometry.room_walls order: front, back, left, right
				var wall: int = (0 if side < 0.0 else 1) if axis == 0 \
					else (2 if side < 0.0 else 3)
				if wall == blind_wall:
					continue
				var pos: Vector2
				var n: Vector2
				if axis == 0:
					pos = Vector2(lerpf(floor_rect.position.x + margin,
							floor_rect.end.x - margin, t),
						floor_rect.position.y if side < 0.0 else floor_rect.end.y)
					n = Vector2(0.0, side)
				else:
					pos = Vector2(
						floor_rect.position.x if side < 0.0 else floor_rect.end.x,
						lerpf(floor_rect.position.y + margin,
							floor_rect.end.y - margin, t))
					n = Vector2(side, 0.0)
				plan.windows.append({"room": level, "pos": pos, "normal": n,
					"width": WINDOW_W, "sill": WINDOW_SILL, "head": head,
					"storey": level})


## The longest side of the biggest table the catalogue has, which is how much
## of the hall's width a high table standing across it takes up.
static func _longest_table() -> float:
	var out := 0.0
	for key in PropCatalog.of_category("table"):
		var f: Vector2 = PropCatalog.footprint(key)
		out = maxf(out, maxf(f.x, f.y))
	return out


## A HouseSpec describing the hall own box, so every house helper --
## `interior_rect`, `room_walls`, `room_floor_rect` -- measures the hall the
## way it measures a room, and the colours come out as the castle masonry
## rather than as a cottage.
static func _hall_spec(spec: CastleSpec, box: AABB) -> HouseSpec:
	var out := HouseSpec.new(spec.seed)
	out.style = &"longhall"
	out.width = box.size.x
	out.length = box.size.z
	out.height = clampf(box.size.y, 2.6, 6.0)
	out.storeys = 1
	out.room_count = 1
	out.program = [&"great_hall"]
	out.variant_name = "%s: the great hall" % spec.variant_name
	out.wall_color = spec.stone_color
	out.trim_color = spec.trim_color
	out.roof_color = spec.roof_color
	out.floor_color = spec.stone_color.darkened(0.35)
	out.clutter = 0.5
	return out


## The way in, at the lower end, in the middle of the end wall.
static func _hall_door(plan: HousePlan, floor_rect: Rect2, up: Vector2) -> void:
	var lengthwise: bool = up.y > 0.5
	var mid: Vector2 = floor_rect.get_center()
	var pos := Vector2(mid.x, floor_rect.position.y) if lengthwise \
		else Vector2(floor_rect.position.x, mid.y)
	plan.doors = [{"a": 0, "b": -1, "pos": pos, "normal": -up,
		"width": HouseGeometry.DOOR_W, "exterior": true, "front": true,
		"storey": 0}]


## Windows down both long walls, evenly spaced and clear of the corners: a
## hall is lit from the sides, because its ends are the dais and the screens.
static func _hall_windows(plan: HousePlan, floor_rect: Rect2, up: Vector2,
		hs: HouseSpec) -> void:
	var lengthwise: bool = up.y > 0.5
	var run: float = floor_rect.size.y if lengthwise else floor_rect.size.x
	var margin: float = HouseGeometry.DOOR_CORNER_MARGIN + WINDOW_W
	var usable: float = run - margin * 2.0
	if usable <= WINDOW_W:
		return
	var count: int = maxi(int(usable / WINDOW_PITCH), 1)
	var head: float = minf(WINDOW_SILL + WINDOW_H, hs.height - 0.2)
	if head - WINDOW_SILL < 0.4:
		return
	for k in range(count):
		var t: float = (float(k) + 0.5) / float(count)
		var along: float = lerpf(floor_rect.position.y + margin,
			floor_rect.end.y - margin, t) if lengthwise \
			else lerpf(floor_rect.position.x + margin, floor_rect.end.x - margin, t)
		for side in [-1.0, 1.0]:
			var pos: Vector2
			var n: Vector2
			if lengthwise:
				pos = Vector2(floor_rect.position.x if side < 0.0 else floor_rect.end.x,
					along)
				n = Vector2(side, 0.0)
			else:
				pos = Vector2(along,
					floor_rect.position.y if side < 0.0 else floor_rect.end.y)
				n = Vector2(0.0, side)
			plan.windows.append({"room": 0, "pos": pos, "normal": n,
				"width": WINDOW_W, "sill": WINDOW_SILL, "head": head,
				"storey": 0})

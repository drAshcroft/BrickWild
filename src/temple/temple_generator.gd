class_name TempleGenerator
extends RefCounted
## Fills a TempleSpec's derived fields from (form, cult, seed) while respecting
## the user-locked footprint and hall height.
##
## Everything that could otherwise make the builder produce a temple nobody can
## hold a rite in is decided and clamped here: how wide the processional way
## is, how big the altar can be before it fills its own dais, whether the pit
## leaves room for a bridge. TempleBuilder.build() is then a pure function of
## the spec, and the rite checks judge the same temple the mesh came from.

const FIRST := ["Ash", "Black", "Crimson", "Drowned", "Grey", "Hollow", "Iron",
	"Night", "Pale", "Rust", "Salt", "Sunken", "Thorn", "Weeping"]
const SECOND := ["barrow", "chancel", "chantry", "choir", "crypt", "fane",
	"font", "hallow", "reliquary", "sanctum", "shrine", "vault"]
const OF := ["of the Open Throat", "of the Ninth Hunger", "of the Patient Dark",
	"of the Split Sky", "of the Long Sleep", "of the Unfed Mouth",
	"of the Turning Wheel", "", "", ""]


static func generate(spec: TempleSpec, p_seed: int) -> void:
	spec.seed = p_seed
	spec.rng.seed = p_seed
	var f: Dictionary = TempleSpec.FORMS[spec.form]
	var c: Dictionary = TempleSpec.CULTS[spec.cult]
	var r := spec.rng

	# ---- shell ----
	spec.wall_t = clampf(spec.height * 0.11, TempleGeometry.WALL_MIN,
		minf(TempleGeometry.WALL_MAX, minf(spec.width, spec.length) * 0.08))

	# ---- the rite: the altar first, because the dais is sized to it ----
	var hall: Rect2 = TempleGeometry.hall_rect(spec)
	spec.altar_w = clampf(hall.size.x * 0.18, 1.2, 3.6)
	spec.altar_l = clampf(spec.altar_w * r.randf_range(0.5, 0.75), 0.8, 2.4)
	spec.altar_h = clampf(spec.height * 0.09, 0.85, 1.35)
	spec.dais_steps = r.randi_range(2, 4)
	spec.dais_height = float(spec.dais_steps) * TempleGeometry.DAIS_RISE

	# ---- the god ----
	spec.idol_kind = _pick(r, c["idol"])
	spec.idol_width = clampf(hall.size.x * r.randf_range(0.16, 0.26), 1.4, 6.0)
	# tall enough to loom: over the altar, and a real share of the room
	spec.idol_height = maxf(spec.height * r.randf_range(0.45, 0.72),
		spec.altar_h * 3.0)
	if spec.form == &"ziggurat":
		spec.idol_height = maxf(spec.height * 0.35, spec.altar_h * 3.0)

	# The sanctum is sized to the altar and the god; if the temple is too short
	# to hold both at arm's length, the god shrinks rather than the rite.
	for guard in range(6):
		if TempleGeometry.sanctum_fits(spec):
			break
		spec.idol_width = maxf(spec.idol_width * 0.85, 1.0)
		spec.idol_height = maxf(spec.idol_height * 0.92, spec.altar_h * 2.2)

	# and never so small that it stops looming over the altar in front of it:
	# the same rule the rite check applies, applied here so it cannot fail
	var altar_top: float = TempleGeometry.dais_top(spec) + spec.altar_h
	spec.idol_height = maxf(spec.idol_height,
		altar_top * 2.15 - TempleGeometry.dais_top(spec))

	# ---- the hole ----
	spec.bridge_width = clampf(TempleGeometry.PROCESSION_MIN + 0.6,
		TempleGeometry.BRIDGE_MIN, 4.0)
	spec.pit = _chance(r, f["pit"])
	spec.pit_radius = 0.0
	if spec.pit:
		_fit_pit(spec, r)
		# A hole wider than the light can cross is a hole nobody would dig: the
		# braziers stand along its lip, and the middle of the bridge has to be
		# within reach of one of them or the crossing is made in the dark.
		var lit: float = TempleGeometry.LIGHT_REACH * 0.9 - TempleGeometry.PIT_RIM - 0.55
		spec.pit_radius = minf(spec.pit_radius, lit)

	# ---- columns ----
	spec.column_rows = _pick(r, f["rows"])
	spec.column_bays = 0 if int(f["bays"][1]) == 0 \
		else r.randi_range(int(f["bays"][0]), int(f["bays"][1]))
	spec.column_r = clampf(spec.height * 0.055, 0.3, 1.1)
	spec.aisle_width = clampf(hall.size.x * 0.12, TempleGeometry.AISLE_MIN, 5.0)
	_fit_columns(spec)

	# ---- what the cult adds ----
	spec.cells = _pick(r, f["cells"]) if _chance(r, c["cells"]) else 0
	spec.brazier_bays = r.randi_range(int(c["brazier"][0]), int(c["brazier"][1]))
	# and never fewer than it takes to light the walk: a processional way with
	# a dark stretch in the middle of it is a corridor, not a rite
	var walk: float = TempleGeometry.altar_center(spec).z \
		- TempleGeometry.entry_point(spec).y
	spec.brazier_bays = maxi(spec.brazier_bays,
		int(ceil(walk / (TempleGeometry.LIGHT_REACH * 0.9))))
	spec.stain = r.randf_range(float(c["stain"][0]), float(c["stain"][1]))

	# ---- what it shows the world ----
	spec.spire = _chance(r, f["spire"])
	spec.spire_height = spec.height * r.randf_range(0.5, 1.1) if spec.spire else 0.0
	spec.terraces = _pick(r, f.get("terraces", [3])) if spec.form == &"ziggurat" else 0
	spec.obelisks = _chance(r, f.get("obelisks", 0.0))
	if spec.form == &"ziggurat":
		var summit := TempleGeometry.terrace_rect(spec, spec.terraces - 1)
		spec.idol_width = minf(spec.idol_width, (minf(summit.size.x, summit.size.y) - 1.0) / 1.4)
		# Terrace count is drawn here to preserve the seeded draw sequence.
		# Refit geometry that depends on its final chamber/summit relationship.
		for guard in 6:
			if TempleGeometry.sanctum_fits(spec):
				break
			spec.idol_width = maxf(spec.idol_width * 0.85, 0.6)
		if spec.pit:
			fit_pit(spec)

	# ---- palette ----
	spec.stone_color = Color(c["stone"][0]).lerp(Color(c["stone"][1]), r.randf())
	spec.trim_color = Color(c["trim"][0]).lerp(Color(c["trim"][1]), r.randf())
	spec.roof_color = Color(c["roof"][0]).lerp(Color(c["roof"][1]), r.randf())
	spec.glow_color = Color(c["glow"])

	spec.variant_name = "The %s%s %s" % [_pick(r, FIRST), _pick(r, SECOND),
		_pick(r, OF)]
	spec.variant_name = spec.variant_name.strip_edges()
	# Materialize the final, fully filtered column arrangement once.  Consumers
	# must read this authored plan list rather than independently re-deriving it.
	_fit_column_bays(spec)
	spec.columns = TempleGeometry.column_records(spec)


## The final sanctum can leave a short colonnade, especially below a summit.
## Fit complete capital diameters along that length, preserving symmetric
## pairs instead of squeezing the originally drawn bay count into collisions.
static func _fit_column_bays(spec: TempleSpec) -> void:
	if spec.form == &"rotunda" or spec.column_bays <= 0:
		return
	var run := TempleGeometry.sanctum_rect(spec).position.y - 1.0 \
		- (TempleGeometry.hall_rect(spec).position.y + 1.6)
	if run < 2.0:
		spec.column_bays = 0
		return
	var pitch := spec.column_r * 2.4 + 0.2
	spec.column_bays = mini(spec.column_bays, floori(run / pitch) + 1)


## A pit has to leave the procession a way across and the dais a place to
## stand. Shrink it until it does; if it cannot, there is no pit -- a hole that
## fills the room is not a feature, it is a demolition.
## Settle a pit that was forced on afterwards -- by the archetype suite, which
## insists the Bloodpit Basilica has a pit whatever the dice said.
static func fit_pit(spec: TempleSpec) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = spec.seed
	_fit_pit(spec, r)
	var lit: float = TempleGeometry.LIGHT_REACH * 0.9 - TempleGeometry.PIT_RIM - 0.55
	spec.pit_radius = minf(spec.pit_radius, lit)


static func _fit_pit(spec: TempleSpec, r: RandomNumberGenerator) -> void:
	var hall: Rect2 = TempleGeometry.hall_rect(spec)
	if spec.form == &"rotunda":
		spec.pit_radius = clampf(TempleGeometry.ring_radius(spec) * 0.45, 1.5,
			minf(hall.size.x, hall.size.y) * 0.22)
		return
	var room: float = TempleGeometry.sanctum_rect(spec).position.y - hall.position.y
	spec.pit_radius = clampf(minf(hall.size.x * 0.18, room * 0.22) * r.randf_range(0.8, 1.1),
		1.2, minf(hall.size.x, room) * 0.3)
	# it must not swallow the way in, nor reach the dais
	var p: Rect2 = TempleGeometry.pit_rect(spec)
	if p.position.y < hall.position.y + 2.0 or p.size.x + 2.0 > hall.size.x:
		spec.pit = false
		spec.pit_radius = 0.0


## Columns may not crowd the processional way, and the outermost row may not
## push into the wall. Shrink the aisle, then drop rows, until they fit.
static func _fit_columns(spec: TempleSpec) -> void:
	if spec.form == &"rotunda":
		return
	var hall: Rect2 = TempleGeometry.hall_rect(spec)
	var half: float = hall.size.x / 2.0 - 0.5
	for guard in range(6):
		var outer: float = TempleGeometry.axis_half_width(spec) + spec.column_r \
			+ float(spec.column_rows - 1) * (spec.aisle_width + spec.column_r * 2.0) \
			+ spec.column_r
		if outer <= half:
			return
		if spec.aisle_width > TempleGeometry.AISLE_MIN:
			spec.aisle_width = maxf(TempleGeometry.AISLE_MIN, spec.aisle_width * 0.8)
			continue
		spec.column_rows -= 1
		if spec.column_rows <= 0:
			spec.column_rows = 0
			spec.column_bays = 0
			return


static func _chance(r: RandomNumberGenerator, p) -> bool:
	return r.randf() < float(p)


static func _pick(r: RandomNumberGenerator, arr: Array):
	return arr[r.randi_range(0, arr.size() - 1)]

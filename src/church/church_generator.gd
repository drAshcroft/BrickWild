class_name ChurchGenerator
extends RefCounted
## Fills a ChurchSpec's derived fields from (style, seed) while respecting the
## user-locked footprint/height. Also assigns a human-readable variant name.

const FIRST_WORDS := ["St.", "Old", "New", "Grey", "White", "Holy", "Saint", "Black", "Abbey", "Chapel"]
const SECOND_WORDS := ["Aldhelm", "Brigid", "Cuthbert", "Denys", "Editha", "Frideswide",
	"Guthlac", "Hilda", "Ivo", "Kenelm", "Mungo", "Ninian", "Oswald", "Wulfran"]
const SUFFIXES := ["-in-the-Wold", "-on-the-Hill", "-by-the-Ford", "", "", "Minster", "Priory"]

static func generate(spec: ChurchSpec, p_seed: int) -> void:
	spec.seed = p_seed
	spec.rng.seed = p_seed
	var s: Dictionary = ChurchSpec.STYLES[spec.style]
	var r := spec.rng

	# --- massing ---
	spec.tower = _chance(r, s["tower"])
	if spec.tower:
		spec.tower_width = clampf(spec.width * r.randf_range(0.75, 1.05), 3.0, spec.width)
		spec.tower_height = spec.height * r.randf_range(0.9, 2.2)
		if spec.style == &"nordic_stave":
			spec.tower_height = spec.height * r.randf_range(1.4, 2.4)
	else:
		spec.tower_width = 0.0
		spec.tower_height = 0.0

	spec.spire = spec.tower and _chance(r, s["spire"])
	spec.spire_pitch = r.randf_range(0.9, 1.6)

	spec.apse = _chance(r, s["apse"])
	spec.apse_radius = spec.width * 0.5 * r.randf_range(0.7, 0.95)

	spec.transept = _chance(r, s["transept"])
	spec.transept_len = spec.width * r.randf_range(1.8, 3.0) if spec.transept else 0.0

	var aisle_opts: Array = s["aisles"]
	spec.aisles = _pick(r, aisle_opts)
	spec.aisle_width = clampf(spec.width * r.randf_range(0.18, 0.32), 1.5, 4.0)
	# Aisles must fit between the tower and the crossing. Deciding it HERE keeps
	# ChurchBuilder.build() a pure function of its spec -- it used to make this
	# call itself by writing spec.aisles = 0 mid-build, which meant the QA suite
	# read the post-mutation value and skipped the very cases that triggered it.
	if spec.aisles > 0 and not ChurchGeometry.aisle_fits(spec):
		spec.aisles = 0

	spec.buttresses = _chance(r, s["buttresses"])
	spec.buttress_count_per_side = r.randi_range(3, 6) if spec.buttresses else 0
	spec.buttress_depth = r.randf_range(0.4, 0.8)

	spec.window_style = s["windows"]
	spec.window_w = r.randf_range(0.8, 1.4)
	spec.window_h = {"round": r.randf_range(1.4, 2.2), "pointed": r.randf_range(2.0, 3.4), "square": r.randf_range(1.0, 1.6)}[String(spec.window_style)]

	spec.clerestory = spec.aisles > 0 and _chance(r, s["clerestory"])

	spec.door_style = _pick(r, s["door"])
	spec.rose_window = _chance(r, s["rose"]) and not spec.tower

	spec.roof_pitch = r.randf_range(0.55, 1.0)
	spec.tower_roof = _pick(r, s["towers_roof"]) if spec.tower else &"flat"

	# palette per style
	match spec.style:
		&"gothic":
			spec.stone_color = Color("b8b2a6").lerp(Color("8f887c"), r.randf_range(0.0, 1.0))
			spec.roof_color = Color("4a5560").lerp(Color("37424e"), r.randf_range(0.0, 1.0))
		&"byzantine":
			spec.stone_color = Color("d9c9a8").lerp(Color("c2ab84"), r.randf_range(0.0, 1.0))
			spec.roof_color = Color("6e5f4a").lerp(Color("8a4a35"), r.randf_range(0.0, 1.0))
		&"nordic_stave":
			spec.stone_color = Color("6b5236").lerp(Color("4a3826"), r.randf_range(0.0, 1.0))  # timber-dark
			spec.roof_color = Color("3a3630").lerp(Color("2c2823"), r.randf_range(0.0, 1.0))
		_: # romanesque
			spec.stone_color = Color("cfc5ae").lerp(Color("a89a80"), r.randf_range(0.0, 1.0))
			spec.roof_color = Color("8a5a40").lerp(Color("6f4436"), r.randf_range(0.0, 1.0))
	spec.trim_color = spec.stone_color.lightened(0.15)

	# ---- landmark features (docs/LANDMARKS.md) ----
	# West front: a single tower, or the twin towers of Notre-Dame and Cologne.
	if spec.tower:
		spec.west_towers = 2 if _chance(r, s.get("twin_towers", 0.0)) else 1
		if spec.west_towers == 2:
			spec.tower_width = minf(spec.tower_width,
				ChurchGeometry.max_twin_tower_width(spec))
	else:
		spec.west_towers = 0

	# Flying buttresses need an aisle roof to spring over.
	spec.flying_buttresses = _chance(r, s.get("flying", 0.0)) and spec.aisles > 0
	spec.flyer_tiers = 2 if spec.flying_buttresses and _chance(r, 0.4) else 1
	if spec.flying_buttresses:
		spec.buttresses = true   # every flyer needs its pier

	spec.crossing_tower = spec.transept and _chance(r, s.get("crossing_tower", 0.0))
	spec.crossing_tower_height = 0.0
	if spec.crossing_tower:
		spec.crossing_tower_height = spec.height * r.randf_range(1.35, 1.9)

	spec.dome = _chance(r, s.get("dome", 0.0))
	var shapes: Array = s.get("dome_shapes", [])
	if spec.dome and shapes.is_empty():
		spec.dome = false
	if spec.dome:
		spec.dome_shape = _pick(r, shapes)
		spec.dome_radius = spec.width * r.randf_range(0.40, 0.48)
		spec.dome_drum_height = (spec.dome_radius
			* ChurchGeometry.DOME_DRUM_RATIO * r.randf_range(0.8, 1.3))
		# a domed church carries a shallow roof: a steep gable over a wide nave
		# out-tops the dome and hides it
		spec.roof_pitch = r.randf_range(0.26, 0.40)
		spec.dome_drum_height = maxf(spec.dome_drum_height,
			ChurchGeometry.min_drum_height(spec))
		spec.dome_lantern = _chance(r, s.get("lantern", 0.25))
		spec.half_domes = _chance(r, s.get("half_domes", 0.0))
		spec.exedrae = spec.half_domes and _chance(r, 0.6)
		# a dome over the crossing replaces a tower there
		spec.crossing_tower = false
		spec.crossing_tower_height = 0.0
	else:
		spec.dome_shape = &""
		spec.dome_radius = 0.0
		spec.dome_drum_height = 0.0

	spec.ambulatory = spec.apse and _chance(r, s.get("ambulatory", 0.0))
	spec.chapel_arrangement = s.get("chapel_arrangement", &"chevet")
	# A chevet fans off the apse and so needs one; a cluster rings the central
	# mass and stands on its own.
	var can_host: bool = spec.apse or spec.chapel_arrangement == &"cluster"
	spec.radiating_chapels = _pick(r, s.get("chapels", [0])) if can_host else 0
	spec.chapel_radius = 0.0
	if spec.radiating_chapels > 0:
		var base_r: float = spec.apse_radius if spec.apse else spec.width * 0.5
		spec.chapel_radius = base_r * r.randf_range(0.30, 0.42)
		_fit_chapels(spec)
	spec.narthex = _chance(r, s.get("narthex", 0.0))

	spec.corner_turrets = spec.style == &"gothic" and _chance(r, 0.5)
	spec.string_course = _chance(r, 0.7)

	spec.variant_name = "%s %s%s" % [
		_pick(r, FIRST_WORDS).trim_suffix("."), _pick(r, SECOND_WORDS), _pick(r, SUFFIXES)]

## Settle chapel size and count so the alcoves fit their hemicycle and leave
## each other clear.
##
## The two constraints chase each other: a chapel's usable fan angle depends on
## its radius, and the radius that keeps neighbours apart depends on the fan.
## Shrinking the radius widens the fan, so iterating converges. If the ring
## still cannot be made to work, drop chapels until it can -- five alcoves that
## fit read better than seven that collide.
static func _fit_chapels(spec: ChurchSpec) -> void:
	while spec.radiating_chapels > 0:
		var r: float = spec.chapel_radius
		for _pass in range(5):
			r = minf(r, ChurchGeometry.chapel_reach(spec) * 0.42)
			spec.chapel_radius = r
			r = minf(r, ChurchGeometry.max_chapel_radius(spec, spec.radiating_chapels))
		spec.chapel_radius = r
		if r >= 0.5:
			break
		spec.radiating_chapels -= 2 if spec.radiating_chapels > 2 else 1
	if spec.radiating_chapels <= 0:
		spec.radiating_chapels = 0
		spec.chapel_radius = 0.0
	elif ChurchGeometry.chapel_max_angle(spec) <= 0.01 and spec.radiating_chapels > 1:
		spec.radiating_chapels = 1


static func _chance(r: RandomNumberGenerator, p) -> bool:
	return r.randf() < float(p)

static func _pick(r: RandomNumberGenerator, arr: Array):
	return arr[r.randi_range(0, arr.size() - 1)]

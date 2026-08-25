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

	spec.corner_turrets = spec.style == &"gothic" and _chance(r, 0.5)
	spec.string_course = _chance(r, 0.7)

	spec.variant_name = "%s %s%s" % [
		_pick(r, FIRST_WORDS).trim_suffix("."), _pick(r, SECOND_WORDS), _pick(r, SUFFIXES)]

static func _chance(r: RandomNumberGenerator, p) -> bool:
	return r.randf() < float(p)

static func _pick(r: RandomNumberGenerator, arr: Array):
	return arr[r.randi_range(0, arr.size() - 1)]

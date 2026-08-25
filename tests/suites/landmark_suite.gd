class_name LandmarkSuite
extends RefCounted
## 4. The famous churches this generator must be able to build.
##
## docs/LANDMARKS.md lists eight real buildings with their footprint and the
## features that define them. ChurchGenerator is probabilistic, so after
## generate() runs we FORCE the defining flags a real landmark demands --
## a coin flip should never be the reason Notre-Dame loses its flying
## buttresses -- then check that ChurchBuilder actually produced structural
## geometry for them, and that MassingCheck still finds the result sound.
## The whole thing repeats at several scale factors, to prove the massing
## holds together from a chapel-sized model up past the real building.

## Scale factors applied to width/length/height together.
const SCALES: Array[float] = [0.25, 0.5, 1.0, 1.75]

## One row per landmark: real nave width/length/height from docs/LANDMARKS.md.
const LANDMARKS: Array[Dictionary] = [
	{"key": "notre_dame", "style": &"gothic", "width": 12.0, "length": 127.0, "height": 33.0},
	{"key": "cologne", "style": &"gothic", "width": 14.0, "length": 144.0, "height": 43.0},
	{"key": "chartres", "style": &"gothic", "width": 16.4, "length": 130.0, "height": 37.5},
	{"key": "salisbury", "style": &"gothic", "width": 12.0, "length": 135.0, "height": 26.0},
	{"key": "durham", "style": &"romanesque", "width": 11.9, "length": 61.0, "height": 22.2},
	{"key": "hagia_sophia", "style": &"byzantine", "width": 31.0, "length": 76.0, "height": 40.0},
	{"key": "florence_duomo", "style": &"renaissance", "width": 17.0, "length": 153.0, "height": 45.0},
	{"key": "st_basil", "style": &"russian", "width": 12.0, "length": 46.0, "height": 30.0},
]


static func run() -> SuiteResult:
	var res := SuiteResult.new("landmark")
	for landmark in LANDMARKS:
		var key: String = landmark["key"]
		var defects := 0
		for scale in SCALES:
			var spec := ChurchSpec.new()
			spec.style = landmark["style"]
			spec.width = float(landmark["width"]) * scale
			spec.length = float(landmark["length"]) * scale
			spec.height = float(landmark["height"]) * scale
			ChurchGenerator.generate(spec, _seed_for(key, scale))
			_force_features(key, spec)

			var builder := ChurchBuilder.new()
			builder.build(spec)
			res.checked += 1
			var who := "%s scale=%.2f" % [key, scale]
			var before_fail: int = res.failures.size()

			_check_required_masses(key, builder, who, res)
			var rep: Dictionary = MassingCheck.new().check(spec, builder)
			for f in rep["failures"]:
				res.fail("%s: %s" % [who, str(f)])
			for w in rep["warnings"]:
				res.warn("%s: %s" % [who, str(w)])

			if res.failures.size() > before_fail:
				defects += 1
		res.note("  %-14s %d scales, %d defects" % [key, SCALES.size(), defects])
	return res


## Deterministic per-(landmark, scale) seed, distinct across the whole table.
static func _seed_for(key: String, scale: float) -> int:
	return 7000 + absi(key.hash()) % 1000 + int(scale * 100.0)


# ------------------------------------------------------------ feature forcing

## Set the flags/fields a real landmark demands, overriding whatever the
## generator's coin flips produced. A size field is only backfilled when the
## generator left it at 0.0 -- if the generator already chose a value, that
## choice wins.
static func _force_features(key: String, spec: ChurchSpec) -> void:
	match key:
		"notre_dame":
			_force_west_towers(spec, 2)
			_force_flying_buttresses(spec)
			if spec.aisles < 2:
				spec.aisles = 2
			spec.apse = true
		"cologne":
			_force_west_towers(spec, 2)
			_force_flying_buttresses(spec)
			if spec.aisles < 2:
				spec.aisles = 2
		"chartres":
			_force_flying_buttresses(spec)
			spec.apse = true
			spec.ambulatory = true
			if spec.radiating_chapels < 5:
				spec.radiating_chapels = 5
			if spec.chapel_radius == 0.0:
				spec.chapel_radius = spec.apse_radius * 0.38
		"salisbury":
			_force_crossing_tower(spec)
		"durham":
			_force_crossing_tower(spec)
			_force_west_towers(spec, 2)
		"hagia_sophia":
			_force_dome(spec, &"hemisphere")
			spec.half_domes = true
		"florence_duomo":
			_force_dome(spec, &"octagonal")
			spec.dome_lantern = true
		"st_basil":
			_force_dome(spec, &"onion")
			if spec.radiating_chapels < 4:
				spec.radiating_chapels = 4
			if spec.chapel_radius == 0.0:
				spec.chapel_radius = spec.apse_radius * 0.38


## Twin (or single) west towers, with a physically sensible width/height when
## the generator did not already choose a tower at all.
static func _force_west_towers(spec: ChurchSpec, count: int) -> void:
	spec.tower = true
	if spec.tower_width == 0.0:
		spec.tower_width = clampf(spec.width * 0.9, 3.0, spec.width)
	if spec.tower_height == 0.0:
		spec.tower_height = spec.height * 1.5
	spec.west_towers = count
	if count >= 2:
		# keep both towers on the facade, mirroring ChurchGenerator's own clamp.
		spec.tower_width = minf(spec.tower_width, ChurchGeometry.max_twin_tower_width(spec))


## Flying buttresses need their piers, which need buttresses turned on at all.
static func _force_flying_buttresses(spec: ChurchSpec) -> void:
	spec.flying_buttresses = true
	spec.buttresses = true
	if spec.buttress_count_per_side == 0:
		spec.buttress_count_per_side = 4
	if spec.buttress_depth == 0.0:
		spec.buttress_depth = 0.6


## A crossing tower needs a crossing: nave and transept must actually meet.
static func _force_crossing_tower(spec: ChurchSpec) -> void:
	spec.transept = true
	if spec.transept_len == 0.0:
		spec.transept_len = spec.width * 2.2
	spec.crossing_tower = true
	if spec.crossing_tower_height == 0.0:
		spec.crossing_tower_height = spec.height * 1.6


## A dome over the crossing replaces a crossing tower there, same as the
## generator enforces when it picks a dome for itself.
static func _force_dome(spec: ChurchSpec, shape: StringName) -> void:
	spec.dome = true
	spec.dome_shape = shape
	if spec.dome_radius == 0.0:
		spec.dome_radius = spec.width * 0.45
	if spec.dome_drum_height == 0.0:
		spec.dome_drum_height = spec.dome_radius * ChurchGeometry.DOME_DRUM_RATIO
	spec.crossing_tower = false
	spec.crossing_tower_height = 0.0


# --------------------------------------------------------- geometry assertions

## For each landmark, confirm the forced feature actually produced a
## structural mass -- not just a flag flipped on a spec nobody read.
static func _check_required_masses(key: String, builder: ChurchBuilder, who: String,
		res: SuiteResult) -> void:
	match key:
		"notre_dame":
			_require(builder, who, res, "flyer_pier_left_", "flying buttresses")
			_require(builder, who, res, "tower_left", "west tower (left)")
			_require(builder, who, res, "tower_right", "west tower (right)")
			_require(builder, who, res, "aisle_left_1", "double aisle (2nd ring)")
			_require(builder, who, res, "apse", "apse")
		"cologne":
			_require(builder, who, res, "flyer_pier_left_", "flying buttresses")
			_require(builder, who, res, "tower_left", "west tower (left)")
			_require(builder, who, res, "tower_right", "west tower (right)")
			_require(builder, who, res, "aisle_left_1", "double aisle (2nd ring)")
		"chartres":
			_require(builder, who, res, "flyer_pier_left_", "flying buttresses")
			_require(builder, who, res, "ambulatory", "ambulatory")
			_require(builder, who, res, "chapel_4", "5th radiating chapel")
		"salisbury":
			_require(builder, who, res, "crossing_tower", "crossing tower")
		"durham":
			_require(builder, who, res, "crossing_tower", "crossing tower")
			_require(builder, who, res, "tower_left", "west tower (left)")
			_require(builder, who, res, "tower_right", "west tower (right)")
		"hagia_sophia":
			# half-domes are not yet their own logged mass; they read off the
			# same drum until the builder gives them a distinct name.
			_require(builder, who, res, "dome_drum", "dome (with buttressing half-domes)")
		"florence_duomo":
			# shape and lantern are attributes of the drum mass, not separate ones.
			_require(builder, who, res, "dome_drum", "octagonal drum + lantern-topped dome")
		"st_basil":
			_require(builder, who, res, "dome_drum", "onion dome")
			_require(builder, who, res, "chapel_3", "4th radiating chapel")


static func _require(builder: ChurchBuilder, who: String, res: SuiteResult, prefix: String,
		feature: String) -> void:
	if not _has_mass(builder, prefix):
		res.fail("%s: %s did not produce a mass starting with '%s'" % [who, feature, prefix])


## True if any logged structural mass's name begins with `prefix`.
static func _has_mass(builder: ChurchBuilder, prefix: String) -> bool:
	for m in builder.mass_log:
		var name: String = m["name"]
		if name.begins_with(prefix):
			return true
	return false

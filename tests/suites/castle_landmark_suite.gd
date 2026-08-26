class_name CastleLandmarkSuite
extends RefCounted
## 9. The famous fortifications this generator must be able to build.
##
## docs/CASTLES.md lists eleven real buildings with their footprint and the
## features that define them. CastleGenerator is probabilistic, so after
## generate() runs we FORCE the defining flags a real landmark demands -- a coin
## flip should never be the reason Bodiam loses its drum towers -- then check
## that CastleBuilder actually produced structural geometry for them, and that
## CastleMassingCheck still finds the result sound.
##
## Each row keeps its tier pinned while the footprint scales, so the sweep asks
## "does a fortress still hold together at 40% and at 150% of Krak?" rather than
## quietly turning into a manor on the way down.

const SCALES: Array[float] = [0.4, 0.7, 1.0, 1.5]

## One row per landmark: real dimensions from docs/CASTLES.md.
const LANDMARKS: Array[Dictionary] = [
	{"key": "longhouse", "style": &"norman", "tier": &"house",
		"width": 6.5, "length": 18.0, "height": 4.5},
	{"key": "stokesay", "style": &"norman", "tier": &"manor",
		"width": 30.0, "length": 24.0, "height": 10.0},
	{"key": "hampton_range", "style": &"french_chateau", "tier": &"manor",
		"width": 40.0, "length": 28.0, "height": 11.0},
	{"key": "bodiam", "style": &"edwardian", "tier": &"castle",
		"width": 55.0, "length": 50.0, "height": 18.0},
	{"key": "caernarfon", "style": &"edwardian", "tier": &"castle",
		"width": 170.0, "length": 60.0, "height": 12.0},
	{"key": "neuschwanstein", "style": &"bavarian", "tier": &"castle",
		"width": 150.0, "length": 40.0, "height": 25.0},
	{"key": "himeji", "style": &"japanese", "tier": &"castle",
		"width": 60.0, "length": 50.0, "height": 15.0},
	{"key": "chambord", "style": &"french_chateau", "tier": &"fortress",
		"width": 156.0, "length": 117.0, "height": 32.0},
	{"key": "krak", "style": &"crusader", "tier": &"fortress",
		"width": 300.0, "length": 140.0, "height": 20.0},
	{"key": "alhambra", "style": &"moorish", "tier": &"fortress",
		"width": 200.0, "length": 70.0, "height": 16.0},
	{"key": "windsor", "style": &"norman", "tier": &"fortress",
		"width": 200.0, "length": 120.0, "height": 18.0},
]


static func run() -> SuiteResult:
	var res := SuiteResult.new("castle landmark")
	for landmark in LANDMARKS:
		var key: String = landmark["key"]
		var defects := 0
		for scale in SCALES:
			var spec := CastleSpec.new()
			spec.style = landmark["style"]
			spec.tier_override = landmark["tier"]
			spec.width = float(landmark["width"]) * scale
			spec.length = float(landmark["length"]) * scale
			spec.height = float(landmark["height"]) * scale
			CastleGenerator.generate(spec, _seed_for(key, scale))
			_force_features(key, spec)

			var builder := CastleBuilder.new()
			builder.build(spec)
			res.checked += 1
			var who := "%s scale=%.2f" % [key, scale]
			var before_fail: int = res.failures.size()

			if spec.tier != landmark["tier"]:
				res.fail("%s: tier_override did not hold (%s)" % [who, String(spec.tier)])
			_check_required_masses(key, spec, builder, who, res, scale)
			var rep: Dictionary = CastleMassingCheck.new().check(spec, builder)
			for f in rep["failures"]:
				res.fail("%s: %s" % [who, str(f)])
			for w in rep["warnings"]:
				res.warn("%s: %s" % [who, str(w)])

			if res.failures.size() > before_fail:
				defects += 1
		res.note("  %-15s %d scales, %d defects" % [key, SCALES.size(), defects])
	return res


## Deterministic per-(landmark, scale) seed, distinct across the whole table.
static func _seed_for(key: String, scale: float) -> int:
	return 3000 + absi(key.hash()) % 1000 + int(scale * 100.0)


# ------------------------------------------------------------ feature forcing

## Set the flags a real landmark demands, overriding the generator's coin
## flips. Sizes the generator already chose are left alone; only the features
## that MAKE the building what it is are forced.
static func _force_features(key: String, spec: CastleSpec) -> void:
	match key:
		"longhouse":
			spec.chimneys = maxi(spec.chimneys, 1)
			spec.wings = 0
		"stokesay":
			# a hall between two towers, inside a low curtain: the earliest
			# fortified manor houses in England
			spec.wings = maxi(spec.wings, 2)
			spec.corner_towers = true
			spec.courtyard = false
		"hampton_range":
			spec.wings = 2
			spec.courtyard = true
			spec.chimneys = maxi(spec.chimneys, 3)
		"bodiam":
			# a quadrangular castle: four drum towers, a twin-towered gatehouse
			spec.corner_towers = true
			spec.gate_towers = true
			spec.side_towers = maxi(spec.side_towers, 1)
		"caernarfon":
			spec.tower_shape = &"polygonal"
			spec.corner_towers = true
			spec.gate_towers = true
			spec.side_towers = maxi(spec.side_towers, 2)
		"neuschwanstein":
			spec.tower_roof = &"cone"
			spec.corner_towers = true
			spec.dormers = true
		"himeji":
			spec.keep_shape = &"tiered"
			spec.tower_roof = &"tiered"
			spec.corner_towers = true
		"chambord":
			spec.tower_shape = &"round"
			spec.tower_roof = &"cone"
			spec.corner_towers = true
			spec.dormers = true
		"krak":
			_force_concentric(spec)
		"alhambra":
			spec.tower_shape = &"square"
			spec.tower_roof = &"flat"
			spec.side_towers = maxi(spec.side_towers, 2)
		"windsor":
			spec.keep_shape = &"shell"
			spec.corner_towers = true


## A concentric castle is two enceintes with a walled causeway between the
## gates. It only exists when there is room for it, so this hands the job to
## CastleGenerator and then asks the spec what it got: at small scales Krak is
## simply a large castle.
static func _force_concentric(spec: CastleSpec) -> void:
	spec.corner_towers = true
	CastleGenerator.force_inner_ward(spec)


# --------------------------------------------------------- geometry assertions

## For each landmark, confirm the forced feature actually produced structural
## geometry -- not just a flag flipped on a spec nobody read.
static func _check_required_masses(key: String, spec: CastleSpec,
		builder: CastleBuilder, who: String, res: SuiteResult, scale: float) -> void:
	match key:
		"longhouse":
			_require(builder, who, res, "hall", "hall block")
			_require(builder, who, res, "chimney_0", "chimney stack")
		"stokesay":
			_require(builder, who, res, "hall", "hall range")
			_require(builder, who, res, "wing_left", "cross wing")
			_require(builder, who, res, "tower_manor_0", "defensible tower")
		"hampton_range":
			_require(builder, who, res, "range_front", "range closing the courtyard")
			_require(builder, who, res, "chimney_0", "chimney stack")
		"bodiam":
			_require(builder, who, res, "wall_0_back", "curtain wall")
			_require(builder, who, res, "tower_0_corner_3", "four corner drum towers")
			_require(builder, who, res, "tower_0_gate_0", "twin-towered gatehouse")
			_require(builder, who, res, "keep", "residential range in the courtyard")
		"caernarfon":
			_require(builder, who, res, "tower_0_side_0", "mural towers along the walls")
			_require(builder, who, res, "gate_0", "gatehouse")
		"neuschwanstein":
			_require(builder, who, res, "tower_0_corner_0", "corner towers with spires")
			_require(builder, who, res, "hall", "palas range")
		"himeji":
			_require(builder, who, res, "keep", "tiered tenshu")
		"chambord":
			_require(builder, who, res, "tower_0_corner_0", "corner drum towers")
			_require(builder, who, res, "keep", "central keep")
		"krak":
			_require(builder, who, res, "wall_0_back", "outer curtain")
			if spec.inner_ward:
				_require(builder, who, res, "wall_1_back", "inner curtain")
				_require(builder, who, res, "link_left", "causeway between the gates")
			elif is_equal_approx(scale, 1.0):
				res.fail("%s: at full size Krak must be concentric, and is not" % who)
		"alhambra":
			_require(builder, who, res, "tower_0_side_0", "square mural towers")
		"windsor":
			_require(builder, who, res, "keep", "shell keep")


static func _require(builder: CastleBuilder, who: String, res: SuiteResult,
		prefix: String, feature: String) -> void:
	if not builder.has_mass(prefix):
		res.fail("%s: %s did not produce a mass starting with '%s'" % [who, feature, prefix])

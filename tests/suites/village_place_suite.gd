extends RefCounted
## VILLAGE-PLACE (`vplace`; docs/VILLAGE_PLACE.md): a place described by its
## features makes a region row the builders take, for every preset and for
## three hundred places nobody thought of; each feature moves what it says
## it moves and a stated feature beats a derived one; the presets are places
## a person could tell apart; what a place says of the village reaches the
## spec; four far-apart places keep their own signature as programmes; and
## the controls fail -- a British hamlet is not a Sahel town, a rotting place
## is not judged by the kept one's paint, a wrong feature is refused.
##
## Programme-level, like `vvernacular`: households are drawn and dwellings
## generated and measured, but no village is laid out. `vplacebuild` builds
## every house type of every preset.

const POP := 40
const SEED := 5
const DRAWS := 300
const FUZZ := 300
## The six places the feature set was asked to reach, by name.
const ASKED: Array[String] = ["provence_hill", "nordic_mountain", "british_hamlet", "russian_collective",
	"congo_forest", "asian_city"]
const PROGRAMMES: Array[String] = ["nordic_mountain", "sahel_town", "asian_city", "rotting_frontier"]


static func run() -> SuiteResult:
	var res := SuiteResult.new("vplace")
	var t0 := Time.get_ticks_msec()
	_features(res)
	_presets(res)
	_fuzz(res)
	_refusals(res)
	_derivations(res)
	_sweeps(res)
	_decay(res)
	_distinct(res)
	_settings(res)
	_programmes(res)
	_moves_nothing(res)
	res.note("total %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	return res


static func _ok(res: SuiteResult, cond: bool, why: String) -> void:
	res.checked += 1
	if not cond:
		res.fail(why)


# ------------------------------------------------------------ the feature set

static func _features(res: SuiteResult) -> void:
	for k in VillagePlace.FEATURES:
		var row: Dictionary = VillagePlace.FEATURES[k]
		_ok(res, String(row.get("group", "")) in VillagePlace.GROUPS and not String(row.get("say", "")).is_empty()
			and String(row.get("kind", "")) in ["share", "name", "names"],
			"features: '%s' wants a group, a kind and a say" % k)
		_ok(res, bool(row.get("derived", false)) or row.has("default"),
			"features: '%s' is neither derived nor has a default" % k)
	var d := VillagePlace.describe()
	_ok(res, (d["features"] as Array).size() == VillagePlace.FEATURES.size()
		and (d["presets"] as Array).size() == VillagePlace.PRESETS.size(), "describe: not every feature and preset")
	# no features at all is still a place: every feature derived
	var f := VillagePlace.derive({})
	var missing: Array = []
	for k in VillagePlace.FEATURES:
		if not f.has(k):
			missing.append(k)
	_ok(res, missing.is_empty(), "derive: {} leaves %s without a value" % str(missing))
	_ok(res, (VillagePlace.ensure({})["errors"] as Array).is_empty(), "the empty place is refused: %s" % str(VillagePlace.ensure({})["errors"]))
	res.note("%d features in %d groups, %d presets, %d paints, %d tongues" % [VillagePlace.FEATURES.size(),
		VillagePlace.GROUPS.size(), VillagePlace.PRESETS.size(), VillagePlace.HUES.size(), VillagePlace.TONGUES.size()])


static func _presets(res: SuiteResult) -> void:
	for id in VillagePlace.preset_ids():
		var p := VillagePlace.parse({"like": id})
		_ok(res, (p["errors"] as Array).is_empty(), "preset %s: %s" % [id, str(p["errors"])])
		var stated: Dictionary = p["features"]
		_ok(res, stated.has("tongue") and stated.has("sacred"), "preset %s states no tongue or landmark" % id)
		var row := VillagePlace.synthesise(stated, id)
		var errs := VillageVernacular.region_errors(row)
		_ok(res, errs.is_empty(), "preset %s: the row is refused: %s" % [id, str(errs)])
		# pure in the stated features
		_ok(res, var_to_str(row) == var_to_str(VillagePlace.synthesise(stated, id)), "preset %s: two syntheses differ" % id)
		_ok(res, VillagePlace.region_id(stated, id) == StringName("place_" + id), "preset %s: id" % id)
	# an override of a preset is another place, with another id
	var a: Dictionary = VillagePlace.ensure({"like": "british_hamlet"})
	var b: Dictionary = VillagePlace.ensure({"like": "british_hamlet", "upkeep": 0.1})
	_ok(res, a["id"] != b["id"] and (b["errors"] as Array).is_empty(), "an overridden preset kept the preset's id")
	# a stated feature is kept exactly; a derived one is not stated
	var f := VillagePlace.derive({"heat": 0.9, "rain": 0.1, "flat_roofs": 0.0, "timber": 1.0})
	_ok(res, is_equal_approx(float(f["flat_roofs"]), 0.0) and is_equal_approx(float(f["timber"]), 1.0),
		"a stated feature lost to its derivation")


## Places nobody thought of: a random subset of the features at random
## values. Every one must make a row the builders take.
static func _fuzz(res: SuiteResult) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261115
	var shares: Array[String] = []
	for k in VillagePlace.FEATURES:
		if String(VillagePlace.FEATURES[k]["kind"]) == "share":
			shares.append(String(k))
	var refused := 0
	var styles := {}
	var types_min := 99
	var types_max := 0
	for i in range(FUZZ):
		var place := {}
		for k in shares:
			if rng.randf() < 0.45:
				# the ends are where formulas break
				var roll := rng.randf()
				place[k] = 0.0 if roll < 0.12 else (1.0 if roll > 0.88 else snappedf(rng.randf(), 0.01))
		if rng.randf() < 0.3:
			place["sacred"] = ["basilica", "spire", "dome", "stave"][rng.randi_range(0, 3)]
		var stated: Dictionary = VillagePlace.parse(place)["features"]
		var row := VillagePlace.synthesise(stated)
		var errs := VillageVernacular.region_errors(row)
		if not errs.is_empty():
			refused += 1
			if refused <= 5:
				res.fail("fuzz %d: %s makes a refused row: %s" % [i, JSON.stringify(place), str(errs.slice(0, 3))])
			continue
		types_min = mini(types_min, (row["houses"] as Dictionary).size())
		types_max = maxi(types_max, (row["houses"] as Dictionary).size())
		for tid in row["houses"]:
			styles[String(row["houses"][tid]["style"])] = true
		# every tier has somewhere to live, and the shop is one of the types
		for tier in ["poor", "middle", "rich"]:
			var lives := false
			for tid in row["houses"]:
				lives = lives or float(row["houses"][tid]["tiers"].get(tier, 0.0)) > 0.0
			if not lives and not (row["houses"] as Dictionary).is_empty():
				continue   # _pick_type falls back to the next tier
	res.checked += FUZZ
	_ok(res, refused == 0, "fuzz: %d of %d random places made a row the builders refuse" % [refused, FUZZ])
	# the space reaches every chassis a village house can be
	for want in ["cottage", "farmhouse", "townhouse", "longhall", "rich", "mediterranean", "asian", "african",
			"thatch_cottage", "roundhouse", "pueblo"]:
		_ok(res, styles.has(want), "fuzz: no random place ever called for the %s chassis" % want)
	res.note("fuzz: %d random places, %d refused, %d..%d house types, chassis %d of 11" % [FUZZ, refused,
		types_min, types_max, styles.size()])


static func _refusals(res: SuiteResult) -> void:
	for bad in [{"heatt": 0.5}, {"heat": 1.5}, {"heat": "hot"}, {"like": "atlantis"}, {"hues": ["mauve"]},
			{"hues": []}, {"sacred": "pagoda"}, {"water": "ocean"}, {"tongue": "klingon"}]:
		var errs: Array = VillagePlace.parse(bad)["errors"]
		_ok(res, not errs.is_empty(), "refusal: %s was taken" % JSON.stringify(bad))
	var request := BuildingRequest.village(SEED, POP)
	request.vernacular = {"place": {"heat": 7}}
	var codes: Array = []
	for e in BuildingLibrary.validate(request):
		codes.append(String(e.get("code", "")))
	_ok(res, codes.has("invalid_vernacular"), "the library took a place with heat 7 (%s)" % str(codes))
	request.vernacular = {"place": {"like": "greek_island"}}
	_ok(res, BuildingLibrary.validate(request).is_empty(), "the library refused a preset: %s" % str(BuildingLibrary.validate(request)))
	# the place survives the request's own document
	var back := BuildingRequest.from_dict(request.to_dict())
	_ok(res, back != null and back.vernacular == request.vernacular, "a place did not survive to_dict/from_dict")
	var house := BuildingRequest.house(SEED)
	house.vernacular = {"place": {"like": "greek_island"}}
	_ok(res, not BuildingLibrary.validate(house).is_empty(), "a house took a place")


# ------------------------------------------------------------ what follows from what

static func _derivations(res: SuiteResult) -> void:
	var d := func(stated: Dictionary) -> Dictionary: return VillagePlace.derive(stated)
	# height cools: the same latitude is colder up the mountain
	_ok(res, VillagePlace.warmth(d.call({"heat": 0.6, "altitude": 0.9})) < VillagePlace.warmth(d.call({"heat": 0.6, "altitude": 0.0})) - 0.2,
		"altitude does not cool")
	# rain grows forest; the tree line and the desert take it away
	_ok(res, float(d.call({"rain": 0.9})["forest"]) > float(d.call({"rain": 0.2})["forest"]) + 0.4, "rain grows no forest")
	_ok(res, float(d.call({"rain": 0.9, "altitude": 1.0})["forest"]) < 0.2, "forest above the tree line")
	_ok(res, float(d.call({"altitude": 0.9})["stone"]) > float(d.call({"altitude": 0.0})["stone"]) + 0.3, "a mountain gives no stone")
	_ok(res, float(d.call({"heat": 0.9, "rain": 0.05})["flat_roofs"]) > 0.8, "a hot desert pitches its roofs")
	_ok(res, float(d.call({"heat": 0.9, "rain": 0.9})["flat_roofs"]) < 0.01, "a rainforest has flat roofs")
	_ok(res, float(d.call({"heat": 0.1, "rain": 0.1})["flat_roofs"]) < 0.01, "a cold desert has flat roofs")
	_ok(res, float(d.call({"wealth": 0.9})["upkeep"]) > float(d.call({"wealth": 0.1})["upkeep"]) + 0.2, "wealth does not keep a place")
	_ok(res, float(d.call({"heat": 0.95, "rain": 0.95})["raised"]) > 0.7, "the hot wet does not raise its floors")
	_ok(res, float(d.call({"heat": 0.15, "rain": 0.6})["long"]) > 0.2, "the cold forest has no longhouse")
	# the layout is the measured row nearest the crowding, in a climate it could be
	_ok(res, VillagePlace.layout_culture(d.call({"heat": 0.8, "rain": 0.3, "density": 0.9})) == &"mediterranean", "a packed warm place is not laid out Mediterranean")
	_ok(res, VillagePlace.layout_culture(d.call({"heat": 0.2, "density": 0.1})) == &"norse", "a scattered cold place is not laid out Norse")
	_ok(res, not VillagePlace.layout_culture(d.call({"heat": 0.4, "rain": 0.7, "density": 0.2})) in [&"saharan", &"moorish", &"east_asian"],
		"a scattered wet temperate place took a hot or an eastern culture")
	# a place between two places
	var mid := VillagePlace.mix({"like": "greek_island"}, {"like": "nordic_mountain"}, 0.5)
	_ok(res, (VillagePlace.ensure(mid)["errors"] as Array).is_empty(), "the midpoint of two presets is refused")
	_ok(res, absf(float(mid["heat"]) - 0.5) < 0.01, "mix does not interpolate")


## `n` households of a place drawn as a village draws them.
static func _draw(place: Dictionary, n := DRAWS) -> Dictionary:
	var fs := VillageVernacular.resolve({"place": place})
	var out := {"n": 0, "style": {}, "material": {}, "form": {}, "walls": {}, "pitch": 0.0, "storeys": 0.0,
		"jank": 0, "lean": 0.0, "shutters": 0.0, "chimney": 0.0, "grime": 0.0, "tiers": {}, "types": {}}
	if fs == null:
		return out
	var f := VillagePlace.derive(VillagePlace.parse(place)["features"])
	var areas: Array[float] = []
	for i in range(n):
		areas.append(300.0 - float(i) * 0.5)
	var tiers := fs.tiers_by_area(areas, float(f["wealth"]))
	var grime := VillageVernacular.grime(fs.place_id)
	for i in range(n):
		var g := fs.house("sweep|%d" % i, tiers[i], &"farming", &"")
		var look: Dictionary = g["look"]
		_count(out["style"], String(g["style"]))
		_count(out["material"], String(look.get("roof_material", "?")))
		_count(out["form"], String(g["clusters"]["roof_form"]))
		_count(out["walls"], String(g["clusters"]["walls"]))
		_count(out["tiers"], String(tiers[i]))
		_count(out["types"], String(g["type"]))
		var pitch: Array = look.get("roof_pitch", [0.0, 0.0])
		out["pitch"] = float(out["pitch"]) + (float(pitch[0]) + float(pitch[1])) * 0.5
		out["storeys"] = float(out["storeys"]) + float(g["storeys"])
		out["jank"] = int(out["jank"]) + int(float(g["jank"]) > 0.0)
		out["lean"] = float(out["lean"]) + float(g["jank"])
		out["shutters"] = float(out["shutters"]) + float(look.get("shutters", 0.0))
		out["chimney"] = float(out["chimney"]) + float(look.get("chimney", 0.0))
		var wall := Color(String(look["wall"][0]))
		out["grime"] = float(out["grime"]) + Vector3(wall.r - grime.r, wall.g - grime.g, wall.b - grime.b).length()
	out["n"] = n
	for k in ["pitch", "storeys", "lean", "shutters", "chimney", "grime"]:
		out[k] = float(out[k]) / float(n)
	return out


static func _count(d: Dictionary, k: String) -> void:
	d[k] = int(d.get(k, 0)) + 1


static func _share(drawn: Dictionary, group: String, keys: Array) -> float:
	var hits := 0
	for k in drawn[group]:
		var hit := false
		for want in keys:
			hit = hit or String(k).contains(String(want))
		hits += int(drawn[group][k]) if hit else 0
	return float(hits) / float(maxi(int(drawn["n"]), 1))


## One feature moved, everything else held: the drawn village moves the way
## the feature says.
static func _sweeps(res: SuiteResult) -> void:
	# rain steepens the roofs
	var dry := _draw({"heat": 0.5, "rain": 0.15, "flat_roofs": 0.0})
	var wet := _draw({"heat": 0.5, "rain": 0.9, "flat_roofs": 0.0})
	_ok(res, float(wet["pitch"]) > float(dry["pitch"]) + 0.2, "rain: the pitch is %.2f wet and %.2f dry" % [wet["pitch"], dry["pitch"]])
	# drought flattens them
	var desert := _draw({"heat": 0.9, "rain": 0.05})
	var jungle := _draw({"heat": 0.9, "rain": 0.95})
	_ok(res, _share(desert, "form", ["flat"]) >= 0.8 and _share(jungle, "form", ["flat"]) == 0.0,
		"drought: flat roofs %.2f in the desert, %.2f in the jungle" % [_share(desert, "form", ["flat"]), _share(jungle, "form", ["flat"])])
	# the land's materials are the walls
	var woods := _draw({"heat": 0.35, "rain": 0.6, "timber": 1.0, "stone": 0.1, "earth": 0.1})
	var crags := _draw({"heat": 0.35, "rain": 0.6, "timber": 0.05, "stone": 1.0, "earth": 0.1})
	var plain := _draw({"heat": 0.35, "rain": 0.6, "timber": 0.05, "stone": 0.05, "earth": 1.0})
	_ok(res, _share(woods, "walls", ["timber", "hardwood", "paint"]) >= 0.9, "timber: only %.2f of walls are timber in a forest" % _share(woods, "walls", ["timber", "hardwood", "paint"]))
	_ok(res, _share(crags, "walls", ["stone", "limestone"]) >= 0.6, "stone: only %.2f of walls are stone on a crag" % _share(crags, "walls", ["stone", "limestone"]))
	_ok(res, _share(plain, "walls", ["cob", "clay", "mud", "adobe", "laterite", "earth plaster", "lime white"]) >= 0.9,
		"earth: only %.2f of walls are earth on a clay plain" % _share(plain, "walls", ["cob", "clay", "mud", "adobe", "laterite", "earth plaster", "lime white"]))
	# the cold wants a fire
	var cold := _draw({"heat": 0.15, "rain": 0.5})
	var hot := _draw({"heat": 0.9, "rain": 0.5})
	_ok(res, float(cold["chimney"]) > float(hot["chimney"]) + 0.5, "cold: chimneys %.2f cold, %.2f hot" % [cold["chimney"], hot["chimney"]])
	# money: off the thatch, up a storey
	var poor := _draw({"heat": 0.45, "rain": 0.6, "wealth": 0.1})
	var rich := _draw({"heat": 0.45, "rain": 0.6, "wealth": 0.9})
	_ok(res, _share(poor, "material", ["thatch"]) > _share(rich, "material", ["thatch"]) + 0.3,
		"wealth: thatch %.2f poor, %.2f rich" % [_share(poor, "material", ["thatch"]), _share(rich, "material", ["thatch"])])
	_ok(res, float(rich["storeys"]) > float(poor["storeys"]) + 0.15, "wealth: storeys %.2f poor, %.2f rich" % [poor["storeys"], rich["storeys"]])
	_ok(res, int(rich["tiers"].get("rich", 0)) > int(poor["tiers"].get("rich", 0)), "wealth: no more rich households in a rich place")
	# crowding: the street's house, and a storey
	var farms := _draw({"heat": 0.45, "rain": 0.6, "density": 0.1})
	var town := _draw({"heat": 0.45, "rain": 0.6, "density": 0.95})
	_ok(res, _share(town, "style", ["townhouse"]) > _share(farms, "style", ["townhouse"]) + 0.3,
		"density: town houses %.2f packed, %.2f scattered" % [_share(town, "style", ["townhouse"]), _share(farms, "style", ["townhouse"])])
	_ok(res, float(town["storeys"]) > float(farms["storeys"]) + 0.3, "density: storeys %.2f packed, %.2f scattered" % [town["storeys"], farms["storeys"]])
	# equals and unequals
	var commune := _draw({"inequality": 0.0})
	var manor := _draw({"inequality": 1.0})
	_ok(res, int(commune["tiers"].get("middle", 0)) > int(manor["tiers"].get("middle", 0)) + DRAWS / 4,
		"inequality: %d middling households among equals, %d under a lord" % [commune["tiers"].get("middle", 0), manor["tiers"].get("middle", 0)])
	# a planned place builds to fewer patterns
	var grown := VillagePlace.synthesise({"heat": 0.45, "rain": 0.6, "timber": 0.6, "stone": 0.6, "earth": 0.6, "order": 0.0})
	var planned := VillagePlace.synthesise({"heat": 0.45, "rain": 0.6, "timber": 0.6, "stone": 0.6, "earth": 0.6, "order": 1.0})
	_ok(res, (planned["houses"] as Dictionary).size() < (grown["houses"] as Dictionary).size(),
		"order: %d types planned, %d grown" % [(planned["houses"] as Dictionary).size(), (grown["houses"] as Dictionary).size()])
	# the habits: stated, they are the village
	_ok(res, _share(_draw({"heat": 0.8, "rain": 0.5, "round": 1.0}), "style", ["roundhouse"]) >= 0.95, "round: not every house is round")
	_ok(res, _share(_draw({"heat": 0.6, "rain": 0.7, "raised": 1.0, "swept_roof": 1.0}), "form", ["irimoya"]) >= 0.95, "swept roof: not every roof is")
	_ok(res, _share(_draw({"heat": 0.2, "rain": 0.6, "long": 1.0}), "style", ["longhall"]) >= 0.95, "long: not every house is a longhouse")
	_ok(res, _share(_draw({"heat": 0.7, "rain": 0.3, "stone": 0.8, "whitewash": 1.0}), "walls", ["lime white"]) >= 0.9, "whitewash: not every wall is white")
	var painted := VillagePlace.synthesise({"timber": 1.0, "colour": 1.0, "hues": ["blue"]})
	var bare := VillagePlace.synthesise({"timber": 1.0, "colour": 0.0, "hues": ["blue"]})
	var has_blue := func(row: Dictionary) -> bool:
		for c in row["trim"]:
			if String(c["name"]) == "blue paint":
				return true
		return false
	_ok(res, has_blue.call(painted) and not has_blue.call(bare), "colour: paint is not what puts blue on the doors")
	res.note("sweeps: pitch %.2f -> %.2f with rain; thatch %.2f -> %.2f and storeys %.2f -> %.2f with wealth; town houses %.2f -> %.2f with density" % [
		dry["pitch"], wet["pitch"], _share(poor, "material", ["thatch"]), _share(rich, "material", ["thatch"]),
		poor["storeys"], rich["storeys"], _share(farms, "style", ["townhouse"]), _share(town, "style", ["townhouse"])])


## Wealth without care, and care without wealth: decay is its own feature.
static func _decay(res: SuiteResult) -> void:
	var base := {"heat": 0.4, "rain": 0.7, "wealth": 0.4}
	var kept := base.duplicate()
	kept["upkeep"] = 1.0
	var rotten := base.duplicate()
	rotten["upkeep"] = 0.0
	var a := _draw(kept)
	var b := _draw(rotten)
	_ok(res, float(b["grime"]) < float(a["grime"]) - 0.08, "decay: walls are %.3f from the grime kept and %.3f rotten" % [a["grime"], b["grime"]])
	_ok(res, int(a["jank"]) == 0 and int(b["jank"]) >= DRAWS * 2 / 3, "decay: %d houses lean kept, %d rotten" % [a["jank"], b["jank"]])
	_ok(res, float(b["lean"]) <= 0.35 + 1e-6, "decay: the mean lean %.2f is past what a standing house has" % b["lean"])
	_ok(res, float(b["shutters"]) < float(a["shutters"]) - 0.15, "decay: shutters %.2f kept, %.2f rotten" % [a["shutters"], b["shutters"]])
	var rk := VillagePlace.synthesise(VillagePlace.parse(kept)["features"])
	var rr := VillagePlace.synthesise(VillagePlace.parse(rotten)["features"])
	_ok(res, float(rr["wealth"]["weathering"]["poor"]) > float(rk["wealth"]["weathering"]["poor"]) + 0.4, "decay: weathering does not follow upkeep")
	# the houses themselves are the same houses: decay is not poverty
	_ok(res, (rk["houses"] as Dictionary).keys() == (rr["houses"] as Dictionary).keys(), "decay: letting a place go changed which houses it has")
	# a rich place let go is still built rich
	var grand := _draw({"heat": 0.4, "rain": 0.7, "wealth": 0.9, "upkeep": 0.05})
	_ok(res, _share(grand, "material", ["thatch"]) < 0.2 and int(grand["jank"]) > 0, "decay: a rich ruin is thatched or stands plumb")
	# wet rots green, dry bleaches to dust
	var moss := VillageVernacular.grime(VillagePlace.ensure({"heat": 0.5, "rain": 0.95})["id"])
	var dust := VillageVernacular.grime(VillagePlace.ensure({"heat": 0.8, "rain": 0.05})["id"])
	_ok(res, moss.g > moss.r and dust.r > dust.g and dust.v > moss.v + 0.15, "decay: grime is %s wet and %s dry" % [moss.to_html(false), dust.to_html(false)])
	# the village's own settings follow
	_ok(res, float(VillagePlace.settings(rotten)["upkeep"]) < 0.05 and float(VillagePlace.settings(kept)["upkeep"]) > 0.95, "decay: upkeep does not reach the village")
	_ok(res, float(VillagePlace.settings({"wealth": 0.9, "upkeep": 1.0, "ornament": 1.0})["decoration_level"])
		> float(VillagePlace.settings({"wealth": 0.1, "upkeep": 0.1})["decoration_level"]) + 0.4, "a kept rich place is no more decorated than a poor rotten one")
	res.note("decay: grime distance %.3f -> %.3f, leaning %d -> %d of %d, shutters %.2f -> %.2f" % [a["grime"], b["grime"],
		a["jank"], b["jank"], DRAWS, a["shutters"], b["shutters"]])


# ------------------------------------------------------------ the presets as places

static func _distinct(res: SuiteResult) -> void:
	var marks := {}
	var draws := {}
	for id in VillagePlace.preset_ids():
		var drawn := _draw({"like": id})
		draws[id] = drawn
		marks[id] = {"style": _top(drawn["style"]), "material": _top(drawn["material"]), "walls": _top(drawn["walls"]),
			"form": _top(drawn["form"]), "storeys": roundi(float(drawn["storeys"]) * 2.0),
			"culture": String(VillagePlace.region({"like": id})["culture"])}
	# the six that were asked for by name are different villages: between any
	# two, the house styles, roof coverings and wall finishes are drawn in
	# shares that differ by 0.6 in all (total variation, each 0..1). The two
	# nearest are the two cold timber places.
	var nearest := INF
	var nearest_pair := ""
	for i in range(ASKED.size()):
		for j in range(i + 1, ASKED.size()):
			var apart := 0.0
			for group in ["style", "material", "walls"]:
				apart += _tv(draws[ASKED[i]][group], draws[ASKED[j]][group])
			if apart < nearest:
				nearest = apart
				nearest_pair = "%s / %s" % [ASKED[i], ASKED[j]]
			_ok(res, apart >= 0.6, "%s and %s are only %.2f apart (%s / %s)" % [ASKED[i], ASKED[j], apart,
				str(marks[ASKED[i]]), str(marks[ASKED[j]])])
	res.note("the six asked for: the nearest two are %s, %.2f apart of 3" % [nearest_pair, nearest])
	var seen := {}
	for id in marks:
		seen[var_to_str(marks[id])] = id
	_ok(res, seen.size() >= VillagePlace.PRESETS.size() - 2, "only %d distinct places among %d presets" % [seen.size(), VillagePlace.PRESETS.size()])
	for id in ASKED:
		res.note("%-19s %s" % [id, str(marks[id])])
	# and each is what it says
	var expect := {
		"provence_hill": {"material": "tile", "culture": "mediterranean"},
		"greek_island": {"form": "flat", "walls": "lime white"},
		"nordic_mountain": {"culture": "norse"},
		"british_hamlet": {"material": "thatch", "culture": "english"},
		"congo_forest": {"style": "roundhouse", "material": "thatch"},
		"savanna_kraal": {"style": "roundhouse"},
		"sahel_town": {"form": "flat"},
		"asian_city": {"style": "asian", "material": "tile", "form": "irimoya"},
		"japanese_farm": {"style": "asian", "culture": "east_asian"},
		"highland_croft": {"material": "thatch"},
	}
	for id in expect:
		for k in expect[id]:
			_ok(res, String(marks[id][k]) == String(expect[id][k]), "%s: its %s is %s, not %s" % [id, k, marks[id][k], expect[id][k]])
	_ok(res, String(marks["nordic_mountain"]["walls"]).contains("timber") or String(marks["nordic_mountain"]["walls"]).contains("paint"),
		"nordic_mountain: its walls are %s" % marks["nordic_mountain"]["walls"])
	_ok(res, String(marks["russian_collective"]["walls"]).contains("timber"), "russian_collective: its walls are %s" % marks["russian_collective"]["walls"])
	# a collective is houses of one pattern; a hamlet is not
	_ok(res, (VillagePlace.region({"like": "russian_collective"})["houses"] as Dictionary).size()
		< (VillagePlace.region({"like": "british_hamlet"})["houses"] as Dictionary).size(), "the collective has as many house types as the hamlet")


## Total variation between two count tables, 0 (the same shares) to 1.
static func _tv(a: Dictionary, b: Dictionary) -> float:
	var na := 0
	var nb := 0
	for k in a:
		na += int(a[k])
	for k in b:
		nb += int(b[k])
	var keys := {}
	for k in a:
		keys[k] = true
	for k in b:
		keys[k] = true
	var sum := 0.0
	for k in keys:
		sum += absf(float(a.get(k, 0)) / float(maxi(na, 1)) - float(b.get(k, 0)) / float(maxi(nb, 1)))
	return sum * 0.5


static func _top(d: Dictionary) -> String:
	var best := ""
	for k in d:
		if best.is_empty() or int(d[k]) > int(d[best]) or (int(d[k]) == int(d[best]) and String(k) < best):
			best = String(k)
	return best


# ------------------------------------------------------------ the village

static func _spec(place: Variant, wealth := 0.4, pop := POP) -> VillageSpec:
	var spec := VillageSpec.new(SEED)
	spec.population = pop
	spec.wealth = wealth
	spec.vernacular = {"place": place if place is Dictionary else {"like": String(place)}}
	VillagePlace.apply(spec)
	spec.generate(SEED)
	return spec


static func _settings(res: SuiteResult) -> void:
	# what the place states reaches the spec
	var spec := _spec("greek_island")
	_ok(res, spec.valid() and spec.water == &"coast" and spec.purpose == &"fishing" and is_equal_approx(spec.wealth, 0.45),
		"greek_island: water %s purpose %s wealth %.2f, errors %s" % [spec.water, spec.purpose, spec.wealth, str(spec.errors())])
	_ok(res, spec.effective_culture() == &"mediterranean", "greek_island: built in the %s culture" % spec.effective_culture())
	# where the place is silent the request stands, and its wealth moves the place
	var poor := _spec({"heat": 0.45, "rain": 0.6}, 0.1)
	var rich := _spec({"heat": 0.45, "rain": 0.6}, 0.9)
	_ok(res, is_equal_approx(poor.wealth, 0.1) and is_equal_approx(rich.wealth, 0.9), "a place with no wealth changed the request's")
	_ok(res, poor.feature_set().place_id != rich.feature_set().place_id, "the request's wealth does not reach a place that states none")
	_ok(res, poor.upkeep < rich.upkeep - 0.2, "upkeep %.2f poor, %.2f rich" % [poor.upkeep, rich.upkeep])
	# a wall wants the people to man it
	_ok(res, _spec("desert_oasis").enclosure == &"palisade" and _spec("desert_oasis", 0.4, 200).enclosure == &"wall",
		"desert_oasis: enclosure %s at 40 people, %s at 200" % [_spec("desert_oasis").enclosure, _spec("desert_oasis", 0.4, 200).enclosure])
	# ...the civic people man it (60 shown, 5000 implied), and a garrison at any size
	var implied := VillageSpec.new(SEED)
	implied.population = 60
	implied.implied_population = 5000
	implied.vernacular = {"place": {"like": "desert_oasis"}}
	VillagePlace.apply(implied)
	var garrison := VillageSpec.new(SEED)
	garrison.population = 40
	garrison.purpose = &"garrison"
	garrison.vernacular = {"place": {"like": "desert_oasis"}}
	VillagePlace.apply(garrison)
	_ok(res, implied.enclosure == &"wall" and implied.valid() and garrison.enclosure == &"wall" and garrison.valid(),
		"desert_oasis: 60 shown and 5000 implied keep '%s', a garrison of 40 '%s'" % [implied.enclosure, garrison.enclosure])
	# a place that makes a small walled garrison a market leaves it a palisade,
	# not a spec that refuses itself
	var held := VillageSpec.new(SEED)
	held.population = 40
	held.purpose = &"garrison"
	held.enclosure = &"wall"
	held.vernacular = {"place": {"like": "rhine_town"}}
	VillagePlace.apply(held)
	_ok(res, held.purpose == &"market" and held.enclosure == &"palisade" and held.valid(),
		"rhine_town over a walled garrison of 40: purpose %s, enclosure %s, errors %s" % [held.purpose, held.enclosure, held.errors()])
	# a place leaves a caller's own upkeep alone when it is the lower
	var worn := VillageSpec.new(SEED)
	worn.upkeep = 0.1
	worn.vernacular = {"place": {"like": "jewel_harbour"}}
	VillagePlace.apply(worn)
	_ok(res, is_equal_approx(worn.upkeep, 0.1), "the place raised an upkeep the caller had lowered")
	# the request factory
	var request := VillagePlace.request(SEED, 60, "sahel_town")
	_ok(res, request.kind == &"village" and request.purpose == &"market" and BuildingLibrary.validate(request).is_empty(),
		"VillagePlace.request: %s" % str(BuildingLibrary.validate(request)))
	# names in the place's tongue, the label in words
	var fs := _spec("russian_collective").feature_set()
	_ok(res, fs.label() == "Russian farming collective" and not fs.village_name(SEED).is_empty(), "label '%s'" % fs.label())
	_ok(res, not _spec({"heat": 0.2, "rain": 0.7}).feature_set().label().is_empty(), "an unnamed place has no label")
	# the ground a place stands on
	var ground := VillagePlace.terrain({"like": "nordic_mountain"}, Rect2(-200, -200, 400, 400), 10.0)
	_ok(res, ground.valid() and ground.relief() > 100.0, "nordic_mountain: the ground is %s with %.0f m of relief" % [
		"valid" if ground.valid() else str(ground.errors()), ground.relief()])
	_ok(res, VillagePlace.terrain({"like": "russian_collective"}, Rect2(-200, -200, 400, 400), 10.0).relief() < 10.0, "the collective's plain is not flat")
	# a blend may name the place beside a region
	var both := VillageVernacular.resolve({"place": {"like": "congo_forest"}, "blend": {"place": 0.5, "norse": 0.5}})
	_ok(res, both != null and both.blend.size() == 2 and both.blend.has(&"place_congo_forest"), "a place does not blend with a region")
	# the description a UI reads
	var described: Dictionary = BrickWild.describe_kind(&"village").get("vernacular", {})
	_ok(res, described.has("place") and (described["place"]["features"] as Array).size() == VillagePlace.FEATURES.size(),
		"describe_kind(village) does not publish the feature set")
	for row in described.get("regions", []):
		_ok(res, not String(row["id"]).begins_with("place_"), "a synthesised place is listed as a region: %s" % row["id"])


## Four places far apart, as programmes: every dwelling generated and judged
## by the row the place made.
static func _programmes(res: SuiteResult) -> void:
	var measured := {}
	for id in PROGRAMMES:
		var t0 := Time.get_ticks_msec()
		var spec := _spec(id)
		_ok(res, spec.valid(), "%s: the spec is refused: %s" % [id, str(spec.errors())])
		var requests := VillageProgrammer.programme(spec)
		measured[id] = VillageVernacularCheck.measure_requests(requests)
		var rep := VillageVernacularCheck.new().check(measured[id], spec.feature_set())
		res.checked += 1
		for f in rep["failures"]:
			res.fail("%s: %s" % [id, f])
		var broken := 0
		var leaning := 0
		for row in measured[id]["dwellings"]:
			broken += int(row.get("error", false))
		for r in requests:
			leaning += int(r.jank > 0.0)
			_ok(res, BuildingLibrary.validate(r).is_empty(), "%s: a %s request is refused: %s" % [id, r.kind, str(BuildingLibrary.validate(r))])
		_ok(res, broken == 0, "%s: %d dwellings did not generate" % [id, broken])
		res.note("%-17s %-20s %2d dwellings, %2d leaning, church %s | %.0f s" % [id, spec.variant_name,
			measured[id]["dwellings"].size(), leaning, measured[id]["landmark"], (Time.get_ticks_msec() - t0) / 1000.0])
	_ok(res, _leaning(_spec("rotting_frontier")) > 0 and _leaning(_spec("asian_city")) == 0, "the rotting place stands plumb or the kept one leans")
	# controls: one place's village judged as another is not that place
	var hamlet_as_sahel := VillageVernacularCheck.new().check(measured["nordic_mountain"], _spec("sahel_town").feature_set())
	_ok(res, not hamlet_as_sahel["ok"] and (hamlet_as_sahel["failures"] as Array).size() >= 3,
		"control: a Nordic village passes as a Sahel town (%d complaints)" % (hamlet_as_sahel["failures"] as Array).size())
	var city_as_frontier := VillageVernacularCheck.new().check(measured["asian_city"], _spec("rotting_frontier").feature_set())
	_ok(res, not city_as_frontier["ok"], "control: the merchant city passes as the rotting frontier")
	# control: the rotting place judged by the SAME place kept -- its paint has
	# gone further than a kept place's may
	var kept := VillagePlace.preset("rotting_frontier")
	kept["upkeep"] = 1.0
	var rot_as_kept := VillageVernacularCheck.new().check(measured["rotting_frontier"], _spec(kept).feature_set())
	_ok(res, not rot_as_kept["ok"], "control: a rotting village passes for the same village well kept")
	res.note("controls: Nordic as Sahel %d complaints, city as frontier %d, rotten as kept %d" % [
		(hamlet_as_sahel["failures"] as Array).size(), (city_as_frontier["failures"] as Array).size(), (rot_as_kept["failures"] as Array).size()])


static func _leaning(spec: VillageSpec) -> int:
	var n := 0
	for r in VillageProgrammer.programme(spec):
		n += int(r.jank > 0.0)
	return n


## A region village is the village it was before places existed: no lean, the
## region's own grime, and a genome that differs only by carrying `jank` 0.
static func _moves_nothing(res: SuiteResult) -> void:
	for id in [&"provence", &"norse"]:
		var fs := VillageVernacular.resolve({String(id): 1.0})
		_ok(res, VillageVernacular.grime(id) == VillageVernacular.GRIME, "%s: its grime moved" % id)
		var g := fs.house("7|3", &"poor", &"farming", &"farmer")
		_ok(res, is_equal_approx(float(g["jank"]), 0.0), "%s: a region house leans" % id)
		_ok(res, fs.place.is_empty() and not fs.to_dict().has("place"), "%s: a region blend carries a place" % id)
	var spec := VillageSpec.new(SEED)
	spec.vernacular = {"norse": 1.0}
	var before := [spec.wealth, spec.upkeep, spec.decoration_level, spec.water, spec.purpose, spec.enclosure, var_to_str(spec.vernacular)]
	VillagePlace.apply(spec)
	_ok(res, before == [spec.wealth, spec.upkeep, spec.decoration_level, spec.water, spec.purpose, spec.enclosure, var_to_str(spec.vernacular)],
		"VillagePlace.apply moved a spec with no place")

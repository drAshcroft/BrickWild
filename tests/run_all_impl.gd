extends RefCounted
## Runs every suite in a fixed order, cheapest and most fundamental first, so a
## broken contract is reported before a slow voxel sweep has a chance to bury it.
##
##   Run everything:  godot --headless --script res://tests/run_all.gd
##   Run one suite:   godot --headless --script res://tests/run_all.gd -- massing
##   Run several:     godot --headless --script res://tests/run_all.gd -- castle cmassing
##
## Exits nonzero if any suite fails.

## Order is deliberate: each suite assumes the ones above it hold.
##   1 library    - the public request/generate/build contract
##   1a placement - placement()'s door contract and Placement.world_rect
##   1b poly      - polygon geometry helpers and WalkGrid rasterisation
##   1c props     - the small props no art pack ships (well, palisade, ...)
##   2 church     - the spec/build contract itself
##   3 normals    - the surfaces face the way they are meant to
##   4 massing    - structural correctness of what that contract produced
##   5 blueprint  - the drawing agrees with the model
##   6 landmark   - the famous churches this generator must be able to build
##   7 castle     - the castle spec/build contract, tier by tier
##   8 cnormals   - the castle's surfaces and openings
##   9 cmassing   - structural correctness of what the castle contract produced
##  10 clandmark  - the famous fortifications this generator must be able to build
##  11 voxelqa    - exhaustive rasterized checks of the churches (slow)
##  12 cvoxelqa   - the same, for the castles (slow)
## 12a dressing   - what is in the churches and castles, and can you walk past it
## 12b interior   - the castle interiors, hall and keep, over two hundred castles
##  13 house      - the house spec/plan/build contract
##  14 assets     - the prop catalogue still describes the props
##  15 houseqa    - quick deterministic house QA; use houseqafull explicitly
##  16 hmultistory- explicit levels, stairs, elevations and top roof
##  17 harchetype - the dwellings this generator must be able to furnish
## 17a court      - buildings round a yard: the court rules and a hundred houses
##  18 shop       - the commercial/civic plan/build contract
##  19 sarchetype - defining rooms, fittings, and walkability for village trades
##  20 hotel      - the palatial hotel plan/build contract
##  21 hlandmark  - symmetry, facade landmarks, hotel programme and circulation
##  22 temple     - the temple spec/build contract and its surfaces
##  23 rite       - would a rite work in it: axis, sightline, procession, fire
##  24 tarchetype - the temples a fantasy author would ask for
##  25 village    - VillageSpec's derived fields and VillagePlan's helpers/purity
##  26 vsite      - the site planner: through road, common, landmark slot, streets
##  27 vlot       - the lot planner: frontages, setbacks, fire gaps, corner lots
##  28 vcheck     - the village checks: scale, roads, lots, places (VIL-006..009)
##  29 world      - the buildings of the wider world (WORLD_BUILDINGS), as
##                  archetype rows; `warchetype` is the same suite
##  30 tree      - the generated tree family: four styles, 24 species, ten rules
##  31 bridge    - the bridge family: four kinds, four mechanisms, ten rules
const ORDER: Array[String] = ["library", "placement", "poly", "props", "church", "normals", "massing", "blueprint", "landmark",
	"churchroof", "ctroof", "stoneshell", "cwalk", "cplanshell", "ctowerplan", "ctowerhouse", "cmotteplan", "cforms", "crangeplan", "caperture", "cshop", "psconce", "ckfurnish", "caccess", "cforebuilding", "cgateaccess", "cgatestairs", "castle", "cnormals", "cmassing", "cwater", "clandmark", "voxelqa", "cvoxelqa", "dressing", "interior",
	"roofprobe", "hroof", "hexterior", "hcomponent", "hopening", "hsky", "hdoor", "hbounds", "hjetty", "hmaterials", "henvelope", "house", "assets", "hassembly", "houseqa", "hmultistory", "harchetype", "court",
	"shop", "sarchetype",
	"hotel", "hotelroof", "hlandmark",
	"temple", "rite", "tarchetype",
	"village", "vsite", "vlot", "vcheck", "vforms", "venclosure", "varchetype", "world", "warchetype", "wld001", "wld002", "wld004", "wld005", "wld006", "wld007", "wld009", "wld010", "wld011", "wld012", "wld013", "wld014", "wld015", "wld016", "wld017", "wld018", "wld019",
	"tree", "bridge"]

## Explicit lanes which should not be repeated by the default all-suite run.
const EXTRA: Array[String] = ["vmine", "varchetypecontracts", "vnativeqa", "vwater", "vmill", "vmillfull", "vformslayout", "vformsfull", "vquick",
	"vformsfull_crossroads", "vformsfull_round", "vformsfull_strand", "vformsfull_planted", "vformsfull_gate",
	"roofquick", "houseqacore", "houseqaplan", "metriccoords", "churchaperture", "churchload", "churchchange", "vis016",
	"houseqafurnish", "houseqafurnishfast", "houseqafull", "castlechange", "ckeepstair", "cbergfried", "cterrace", "chimeji", "barracks100", "barracksquick", "librarybiz", "libraryreg", "library100", "prison", "palace", "markethall", "wld001_domus", "wld001_riad",
	"wld001_palazzo", "wld001_domus_07", "wld001_domus_10",
	"wld001_domus_14", "wld001_domus_19", "wld001_riad_07", "wld001_riad_10",
	"wld001_riad_14", "wld001_riad_19", "wld001_palazzo_07",
	"wld001_palazzo_10", "wld001_palazzo_14", "wld001_palazzo_19",
	"dmvbrief",
	"varchetype_thorpe", "varchetype_thorpe_0_07", "varchetype_green_village", "varchetype_ford", "varchetype_mill_village",
	"varchetype_strand", "varchetype_pine_hold", "varchetype_mine_camp", "varchetype_pilgrims_rest", "cas013",
	"varchetype_lords_village", "varchetype_market_town", "varchetype_blight", "varchetype_cap", "wld003", "wld011", "wld014", "wld015", "wld016", "int021",
	"runnererror", "runnerfail", "int012", "int013", "thievesden100"]

## LANES -- the suites worth running for a given KIND OF EDIT.
##
## The slow house suites are slow because they run the FURNISHER SEARCH, not
## because they cover more geometry: `house` spends six minutes to make 123
## checks while `roofquick` makes 2452 in eleven seconds. Running them after an
## emitter or logging change buys most of half an hour and almost no coverage.
## So pick the lane that matches what you touched, and leave the rest to a
## batched sweep.
##
## Measured on this machine, September 2026. Times drift; the ORDER of
## magnitude is the point.
##
##   lane:geom    ~30s   mesh kit, emitters, roof maths, the component log
##   lane:plan    ~4m    the planner, room programme, doors, circulation
##   lane:dress   ~10m   the furnisher, prop recipes, assembly, exteriors
##   lane:assets  ~6m    anything under assets/props/ or catalog.json
##   lane:house-plan-fast     bounded plan and multi-storey checks
##   lane:house-furnish-fast  bounded furnishing and assembly checks
##   lane:house-exterior-fast bounded exterior and assembly checks
##   lane:assets-fast        props and assembly contract (catalogue rebuild separate)
##   lane:village-fast       site, lot and village contract checks
##   lane:castle-change  ~81s body / 91s host: fixed castle geometry and QA
##   lane:castle         exhaustive castle sweeps; schedule separately
##   lane:church-change  ~10s body  bounded roofs, domed styles, openings, massing
##   lane:church         exhaustive church sweeps; schedule separately
##   lane:temple  ~3m    temple geometry and the rite rules
##   lane:sweep   ~40m   everything above; background it, do not wait on it
##   lane:tree    ~1m    anything in src/tree/, qa/tree_check.gd, tree_shapes
##   lane:bridge  ~1m    anything in src/bridge/, qa/bridge_check.gd
##
## Usage: godot --headless --path . --script res://tests/run_all.gd -- lane:geom
## Lanes and bare suite names can be mixed; duplicates run once.
const LANES: Dictionary = {
	"lane:geom": ["roofquick", "hroof", "hcomponent", "hopening", "hsky", "hdoor", "hbounds", "hjetty", "hmaterials", "metriccoords"],
	"lane:plan": ["house", "houseqaplan", "hmultistory"],
	"lane:dress": ["houseqafurnish", "hexterior", "hassembly", "harchetype"],
	"lane:assets": ["assets", "props", "hassembly"],
	"lane:house-plan-fast": ["houseqaplan", "hmultistory"],
	"lane:house-furnish-fast": ["houseqafurnishfast", "hassembly"],
	"lane:house-exterior-fast": ["hexterior", "hassembly"],
	"lane:assets-fast": ["props", "hassembly"],
	"lane:library-change": ["shop", "librarybiz", "libraryreg"],
	"lane:palace-change": ["palace"],
	"lane:village-fast": ["vquick"],
	"lane:castle-change": ["ctowerhouse", "caperture", "cgatestairs", "castlechange", "cbergfried"],
	"lane:castle": ["castle", "cnormals", "cmassing", "clandmark", "cvoxelqa", "ctowerplan", "cmotteplan", "cforms", "caccess", "cforebuilding", "cgateaccess", "cgatestairs", "cbergfried", "cterrace"],
	"lane:church-change": ["churchroof", "churchchange"],
	"lane:church": ["church", "normals", "massing", "churchaperture", "churchload"],
	"lane:temple": ["temple", "rite"],
	"lane:world": ["wld001", "wld002", "wld003", "wld004", "wld005", "wld006", "wld007", "wld009", "wld010", "wld011", "wld012", "wld013", "wld017", "wld018"],
	"lane:tree": ["tree"],
	"lane:bridge": ["bridge"],
	"lane:sweep": ORDER,
}


static func _run_one(key: String) -> SuiteResult:
	match key:
		"runnererror":
			# Intentionally reports a passing result after a parser error. This
			# opt-in fixture proves the runner overrides that false green verdict.
			var broken := GDScript.new()
			broken.source_code = "extends RefCounted\nfunc broken(:\n"
			broken.reload()
			var result := SuiteResult.new("runner script error control")
			result.checked = 1
			return result
		"runnerfail":
			var result := SuiteResult.new("runner explicit failure control")
			result.checked = 1
			result.fail("deliberate failing fixture")
			return result
		"vmine":
			return preload("res://tests/suites/village_adit_suite.gd").run()
		"varchetypecontracts":
			return VillageArchetypeSuite.run_contracts()
		"dmvbrief":
			return preload("res://tests/suites/site_brief_suite.gd").run()
		"vnativeqa":
			return preload("res://tests/suites/village_native_qa_suite.gd").run()
		"vwater":
			return VillageWaterPlanSuite.run()
		"hjetty":
			return preload("res://tests/suites/house_jetty_suite.gd").run()
		"metriccoords":
			return preload("res://tests/suites/metric_coords_suite.gd").run()
		"churchaperture":
			return preload("res://tests/suites/church_aperture_suite.gd").run()
		"churchload":
			return preload("res://tests/suites/church_load_suite.gd").run()
		"churchchange":
			return preload("res://tests/suites/church_change_suite.gd").run()
		"vis016":
			var result := SuiteResult.new("VIS-016 curved pendentive controls")
			preload("res://tests/suites/church_roof_suite.gd")._pendentive_transition(result)
			return result
		"hmaterials":
			return preload("res://tests/suites/house_material_suite.gd").run()
		"henvelope":
			return preload("res://tests/suites/house_envelope_suite.gd").run()
		"library":
			return LibrarySuite.run()
		"placement":
			return PlacementSuite.run()
		"int021":
			return PlacementSuite.run_orientation()
		"poly":
			return PolySuite.run()
		"props":
			return PropKitSuite.run()
		"church":
			return ChurchSuite.run()
		"churchroof":
			return preload("res://tests/suites/church_roof_suite.gd").run()
		"ctroof":
			return preload("res://tests/suites/castle_temple_roof_suite.gd").run()
		"normals":
			return NormalsSuite.run()
		"massing":
			return MassingSuite.run()
		"blueprint":
			return BlueprintMatchSuite.run()
		"landmark":
			return LandmarkSuite.run()
		"castle":
			return CastleSuite.run()
		"stoneshell":
			return preload("res://tests/suites/stone_shell_suite.gd").run()
		"cwalk":
			return preload("res://tests/suites/castle_walk_suite.gd").run()
		"cplanshell":
			return load("res://tests/suites/castle_plan_shell_suite.gd").run()
		"ctowerplan":
			return load("res://tests/suites/castle_tower_plan_suite.gd").run()
		"ctowerhouse":
			return load("res://tests/suites/castle_tower_house_suite.gd").run()
		"cmotteplan":
			return load("res://tests/suites/castle_motte_plan_suite.gd").run()
		"cforms":
			return load("res://tests/suites/castle_forms_suite.gd").run()
		"crangeplan":
			return load("res://tests/suites/castle_range_plan_suite.gd").run()
		"caperture":
			return load("res://tests/suites/castle_aperture_suite.gd").run()
		"cshop":
			return load("res://tests/suites/castle_shop_suite.gd").run()
		"psconce":
			return load("res://tests/suites/polygon_sconce_suite.gd").run()
		"ckfurnish":
			return load("res://tests/suites/castle_keep_furnishing_suite.gd").run()
		"caccess":
			return preload("res://tests/suites/castle_access_suite.gd").run()
		"cforebuilding":
			return preload("res://tests/suites/castle_forebuilding_suite.gd").run()
		"cbergfried":
			return preload("res://tests/suites/castle_bergfried_suite.gd").run()
		"cas013":
			return preload("res://tests/suites/castle_curved_suite.gd").run()
		"cterrace":
			return preload("res://tests/suites/castle_terrace_suite.gd").run()
		"chimeji":
			return CastleLandmarkSuite.run("himeji")
		"cgateaccess":
			return preload("res://tests/suites/castle_gate_access_suite.gd").run()
		"cgatestairs":
			return preload("res://tests/suites/castle_gate_stair_suite.gd").run()
		"castlechange":
			return preload("res://tests/suites/castle_change_suite.gd").run()
		"ckeepstair":
			return preload("res://tests/suites/castle_keep_stair_suite.gd").run()
		"cnormals":
			return CastleNormalsSuite.run()
		"cmassing":
			return CastleMassingSuite.run()
		"cwater":
			return preload("res://tests/suites/castle_water_suite.gd").run()
		"clandmark":
			return CastleLandmarkSuite.run()
		"voxelqa":
			return BlueprintQASuite.run()
		"cvoxelqa":
			return CastleQASuite.run()
		"dressing":
			return DressingSuite.run()
		"interior":
			return CastleInteriorSuite.run()
		"house":
			return HouseSuite.run()
		"hroof":
			return preload("res://tests/suites/house_roof_suite.gd").run()
		"roofprobe":
			return preload("res://tests/roof_probe.gd").self_test()
		"hexterior":
			return preload("res://tests/suites/house_exterior_suite.gd").run()
		"hcomponent":
			return preload("res://tests/suites/house_component_suite.gd").run()
		"hopening":
			return preload("res://tests/suites/house_roof_opening_suite.gd").run()
		"hsky":
			return preload("res://tests/suites/house_sky_opening_suite.gd").run()
		"hdoor":
			return preload("res://tests/suites/house_raised_door_suite.gd").run()
		"hbounds":
			return preload("res://tests/suites/house_bounds_suite.gd").run()
		"assets":
			return HouseAssetsSuite.run()
		"hassembly":
			return load("res://tests/suites/house_assembly_suite.gd").run()
		"houseqa":
			return HouseQASuite.run()
		"houseqacore":
			return HouseQASuite.run(false, &"core")
		"houseqaplan":
			return HouseQASuite.run(false, &"planning")
		"houseqafurnish":
			return HouseQASuite.run(false, &"furnishing")
		"houseqafurnishfast":
			return HouseQASuite.run(false, &"furnishing", 12, 8)
		"houseqafull":
			return HouseQASuite.run(true)
		"roofquick":
			return preload("res://tests/suites/roof_quick_suite.gd").run()
		"hmultistory":
			return HouseMultistorySuite.run()
		"harchetype":
			return HouseArchetypeSuite.run()
		"court":
			return CourtSuite.run()
		"shop":
			return ShopSuite.run()
		"sarchetype":
			return ShopArchetypeSuite.run()
		"int013":
			return ShopArchetypeSuite.run_int013()
		"int012":
			return ShopArchetypeSuite.run_int012()
		"thievesden100":
			return ShopArchetypeSuite.run_thieves_den_seeds(100)
		"markethall":
			return ShopArchetypeSuite.run_market_hall()
		"barracks100":
			return ShopArchetypeSuite.run_barracks_seeds(100)
		"barracksquick":
			return ShopArchetypeSuite.run_barracks_quick()
		"librarybiz":
			return preload("res://tests/suites/library_business_suite.gd").run()
		"libraryreg":
			return preload("res://tests/suites/library_business_suite.gd").run_repair_regressions()
		"library100":
			return preload("res://tests/suites/library_business_suite.gd").run_seeds(100)
		"prison":
			return preload("res://tests/suites/prison_suite.gd").run()
		"palace":
			return preload("res://tests/suites/palace_suite.gd").run()
		"hotel":
			return HotelSuite.run()
		"hotelroof":
			return preload("res://tests/suites/hotel_roof_smoke_suite.gd").run()
		"hlandmark":
			return HotelLandmarkSuite.run()
		"temple":
			return TempleSuite.run()
		"rite":
			return TempleQASuite.run()
		"tarchetype":
			return TempleArchetypeSuite.run()
		"village":
			return VillageSuite.run()
		"vquick":
			return preload("res://tests/suites/village_quick_suite.gd").run()
		"vsite":
			return VillageSiteSuite.run()
		"vlot":
			return VillageLotSuite.run()
		"vcheck":
			return VillageCheckSuite.run()
		"vforms":
			return VillageFormsSuite.run()
		"vformslayout":
			return VillageFormsSuite.run_layout()
		"vformsfull":
			return VillageFormsSuite.run_full()
		"vformsfull_crossroads", "vformsfull_round", "vformsfull_strand", "vformsfull_planted", "vformsfull_gate":
			return VillageFormsSuite.run_full(StringName(key.trim_prefix("vformsfull_")))
		"venclosure":
			return preload("res://tests/suites/village_enclosure_suite.gd").run()
		"vmill":
			return preload("res://tests/suites/village_mill_suite.gd").run()
		"vmillfull":
			return preload("res://tests/suites/village_mill_suite.gd").run(true)
		"varchetype":
			return VillageArchetypeSuite.run()
		"varchetype_thorpe":
			return VillageArchetypeSuite.run_row(&"thorpe")
		"varchetype_thorpe_0_07":
			return VillageArchetypeSuite.run_case(&"thorpe", 0, 0.7)
		"varchetype_green_village":
			return VillageArchetypeSuite.run_row(&"green_village")
		"varchetype_ford":
			return VillageArchetypeSuite.run_row(&"ford")
		"varchetype_mill_village":
			return VillageArchetypeSuite.run_row(&"mill_village")
		"varchetype_strand":
			return VillageArchetypeSuite.run_row(&"strand")
		"varchetype_pine_hold":
			return VillageArchetypeSuite.run_row(&"pine_hold")
		"varchetype_mine_camp":
			return VillageArchetypeSuite.run_row(&"mine_camp")
		"varchetype_pilgrims_rest":
			return VillageArchetypeSuite.run_row(&"pilgrims_rest")
		"varchetype_lords_village":
			return VillageArchetypeSuite.run_row(&"lords_village")
		"varchetype_market_town":
			return VillageArchetypeSuite.run_row(&"market_town")
		"varchetype_blight":
			return VillageArchetypeSuite.run_row(&"blight")
		"varchetype_cap":
			return VillageArchetypeSuite.run_row(&"cap")
		"world", "warchetype":
			return WorldArchetypeSuite.run()
		"wld001":
			return preload("res://tests/suites/world_courtyard_suite.gd").run()
		"wld002":
			return preload("res://tests/suites/insula_suite.gd").run()
		"wld004":
			return preload("res://tests/suites/qibla_suite.gd").run()
		"wld005":
			return preload("res://tests/suites/hammam_suite.gd").run()
		"wld006":
			return preload("res://tests/suites/world_han_suite.gd").run()
		"wld007":
			return preload("res://tests/suites/world_siheyuan_suite.gd").run()
		"wld009":
			return preload("res://tests/suites/pagoda_suite.gd").run()
		"wld011":
			return preload("res://tests/suites/mountain_suite.gd").run()
		"wld012":
			return preload("res://tests/suites/cruciform_suite.gd").run()
		"wld017":
			return preload("res://tests/suites/world_stupa_suite.gd").run()
		"wld018":
			return preload("res://tests/suites/vihara_suite.gd").run()
		"wld010":
			return preload("res://tests/suites/tulou_suite.gd").run()
		"wld013":
			return preload("res://tests/suites/nagara_suite.gd").run()
		"wld014":
			return preload("res://tests/suites/dravida_suite.gd").run()
		"wld015":
			return preload("res://tests/suites/cut_temple_suite.gd").run()
		"wld016":
			return preload("res://tests/suites/vav_suite.gd").run()
		"wld019":
			return preload("res://tests/suites/vastu_suite.gd").run()
		"wld001_domus":
			return preload("res://tests/suites/world_courtyard_suite.gd").run_kind(&"domus")
		"wld001_riad":
			return preload("res://tests/suites/world_courtyard_suite.gd").run_kind(&"riad")
		"wld001_palazzo":
			return preload("res://tests/suites/world_courtyard_suite.gd").run_kind(&"palazzo")
		"wld001_domus_07", "wld001_domus_10", "wld001_domus_14", "wld001_domus_19", "wld001_riad_07", "wld001_riad_10", "wld001_riad_14", "wld001_riad_19", "wld001_palazzo_07", "wld001_palazzo_10", "wld001_palazzo_14", "wld001_palazzo_19":
			var pieces := key.split("_")
			var kind := StringName(pieces[1])
			var scale := float(pieces[2].left(1) + "." + pieces[2].right(1))
			return preload("res://tests/suites/world_courtyard_suite.gd").run_kind_scale(kind, scale)
		"wld003":
			return WorldArchetypeSuite.run_tower_house()
		"tree":
			return preload("res://tests/suites/tree_suite.gd").run()
		"bridge":
			return preload("res://tests/suites/bridge_suite.gd").run()
	return null


## Where a suite sits in the canonical order. EXTRA lanes have no ORDER slot,
## so they sort after the suite they are a subset of -- close enough, and it
## keeps "cheapest and most fundamental first" true for mixed selections.
static func _suite_rank(key: String) -> int:
	var i := ORDER.find(key)
	if i >= 0:
		return i
	return ORDER.size() + EXTRA.find(key)


func execute(script_error_capture: Object) -> int:
	var args := OS.get_cmdline_user_args()
	var wanted: Array[String] = ORDER.duplicate()
	if args.size() > 0:
		wanted = []
		for a in args:
			var expanded: Array = LANES.get(a, [a])
			for key in expanded:
				if not (key in ORDER or key in EXTRA):
					printerr("unknown suite '%s'; known suites: %s; known lanes: %s"
						% [key, ", ".join(ORDER + EXTRA), ", ".join(LANES.keys())])
					return 2
				# A lane and a bare name can ask for the same suite. Run it once,
				# in the ORDER the runner is built around rather than in the
				# order they happened to be typed.
				if not wanted.has(key):
					wanted.append(key)
		wanted.sort_custom(func(a2: String, b2: String) -> bool:
			return _suite_rank(a2) < _suite_rank(b2))

	var results: Array[SuiteResult] = []
	var failed_suites := 0
	for key in wanted:
		print("Running %s..." % key)
		var started := Time.get_ticks_msec()
		var res: SuiteResult = _run_one(key)
		res.note("elapsed %.2fs" % ((Time.get_ticks_msec() - started) / 1000.0))
		results.append(res)
		if not res.ok():
			failed_suites += 1
		print("--- %s ---" % res.suite_name)
		for n in res.notes:
			print("    " + n)
		for w in res.warnings:
			print("  WARN " + w)
		for f in res.failures:
			print("  FAIL " + f)
		print("")

	var script_errors: Array[String] = script_error_capture.script_errors()
	if not script_errors.is_empty():
		failed_suites += 1
		print("--- engine script errors ---")
		for message in script_errors.slice(0, 5):
			print("  FAIL SCRIPT " + message)
		if script_errors.size() > 5:
			print("  ... %d more script errors" % (script_errors.size() - 5))
		print("")

	print("=".repeat(60))
	var total_checked := 0
	var total_fail := 0
	var total_warn := 0
	for res in results:
		print("  " + res.summary())
		total_checked += res.checked
		total_fail += res.failures.size()
		total_warn += res.warnings.size()
	total_fail += script_errors.size()
	print("=".repeat(60))
	print("%s -- %d suites, %d checks, %d failures, %d warnings" % [
		"ALL PASS" if failed_suites == 0 else "%d SUITE(S) FAILED" % failed_suites,
		results.size(), total_checked, total_fail, total_warn])
	return 1 if failed_suites > 0 else 0

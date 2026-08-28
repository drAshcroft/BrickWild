extends SceneTree
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
##  13 house      - the house spec/plan/build contract
##  14 assets     - the prop catalogue still describes the props
##  15 houseqa    - plan, furnishing and circulation of every house
##  16 harchetype - the dwellings this generator must be able to furnish
##  17 temple     - the temple spec/build contract and its surfaces
##  18 rite       - would a rite work in it: axis, sightline, procession, fire
##  19 tarchetype - the temples a fantasy author would ask for
const ORDER: Array[String] = ["library", "church", "normals", "massing", "blueprint", "landmark",
	"castle", "cnormals", "cmassing", "clandmark", "voxelqa", "cvoxelqa",
	"house", "assets", "houseqa", "harchetype",
	"temple", "rite", "tarchetype"]


static func _run_one(key: String) -> SuiteResult:
	match key:
		"library":
			return LibrarySuite.run()
		"church":
			return ChurchSuite.run()
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
		"cnormals":
			return CastleNormalsSuite.run()
		"cmassing":
			return CastleMassingSuite.run()
		"clandmark":
			return CastleLandmarkSuite.run()
		"voxelqa":
			return BlueprintQASuite.run()
		"cvoxelqa":
			return CastleQASuite.run()
		"house":
			return HouseSuite.run()
		"assets":
			return HouseAssetsSuite.run()
		"houseqa":
			return HouseQASuite.run()
		"harchetype":
			return HouseArchetypeSuite.run()
		"temple":
			return TempleSuite.run()
		"rite":
			return TempleQASuite.run()
		"tarchetype":
			return TempleArchetypeSuite.run()
	return null


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var wanted: Array[String] = ORDER.duplicate()
	if args.size() > 0:
		wanted = []
		for a in args:
			if a in ORDER:
				wanted.append(a)
			else:
				printerr("unknown suite '%s'; known: %s" % [a, ", ".join(ORDER)])
				quit(2)
				return

	var results: Array[SuiteResult] = []
	var failed_suites := 0
	for key in wanted:
		var res: SuiteResult = _run_one(key)
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

	print("=".repeat(60))
	var total_checked := 0
	var total_fail := 0
	var total_warn := 0
	for res in results:
		print("  " + res.summary())
		total_checked += res.checked
		total_fail += res.failures.size()
		total_warn += res.warnings.size()
	print("=".repeat(60))
	print("%s -- %d suites, %d checks, %d failures, %d warnings" % [
		"ALL PASS" if failed_suites == 0 else "%d SUITE(S) FAILED" % failed_suites,
		results.size(), total_checked, total_fail, total_warn])
	quit(1 if failed_suites > 0 else 0)

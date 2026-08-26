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
##   1 church     - the spec/build contract itself
##   2 normals    - the surfaces face the way they are meant to
##   3 massing    - structural correctness of what that contract produced
##   4 blueprint  - the drawing agrees with the model
##   5 landmark   - the famous churches this generator must be able to build
##   6 castle     - the castle spec/build contract, tier by tier
##   7 cnormals   - the castle's surfaces and openings
##   8 cmassing   - structural correctness of what the castle contract produced
##   9 clandmark  - the famous fortifications this generator must be able to build
##  10 voxelqa    - exhaustive rasterized checks of the churches (slow)
##  11 cvoxelqa   - the same, for the castles (slow)
##  12 house      - the house spec/plan/build contract
##  13 assets     - the prop catalogue still describes the props
##  14 houseqa    - plan, furnishing and circulation of every house
##  15 harchetype - the dwellings this generator must be able to furnish
const ORDER: Array[String] = ["church", "normals", "massing", "blueprint", "landmark",
	"castle", "cnormals", "cmassing", "clandmark", "voxelqa", "cvoxelqa",
	"house", "assets", "houseqa", "harchetype"]


static func _run_one(key: String) -> SuiteResult:
	match key:
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

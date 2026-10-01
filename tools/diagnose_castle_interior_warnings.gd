extends SceneTree
## Inspect focused CastleQA interior warning fixtures without running the
## full CastleQA voxel sweep. Pass CastleSweep keys as style/tier/index.
## Example: -- norman/castle/0 edwardian/castle/0

const DEFAULT_FIXTURES := [
	"norman/castle/0",
	"norman/castle/1",
	"norman/fortress/0",
	"norman/fortress/1",
	"edwardian/castle/0",
	"edwardian/castle/2",
	"edwardian/fortress/0",
	"french_chateau/castle/1",
	"french_chateau/fortress/1",
]


func _initialize() -> void:
	var selectors: PackedStringArray = OS.get_cmdline_user_args()
	if selectors.is_empty():
		selectors = PackedStringArray(DEFAULT_FIXTURES)
	for selector in selectors:
		var pieces := selector.split("/")
		if pieces.size() != 3 or not pieces[2].is_valid_int():
			push_error("Expected style/tier/index selector, got: " + selector)
			quit(2)
			return
		_inspect_fixture(selector, pieces[0], pieces[1], int(pieces[2]))
	quit()


func _inspect_fixture(selector: String, style: String, tier: String, index: int) -> void:
	var spec: CastleSpec = CastleSweep.spec_at(StringName(style), StringName(tier), index)
	var builder := CastleBuilder.new()
	builder.build(spec)
	for row in builder.interiors:
		var plan: HousePlan = row.plan
		var qa := HouseQA.new().check(plan, null)
		var nav := HouseNavCheck.new()
		var nav_report: Dictionary = nav.check(plan)
		var rooms: Array[Dictionary] = []
		for room in plan.rooms:
			var rect: Rect2 = room.rect
			rooms.append({
				"kind": String(room.kind),
				"storey": int(room.get("storey", 0)),
				"rect": _rect(rect),
				"aspect": snappedf(maxf(rect.size.x, rect.size.y) / maxf(0.001, minf(rect.size.x, rect.size.y)), 0.01),
			})
		var furniture: Array[Dictionary] = []
		for item in plan.furniture:
			var rect: Rect2 = item.get("rect", Rect2())
			furniture.append({
				"key": String(item.get("key", "")),
				"category": PropCatalog.category(String(item.get("key", ""))),
				"room": int(item.get("room", -1)),
				"rect": _rect(rect),
				"pos": str(item.get("pos", Vector3.ZERO)),
				"rot": snappedf(float(item.get("rot", 0.0)), 0.001),
				"wall": int(item.get("wall", -1)),
				"row": String(item.get("row", "")),
				"role": String(item.get("role", "")),
				"free_standing": bool(item.get("free_standing", false)),
			})
		var record := {
			"fixture": selector,
			"seed": spec.seed,
			"building": String(row.get("id", "")),
			"rooms": rooms,
			"focus": str(plan.focus),
			"dais": str(plan.dais),
			"zones": str(plan.zones),
			"furniture": furniture,
			"compromises": str(plan.compromises),
			"warnings": qa.warnings,
			"failures": qa.failures,
			"nav_warnings": nav_report.get("warnings", []),
			"nav_failures": nav_report.get("failures", []),
			"walk_map_storey_0": nav.ascii_map(0),
		}
		print(JSON.stringify(record))


func _rect(rect: Rect2) -> Array[float]:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

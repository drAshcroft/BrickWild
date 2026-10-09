extends SceneTree
## Mechanical regression for the actual sacred-render request selectors.
## Uses the frozen 234-row request matrix but creates no viewport or images.

class NonProcessingSacredRenderer:
	extends "res://tools/render_sacred_acceptance.gd"
	func _init() -> void:
		pass


const EXPECTED_8102 := ["church/nordic_stave/small/8102"]
const EXPECTED_ROMANESQUE_SUBSET := [
	"church/romanesque/small/1", "church/romanesque/small/21325"
]
const ORIGINAL_VIEWS := ["exterior", "axis", "cutaway"]
var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var baseline := NonProcessingSacredRenderer.new()
	_expect(baseline._validate_frozen_matrix(), "frozen matrix/batch contract failed")
	baseline._size_filter = "all"
	var all_cases: Array[Dictionary] = baseline._all_cases()
	_expect(all_cases.size() == 234, "frozen matrix must retain 234 requests")
	var all_selected: Array[Dictionary] = baseline._selected_cases()
	_expect(all_selected.size() == 234,
		"actual selector must retain every request when all sizes are selected")
	_expect(baseline._selected_views() == ORIGINAL_VIEWS,
		"default --view=all no longer selects the original three views")
	_expect(baseline._planned_image_count() == 702,
		"actual all-size selector must plan the original 702 images")
	baseline.free()

	var normalized := _parse_selection(["--family=church", "--size=small",
		"--seed=8102", "--style=nordic_stave", "--view=axis"])
	_expect(_ids(normalized) == EXPECTED_8102,
		"--seed=8102 must select exactly the frozen Nordic small request")

	var subset_renderer := NonProcessingSacredRenderer.new()
	_expect(subset_renderer._parse_args(PackedStringArray(["--family=church",
		"--size=small", "--seed=1,21325", "--style=romanesque", "--view=all"])),
		"romanesque seed-subset selector arguments rejected")
	_expect(_ids(subset_renderer._selected_cases()) == EXPECTED_ROMANESQUE_SUBSET,
		"comma-separated seeds 1,21325 selected a wrong request set")
	_expect(subset_renderer._selected_views() == ORIGINAL_VIEWS,
		"explicit --view=all must remain the original three views")
	subset_renderer.free()

	var vault_renderer := NonProcessingSacredRenderer.new()
	_expect(vault_renderer._parse_args(PackedStringArray(["--family=church",
		"--size=small", "--seed=8102", "--style=nordic_stave", "--view=vault"])),
		"explicit Church --view=vault selector arguments rejected")
	_expect(_ids(vault_renderer._selected_cases()) == EXPECTED_8102,
		"explicit vault selector changed its exact request")
	_expect(vault_renderer._selected_views() == ["vault"],
		"explicit --view=vault must select one supplemental view only")
	vault_renderer.free()

	print("SACRED_SELECTOR_CONTRACT failed=", _failed)
	quit(1 if _failed else 0)


func _parse_selection(args: Array[String]) -> Array[Dictionary]:
	var renderer := NonProcessingSacredRenderer.new()
	if not renderer._parse_args(PackedStringArray(args)):
		_fail("seed 8102 selector arguments rejected")
		renderer.free()
		return []
	var result: Array[Dictionary] = renderer._selected_cases()
	renderer.free()
	return result


func _ids(cases: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for row in cases:
		result.append(String(row.get("id", "")))
	return result


func _expect(ok: bool, message: String) -> void:
	if not ok:
		_fail(message)


func _fail(message: String) -> void:
	_failed = true
	printerr("SACRED_SELECTOR_FAIL ", message)

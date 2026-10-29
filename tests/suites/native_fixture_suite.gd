extends RefCounted
## Native fixtures restored by LIVE-FIXTURE-TRIAGE (docs/LIVE_TASKS_HISTORY.md).
##
## Each is a stand-alone `extends SceneTree` script that ends in quit(code).
## This suite runs every script of a group in its own Godot process and passes
## when the exit code is 0, so a fixture cannot go back to being an orphan:
## it is a named suite (`nfgeom` ...) inside a lane.
##
## A parse error in a fixture makes its process hang rather than exit, as with
## any headless script; read the top of the log for "Parse Error".

const GROUPS: Dictionary = {
	# seconds: the closed-edge floor and mesh primitives
	"nfgeom": ["walk_floor_edge_test", "mesh_support_closed_edge_test",
		"meshkit_open_edge_mapping_test"],
	# ground entry is 4 s; the Pylon and Rotunda architecture fixtures are 90-130 s
	"nftempleshort": ["temple_ground_entry_contract_test"],
	"nftemple": ["pylon_native_architecture_test", "rotunda_native_architecture_test"],
	# the selector is a 16 s tool regression; the arcade body contract is ~5 min
	"nfchurchshort": ["sacred_render_selector_test"],
	"nfchurch": ["church_arcade_contract_test"],
	# house fixtures that need no generator search, or a single seed
	"nfhouse": ["domestic_groups_fixture", "upper_flight_approach_test",
		"domestic_hearth_flue_scope_test", "house_clothes_storage_test",
		"house_hearth_mesh_contract_test"],
	# the three that build and assemble several houses
	"nfhouseslow": ["house_personality_camera_test", "domestic_hearth_flue_trace_test",
		"domestic_hearth_tending_test"],
}


static func run(group: String) -> SuiteResult:
	var res := SuiteResult.new("native fixtures " + group)
	var project := ProjectSettings.globalize_path("res://")
	for name: String in GROUPS.get(group, []):
		var output: Array = []
		var started := Time.get_ticks_msec()
		var code := OS.execute(OS.get_executable_path(),
			PackedStringArray(["--headless", "--path", project, "--script",
				"res://tests/%s.gd" % name]), output, true)
		res.checked += 1
		res.note("%s exit=%d %.0fs" % [name, code, (Time.get_ticks_msec() - started) / 1000.0])
		if code != 0:
			var tail: Array[String] = []
			for line in String("".join(output)).split("\n"):
				if line.begins_with("ERROR") or line.begins_with("FAIL") or "failure" in line:
					tail.append(line.strip_edges())
			res.fail("%s exited %d: %s" % [name, code, " | ".join(tail.slice(0, 4))])
	return res

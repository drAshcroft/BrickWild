extends SceneTree
## Full native village acceptance, optionally split into explicit seed ranges.
## Example: --script res://tests/village_forms_full_test.gd -- --form=gate --start=10 --count=10
## All 0..49 seeds must pass for each form before the complete gate is satisfied.

func _initialize() -> void:
	var form: StringName = &""
	var first := 0
	var count := VillageFormsSuite.SEEDS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--form="):
			form = StringName(arg.trim_prefix("--form="))
		elif arg.begins_with("--start="):
			first = int(arg.trim_prefix("--start="))
		elif arg.begins_with("--count="):
			count = int(arg.trim_prefix("--count="))
		else:
			printerr("unknown argument: ", arg)
			quit(2)
			return
	var res := VillageFormsSuite.run_full(form, first, count)
	print("VFORMS RESULT checks=", res.checked, " failures=", res.failures.size())
	for failure in res.failures:
		printerr(failure)
	quit(0 if res.failures.is_empty() else 1)

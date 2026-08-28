extends SceneTree
## Focused one-to-three-storey house contract.
## Run: godot --headless --script res://tests/house_multistory_test.gd


func _init() -> void:
	var res: SuiteResult = HouseMultistorySuite.run()
	for n in res.notes:
		print("    " + n)
	for w in res.warnings:
		print("  WARN " + w)
	for f in res.failures:
		print("  FAIL " + f)
	print(res.summary())
	quit(0 if res.ok() else 1)

extends SceneTree
## Probe: only the yard-door rule of the shoptrade suite.
func _init() -> void:
	var res := SuiteResult.new("yard door")
	ShopTradeSuite._run_yard_door(res)
	print("checked ", res.checked, " failures ", res.failures.size())
	for f in res.failures: print("  ", f)
	quit()

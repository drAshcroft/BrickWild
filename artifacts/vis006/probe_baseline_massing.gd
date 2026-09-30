extends SceneTree
## Bounded baseline probe for failures reported by the full VIS-006 sweep.

func _init() -> void:
	for row in [[&"norman", &"fortress", 2],
			[&"crusader", &"fortress", 1]]:
		var spec: CastleSpec = CastleSweep.spec_at(row[0], row[1], row[2])
		var builder := CastleBuilder.new()
		builder.build(spec)
		var report: Dictionary = CastleMassingCheck.new().check(spec, builder)
		print("BASELINE %s %s seed=%d" % [row[0], row[1], spec.seed])
		for failure in report.failures:
			print("  FAIL ", failure)
	var tower := CastleMassingSuite._tower_house_spec(8.0, 8.0, 45.0, 8803)
	var tower_builder := CastleBuilder.new()
	tower_builder.build(tower)
	print("BASELINE tower house seed=8803")
	for failure in TowerCheck.new().check(tower, tower_builder).failures:
		print("  FAIL ", failure)
	for failure in CastleMassingCheck.new().check(tower, tower_builder).failures:
		print("  FAIL ", failure)
	quit()

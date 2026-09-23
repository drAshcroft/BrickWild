extends SceneTree
## Porch entrances must not collapse to the empty gatehouse at the origin.

func _init() -> void:
	var result := SuiteResult.new("castle porch placement")
	for tier in [&"house", &"manor"]:
		for closed in [false, true]:
			var spec := CastleSpec.new()
			spec.width = 30.0
			spec.length = 40.0
			spec.height = 8.0
			spec.tier = tier
			spec.courtyard = closed
			var made := GeneratedBuilding.new()
			made.spec = spec
			var door := BuildingFamilyAdapter.of(&"castle").door(made)
			var porch := CastleGeometry.porch_aabb(spec)
			result.checked += 1
			if door.z != porch.position.z or door.x != porch.get_center().x or door.y <= 0:
				result.fail("%s closed=%s entrance misses porch mouth" % [tier, closed])
	for failure in result.failures:
		print("FAIL: " + failure)
	print(result.summary())
	quit(0 if result.ok() else 1)

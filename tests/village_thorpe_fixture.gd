extends SceneTree
## The first failing Thorpe acceptance cell, kept bounded for routine work.
## The complete three-seed/three-scale row remains varchetype_thorpe.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var result := VillageArchetypeSuite.run_case(&"thorpe", 0, 1.4)
	for failure in result.failures:
		print("FAIL ", failure)
	for warning in result.warnings:
		print("WARN ", warning)
	print("THORPE ", result.checked, " checks, ", result.failures.size(),
		" failures, ", result.warnings.size(), " warnings")
	quit(0 if result.failures.is_empty() else 1)

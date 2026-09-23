extends SceneTree
## Run through profile_castle_interiors.py: its isolated snapshot supplies Clock.
var Clock: GDScript
var report := {"complete": false, "quiet_requested": true, "qa_enabled": true, "cases": {}}
var failed := false

func _init() -> void:
	if not FileAccess.file_exists("res://tools/castle_phase_clock.gd"):
		printerr("Prepare an isolated snapshot with tools/profile_castle_interiors.py first.")
		quit(2)
		return
	Clock = load("res://tools/castle_phase_clock.gd")
	var repetitions := 3
	var cases: Array[String] = []
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		match args[i]:
			"--repeat":
				i += 1
				repetitions = maxi(int(args[i]), 1)
			"--case":
				i += 1
				cases.append(args[i])
			"--concurrent": report.quiet_requested = false
			"--no-qa": report.qa_enabled = false
		i += 1
	if cases.is_empty():
		cases.assign(["norman:manor:0", "norman:castle:0", "norman:fortress:0",
			"edwardian:castle:0", "edwardian:fortress:0", "crusader:fortress:0"])
	for label in cases:
		var parts := label.split(":")
		if parts.size() != 3 or not CastleSweep.SIZES.has(StringName(parts[1])) \
				or not CastleSpec.STYLES.has(StringName(parts[0])) \
				or not parts[2].is_valid_int() or int(parts[2]) < 0 or int(parts[2]) >= CastleSweep.COUNT:
			printerr("Invalid case: ", label)
			quit(2)
			return
		var samples: Array[Dictionary] = []
		var fingerprint := ""
		for sample in range(repetitions):
			print("PROFILE START ", label, " sample=", sample + 1)
			Clock.clear()
			var started := Time.get_ticks_usec()
			var spec := CastleSweep.spec_at(StringName(parts[0]), StringName(parts[1]), int(parts[2]))
			var builder := CastleBuilder.new()
			var mesh := builder.build(spec)
			var generated_us := Time.get_ticks_usec() - started
			var qa := {"failures": [], "warnings": []}
			var qa_us := 0
			if report.qa_enabled:
				started = Time.get_ticks_usec()
				qa = CastleQA.new().check(spec, mesh, builder)
				qa_us = Time.get_ticks_usec() - started
			var state := _snapshot(spec, mesh, builder)
			var bytes := var_to_bytes(state)
			var digest := HashingContext.new()
			digest.start(HashingContext.HASH_SHA256)
			digest.update(bytes)
			var actual := digest.finish().hex_encode()
			if sample == 0:
				fingerprint = actual
				FileAccess.open("res://results/" + label.replace(":", "_") + ".bin", FileAccess.WRITE).store_buffer(bytes)
			elif actual != fingerprint:
				failed = true
				printerr("NONDETERMINISTIC ", label, " sample=", sample + 1)
			if not qa.failures.is_empty(): failed = true
			var row := {"generate_ms": generated_us / 1000.0, "qa_ms": qa_us / 1000.0,
				"phases": Clock.rows.duplicate(true), "fingerprint": actual,
				"failures": qa.failures, "warnings": qa.warnings,
				"interiors": builder.interiors.size(), "keep_shape": spec.keep_shape}
			samples.append(row)
			report.cases[label] = {"samples": samples, "fingerprint": fingerprint,
				"median_ms": _medians(samples)}
			_save()
			print("PROFILE FINISH ", label, " ", JSON.stringify(row))
	report.complete = true
	report.ok = not failed
	_save()
	print("PROFILE COMPLETE ok=", not failed)
	quit(1 if failed else 0)

func _snapshot(spec: CastleSpec, mesh: ArrayMesh, builder: CastleBuilder) -> Dictionary:
	var interiors: Array = []
	for row in builder.interiors:
		var plan: HousePlan = row.plan
		interiors.append({"id": row.id, "plan": _state(plan),
			"rng_seed": plan.spec.rng.seed, "rng_state": plan.spec.rng.state,
			"transform": row.transform, "bounds": row.bounds})
	var surfaces: Array = []
	for i in range(mesh.get_surface_count()): surfaces.append(mesh.surface_get_arrays(i))
	return {"spec": _state(spec), "rng_seed": spec.rng.seed,
		"rng_state": spec.rng.state, "interiors": interiors, "surfaces": surfaces,
		"part_log": builder.part_log, "mass_log": builder.mass_log,
		"component_log": builder.component_log, "prop_log": builder.prop_log,
		"interior_errors": builder.interior_errors}

## Profile snapshots include every script field, including derived subclasses
## and private data, plus RNG state. They are local evidence, not a wire format.
func _state(value: Variant) -> Variant:
	if value is RandomNumberGenerator:
		return {"rng_seed": value.seed, "rng_state": value.state}
	if value is Object:
		var out := {"class": value.get_script().resource_path}
		for property in value.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				out[property.name] = _state(value.get(property.name))
		return out
	if value is Dictionary:
		var out := {}
		for key in value: out[key] = _state(value[key])
		return out
	if value is Array:
		var out: Array = []
		for item in value: out.append(_state(item))
		return out
	return value

func _medians(samples: Array[Dictionary]) -> Dictionary:
	var values := {"generate": [], "qa": []}
	for sample in samples:
		values.generate.append(sample.generate_ms)
		values.qa.append(sample.qa_ms)
		for label in sample.phases:
			for mode in ["inclusive_us", "self_us"]:
				var key: String = label + "." + mode.replace("_us", "")
				if not values.has(key): values[key] = []
				values[key].append(float(sample.phases[label][mode]) / 1000.0)
	var medians := {}
	for key in values:
		var numbers: Array = values[key]
		numbers.sort()
		var middle := numbers.size() / 2
		medians[key] = numbers[middle] if numbers.size() % 2 else (numbers[middle - 1] + numbers[middle]) * 0.5
	return medians

func _save() -> void:
	FileAccess.open("res://results/profile.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))

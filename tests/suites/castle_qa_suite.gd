class_name CastleQASuite
extends RefCounted
## 10. Full voxel QA for castles: rasterizes each mesh and runs the checks that
##     measure the geometry rather than the mass log. Slow, so it runs last
##     alongside the church's own voxel sweep.

static func run() -> SuiteResult:
	var res := SuiteResult.new("castle voxel QA")
	var started_msec := Time.get_ticks_msec()
	var styles := CastleSweep.styles()
	var tiers := CastleSweep.tiers()
	const FANTASY_FIXTURE_COUNT := 3
	var total_fixtures := styles.size() * tiers.size() * CastleSweep.COUNT + FANTASY_FIXTURE_COUNT
	var completed := 0
	for style in styles:
		for tier in tiers:
			for i in range(CastleSweep.COUNT):
				var spec: CastleSpec = CastleSweep.spec_at(style, tier, i)
				var builder := CastleBuilder.new()
				var mesh: ArrayMesh = builder.build(spec)
				var report: Dictionary = CastleQA.new().check(spec, mesh, builder)
				res.checked += 1
				var who := "%s %s %s seed=%d" % [String(style), String(tier),
					spec.variant_name, spec.seed]
				if not report["ok"]:
					for f in report["failures"]:
						res.fail("%s: %s" % [who, str(f)])
				for w in report["warnings"]:
					res.warn("%s: %s" % [who, str(w)])
				completed += 1
				if completed % 10 == 0:
					_log_progress(completed, total_fixtures, started_msec)
	completed = _fantasy_fixtures(res, completed, total_fixtures, started_msec)
	_log_progress(completed, total_fixtures, started_msec)
	return res


## Wizard's required tall proportion is outside the ordinary sweep; keep all
## three CAS-012 silhouettes together as a fast, named voxel regression.
static func _fantasy_fixtures(res: SuiteResult, completed: int, total: int, started_msec: int) -> int:
	for row in [
			{"style": &"wizard", "w": 9.0, "l": 9.0, "h": 42.0, "tier": &"house", "seed": 12012},
			{"style": &"dark", "w": 40.0, "l": 55.0, "h": 14.0, "tier": &"castle", "seed": 9249},
			{"style": &"sky", "w": 80.0, "l": 110.0, "h": 14.0, "tier": &"castle", "seed": 12012},
	]:
		_log_progress(completed, total, started_msec, "before fantasy " + String(row.style))
		var spec := CastleSpec.new()
		spec.style = row.style
		spec.width = row.w
		spec.length = row.l
		spec.height = row.h
		spec.tier_override = row.tier
		CastleGenerator.generate(spec, row.seed)
		var builder := CastleBuilder.new()
		var mesh := builder.build(spec)
		var report: Dictionary = CastleQA.new().check(spec, mesh, builder)
		res.checked += 1
		for f in report.failures:
			res.fail("fantasy %s: %s" % [String(row.style), str(f)])
		for w in report.warnings:
			res.warn("fantasy %s: %s" % [String(row.style), str(w)])
		completed += 1
	return completed


static func _log_progress(completed: int, total: int, started_msec: int, stage: String = "") -> void:
	var elapsed_seconds := float(Time.get_ticks_msec() - started_msec) / 1000.0
	var message := "[cvoxelqa] %d/%d fixtures complete; elapsed %ss" % [completed, total, String.num(elapsed_seconds, 1)]
	if not stage.is_empty():
		message += " (%s)" % stage
	print(message)

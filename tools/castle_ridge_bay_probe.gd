extends SceneTree
## What bay count does each ridge range's ground floor and its upper storeys
## want, and how big would an upper room be? No building, no furnishing: the
## plan's own geometry only.
##
##   godot --headless --path . --script res://tools/castle_ridge_bay_probe.gd
func _init() -> void:
	var specs: Array = []
	for row in CastleSweep.each():
		var spec := CastleSweep.spec_at(row.style, row.tier, row.index)
		if CastleGeometry.is_ridge(spec):
			specs.append(["%s/%s/%d" % [row.style, row.tier, row.index], spec])
	for scale in CastleLandmarkSuite.SCALES:
		var spec := CastleSpec.new()
		spec.style = &"bavarian"
		spec.tier_override = &"castle"
		spec.width = 150.0 * scale
		spec.length = 40.0 * scale
		spec.height = 25.0 * scale
		CastleGenerator.generate(spec,
			CastleLandmarkSuite._seed_for("neuschwanstein", scale))
		CastleLandmarkSuite._force_features("neuschwanstein", spec)
		specs.append(["neuschwanstein x%.2f" % scale, spec])
	for entry in specs:
		var spec: CastleSpec = entry[1]
		var levels := CastleGeometry.ridge_storeys(spec)
		for seg in CastleGeometry.ridge_ranges(spec):
			var run: float = float(seg["length"])
			var across: float = float(seg["width"])
			if run < CastleInteriorPlans.MIN_RANGE_RUN \
					or across < CastleInteriorPlans.MIN_RANGE_SIDE:
				continue
			var box := AABB(Vector3(-run * 0.5, 0.0, -across * 0.5),
				Vector3(run, spec.height, across))
			var hs: HouseSpec = CastleInteriorPlans._hall_spec(spec, box)
			var fr: Rect2 = HouseGeometry.interior_rect(hs)
			var kind: StringName = &"great_hall" if String(seg["name"]) == "hall" \
				else &"lords_chamber"
			var bays: int = CastleInteriorPlans._range_bays(fr, kind)
			var upper: int = bays
			if kind == &"great_hall" and levels > 1:
				upper = CastleInteriorPlans._range_bays(fr, &"parlour")
			if bays == upper:
				continue
			print("%-28s %-8s %5.1f x %5.1f levels=%d bays=%d upper=%d upper_room=%.0fm2" % [
				entry[0], String(seg["name"]), fr.size.x, fr.size.y, levels, bays, upper,
				fr.size.x / float(upper) * fr.size.y])
	quit()

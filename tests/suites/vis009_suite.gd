extends RefCounted
## Focused roof/facade hierarchy contract for the Bavarian ridge and French chateau.

static func run() -> SuiteResult:
	var result := SuiteResult.new("VIS-009 ridge and chateau facade hierarchy")
	for key in ["neuschwanstein", "chambord"]:
		var spec := _landmark_spec(key)
		var builder := CastleBuilder.new()
		builder.build(spec)
		_check_dormers(result, key, builder)
		_check_opening_ownership(result, key, builder)
	return result


static func _landmark_spec(key: String) -> CastleSpec:
	var row: Dictionary = {}
	for entry in CastleLandmarkSuite.LANDMARKS:
		if String(entry.key) == key:
			row = entry
			break
	assert(not row.is_empty(), "unknown VIS-009 fixture: " + key)
	var spec := CastleSpec.new()
	spec.style = row.style
	spec.tier_override = row.tier
	spec.width = float(row.width)
	spec.length = float(row.length)
	spec.height = float(row.height)
	CastleGenerator.generate(spec, CastleLandmarkSuite._seed_for(key, 1.0))
	CastleLandmarkSuite._force_features(key, spec)
	return spec


static func _check_dormers(result: SuiteResult, key: String, builder: CastleBuilder) -> void:
	var gables := 0
	var roofs := 0
	for row in builder.component_log:
		var role := String(row.get("role", ""))
		var host_name := String(row.get("host", ""))
		if role == "dormer_gable":
			gables += 1
			if not host_name.begins_with("dormer:"):
				result.fail("%s: dormer gable has no range-owned host: %s" % [key, host_name])
		elif role == "dormer_roof":
			roofs += 1
	result.checked += 1
	if gables < 4 or roofs != gables * 2:
		result.fail("%s: expected complete range-owned gabled dormers, got gables=%d roofs=%d" % [key, gables, roofs])
	# Deliberate omission control: the production rule cannot pass if a gable
	# loses its component record, even when its two roof cheeks remain logged.
	var saved: Dictionary = {}
	for i in range(builder.component_log.size()):
		if String(builder.component_log[i].get("role", "")) == "dormer_gable":
			saved = builder.component_log[i]
			builder.component_log.remove_at(i)
			break
	result.checked += 1
	if saved.is_empty() or _has_dormer_gable(builder, String(saved.get("host", ""))):
		result.fail("%s: missing-gable negative control was not detected" % key)
	if not saved.is_empty():
		builder.component_log.append(saved)


static func _check_opening_ownership(result: SuiteResult, key: String, builder: CastleBuilder) -> void:
	var selected: Dictionary = {}
	for part in builder.part_log:
		if String(part.get("kind", "")) == "window" and String(part.get("component_host", "")).begins_with("dormer:"):
			selected = part
			break
	result.checked += 1
	if selected.is_empty() or not _opening_belongs_to_dormer(builder, selected):
		result.fail("%s: gabled dormer window is not supported by its logged gable" % key)
		return
	var cut_row: Dictionary = {}
	for row in builder._roof_openings:
		if String(row.get("owner", "")) == String(selected.get("component_host", "")):
			cut_row = row
			break
	result.checked += 1
	if cut_row.is_empty() or _roof_cut_is_missing(builder, cut_row):
		result.fail("%s: dormer host roof does not have the logged opening cut" % key)
		return
	var cut_index := builder._roof_openings.find(cut_row)
	builder._roof_openings.remove_at(cut_index)
	result.checked += 1
	if not _roof_cut_is_missing(builder, cut_row):
		result.fail("%s: omitted-roof-cut negative control was not detected" % key)
	builder._roof_openings.append(cut_row)
	var original: Vector3 = selected.pos
	selected.pos = original + selected.facing * 10.0
	result.checked += 1
	if _opening_belongs_to_dormer(builder, selected):
		result.fail("%s: moved-off-face dormer opening escaped negative control" % key)
	selected.pos = original


static func _has_dormer_gable(builder: CastleBuilder, host_name: String) -> bool:
	for row in builder.component_log:
		if String(row.get("role", "")) == "dormer_gable" and String(row.get("host", "")) == host_name:
			return true
	return false


static func _opening_belongs_to_dormer(builder: CastleBuilder, part: Dictionary) -> bool:
	var owner := String(part.get("component_host", ""))
	if owner.is_empty() or not part.has("facing"):
		return false
	for row in builder.component_log:
		if String(row.get("role", "")) != "dormer_gable" or String(row.get("host", "")) != owner:
			continue
		var bounds := MassBuilder.component_aabb(row)
		if bounds.grow(0.08).has_point(part.pos):
			return Vector3.UP.dot(part.facing) == 0.0
	return false


static func _roof_cut_is_missing(builder: CastleBuilder, opening: Dictionary) -> bool:
	var face_index := int(opening["face_index"])
	if face_index < 0 or face_index >= builder._roof_faces.size():
		return true
	var probe := Vector2.ZERO
	var polygon: PackedVector2Array = opening["polygon"]
	for point in polygon:
		probe += point
	probe /= float(polygon.size())
	var pieces: Array[PackedVector2Array] = [RoofShape.footprint(builder._roof_faces[face_index])]
	for row in builder._roof_openings:
		if int(row["face_index"]) != face_index:
			continue
		var remaining: Array[PackedVector2Array] = []
		for piece in pieces:
			remaining.append_array(RoofShape.subtract(piece, row["polygon"]))
		pieces = remaining
	for piece in pieces:
		if Poly.contains_point(piece, probe):
			return true
	return false

class_name ColumnGrid
extends RefCounted
## Symmetric rectangular column-grid authoring helper.
##
## Positions are centred on both axes.  Temple-specific grids may carry extra
## semantics (rings, aisles, pits), but they can still use this primitive for
## halls that want a regular, mirror-safe field.

static func grid(rect: Rect2, files: int, rows: int, margin: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if files <= 0 or rows <= 0 or rect.size.x <= margin * 2.0 or rect.size.y <= margin * 2.0:
		return out
	var centre := rect.get_center()
	var usable_size := rect.size - Vector2.ONE * margin * 2.0
	for row in range(rows):
		var z := centre.y + usable_size.y * ((float(row) + 0.5) / float(rows) - 0.5)
		for file in range(files):
			var x := centre.x + usable_size.x * ((float(file) + 0.5) / float(files) - 0.5)
			out.append({"pos": Vector3(x, 0.0, z), "radius": margin,
				"height": 0.0, "ring": row})
	# The centred lattice is mirror-safe only when its dimensions and counts are
	# paired. Rejecting odd/asymmetric requests is preferable to silently
	# promising a symmetry contract the caller cannot satisfy.
	if not _has_mirror(out, centre):
		return []
	return out


static func _has_mirror(columns: Array[Dictionary], centre := Vector2.ZERO, tol := 0.0001) -> bool:
	for column in columns:
		var p: Vector3 = column["pos"]
		var found_x := false
		var found_z := false
		for other in columns:
			var q: Vector3 = other["pos"]
			found_x = found_x or (absf((q.x + p.x) - centre.x * 2.0) <= tol and absf(q.z - p.z) <= tol)
			found_z = found_z or (absf(q.x - p.x) <= tol and absf((q.z + p.z) - centre.y * 2.0) <= tol)
		if not found_x or not found_z:
			return false
	return true

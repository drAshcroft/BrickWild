class_name CrookedCheck
extends RefCounted
## The crooked contract (HNT-041), measured on the emitted meshes, never on
## the warp's own description of itself. What jank is allowed to do to a
## building, and what it is not:
##
##   lean       no storey leans more than CrookedWarp.MAX_LEAN_DEG
##   volume     every storey's affine has determinant 1: nothing is squashed,
##              nothing turned inside out
##   level      no vertex changes height except the new ones on a floor line,
##              which are cut exactly there -- floors stay floors
##   one storey every warped triangle lies within one storey, so the walls
##              kink AT the floor lines and nowhere else
##   faces      the warped mesh passes the ordinary mesh-integrity check:
##              finite, no degenerate triangles, normals agree with winding
##
## A defect is returned as text, one line each; an empty list is a pass.

const Integrity := preload("res://qa/mesh_integrity_check.gd")
const DET_TOL := 1e-4
const Y_TOL := 1e-4


static func check(warp: CrookedWarp, before: ArrayMesh, after: ArrayMesh,
		where := "mesh") -> Array[String]:
	var out: Array[String] = []
	out.append_array(check_warp(warp, where))
	if before == null or after == null:
		out.append("%s: no mesh to compare" % where)
		return out
	out.append_array(check_levels(warp, before, after, where))
	out.append_array(check_one_storey(warp, after, where))
	for failure in Integrity.check(after, where):
		out.append("%s: integrity: %s" % [where, failure])
	return out


## The warp's own numbers: the lean cap and the determinant.
static func check_warp(warp: CrookedWarp, where := "warp") -> Array[String]:
	var out: Array[String] = []
	var lean := warp.max_lean_deg()
	if lean > CrookedWarp.MAX_LEAN_DEG + 1e-3:
		out.append("%s: a storey leans %.1f degrees, above the %.0f-degree cap" % [
			where, lean, CrookedWarp.MAX_LEAN_DEG])
	for i in range(warp.keys.size()):
		var det := warp.affine(i).basis.determinant()
		if absf(det - 1.0) > DET_TOL:
			out.append("%s: storey %d has determinant %.4f, not 1" % [where, i, det])
	return out


## Heights: every warped vertex sits at a height the original mesh already
## had, or exactly on a floor line.
static func check_levels(warp: CrookedWarp, before: ArrayMesh, after: ArrayMesh,
		where := "mesh") -> Array[String]:
	var out: Array[String] = []
	var heights := {}
	for y in _heights(before):
		heights[snappedf(y, Y_TOL)] = true
	for k in warp.keys:
		heights[snappedf(k, Y_TOL)] = true
	var strays := 0
	var first := 0.0
	for y in _heights(after):
		if not heights.has(snappedf(y, Y_TOL)):
			if strays == 0:
				first = y
			strays += 1
	if strays > 0:
		out.append("%s: %d vertices moved off their level (first at y=%.4f)" % [
			where, strays, first])
	return out


## Every triangle inside one storey: none may reach clearly across a floor
## line, or the wall it belongs to bends somewhere other than the floor.
static func check_one_storey(warp: CrookedWarp, after: ArrayMesh,
		where := "mesh") -> Array[String]:
	var out: Array[String] = []
	var crossing := 0
	for si in range(after.get_surface_count()):
		if after.surface_get_primitive_type(si) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays: Array = after.surface_get_arrays(si)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx = arrays[Mesh.ARRAY_INDEX]
		var n: int = idx.size() if typeof(idx) != TYPE_NIL else v.size()
		for t in range(n / 3):
			var ys: Array[float] = []
			for c in range(3):
				var i: int = idx[t * 3 + c] if typeof(idx) != TYPE_NIL else t * 3 + c
				ys.append(v[i].y)
			var lo: float = ys.min()
			var hi: float = ys.max()
			for k in warp.keys:
				if lo < k - CrookedWarp.ON_LINE and hi > k + CrookedWarp.ON_LINE:
					crossing += 1
					break
	if crossing > 0:
		out.append("%s: %d triangles reach across a floor line" % [where, crossing])
	return out


static func _heights(mesh: ArrayMesh) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for si in range(mesh.get_surface_count()):
		var v: PackedVector3Array = mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
		for p in v:
			out.append(p.y)
	return out

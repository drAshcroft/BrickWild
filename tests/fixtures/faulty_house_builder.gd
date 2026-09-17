extends HouseBuilder
## A house that LIES about its own exterior, so the component check has
## something real to catch.
##
## The point of a component log is that it is written at emission. Prove it:
## this builder logs a component exactly as HouseBuilder would -- the geometry
## the plan asked for -- and then emits something else, or nothing at all. The
## spec, the plan and every other part of the house are untouched, so a check
## that re-derives the roof from the spec agrees with the log and sees nothing
## wrong. Only a check that measures the MESH notices.

enum Fault { NONE, REMOVE, MOVE }

## Which fault to inject, into which role, and into which emission of it.
var fault: Fault = Fault.NONE
var fault_role := ""
var fault_index := 0
## How far a MOVE shifts the piece: far enough to be a defect, small enough
## that a threshold set for real tolerances has to be doing the work.
var move_by := Vector3(0.45, 0.30, 0.0)

var _seen := 0


func build(p_plan: HousePlan, with_roof := true) -> ArrayMesh:
	_seen = 0
	return super.build(p_plan, with_roof)


func component_box(role: String, size: Vector3, xform: Transform3D, surf: int) -> Dictionary:
	if role != fault_role or fault == Fault.NONE:
		return super.component_box(role, size, xform, surf)
	var mine := _seen
	_seen += 1
	if mine != fault_index:
		return super.component_box(role, size, xform, surf)
	var row := _log_component(role, "box", surf, {"xf": xform, "size": size})
	if fault == Fault.MOVE:
		_kit.oriented_box(size, xform.translated(move_by), surf)
	return row


func component_slab(role: String, points: PackedVector3Array, depth: float,
		surf: int, vertical := true) -> Dictionary:
	if role != fault_role or fault == Fault.NONE:
		return super.component_slab(role, points, depth, surf, vertical)
	var mine := _seen
	_seen += 1
	if mine != fault_index:
		return super.component_slab(role, points, depth, surf, vertical)
	var row := _log_component(role, "slab", surf,
		{"points": points, "depth": depth, "vertical": vertical})
	if fault == Fault.MOVE:
		var shifted := PackedVector3Array()
		for p in points:
			shifted.append(p + move_by)
		_kit.slab_poly(shifted, depth, surf, vertical)
	return row

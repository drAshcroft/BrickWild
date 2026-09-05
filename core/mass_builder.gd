class_name MassBuilder
extends RefCounted
## What every building generator has in common: the mesh kit it emits into, and
## the two logs the QA harness measures.
##
## The logs are the whole reason this base class exists. Every correctness check
## in qa/ reads geometry the builder ACTUALLY emitted rather than re-deriving it
## from the spec -- re-deriving is how the old parts_join check became a
## tautology. Church and castle therefore have to log the same way, or the
## checks cannot be shared between them.

## QA log: one entry per primitive placed during build().
## {kind:String, pos:Vector3, size:Vector3, rot_y:float, facing:Vector3, tag:String}
var part_log: Array = []
## QA log: one entry per STRUCTURAL MASS -- the load-bearing volumes a person
## would name when describing the building. Unlike part_log this records the
## true world-space AABB of the volume as emitted.
## {name:String, aabb:AABB}
var mass_log: Array[Dictionary] = []
## Tallest point reached, maintained by the builder as it places parts.
var total_height := 0.0

var _kit: MeshKit
var _tag := ""


## Start a fresh build with `surface_count` surfaces. Clears both logs, so a
## builder instance can be reused without the previous run's masses leaking in.
func begin(surface_count: int) -> void:
	part_log.clear()
	mass_log.clear()
	total_height = 0.0
	_kit = MeshKit.new(surface_count)


func commit() -> ArrayMesh:
	return _kit.commit()


## Tag subsequent parts (e.g. "keep", "curtain", "nave") for diagnostics.
func tag(t: String) -> void:
	_tag = t


func _log_part(kind: String, pos: Vector3, size := Vector3.ZERO, rot_y := 0.0,
		facing := Vector3.ZERO) -> void:
	part_log.append({"kind": kind, "pos": pos, "size": size, "rot_y": rot_y,
		"facing": facing, "tag": _tag})


## Record a structural mass by its true world AABB. `ground` is the level the
## mass stands on when it is not the ground plane (INT-016): a cellar wall
## stands on the pit floor a storey down.
func _log_mass(mass_name: String, aabb: AABB, ground := 0.0) -> void:
	var row := {"name": mass_name, "aabb": aabb.abs()}
	if absf(ground) > 0.0001:
		row["ground"] = ground
	mass_log.append(row)


## Structural box. Logged for QA, then handed to the shared kit.
func box(size: Vector3, pos: Vector3, s: int, rot_y := 0.0, shear := 0.0) -> void:
	_log_part("box", pos, size, rot_y)
	_kit.box(size, pos, s, rot_y, shear)


## True if any logged structural mass's name begins with `prefix`.
func has_mass(prefix: String) -> bool:
	for m in mass_log:
		if (m["name"] as String).begins_with(prefix):
			return true
	return false


## The logged AABB of mass `mass_name`, or a zero AABB when absent.
func mass_aabb(mass_name: String) -> AABB:
	for m in mass_log:
		if m["name"] == mass_name:
			return m["aabb"]
	return AABB()

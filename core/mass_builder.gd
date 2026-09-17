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
## QA log: one entry per PROP the building is dressed with, in the form
## PropCatalog.placement() returns. Empty on a family that emits no dressing.
## Like the other two logs it records what the builder ACTUALLY placed, which
## is what DressingCheck measures and what the assembler instantiates.
var prop_log: Array[Dictionary] = []
## QA log: one entry per STRUCTURAL MASS -- the load-bearing volumes a person
## would name when describing the building. Unlike part_log this records the
## true world-space AABB of the volume as emitted.
## {name:String, aabb:AABB}
var mass_log: Array[Dictionary] = []
## QA log: one entry per ARCHITECTURAL COMPONENT -- the named exterior pieces
## a person points at (a roof face, a dormer cheek, a verge board, a wall
## beam). part_log records that a primitive happened; this records WHICH
## building part it was, whose it is, and the geometry it was emitted with.
##
## Every row is written AT EMISSION from the numbers handed to the mesh kit,
## never re-derived from the spec afterwards -- re-deriving is how a check
## turns into a tautology that agrees with a roof nobody built.
##
## Common keys: {id:String, role:String, form:String, host:String,
##   storey:int, surface:int, tag:String}
##   form == "box"  adds {xf:Transform3D, size:Vector3}
##   form == "slab" adds {points:PackedVector3Array, depth:float,
##                        vertical:bool}
## `id` is "<role>#<n>", n counting that role's emissions in emission order,
## so a deterministic build gives a component the same identity every time.
var component_log: Array[Dictionary] = []

## Tallest point reached, maintained by the builder as it places parts.
var total_height := 0.0

var _kit: MeshKit
var _tag := ""
var _comp_host := ""
var _comp_storey := 0
var _comp_seq: Dictionary = {}


## Start a fresh build with `surface_count` surfaces. Clears both logs, so a
## builder instance can be reused without the previous run's masses leaking in.
func begin(surface_count: int) -> void:
	part_log.clear()
	mass_log.clear()
	prop_log.clear()
	component_log.clear()
	_comp_host = ""
	_comp_storey = 0
	_comp_seq.clear()
	total_height = 0.0
	_kit = MeshKit.new(surface_count)


func commit() -> ArrayMesh:
	return _kit.commit()


## Tag subsequent parts (e.g. "keep", "curtain", "nave") for diagnostics.
func tag(t: String) -> void:
	_tag = t


## Name the thing the components emitted from here on BELONG to: "roof",
## "dormer_0", "porch", "frame_1". A component without a host cannot be told
## apart from an identically shaped one on a different part of the building,
## which is the whole reason exterior QA needs this log.
func host(host_name: String, storey := 0) -> void:
	_comp_host = host_name
	_comp_storey = storey


## Stop attributing components to a host.
func host_end() -> void:
	_comp_host = ""
	_comp_storey = 0


## The identity the next component with this role will get. Counting in
## emission order rather than hashing geometry means a component keeps its
## name when it MOVES, which is what lets QA say "dormer_1 has shifted"
## instead of "a dormer vanished and an unknown one appeared".
func _next_component_id(role: String) -> String:
	var n: int = int(_comp_seq.get(role, 0))
	_comp_seq[role] = n + 1
	return "%s#%d" % [role, n]


func _log_component(role: String, form: String, surface: int, extra: Dictionary) -> Dictionary:
	var row := {"id": _next_component_id(role), "role": role, "form": form,
		"host": _comp_host, "storey": _comp_storey, "surface": surface,
		"tag": _tag}
	row.merge(extra)
	component_log.append(row)
	return row


## Emit an oriented box AND record it as a named component. The kit gets
## exactly the arguments it would have got from a bare _kit.oriented_box call,
## so logging cannot move a vertex.
func component_box(role: String, size: Vector3, xform: Transform3D, surf: int) -> Dictionary:
	var row := _log_component(role, "box", surf, {"xf": xform, "size": size})
	_kit.oriented_box(size, xform, surf)
	return row


## Emit a polygon slab AND record it as a named component. `points` are the
## WORLD-space polygon actually handed to the kit.
func component_slab(role: String, points: PackedVector3Array, depth: float,
		surf: int, vertical := true) -> Dictionary:
	var row := _log_component(role, "slab", surf,
		{"points": points, "depth": depth, "vertical": vertical})
	_kit.slab_poly(points, depth, surf, vertical)
	return row


## Record a component emitted by a kit primitive this log has no shape for
## (a ridge roof, a drum, a taper). `args` must be the ARGUMENTS HANDED TO THE
## KIT plus an explicit world `aabb`, so the row still describes what was
## emitted rather than what the spec asked for.
func component_note(role: String, form: String, surf: int, args: Dictionary) -> Dictionary:
	return _log_component(role, form, surf, args)


## Every logged component whose role begins with `role_prefix` (all of them
## when the prefix is empty).
func components(role_prefix := "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in component_log:
		if role_prefix.is_empty() or (c["role"] as String).begins_with(role_prefix):
			out.append(c)
	return out


## Every logged component belonging to `host_name`.
func components_of(host_name: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in component_log:
		if c["host"] == host_name:
			out.append(c)
	return out


## The distinct host names that emitted components, in first-emission order.
func component_hosts() -> PackedStringArray:
	var out := PackedStringArray()
	for c in component_log:
		var h: String = c["host"]
		if not h.is_empty() and not out.has(h):
			out.append(h)
	return out


## The world AABB a logged component occupies, from its emitted geometry.
static func component_aabb(row: Dictionary) -> AABB:
	if row.has("aabb"):
		return (row["aabb"] as AABB).abs()
	var pts := PackedVector3Array()
	if row["form"] == "box":
		var xf: Transform3D = row["xf"]
		var h: Vector3 = (row["size"] as Vector3) * 0.5
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					pts.append(xf * Vector3(h.x * sx, h.y * sy, h.z * sz))
	elif row["form"] == "slab":
		# slab_poly offsets the polygon by half its thickness EITHER WAY, along
		# UP when the caller asked for vertical depth and along the polygon's
		# own normal otherwise. Mirror that, or the recorded volume is a
		# zero-thickness sheet and nothing sitting on it ever collides.
		var src: PackedVector3Array = row["points"]
		if src.size() < 3:
			return AABB()
		var axis := Vector3.UP
		if not bool(row["vertical"]):
			axis = (src[1] - src[0]).cross(src[2] - src[0]).normalized()
			if axis.length_squared() < 1e-12:
				axis = Vector3.UP
		var off: Vector3 = axis * (float(row["depth"]) * 0.5)
		for p in src:
			pts.append(p + off)
			pts.append(p - off)
	else:
		return AABB()
	if pts.is_empty():
		return AABB()
	var box_aabb := AABB(pts[0], Vector3.ZERO)
	for p in pts:
		box_aabb = box_aabb.expand(p)
	return box_aabb


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

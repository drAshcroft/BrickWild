class_name ComponentCheck
extends RefCounted
## Does the building actually CONTAIN the parts it says it emitted?
##
## MassBuilder.component_log names the exterior pieces -- this roof face, that
## dormer cheek, the verge board on the south gable -- and records the geometry
## each was emitted with. This check re-emits every one of those rows on its own
## and requires the finished mesh to hold precisely those triangles.
##
## That is the difference between a log and evidence. A log that is written
## from the spec agrees with a dormer nobody built; a log that is written at
## emission and then MEASURED AGAINST THE MESH cannot. Move a component after
## it was logged, or drop one the log still claims, and this says so.

## Roles that make up the main roof of the building itself. A porch roof and a
## dormer rooflet are roofs too, but they are not THE roof, and counting them
## as one is how a house ends up with three main roof masses.
const MAIN_ROOF_ROLE := "roof_face_"

## Forms whose geometry this check can reproduce. A row of any other form is
## counted and attributed but not measured; `unverified` reports how many.
const MEASURABLE := ["box", "slab"]


## {ok:bool, failures:PackedStringArray, checked:int, unverified:int}
static func check(builder: MassBuilder, mesh: ArrayMesh) -> Dictionary:
	var failures := PackedStringArray()
	var checked := 0
	var unverified := 0
	# One isolated kit per surface: the mesh's surface i and the component's
	# surface i have to match, or a roof slab emitted onto the wall surface
	# would pass by being present somewhere.
	var isolated: Dictionary = {}
	for row in builder.component_log:
		if not MEASURABLE.has(row["form"]):
			unverified += 1
			continue
		checked += 1
		var surf := int(row["surface"])
		if not isolated.has(surf):
			isolated[surf] = MeshKit.new(1)
		var kit: MeshKit = isolated[surf]
		if row["form"] == "box":
			kit.oriented_box(row["size"], row["xf"], 0)
		else:
			kit.slab_poly(row["points"], float(row["depth"]), 0,
				bool(row["vertical"]), PackedInt32Array(row.get("open_edges", PackedInt32Array())))
	for surf in isolated:
		var at := logical_surface(mesh, int(surf))
		if at < 0:
			failures.append("components claim surface %d, mesh has %d"
				% [surf, mesh.get_surface_count()])
			continue
		var want_arrays: Array = (isolated[surf] as MeshKit).commit().surface_get_arrays(0)
		var have_arrays: Array = mesh.surface_get_arrays(at)
		var want: PackedVector3Array = _triangle_vertices(want_arrays)
		var have: PackedVector3Array = _triangle_vertices(have_arrays)
		var missing := missing_triangles(have, want)
		if missing > 0:
			failures.append("surface %d is missing %d logged component triangles"
				% [surf, missing])
	return {"ok": failures.is_empty(), "failures": failures,
		"checked": checked, "unverified": unverified}


## The position in `mesh` of the surface a builder calls slot `logical`, or -1.
## A committed mesh omits an empty slot, so the survivors after it move down; a
## builder that names them `material_slot:N` (MeshKit.commit_named) says which
## is which. Without names the slot is the position.
static func logical_surface(mesh: ArrayMesh, logical: int) -> int:
	var named := false
	for s in range(mesh.get_surface_count()):
		var name := mesh.surface_get_name(s)
		if name.begins_with("material_slot:"):
			named = true
			if int(name.trim_prefix("material_slot:")) == logical:
				return s
	if named:
		return -1
	return logical if logical >= 0 and logical < mesh.get_surface_count() else -1


## Expand indexed surfaces into the triangle stream used by the renderer.
## A non-indexed surface keeps its vertex soup; a present but empty index array
## means the surface has no triangles, even if its old vertices remain stored.
static func _triangle_vertices(arrays: Array) -> PackedVector3Array:
	if arrays.size() <= Mesh.ARRAY_INDEX:
		return PackedVector3Array()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index_value: Variant = arrays[Mesh.ARRAY_INDEX]
	if index_value == null:
		return vertices
	var indices: PackedInt32Array = index_value
	if indices.size() % 3 != 0:
		return PackedVector3Array()
	var expanded := PackedVector3Array()
	for index in indices:
		if index < 0 or index >= vertices.size():
			return PackedVector3Array()
		expanded.append(vertices[index])
	return expanded


## The component identities, in emission order. Two builds of the same plan
## must produce the same list, or nothing downstream can name a part.
static func identities(builder: MassBuilder) -> PackedStringArray:
	var out := PackedStringArray()
	for row in builder.component_log:
		out.append("%s/%s" % [row["host"], row["id"]])
	return out


## Components claimed as part of the building's own roof: the main roof faces
## and everything hosted on the roof or on one of its dormers. A porch is not
## included -- it has its own host.
static func roof_claims(builder: MassBuilder) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row in builder.component_log:
		var host: String = row["host"]
		if host == "roof" or host.begins_with("dormer"):
			out.append(row)
	return out


## How many triangles `want` has that `have` does not. Winding-sensitive: a
## face emitted the other way round is a different triangle, which is the
## point -- Godot's front faces are clockwise and an inside-out roof is a bug.
static func missing_triangles(have: PackedVector3Array,
		want: PackedVector3Array) -> int:
	var have_counts := triangle_counts(have)
	var want_counts := triangle_counts(want)
	var missing := 0
	for key in want_counts:
		var short: int = int(want_counts[key]) - int(have_counts.get(key, 0))
		if short > 0:
			missing += short
	return missing


static func contains_triangles(have: PackedVector3Array,
		want: PackedVector3Array) -> bool:
	return missing_triangles(have, want) == 0


## Multiset of triangles, keyed so the same triangle emitted twice counts
## twice. Rotating a triangle's own vertices is the same triangle; reversing
## them is not.
static func triangle_counts(vertices: PackedVector3Array) -> Dictionary:
	var counts := {}
	if vertices.size() % 3 != 0:
		return counts
	for i in range(0, vertices.size(), 3):
		var key := triangle_key(vertices[i], vertices[i + 1], vertices[i + 2])
		counts[key] = int(counts.get(key, 0)) + 1
	return counts


static func triangle_key(a: Vector3, b: Vector3, c: Vector3) -> String:
	var keys := [point_key(a), point_key(b), point_key(c)]
	var start := 0
	for i in range(1, 3):
		if String(keys[i]) < String(keys[start]):
			start = i
	return "%s>%s>%s" % [keys[start], keys[(start + 1) % 3], keys[(start + 2) % 3]]


static func point_key(p: Vector3) -> String:
	return "%d:%d:%d" % [roundi(p.x * 100000.0), roundi(p.y * 100000.0),
		roundi(p.z * 100000.0)]

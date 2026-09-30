class_name VoxelGrid
extends RefCounted
## A rasterized copy of a built mesh, for the checks an AABB cannot answer:
## is the solid one connected piece, is this opening actually cut into masonry,
## does the wall line ever break.
##
## Extracted from BlueprintQA, which was the only place it existed, so the
## castle checks can ask the same questions of their own meshes. It knows
## nothing about churches or castles -- it takes a mesh and hands back voxels.

## Default voxel size in metres. A grid may be coarser: a 300 m fortress at
## half-metre voxels is 24 million cells, and the dilation pass alone made the
## sweep take longer than every other suite put together. Callers scale the
## voxel to the building so the grid stays about the same size whatever it is
## measuring.
const VOX := 0.5

var vox := VOX
var origin := Vector3.ZERO
var nx := 0
var ny := 0
var nz := 0

var _solid: Array[PackedByteArray] = []


## Rasterize `mesh`, skipping one surface (openings are recesses, not
## structure). Surfaces are hollow shells, so the result is dilated by one
## voxel: that gives every wall real thickness in the grid and merges touching
## geometry into one mass.
func rasterize(mesh: ArrayMesh, skip_surface: Variant = -1, vox_size := 0.0,
		extra_bounds: Array[AABB] = []) -> void:
	vox = vox_size if vox_size > 0.0 else VOX
	var mn := Vector3(INF, INF, INF)
	var mx := -Vector3(INF, INF, INF)
	for s in range(mesh.get_surface_count()):
		var verts: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for v in verts:
			mn = mn.min(v)
			mx = mx.max(v)
	for bounds in extra_bounds:
		mn = mn.min(bounds.position)
		mx = mx.max(bounds.end)
	# expand by one voxel so boundary geometry rasterizes fully
	origin = Vector3(floorf(mn.x / vox) * vox - vox, floorf(mn.y / vox) * vox - vox,
		floorf(mn.z / vox) * vox - vox)
	nx = int(ceil((mx.x - origin.x) / vox)) + 2
	ny = int(ceil((mx.y - origin.y) / vox)) + 2
	nz = int(ceil((mx.z - origin.z) / vox)) + 2
	_solid.clear()
	for _y in range(ny):
		var row := PackedByteArray()
		row.resize(nx * nz)
		_solid.append(row)

	for s2 in range(mesh.get_surface_count()):
		if (skip_surface is int and s2 == int(skip_surface)) \
				or (skip_surface is Array and s2 in skip_surface):
			continue
		var arrays: Array = mesh.surface_get_arrays(s2)
		var verts2: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx_v = arrays[Mesh.ARRAY_INDEX]
		var idx: PackedInt32Array = idx_v if idx_v != null else PackedInt32Array()
		if idx.is_empty():
			idx.resize(verts2.size())
			for k in range(verts2.size()):
				idx[k] = k
		var i := 0
		while i + 2 < idx.size():
			_mark_tri(verts2[idx[i]], verts2[idx[i + 1]], verts2[idx[i + 2]])
			i += 3
	_dilate()


func get_voxel(x: int, y: int, z: int) -> bool:
	if x < 0 or x >= nx or y < 0 or y >= ny or z < 0 or z >= nz:
		return false
	return _solid[y][x * nz + z] == 1


func at_world(p: Vector3) -> bool:
	return get_voxel(vx(p.x), vy(p.y), vz(p.z))


func count_solid() -> int:
	var n := 0
	for y in range(ny):
		for b in _solid[y]:
			if b == 1:
				n += 1
	return n


func world_of(x: int, y: int, z: int) -> Vector3:
	return origin + Vector3(x + 0.5, y + 0.5, z + 0.5) * vox


## Is there solid masonry in any of the 26 neighbours?
func has_neighbor(x: int, y: int, z: int) -> bool:
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for dz in range(-1, 2):
				if dx == 0 and dy == 0 and dz == 0:
					continue
				if get_voxel(x + dx, y + dy, z + dz):
					return true
	return false


## Does the ray from v along dir hit solid masonry before leaving the grid?
func ray_hits_solid(v: Vector3i, dir: Vector3i) -> bool:
	var x: int = v.x + dir.x
	var y: int = v.y + dir.y
	var z: int = v.z + dir.z
	while x >= 0 and x < nx and y >= 0 and y < ny and z >= 0 and z < nz:
		if get_voxel(x, y, z):
			return true
		x += dir.x
		y += dir.y
		z += dir.z
	return false


## Six-way flood fill from a solid voxel; returns the set of cells reached.
func flood_from(seed: Vector3i) -> Dictionary:
	var visited := {seed: true}
	var stack: Array[Vector3i] = [seed]
	while not stack.is_empty():
		var cur: Vector3i = stack.pop_back()
		for d in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.UP, Vector3i.DOWN,
				Vector3i.FORWARD, Vector3i.BACK]:
			var nxt: Vector3i = cur + d
			if visited.has(nxt):
				continue
			if get_voxel(nxt.x, nxt.y, nxt.z):
				visited[nxt] = true
				stack.append(nxt)
	return visited


## The first solid voxel not in `visited`, for diagnosing an orphan region.
func first_unvisited(visited: Dictionary) -> Vector3i:
	for y in range(ny):
		for x in range(nx):
			for z in range(nz):
				if get_voxel(x, y, z) and not visited.has(Vector3i(x, y, z)):
					return Vector3i(x, y, z)
	return Vector3i(-1, -1, -1)


func vx(wx: float) -> int:
	return clampi(int(floor((wx - origin.x) / vox)), 0, nx - 1)


func vy(wy: float) -> int:
	return clampi(int(floor((wy - origin.y) / vox)), 0, ny - 1)


func vz(wz: float) -> int:
	return clampi(int(floor((wz - origin.z) / vox)), 0, nz - 1)


# --------------------------------------------------------------- internals

## Conservative triangle rasterization: sampled along the edges and across the
## interior, at half a voxel, so no wall slips between two samples.
func _mark_tri(a: Vector3, b: Vector3, c: Vector3) -> void:
	var steps: int = int(maxf(maxf((b - a).length(), (c - b).length()),
		(a - c).length()) / (vox * 0.5)) + 1
	for i in range(steps + 1):
		var t0: float = float(i) / steps
		var pa: Vector3 = a.lerp(b, t0)
		var pc: Vector3 = a.lerp(c, t0)
		var inner: int = int(pc.distance_to(pa) / (vox * 0.5)) + 1
		for j in range(inner):
			_set_world(pa.lerp(pc, float(j) / inner))


func _set_world(p: Vector3) -> void:
	var x := int(floor((p.x - origin.x) / vox))
	var y := int(floor((p.y - origin.y) / vox))
	var z := int(floor((p.z - origin.z) / vox))
	if x >= 0 and x < nx and y >= 0 and y < ny and z >= 0 and z < nz:
		_solid[y][x * nz + z] = 1


func _dilate() -> void:
	var out: Array[PackedByteArray] = []
	for y in range(ny):
		var row := PackedByteArray()
		row.resize(nx * nz)
		out.append(row)
	for y in range(ny):
		for x in range(nx):
			for z in range(nz):
				if _solid[y][x * nz + z] != 1:
					continue
				for dy in range(-1, 2):
					var yy: int = y + dy
					if yy < 0 or yy >= ny:
						continue
					for dx in range(-1, 2):
						var xx: int = x + dx
						if xx < 0 or xx >= nx:
							continue
						for dz in range(-1, 2):
							var zz: int = z + dz
							if zz >= 0 and zz < nz:
								out[yy][xx * nz + zz] = 1
	_solid = out

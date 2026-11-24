class_name VillageFinishedGround
extends RefCounted
## The ground of a planned village as a consumer must make it
## (CITY-GROUND-CONTRACT, docs/VILLAGE_TERRAIN.md "The caller shapes the
## ground"). Only ever called for a plan on given ground.
##
## WHY. BrickWild grades every lot to its own plane, beds every road and cuts
## every stair street, and plans the entry flights, the plinths, the props and
## the 3D walk against THAT ground (VillageGroundSurface). A consumer that
## levels its own pad under each building instead has a terrain the buildings
## were not built for: flights end in the air or in the bank, foundations show,
## the street mesh runs into them. So the ground is published, not described:
## one height grid, in the plan's own frame, that the consumer lays into its
## terrain. Inside the site it is `VillageGroundSurface.height_at`; in the
## margin round it, the ground the plan was made on, so the consumer has a
## band to blend back to its own surface over.
##
## The grid is a `brickwild.terrain` grid like the one the caller gave, but in
## the PLAN's frame: a node at plan point p stands on the caller's ground at
## `site.anchor_m + p rotated by site.yaw_deg`, as every plan point does.
## A step in the ground (a terrace wall, a riser beside a road) is sampled as
## it is: within one cell the consumer's terrain ramps where BrickWild's mesh
## drops a wall.

## The grid's spacing. A voxel terrain meshes about a metre; finer than that
## buys nothing a consumer can lay.
const CELL_M := 1.0
## How far round the site the grid carries the ground the plan was made on.
const MARGIN_M := 12.0
## A node this far from the given ground is counted as moved.
const CHANGED_M := 0.05


## The ground the plan was made on at plan point `p`: the caller's grid (eased
## or not), read through the siting.
static func given_at(plan: VillagePlan, p: Vector2) -> float:
	var g: VillageTerrain = plan.terrain()
	if g.parent != null:
		return g.parent.height_at(g.to_parent(p))
	return g.height_at(p)


## The finished ground of `plan` over its site grown by `margin_m`, at
## `cell_m`, in the plan's frame. Null for a plan without ground.
static func grid(plan: VillagePlan, cell_m := CELL_M, margin_m := MARGIN_M) -> VillageTerrain:
	var surface := VillageGroundSurface.of(plan)
	if surface == null:
		return null
	var site: Rect2 = plan.site
	var want: Rect2 = site.grow(margin_m)
	# on the cell lattice, so two plans of one site sample the same points
	var rect := Rect2((want.position / cell_m).floor() * cell_m, Vector2.ZERO)
	var cols: int = int(ceil((want.end.x - rect.position.x) / cell_m)) + 1
	var rows: int = int(ceil((want.end.y - rect.position.y) / cell_m)) + 1
	var heights := PackedFloat32Array()
	heights.resize(cols * rows)
	for r in range(rows):
		for c in range(cols):
			var p: Vector2 = rect.position + Vector2(c, r) * cell_m
			# to the millimetre, like everything the exporter writes: two machines, one file
			heights[r * cols + c] = snappedf(surface.height_at(p) if site.has_point(p) else given_at(plan, p), 0.001)
	var out := VillageTerrain.new()
	out.origin = rect.position
	out.cell_m = cell_m
	out.cols = cols
	out.rows = rows
	out.heights = heights
	out.water_level_m = plan.terrain().water_level_m
	out.source = "finished"
	out._validate()
	return out


## How far the finished ground stands from the ground the plan was made on,
## read at the grid's own nodes inside the site:
##   {"cut_max_m", "fill_max_m", "cut_m3", "fill_m3", "changed_m2", "site_m2"}
static func moved(plan: VillagePlan, finished: VillageTerrain) -> Dictionary:
	var out := {"cut_max_m": 0.0, "fill_max_m": 0.0, "cut_m3": 0.0, "fill_m3": 0.0, "changed_m2": 0.0,
		"site_m2": plan.site.get_area()}
	var node_m2: float = finished.cell_m * finished.cell_m
	for r in range(finished.rows):
		for c in range(finished.cols):
			var p: Vector2 = finished.origin + Vector2(c, r) * finished.cell_m
			if not plan.site.has_point(p):
				continue
			var d: float = finished.heights[r * finished.cols + c] - given_at(plan, p)
			if d < 0.0:
				out["cut_max_m"] = maxf(float(out["cut_max_m"]), -d)
				out["cut_m3"] = float(out["cut_m3"]) - d * node_m2
			else:
				out["fill_max_m"] = maxf(float(out["fill_max_m"]), d)
				out["fill_m3"] = float(out["fill_m3"]) + d * node_m2
			if absf(d) > CHANGED_M:
				out["changed_m2"] = float(out["changed_m2"]) + node_m2
	return out

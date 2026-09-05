class_name CastleBuilder
extends MassBuilder
## CastleSpec -> ArrayMesh. Massing-first, and which masses exist is decided by
## the tier the footprint fell into:
##
##   house     one hall block, a porch, an annexe, external chimney stacks
##   manor     a main range with cross wings round a court, optional front range
##   castle    a curtain wall with towers and a gatehouse, keep and hall inside
##   fortress  all of that, with a second enceinte inside the first and a walled
##             causeway joining the two gatehouses
##
## Every position comes from CastleGeometry. Nothing here derives massing of its
## own -- when the church builder and its blueprint each derived their own, the
## drawing quietly stopped being a drawing of the model.
##
## Surfaces: 0 = stone, 1 = trim (parapets, copings), 2 = roof, 3 = openings.

const SURF_STONE := 0
const SURF_TRIM := 1
const SURF_ROOF := 2
const SURF_OPEN := 3

## Steps a battered wall or tower is emitted in. More steps is a smoother
## talus; four reads as masonry courses rather than as a ramp.
const BATTER_STEPS := 4
const EAVE := 0.5              # roof overhang past the wall it caps
const SLIT_BAY := 4.5          # metres of wall per arrow slit

var spec: CastleSpec


func build(p_spec: CastleSpec) -> ArrayMesh:
	spec = p_spec
	begin(4)
	total_height = spec.height

	if CastleGeometry.is_tower_house(spec):
		_build_tower_house()
		return commit()
	if CastleGeometry.is_ridge(spec):
		_build_ridge()
		return commit()
	match spec.tier:
		&"house":
			_build_house()
		&"manor":
			_build_manor()
		_:
			_build_enclosure()
	return commit()


# -------------------------------------------------------- motte and bailey

## The mound, the shell keep on it and the curtain that climbs to it.
func _build_motte() -> void:
	var m: AABB = CastleGeometry.motte_aabb(spec)
	var c: Vector2 = CastleGeometry.motte_center(spec)
	var rb: float = CastleGeometry.motte_base_radius(spec)
	var rt: float = CastleGeometry.motte_top_radius(spec)
	tag("motte")
	_kit.drum(Vector3(c.x, 0.0, c.y), rb, rt, spec.motte_height, SURF_STONE, 24)
	_log_mass("motte", m)

	tag("keep")
	var k: AABB = CastleGeometry.shell_keep_aabb(spec)
	var base := Vector3(c.x, spec.motte_height, c.y)
	var t: float = spec.shell_thickness
	_kit.oval_ring(base, k.size.x / 2.0, k.size.z / 2.0, t, k.size.y, SURF_STONE, 28)
	_log_mass("keep_shell", k)
	# the parapet, merlon by merlon round the oval
	if spec.battlements:
		var n := 28
		for i in range(n):
			var a: float = TAU * float(i) / n
			var p := base + Vector3(cos(a) * (k.size.x / 2.0 - t / 2.0), k.size.y + spec.merlon_h / 2.0,
				sin(a) * (k.size.z / 2.0 - t / 2.0))
			box(Vector3(CastleGeometry.MERLON_W, spec.merlon_h, minf(t, 0.6)), p, SURF_TRIM, -a)
	# a door in the keep, on the side the climb arrives
	_opening(base + Vector3(0.0, 1.6, -(k.size.z / 2.0 + CastleGeometry.OPENING_EPS)),
		PI, minf(k.size.x * 0.12, 1.6), 2.6, &"arched", true)
	total_height = maxf(total_height, spec.motte_height + k.size.y + spec.merlon_h)

	tag("climb")
	var w: Dictionary = CastleGeometry.climb_wall(spec)
	var a: Vector3 = w["from"]
	var b: Vector3 = w["to"]
	var dir: Vector3 = (b - a).normalized()
	var length: float = a.distance_to(b)
	var up := Vector3(0.0, dir.z, -dir.y).normalized()
	if up.y < 0.0:
		up = -up
	var h: float = float(w["height"])
	var th: float = float(w["thickness"])
	var centre: Vector3 = a + dir * (length / 2.0) + up * (h / 2.0)
	var xf := Transform3D(Basis(Vector3.RIGHT, up, dir), centre)
	_kit.oriented_box(Vector3(th, h, length), xf, SURF_STONE)
	_log_mass("climb", CastleGeometry.climb_aabb(spec))


# ------------------------------------------------------------ ridge castle

## Ranges along the spine, each a rotated block under its own ridge roof with
## a row of windows a storey, diving into the tower at either end; a tower at
## every vertex. No curtain, no gate, no bailey: the ranges are the walls.
func _build_ridge() -> void:
	var storeys: int = CastleGeometry.ridge_storeys(spec)
	var sh: float = spec.height / float(storeys)
	for seg in CastleGeometry.ridge_ranges(spec):
		var name: String = seg["name"]
		tag("hall" if name == "hall" else "range")
		var a: Vector2 = seg["from"]
		var b: Vector2 = seg["to"]
		var mid: Vector2 = (a + b) / 2.0
		var yaw: float = seg["yaw"]
		var length: float = seg["length"]
		var width: float = seg["width"]
		var height: float = seg["height"]
		box(Vector3(length, height, width), Vector3(mid.x, height / 2.0, mid.y), SURF_STONE, yaw)
		_log_mass(name, CastleGeometry.ridge_range_aabb(seg))
		# the roof runs along the range: local Z of the roof transform is the
		# direction of the segment
		var dir: Vector2 = seg["dir"]
		var rise: float = width * spec.roof_pitch * 0.5
		var xf := Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.y)), Vector3(mid.x, height, mid.y))
		_kit.ridge_roof(xf, width + EAVE, length + EAVE * 0.8, rise, SURF_ROOF, SURF_STONE, width, length)
		if spec.dormers:
			_ridge_dormers(mid, dir, length, width, height, rise)
		total_height = maxf(total_height, height + rise)
		# windows: a row a storey on both long faces, on the rotated face
		var n: Vector2 = seg["normal"]
		var count: int = clampi(int(length / 3.5), 1, 24)
		for s in range(storeys):
			var y: float = (float(s) + 0.55) * sh
			for side in [1.0, -1.0]:
				var face_n: Vector2 = n * side
				var ang: float = atan2(face_n.x, face_n.y)
				for i in range(count):
					var t: float = (float(i) + 1.0) / (float(count) + 1.0) - 0.5
					var p: Vector2 = mid + dir * (length * t) + face_n * (width / 2.0 + CastleGeometry.OPENING_EPS)
					_opening(Vector3(p.x, y, p.y), ang, spec.window_w, spec.window_h, spec.window_style)
	tag("tower")
	var i2 := 0
	for tc in CastleGeometry.ridge_tower_centers(spec):
		_tower(tc["pos"], 0, "tower_0_corner_%d" % i2, tc["away"], i2)
		i2 += 1


## Dormers along a rotated range, either side of its ridge.
func _ridge_dormers(mid: Vector2, dir: Vector2, length: float, width: float,
		height: float, rise: float) -> void:
	var n := Vector2(-dir.y, dir.x)
	var count: int = clampi(int(length / 6.0), 1, 8)
	var dw: float = minf(1.4, width * 0.2)
	var yaw: float = atan2(-dir.y, dir.x)
	for side in [-1.0, 1.0]:
		for i in range(count):
			var t: float = (float(i) + 1.0) / (float(count) + 1.0) - 0.5
			var p: Vector2 = mid + dir * (length * t) + n * (side * width * 0.26)
			box(Vector3(dw, dw * 1.5, dw), Vector3(p.x, height + rise * 0.45 + dw * 0.75, p.y),
				SURF_ROOF, yaw)


# ------------------------------------------------------------- tower house

## One tall block, storey by storey, each a little wider than the one above
## (the walls thicken toward the foot); a fighting platform on top; a raised
## door on the front face and rows of windows above it; and the jog off one
## corner. The `hall` mass is the shaft as a whole -- the anchor every
## unwalled tier is measured from -- and each storey is logged as its own
## mass so TowerCheck can read the wall thickness off the foot and the top.
func _build_tower_house() -> void:
	var t: AABB = CastleGeometry.tower_house_aabb(spec)
	tag("hall")
	_log_mass("hall", t)
	tag("storey")
	var n: int = maxi(spec.tower_storeys, 1)
	for s in range(n):
		var a: AABB = CastleGeometry.tower_storey_aabb(spec, s)
		_box_aabb(a, SURF_STONE)
		_log_mass("storey_%d" % s, a)
	tag("platform")
	var p: AABB = CastleGeometry.tower_platform_aabb(spec)
	_box_aabb(p, SURF_STONE)
	_log_mass("platform", p)
	_crenellate_rect(p, p.position.y + p.size.y, SURF_TRIM)
	total_height = maxf(total_height, p.position.y + p.size.y + spec.merlon_h)

	# the way in: one door, a storey up, on the front face of the storey it
	# opens into
	tag("door")
	var sill: float = CastleGeometry.tower_door_sill(spec)
	var door_h: float = minf(CastleGeometry.tower_storey_height(spec) * 0.7, 2.6)
	var door_storey: int = clampi(int(sill / CastleGeometry.tower_storey_height(spec)), 0, n - 1)
	var ds: AABB = CastleGeometry.tower_storey_aabb(spec, door_storey)
	_opening(Vector3(t.position.x + t.size.x / 2.0, sill + door_h / 2.0,
		ds.position.z - CastleGeometry.OPENING_EPS), PI, minf(t.size.x * 0.25, 1.4),
		door_h, &"arched", true)

	# windows on every storey above the lift, on all four faces of that
	# storey's own box -- never on the ground storey, which is blind
	tag("window")
	for s2 in range(n):
		var a2: AABB = CastleGeometry.tower_storey_aabb(spec, s2)
		var y: float = a2.position.y + a2.size.y * 0.55
		if y - spec.window_h / 2.0 < CastleGeometry.TOWER_LIFT_MIN:
			continue
		var only: Array = []
		if s2 == door_storey:
			only = [Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0)]
		_face_openings(a2, y, spec.window_style, only, 3.5)

	tag("wing")
	var j := 0
	for jog in CastleGeometry.tower_jog_aabbs(spec):
		# the face it shares with the shaft is buried; the jog looks the
		# other three ways, and only above the lift
		var buried := Vector3(0, 0, 1) if j == 0 else Vector3(0, 0, -1)
		var faces: Array = []
		for f in [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0)]:
			if (f as Vector3).dot(buried) < 0.9:
				faces.append(f)
		_box_aabb(jog, SURF_STONE)
		_log_mass("wing_jog_%d" % j, jog)
		var jp := AABB(Vector3(jog.position.x - 0.2, jog.position.y + jog.size.y, jog.position.z - 0.2),
			Vector3(jog.size.x + 0.4, 0.4, jog.size.z + 0.4))
		_box_aabb(jp, SURF_STONE)
		_crenellate_rect(jp, jp.position.y + jp.size.y, SURF_TRIM)
		var rows: int = maxi(int(jog.size.y / CastleGeometry.tower_storey_height(spec)), 1)
		for row in range(rows):
			var jy: float = (float(row) + 0.55) * CastleGeometry.tower_storey_height(spec)
			if jy - spec.window_h / 2.0 < CastleGeometry.TOWER_LIFT_MIN or jy > jog.size.y - 0.5:
				continue
			_face_openings(jog, jy, spec.window_style, faces, 3.5)
		j += 1


# ------------------------------------------------------------------- house

func _build_house() -> void:
	tag("hall")
	var a: AABB = CastleGeometry.house_range_aabb(spec)
	_range(a, "hall", SURF_STONE, true)

	tag("annexe")
	var ann: AABB = CastleGeometry.annexe_aabb(spec)
	if ann.size.x > 0.0:
		_range(ann, "annexe", SURF_STONE, true)

	_build_porch()
	_build_chimneys()


# ------------------------------------------------------------------- manor

func _build_manor() -> void:
	tag("range")
	_range(CastleGeometry.house_range_aabb(spec), "hall", SURF_STONE, true)

	tag("wing")
	for side in CastleGeometry.wing_sides(spec):
		var w: AABB = CastleGeometry.manor_wing_aabb(spec, side)
		_range(w, "wing_%s" % ("left" if side < 0.0 else "right"), SURF_STONE, true)

	tag("range")
	var fr: AABB = CastleGeometry.manor_front_range_aabb(spec)
	if fr.size.x > 0.0:
		_range(fr, "range_front", SURF_STONE, true)

	tag("tower")
	var i := 0
	for c in CastleGeometry.manor_tower_centers(spec):
		_tower(c, 0, "tower_manor_%d" % i, Vector3(0, 0, -1))
		i += 1

	_build_porch()
	_build_chimneys()


## The entrance block: a porch on an open court, a gate passage through a
## closed one. Either way it laps the range it serves, so it reads as built
## into the house rather than parked against it.
func _build_porch() -> void:
	var p: AABB = CastleGeometry.porch_aabb(spec)
	if p.size.x <= 0.0:
		return
	tag("porch")
	_box_aabb(p, SURF_STONE)
	_log_mass("porch", p)
	var xf := Transform3D(Basis(), Vector3(0.0, p.size.y, p.position.z + p.size.z / 2.0))
	_kit.ridge_roof(xf, p.size.x + 0.3, p.size.z + 0.3,
		p.size.x * spec.roof_pitch * 0.4, SURF_ROOF, SURF_STONE, p.size.x, p.size.z)
	_opening(Vector3(0.0, p.size.y * 0.42, p.position.z - CastleGeometry.OPENING_EPS),
		PI, minf(p.size.x * 0.5, 2.0), p.size.y * 0.6, &"arched", true)
	total_height = maxf(total_height, p.size.y + p.size.x * spec.roof_pitch * 0.4)


func _build_chimneys() -> void:
	if spec.chimneys <= 0:
		return
	tag("chimney")
	for i in range(spec.chimneys):
		var c: AABB = CastleGeometry.chimney_aabb(spec, i)
		_box_aabb(c, SURF_STONE)
		_log_mass("chimney_%d" % i, c)
		# the coping course that stops a stack reading as a bare post
		box(Vector3(c.size.x + 0.3, 0.25, c.size.z + 0.3),
			Vector3(c.position.x + c.size.x / 2.0, c.size.y + 0.12,
				c.position.z + c.size.z / 2.0), SURF_TRIM)
		total_height = maxf(total_height, c.size.y + 0.25)


# --------------------------------------------------------------- enclosure

func _build_enclosure() -> void:
	for r in CastleGeometry.rings(spec):
		_build_ring(r)

	tag("barbican")
	var bar: AABB = CastleGeometry.barbican_aabb(spec)
	if bar.size.x > 0.0:
		_box_aabb(bar, SURF_STONE)
		_log_mass("barbican", bar)
		_crenellate_rect(bar, bar.size.y, SURF_TRIM)
		_opening(Vector3(0.0, bar.size.y * 0.4, bar.position.z - CastleGeometry.OPENING_EPS),
			PI, minf(bar.size.x * 0.45, 2.4), bar.size.y * 0.55, &"arched", true)

	tag("link")
	for side in [-1.0, 1.0]:
		var lk: AABB = CastleGeometry.gate_link_aabb(spec, side)
		if lk.size.z <= 0.0:
			continue
		_box_aabb(lk, SURF_STONE)
		_log_mass("link_%s" % ("left" if side < 0.0 else "right"), lk)
		_crenellate_rect(lk, lk.size.y, SURF_TRIM)

	tag("keep")
	if spec.keep:
		_build_keep()
	if CastleGeometry.is_motte(spec):
		_build_motte()

	# The hall and the chapel look into the bailey (CAS-003): windows on the
	# courtyard face and the free short end, none through the curtain they
	# stand against, and a row of them rather than one every five metres.
	tag("hall")
	var hall: AABB = CastleGeometry.hall_aabb(spec)
	if hall.size.x > 0.0:
		_range(hall, "hall", SURF_STONE, true, [Vector3(1, 0, 0), Vector3(0, 0, -1)], RANGE_BAY)

	tag("chapel")
	var chapel: AABB = CastleGeometry.chapel_aabb(spec)
	if chapel.size.x > 0.0:
		_range(chapel, "chapel", SURF_STONE, true, [Vector3(-1, 0, 0)], RANGE_BAY)
		_build_apse()


## The chapel's apse: a half-drum on the end toward the gate, under a half
## cone, embedded in the chapel the way the church's is in its nave.
func _build_apse() -> void:
	var a: AABB = CastleGeometry.apse_aabb(spec)
	if a.size.x <= 0.0:
		return
	tag("apse")
	var r: float = CastleGeometry.apse_radius(spec)
	var h: float = a.size.y
	var origin := Vector3(a.position.x + a.size.x / 2.0, 0.0, a.position.z + a.size.z)
	# the half of a revolve that lies at -Z: angles PI .. 2PI
	_kit.revolve(PackedVector2Array([Vector2(r, 0.0), Vector2(r, h)]), origin,
		SURF_STONE, 10, PI, PI)
	_kit.revolve(PackedVector2Array([Vector2(r * 1.08, h), Vector2(0.0, h + r * 0.9)]),
		origin, SURF_ROOF, 10, PI, PI)
	_log_mass("apse", a)
	_log_part("apse", a.position + a.size / 2.0, a.size)
	# one window on the axis of the apse, looking out toward the gate
	_opening(origin + Vector3(0.0, h * 0.5, -(r + CastleGeometry.OPENING_EPS)),
		PI, spec.window_w, spec.window_h, spec.window_style)
	total_height = maxf(total_height, h + r * 0.9)


func _build_ring(r: int) -> void:
	if CastleGeometry.is_polygonal(spec):
		_build_ring_walls_poly(r)
	else:
		_build_ring_walls_rect(r)

	tag("tower")
	var i := 0
	for c in CastleGeometry.vertex_tower_centers(spec, r):
		# a vertex tower's free faces are the ones on the outward bisector
		var away := Vector3(signf(c.x), 0.0, signf(c.z)).normalized()
		if CastleGeometry.is_polygonal(spec):
			var mid: Vector2 = CastleGeometry.polygon_bbox(
				CastleGeometry.enceinte_polygon(spec, r)).get_center()
			away = Vector3(c.x - mid.x, 0.0, c.z - mid.y).normalized()
		_tower(c, r, "tower_%d_corner_%d" % [r, i], away, i)
		i += 1
	i = 0
	for slot in CastleGeometry.side_tower_slots(spec, r):
		_tower(slot["pos"], r, "tower_%d_side_%d" % [r, i], slot["facing"])
		i += 1
	i = 0
	for c2 in CastleGeometry.gate_tower_centers(spec, r):
		_tower(c2, r, "tower_%d_gate_%d" % [r, i], Vector3(0, 0, -1))
		i += 1

	tag("gate")
	var g: AABB = CastleGeometry.gatehouse_aabb(spec, r)
	if g.size.x > 0.0:
		_box_aabb(g, SURF_STONE)
		_log_mass("gate_%d" % r, g)
		_crenellate_rect(g, g.size.y, SURF_TRIM)
		var door_h: float = minf(g.size.y * 0.4, 5.0)
		_opening(Vector3(0.0, door_h / 2.0, g.position.z - CastleGeometry.OPENING_EPS),
			PI, minf(g.size.x * 0.4, 4.0), door_h, &"arched", true)
		# murder holes read as a band of small openings over the passage
		for k in range(3):
			var x: float = lerpf(-g.size.x * 0.3, g.size.x * 0.3, float(k) / 2.0)
			_opening(Vector3(x, g.size.y * 0.72, g.position.z - CastleGeometry.OPENING_EPS),
				PI, 0.4, 0.6, &"square")
		total_height = maxf(total_height, g.size.y + CastleGeometry.PARAPET_RISE + spec.merlon_h)


## The four axis-aligned runs of a rectangular enceinte -- the N = 4 plan, kept
## on its own path because every box in it lands on an axis and there is no
## reason to put it through a rotation that would only round it.
func _build_ring_walls_rect(r: int) -> void:
	tag("curtain")
	var t: float = CastleGeometry.wall_thickness(spec, r)
	for which in CastleGeometry.wall_names(spec, r):
		var a: AABB = CastleGeometry.wall_aabb(spec, r, which)
		if a.size.x < CastleGeometry.MIN_WALL_RUN and a.size.z < CastleGeometry.MIN_WALL_RUN:
			continue
		var outward: Vector3 = _wall_outward(which)
		_battered_wall(a, t, outward)
		_log_mass("wall_%d_%s" % [r, String(which)], a)
		_wall_top(a, outward, t)
		_wall_slits(a, outward, t, r)
		total_height = maxf(total_height, a.size.y + CastleGeometry.PARAPET_RISE + spec.merlon_h)


## The runs of a polygonal enceinte: the same battered wall, wall walk,
## crenellations and slits, but aligned to the edge instead of to an axis.
## Every box is emitted rotated about Y, and every opening is placed on the
## rotated FACE -- on a hexagon the difference between the wall and its bounding
## box is metres, so an opening on the box hangs in open air.
func _build_ring_walls_poly(r: int) -> void:
	tag("curtain")
	for seg in CastleGeometry.wall_segments(spec, r):
		_wall_run(seg, r)


func _wall_run(seg: Dictionary, r: int) -> void:
	var t: float = CastleGeometry.wall_thickness(spec, r)
	var tb: float = CastleGeometry.wall_base_thickness(spec, r)
	var h: float = CastleGeometry.wall_height(spec, r)
	var run: float = seg["length"]
	var yaw: float = seg["yaw"]
	var outward: Vector3 = seg["outward"]
	# the inner face, which is vertical at every course
	var mid: Vector2 = ((seg["a"] as Vector2) + (seg["b"] as Vector2)) / 2.0
	var inner := Vector3(mid.x - outward.x * t, 0.0, mid.y - outward.z * t)
	for i in range(BATTER_STEPS):
		var y0: float = h * float(i) / BATTER_STEPS
		var y1: float = h * float(i + 1) / BATTER_STEPS
		var th: float = lerpf(tb, t, (y0 + y1) / 2.0 / h)
		box(Vector3(run, y1 - y0, th),
			inner + outward * (th / 2.0) + Vector3(0.0, (y0 + y1) / 2.0, 0.0),
			SURF_STONE, yaw)
	_log_mass("wall_%d_%s" % [r, String(seg["name"])],
		CastleGeometry.segment_aabb(spec, r, seg))

	# wall walk and merlons, following the run's own top face
	var walk: Vector3 = inner + outward * (t / 2.0) + Vector3(0.0, h + CastleGeometry.PARAPET_RISE / 2.0, 0.0)
	box(Vector3(run, CastleGeometry.PARAPET_RISE, t + 0.3), walk, SURF_TRIM, yaw)
	if spec.battlements:
		var edge: Vector3 = inner + outward * (t - spec.merlon_h * 0.35)
		var along := Vector3(cos(yaw), 0.0, -sin(yaw)) * (run / 2.0)
		_crenellate_run(edge - along, edge + along, h + CastleGeometry.PARAPET_RISE,
			spec.merlon_h * 0.7, yaw, SURF_TRIM)
	_run_slits(seg, r)
	total_height = maxf(total_height, h + CastleGeometry.PARAPET_RISE + spec.merlon_h)


## Arrow slits down a slanted run, on the battered face itself.
func _run_slits(seg: Dictionary, r: int) -> void:
	var t: float = CastleGeometry.wall_thickness(spec, r)
	var tb: float = CastleGeometry.wall_base_thickness(spec, r)
	var h: float = CastleGeometry.wall_height(spec, r)
	var run: float = seg["length"]
	var outward: Vector3 = seg["outward"]
	var mid: Vector2 = ((seg["a"] as Vector2) + (seg["b"] as Vector2)) / 2.0
	var inner := Vector3(mid.x - outward.x * t, 0.0, mid.y - outward.z * t)
	var y: float = h * 0.62
	var th: float = lerpf(tb, t, y / h)
	var face: Vector3 = inner + outward * (th + CastleGeometry.OPENING_EPS)
	var along := Vector3(cos(seg["yaw"]), 0.0, -sin(seg["yaw"])) * run
	var n: int = clampi(int(run / SLIT_BAY), 1, 24)
	for i in range(n):
		var f: float = (float(i) + 1.0) / (float(n) + 1.0) - 0.5
		_opening(face + along * f + Vector3(0.0, y, 0.0), seg["yaw"], 0.32, 1.5,
			&"slit")


## The keep: a great square tower, a drum, a shell keep on its own plinth, or
## the tiered tenshu of a Japanese castle.
func _build_keep() -> void:
	var k: AABB = CastleGeometry.keep_aabb(spec)
	var c := Vector3(k.position.x + k.size.x / 2.0, 0.0, k.position.z + k.size.z / 2.0)
	_log_mass("keep", k)
	var opening_y: float = k.size.y * 0.55
	match spec.keep_shape:
		&"round", &"shell":
			var base_r: float = minf(k.size.x, k.size.z) / 2.0
			var top_r: float = base_r * 0.94
			_kit.drum(c, base_r, top_r, k.size.y, SURF_STONE, 14)
			_crenellate_ring(c, top_r, k.size.y, 14, SURF_TRIM)
			_shell_openings(c, lerpf(base_r, top_r, opening_y / k.size.y), opening_y, 14)
		&"tiered":
			# A battered stone base carrying diminishing timber storeys. drum()
			# takes a CIRCUMradius: handing it the half-side made the plinth a
			# square inscribed in the keep's own footprint, which shrank it off
			# the wall it is supposed to lap and left the tenshu standing free.
			# A tenshu is squat: a deep stone base carrying storeys that step
			# down over most of the footprint. Three narrow tiers on a shallow
			# plinth gave a spike, not Himeji.
			var half: float = minf(k.size.x, k.size.z) / 2.0
			var plinth: float = k.size.y * CastleGeometry.TENSHU_PLINTH
			var corner: float = half * sqrt(2.0)
			_kit.drum(c, corner, corner * 0.88, plinth, SURF_STONE, 4, PI / 4.0)
			_kit.tiered_taper(c + Vector3(0, plinth, 0), half * 1.85,
				k.size.y - plinth, SURF_ROOF, CastleGeometry.TENSHU_TIERS, 0.14)
			_shell_openings(c, corner * 0.91, plinth * 0.5, 4, PI / 4.0)
		_:
			_box_aabb(k, SURF_STONE)
			_crenellate_rect(k, k.size.y, SURF_TRIM)
			_kit.hip_roof(k.size.x * 0.8, k.size.z * 0.8,
				CastleGeometry.roof_rise(spec, k), c.z, SURF_ROOF, k.size.y)
			_face_openings(k, opening_y, spec.window_style)
	total_height = maxf(total_height, k.size.y + CastleGeometry.roof_rise(spec, k))


# --------------------------------------------------------------- primitives

## Metres of bailey-facing wall per window on a hall or chapel: a row of
## windows, not one every five metres.
const RANGE_BAY := 3.0


## A block, its roof, and a window in each long face: the shape of every range
## in the design, whether it is a hall, a wing or a whole house. `faces` limits
## the windows to the listed outward normals (empty = every face); `bay` is
## the metres of wall per window.
func _range(a: AABB, mass_name: String, surf: int, roofed: bool,
		faces: Array = [], bay := 5.0) -> void:
	_box_aabb(a, surf)
	_log_mass(mass_name, a)
	var cx: float = a.position.x + a.size.x / 2.0
	var cz: float = a.position.z + a.size.z / 2.0
	if roofed:
		var rise: float = CastleGeometry.roof_rise(spec, a)
		var along_x: bool = CastleGeometry.ridge_along_x(a)
		var yaw: float = PI / 2.0 if along_x else 0.0
		var span: float = a.size.z if along_x else a.size.x
		var along: float = a.size.x if along_x else a.size.z
		var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(cx, a.size.y, cz))
		_kit.ridge_roof(xf, span + EAVE, along + EAVE * 0.8, rise, SURF_ROOF,
			SURF_STONE, span, along)
		total_height = maxf(total_height, a.size.y + rise)
		if spec.dormers:
			_dormers(a, along_x, rise)
	_face_openings(a, a.size.y * 0.5, spec.window_style, faces, bay)


## Windows in the middle of each of a block's four faces, facing out of it.
## Bays are spaced off the face, so a long range gets a row and a small annexe
## gets one.
func _face_openings(a: AABB, y: float, style: StringName, only: Array = [],
		bay := 5.0) -> void:
	var eps: float = CastleGeometry.OPENING_EPS
	var faces := [
		{"n": Vector3(0, 0, -1), "len": a.size.x, "ang": PI},
		{"n": Vector3(0, 0, 1), "len": a.size.x, "ang": 0.0},
		{"n": Vector3(-1, 0, 0), "len": a.size.z, "ang": -PI / 2.0},
		{"n": Vector3(1, 0, 0), "len": a.size.z, "ang": PI / 2.0},
	]
	var c := Vector3(a.position.x + a.size.x / 2.0, y, a.position.z + a.size.z / 2.0)
	for f in faces:
		var n: Vector3 = f["n"]
		if not only.is_empty():
			var wanted := false
			for o in only:
				if (o as Vector3).dot(n) > 0.9:
					wanted = true
			if not wanted:
				continue
		var run: float = f["len"]
		var count: int = clampi(int(run / bay), 1, 12)
		var half: Vector3 = Vector3(a.size.x, 0.0, a.size.z) / 2.0
		var face_c: Vector3 = c + Vector3(n.x * (half.x + eps), 0.0, n.z * (half.z + eps))
		var along := Vector3(n.z, 0.0, -n.x)      # the face's own long axis
		for i in range(count):
			var t: float = (float(i) + 1.0) / (float(count) + 1.0) - 0.5
			_opening(face_c + along * (run * t), f["ang"], spec.window_w,
				spec.window_h, style)


## Openings round a revolved shaft, one to each cardinal face.
##
## A drum or a tiered keep is narrower than the box its mass is logged as, so
## an opening placed on that box hangs in the air beside the building -- which
## is what the voxel sweep caught the tenshu doing. `radius` is the shell's
## CIRCUMradius at the height the openings sit; the face itself is the apothem,
## and on a four-sided shaft the difference between the two is 30% of the keep.
func _shell_openings(c: Vector3, radius: float, y: float, sides: int,
		rot := 0.0) -> void:
	var eps: float = CastleGeometry.OPENING_EPS
	var face_r: float = radius * cos(PI / float(sides)) + eps
	for k in range(4):
		var ang: float = rot + PI / 2.0 * k
		_opening(c + Vector3(sin(ang) * face_r, y, cos(ang) * face_r),
			ang, spec.window_w, spec.window_h, spec.window_style)


## Roof dormers: the tall gabled windows of a chateau roofline.
func _dormers(a: AABB, along_x: bool, rise: float) -> void:
	var n: int = clampi(int((a.size.x if along_x else a.size.z) / 6.0), 1, 6)
	var run: float = a.size.x if along_x else a.size.z
	var span: float = a.size.z if along_x else a.size.x
	var dw: float = minf(1.4, span * 0.2)
	for side in [-1.0, 1.0]:
		for i in range(n):
			var t: float = (float(i) + 1.0) / (float(n) + 1.0) - 0.5
			var out: float = span * 0.26
			var pos: Vector3 = Vector3(a.position.x + a.size.x / 2.0,
				a.size.y + rise * 0.45, a.position.z + a.size.z / 2.0)
			if along_x:
				pos += Vector3(run * t, 0.0, side * out)
			else:
				pos += Vector3(side * out, 0.0, run * t)
			box(Vector3(dw, dw * 1.5, dw), pos + Vector3(0, dw * 0.75, 0), SURF_ROOF)


## A wall run emitted as a battered stack: the inner face is vertical at every
## course, the outer face spreads as it descends. Pinning the inner face is what
## lets everything inside the bailey ignore the talus completely.
func _battered_wall(a: AABB, top_thick: float, outward: Vector3) -> void:
	var axis: int = 0 if absf(outward.x) > 0.5 else 2
	var base_thick: float = a.size.x if axis == 0 else a.size.z
	var inner: float = a.position[axis] if outward[axis] > 0.0 \
		else a.position[axis] + base_thick
	for i in range(BATTER_STEPS):
		var y0: float = a.size.y * float(i) / BATTER_STEPS
		var y1: float = a.size.y * float(i + 1) / BATTER_STEPS
		var th: float = lerpf(base_thick, top_thick, (y0 + y1) / 2.0 / a.size.y)
		var c: float = inner + outward[axis] * th / 2.0
		var size := Vector3(th if axis == 0 else a.size.x, y1 - y0,
			a.size.z if axis == 0 else th)
		var pos := Vector3(c if axis == 0 else a.position.x + a.size.x / 2.0,
			(y0 + y1) / 2.0, a.position.z + a.size.z / 2.0 if axis == 0 else c)
		box(size, pos, SURF_STONE)


## The wall walk and its merlons, following the wall's own top face.
func _wall_top(a: AABB, outward: Vector3, top_thick: float) -> void:
	var axis: int = 0 if absf(outward.x) > 0.5 else 2
	var base_thick: float = a.size.x if axis == 0 else a.size.z
	var inner: float = a.position[axis] if outward[axis] > 0.0 \
		else a.position[axis] + base_thick
	var walk: float = inner + outward[axis] * top_thick / 2.0
	var run: float = a.size.z if axis == 0 else a.size.x
	var cx: float = walk if axis == 0 else a.position.x + a.size.x / 2.0
	var cz: float = a.position.z + a.size.z / 2.0 if axis == 0 else walk
	box(Vector3(top_thick + 0.3 if axis == 0 else run, CastleGeometry.PARAPET_RISE,
			run if axis == 0 else top_thick + 0.3),
		Vector3(cx, a.size.y + CastleGeometry.PARAPET_RISE / 2.0, cz), SURF_TRIM)
	if not spec.battlements:
		return
	var edge: float = inner + outward[axis] * (top_thick - spec.merlon_h * 0.35)
	var from_p: Vector3
	var to_p: Vector3
	if axis == 0:
		from_p = Vector3(edge, 0.0, a.position.z)
		to_p = Vector3(edge, 0.0, a.position.z + a.size.z)
	else:
		from_p = Vector3(a.position.x, 0.0, edge)
		to_p = Vector3(a.position.x + a.size.x, 0.0, edge)
	_crenellate(from_p, to_p, a.size.y + CastleGeometry.PARAPET_RISE,
		spec.merlon_h * 0.7, SURF_TRIM)


## Arrow slits down the outer face of a wall run. The face is battered, so the
## slit has to follow it: placed on the base plane instead, every one of them
## would hang in the air a metre outside a wall that had already stepped in.
func _wall_slits(a: AABB, outward: Vector3, top_thick: float, r: int) -> void:
	var axis: int = 0 if absf(outward.x) > 0.5 else 2
	var base_thick: float = a.size.x if axis == 0 else a.size.z
	var inner: float = a.position[axis] if outward[axis] > 0.0 \
		else a.position[axis] + base_thick
	var y: float = a.size.y * 0.62
	var th: float = lerpf(base_thick, top_thick, y / a.size.y)
	var face: float = inner + outward[axis] * (th + CastleGeometry.OPENING_EPS)
	var run: float = a.size.z if axis == 0 else a.size.x
	var n: int = clampi(int(run / SLIT_BAY), 1, 24)
	var ang: float = atan2(outward.x, outward.z)
	for i in range(n):
		var f: float = (float(i) + 1.0) / (float(n) + 1.0)
		var p: Vector3
		if axis == 0:
			p = Vector3(face, y, lerpf(a.position.z, a.position.z + a.size.z, f))
		else:
			p = Vector3(lerpf(a.position.x, a.position.x + a.size.x, f), y, face)
		_opening(p, ang, 0.32, 1.5, &"slit")


## One castle tower: a battered shaft, its cap, its parapet and its slits. The
## shape (round, square, polygonal) is a segment count on the same primitive.
## `vertex` is the tower's index on its ring, so the great tower (CAS-002)
## is built at its own size; -1 for a side or gate tower.
func _tower(c: Vector3, r: int, mass_name: String, outward: Vector3,
		vertex := -1) -> void:
	var sides: int = CastleGeometry.tower_sides(spec)
	var rot: float = CastleGeometry.tower_rotation(spec)
	var h: float = CastleGeometry.tower_height_at(spec, r, vertex)
	var top_r: float = CastleGeometry.tower_radius_for(spec,
		CastleGeometry.tower_half_at(spec, r, vertex))
	var base_r: float = CastleGeometry.tower_radius_for(spec,
		CastleGeometry.tower_base_half_at(spec, r, vertex))
	_kit.drum(c, base_r, top_r, h, SURF_STONE, sides, rot)
	_log_mass(mass_name, CastleGeometry.tower_aabb(spec, r, c, vertex))
	_log_part("tower", c + Vector3(0, h / 2.0, 0), Vector3(top_r * 2.0, h, top_r * 2.0))

	var rise: float = CastleGeometry.tower_roof_rise_at(spec, r, vertex)
	match spec.tower_roof:
		&"cone":
			_kit.cone(top_r * 1.08, rise, c + Vector3(0, h, 0), SURF_ROOF, sides)
		&"pyramid":
			_kit.stepped_taper(c + Vector3(0, h, 0), top_r * 2.1, rise, SURF_ROOF, 3, 0.2)
		&"tiered":
			_kit.tiered_taper(c + Vector3(0, h, 0), top_r * 2.0, rise, SURF_ROOF, 2, 0.15)
		_:
			if spec.battlements:
				_crenellate_ring(c, top_r, h, sides, SURF_TRIM)
			else:
				_kit.drum(c + Vector3(0, h, 0), top_r * 1.12, top_r * 1.12,
					CastleGeometry.PARAPET_RISE, SURF_TRIM, sides, rot)
	total_height = maxf(total_height, h + rise)

	# Slits on the faces that look OUT of the castle, and on the shell rather
	# than on the bounding box: a tower's other faces are buried in the curtain
	# it studs, so a slit there is a window into three metres of masonry.
	var y: float = h * 0.6
	var face_r: float = lerpf(base_r, top_r, y / h) * cos(PI / float(sides))
	var out_ang: float = atan2(outward.x, outward.z)
	for k in range(3):
		var ang: float = out_ang + (float(k) - 1.0) * 0.6
		_opening(c + Vector3(sin(ang) * (face_r + CastleGeometry.OPENING_EPS), y,
			cos(ang) * (face_r + CastleGeometry.OPENING_EPS)), ang, 0.32, 1.4, &"slit")


## Merlons along a run, at `y`, each `thick` deep across the parapet.
func _crenellate(from_p: Vector3, to_p: Vector3, y: float, thick: float,
		surf: int) -> void:
	var seg: Vector3 = to_p - from_p
	var run: float = seg.length()
	var pitch: float = CastleGeometry.MERLON_W + CastleGeometry.MERLON_GAP
	var n: int = int(run / pitch)
	if n <= 0:
		return
	var dir: Vector3 = seg / run
	var along_x: bool = absf(dir.x) > 0.5
	for i in range(n):
		var p: Vector3 = from_p + dir * (pitch * (float(i) + 0.5))
		var size := Vector3(CastleGeometry.MERLON_W if along_x else thick,
			spec.merlon_h, thick if along_x else CastleGeometry.MERLON_W)
		box(size, Vector3(p.x, y + spec.merlon_h / 2.0, p.z), surf)


## Merlons along a run that does not lie on an axis: same pitch, but each
## merlon is turned to sit square on the parapet it stands on.
func _crenellate_run(from_p: Vector3, to_p: Vector3, y: float, thick: float,
		yaw: float, surf: int) -> void:
	var seg: Vector3 = to_p - from_p
	var run: float = seg.length()
	var pitch: float = CastleGeometry.MERLON_W + CastleGeometry.MERLON_GAP
	var n: int = int(run / pitch)
	if n <= 0:
		return
	var dir: Vector3 = seg / run
	for i in range(n):
		var p: Vector3 = from_p + dir * (pitch * (float(i) + 0.5))
		box(Vector3(CastleGeometry.MERLON_W, spec.merlon_h, thick),
			Vector3(p.x, y + spec.merlon_h / 2.0, p.z), surf, yaw)


## Merlons round the top of a block, on all four sides.
func _crenellate_rect(a: AABB, y: float, surf: int) -> void:
	if not spec.battlements:
		return
	var inset := 0.25
	var x0: float = a.position.x + inset
	var x1: float = a.position.x + a.size.x - inset
	var z0: float = a.position.z + inset
	var z1: float = a.position.z + a.size.z - inset
	var t: float = 0.35
	_crenellate(Vector3(x0, 0, z0), Vector3(x1, 0, z0), y, t, surf)
	_crenellate(Vector3(x0, 0, z1), Vector3(x1, 0, z1), y, t, surf)
	_crenellate(Vector3(x0, 0, z0), Vector3(x0, 0, z1), y, t, surf)
	_crenellate(Vector3(x1, 0, z0), Vector3(x1, 0, z1), y, t, surf)


## Merlons round a tower's parapet, one to each face of the shell.
func _crenellate_ring(c: Vector3, radius: float, y: float, sides: int,
		surf: int) -> void:
	var n: int = maxi(sides, 6)
	for i in range(n):
		var ang: float = TAU * float(i) / n
		var p: Vector3 = c + Vector3(cos(ang) * radius, 0.0, sin(ang) * radius)
		box(Vector3(CastleGeometry.MERLON_W, spec.merlon_h, CastleGeometry.MERLON_W),
			Vector3(p.x, y + spec.merlon_h / 2.0, p.z), surf, -ang)


## An AABB emitted as a box, which is how nearly every castle mass is drawn.
func _box_aabb(a: AABB, surf: int) -> void:
	box(a.size, a.position + a.size / 2.0, surf)


# ---------------------------------------------------------------- openings

## Dark recessed opening facing local +Z, rotated by `face` around Y.
##
## Same contract as the church's window(): `pos` is ON the wall face and the
## recess is pushed half its depth into the masonry, so the opening reads as cut
## into the stone rather than glued onto it. `facing` is logged because an AABB
## cannot tell a window from a window turned sideways -- the normals suite
## proves each one looks out of its wall.
func _opening(pos: Vector3, face: float, w: float, h: float, style: StringName,
		door := false) -> void:
	_log_part("window", pos, Vector3(w, h, 0.0), face,
		Basis(Vector3.UP, face) * Vector3(0, 0, 1))
	var depth: float = 0.24 if door else 0.14
	var t := Transform3D(Basis(Vector3.UP, face), pos)
	var t_in: Transform3D = t.translated_local(Vector3(0, 0, -depth / 2.0))
	_kit.oriented_box(Vector3(w, h, depth), t_in, SURF_OPEN)
	var st: SurfaceTool = _kit.surface(SURF_OPEN)
	var face_n: Vector3 = t.basis * Vector3(0, 0, 1)
	if style == &"arched":
		var seg: int = 5
		var rr: float = w * 0.5
		for i in range(seg):
			var a0: float = TAU / seg * i
			var a1: float = TAU / seg * (i + 1)
			var c := Vector3(0, h / 2.0, 0)
			var p0 := Vector3(cos(a0) * rr, h / 2.0 + sin(a0) * rr * 0.6, 0)
			var p1 := Vector3(cos(a1) * rr, h / 2.0 + sin(a1) * rr * 0.6, 0)
			for p in [c, p1, p0]:
				st.set_normal(face_n)
				st.set_uv(Vector2(0.5, 0.5))
				st.add_vertex(t * p)
	if style == &"mullioned":
		# the stone bar that divides a manor window into lights
		_kit.oriented_box(Vector3(0.12, h, depth + 0.04), t_in, SURF_TRIM)
	if door:
		return
	var ft: float = 0.12
	_kit.oriented_box(Vector3(w + ft * 2.0, ft, depth + 0.04),
		t_in.translated_local(Vector3(0, h / 2.0 + ft / 2.0, 0)), SURF_TRIM)
	_kit.oriented_box(Vector3(ft, h, depth + 0.04),
		t_in.translated_local(Vector3(-w / 2.0 - ft / 2.0, 0, 0)), SURF_TRIM)
	_kit.oriented_box(Vector3(ft, h, depth + 0.04),
		t_in.translated_local(Vector3(w / 2.0 + ft / 2.0, 0, 0)), SURF_TRIM)


## Which way a named wall run faces.
static func _wall_outward(which: StringName) -> Vector3:
	match which:
		&"back":
			return Vector3(0, 0, 1)
		&"left":
			return Vector3(-1, 0, 0)
		&"right":
			return Vector3(1, 0, 0)
	return Vector3(0, 0, -1)

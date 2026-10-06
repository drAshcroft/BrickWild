class_name HotelBuilder
extends HouseBuilder
## The walkable house shell with a palatial, bilaterally symmetric facade and
## a steep mansard-like roofline layered on before the mesh is committed.

const WINDOW_W := 0.92
const WINDOW_H := 1.5
const FRAME := 0.13
const FACADE_D := 0.12

## How far down the slope a dormer front face sits, as a fraction of the roof
## half span. Low enough to read as an attic window from the road, far enough
## from the eave that the slope behind it can still rise to meet the rooflet.
const DORMER_SET_DOWN := 0.62
## The dormer opening, and the body that stands in it.
const DORMER_W := 1.15
## The arched ceremonial entrance opening.
const ENTRANCE_W := 3.8


func build(p_plan: HousePlan, with_roof := true) -> ArrayMesh:
	plan = p_plan
	spec = p_plan.spec
	begin(4)
	total_height = HotelGeometry.wall_top(spec as HotelSpec)
	_build_floor()
	_build_exterior_walls()
	_build_partitions()
	_build_facade()
	if with_roof:
		_build_palace_roof()
		# the guest floor under the mansard has a ceiling, like a house's top
		# storey (WALK-QA, 6 Oct). `roof_enabled` stays false: HouseQA reads
		# it as "this is a house roof" and the mansard is not one.
		_build_ceiling(true, true)
	# The planner lays rugs and hearth breasts for a hotel exactly as for a
	# house (LAY-010), so the builder must emit the same structure.
	_build_hearth_breast()
	_build_rugs()
	return commit()


func _build_facade() -> void:
	var hs := spec as HotelSpec
	var z := HotelGeometry.front_z(hs)
	var top := HotelGeometry.wall_top(hs)
	var centre_w := HotelGeometry.centre_width(hs)
	# Everything below is SEATED on the wall it dresses (_face_box), on all
	# four walls. It used to be centred on front_z, 0.28 m proud of the wall,
	# and only on the front: the dressing floated with daylight behind it and
	# the long side and back walls were bare pink slabs (WALK-QA, 6 Oct,
	# hotel pins 4, 5 and 6).
	_build_courses(hs)
	_build_quoins(hs)
	_build_hoods(hs)
	_build_pilasters(hs)
	_build_entrance(HotelGeometry.wall_face_z(hs), centre_w)
	_build_balconies(hs)
	_build_centre_crown(z, top, centre_w)


## How far facade dressing is sunk into its wall, so that its back face is
## buried in the masonry instead of lying in the wall's own plane.
const EMBED := 0.03
## String courses: height and projection.
const COURSE_H := 0.22
const COURSE_D := 0.34
## Corner rustication: the pier, and the blocks laid over it.
const QUOIN_PIER := 0.30
const QUOIN_PROUD := 0.10
const QUOIN_BLOCK_PROUD := 0.16
const QUOIN_PITCH := 0.6
const QUOIN_BLOCK_H := 0.46
## Pilaster strips on the cell divisions.
const PILASTER_W := 0.36
const PILASTER_D := 0.10
## Window hoods: how far past the opening each end runs, and their projection.
const HOOD_OVER := 0.19
const HOOD_D := 0.30


## The four outside faces of the shell: the left end of the face, the
## direction along it, the outward normal and its length. The shell's outer
## faces are the site rectangle's edges.
func _faces(hs: HotelSpec) -> Array[Dictionary]:
	var hw := hs.width * 0.5
	var hl := hs.length * 0.5
	return [
		{"side": &"front", "o": Vector2(-hw, -hl), "dir": Vector2(1, 0), "n": Vector2(0, -1), "len": hs.width},
		{"side": &"back", "o": Vector2(-hw, hl), "dir": Vector2(1, 0), "n": Vector2(0, 1), "len": hs.width},
		{"side": &"left", "o": Vector2(-hw, -hl), "dir": Vector2(0, 1), "n": Vector2(-1, 0), "len": hs.length},
		{"side": &"right", "o": Vector2(hw, -hl), "dir": Vector2(0, 1), "n": Vector2(1, 0), "len": hs.length},
	]


## A box laid against a face: `t` along it, `along` long, `y` its centre
## height, standing `depth` out of the wall with EMBED of that buried. Logged
## as a named component AND as a part, so exterior QA sees it and the landmark
## counts (which read part tags) still do.
func _face_box(face: Dictionary, role: String, t: float, along: float, y: float,
		h: float, depth: float) -> void:
	var dir: Vector2 = face["dir"]
	var n: Vector2 = face["n"]
	var c: Vector2 = Vector2(face["o"]) + dir * t + n * (depth * 0.5 - EMBED)
	var yaw := atan2(-dir.y, dir.x)
	var size := Vector3(along, h, depth)
	component_box(role, size, Transform3D(Basis(Vector3.UP, yaw), Vector3(c.x, y, c.y)), SURF_TRIM)
	_log_part("box", Vector3(c.x, y, c.y), size, yaw)


## Every opening cut in one face, as {t, w, y0, y1} in world heights, with the
## width its dressing takes (frame and hood) folded in.
func _face_openings(face: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var n: Vector2 = face["n"]
	var dir: Vector2 = face["dir"]
	var records: Array = []
	for w in plan.windows:
		records.append([w, float(w["width"]) + HOOD_OVER * 2.0, float(w["sill"]),
			float(w["head"]) + 0.3])
	for d in plan.doors:
		if not d["exterior"]:
			continue
		var dw: float = ENTRANCE_W if bool(d.get("front", false)) else float(d["width"]) + 0.2
		records.append([d, dw, float(d.get("sill", 0.0)),
			float(d.get("head", HouseGeometry.DOOR_H)) + 0.1])
	for r in records:
		var rec: Dictionary = r[0]
		if Vector2(rec["normal"]).dot(n) < 0.9:
			continue
		var level := HousePlan.record_storey(rec)
		var pos: Vector2 = rec["pos"]
		out.append({"t": (pos - Vector2(face["o"])).dot(dir), "w": float(r[1]),
			"y0": level * spec.height + float(r[2]), "y1": level * spec.height + float(r[3])})
	return out


## The heights of the string courses: an ankle-height base course, one at
## every floor line and one at the wall head.
func _course_heights(hs: HotelSpec) -> Array[float]:
	var out: Array[float] = []
	for level in range(hs.storeys + 1):
		out.append(0.25 if level == 0 else float(level) * hs.height - 0.12)
	return out


## Horizontal string courses round all four walls, stopping either side of any
## opening they would cross (the base course must not trip a doorway). Front
## and back run through the corners; the sides stop against them, so no two
## course faces share a plane.
func _build_courses(hs: HotelSpec) -> void:
	tag("cornice")
	for face in _faces(hs):
		var through: bool = face["side"] in [&"front", &"back"]
		var t0: float = -(COURSE_D - EMBED) if through else EMBED
		var t1: float = float(face["len"]) - t0
		var openings := _face_openings(face)
		host("course_%s" % String(face["side"]))
		for y in _course_heights(hs):
			var gaps: Array = []
			for op in openings:
				if float(op["y1"]) > y - COURSE_H * 0.5 and float(op["y0"]) < y + COURSE_H * 0.5:
					gaps.append([float(op["t"]) - float(op["w"]) * 0.5,
						float(op["t"]) + float(op["w"]) * 0.5])
			gaps.sort_custom(func(a, b): return a[0] < b[0])
			gaps.append([t1, t1])
			var cursor := t0
			for g in gaps:
				var lo: float = minf(g[0], t1)
				if lo - cursor > 0.05:
					_face_box(face, "string_course", (cursor + lo) * 0.5, lo - cursor,
						y, COURSE_H, COURSE_D)
				cursor = maxf(cursor, g[1])
		host_end()


## Rusticated quoins at all four corners: a pier wrapping the corner and
## alternating long and short blocks over it, kept clear of the openings and
## of the string courses.
func _build_quoins(hs: HotelSpec) -> void:
	tag("pilaster")
	var top := HotelGeometry.wall_top(hs)
	var courses := _course_heights(hs)
	for face in _faces(hs):
		var through: bool = face["side"] in [&"front", &"back"]
		var openings := _face_openings(face)
		var length: float = face["len"]
		host("quoin_%s" % String(face["side"]))
		for end in [0, 1]:
			# the clear run from this corner to the first opening
			var clear := 1.2
			for op in openings:
				var edge: float = float(op["t"]) - float(op["w"]) * 0.5
				if end == 1:
					edge = length - float(op["t"]) - float(op["w"]) * 0.5
				clear = minf(clear, edge - 0.08)
			if clear < QUOIN_PIER:
				continue
			# Front and back own the corner itself; the side pieces start
			# behind them so the two never share a face.
			var start: float = -QUOIN_PROUD if through else EMBED
			var pier_len: float = QUOIN_PIER - start
			var pier_t: float = start + pier_len * 0.5
			# stops short of the wall head, so its top is not the wall's plane
			_face_box(face, "quoin_pier", pier_t if end == 0 else length - pier_t, pier_len,
				(top - 0.05) * 0.5, top - 0.05, QUOIN_PROUD + EMBED)
			var k := 0
			var y0 := 0.40
			while y0 + QUOIN_BLOCK_H < top - 0.3:
				var y1 := y0 + QUOIN_BLOCK_H
				var crossing := false
				for cy in courses:
					if y1 > cy - COURSE_H * 0.5 - 0.02 and y0 < cy + COURSE_H * 0.5 + 0.02:
						crossing = true
				if not crossing:
					var long: bool = (k % 2 == 0) == through
					var reach: float = minf(clear, 0.72 if long else 0.42)
					var bstart: float = -QUOIN_BLOCK_PROUD if through else EMBED
					var blen: float = reach - bstart
					var bt: float = bstart + blen * 0.5
					_face_box(face, "quoin_block", bt if end == 0 else length - bt, blen,
						(y0 + y1) * 0.5, QUOIN_BLOCK_H, QUOIN_BLOCK_PROUD + EMBED)
				k += 1
				y0 += QUOIN_PITCH
		host_end()


## A hood over every window on every wall, from the SAME plan.windows the shell
## cut -- never a second painted grid.
func _build_hoods(hs: HotelSpec) -> void:
	tag("facade_hood")
	for face in _faces(hs):
		var n: Vector2 = face["n"]
		for i in range(plan.windows.size()):
			var w: Dictionary = plan.windows[i]
			if Vector2(w["normal"]).dot(n) < 0.9:
				continue
			var level := HousePlan.record_storey(w)
			var t: float = (Vector2(w["pos"]) - Vector2(face["o"])).dot(face["dir"])
			host("hotel_window_%d" % i, level)
			_face_box(face, "facade_hood", t, float(w["width"]) + HOOD_OVER * 2.0,
				level * hs.height + float(w["head"]) + 0.22, 0.12, HOOD_D)
			host_end()


## Pilaster strips on the cell divisions -- where the partitions meet the
## outside wall -- wherever one stands clear of every opening and hood on its
## wall, so the long elevations read in bays rather than as one slab. A strip
## that would cross a window is not laid at all (the old bay grid did cross
## them).
func _build_pilasters(hs: HotelSpec) -> void:
	tag("pilaster")
	var top := HotelGeometry.wall_top(hs)
	var inner := HouseGeometry.interior_rect(hs)
	for face in _faces(hs):
		var along_x: bool = absf(Vector2(face["dir"]).x) > 0.5
		var lo: float = inner.position.x if along_x else inner.position.y
		var hi: float = inner.end.x if along_x else inner.end.y
		var lines := {}
		for room in plan.rooms:
			var r: Rect2 = room["rect"]
			for v in ([r.position.x, r.end.x] if along_x else [r.position.y, r.end.y]):
				if v > lo + 0.5 and v < hi - 0.5:
					lines[snappedf(v, 0.001)] = true
		var openings := _face_openings(face)
		var origin: float = Vector2(face["o"]).x if along_x else Vector2(face["o"]).y
		host("pilasters_%s" % String(face["side"]))
		for v in lines.keys():
			var t: float = float(v) - origin
			var clear := true
			for op in openings:
				if absf(t - float(op["t"])) < float(op["w"]) * 0.5 + PILASTER_W * 0.5 + 0.05:
					clear = false
			if face["side"] == &"front":
				for b in _balconies():
					if absf(float(v) - b.x) < b.y * 0.5 + PILASTER_W:
						clear = false
				if absf(float(v)) < ENTRANCE_W:
					clear = false
			if not clear:
				continue
			_face_box(face, "pilaster", t, PILASTER_W, (0.30 + top - 0.12) * 0.5,
				top - 0.42, PILASTER_D + EMBED)
		host_end()


## Half the width of the ceremonial entrance void, which the planned front
## door (1.8 m) sits in the middle of.
func _entrance_half_width() -> float:
	return ENTRANCE_W * 0.5


func _window(pos: Vector3, ground := false) -> void:
	var h := WINDOW_H * (1.12 if ground else 1.0)
	# Blind lights belong only to the unoccupied roof crown and cupolas.
	# Habitable storeys must use the actual apertures above.
	tag("crown_window")
	_glazing_box("crown_glazing", Vector3(WINDOW_W, h, FACADE_D),
		Transform3D(Basis(), pos))
	box(Vector3(WINDOW_W + FRAME * 2.0, FRAME, FACADE_D * 1.8),
		pos + Vector3(0, h * 0.5 + FRAME * 0.5, -0.02), SURF_TRIM)
	box(Vector3(WINDOW_W + FRAME * 2.0, FRAME, FACADE_D * 1.8),
		pos - Vector3(0, h * 0.5 + FRAME * 0.5, 0.02), SURF_TRIM)
	for side in [-1.0, 1.0]:
		box(Vector3(FRAME, h + FRAME * 2.0, FACADE_D * 1.8),
			pos + Vector3(side * (WINDOW_W + FRAME) * 0.5, 0, -0.02), SURF_TRIM)
	# A mullion and hood turn the rectangles into the tall paired windows in
	# the reference without pretending they are holes in the wall.
	box(Vector3(0.08, h, FACADE_D * 2.0), pos + Vector3(0, 0, -0.03), SURF_TRIM)
	box(Vector3(WINDOW_W + 0.38, 0.12, 0.3),
		pos + Vector3(0, h * 0.5 + 0.22, 0), SURF_TRIM)


## `z` is the front wall's face: every piece is seated on it.
func _build_entrance(z: float, centre_w: float) -> void:
	tag("ceremonial_entrance")
	var door_w := 1.8
	var door_h := minf(2.65, spec.height - 0.45)
	for side in [-1.0, 1.0]:
		box(Vector3(0.32, door_h, 0.42),
			Vector3(side * (door_w * 0.5 + 0.3), door_h * 0.5, z - 0.21 + EMBED),
			SURF_TRIM)
		# The plinth steps out on the street and outer sides only. Its door
		# side stops 1 cm inside the pier's (one plane would fight): stepped
		# 5 cm towards the opening, it showed past the end of the reveal as a
		# stub in the doorway (WALK-QA, 6 Oct, hotel pin 7).
		box(Vector3(0.36, 0.18, 0.54),
			Vector3(side * (door_w * 0.5 + 0.33), 0.09, z - 0.27 + EMBED), SURF_TRIM)
	_kit.arc_ribbon(Vector3(-door_w * 0.5, door_h + 0.05, z - 0.125 + EMBED),
		Vector3(door_w * 0.5, door_h + 0.05, z - 0.125 + EMBED), 0.25, 0.14, 0.25,
		SURF_TRIM, 10)
	var canopy_w := minf(centre_w * 0.78, 11.0)
	var canopy_y := spec.height - 0.38
	box(Vector3(canopy_w, 0.24, 1.35), Vector3(0, canopy_y, z - 0.675 + EMBED), SURF_TRIM)
	# The hotel's name board is the canopy's fascia. It used to be a plaque on
	# the wall between the floors, which is where the balcony doors now are.
	box(Vector3(canopy_w * 0.7, 0.34, 0.08),
		Vector3(0, canopy_y, z - 1.35 + EMBED - 0.03), SURF_WALL)


## A balcony is BALCONY_W wide, centred on its french window.
const BALCONY_W := 2.3
const BALCONY_D := 1.05


## Every balcony, as (centre x, width, storey): one per `balcony_x` the
## planner gave its french windows, wide enough to stand before all of them.
func _balconies() -> Array[Vector3]:
	var spans := {}
	for w in plan.windows:
		if not bool(w.get("balcony", false)):
			continue
		var key: float = snappedf(float(w.get("balcony_x", Vector2(w["pos"]).x)), 0.001)
		var reach: float = absf(Vector2(w["pos"]).x - key)
		var was: Vector2 = spans.get(key, Vector2(0.0, HousePlan.record_storey(w)))
		spans[key] = Vector2(maxf(was.x, reach), was.y)
	var out: Array[Vector3] = []
	for key in spans:
		out.append(Vector3(key, spans[key].x * 2.0 + BALCONY_W, spans[key].y))
	return out


## The balconies stand at the floor of the storey they serve, in front of the
## french window the planner opened for each (HotelPlanner._open_balconies):
## a balcony with no door behind it, at sill height and off the window grid,
## is what the walk-through found (WALK-QA, 6 Oct, hotel pins 2 and 3).
func _build_balconies(hs: HotelSpec) -> void:
	var z := HotelGeometry.wall_face_z(hs)
	for b in _balconies():
		tag("balcony")
		var x: float = b.x
		var width: float = b.y
		var top := b.z * hs.height + HouseGeometry.FLOOR_T
		var slab_t := 0.18
		var front := z - BALCONY_D + EMBED
		box(Vector3(width, slab_t, BALCONY_D),
			Vector3(x, top - slab_t * 0.5, z - BALCONY_D * 0.5 + EMBED), SURF_TRIM)
		var half := width * 0.5 - 0.08
		var posts := maxi(7, int(half * 2.0 / 0.33) + 1)
		for post in range(posts):
			var px: float = x - half + post * (half * 2.0 / float(posts - 1))
			# up into the rail, so the balusters carry it
			box(Vector3(0.08, 0.75, 0.08), Vector3(px, top + 0.375, front + 0.08), SURF_TRIM)
		box(Vector3(width - 0.1, 0.09, 0.1), Vector3(x, top + 0.78, front + 0.08), SURF_TRIM)
		# The two ends, from the front rail back into the wall, so the balcony
		# is closed on three sides. They abut the front rail rather than overlap
		# it: the two tops are one plane.
		var end_from := front + 0.13
		var end_to := z + EMBED
		# Each end carries balusters at the front's pitch. A bare rail running
		# back to the wall, with nothing under it, read from the street as a
		# diagonal stub poking past the balcony (WALK-QA, 6 Oct, hotel pin 2).
		var pitch: float = half * 2.0 / float(posts - 1)
		var end_posts := maxi(1, int((end_to - 0.06 - (front + 0.08)) / pitch))
		for side in [-1.0, 1.0]:
			box(Vector3(0.08, 0.09, end_to - end_from),
				Vector3(x + side * half, top + 0.78, (end_from + end_to) * 0.5), SURF_TRIM)
			for k in range(1, end_posts + 1):
				# 7 cm, not the rail's 8: their sides would share its planes
				box(Vector3(0.07, 0.75, 0.08),
					Vector3(x + side * half, top + 0.375, front + 0.08 + k * pitch), SURF_TRIM)


func _build_centre_crown(z: float, top: float, centre_w: float) -> void:
	tag("centre_pavilion")
	var crown_h := 1.45
	box(Vector3(centre_w, crown_h, 0.72),
		Vector3(0, top + crown_h * 0.5, z + 0.12), SURF_WALL)
	_log_mass("wall_centre_pavilion", AABB(
		Vector3(-centre_w * 0.5, top, z - 0.24), Vector3(centre_w, crown_h, 0.72)))
	for x in [-centre_w * 0.5, 0.0, centre_w * 0.5]:
		box(Vector3(0.36, crown_h + 0.2, 0.5),
			Vector3(x, top + crown_h * 0.5, z - 0.18), SURF_TRIM)
	_window(Vector3(0, top + crown_h * 0.55, z - 0.28))
	_kit.gable_end(centre_w * 0.28, 1.5, top + crown_h, z - 0.28,
		0.28, SURF_WALL)
	total_height = maxf(total_height, top + crown_h + 1.5)


func _build_palace_roof() -> void:
	var hs := spec as HotelSpec
	var top := HotelGeometry.wall_top(hs)
	tag("mansard_roof")
	# Ridge along X: the dark steep slope is the dominant face seen from the
	# road, as it is in the reference elevation. The roof is turned a quarter
	# turn to get there, so the roof local X runs across the hotel LENGTH and
	# its local Z along the hotel WIDTH. Every dormer number below is in that
	# frame, not in the hotel one.
	var layout := HotelGeometry.roof_layout(hs)
	var xf: Transform3D = layout["transform"]
	var roof: Array[PackedVector3Array] = layout["faces"]
	var dormers := _hotel_dormer_seats(hs, roof)
	# ridge_roof still closes the four wall heads against the actual roof
	# underside; that part has no dormers in it. Its slopes are deferred so the
	# dormer openings can be cut out of them first: a dormer with no hole
	# behind it is a box with the host roof running through its glazing.
	var deferred: Array[PackedVector3Array] = []
	_kit.ridge_roof(xf, hs.length + 1.0, hs.width + 1.0, hs.roof_rise,
		SURF_ROOF, SURF_WALL, hs.length, hs.width, 0.3, 0.0, deferred)
	for fi in range(roof.size()):
		var pieces: Array[PackedVector2Array] = [RoofShape.footprint(roof[fi])]
		for d in dormers:
			if int(d["face"]) != fi:
				continue
			var next: Array[PackedVector2Array] = []
			for piece in pieces:
				next.append_array(RoofShape.subtract(piece, d["opening"]))
			pieces = next
		for piece in pieces:
			_kit.slab_poly(xf * RoofShape.lift(piece, roof[fi]),
				RoofShape.DEPTH, SURF_ROOF, true)
	_log_mass("roof", AABB(
		Vector3(-hs.width * 0.5 - 0.5, top, -hs.length * 0.5 - 0.5),
		Vector3(hs.width + 1.0, hs.roof_rise + 4.0, hs.length + 1.0)))
	_build_hotel_dormers(xf, dormers)
	if hs.cupolas:
		_build_cupola(-HotelGeometry.tower_x(hs), top, hs)
		_build_cupola(HotelGeometry.tower_x(hs), top, hs)
	total_height = maxf(total_height, HotelGeometry.total_height(hs))


## Where the hotel dormers sit, in the roof own frame.
##
## The old version put each box at a fixed z just outside the front wall and
## lifted it to 42 per cent of the rise -- two numbers with nothing to do with
## where the roof surface actually is. On a 48x24 palace that left every body
## between 0.78 m and 1.14 m in the air above its own slope (ROOF-AUDIT-001).
## The seat now comes from the roof: RoofShape.dormer_seat answers "at what
## local X is the host plane this high", and every coordinate below is one of
## its answers.
func _hotel_dormer_seats(hs: HotelSpec, roof: Array[PackedVector3Array]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if hs.dormer_count <= 0 or roof.is_empty():
		return out
	var half: float = (hs.length + 1.0) * 0.5
	# The dormers face the road, and the road is -Z. The roof quarter turn maps
	# its +X to the hotel -Z, so the road-facing slope is +X: the face
	# RoofShape.faces emits second.
	var seat := RoofShape.dormer_seat(half, hs.roof_rise,
		half * DORMER_SET_DOWN, DORMER_W)
	if not bool(seat["fits"]):
		return out
	var face_index := 1 if roof.size() > 1 else 0
	var host: PackedVector2Array = RoofShape.footprint(roof[face_index])
	var front: float = seat["front"]
	var rh: float = seat["roof_half"]
	var hw: float = DORMER_W * 0.5
	var out_dir: float = signf(front)
	var run: float = hs.width * 0.76
	var cupola_r: float = HotelGeometry.cupola_radius(hs) + 0.4
	var tower_x: float = HotelGeometry.tower_x(hs)
	for i in range(hs.dormer_count):
		# The dormers march along the ridge, which is the roof local Z and the
		# hotel world X.
		var z := -run * 0.5 + run * (float(i) + 0.5) / float(hs.dormer_count)
		if absf(z) < HotelGeometry.centre_width(hs) * 0.25:
			continue      # the centre crown stands here
		if hs.cupolas and absf(absf(z) - tower_x) < cupola_r + hw:
			continue      # and a cupola here
		var cover := PackedVector2Array([
			Vector2(front + out_dir * 0.12, z - rh),
			Vector2(seat["side_x"], z - rh), Vector2(seat["peak_x"], z),
			Vector2(seat["side_x"], z + rh), Vector2(front + out_dir * 0.12, z + rh)])
		var valid := true
		for p in cover:
			if not Poly.contains_point(host, p):
				valid = false
			for j in range(host.size()):
				var edge: Vector2 = host[(j + 1) % host.size()] - host[j]
				if absf(edge.cross(p - host[j])) / edge.length() < 0.12:
					valid = false
		if not valid:
			continue
		var row := seat.duplicate()
		row["id"] = "dormer_%d" % i
		row["face"] = face_index
		row["z"] = z
		row["out"] = out_dir
		row["opening"] = PackedVector2Array([
			Vector2(front, z - hw), Vector2(seat["cheek_x"], z - hw),
			Vector2(seat["peak_x"], z), Vector2(seat["cheek_x"], z + hw),
			Vector2(front, z + hw)])
		out.append(row)
	return out


## The hotel dormers: a long even row across a mansard, which is not the same
## piece of architecture as HouseBuilder._build_dormers -- that one sets them
## on one pitch of a cottage roof. The SEAT is shared; only the carpentry here
## differs.
func _build_hotel_dormers(xf: Transform3D, dormers: Array[Dictionary]) -> void:
	for d in dormers:
		tag("dormer")
		host(String(d["id"]), maxi(spec.storeys, 1) - 1)
		var first := component_log.size()
		var z: float = d["z"]
		var front: float = d["front"]
		var out_dir: float = d["out"]
		var base: float = float(d["base"]) - RoofShape.DEPTH * 0.5
		var eave: float = d["eave"]
		var peak: float = d["peak"]
		var rh: float = d["roof_half"]
		var hw: float = DORMER_W * 0.5
		var lift: float = peak - eave
		var side_top: float = eave + lift * (1.0 - hw / rh) - RoofShape.DEPTH * 0.5
		var head: float = eave - RoofShape.DEPTH * 0.5
		# Rooflet: ends on the valley where it meets the host plane, not in a
		# rectangle buried behind the slope.
		for side in [-1.0, 1.0]:
			_slab(xf, "dormer_roof", PackedVector3Array([
				Vector3(front + out_dir * 0.12, eave, z + side * rh),
				Vector3(d["side_x"], eave, z + side * rh),
				Vector3(d["peak_x"], peak, z),
				Vector3(front + out_dir * 0.12, peak, z)]),
				RoofShape.DEPTH, SURF_ROOF, true)
			# Cheeks taper to nothing at that same intersection.
			_slab(xf, "dormer_cheek", PackedVector3Array([
				Vector3(front, base, z + side * hw),
				Vector3(front, side_top, z + side * hw),
				Vector3(d["cheek_x"], side_top, z + side * hw)]),
				0.08, SURF_WALL, false)
		_slab(xf, "dormer_gable", PackedVector3Array([
			Vector3(front, head, z - hw), Vector3(front, head, z + hw),
			Vector3(front, side_top, z + hw),
			Vector3(front, peak - RoofShape.DEPTH * 0.5, z),
			Vector3(front, side_top, z - hw)]), 0.10, SURF_WALL, false)
		# The window in it, and the glazing the host roof must not run through.
		var win_bottom: float = base + 0.20
		var win_top: float = head - 0.13
		var win_w: float = DORMER_W * 0.65
		for side in [-1.0, 1.0]:
			component_box("dormer_jamb",
				Vector3(0.10, head - base, hw - win_w * 0.5),
				xf * Transform3D(Basis(), Vector3(front, (head + base) * 0.5,
					z + side * (hw + win_w * 0.5) * 0.5)), SURF_TRIM)
		for band in [[base, win_bottom], [win_top, head]]:
			component_box("dormer_panel", Vector3(0.10, band[1] - band[0], win_w),
				xf * Transform3D(Basis(), Vector3(front,
					(band[0] + band[1]) * 0.5, z)), SURF_TRIM)
		component_box("dormer_glazing", Vector3(0.04, win_top - win_bottom, win_w),
			xf * Transform3D(Basis(), Vector3(front + out_dir * 0.04,
				(win_top + win_bottom) * 0.5, z)), SURF_ROOF)
		# One part_log row per dormer BODY, measured from the pieces actually
		# emitted for it. The landmark rule counts dormers, and geometry that
		# only exists in the mesh is geometry QA cannot count -- which is how
		# seating the dormers correctly still managed to break that rule.
		#
		# The record is the BODY: cheeks and gable front, from the front face
		# back to where the cheeks die into the host. The rooflet overhangs and
		# must stay out of it, or the attachment probe -- which samples the
		# host under the body's REAR edge -- would sample past the join.
		#
		# kind is "box", not "dormer": tools/check_roofs.gd selects bodies with
		# `tag == "dormer" and kind == "box"`, and a record it cannot select is
		# a test that passes by measuring nothing.
		var bounds := AABB()
		var found := false
		for ci in range(first, component_log.size()):
			var role: String = component_log[ci]["role"]
			if role != "dormer_cheek" and role != "dormer_gable":
				continue
			var piece := MassBuilder.component_aabb(component_log[ci])
			bounds = piece if not found else bounds.merge(piece)
			found = true
		if found:
			_log_part("box", bounds.get_center(), bounds.size)
		host_end()


## A roof-local polygon slab, emitted and logged in world space.
func _slab(xf: Transform3D, role: String, local: PackedVector3Array,
		depth: float, surface: int, vertical: bool) -> void:
	var world := PackedVector3Array()
	for p in local:
		world.append(xf * p)
	component_slab(role, world, depth, surface, vertical)


func _build_cupola(x: float, top: float, hs: HotelSpec) -> void:
	var r := HotelGeometry.cupola_radius(hs)
	var z := HotelGeometry.front_z(hs) + 1.9
	tag("corner_tower")
	box(Vector3(r * 2.05, 2.4, r * 2.05),
		Vector3(x, top + 1.0, z), SURF_WALL)
	_log_mass("wall_cupola_tower", AABB(Vector3(x - r, top - 0.2, z - r),
		Vector3(r * 2.0, 2.6, r * 2.0)))
	for side in [-1.0, 1.0]:
		box(Vector3(0.2, 2.45, 0.26),
			Vector3(x + side * r * 0.82, top + 1.0, z - r - 0.1), SURF_TRIM)
	_window(Vector3(x, top + 1.0, z - r - 0.2))
	tag("cupola")
	var profile := PackedVector2Array([
		Vector2(r * 1.1, 0.0), Vector2(r * 1.12, 0.28),
		Vector2(r * 0.88, 1.15), Vector2(r * 0.42, 2.0), Vector2(0.0, 2.45)])
	_kit.revolve(profile, Vector3(x, top + 2.2, z), SURF_ROOF, 16, TAU)
	_kit.cone(0.16, 1.5, Vector3(x, top + 4.55, z), SURF_TRIM, 10)

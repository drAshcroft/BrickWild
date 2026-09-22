class_name TempleBuilder
extends MassBuilder
## TempleSpec -> ArrayMesh, plus a list of props to hang on it.
##
## The architecture is emitted as geometry, the way the churches and castles
## are: floor, walls, columns, dais, altar, idol, pit, roof. The dressing is a
## list of prop placements the assembler instantiates, the way a house's
## furniture is -- braziers down the processional way, chains in the cells,
## a knife and a chalice on the altar.
##
## Both go into the logs the checks read. mass_log is what the structural rules
## measure; prop_log is what the rite check reads to ask whether the place is
## lit and whether the cells hold anything.
##
## Surfaces: 0 = stone, 1 = trim (gold, bone, whatever the cult gilds), 2 =
## roof, 3 = the dark (pit throats, gate voids, eye sockets).

const SURF_STONE := 0
const SURF_TRIM := 1
const SURF_ROOF := 2
const SURF_DARK := 3

var spec: TempleSpec


func build(p_spec: TempleSpec) -> ArrayMesh:
	spec = p_spec
	begin(4)
	total_height = spec.height

	_build_floor()
	_build_walls()
	_build_columns()
	_build_dais()
	_build_altar()
	_build_idol()
	_build_pit()
	_build_cells()
	_build_roof()
	_build_outworks()
	_dress()
	return commit()


# ------------------------------------------------------------------ floor

func _build_floor() -> void:
	tag("floor")
	var t: float = TempleGeometry.FLOOR_T
	var plates: Array[Rect2] = TempleGeometry.floor_rects(spec)
	var i := 0
	for r in plates:
		box(Vector3(r.size.x, t, r.size.y),
			Vector3(r.get_center().x, -t / 2.0 + 0.001, r.get_center().y), SURF_STONE)
		_log_mass("floor" if i == 0 else "floor_%d" % i,
			AABB(Vector3(r.position.x, -t, r.position.y),
				Vector3(r.size.x, t, r.size.y)))
		i += 1


# ------------------------------------------------------------------ walls

## The outer walls, with the gate cut through the front one on the axis. A
## ziggurat has no walls of its own -- its terraces are its walls -- so it gets
## the doorway alone, at the foot of the great stair.
func _build_walls() -> void:
	tag("wall")
	var r: Rect2 = TempleGeometry.site_rect(spec)
	var t: float = spec.wall_t
	var h: float = spec.height
	if spec.form == &"ziggurat":
		_gate_void(r.position.y + TempleGeometry.terrace_inset(spec) / 2.0)
		return
	var runs := [
		{"name": "wall_back", "rect": Rect2(Vector2(r.position.x, r.end.y - t),
			Vector2(r.size.x, t))},
		{"name": "wall_left", "rect": Rect2(Vector2(r.position.x, r.position.y + t),
			Vector2(t, r.size.y - t * 2.0))},
		{"name": "wall_right", "rect": Rect2(Vector2(r.end.x - t, r.position.y + t),
			Vector2(t, r.size.y - t * 2.0))},
	]
	# the front wall, in two pieces either side of the gate
	var gate: float = TempleGeometry.GATE_W
	for side in [-1.0, 1.0]:
		var x0: float = r.position.x if side < 0.0 else gate / 2.0
		var w: float = (r.size.x - gate) / 2.0
		runs.append({"name": "wall_front_%s" % ("left" if side < 0.0 else "right"),
			"rect": Rect2(Vector2(x0, r.position.y), Vector2(w, t))})
	for run in runs:
		var rect: Rect2 = run["rect"]
		if rect.size.x <= 0.01 or rect.size.y <= 0.01:
			continue
		box(Vector3(rect.size.x, h, rect.size.y),
			Vector3(rect.get_center().x, h / 2.0, rect.get_center().y), SURF_STONE)
		_log_mass(String(run["name"]), AABB(Vector3(rect.position.x, 0.0, rect.position.y),
			Vector3(rect.size.x, h, rect.size.y)))
	# the lintel over the gate, and the dark of the opening
	var gh: float = minf(TempleGeometry.GATE_H, h - 0.6)
	box(Vector3(gate + t, h - gh, t), Vector3(0.0, gh + (h - gh) / 2.0,
		r.position.y + t / 2.0), SURF_STONE)
	_gate_void(r.position.y + t / 2.0)
	total_height = maxf(total_height, h)


## The gate: a jamb either side and a threshold under it, and nothing in
## between.
##
## It was a black slab at first, to read as a doorway from outside. That put an
## opaque panel across the one view the whole building is arranged to give you
## -- the rite check would still have said the god was visible, because the
## slab is not a structural mass, and the check would have been describing a
## temple nobody could see into.
func _gate_void(z: float) -> void:
	var gh: float = minf(TempleGeometry.GATE_H, spec.height - 0.6)
	var jamb: float = spec.wall_t * 0.35
	for side in [-1.0, 1.0]:
		box(Vector3(jamb, gh, spec.wall_t * 1.05),
			Vector3(side * (TempleGeometry.GATE_W / 2.0 + jamb / 2.0), gh / 2.0, z),
			SURF_TRIM)
	box(Vector3(TempleGeometry.GATE_W + jamb * 2.0, 0.12, spec.wall_t * 1.05),
		Vector3(0.0, 0.06, z), SURF_TRIM)
	_log_part("window", Vector3(0.0, gh / 2.0, z),
		Vector3(TempleGeometry.GATE_W, gh, 0.0), PI, Vector3(0, 0, -1))


# ---------------------------------------------------------------- columns

func _build_columns() -> void:
	if spec.columns.is_empty():
		return
	tag("column")
	var i := 0
	for column in spec.columns:
		var c: Vector3 = column["pos"]
		var r: float = float(column["radius"])
		var h: float = float(column["height"])
		# a shaft that tapers, on a plinth, under a capital: three boxes and a
		# revolve, which is all a column has ever been
		box(Vector3(r * 2.4, 0.22, r * 2.4), Vector3(c.x, 0.11, c.z), SURF_STONE)
		_kit.drum(Vector3(c.x, 0.22, c.z), r, r * 0.86, h - 0.22, SURF_STONE, 12)
		_kit.drum(Vector3(c.x, h, c.z), r * 1.25, r * 1.1,
			TempleGeometry.COLUMN_CAP * r, SURF_TRIM, 12)
		_log_mass("column_%d" % i, AABB(Vector3(c.x - r * 1.2, 0.0, c.z - r * 1.2),
			Vector3(r * 2.4, h + TempleGeometry.COLUMN_CAP * r, r * 2.4)))
		i += 1


# ------------------------------------------------------------------- dais

func _build_dais() -> void:
	tag("dais")
	var d: Rect2 = TempleGeometry.dais_rect(spec)
	var steps: int = maxi(spec.dais_steps, 1)
	var rise: float = TempleGeometry.DAIS_RISE
	var tread: float = TempleGeometry.DAIS_TREAD
	for i in range(steps):
		# each step is the one above it, grown by a tread on the three sides
		# the congregation can climb from
		var grow: float = float(steps - 1 - i) * tread
		var r: Rect2 = Rect2(d.position - Vector2(grow, grow),
			d.size + Vector2(grow * 2.0, grow))
		box(Vector3(r.size.x, rise * float(i + 1), r.size.y),
			Vector3(r.get_center().x, rise * float(i + 1) / 2.0, r.get_center().y),
			SURF_STONE)
	var foot: Rect2 = TempleGeometry.dais_footprint(spec)
	_log_mass("dais", AABB(Vector3(foot.position.x, 0.0, foot.position.y),
		Vector3(foot.size.x, spec.dais_height, foot.size.y)))


# ------------------------------------------------------------------ altar

func _build_altar() -> void:
	tag("altar")
	var c: Vector3 = TempleGeometry.altar_center(spec)
	var w: float = spec.altar_w
	var l: float = spec.altar_l
	var h: float = spec.altar_h
	# a block, a slab on top of it, and the channel cut round the slab that
	# tells you what the slab is for
	box(Vector3(w * 0.82, h - 0.12, l * 0.82), Vector3(c.x, c.y + (h - 0.12) / 2.0, c.z),
		SURF_STONE)
	box(Vector3(w, 0.12, l), Vector3(c.x, c.y + h - 0.06, c.z), SURF_TRIM)
	for side in [-1.0, 1.0]:
		box(Vector3(w * 1.02, 0.05, 0.06),
			Vector3(c.x, c.y + h - 0.02, c.z + side * (l / 2.0 - 0.05)), SURF_DARK)
	_log_mass("altar", AABB(Vector3(c.x - w / 2.0, 0.0, c.z - l / 2.0),
		Vector3(w, c.y + h, l)))


# ------------------------------------------------------------------- idol

## The god. Five shapes, one silhouette rule: it stands on the axis behind the
## altar and it is the tallest thing in the room.
func _build_idol() -> void:
	tag("idol")
	var c: Vector3 = TempleGeometry.idol_center(spec)
	var w: float = spec.idol_width
	var h: float = spec.idol_height
	match spec.idol_kind:
		&"monolith":
			# a leaning slab, unworked, older than the temple round it
			_kit.oriented_box(Vector3(w, h, w * 0.32),
				Transform3D(Basis(Vector3(0, 0, 1), 0.05), Vector3(c.x, c.y + h / 2.0, c.z)),
				SURF_STONE)
			box(Vector3(w * 1.3, 0.3, w * 0.7), Vector3(c.x, c.y + 0.15, c.z), SURF_TRIM)
		&"figure":
			# legs, body, arms, and a head too small for them
			var leg: float = h * 0.32
			for side in [-1.0, 1.0]:
				box(Vector3(w * 0.22, leg, w * 0.24),
					Vector3(c.x + side * w * 0.22, c.y + leg / 2.0, c.z), SURF_STONE)
			box(Vector3(w * 0.78, h * 0.42, w * 0.4),
				Vector3(c.x, c.y + leg + h * 0.21, c.z), SURF_STONE)
			for side2 in [-1.0, 1.0]:
				_kit.oriented_box(Vector3(w * 0.16, h * 0.5, w * 0.16),
					Transform3D(Basis(Vector3(0, 0, 1), side2 * 0.55),
						Vector3(c.x + side2 * w * 0.5, c.y + leg + h * 0.28, c.z)),
					SURF_STONE)
			box(Vector3(w * 0.3, h * 0.18, w * 0.3),
				Vector3(c.x, c.y + leg + h * 0.42 + h * 0.09, c.z), SURF_TRIM)
			_kit.stepped_taper(Vector3(c.x, c.y + leg + h * 0.42 + h * 0.18, c.z),
				w * 0.34, h * 0.14, SURF_TRIM, 3, 0.1)
		&"coil":
			# a serpent, wound round its own plinth, head at the top
			var turns: float = 3.0
			var rings: int = 22
			for i in range(rings):
				var t: float = float(i) / float(rings - 1)
				var a: float = t * TAU * turns
				var rr: float = lerpf(w * 0.5, w * 0.12, t)
				var y: float = c.y + t * h * 0.9
				box(Vector3(w * 0.24, h / float(rings) * 1.6, w * 0.24),
					Vector3(c.x + sin(a) * rr, y, c.z + cos(a) * rr), SURF_STONE, a)
			box(Vector3(w * 0.3, h * 0.12, w * 0.42),
				Vector3(c.x, c.y + h * 0.95, c.z - w * 0.1), SURF_TRIM)
		&"cairn":
			# a heap of skulls, stacked into a spire because somebody had time
			_kit.stepped_taper(Vector3(c.x, c.y, c.z), w, h, SURF_TRIM, 7, w * 0.12, false, 0.0, 1.15)
			box(Vector3(w * 1.15, 0.25, w * 1.15), Vector3(c.x, c.y + 0.12, c.z), SURF_STONE)
		_:
			# a pyre: a column of fire, held up by an iron basket
			_kit.drum(Vector3(c.x, c.y, c.z), w * 0.5, w * 0.34, h * 0.34,
				SURF_STONE, 8)
			_kit.drum(Vector3(c.x, c.y + h * 0.34, c.z), w * 0.44, w * 0.1,
				h * 0.66, SURF_TRIM, 8)
	_log_mass("idol", AABB(Vector3(c.x - w / 2.0, 0.0, c.z - w / 2.0),
		Vector3(w, c.y + h, w)))
	total_height = maxf(total_height, c.y + h)


# --------------------------------------------------------------------- pit

func _build_pit() -> void:
	var p: Rect2 = TempleGeometry.pit_rect(spec)
	if p.size.x <= 0.0:
		return
	tag("pit")
	# the throat: a dark shaft, so the hole reads as bottomless rather than as
	# a missing floor tile
	var depth: float = maxf(spec.height * 0.9, 4.0)
	box(Vector3(p.size.x, depth, p.size.y),
		Vector3(p.get_center().x, -depth / 2.0 - 0.3, p.get_center().y), SURF_DARK)
	# and the rim round it
	var rim: float = TempleGeometry.PIT_RIM
	for side in [-1.0, 1.0]:
		box(Vector3(p.size.x + rim * 2.0, rim, rim),
			Vector3(p.get_center().x, rim / 2.0, p.position.y + (0.0 if side < 0.0 else p.size.y)),
			SURF_TRIM)
		box(Vector3(rim, rim, p.size.y),
			Vector3(p.position.x + (0.0 if side < 0.0 else p.size.x), rim / 2.0,
				p.get_center().y), SURF_TRIM)
	var b: Rect2 = TempleGeometry.bridge_rect(spec)
	if b.size.x > 0.0:
		box(Vector3(b.size.x, 0.24, b.size.y),
			Vector3(b.get_center().x, -0.12, b.get_center().y), SURF_STONE)
		_log_mass("bridge", AABB(Vector3(b.position.x, -0.24, b.position.y),
			Vector3(b.size.x, 0.24, b.size.y)))


# ------------------------------------------------------------------- cells

func _build_cells() -> void:
	var cells: Array[Rect2] = TempleGeometry.cell_rects(spec)
	if cells.is_empty():
		return
	tag("cell")
	var h: float = minf(spec.height * 0.55, 3.2)
	var i := 0
	for c in cells:
		# the alcove reads as a recess: a dark back wall and a lintel over it
		box(Vector3(c.size.x, 0.35, c.size.y),
			Vector3(c.get_center().x, h + 0.17, c.get_center().y), SURF_STONE)
		box(Vector3(c.size.x * 0.9, h, 0.12),
			Vector3(c.get_center().x, h / 2.0,
				c.position.y + (c.size.y if c.position.x < 0.0 else 0.0)), SURF_DARK)
		_log_mass("cell_%d" % i, AABB(Vector3(c.position.x, 0.0, c.position.y),
			Vector3(c.size.x, h + 0.35, c.size.y)))
		i += 1


# -------------------------------------------------------------------- roof

func _build_roof() -> void:
	tag("roof")
	var r: Rect2 = TempleGeometry.site_rect(spec)
	var h: float = spec.height
	match TempleSpec.FORMS[spec.form]["roof"]:
		&"ridge":
			var along_x: bool = r.size.x > r.size.y
			var yaw: float = PI / 2.0 if along_x else 0.0
			var span: float = r.size.y if along_x else r.size.x
			var along: float = r.size.x if along_x else r.size.y
			_kit.ridge_roof(Transform3D(Basis(Vector3.UP, yaw), Vector3(0.0, h, 0.0)),
				span + 1.2, along + 0.8, span * 0.32, SURF_ROOF, SURF_STONE, span, along)
			total_height = maxf(total_height, TempleGeometry.roof_height(spec))
		&"flat":
			box(Vector3(r.size.x + 0.8, 0.5, r.size.y + 0.8),
				Vector3(0.0, h + 0.25, 0.0), SURF_ROOF)
			total_height = maxf(total_height, h + 0.5)
		&"terraced":
			_build_terraces()
		&"dome":
			_build_dome_roof(r)
			total_height = maxf(total_height, TempleGeometry.roof_height(spec))
	if spec.spire:
		var base: float = TempleGeometry.hall_rect(spec).size.x * TempleGeometry.SPIRE_BASE
		var z: float = TempleGeometry.dais_rect(spec).get_center().y
		# The dais can be away from the dome apex or a transverse ridge.
		# Seat the entire spire footprint on masonry meeting the host roof.
		var top := TempleGeometry.roof_height(spec)
		if top > h:
			box(Vector3(base, top - h, base), Vector3(0, (h + top) * 0.5, z), SURF_STONE)
		_kit.stepped_taper(Vector3(0.0, TempleGeometry.roof_height(spec), z),
			base, spec.spire_height, SURF_ROOF, 5, 0.2)
		total_height = maxf(total_height,
			TempleGeometry.roof_height(spec) + spec.spire_height)


func _build_dome_roof(rect: Rect2) -> void:
	var radius := TempleGeometry.dome_radius(spec)
	var rim := PackedVector2Array()
	for i in range(TempleGeometry.DOME_SEGMENTS):
		var angle := TAU * i / TempleGeometry.DOME_SEGMENTS
		rim.append(Vector2(cos(angle), sin(angle)) * radius)
	var deck := rect.grow(0.4)
	var outline := PackedVector2Array([deck.position, Vector2(deck.end.x, deck.position.y),
		deck.end, Vector2(deck.position.x, deck.end.y)])
	for piece in RoofShape.subtract(outline, rim):
		var face := PackedVector3Array()
		for p in piece:
			face.append(Vector3(p.x, spec.height, p.y))
		_kit.slab_poly(face, RoofShape.DEPTH, SURF_ROOF, true)
	# Closed shell with matching upper and lower seams at the deck.
	var mid := _dome_profile(radius, radius * 0.55)
	var shell := PackedVector2Array()
	for p in mid:
		shell.append(p + Vector2(0, RoofShape.DEPTH * 0.5))
	for i in range(mid.size() - 1, -1, -1):
		shell.append(mid[i] - Vector2(0, RoofShape.DEPTH * 0.5))
	shell.append(shell[0])
	_kit.revolve(shell, Vector3(0, spec.height, 0), SURF_ROOF, TempleGeometry.DOME_SEGMENTS)


## The lowest terrace as a ring of four slabs, with the doorway left out of the
## front one. What is inside it is the chamber; what is on top of it is the
## rest of the mountain.
func _terrace_ring(r: Rect2, th: float) -> void:
	var t: float = TempleGeometry.terrace_inset(spec)
	var gate: float = TempleGeometry.GATE_W
	var runs := [
		Rect2(Vector2(r.position.x, r.end.y - t), Vector2(r.size.x, t)),
		Rect2(Vector2(r.position.x, r.position.y + t), Vector2(t, r.size.y - t * 2.0)),
		Rect2(Vector2(r.end.x - t, r.position.y + t), Vector2(t, r.size.y - t * 2.0)),
		Rect2(Vector2(r.position.x, r.position.y), Vector2((r.size.x - gate) / 2.0, t)),
		Rect2(Vector2(gate / 2.0, r.position.y), Vector2((r.size.x - gate) / 2.0, t)),
	]
	for run in runs:
		if run.size.x <= 0.01 or run.size.y <= 0.01:
			continue
		box(Vector3(run.size.x, th, run.size.y),
			Vector3(run.get_center().x, th / 2.0, run.get_center().y), SURF_STONE)
	# the lintel over the doorway
	var gh: float = minf(TempleGeometry.GATE_H, th - 0.6)
	if th - gh > 0.05:
		box(Vector3(gate + t, th - gh, t),
			Vector3(0.0, gh + (th - gh) / 2.0, r.position.y + t / 2.0), SURF_STONE)


static func _dome_profile(radius: float, rise: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps: int = 6
	for i in range(steps + 1):
		var t: float = float(i) / steps
		pts.append(Vector2(radius * cos(t * PI / 2.0), rise * sin(t * PI / 2.0)))
	return pts


## The stepped mountain, and the stair up the front of it.
func _build_terraces() -> void:
	var th: float = TempleGeometry.terrace_height(spec)
	for level in range(spec.terraces):
		var r: Rect2 = TempleGeometry.terrace_rect(spec, level)
		if r.size.x <= 1.0 or r.size.y <= 1.0:
			break
		if level == 0:
			# the lowest terrace is hollow: the chamber where the rite is held
			# is inside it, so it goes up as four thick slabs round a room
			# rather than as a solid block of stone
			_terrace_ring(r, th)
		else:
			# stone, not roof. The cutaway view hides the roof surface, and a
			# mountain built out of roof vanished from under its own god, who
			# was left hanging in the sky above an empty chamber.
			box(Vector3(r.size.x, th, r.size.y),
				Vector3(r.get_center().x, th * float(level) + th / 2.0, r.get_center().y),
				SURF_STONE)
		# a coping course round the lip of each terrace. It is what a stepped
		# mountain actually has, and it is also the only thing a ziggurat puts
		# on the roof surface -- without it that surface is empty, the mesh
		# comes back with three surfaces instead of four, and every material
		# after it is handed the wrong colour.
		var lip: float = 0.28
		var y: float = th * float(level + 1)
		for side in [-1.0, 1.0]:
			box(Vector3(r.size.x, lip, lip * 1.6),
				Vector3(r.get_center().x, y - lip / 2.0,
					r.position.y + (0.0 if side < 0.0 else r.size.y)), SURF_ROOF)
			box(Vector3(lip * 1.6, lip, r.size.y),
				Vector3(r.position.x + (0.0 if side < 0.0 else r.size.x),
					y - lip / 2.0, r.get_center().y), SURF_ROOF)
		_log_mass("terrace_%d" % level, AABB(Vector3(r.position.x, 0.0, r.position.y),
			Vector3(r.size.x, th * float(level + 1), r.size.y)))
	var top: float = TempleGeometry.terrace_top(spec)
	var flights: Array[Rect2] = TempleGeometry.stair_rects(spec)
	var names := ["stair_left", "stair_right"]
	for f in range(flights.size()):
		var s: Rect2 = flights[f]
		var steps: int = maxi(int(top / 0.35), 4)
		for i in range(steps):
			# each step is a block as tall as the height it reaches, so the
			# flight is solid underneath rather than a floating staircase
			# the flight rises TOWARD the mountain: the tall end is the one
			# against it. Inverted, it climbs away into the open air and reads
			# as a ramp parked beside the building
			var t: float = float(i) / float(steps)
			var y: float = top * float(i + 1) / float(steps)
			var z: float = lerpf(s.position.y, s.end.y, t)
			box(Vector3(s.size.x, y, s.size.y / float(steps) + 0.05),
				Vector3(s.get_center().x, y / 2.0, z), SURF_STONE)
		_log_mass(names[f], AABB(Vector3(s.position.x, 0.0, s.position.y),
			Vector3(s.size.x, top, s.size.y)))
	total_height = maxf(total_height, top)


# ---------------------------------------------------------------- outworks

func _build_outworks() -> void:
	var r: Rect2 = TempleGeometry.site_rect(spec)
	if spec.form == &"pylon":
		tag("pylon")
		for i in range(TempleGeometry.pylon_rects(spec).size()):
			var p: Rect2 = TempleGeometry.pylon_rects(spec)[i]
			var h: float = spec.height * 1.35
			# a pylon batters: wider at the foot than at the top
			_kit.stepped_taper(Vector3(p.get_center().x, 0.0, p.get_center().y),
				p.size.x, h, SURF_STONE, 3, p.size.x * 0.86)
			_log_mass("pylon_%d" % i, AABB(Vector3(p.position.x, 0.0, p.position.y),
				Vector3(p.size.x, h, p.size.y)))
			total_height = maxf(total_height, h)
	if spec.obelisks:
		tag("obelisk")
		var oh: float = TempleGeometry.obelisk_height(spec)
		for side in [-1.0, 1.0]:
			var c: Vector2 = TempleGeometry.obelisk_center(spec, side)
			var x: float = c.x
			var z: float = c.y
			box(Vector3(oh * 0.14, oh * 0.82, oh * 0.14), Vector3(x, oh * 0.41, z),
				SURF_STONE)
			_kit.stepped_taper(Vector3(x, oh * 0.82, z), oh * 0.14, oh * 0.18,
				SURF_TRIM, 3, 0.05)
			_log_mass("obelisk_%s" % ("left" if side < 0.0 else "right"),
				AABB(Vector3(x - oh * 0.07, 0.0, z - oh * 0.07),
					Vector3(oh * 0.14, oh, oh * 0.14)))
			total_height = maxf(total_height, oh)


# ---------------------------------------------------------------- dressing

## What the cult puts in the place once the masons have gone: braziers down the
## processional way, a knife and a cup on the altar, chains and cages in the
## cells, banners on the walls.
##
## These are prop placements rather than geometry, and they are logged so the
## rite check can ask the questions that matter about them -- above all whether
## the way to the altar is lit.
func _dress() -> void:
	tag("dressing")
	_dress_braziers()
	_dress_pit()
	_dress_altar()
	_dress_cells()
	_dress_walls()


## Braziers in pairs down the axis, flanking the way without standing in it.
##
## Spaced by the rule the rite check tests rather than by a count: walk the
## axis, and whenever the last flame is further behind than a brazier throws
## light, set down another pair. A pair that would land in the hole steps
## forward to the far lip of it instead of being dropped -- which is what left
## a ten metre stretch of the walk dark when they were merely skipped.
func _dress_braziers() -> void:
	var z0: float = TempleGeometry.entry_point(spec).y + 1.2
	var z1: float = TempleGeometry.altar_center(spec).z - 1.5
	if z1 <= z0:
		return
	var x: float = TempleGeometry.axis_half_width(spec) + 0.5
	var pit: Rect2 = TempleGeometry.pit_rect(spec)
	var reach: float = TempleGeometry.LIGHT_REACH * 0.62
	var z: float = z0
	var placed := 0
	while z <= z1 + 0.01 and placed < 24:
		var at: float = z
		if pit.size.x > 0.0 and at > pit.position.y - 0.6 and at < pit.end.y + 0.6:
			# step past the hole rather than into it
			at = pit.end.y + 0.8
		if at > z1:
			break
		for side in [-1.0, 1.0]:
			_prop("Cauldron", Vector3(side * x, 0.0, at), 0.0, 1.0, &"light")
		placed += 1
		z = at + reach
	# and one pair at the foot of the dais, so the altar is never approached
	# out of the dark
	for side2 in [-1.0, 1.0]:
		_prop("Cauldron", Vector3(side2 * x, 0.0, z1), 0.0, 1.0, &"light")


## Fire along the lip of the pit.
##
## The braziers down the way step round the hole, which leaves the crossing --
## the most frightening part of the walk, and the part a congregation actually
## remembers -- unlit. These stand along both lips at the same spacing, so a
## wide pit is lit the whole way over rather than only at its corners: with
## corner braziers alone, a twelve metre hole left the middle of its own bridge
## nine metres from the nearest flame.
func _dress_pit() -> void:
	var pit: Rect2 = TempleGeometry.pit_rect(spec)
	if pit.size.x <= 0.0:
		return
	var out: float = TempleGeometry.PIT_RIM + 0.55
	var x: float = pit.size.x / 2.0 + out
	var reach: float = TempleGeometry.LIGHT_REACH * 0.62
	var z0: float = pit.position.y - out
	var z1: float = pit.end.y + out
	var n: int = maxi(int(ceil((z1 - z0) / reach)), 1)
	for i in range(n + 1):
		var z: float = lerpf(z0, z1, float(i) / float(n))
		for side in [-1.0, 1.0]:
			_prop("Cauldron", Vector3(pit.get_center().x + side * x, 0.0, z),
				0.0, 1.0, &"light")


## The altar furniture. A cup, a blade, and candles: the whole apparatus of the
## rite is four small objects and a great deal of stone.
func _dress_altar() -> void:
	var c: Vector3 = TempleGeometry.altar_center(spec)
	var top: float = c.y + spec.altar_h
	_prop("Chalice", Vector3(c.x - spec.altar_w * 0.28, top, c.z), 0.0, 1.0, &"vessel")
	_prop("Table_Knife", Vector3(c.x + spec.altar_w * 0.2, top, c.z), PI / 2.0, 1.4,
		&"blade")
	for side in [-1.0, 1.0]:
		_prop("CandleStick_Triple", Vector3(c.x + side * spec.altar_w * 0.42, top,
			c.z + spec.altar_l * 0.2), 0.0, 1.0, &"light")


## What the cells hold.
func _dress_cells() -> void:
	var cells: Array[Rect2] = TempleGeometry.cell_rects(spec)
	var chance: float = float(TempleSpec.CULTS[spec.cult]["chains"])
	var i := 0
	for cell in cells:
		var c: Vector2 = cell.get_center()
		var yaw: float = PI / 2.0 if c.x < 0.0 else -PI / 2.0
		if float(i) / maxf(float(cells.size()), 1.0) < chance:
			_prop("Cage_Small", Vector3(c.x, 0.0, c.y), yaw, 1.0, &"cage")
		else:
			_prop("Chain_Coil", Vector3(c.x, 0.0, c.y), yaw, 1.0, &"chain")
		i += 1


## Banners between the columns, and torches on the walls, which is where the
## light that is not fire in a bowl comes from.
func _dress_walls() -> void:
	var hall: Rect2 = TempleGeometry.hall_rect(spec)
	var n: int = clampi(int(hall.size.y / 6.0), 1, 5)
	for i in range(n):
		var t: float = (float(i) + 0.5) / float(n)
		var z: float = lerpf(hall.position.y + 1.5, hall.end.y - 2.0, t)
		for side in [-1.0, 1.0]:
			var x: float = (hall.end.x if side > 0.0 else hall.position.x) - side * 0.12
			var yaw: float = -PI / 2.0 if side > 0.0 else PI / 2.0
			_prop("Torch_Metal", Vector3(x, 2.4, z), yaw, 1.0, &"light")
			if i % 2 == 0:
				_prop("Banner_1", Vector3(x, spec.height * 0.62, z + 1.2), yaw, 1.0,
					&"banner")


func _prop(key: String, pos: Vector3, yaw: float, scale: float,
		kind: StringName) -> void:
	prop_log.append({"key": key, "pos": pos, "yaw": yaw, "scale": scale,
		"kind": kind})

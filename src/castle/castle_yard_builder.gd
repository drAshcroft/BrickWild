class_name CastleYardBuilder
extends RefCounted
## Raises what CastleYards planned: the earth under each yard and the pieces no
## pack ships -- lean-to roofs, woodpiles, rail fences, haystacks, troughs and
## stall canopies. Everything goes through the builder, so it is in its logs:
##
##   component_log  `yard_ground` and `yard_rim` (host `yard_<name>`), the
##                  roofs and cloth (`yard_roof`), so exterior QA can see them
##   mass_log       `yardwork_<name>_<piece>` for every SOLID piece, measured
##                  from what was emitted. The yard suite keeps every catalogue
##                  prop out of these, and the voxel QA seeds from them the way
##                  it does from the well.
##
## They are named `yardwork_` and not `yard_` on purpose: `yard_` is the prefix
## of a bailey BUILDING, and every rule about buildings (the bailey clearance,
## the range roof cover, the terraced re-grounding) reads it.
##
## Colour. The earth, the timber, the hay and the cloth are vertex-coloured
## onto the two dressing surfaces of the shell, so a new colour costs no new
## material. See CastleBuilder.SURF_GROUND and SURF_DRESS.

## The beaten earth of each yard, by CastleYards.EARTH index: smithy soot,
## stable straw and dung, market gravel, timber-store sawdust.
const EARTH := [Color("4a4039"), Color("9b7a48"), Color("a89a80"), Color("c3a46f")]
const EARTH_RIM := [Color("2f2925"), Color("6d5532"), Color("7d725d"), Color("8f7650")]
const WOODS := [Color("6b4a2c"), Color("7d5a37"), Color("5a3d24"), Color("8a6842")]
const HAY := Color("d4b04e")
const HAY_DARK := Color("b38f35")
const CLOTH_A := Color("9e3a2c")
const CLOTH_B := Color("dccba2")
const ROPE := Color("3a2a1c")


static func emit(b: CastleBuilder, yards: Array) -> void:
	for yard in yards:
		var yard_name := String(yard["name"])
		b.tag("yard_" + yard_name)
		b.host("yard_" + yard_name)
		var ground: float = float(yard["ground"])
		_patch(b, yard, ground)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(yard_name) ^ 0x6C6F67
		var n := 0
		for piece in yard["pieces"]:
			n += 1
			var id := "yardwork_%s_%s%d" % [yard_name, String(piece["kind"]), n]
			match StringName(piece["kind"]):
				&"post":
					_post(b, id, piece, ground, rng)
				&"solid":
					_solid(b, id, piece, ground, rng)
				&"woodpile":
					_woodpile(b, id, piece, ground, rng)
				&"stack":
					_stack(b, id, piece, ground)
				&"fence":
					_fence(b, id, piece, ground, rng)
				&"roof":
					_roof(b, piece, ground)
		b.host_end()


static func _colour(b: CastleBuilder, surf: int, c: Color) -> void:
	b._kit.surface(surf).set_color(c)


static func _white(b: CastleBuilder, surf: int) -> void:
	b._kit.surface(surf).set_color(Color.WHITE)


## The earth quad: a darker rim and the working surface inside it.
static func _patch(b: CastleBuilder, yard: Dictionary, ground: float) -> void:
	var r: Rect2 = yard["rect"]
	var idx: int = int(yard["earth"])
	b.mark_ground_skin()
	_colour(b, CastleBuilder.SURF_GROUND, EARTH_RIM[idx])
	b.component_box("yard_rim", Vector3(r.size.x, CastleYards.PATCH_H * 0.8, r.size.y),
		Transform3D(Basis.IDENTITY, Vector3(r.get_center().x,
			ground + CastleYards.PATCH_H * 0.4, r.get_center().y)), CastleBuilder.SURF_GROUND)
	var inner: Rect2 = r.grow(-minf(0.9, minf(r.size.x, r.size.y) * 0.08))
	_colour(b, CastleBuilder.SURF_GROUND, EARTH[idx])
	b.component_box("yard_ground", Vector3(inner.size.x, CastleYards.PATCH_H, inner.size.y),
		Transform3D(Basis.IDENTITY, Vector3(inner.get_center().x,
			ground + CastleYards.PATCH_H * 0.5, inner.get_center().y)), CastleBuilder.SURF_GROUND)
	_white(b, CastleBuilder.SURF_GROUND)


static func _wood(rng: RandomNumberGenerator) -> Color:
	return WOODS[rng.randi() % WOODS.size()]


## A square timber post, standing on the ground.
static func _post(b: CastleBuilder, id: String, piece: Dictionary, ground: float,
		rng: RandomNumberGenerator) -> void:
	var p: Vector2 = piece["pos"]
	var h: float = float(piece["h"])
	_colour(b, CastleBuilder.SURF_DRESS, _wood(rng))
	var y0: float = ground + CastleYards.PATCH_H
	b._kit.box(Vector3(0.2, h, 0.2), Vector3(p.x, y0 + h / 2.0, p.y), CastleBuilder.SURF_DRESS)
	_white(b, CastleBuilder.SURF_DRESS)
	b._log_mass(id, AABB(Vector3(p.x - 0.1, ground, p.y - 0.1),
		Vector3(0.2, h + CastleYards.PATCH_H, 0.2)), ground)


static func _solid(b: CastleBuilder, id: String, piece: Dictionary, ground: float,
		rng: RandomNumberGenerator) -> void:
	var r: Rect2 = piece["rect"]
	var h: float = float(piece["h"])
	var y0: float = ground + CastleYards.PATCH_H
	_colour(b, CastleBuilder.SURF_DRESS, _wood(rng))
	b._kit.box(Vector3(r.size.x, h, r.size.y), Vector3(r.get_center().x, y0 + h / 2.0,
		r.get_center().y), CastleBuilder.SURF_DRESS)
	_white(b, CastleBuilder.SURF_DRESS)
	b._log_mass(id, AABB(Vector3(r.position.x, ground, r.position.y),
		Vector3(r.size.x, h + CastleYards.PATCH_H, r.size.y)), ground)


## Logs laid side by side in courses, ends toward the viewer: a stack of fuel,
## built from the log, not painted on a box. Courses offset by half a log.
static func _woodpile(b: CastleBuilder, id: String, piece: Dictionary, ground: float,
		rng: RandomNumberGenerator) -> void:
	var r: Rect2 = piece["rect"]
	var h: float = float(piece["h"])
	var along_x: bool = bool(piece["logs_along_x"])
	var y0: float = ground + CastleYards.PATCH_H
	var girth := 0.26
	var length: float = r.size.x if along_x else r.size.y
	var across: float = r.size.y if along_x else r.size.x
	var cols: int = maxi(1, int(floor(across / girth)))
	var rows: int = maxi(1, int(floor(h / girth)))
	for row in range(rows):
		var shift: float = girth * 0.5 if row % 2 == 1 else 0.0
		for col in range(cols):
			var off: float = (float(col) + 0.5) * girth + shift - across / 2.0
			if absf(off) > across / 2.0 - girth * 0.4:
				continue
			var jitter: float = rng.randf_range(-0.05, 0.05) * length
			var len: float = length * 0.96 + jitter
			_colour(b, CastleBuilder.SURF_DRESS, _wood(rng))
			var y: float = y0 + (float(row) + 0.5) * girth
			var c := r.get_center()
			if along_x:
				b._kit.box(Vector3(len, girth * 0.94, girth * 0.94),
					Vector3(c.x, y, c.y + off), CastleBuilder.SURF_DRESS)
			else:
				b._kit.box(Vector3(girth * 0.94, girth * 0.94, len),
					Vector3(c.x + off, y, c.y), CastleBuilder.SURF_DRESS)
	_white(b, CastleBuilder.SURF_DRESS)
	b._log_mass(id, AABB(Vector3(r.position.x, ground, r.position.y),
		Vector3(r.size.x, float(rows) * girth + CastleYards.PATCH_H, r.size.y)), ground)


## A haystack: a revolved dome with a girdle of rope round its belly and a
## pole through the crown.
static func _stack(b: CastleBuilder, id: String, piece: Dictionary, ground: float) -> void:
	var at: Vector2 = piece["pos"]
	var radius: float = float(piece["r"])
	var h: float = float(piece["h"])
	var base := Vector3(at.x, ground + CastleYards.PATCH_H, at.y)
	var profile := PackedVector2Array([
		Vector2(radius * 0.86, 0.0), Vector2(radius, h * 0.28),
		Vector2(radius * 0.9, h * 0.55), Vector2(radius * 0.56, h * 0.82),
		Vector2(0.0, h)])
	_colour(b, CastleBuilder.SURF_DRESS, HAY)
	b._kit.revolve(profile, base, CastleBuilder.SURF_DRESS, 14)
	_colour(b, CastleBuilder.SURF_DRESS, HAY_DARK)
	b._kit.revolve(PackedVector2Array([Vector2(radius * 0.82, 0.0), Vector2(radius * 0.97, h * 0.1),
		Vector2(radius * 0.94, h * 0.2)]), base - Vector3(0.0, 0.0, 0.0), CastleBuilder.SURF_DRESS, 14)
	_colour(b, CastleBuilder.SURF_DRESS, ROPE)
	b._kit.box(Vector3(0.1, h * 0.28, 0.1), base + Vector3(0.0, h + h * 0.1, 0.0),
		CastleBuilder.SURF_DRESS)
	_white(b, CastleBuilder.SURF_DRESS)
	b._log_mass(id, AABB(Vector3(at.x - radius, ground, at.y - radius),
		Vector3(radius * 2.0, h + h * 0.2 + CastleYards.PATCH_H, radius * 2.0)), ground)


## A straight run of rail fence: a post every couple of metres and two rails,
## the lower low enough to stop a lamb and the upper to stop a horse.
static func _fence(b: CastleBuilder, id: String, piece: Dictionary, ground: float,
		rng: RandomNumberGenerator) -> void:
	var a: Vector2 = piece["a"]
	var c: Vector2 = piece["b"]
	var h: float = float(piece["h"])
	var y0: float = ground + CastleYards.PATCH_H
	var length: float = a.distance_to(c)
	var count: int = maxi(1, int(ceil(length / 2.2)))
	var dir: Vector2 = (c - a) / length
	for i in range(count + 1):
		var p: Vector2 = a + dir * (length * float(i) / float(count))
		_colour(b, CastleBuilder.SURF_DRESS, _wood(rng))
		b._kit.box(Vector3(0.16, h, 0.16), Vector3(p.x, y0 + h / 2.0, p.y), CastleBuilder.SURF_DRESS)
	var mid: Vector2 = (a + c) * 0.5
	var along_x: bool = absf(dir.x) > absf(dir.y)
	for level in [0.42, 0.82]:
		_colour(b, CastleBuilder.SURF_DRESS, _wood(rng))
		var size := Vector3(length, 0.1, 0.07) if along_x else Vector3(0.07, 0.1, length)
		b._kit.box(size, Vector3(mid.x, y0 + h * level, mid.y), CastleBuilder.SURF_DRESS)
	_white(b, CastleBuilder.SURF_DRESS)
	# Two runs meet at a corner post that belongs to both. Each logs only the
	# rails and the posts between its ends, so the masses touch and never overlap.
	var a2: Vector2 = a + dir * 0.2
	var c2: Vector2 = c - dir * 0.2
	var lo := Vector2(minf(a2.x, c2.x), minf(a2.y, c2.y)) - Vector2.ONE * 0.08
	var hi := Vector2(maxf(a2.x, c2.x), maxf(a2.y, c2.y)) + Vector2.ONE * 0.08
	b._log_mass(id, AABB(Vector3(lo.x, ground, lo.y),
		Vector3(hi.x - lo.x, h + CastleYards.PATCH_H, hi.y - lo.y)), ground)


## A roof or a cloth: logged as a component, never as a mass, so what stands
## UNDER it -- an anvil, a table -- is not inside a solid.
static func _roof(b: CastleBuilder, piece: Dictionary, ground: float) -> void:
	var lift := Vector3(0.0, ground + CastleYards.PATCH_H, 0.0)
	var pts := PackedVector3Array()
	for p in piece["pts"] as PackedVector3Array:
		pts.append(p + lift)
	match StringName(piece["surf"]):
		&"tile":
			b.component_slab("yard_roof", pts, 0.12, CastleBuilder.SURF_ROOF, true)
		&"cloth_a":
			_colour(b, CastleBuilder.SURF_DRESS, CLOTH_A)
			b.component_slab("yard_cloth", pts, 0.05, CastleBuilder.SURF_DRESS, true)
			_white(b, CastleBuilder.SURF_DRESS)
		_:
			_colour(b, CastleBuilder.SURF_DRESS, CLOTH_B)
			b.component_slab("yard_cloth", pts, 0.05, CastleBuilder.SURF_DRESS, true)
			_white(b, CastleBuilder.SURF_DRESS)

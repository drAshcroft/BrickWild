class_name BridgeAssembler
extends RefCounted
## A bridge as a scene: the mesh, its materials, its lights, and -- the part
## that makes a bridge photographable at all -- THE GROUND IT STANDS ON.
##
## Everything above this file works in metres and polygons and never builds a
## vertex, which is what lets the geometry suite sweep hundreds of bridges
## headless in milliseconds. Here, at the very end, the mesh gets materials and
## the site gets geometry.
##
## The site is the interesting part. A bridge with no gorge around it is a
## bridge on a table, and half of what makes a span read as a span is the
## ground refusing to continue past its abutments. So `site()` builds the
## banks out of `BridgeGeometry.bank_height_at` -- the SAME function the
## abutments' footings were computed from -- and a bridge therefore cannot be
## placed on a landscape that disagrees with it. That is the whole argument for
## putting the terrain in `BridgeGeometry` rather than in a render tool.
##
## Model axes: +X along the span, +Y up, +Z across, y = 0 the water.

const WATER := Color("3f5c63")
const GROUND := Color("6d6a52")
const ROCK := Color("7b7566")
const BED := Color("3a4438")

## How far the modelled ground runs beyond the span, in metres, and how deep
## the water is drawn. The site is a backdrop, not a landscape: a river
## kilometre long would not help a picture of a bridge.
const SITE_REACH := 12.0
const WATER_DEPTH := 3.0
## How many steps the bank profile is sampled at. Twenty-four is enough for a
## batter to read as a slope and few enough that the site is a hundred boxes.
const SITE_STEPS := 64
## How far the modelled ground runs past the top of the bank.


static func materials(spec: BridgeSpec) -> Array[StandardMaterial3D]:
	var out: Array[StandardMaterial3D] = []
	var m := StandardMaterial3D.new()
	m.albedo_color = spec.stone_color
	m.roughness = 0.94
	m.vertex_color_use_as_albedo = true
	out.append(m)
	var t := StandardMaterial3D.new()
	t.albedo_color = spec.timber_color
	t.roughness = 0.88
	t.vertex_color_use_as_albedo = true
	out.append(t)
	var d := StandardMaterial3D.new()
	d.albedo_color = spec.deck_color
	d.roughness = 0.92
	d.vertex_color_use_as_albedo = true
	out.append(d)
	var k := StandardMaterial3D.new()
	k.albedo_color = spec.metal_color
	k.roughness = 0.45
	k.metallic = 0.6
	k.vertex_color_use_as_albedo = true
	out.append(k)
	return out


## A whole bridge: a `MeshInstance3D`, a site, and a lamp per `spec.glow` entry.
static func build(spec: BridgeSpec, builder: BridgeBuilder = null) -> Node3D:
	var root := Node3D.new()
	root.name = name_of(spec)
	var kit: BridgeBuilder = builder if builder != null else BridgeBuilder.new()
	var mesh: ArrayMesh = kit.build(spec)
	var span := MeshInstance3D.new()
	span.name = "Mesh"
	span.mesh = mesh
	var cols: Array[StandardMaterial3D] = materials(spec)
	for i in range(mesh.get_surface_count()):
		if i < cols.size():
			span.set_surface_override_material(i, cols[i])
	root.add_child(span)
	root.add_child(site(spec))
	for i in range(spec.glow.size()):
		var e: Dictionary = spec.glow[i]
		var lamp := OmniLight3D.new()
		lamp.name = "glow_%d" % i
		lamp.position = e["pos"]
		lamp.light_color = e.get("colour", Color("ffd08a"))
		lamp.light_energy = float(e.get("energy", 2.0))
		lamp.omni_range = float(e.get("range", 8.0))
		root.add_child(lamp)
	return root


## The ground the bridge stands in: two banks, a bed, and the water between
## them, all stepped along X out of `BridgeGeometry.bank_height_at`.
## The ground the bridge stands in.
##
## Five solids, not a stepped terrain: a flat top on each side, one SLOPED slab
## down to the water, and a flat bed between. A bank built as a stack of boxes
## stepping down reads as a ziggurat -- and that is not a matter of taste, it is
## what a staircase looks like, and a bridge on one is a bridge on a Mayan
## pyramid. The slope is one box, rotated to the batter `bank_height_at`
## describes, and the two agree because they are the same function.
static func site(spec: BridgeSpec) -> Node3D:
	var root := Node3D.new()
	root.name = "Site"
	var kit := MeshKit.new(3)
	var half: float = spec.span * 0.5
	var toe: float = half + spec.bank_run
	var reach: float = toe + SITE_REACH * 0.5
	var z_far: float = clampf(spec.span * 0.30, 11.0, 48.0)
	var bed: float = spec.water_level - WATER_DEPTH
	var bank: float = spec.bank_height
	var water_mid: float = spec.water_level

	# The bed, under the channel and out to the far edge.
	kit.oriented_box(Vector3(reach * 2.0, water_mid - bed, z_far * 2.0),
		Transform3D(Basis(), Vector3(0.0, (water_mid + bed) * 0.5, 0.0)), 0)

	# The two bank tops: a flat shelf either side of the channel, from the
	# water's edge outward.
	for sx in [-1.0, 1.0]:
		var top_len: float = reach - half
		kit.oriented_box(Vector3(top_len, bank - water_mid, z_far * 2.0),
			Transform3D(Basis(), Vector3(sx * (half + top_len * 0.5),
				(bank + water_mid) * 0.5, 0.0)), 2)
		# And the slope between them, as ONE rotated slab. Its length is the
		# hypotenuse of the batter, and its angle is the batter's own.
		var run: float = spec.bank_run
		var rise: float = bank - water_mid
		var len: float = sqrt(run * run + rise * rise)
		var ang: float = atan2(rise, run)
		var cx: float = sx * (half + run * 0.5)
		var cy: float = (bank + water_mid) * 0.5
		var basis := Basis(Vector3(0.0, 0.0, 1.0), -sx * ang)
		kit.oriented_box(Vector3(len, 0.5, z_far * 2.0),
			Transform3D(basis, Vector3(cx, cy, 0.0)), 1)
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = kit.commit()
	var gm := StandardMaterial3D.new()
	gm.roughness = 1.0
	ground.set_surface_override_material(0, _mat(BED))
	ground.set_surface_override_material(1, _mat(ROCK))
	ground.set_surface_override_material(2, _mat(GROUND))
	root.add_child(ground)

	var water := MeshInstance3D.new()
	water.name = "Water"
	var wk := MeshKit.new(1)
	wk.oriented_box(Vector3(half * 2.0, 0.1, z_far * 2.0),
		Transform3D(Basis(), Vector3(0.0, water_mid, 0.0)), 0)
	water.mesh = wk.commit()
	var wm := StandardMaterial3D.new()
	wm.albedo_color = WATER
	wm.roughness = 0.1
	wm.metallic = 0.15
	water.set_surface_override_material(0, wm)
	root.add_child(water)
	return root


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m


## A safe node name, for the same reason the house assembler has one: Godot
## refuses `.` `:` `@` `/` `%` and `"` in a node name.
static func name_of(spec: BridgeSpec) -> String:
	var n: String = spec.variant_name.strip_edges()
	if n.is_empty():
		return "Bridge"
	for bad in [".", ":", "@", "/", "%", "\""]:
		n = n.replace(bad, "_")
	return n


## A representative subject for a render tool or a gallery, by kind.
static func showcase(kind: StringName, seed: int) -> BridgeSpec:
	var s := BridgeSpec.new()
	s.kind = kind
	s.seed = seed
	match kind:
		&"stone":
			s.span = 34.0
			s.width = 5.0
			s.deck_height = 5.2
			s.bank_height = 5.2
			s.bank_run = 16.0
		&"covered":
			s.span = 30.0
			s.width = 5.4
			s.deck_height = 4.4
			s.bank_height = 4.4
			s.bank_run = 14.0
		&"rope":
			s.span = 76.0
			s.width = 6.0
			s.deck_height = 6.0
			s.bank_height = 6.0
			s.bank_run = 26.0
		_:
			s.span = 46.0
			s.width = 6.0
			s.deck_height = 5.0
			s.bank_height = 5.0
			s.bank_run = 20.0
	return s

extends RefCounted
## CULTURE-FURNISH-VOCAB: what a furnished minka, Sahel courtyard house or
## roundhouse is furnished WITH.
##
## The furnisher plans by category and footprint (a table, two seats, a bed
## against a wall, a light on the wall) and that plan is right for any
## household: it is what HouseFurnishCheck and HouseNavCheck judge. What was
## wrong was the stock: a minka's table was the European trestle table, its
## lights wall torches and a chandelier, its cups goblets and tankards, its
## floor planks. So the plan rows are left exactly as placed and judged, and
## the assembler asks this vocabulary what each row LOOKS like in this style.
## A look never grows past its row's rect (the floor the checks measured), so
## the walk and the clearances are the plan's own; things that stood on a
## lowered table are lowered with it.
##
## Missing catalogue props are procedural, as the witch broom is: tatami,
## a chabudai, zabuton, a futon, a tansu, a tokonoma, paper lanterns; a low
## table, low stools, a rope bed, water jars, storage pots, baskets and a
## grinding stone.
##
## Deny list (tests/culture_furnish_test.gd): no row of these styles may load
## one of DENY's models, and the floor finish may not be planks.

const DENY: Array[String] = ["Table_Large", "Chalice", "Mug", "Chandelier",
	"Torch_Metal", "Dungeon_Torch"]

const MINKA := {
	"Table_Large": "low_table", "Chair_1": "zabuton", "Stool": "zabuton",
	"Bench": "zabuton_row", "Bed_Twin1": "futon", "Bed_Twin2": "futon",
	"Chest_Wood": "tansu", "Nightstand_Shelf": "tansu", "Cabinet": "tansu",
	"Torch_Metal": "wall_andon", "Dungeon_Torch": "wall_andon",
	"Chandelier": "paper_lantern", "Candle_1": "andon", "Candle_2": "andon",
	"CandleStick": "andon", "CandleStick_Triple": "andon", "CandleStick_Stand": "andon",
	"Mug": "tea_cup", "Chalice": "tea_cup", "Table_Plate": "lacquer_bowl",
	"Table_Fork": "chopsticks", "Table_Knife": "chopsticks", "Table_Spoon": "chopsticks",
	"Bottle_1": "tokkuri",
}

const SAHEL := {
	"Table_Large": "low_table", "Chair_1": "low_stool", "Stool": "low_stool",
	"Bench": "banco_bench", "Bed_Twin1": "rope_bed", "Bed_Twin2": "rope_bed",
	"Chest_Wood": "grain_jar", "Nightstand_Shelf": "banco_shelf", "Cabinet": "banco_shelf",
	"Barrel": "storage_pot", "Barrel_Apples": "storage_pot", "Dungeon_Barrel": "storage_pot",
	"Barrel_Holder": "storage_pots", "Crate_Wooden": "basket", "FarmCrate_Apple": "basket",
	"FarmCrate_Carrot": "basket", "FarmCrate_Empty": "basket",
	"Bucket_Wooden_1": "water_jar", "Bucket_Metal": "water_jar",
	"Workbench": "grinding_stone",
	"Torch_Metal": "clay_lamp_wall", "Dungeon_Torch": "clay_lamp_wall",
	"Chandelier": "clay_lamp_hanging", "Candle_1": "clay_lamp", "Candle_2": "clay_lamp",
	"CandleStick": "clay_lamp", "CandleStick_Triple": "clay_lamp", "CandleStick_Stand": "clay_lamp",
	"Mug": "clay_cup", "Chalice": "clay_cup", "Table_Plate": "calabash",
	"Table_Fork": "wooden_spoon", "Table_Knife": "wooden_spoon", "Table_Spoon": "wooden_spoon",
	"Bottle_1": "clay_flask",
}

## A roundhouse shares the earthen household of the Sahel list, but sleeps on a
## straw pallet on the floor and keeps its wooden chest.
const ROUND_OVERRIDES := {
	"Bed_Twin1": "pallet", "Bed_Twin2": "pallet", "Chest_Wood": "plank_chest",
}

## Top of each look that things can be set on, metres above its floor.
const TOPS := {
	"low_table": 0.33, "tansu": 0.0, "grinding_stone": 0.46, "banco_shelf": 0.55,
	"banco_bench": 0.38, "tokonoma": 0.16,
}

## The most a look takes of its row's rect (long side, short side), metres.
const EXTENT := {
	"low_table": Vector2(1.4, 0.85), "grinding_stone": Vector2(1.6, 0.7),
	"tansu": Vector2(1.2, 0.45), "tokonoma": Vector2(1.35, 0.42),
	"banco_shelf": Vector2(1.3, 0.42),
}

## Looks hung on a wall or the ceiling by their pos, not stood on the floor.
const MOUNTED_LOOKS: Array[String] = ["wall_andon", "clay_lamp_wall", "paper_lantern",
	"clay_lamp_hanging"]

const TATAMI := Color(0.70, 0.64, 0.42)
const EARTH := Color(0.50, 0.37, 0.25)

static var _mats := {}


## "minka", "sahel", "round" or "" (no vocabulary: the stock is the house's own).
static func culture(plan: HousePlan) -> String:
	if plan == null or plan.spec == null or plan.spec is ShopSpec or plan.world_family != &"":
		return ""
	match plan.spec.style:
		&"asian":
			return "minka"
		&"african":
			return "sahel"
		&"roundhouse":
			return "round"
	return ""


## "tatami", "earth" or "planks".
static func floor_finish(plan: HousePlan) -> String:
	match culture(plan):
		"minka":
			return "tatami"
		"sahel", "round":
			return "earth"
	return "planks"


## Looks for every furniture row, by row index (absent: the catalogue model).
static func looks(plan: HousePlan) -> Dictionary:
	var c := culture(plan)
	var out := {}
	if c.is_empty():
		return out
	var table: Dictionary = MINKA if c == "minka" else SAHEL
	var tokonoma_done := false
	for i in range(plan.furniture.size()):
		var row: Dictionary = plan.furniture[i]
		var key := String(row.get("key", ""))
		var look := String(table.get(key, ""))
		if c == "round" and ROUND_OVERRIDES.has(key):
			look = String(ROUND_OVERRIDES[key])
		# the minka's best room keeps one alcove: the first cabinet against a
		# wall of the hall or parlour becomes the tokonoma
		if c == "minka" and key == "Cabinet" and not tokonoma_done \
				and plan.kind_of(int(row.get("room", 0))) in [&"hall", &"parlour"]:
			look = "tokonoma"
			tokonoma_done = true
		# a lamp set on a table is a small one
		if look == "andon" and PropCatalog.has_tag(key, PropCatalog.ON_SURFACE):
			look = "andon_small"
		if not look.is_empty():
			out[i] = look
	return out


## How far a piece set ON another row moves when its host takes a look: down
## to the look's top, and in from the ends of a host that the look made
## shorter (a cup at the end of a 2.8 m trestle would hang off a 1.4 m
## chabudai).
static func host_shift(plan: HousePlan, i: int, looks_by_row: Dictionary) -> Vector3:
	var host := int(plan.furniture[i].get("host", -1))
	# seats drawn up to a table carry it as their host too; only what stands ON it moves
	if not PropCatalog.has_tag(String(plan.furniture[i].get("key", "")), PropCatalog.ON_SURFACE):
		return Vector3.ZERO
	if host < 0 or host >= plan.furniture.size() or not looks_by_row.has(host):
		return Vector3.ZERO
	var look := String(looks_by_row[host])
	var row: Dictionary = plan.furniture[host]
	var key := String(row.get("key", ""))
	var old_top := PropCatalog.surface_height(key) * PropCatalog.placement_height_scale(row)
	if not TOPS.has(look) or old_top <= 0.0:
		return Vector3.ZERO
	var top := float(TOPS[look])
	if top <= 0.0:
		top = _tansu_height(row, key)
	var hr := Rect2(row["rect"])
	var fit := fit_in_wall(plan, row, look)
	var hc: Vector2 = fit["c"]
	hr.size *= float(fit["k"])
	var ext: Vector2 = EXTENT.get(look, Vector2(99.0, 99.0))
	var half := (Vector2(ext.x, ext.y) if hr.size.x >= hr.size.y else Vector2(ext.y, ext.x)) * 0.5
	half = Vector2(minf(half.x, hr.size.x * 0.5), minf(half.y, hr.size.y * 0.5)) - Vector2(0.08, 0.08)
	half = half.max(Vector2.ZERO)
	var p: Vector3 = plan.furniture[i]["pos"]
	var nx := clampf(p.x, hc.x - half.x, hc.x + half.x)
	var nz := clampf(p.z, hc.y - half.y, hc.y + half.y)
	return Vector3(nx - p.x, top - old_top, nz - p.z)


## The model key that row `i` actually puts in the scene (its look, or the key).
static func shown_key(plan: HousePlan, i: int, looks_by_row: Dictionary) -> String:
	if looks_by_row.has(i):
		return "Culture_" + String(looks_by_row[i])
	return String(plan.furniture[i].get("key", ""))


static func _tansu_height(row: Dictionary, key: String) -> float:
	match key:
		"Nightstand_Shelf":
			return 0.5
		"Chest_Wood":
			return 0.62
	return minf(0.95, PropCatalog.height(key) * PropCatalog.placement_height_scale(row))


# --- materials ---------------------------------------------------------------

static func _mat(name: String) -> StandardMaterial3D:
	if _mats.has(name):
		return _mats[name]
	var m := StandardMaterial3D.new()
	m.roughness = 0.9
	match name:
		"dark_wood":
			m.albedo_color = Color(0.24, 0.15, 0.09)
		"wood":
			m.albedo_color = Color(0.48, 0.33, 0.19)
		"pale_wood":
			m.albedo_color = Color(0.70, 0.56, 0.38)
		"lacquer":
			m.albedo_color = Color(0.36, 0.07, 0.05)
			m.roughness = 0.35
		"iron":
			m.albedo_color = Color(0.16, 0.15, 0.14)
			m.metallic = 0.6
		"indigo":
			m.albedo_color = Color(0.17, 0.22, 0.38)
		"cotton":
			m.albedo_color = Color(0.86, 0.83, 0.76)
		"tatami":
			m.albedo_color = TATAMI
		"paper":
			m.albedo_color = Color(0.95, 0.90, 0.78)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.78, 0.45)
			m.emission_energy_multiplier = 0.6
		"ink":
			m.albedo_color = Color(0.12, 0.12, 0.12)
		"scroll":
			m.albedo_color = Color(0.88, 0.85, 0.74)
		"ceramic":
			m.albedo_color = Color(0.82, 0.80, 0.72)
			m.roughness = 0.4
		"clay":
			m.albedo_color = Color(0.62, 0.34, 0.20)
		"dark_clay":
			m.albedo_color = Color(0.36, 0.22, 0.15)
		"earth":
			m.albedo_color = Color(0.66, 0.46, 0.29)
		"stone":
			m.albedo_color = Color(0.45, 0.43, 0.40)
		"straw":
			m.albedo_color = Color(0.72, 0.60, 0.33)
		"rope":
			m.albedo_color = Color(0.60, 0.50, 0.32)
		"calabash":
			m.albedo_color = Color(0.74, 0.58, 0.30)
		"wool":
			m.albedo_color = Color(0.52, 0.40, 0.28)
		"flame":
			m.albedo_color = Color(1.0, 0.75, 0.35)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.65, 0.25)
			m.emission_energy_multiplier = 2.0
	_mats[name] = m
	return m


static func _box(parent: Node3D, size: Vector3, centre: Vector3, mat: String) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = _mat(mat)
	n.position = centre
	parent.add_child(n)
	return n


static func _cyl(parent: Node3D, r_bottom: float, r_top: float, h: float, base: Vector3,
		mat: String, sides := 14) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = r_bottom
	mesh.top_radius = r_top
	mesh.height = h
	mesh.radial_segments = sides
	mesh.rings = 1
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = _mat(mat)
	n.position = base + Vector3(0.0, h * 0.5, 0.0)
	parent.add_child(n)
	return n


static func _ball(parent: Node3D, r: float, h: float, centre: Vector3, mat: String) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = h
	mesh.radial_segments = 16
	mesh.rings = 8
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = _mat(mat)
	n.position = centre
	parent.add_child(n)
	return n


## A jar standing on y = 0: a round body (radius r, height h) and a neck.
static func _jar(parent: Node3D, r: float, h: float, at: Vector3, mat: String) -> void:
	_ball(parent, r, h * 0.82, at + Vector3(0.0, h * 0.41, 0.0), mat)
	_cyl(parent, r * 0.42, r * 0.5, h * 0.2, at + Vector3(0.0, h * 0.78, 0.0), mat)


# --- the looks ---------------------------------------------------------------

## The scene node for row `p` taking `look`. Plan coordinates, like
## HouseAssembler._instance (the assembler lifts the house afterwards).
static func node_for(plan: HousePlan, p: Dictionary, look: String, shift: Vector3) -> Node3D:
	var f := fit_in_wall(plan, p, look)
	return _build(plan, p, look, shift, f["c"], float(f["k"]))


## A look is drawn inside its row's rect, but on a ROUND (polygonal) hall the
## rect is only the bounding box of the piece and the wall is the curve: a low
## table or a chest at the edge of the ring pokes through it. Walk the look in
## toward the middle of the room, then shrink it, until its real footprint is
## inside the room's outline. Returns {"c": Vector2 centre, "k": float scale};
## the row's own centre and 1.0 when the room is a plain rectangle or the look
## already stands inside.
static func fit_in_wall(plan: HousePlan, p: Dictionary, look: String) -> Dictionary:
	var rect := Rect2(p["rect"])
	var out := {"c": rect.get_center(), "k": 1.0}
	var room := int(p.get("room", 0))
	if not plan.is_polygonal(room) or bool(p.get("mounted", false)) or look in MOUNTED_LOOKS 			or PropCatalog.has_tag(String(p.get("key", "")), PropCatalog.ON_SURFACE):
		return out
	var outline: PackedVector2Array = plan.outline_of(room)
	var middle := Poly.bounding_rect(outline).get_center()
	var c: Vector2 = out["c"]
	var k := 1.0
	for i in range(40):
		var node := _build(plan, p, look, Vector3.ZERO, c, k)
		var fp := footprint(node)
		node.free()
		var corners := PackedVector2Array([fp.position, Vector2(fp.end.x, fp.position.y),
			fp.end, Vector2(fp.position.x, fp.end.y)])
		if Poly.encloses_corners(outline, corners, 0.01):
			break
		var d := middle - c
		if d.length() > 0.04:
			c += d.normalized() * 0.04
		if i % 4 == 3:
			k = maxf(0.5, k * 0.93)
	out["c"] = c
	out["k"] = k
	return out


## The look's footprint on the floor plan (every part is an axis-aligned
## primitive hung straight off the root).
static func footprint(node: Node3D) -> Rect2:
	var fp := Rect2()
	var first := true
	for ch in node.get_children():
		if not (ch is MeshInstance3D) or (ch as MeshInstance3D).mesh == null:
			continue
		var b: AABB = (ch as MeshInstance3D).mesh.get_aabb()
		var r := Rect2(node.position.x + ((ch as Node3D).position.x + b.position.x) * node.scale.x,
			node.position.z + ((ch as Node3D).position.z + b.position.z) * node.scale.z,
			b.size.x * node.scale.x, b.size.z * node.scale.z)
		fp = r if first else fp.merge(r)
		first = false
	return fp


static func _build(plan: HousePlan, p: Dictionary, look: String, shift: Vector3,
		fit_c: Vector2, fit_k: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Culture_" + look
	root.set_meta("plan_key", String(p.get("key", "")))
	root.set_meta("culture_look", look)
	var rect := Rect2(p["rect"])
	var pos: Vector3 = p["pos"]
	var c := fit_c
	var yaw := float(p.get("yaw", 0.0))
	# local frame: x along the rect's long side, the look is axis-aligned
	var sx := rect.size.x
	var sz := rect.size.y
	var into := Vector3(-sin(yaw), 0.0, -cos(yaw))   # a mounted piece's body is this way
	root.position = Vector3(c.x, pos.y, c.y) + shift
	root.scale = Vector3(fit_k, 1.0, fit_k)
	var long_x := sx >= sz
	var L := maxf(sx, sz)
	var W := minf(sx, sz)
	var along := Vector3.RIGHT if long_x else Vector3.BACK
	var across := Vector3.BACK if long_x else Vector3.RIGHT
	match look:
		"low_table":
			var tl := minf(L, 1.4)
			var tw := minf(W, 0.85)
			var top := float(TOPS["low_table"])
			var wood := "dark_wood" if culture(plan) == "minka" else "wood"
			_box(root, _sz(along, tl, across, tw, 0.04), Vector3(0, top - 0.02, 0), wood)
			for a: float in [-1.0, 1.0]:
				for b: float in [-1.0, 1.0]:
					var at := along * (tl * 0.5 - 0.07) * a + across * (tw * 0.5 - 0.07) * b
					_box(root, Vector3(0.05, top - 0.04, 0.05), at + Vector3(0, (top - 0.04) * 0.5, 0), wood)
		"zabuton":
			var zs := minf(0.52, W - 0.02)
			_box(root, Vector3(zs, 0.07, zs), Vector3(0, 0.035, 0), "indigo")
		"zabuton_row":
			var n := clampi(int(L / 0.62), 1, 4)
			for k in range(n):
				var t := (float(k) + 0.5) / float(n) - 0.5
				var zr := minf(0.52, W - 0.02)
				_box(root, Vector3(zr, 0.07, zr), along * t * L + Vector3(0, 0.035, 0), "indigo")
		"futon":
			var fl := minf(L, 2.0)
			var fw := minf(W, 1.0)
			_box(root, _sz(along, fl, across, fw, 0.09), Vector3(0, 0.045, 0), "cotton")
			_box(root, _sz(along, fl * 0.62, across, fw * 0.96, 0.06),
				along * (fl * 0.19) + Vector3(0, 0.12, 0), "indigo")
			var head := _head_dir(yaw, along)
			_box(root, _sz(along, 0.22, across, 0.42, 0.1), head * (fl * 0.5 - 0.15) + Vector3(0, 0.14, 0), "straw")
		"tansu":
			var h := _tansu_height(p, String(p.get("key", "")))
			var tl2 := minf(L, 1.2)
			var tw2 := minf(W, 0.45)
			_box(root, _sz(along, tl2, across, tw2, h), Vector3(0, h * 0.5, 0), "dark_wood")
			# drawer fronts and iron pulls on the room side
			var front := _front_dir(plan, p, across)
			var rows := clampi(int(h / 0.22), 2, 4)
			for k in range(rows):
				var y := (float(k) + 0.5) * h / float(rows)
				_box(root, _sz(along, tl2 * 0.9, across, 0.012, 0.012),
					front * (tw2 * 0.5) + Vector3(0, (float(k) + 1.0) * h / float(rows) - 0.01, 0), "wood")
				for s: float in [-0.25, 0.25]:
					_box(root, _sz(along, 0.09, across, 0.02, 0.04), front * (tw2 * 0.5 + 0.01)
						+ along * tl2 * s + Vector3(0, y, 0), "iron")
		"tokonoma":
			var front2 := _front_dir(plan, p, across)
			var dl := minf(L, 1.35)
			var dw := minf(W, 0.42)
			var top2 := float(TOPS["tokonoma"])
			_box(root, _sz(along, dl, across, dw, top2), Vector3(0, top2 * 0.5, 0), "pale_wood")
			_box(root, _sz(along, dl, across, 0.06, 0.06), front2 * (dw * 0.5 - 0.03) + Vector3(0, top2 + 0.01, 0), "lacquer")
			# the hanging scroll on the wall behind, and a vase on the dais
			var back := -front2 * (dw * 0.5 - 0.02)
			_box(root, _sz(along, 0.42, across, 0.01, 1.05), back + Vector3(0, top2 + 0.95, 0), "scroll")
			_box(root, _sz(along, 0.2, across, 0.012, 0.5), back + front2 * 0.005 + Vector3(0, top2 + 1.0, 0), "ink")
			_box(root, _sz(along, 0.48, across, 0.02, 0.025), back + Vector3(0, top2 + 1.49, 0), "dark_wood")
			_jar(root, 0.09, 0.3, along * (dl * 0.25) + Vector3(0, top2, 0), "ceramic")
		"wall_andon", "clay_lamp_wall":
			# pos is the wall mount at the light's height; the body is `into`
			root.position = Vector3(pos.x, pos.y, pos.z) + shift
			if look == "wall_andon":
				_box(root, Vector3(0.05, 0.05, 0.05) + _abs(into) * 0.12, into * 0.08, "dark_wood")
				_box(root, Vector3(0.18, 0.26, 0.18), into * 0.2 + Vector3(0, -0.02, 0), "paper")
				_box(root, Vector3(0.2, 0.025, 0.2), into * 0.2 + Vector3(0, 0.12, 0), "dark_wood")
			else:
				_box(root, Vector3(0.06, 0.04, 0.06) + _abs(into) * 0.16, into * 0.1 + Vector3(0, -0.06, 0), "earth")
				_cyl(root, 0.06, 0.08, 0.05, into * 0.14 + Vector3(0, -0.04, 0), "clay")
				_ball(root, 0.025, 0.06, into * 0.14 + Vector3(0, 0.04, 0), "flame")
		"paper_lantern", "clay_lamp_hanging":
			root.position = Vector3(pos.x, pos.y, pos.z)
			_cyl(root, 0.006, 0.006, 0.55, Vector3(0, -0.55, 0), "rope", 4)
			if look == "paper_lantern":
				_ball(root, 0.2, 0.46, Vector3(0, -0.8, 0), "paper")
				_cyl(root, 0.08, 0.08, 0.03, Vector3(0, -0.58, 0), "dark_wood")
			else:
				_ball(root, 0.13, 0.22, Vector3(0, -0.66, 0), "calabash")
				_ball(root, 0.03, 0.07, Vector3(0, -0.53, 0), "flame")
		"andon":
			_box(root, Vector3(0.16, 0.34, 0.16), Vector3(0, 0.19, 0), "paper")
			_box(root, Vector3(0.2, 0.025, 0.2), Vector3(0, 0.37, 0), "dark_wood")
			for a: float in [-1.0, 1.0]:
				for b: float in [-1.0, 1.0]:
					_box(root, Vector3(0.02, 0.04, 0.02), Vector3(a * 0.08, 0.02, b * 0.08), "dark_wood")
		"andon_small":
			_box(root, Vector3(0.09, 0.16, 0.09), Vector3(0, 0.09, 0), "paper")
			_box(root, Vector3(0.11, 0.015, 0.11), Vector3(0, 0.175, 0), "dark_wood")
		"plank_chest":
			# a plain boarded chest with a flat lid and two iron straps
			var cl := minf(L, 1.1)
			var cw := minf(W, 0.6)
			_box(root, _sz(along, cl, across, cw, 0.5), Vector3(0, 0.25, 0), "wood")
			_box(root, _sz(along, cl + 0.02, across, cw + 0.02, 0.05), Vector3(0, 0.52, 0), "dark_wood")
			for s2: float in [-0.3, 0.3]:
				_box(root, _sz(along, 0.05, across, cw + 0.03, 0.51), along * cl * s2 + Vector3(0, 0.27, 0), "iron")
		"clay_lamp":
			_cyl(root, 0.05, 0.07, 0.045, Vector3.ZERO, "clay")
			_ball(root, 0.02, 0.05, Vector3(0, 0.06, 0), "flame")
		"tea_cup":
			_cyl(root, 0.03, 0.04, 0.06, Vector3.ZERO, "ceramic")
		"clay_cup":
			_cyl(root, 0.035, 0.045, 0.07, Vector3.ZERO, "clay")
		"lacquer_bowl":
			_cyl(root, 0.05, 0.08, 0.06, Vector3.ZERO, "lacquer")
		"calabash":
			_cyl(root, 0.06, 0.13, 0.07, Vector3.ZERO, "calabash")
		"chopsticks":
			for s: float in [-0.012, 0.012]:
				_box(root, _sz(along, 0.22, across, 0.008, 0.008), across * s + Vector3(0, 0.004, 0), "lacquer")
		"wooden_spoon":
			_box(root, _sz(along, 0.2, across, 0.025, 0.012), Vector3(0, 0.006, 0), "wood")
		"tokkuri":
			_jar(root, 0.05, 0.18, Vector3.ZERO, "ceramic")
		"clay_flask":
			_jar(root, 0.06, 0.2, Vector3.ZERO, "clay")
		"low_stool":
			_cyl(root, 0.15, 0.16, 0.06, Vector3(0, 0.2, 0), "wood")
			_cyl(root, 0.12, 0.06, 0.2, Vector3.ZERO, "wood", 8)
		"banco_bench":
			var top3 := float(TOPS["banco_bench"])
			_box(root, _sz(along, L, across, minf(W, 0.5), top3), Vector3(0, top3 * 0.5, 0), "earth")
		"rope_bed":
			var bl := minf(L, 2.0)
			var bw := minf(W, 1.0)
			_box(root, _sz(along, bl, across, bw, 0.06), Vector3(0, 0.33, 0), "wood")
			_box(root, _sz(along, bl * 0.96, across, bw * 0.94, 0.03), Vector3(0, 0.375, 0), "straw")
			for a: float in [-1.0, 1.0]:
				for b: float in [-1.0, 1.0]:
					_box(root, Vector3(0.06, 0.3, 0.06), along * (bl * 0.5 - 0.05) * a
						+ across * (bw * 0.5 - 0.05) * b + Vector3(0, 0.15, 0), "wood")
			_box(root, _sz(along, bl * 0.5, across, bw * 0.9, 0.025), along * (-bl * 0.2) + Vector3(0, 0.4, 0), "indigo")
		"pallet":
			var pl := minf(L, 2.0)
			var pw := minf(W, 1.0)
			# a low plank frame lying on the floor, a straw tick and a hide
			_box(root, _sz(along, pl, across, pw, 0.12), Vector3(0, 0.06, 0), "wood")
			_box(root, _sz(along, pl * 0.94, across, pw * 0.9, 0.12), Vector3(0, 0.18, 0), "straw")
			_box(root, _sz(along, pl * 0.55, across, pw * 0.95, 0.03), along * (-pl * 0.18) + Vector3(0, 0.255, 0), "wool")
		"banco_shelf":
			# an earthen bench-shelf against the wall, pots at its ends
			var top5 := float(TOPS["banco_shelf"])
			var sl := minf(L, 1.3)
			var sw := minf(W, 0.42)
			_box(root, _sz(along, sl, across, sw, top5), Vector3(0, top5 * 0.5, 0), "earth")
			_jar(root, 0.1, 0.26, along * (sl * 0.5 - 0.14) + Vector3(0, top5, 0), "clay")
			_jar(root, 0.08, 0.2, along * (-sl * 0.5 + 0.12) + Vector3(0, top5, 0), "dark_clay")
		"grain_jar":
			_jar(root, minf(W, 0.6) * 0.5, minf(0.95, maxf(L, W) * 0.9), Vector3.ZERO, "clay")
		"storage_pot":
			_jar(root, minf(W, 0.7) * 0.5, 0.8, Vector3.ZERO, "clay")
		"storage_pots":
			var count := clampi(int(L / 0.42), 1, 3)
			for k in range(count):
				var t2 := (float(k) + 0.5) / float(count) - 0.5
				var r := minf(W * 0.5, L / float(count) * 0.45)
				_jar(root, r, r * 2.4 + 0.1 * float(k % 2), along * t2 * L, "clay" if k % 2 == 0 else "dark_clay")
		"water_jar":
			_jar(root, minf(W, 0.48) * 0.5, 0.5, Vector3.ZERO, "dark_clay")
			_cyl(root, 0.07, 0.11, 0.05, Vector3(0.0, 0.5, 0.0), "calabash")
		"basket":
			_cyl(root, minf(W, 0.6) * 0.42, minf(W, 0.6) * 0.5, minf(0.45, W * 0.7), Vector3.ZERO, "straw")
		"grinding_stone":
			var top4 := float(TOPS["grinding_stone"])
			var gl := minf(L, 1.6)
			var gw := minf(W, 0.7)
			_box(root, _sz(along, gl, across, gw, top4), Vector3(0, top4 * 0.5, 0), "earth")
			_box(root, _sz(along, 0.55, across, 0.32, 0.07), along * (-gl * 0.22) + Vector3(0, top4 + 0.035, 0), "stone")
			_box(root, _sz(along, 0.16, across, 0.24, 0.06), along * (-gl * 0.22) + Vector3(0, top4 + 0.1, 0), "stone")
		_:
			pass
	return root


static func _sz(along: Vector3, l: float, across: Vector3, w: float, h: float) -> Vector3:
	return _abs(along) * l + _abs(across) * w + Vector3(0, h, 0)


static func _abs(v: Vector3) -> Vector3:
	return Vector3(absf(v.x), absf(v.y), absf(v.z))


## The side of a wall piece that faces the room: from its yaw (its back is
## to the wall), resolved onto the across axis of its rect.
static func _front_dir(_plan: HousePlan, p: Dictionary, across: Vector3) -> Vector3:
	var yaw := float(p.get("yaw", 0.0))
	var facing := Vector3(-sin(yaw), 0.0, -cos(yaw))
	return across if facing.dot(across) >= 0.0 else -across


## The head end of a bed: the end its back (yaw) points away from.
static func _head_dir(yaw: float, along: Vector3) -> Vector3:
	var facing := Vector3(-sin(yaw), 0.0, -cos(yaw))
	return -along if facing.dot(along) >= 0.0 else along

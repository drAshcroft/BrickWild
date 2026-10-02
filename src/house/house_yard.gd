class_name HouseYard
extends RefCounted
## What stands outside a house: the yard (EVAL-B06).
##
## The plan owns it. A house is dressed in two layers:
##
##   * `plan.exterior`  the facade pieces on the wall itself (HouseExterior):
##     a lantern, a bench, a barrel on the service wall;
##   * `plan.yard`      measured catalogue props on the ground beyond them, and
##     `plan.yard_pieces` the BUILT things the catalogue has no model for -- a
##     fence of rails, a woodpile, a washing line, a midden, a charcoal lean-to.
##
## Props are instantiated by HouseAssembler and nowhere else. Pieces are
## emitted by HouseBuilder through `component_box` with host "yard", so exterior
## QA sees them; both are planned here, in metres and rectangles, with no model
## loaded and no RNG shared with the interior (the yard draws from its own
## generator, so dressing the yard can never move a chair).
##
## Hosts: "front" (the entrance's own wall), "side", "rear", "porch", "chimney"
## and "path". The yard ENVELOPE is the shell footprint (porch and chimney
## stack included) grown by `HouseSpec.yard_apron` -- a 2 to 3 m apron, by
## style. Nothing is planned outside it: the lot owns the rest.
##
## One choice a painter made: a yard says who lives here before you reach the
## door. The recipe is one entrance feature (the stepping-stone path and what
## flanks it), then one or two working groups, never a scatter. A smith's yard
## is a quench trough, a cart and a charcoal lean-to; a cottage keeps a fenced
## kitchen garden and a washing line; a farm has its woodpile, its cart and
## its midden; an inn a signpost and its barrels; an alchemist a herb bed and
## drying line; a longhall its weapon stand and training dummy.

## Style apron, metres. A townhouse is tight to its street; a farm sprawls.
const APRON := {&"cottage": 2.6, &"farmhouse": 3.0, &"townhouse": 2.0,
	&"longhall": 2.8, &"witch_hut": 2.6}
const DEFAULT_APRON := 2.5

## A thing this low is a path, not an obstacle: it is walked over, and it may
## lie across a door approach (the path to the door does).
const FLUSH := 0.12
## Walkers: an obstacle must reach above this and start below head height.
const STEP := 0.2
const HEAD := 1.7
## Clearance kept between two things in the yard.
const GAP := 0.05

## What the household does, in order of importance. A trade adds its working
## groups; the style contributes the first of its own when there is a trade
## and up to two when there is none.
const STYLE_GROUPS := {
	&"cottage": [&"washing_line", &"garden", &"flowers"],
	&"farmhouse": [&"woodpile", &"cart", &"midden"],
	&"townhouse": [&"crates", &"rain_barrel"],
	&"longhall": [&"woodpile", &"training"],
	&"witch_hut": [&"herb_bed", &"drying_line", &"mushrooms", &"midden"],
}
const TRADE_GROUPS := {
	&"none": [],
	&"smith": [&"trough", &"leanto", &"cart"],
	&"farmer": [&"woodpile", &"cart"],
	&"innkeeper": [&"signpost", &"tap_barrels", &"cart"],
	&"alchemist": [&"herb_bed", &"drying_line"],
	&"scholar": [&"flowers"],
}
## The most working groups a yard takes, besides the path and the porch pail.
const MAX_GROUPS := 3

## Built-piece kinds, for the check.
const KINDS := ["fence", "woodpile", "washing_line", "midden", "leanto", "trough",
	"signpost", "bed", "path"]

const HERBS := ["Wild_Plant_7", "Wild_Fern_1", "Wild_Plant_1", "Nature_Flower_3_Clump", "Wild_Fern_1", "Wild_Plant_7"]


# ---------------------------------------------------------------- the envelope

## The apron, metres: the spec's own when it set one, the style's otherwise.
static func apron(spec: HouseSpec) -> float:
	if spec.yard_apron > 0.0:
		return spec.yard_apron
	return float(APRON.get(spec.style, DEFAULT_APRON))


## Does this plan get a yard at all? A rectangular dwelling does. Courts,
## polygon shells, and the shop/hotel/castle families dress their own ground.
static func applies(plan: HousePlan) -> bool:
	var spec := plan.spec
	if not spec.exterior_props or spec.has_method("room_program"):
		return false
	if HouseGeometry.is_shaped(plan) or plan.has_court():
		return false
	return plan.entrance() >= 0


## Does this plan stand on open ground with a road edge to walk from? A house, a
## shop and a hotel do. A courtyard or shaped plan opens its doors onto its own
## court and a castle interior stands inside masonry: there is no road edge to
## reach them from, and the access rule has nothing to say (EVAL-C14).
static func has_road_edge(plan: HousePlan) -> bool:
	return plan.spec.exterior_props and not HouseGeometry.is_shaped(plan) 		and not plan.has_court()


# --------------------------------------------------------------------- planning

## Plan the yard into `plan.yard` and `plan.yard_pieces`. Deterministic: the same
## plan always gets the same yard, from a generator of its own.
static func plan(p: HousePlan) -> void:
	p.yard.clear()
	p.yard_pieces.clear()
	if not applies(p):
		return
	var ctx := _context(p)
	var wanted: Array[StringName] = [&"path", &"porch_pail"]
	var groups: Array = TRADE_GROUPS.get(p.spec.trade, [])
	var style: Array = STYLE_GROUPS.get(p.spec.style, [])
	var from_style: Array = style.slice(0, 1 if not groups.is_empty() else 2)
	for g in groups + from_style:
		if g not in wanted and wanted.size() < MAX_GROUPS + 2:
			wanted.append(g)
	for g in wanted:
		var made := _group(ctx, g)
		if made.is_empty():
			p.exterior_omissions.append("yard %s: no clear ground" % g)
			continue
		_accept(ctx, g, made)
	# The one thing that must survive: a person can walk from the road to the
	# door. Take groups back, last first, until they can.
	while not ctx["order"].is_empty() and not access_ok(p):
		var last: String = ctx["order"].pop_back()
		var kept_props: Array[Dictionary] = []
		for prop in p.yard:
			if str(prop["group"]) != last:
				kept_props.append(prop)
		p.yard = kept_props
		var kept_pieces: Array[Dictionary] = []
		for piece in p.yard_pieces:
			if str(piece["group"]) != last:
				kept_pieces.append(piece)
		p.yard_pieces = kept_pieces
		p.exterior_omissions.append("yard %s: removed to keep the approach open" % last)


static func _context(p: HousePlan) -> Dictionary:
	var spec := p.spec
	var door: Dictionary = p.doors[p.entrance()]
	var n: Vector2 = door["normal"]
	var fwd := Vector2(0, -1)
	if absf(n.x) > absf(n.y):
		fwd = Vector2(signf(n.x), 0)
	else:
		fwd = Vector2(0, signf(n.y))
	var lat := Vector2(-fwd.y, fwd.x)
	var site := HouseGeometry.site_rect(spec)
	var half := site.size * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("yard|%d|%s|%s" % [spec.seed, spec.style, spec.trade])
	var ctx := {"plan": p, "fwd": fwd, "lat": lat, "ext_f": half.dot(fwd.abs()),
		"ext_l": half.dot(lat.abs()), "env": HouseGeometry.yard_rect(p),
		"door_u": Vector2(door["pos"]).dot(lat), "door": door, "rng": rng,
		"side_pref": 1.0 if rng.randf() < 0.5 else -1.0,
		"order": [] as Array[String], "counts": {}, "accepted": [] as Array[AABB]}
	for e in p.exterior:
		(ctx["accepted"] as Array).append(HouseExterior.bounds_of(e))
	return ctx


## Record an accepted group in the plan and the ctx.
static func _accept(ctx: Dictionary, name: StringName, made: Dictionary) -> void:
	var p: HousePlan = ctx["plan"]
	var n: int = int(ctx["counts"].get(name, 0))
	ctx["counts"][name] = n + 1
	var tag := "%s#%d" % [name, n]
	ctx["order"].append(tag)
	for prop in made.get("props", []):
		prop["id"] = "yard_%d" % p.yard.size()
		prop["group"] = tag
		prop["bounds"] = HouseExterior.bounds_of(prop)
		prop["rect"] = Rect2(Vector2(prop["bounds"].position.x, prop["bounds"].position.z),
			Vector2(prop["bounds"].size.x, prop["bounds"].size.z))
		p.yard.append(prop)
		(ctx["accepted"] as Array).append(prop["bounds"])
	for piece in made.get("pieces", []):
		piece["id"] = "%s_%d" % [piece["kind"], p.yard_pieces.size()]
		piece["group"] = tag
		piece["rect"] = piece_rect(piece)
		p.yard_pieces.append(piece)
		for part in piece["parts"]:
			(ctx["accepted"] as Array).append(part_aabb(part))


# -------------------------------------------------------------------- the cells

## A cell is a place on one wall: `o` the point on the wall face, `out` the unit
## vector away from it, `tan` the unit vector along it. A thing is described in
## (t, d): t along the wall, d out from it.
static func _cell(ctx: Dictionary, region: String, s: float) -> Dictionary:
	var fwd: Vector2 = ctx["fwd"]
	var lat: Vector2 = ctx["lat"]
	var out := fwd
	var tangent := lat
	var ext: float = ctx["ext_f"]
	match region:
		"rear":
			out = -fwd
		"left":
			out = lat
			tangent = fwd
			ext = ctx["ext_l"]
		"right":
			out = -lat
			tangent = fwd
			ext = ctx["ext_l"]
	var env: Rect2 = ctx["env"]
	var reach := _extent(env, out)
	return {"region": region, "out": out, "tan": tangent,
		"o": out * ext + tangent * s, "room": reach - ext, "s": s,
		"host": _host(ctx, region)}


static func _host(ctx: Dictionary, region: String) -> String:
	match region:
		"front":
			return "front"
		"rear":
			return "rear"
	return "side"


## World point of cell coordinates.
static func _w(cell: Dictionary, t: float, d: float) -> Vector2:
	return (cell["o"] as Vector2) + (cell["tan"] as Vector2) * t + (cell["out"] as Vector2) * d


## The tangent offsets a region offers, nearest `anchor` first.
static func _slots(ctx: Dictionary, region: String, anchor: float) -> Array[float]:
	var reach: float = ctx["ext_l"] + 0.8 if region in ["front", "rear"] else ctx["ext_f"] - 0.4
	var out: Array[float] = []
	var s := -reach
	while s <= reach + 0.001:
		out.append(s)
		s += 0.5
	var pref: float = ctx["side_pref"]
	out.sort_custom(func(a: float, b: float) -> bool:
		return absf(a - anchor) + 0.002 * pref * signf(a - anchor) \
			< absf(b - anchor) + 0.002 * pref * signf(b - anchor))
	return out


# ------------------------------------------------------------------- the groups

static func _group(ctx: Dictionary, name: StringName) -> Dictionary:
	match name:
		&"path":
			return _path(ctx)
		&"porch_pail":
			return _porch_pail(ctx)
		&"garden":
			return _search(ctx, ["rear", "left", "right"], _kitchen_anchor(ctx, 0.0), [0.5, 0.9],
				func(cell: Dictionary, gap: float) -> Dictionary: return _garden(ctx, cell, gap))
		&"washing_line":
			return _search(ctx, ["left", "right", "rear"], 0.0, [0.9, 1.4],
				func(cell: Dictionary, gap: float) -> Dictionary: return _washing_line(cell, gap, 3.0, true))
		&"drying_line":
			return _search(ctx, ["left", "right", "rear"], 0.0, [0.9, 1.3],
				func(cell: Dictionary, gap: float) -> Dictionary: return _washing_line(cell, gap, 2.0, false))
		&"flowers":
			return _flowers(ctx)
		&"woodpile":
			return _woodpile(ctx)
		&"cart":
			return _search(ctx, ["left", "right", "rear", "front"], 0.0, [0.5, 1.2],
				func(cell: Dictionary, gap: float) -> Dictionary:
					return _prop_group(ctx, cell, gap, "Dungeon_Cart", 0.4, "cart"))
		&"midden":
			return _search(ctx, ["rear", "left", "right"], ctx["ext_l"] * -ctx["side_pref"], [1.4, 1.1],
				func(cell: Dictionary, gap: float) -> Dictionary: return _midden(cell, gap))
		&"crates":
			return _search(ctx, ["left", "right", "rear"], 0.0, [0.15, 0.6],
				func(cell: Dictionary, gap: float) -> Dictionary: return _crates(ctx, cell, gap))
		&"rain_barrel":
			return _search(ctx, ["left", "right", "rear", "front"], _chimney_anchor(ctx), [0.15, 0.6],
				func(cell: Dictionary, gap: float) -> Dictionary:
					return _prop_group(ctx, cell, gap, "Barrel", 1.0, "rain_barrel"))
		&"training":
			return _search(ctx, ["front", "left", "right"], ctx["door_u"] + 3.5 * ctx["side_pref"], [1.0, 0.5],
				func(cell: Dictionary, gap: float) -> Dictionary: return _training(ctx, cell, gap))
		&"herb_bed":
			return _search(ctx, ["front", "left", "right", "rear"], ctx["door_u"] - 3.0 * ctx["side_pref"], [0.5, 1.0],
				func(cell: Dictionary, gap: float) -> Dictionary: return _herb_bed(ctx, cell, gap, false))
		&"mushrooms":
			return _search(ctx, ["rear", "left", "right"], 0.0, [0.3, 0.8],
				func(cell: Dictionary, gap: float) -> Dictionary: return _mushrooms(ctx, cell, gap))
		&"trough":
			return _search(ctx, ["left", "right", "front"], 0.0, [0.35, 0.9],
				func(cell: Dictionary, gap: float) -> Dictionary: return _trough(cell, gap))
		&"leanto":
			return _search(ctx, ["left", "right", "rear"], 0.0, [0.0],
				func(cell: Dictionary, gap: float) -> Dictionary: return _leanto(cell))
		&"signpost":
			return _signpost(ctx)
		&"tap_barrels":
			return _search(ctx, ["front", "left", "right"], ctx["door_u"] + 2.4 * ctx["side_pref"], [0.15, 0.6],
				func(cell: Dictionary, gap: float) -> Dictionary: return _tap_barrels(ctx, cell, gap))
	return {}


## Try each region, each distance from the wall, each place along it, in a fixed
## order, and take the first group the clearance rules accept.
static func _search(ctx: Dictionary, regions: Array, anchor: float, gaps: Array,
		builder: Callable) -> Dictionary:
	for region in regions:
		for gap in gaps:
			for s in _slots(ctx, region, anchor):
				var cell := _cell(ctx, region, s)
				var made: Dictionary = builder.call(cell, float(gap))
				if made.is_empty():
					continue
				if _group_reason(ctx, made).is_empty():
					return made
	return {}


## Why a group cannot stand where it is. Empty when it can.
static func _group_reason(ctx: Dictionary, made: Dictionary) -> String:
	var p: HousePlan = ctx["plan"]
	var env: Rect2 = ctx["env"]
	var seen: Array = ctx["accepted"]
	for prop in made.get("props", []):
		var why := clear_reason(p, env, HouseExterior.bounds_of(prop))
		if why.is_empty():
			why = _overlap_reason(seen, HouseExterior.bounds_of(prop))
		if not why.is_empty():
			return why
	for piece in made.get("pieces", []):
		for part in piece["parts"]:
			var box := part_aabb(part)
			var why := clear_reason(p, env, box)
			if why.is_empty():
				why = _overlap_reason(seen, box)
			if not why.is_empty():
				return why
	return ""


static func _overlap_reason(seen: Array, box: AABB) -> String:
	if _is_flush(box):
		for other in seen:
			if not _is_flush(other) and box.grow(GAP).intersects(other):
				return "overlaps another yard piece"
		return ""
	for other in seen:
		if box.grow(GAP).intersects(other):
			return "overlaps another yard piece"
	return ""


static func _is_flush(box: AABB) -> bool:
	return box.position.y + box.size.y <= FLUSH


## THE shared rule. Whether one measured box may stand in this yard: inside the
## envelope, not in the house, not on the porch, and -- unless it is flush with
## the ground -- not in a door approach, a window's drip and shutter, or the
## chimney. The facade half is HouseExterior.facade_clear, the very function
## the facade recipes use. Empty when clear.
static func clear_reason(plan: HousePlan, env: Rect2, box: AABB) -> String:
	var r := Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z))
	if r.position.x < env.position.x - 0.005 or r.position.y < env.position.y - 0.005 \
			or r.end.x > env.end.x + 0.005 or r.end.y > env.end.y + 0.005:
		return "outside the yard envelope"
	var site := HouseGeometry.site_rect(plan.spec)
	var building := AABB(Vector3(site.position.x, 0, site.position.y),
		Vector3(site.size.x, plan.spec.height * plan.spec.storeys, site.size.y))
	if box.intersects(building.grow(-0.01)):
		return "intersects the house wall"
	if _is_flush(box):
		return ""
	var why := HouseExterior.facade_clear(plan, box)
	if not why.is_empty():
		return why
	var porch := HouseGeometry.porch_rect(plan)
	if porch.size.x > 0.0 and box.intersects(AABB(Vector3(porch.position.x, -0.1, porch.position.y),
			Vector3(porch.size.x, HouseGeometry.DOOR_H + 0.6, porch.size.y))):
		return "stands on the porch"
	return ""


# ----------------------------------------------------------- measured prop groups

## One prop standing out from the wall in `cell`, `gap` metres off it, facing out.
static func _prop_at(cell: Dictionary, t: float, gap: float, key: String, scale: float,
		role: String, face: Vector2 = Vector2.ZERO) -> Dictionary:
	var out: Vector2 = cell["out"]
	var dir: Vector2 = out if face == Vector2.ZERO else face
	var yaw := atan2(-dir.x, -dir.y)
	var foot := PropCatalog.footprint_rotated(key, yaw + PropCatalog.face_offset(key)) * scale
	var depth := foot.dot(out.abs())
	var centre := _w(cell, t, gap + depth * 0.5)
	return make_prop(key, centre, yaw, scale, role, str(cell["host"]))


## A prop dropped on a centre. Origin follows the measured centre offset, the
## way the facade pieces do, so bounds_of() and the assembler agree.
static func make_prop(key: String, centre: Vector2, yaw: float, scale: float,
		role: String, host: String) -> Dictionary:
	var rotation := Basis(Vector3.UP, yaw + PropCatalog.face_offset(key))
	var off: Vector3 = rotation * (PropCatalog.centre_offset(key) * scale)
	var prop := {"key": key, "pos": Vector3(centre.x - off.x, 0.0, centre.y - off.z),
		"yaw": yaw, "scale": scale, "role": role, "host": host, "storey": 0,
		"mounted": false}
	prop["bounds"] = HouseExterior.bounds_of(prop)
	return prop


static func _prop_group(ctx: Dictionary, cell: Dictionary, gap: float, key: String,
		scale: float, role: String) -> Dictionary:
	if not PropCatalog.known(key):
		return {}
	return {"props": [_prop_at(cell, 0.0, gap, key, scale, role)]}


static func _porch_pail(ctx: Dictionary) -> Dictionary:
	var door: Dictionary = ctx["door"]
	var w: float = float(door["width"]) + 1.1
	var lean: float = -float(ctx["side_pref"])
	for flip in [1.0, -1.0]:
		var s: float = ctx["door_u"] + lean * flip * (w * 0.5 + 0.45)
		var cell := _cell(ctx, "front", s)
		var made := {"props": [_prop_at(cell, 0.0, 0.15, "Bucket_Wooden_1", 1.0, "porch_pail")]}
		made["props"][0]["host"] = "porch" if ctx["plan"].spec.porch else "front"
		if _group_reason(ctx, made).is_empty():
			return made
	return {}


## The stepping-stone path from the road edge to the door. Flush with the
## ground, so it is walked over and may cross the door approach.
static func _path(ctx: Dictionary) -> Dictionary:
	var env: Rect2 = ctx["env"]
	var cell := _cell(ctx, "front", ctx["door_u"])
	var parts: Array = []
	var d := 0.28
	var porch := HouseGeometry.porch_rect(ctx["plan"])
	# Full walking-width pavers read as an approach, not a tiny scattering of
	# stones. Built geometry also survives a public checkout without Wild art.
	while d < float(cell["room"]) - 0.24:
		var part := _part(cell, "path_paver", 0.0, d, 0.86, 0.46, 0.0, 0.045, "floor")
		var b := part_aabb(part)
		var r := Rect2(Vector2(b.position.x, b.position.z), Vector2(b.size.x, b.size.z))
		var on_porch: bool = porch.size.x > 0.0 and porch.grow(0.05).intersects(r)
		if not on_porch and clear_reason(ctx["plan"], env, b).is_empty() \
				and _overlap_reason(ctx["accepted"], b).is_empty():
			parts.append(part)
		d += 0.50
	return {"pieces": [_piece("path", "approach", parts, "path")]} if not parts.is_empty() else {}


static func _flowers(ctx: Dictionary) -> Dictionary:
	var door: Dictionary = ctx["door"]
	var w: float = float(door["width"]) + 1.1
	var props: Array = []
	var keys := ["Nature_Flower_3_Clump", "Nature_Flower_5_Clump"]
	for flip in [1.0, -1.0]:
		var s: float = ctx["door_u"] + flip * (w * 0.5 + 0.55 + (0.5 if flip == ctx["side_pref"] else 0.0))
		var cell := _cell(ctx, "front", s)
		var prop := _prop_at(cell, 0.0, 0.2, keys[0 if flip > 0.0 else 1], 1.6, "bed_flowers")
		var probe := {"props": [prop]}
		if _group_reason(ctx, probe).is_empty():
			props.append(prop)
	return {"props": props} if not props.is_empty() else {}


static func _crates(ctx: Dictionary, cell: Dictionary, gap: float) -> Dictionary:
	if not PropCatalog.known("Crate_Wooden"):
		return {}
	var a := _prop_at(cell, 0.0, gap, "Crate_Wooden", 0.9, "crates")
	var bounds := HouseExterior.bounds_of(a)
	var span := bounds.size.x if absf((cell["tan"] as Vector2).x) > 0.5 else bounds.size.z
	var b := _prop_at(cell, span + 0.1, gap, "Bag", 1.0, "crates")
	return {"props": [a, b]}


static func _tap_barrels(ctx: Dictionary, cell: Dictionary, gap: float) -> Dictionary:
	var a := _prop_at(cell, 0.0, gap, "Barrel", 1.0, "tap_barrel")
	var b := _prop_at(cell, 0.8, gap, "Barrel_Apples" if ctx["plan"].spec.seed % 2 == 0 else "Barrel", 1.0, "tap_barrel")
	var c := _prop_at(cell, 0.4, gap + 0.72, "Barrel", 1.0, "tap_barrel")
	return {"props": [a, b, c]}


static func _training(ctx: Dictionary, cell: Dictionary, gap: float) -> Dictionary:
	var stand := _prop_at(cell, 0.0, gap, "WeaponStand", 1.0, "weapon_stand")
	var dummy := _prop_at(cell, 1.7, gap, "Dummy", 1.0, "training_dummy")
	return {"props": [stand, dummy]}


static func _mushrooms(ctx: Dictionary, cell: Dictionary, gap: float) -> Dictionary:
	var props: Array = []
	var keys := ["Wild_Mushroom_Common", "Wild_Mushroom_Laetiporus", "Wild_Mushroom_Common"]
	var at := [0.0, 0.55, 1.0]
	var depth := [0.0, 0.25, -0.1]
	for i in 3:
		props.append(_prop_at(cell, at[i], gap + depth[i] + 0.2, keys[i], 0.35, "mushrooms"))
	return {"props": props}


# ----------------------------------------------------------------- built pieces

## A box in cell coordinates: `st` along the wall, `sd` out from it, `h` high from
## `y0`, centred at (t, d). World-aligned, so the part carries no rotation.
static func _part(cell: Dictionary, role: String, t: float, d: float, st: float, sd: float,
		y0: float, h: float, surf: String) -> Dictionary:
	var c := _w(cell, t, d)
	var tan_v: Vector2 = cell["tan"]
	var out_v: Vector2 = cell["out"]
	var size := tan_v.abs() * st + out_v.abs() * sd
	return {"role": role, "surf": surf, "size": Vector3(size.x, h, size.y),
		"centre": Vector3(c.x, y0 + h * 0.5, c.y), "basis": Basis()}


static func part_xform(part: Dictionary) -> Transform3D:
	return Transform3D(part["basis"], part["centre"])


static func part_aabb(part: Dictionary) -> AABB:
	var xf := part_xform(part)
	var half: Vector3 = (part["size"] as Vector3) * 0.5
	var out := AABB(xf * -half, Vector3.ZERO)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				out = out.expand(xf * Vector3(half.x * sx, half.y * sy, half.z * sz))
	return out


static func piece_rect(piece: Dictionary) -> Rect2:
	var r := Rect2()
	var first := true
	for part in piece["parts"]:
		var b := part_aabb(part)
		var pr := Rect2(Vector2(b.position.x, b.position.z), Vector2(b.size.x, b.size.z))
		r = pr if first else r.merge(pr)
		first = false
	return r


static func _piece(kind: String, role: String, parts: Array, host: String) -> Dictionary:
	return {"kind": kind, "role": role, "host": host, "parts": parts}


## A run of posts and two rails from (t0, d0) to (t1, d1), axis-aligned.
static func _fence_run(cell: Dictionary, t0: float, d0: float, t1: float, d1: float,
		parts: Array, gap_from := 0.0, gap_to := 0.0) -> void:
	var along_t := absf(t1 - t0) > absf(d1 - d0)
	var length := absf(t1 - t0) if along_t else absf(d1 - d0)
	var posts := maxi(int(ceil(length / 1.2)), 1)
	for i in posts + 1:
		var f := float(i) / float(posts)
		var t := lerpf(t0, t1, f)
		var d := lerpf(d0, d1, f)
		parts.append(_part(cell, "fence_post", t, d, 0.09, 0.09, 0.0, 1.05, "trim"))
	# rails, skipping a gateway between gap_from and gap_to along the run
	var spans: Array = [[0.0, length]]
	if gap_to > gap_from:
		spans = [[0.0, gap_from], [gap_to, length]]
	for sp in spans:
		if float(sp[1]) - float(sp[0]) < 0.05:
			continue
		var mid: float = (float(sp[0]) + float(sp[1])) * 0.5
		var run: float = float(sp[1]) - float(sp[0])
		var tc: float = lerpf(t0, t1, mid / length)
		var dc: float = lerpf(d0, d1, mid / length)
		for y in [0.42, 0.82]:
			var st: float = run if along_t else 0.05
			var sd: float = 0.05 if along_t else run
			parts.append(_part(cell, "fence_rail", tc, dc, st, sd, y, 0.07, "trim"))


## A fenced kitchen garden: three sides of rails and the wall's side left open
## as a way in, a raised bed, and plants.
static func _garden(ctx: Dictionary, cell: Dictionary, gap: float) -> Dictionary:
	var room: float = cell["room"]
	var d0 := gap + 0.4
	var depth: float = minf(1.7, room - d0 - 0.12)
	if depth < 1.0:
		return {}
	var w := 3.0
	var d1 := d0 + depth
	var parts: Array = []
	_fence_run(cell, -w * 0.5, d1, w * 0.5, d1, parts)
	_fence_run(cell, -w * 0.5, d0, -w * 0.5, d1, parts)
	_fence_run(cell, w * 0.5, d0, w * 0.5, d1, parts)
	_fence_run(cell, -w * 0.5, d0, w * 0.5, d0, parts, w * 0.5 - 0.5, w * 0.5 + 0.5)
	var bed_d := (d0 + d1) * 0.5
	parts.append(_part(cell, "bed_soil", 0.0, bed_d, w - 0.5, depth - 0.5, 0.0, 0.2, "trim"))
	var made := {"pieces": [_piece("fence", "garden", parts, str(cell["host"]))], "props": []}
	var rng: RandomNumberGenerator = ctx["rng"]
	var base := rng.randi()
	for i in 5:
		var key: String = HERBS[(base + i) % HERBS.size()]
		var tt := -w * 0.5 + 0.5 + float(i) * (w - 1.0) / 4.0
		var prop := make_prop(key, _w(cell, tt, bed_d), 0.0, _fit(key, 0.55), "kitchen_garden", str(cell["host"]))
		made["props"].append(_raised(prop, 0.2))
	return made


## A prop standing on something (a raised bed) rather than the ground.
static func _raised(prop: Dictionary, y: float) -> Dictionary:
	var at: Vector3 = prop["pos"]
	at.y = y
	prop["pos"] = at
	prop["bounds"] = HouseExterior.bounds_of(prop)
	return prop


static func _fit(key: String, target: float) -> float:
	var f := PropCatalog.footprint(key)
	return clampf(target / maxf(maxf(f.x, f.y), 0.01), 0.2, 1.4)


static func _herb_bed(ctx: Dictionary, cell: Dictionary, gap: float, fenced: bool) -> Dictionary:
	var w := 2.2
	var depth := 0.9
	var d := gap + depth * 0.5
	var parts: Array = []
	parts.append(_part(cell, "bed_board", 0.0, gap + 0.03, w, 0.06, 0.0, 0.28, "trim"))
	parts.append(_part(cell, "bed_board", 0.0, gap + depth - 0.03, w, 0.06, 0.0, 0.28, "trim"))
	parts.append(_part(cell, "bed_board", -w * 0.5 + 0.03, d, 0.06, depth - 0.12, 0.0, 0.28, "trim"))
	parts.append(_part(cell, "bed_board", w * 0.5 - 0.03, d, 0.06, depth - 0.12, 0.0, 0.28, "trim"))
	parts.append(_part(cell, "bed_soil", 0.0, d, w - 0.12, depth - 0.12, 0.0, 0.22, "trim"))
	var made := {"pieces": [_piece("bed", "herb_bed", parts, str(cell["host"]))], "props": []}
	var rng: RandomNumberGenerator = ctx["rng"]
	var base := rng.randi()
	for i in 4:
		var key: String = HERBS[(base + i) % HERBS.size()]
		var tt := -w * 0.5 + 0.4 + float(i) * (w - 0.8) / 3.0
		var prop := make_prop(key, _w(cell, tt, d), float(i) * 1.1, _fit(key, 0.5), "herbs", str(cell["host"]))
		made["props"].append(_raised(prop, 0.22))
	return made


## Two posts and a line between them, with linen on it.
static func _washing_line(cell: Dictionary, gap: float, length: float, linen: bool) -> Dictionary:
	var parts: Array = []
	for side in [-1.0, 1.0]:
		parts.append(_part(cell, "line_post", side * length * 0.5, gap, 0.1, 0.1, 0.0, 1.95, "trim"))
	parts.append(_part(cell, "line", 0.0, gap, length, 0.02, 1.85, 0.02, "trim"))
	var sheets := 3 if linen else 4
	for i in sheets:
		var t := -length * 0.5 + (float(i) + 0.75) * length / (float(sheets) + 0.5)
		var h := 0.5 if linen else 0.35
		parts.append(_part(cell, "linen" if linen else "herb_bunch", t, gap, 0.5 if linen else 0.18, 0.02,
			1.85 - h, h, "wall" if linen else "trim"))
	return {"pieces": [_piece("washing_line", "washing_line", parts, str(cell["host"]))]}


## Logs end-on to the eye: a stack of short square logs standing between two
## stakes, against the wall under the eaves.
static func _woodpile(ctx: Dictionary) -> Dictionary:
	var anchor := _chimney_anchor(ctx)
	var regions: Array = [_chimney_region(ctx)] if _chimney_region(ctx) != "" else []
	var kitchen := _kitchen_region(ctx)
	if kitchen != "" and kitchen not in regions:
		regions.append(kitchen)
	for r in ["rear", "left", "right"]:
		if r not in regions:
			regions.append(r)
	var rng: RandomNumberGenerator = ctx["rng"]
	var salt := rng.randi()
	return _search(ctx, regions, anchor, [0.12, 0.3],
		func(cell: Dictionary, gap: float) -> Dictionary: return _logs(cell, gap, salt))


static func _logs(cell: Dictionary, gap: float, salt: int) -> Dictionary:
	var parts: Array = []
	var cols := 7
	var rows := 5
	var size := 0.13
	var width := float(cols) * size
	for r in rows:
		for c in cols:
			var jitter := float(((salt >> (r * cols + c) % 20) & 3)) * 0.03
			var length := 0.46 + jitter
			var t := -width * 0.5 + (float(c) + 0.5) * size
			parts.append(_part(cell, "log", t, gap + length * 0.5, size - 0.012, length,
				float(r) * size, size - 0.012, "trim"))
	for side in [-1.0, 1.0]:
		parts.append(_part(cell, "stake", side * (width * 0.5 + 0.04), gap + 0.3, 0.06, 0.06, 0.0, 0.95, "trim"))
	return {"pieces": [_piece("woodpile", "woodpile", parts, str(cell["host"]))]}


static func _midden(cell: Dictionary, gap: float) -> Dictionary:
	var parts: Array = []
	parts.append(_part(cell, "midden_heap", 0.0, gap + 0.5, 1.4, 1.0, 0.0, 0.26, "trim"))
	parts.append(_part(cell, "midden_heap", 0.1, gap + 0.5, 0.9, 0.7, 0.26, 0.2, "trim"))
	parts.append(_part(cell, "midden_heap", -0.15, gap + 0.45, 0.4, 0.3, 0.46, 0.12, "trim"))
	return {"pieces": [_piece("midden", "midden", parts, str(cell["host"]))]}


## The smith's quench trough: a long open box of boards.
static func _trough(cell: Dictionary, gap: float) -> Dictionary:
	var l := 1.3
	var w := 0.5
	var h := 0.5
	var d := gap + w * 0.5
	var parts: Array = []
	parts.append(_part(cell, "trough_floor", 0.0, d, l, w, 0.0, 0.08, "trim"))
	parts.append(_part(cell, "trough_side", 0.0, d - w * 0.5 + 0.03, l, 0.06, 0.0, h, "trim"))
	parts.append(_part(cell, "trough_side", 0.0, d + w * 0.5 - 0.03, l, 0.06, 0.0, h, "trim"))
	parts.append(_part(cell, "trough_end", -l * 0.5 + 0.03, d, 0.06, w - 0.12, 0.0, h, "trim"))
	parts.append(_part(cell, "trough_end", l * 0.5 - 0.03, d, 0.06, w - 0.12, 0.0, h, "trim"))
	return {"pieces": [_piece("trough", "quench_trough", parts, str(cell["host"]))]}


## The charcoal lean-to: two posts, a plank roof sloping away from the wall, and
## a stepped heap of charcoal under it.
static func _leanto(cell: Dictionary) -> Dictionary:
	var w := 2.4
	var depth := 1.5
	var parts: Array = []
	for side in [-1.0, 1.0]:
		parts.append(_part(cell, "leanto_post", side * (w * 0.5 - 0.06), depth, 0.12, 0.12, 0.0, 1.85, "trim"))
	var tan3 := Vector3((cell["tan"] as Vector2).x, 0.0, (cell["tan"] as Vector2).y)
	var out3 := Vector3((cell["out"] as Vector2).x, 0.0, (cell["out"] as Vector2).y)
	var turn := signf(tan3.cross(out3).y)
	var drop := 0.35
	var slope := atan2(drop, depth)
	var roof := _part(cell, "leanto_roof", 0.0, depth * 0.5 + 0.07, w, depth, 1.97 - drop * 0.5, 0.06, "trim")
	roof["basis"] = Basis(tan3, -turn * slope)
	parts.append(roof)
	parts.append(_part(cell, "charcoal", 0.0, 0.55, 1.7, 0.9, 0.0, 0.55, "trim"))
	parts.append(_part(cell, "charcoal", 0.2, 0.55, 1.0, 0.6, 0.55, 0.3, "trim"))
	parts.append(_part(cell, "charcoal", -0.55, 1.2, 0.5, 0.4, 0.0, 0.3, "trim"))
	return {"pieces": [_piece("leanto", "charcoal_leanto", parts, str(cell["host"]))]}


## The inn's signpost, out by the road edge where a rider reads it.
static func _signpost(ctx: Dictionary) -> Dictionary:
	var side: float = ctx["side_pref"]
	for flip in [1.0, -1.0]:
		var s: float = ctx["door_u"] + side * flip * 2.8
		var cell := _cell(ctx, "front", s)
		var d: float = float(cell["room"]) - 0.5
		if d < 1.0:
			continue
		var parts: Array = []
		parts.append(_part(cell, "sign_post", 0.0, d, 0.11, 0.11, 0.0, 2.35, "trim"))
		parts.append(_part(cell, "sign_arm", -side * flip * 0.4, d, 0.8, 0.06, 2.05, 0.06, "trim"))
		parts.append(_part(cell, "sign_board", -side * flip * 0.6, d, 0.62, 0.05, 1.5, 0.45, "trim"))
		var made := {"pieces": [_piece("signpost", "inn_sign", parts, "front")]}
		if _group_reason(ctx, made).is_empty():
			return made
	return {}


# ---------------------------------------------------------------------- anchors

static func _room_of(ctx: Dictionary, kind: StringName) -> int:
	var p: HousePlan = ctx["plan"]
	for i in p.rooms.size():
		if p.rooms[i]["kind"] == kind and HousePlan.record_storey(p.rooms[i]) == 0:
			return i
	return -1


## The wall region a ground-floor room touches, and where along it, preferring
## the back and sides to the front.
static func _kitchen_region(ctx: Dictionary) -> String:
	var info := _kitchen_info(ctx)
	return str(info.get("region", ""))


static func _kitchen_anchor(ctx: Dictionary, fallback: float) -> float:
	return float(_kitchen_info(ctx).get("s", fallback))


static func _kitchen_info(ctx: Dictionary) -> Dictionary:
	var p: HousePlan = ctx["plan"]
	var i := _room_of(ctx, &"kitchen")
	if i < 0:
		return {}
	var rect: Rect2 = p.rooms[i]["rect"]
	var inner := HouseGeometry.site_rect(p.spec).grow(-HouseGeometry.wall_thickness(p.spec))
	for region in ["rear", "left", "right", "front"]:
		var cell := _cell(ctx, region, 0.0)
		var out: Vector2 = cell["out"]
		if absf(_extent(rect, out) - _extent(inner, out)) < 0.4:
			return {"region": region, "s": rect.get_center().dot(cell["tan"] as Vector2)}
	return {}


## How far a rectangle reaches in a direction.
static func _extent(r: Rect2, dir: Vector2) -> float:
	var reach := -INF
	for c in [r.position, r.end, Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y)]:
		reach = maxf(reach, (c as Vector2).dot(dir))
	return reach


static func _chimney_region(ctx: Dictionary) -> String:
	var p: HousePlan = ctx["plan"]
	if not p.spec.chimney:
		return ""
	var c := HouseGeometry.chimney_center(p)
	var site := HouseGeometry.site_rect(p.spec)
	if site.has_point(c):
		return ""
	for region in ["front", "rear", "left", "right"]:
		var cell := _cell(ctx, region, 0.0)
		var out: Vector2 = cell["out"]
		if c.dot(out) > float(ctx["ext_f"] if region in ["front", "rear"] else ctx["ext_l"]) - 0.3:
			return region
	return ""


static func _chimney_anchor(ctx: Dictionary) -> float:
	var region := _chimney_region(ctx)
	if region == "":
		return 0.0
	var c := HouseGeometry.chimney_center(ctx["plan"])
	var cell := _cell(ctx, region, 0.0)
	return c.dot(cell["tan"]) + 1.2 * float(ctx["side_pref"])


# ------------------------------------------------------------------ for checks

## Obstructions the yard puts on the ground: every prop and built part a person
## would have to walk round. Flush things and things overhead are not.
static func obstacles(plan: HousePlan) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for prop in plan.yard:
		var b := HouseExterior.bounds_of(prop)
		if b.position.y + b.size.y > STEP and b.position.y < HEAD:
			out.append(Rect2(Vector2(b.position.x, b.position.z), Vector2(b.size.x, b.size.z)))
	for piece in plan.yard_pieces:
		for part in piece["parts"]:
			var b := part_aabb(part)
			if b.position.y + b.size.y > STEP and b.position.y < HEAD:
				out.append(Rect2(Vector2(b.position.x, b.position.z), Vector2(b.size.x, b.size.z)))
	return out


## The access rule: the front door is reached from the road edge, and so is every
## ground-floor door the bare house would have been reached at. A shell whose own
## chimney stands in its back door is the shell's defect, not the yard's; the yard
## may only never make a reachable door unreachable.
static func access_ok(plan: HousePlan) -> bool:
	if plan.entrance() < 0 or not has_road_edge(plan):
		return true
	var with_yard := HouseExterior.reached_doors(plan, true)
	if plan.entrance() not in with_yard:
		return false
	for d in HouseExterior.reached_doors(plan, false):
		if d not in with_yard:
			return false
	return true


## The ground rectangle holding everything the yard actually placed (props and
## built pieces, the path included); empty when there is none.
static func extent(plan: HousePlan) -> Rect2:
	var r := Rect2()
	var first := true
	for p in plan.yard:
		var b := HouseExterior.bounds_of(p)
		var pr := Rect2(Vector2(b.position.x, b.position.z), Vector2(b.size.x, b.size.z))
		r = pr if first else r.merge(pr)
		first = false
	for piece in plan.yard_pieces:
		r = piece["rect"] if first else r.merge(piece["rect"])
		first = false
	return r


## The catalogue categories this house already puts outside, on the wall and in
## the yard: what a village dressing the same ground must not add again.
static func categories(plan: HousePlan) -> Array[String]:
	var out: Array[String] = []
	for p in plan.exterior + plan.yard:
		var cat := PropCatalog.category(str(p["key"]))
		if cat != "" and cat not in out and str(p.get("host", "")) != "path":
			out.append(cat)
	out.sort()
	return out


## Where the road meets the yard on the line of the front door: the point the
## walk starts from.
static func road_point(plan: HousePlan) -> Vector2:
	var door: Dictionary = plan.doors[plan.entrance()]
	var env := HouseGeometry.yard_rect(plan)
	var n: Vector2 = door["normal"]
	var pos: Vector2 = door["pos"]
	var t := INF
	if absf(n.x) > 0.5:
		t = ((env.end.x if n.x > 0.0 else env.position.x) - pos.x) / n.x
	else:
		t = ((env.end.y if n.y > 0.0 else env.position.y) - pos.y) / n.y
	return pos + n * maxf(t - 0.12, 0.0)

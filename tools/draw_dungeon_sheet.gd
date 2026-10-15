extends SceneTree
## Draw every room of a realised dungeon as a contact sheet: a plan cut at hand
## height above, a section through the middle below. Headless; it samples the
## carve programme, so the sheet shows what a consumer would carve, not what
## the planner meant.
##
##   godot --headless --path . --script res://tools/draw_dungeon_sheet.gd -- \
##       --plan tests/fixtures/dungeon/flooded_ruin_temple_42.plan.json \
##       --out artifacts/dungeon/flooded_ruin.png
##
## Writes the PNG and, beside it, `<out>.md` naming each tile in order.
## Plan: rock dark, floor sand, dais pale, pit black, water blue, obstruction
## brown, doorway green (open) or red (locked); sockets: fixture yellow, light
## orange, set piece magenta. Section, across the short axis: rock dark, air
## pale, floor line sand.

const PX := 0.4            # metres per pixel
const PAD := 6
const COLS := 5
const ROCK := Color(0.18, 0.18, 0.2)
const AIR := Color(0.86, 0.84, 0.78)
const FLOOR := Color(0.83, 0.72, 0.5)
const DAIS := Color(0.95, 0.88, 0.66)
const PIT := Color(0.04, 0.04, 0.08)
const WATER := Color(0.45, 0.62, 0.85)
const BLOCK := Color(0.48, 0.32, 0.2)
const OPEN := Color(0.3, 0.7, 0.35)
const LOCKED := Color(0.8, 0.25, 0.2)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var plan_path := ""
	var out_path := ""
	for i in range(args.size() - 1):
		if args[i] == "--plan":
			plan_path = args[i + 1]
		elif args[i] == "--out":
			out_path = args[i + 1]
	if plan_path == "" or out_path == "":
		printerr("usage: draw_dungeon_sheet.gd -- --plan PLAN.json --out SHEET.png")
		quit(2)
		return
	var payload = JSON.parse_string(FileAccess.get_file_as_string(plan_path))
	var result := DungeonRealiser.realise(payload)
	if not bool(result["ok"]):
		printerr(result["errors"])
		quit(3)
		return
	var geo := DungeonGeometry.new()
	var doc: Dictionary = result["document"]
	var tiles: Array[Image] = []
	var index: Array[String] = ["# %s -- %s" % [plan_path.get_file(), doc["style"]["label"]], ""]
	var n := 0
	for room: Dictionary in doc["rooms"]:
		tiles.append(_tile(room, geo))
		n += 1
		var g: Dictionary = room["grammar"]
		index.append("%d. %s (%s, %s): %s ceiling, %s walls, %s floor; %d doors, %d fixtures%s"
			% [n, room["key"], room["role"], room["archetype"], g["ceiling"], g["walls"], g["floor"],
				(room["doorways"] as Array).size(), (room["sockets"]["fixtures"] as Array).size(),
				"" if (room["sockets"]["set_pieces"] as Array).is_empty()
					else "; set piece " + String(room["sockets"]["set_pieces"][0]["kind"])])
	var tw := 0
	var th := 0
	for t in tiles:
		tw = maxi(tw, t.get_width())
		th = maxi(th, t.get_height())
	var rows := int(ceil(float(tiles.size()) / COLS))
	var sheet := Image.create(COLS * (tw + PAD) + PAD, rows * (th + PAD) + PAD, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.1, 0.1, 0.1))
	for i in range(tiles.size()):
		var t := tiles[i]
		sheet.blit_rect(t, Rect2i(Vector2i.ZERO, t.get_size()),
			Vector2i(PAD + (i % COLS) * (tw + PAD), PAD + (i / COLS) * (th + PAD)))
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	sheet.save_png(out_path)
	var f := FileAccess.open(out_path + ".md", FileAccess.WRITE)
	f.store_string("\n".join(index) + "\n")
	f.close()
	print("wrote %s (%d rooms)" % [out_path, tiles.size()])
	quit(0)


func _tile(room: Dictionary, geo: DungeonGeometry) -> Image:
	var ops: Array = room["carve"]
	var half := Vector2(float(room["size"]["half"][0]), float(room["size"]["half"][1]))
	var ext := half + Vector2.ONE * (geo.tunnel_reach + 1.0)
	var w := int(ext.x * 2.0 / PX)
	var h := int(ext.y * 2.0 / PX)
	var top := float(room["size"]["ceiling"]) + 1.0
	var bottom := -7.0
	var sh := int((top - bottom) / PX)
	# The section cuts across the short axis, where a barrel vault shows its arch.
	var across_z := half.x >= half.y
	var sw := h if across_z else w
	var img := Image.create(maxi(w, sw), h + 3 + sh, false, Image.FORMAT_RGB8)
	img.fill(Color(0.1, 0.1, 0.1))
	var wet := room.has("water")
	for px in range(w):
		var x := -ext.x + (float(px) + 0.5) * PX
		for pz in range(h):
			var z := -ext.y + (float(pz) + 0.5) * PX
			img.set_pixel(px, pz, _plan_colour(ops, x, z, wet and absf(x) < half.x and absf(z) < half.y))
	for px in range(sw):
		var u := -(ext.y if across_z else ext.x) + (float(px) + 0.5) * PX
		for py in range(sh):
			var y := top - (float(py) + 0.5) * PX
			var p := Vector3(0.0, y, u) if across_z else Vector3(u, y, 0.0)
			var c := ROCK if DungeonCarve.solid_at(ops, p) else AIR
			if absf(y) < PX * 0.5:
				c = c.lerp(FLOOR, 0.5)
			img.set_pixel(px, h + 3 + py, c)
	for d: Dictionary in room["doorways"]:
		var locked := String((d["lock"] as Dictionary).get("kind", "")) != ""
		_dot(img, ext, Vector2(float(d["mouth"][0]), float(d["mouth"][2])), LOCKED if locked else OPEN, 4)
	for s: Dictionary in room["sockets"]["lights"]:
		_dot(img, ext, Vector2(float(s["position"][0]), float(s["position"][2])), Color(1, 0.55, 0.1), 2)
	for s: Dictionary in room["sockets"]["fixtures"]:
		_dot(img, ext, Vector2(float(s["position"][0]), float(s["position"][2])), Color(1, 0.95, 0.1), 3)
	for s: Dictionary in room["sockets"]["set_pieces"]:
		_dot(img, ext, Vector2(float(s["position"][0]), float(s["position"][2])), Color(0.9, 0.2, 0.9), 4)
	return img


func _plan_colour(ops: Array, x: float, z: float, wet: bool) -> Color:
	if DungeonCarve.solid_at(ops, Vector3(x, 1.2, z)):
		var any_air := not DungeonCarve.solid_at(ops, Vector3(x, 0.1, z)) \
			or not DungeonCarve.solid_at(ops, Vector3(x, 2.4, z))
		return BLOCK if any_air else ROCK
	if not DungeonCarve.solid_at(ops, Vector3(x, -0.3, z)):
		return PIT if not DungeonCarve.solid_at(ops, Vector3(x, -1.5, z)) else FLOOR.darkened(0.25)
	if DungeonCarve.solid_at(ops, Vector3(x, 0.3, z)):
		return DAIS
	return WATER if wet else FLOOR


func _dot(img: Image, ext: Vector2, p: Vector2, c: Color, r: int) -> void:
	var cx := int((p.x + ext.x) / PX)
	var cz := int((p.y + ext.y) / PX)
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			var x := cx + dx
			var z := cz + dz
			if x >= 0 and z >= 0 and x < img.get_width() and z < int(ext.y * 2.0 / PX):
				img.set_pixel(x, z, c)

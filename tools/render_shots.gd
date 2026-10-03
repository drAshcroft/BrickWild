extends SceneTree
## Renders reference images of the generator's output to artifacts/renders/.
##
## Must run WITHOUT --headless: the headless dummy renderer cannot produce an
## image. It draws into a SubViewport, so no window content is captured.
##
## Run: godot --path . --script res://tools/render_shots.gd

const OUT_DIR := "res://artifacts/renders"
const SHOT := Vector2i(1100, 760)
const SHEET := Vector2i(900, 1180)

var _vp: SubViewport
var _cam: Camera3D
var _root3d: Node3D
var _mesh_inst: MeshInstance3D
var _key_light: DirectionalLight3D
var _fill_light: DirectionalLight3D
var _stage_environment: Environment
var _legacy_light := false
var _mesh_only := false

var _ground_mat: ShaderMaterial
var _atmo: Dictionary = {}
var _family: StringName = &"church"

# EVAL-B01. The key is a warm sun swung 112 degrees round from the camera, so
# the camera sees the shaded faces with the lit edges raking past them and the
# cast shadows fall toward the lens. Every subject has its own camera yaw, so
# the light is placed from the yaw, never fixed in the world. The fill is the
# cool sky on the other side, a quarter of the key. Each family has a time of
# day (ATMOSPHERES); the values the shot used are copied into the manifest.
const KEY_ELEVATION := -29.0
const KEY_CAMERA_OFFSET := -112.0
const KEY_ENERGY := 2.4
const FILL_ELEVATION := -15.0
const FILL_CAMERA_OFFSET := 65.0
const FILL_ENERGY := 0.6

## Time of day and weather per family. `key_elevation` is degrees above the
## horizon. `earth_a`/`earth_b` are the two tones the ground mottles between.
## The haze colour is both the fog and the sky's horizon, so the far ground
## melts into the sky instead of ending on a hard edge.
const ATMOSPHERES := {
	&"church": {"label": "clear late morning, dry meadow",
		"sky_top": "4a74b0", "sky_horizon": "d6dcdc", "haze": "d6dcdc",
		"below": "b9bfba", "earth_a": "6c6d58", "earth_b": "787a60",
		"key_color": "fff0d8", "key_energy": 2.1, "key_elevation": 29.0,
		"fill_color": "cfdcff", "fill_energy": 0.6, "ambient": 0.45},
	&"castle": {"label": "high thin overcast, rough dun field",
		"sky_top": "5f7ea6", "sky_horizon": "cdd0cc", "haze": "cdd0cc",
		"below": "aaa9a0", "earth_a": "5f5d4d", "earth_b": "6a6753",
		"key_color": "ffe9cc", "key_energy": 1.7, "key_elevation": 28.0,
		"fill_color": "c8d4f0", "fill_energy": 0.55, "ambient": 0.4},
	&"house": {"label": "warm afternoon, kept grass",
		"sky_top": "4d7bb8", "sky_horizon": "dcdcd0", "haze": "dcdcd0",
		"below": "bcc0b2", "earth_a": "66714f", "earth_b": "737c59",
		"key_color": "ffe8c8", "key_energy": 2.2, "key_elevation": 31.0,
		"fill_color": "d0dfff", "fill_energy": 0.62, "ambient": 0.45},
	&"temple_dusk": {"label": "dusk, ash-red western sky, cold earth",
		"sky_top": "2e4a82", "sky_horizon": "c9966f", "haze": "c9966f",
		"below": "8a6a58", "earth_a": "58534b", "earth_b": "655c4f",
		"key_color": "ffcc99", "key_energy": 1.6, "key_elevation": 17.0,
		"fill_color": "8ea4d8", "fill_energy": 0.45, "ambient": 0.5},
	&"temple_dark": {"label": "night within, cool blue-grey stone, braziers the only warm light",
		"sky_top": "2b3550", "sky_horizon": "4a4a66", "haze": "2d2d3a",
		"below": "1a191f", "earth_a": "2c2a2a", "earth_b": "353029",
		# EVAL-C09 raised the dark floor so the pylon of the Starless Deep is
		# readable: the colonnade, the floor and the altar in cool blue, the
		# braziers still the only warm light
		"key_color": "ffffff", "key_energy": 0.8, "key_elevation": 42.0,
		"fill_color": "ffffff", "fill_energy": 0.3, "ambient": 0.7,
		# inside the hall the sun comes down the axis, as it always did: the
		# shafts between the columns are the picture
		"key_offset": 49.0, "no_fog": true},
	&"legacy": {"label": "historical VIS-001 stage",
		"sky_top": "6b8cb5", "sky_horizon": "cfd8e0", "haze": "9aa0a0",
		"below": "9aa0a0", "earth_a": "6f7360", "earth_b": "6f7360",
		"key_color": "ffffff", "key_energy": 1.5, "key_elevation": 42.0,
		"fill_color": "ffffff", "fill_energy": 0.35, "ambient": 1.0},
}

const GROUND_SHADER := """
shader_type spatial;
uniform vec3 earth_a : source_color = vec3(0.45, 0.45, 0.30);
uniform vec3 earth_b : source_color = vec3(0.52, 0.50, 0.34);
varying vec3 wp;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x),
		mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float n = vn(wp.xz / 70.0) * 0.5 + vn(wp.xz / 17.0) * 0.3 + vn(wp.xz / 3.2) * 0.2;
	vec3 c = mix(earth_a, earth_b, smoothstep(0.25, 0.75, n));
	c *= 0.93 + 0.14 * vn(wp.xz * 2.7);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
"""


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_build_stage()
	await process_frame
	var args := OS.get_cmdline_user_args()
	_mesh_only = args.has("mesh-only")
	if args.has("refinement"):
		await _shoot_refinement(args)
		quit()
		return
	if args.has("scene-qa"):
		await _shoot_scene_acceptance()
		quit()
		return
	if args.has("vis004"):
		await _shoot_vis004_acceptance()
		quit()
		return
	if args.has("vis005"):
		await _shoot_vis005_acceptance()
		quit()
		return
	if args.has("vis012"):
		await _shoot_vis012_acceptance()
		quit()
		return
	if args.has("vis015"):
		await _shoot_vis015_acceptance()
		quit()
		return
	if args.has("vis011"):
		await _shoot_vis011_acceptance()
		quit()
		return
	if args.has("vis010"):
		await _shoot_vis010_acceptance()
		quit()
		return
	if args.has("hero-domes"):
		await _shoot_hero_domes()
		quit()
		return
	if args.has("vis009"):
		await _shoot_vis009_acceptance()
		quit()
		return
	if args.has("vis007") or args.has("vis007-before"):
		await _shoot_vis007_acceptance("before" if args.has("vis007-before") else "after")
		quit()
		return
	if args.has("visual-qa"):
		var selection: String = args[1] if args.size() > 1 else ""
		await _shoot_visual_acceptance(selection)
		quit()
		return

	var manifest: Array[Dictionary] = []

	# ---- the landmark churches, three-quarter view ----
	for entry in _landmarks():
		var spec: ChurchSpec = _landmark_spec(entry)
		var file: String = "%s.jpg" % entry["key"]
		await _shoot_church(spec, file, 0.72, -0.28, 1.0)
		var row: Dictionary = _describe(entry, spec, file)
		row.merge(_portrait_metadata(entry["seed"], 0.72, -0.28, 1.0))
		row["render_path"] = "mesh_only" if args.has("mesh-only") else "assembled"
		manifest.append(row)

	# ---- feature close-ups ----
	for shot in _detail_shots():
		var spec: ChurchSpec = _landmark_spec(shot["entry"])
		var f: Array = _focus_of(spec, shot["focus"])
		await _shoot_church(spec, shot["file"], shot["yaw"], shot["pitch"], 1.0,
			f[0], f[1])
		var row: Dictionary = {"key": shot["file"].get_basename(), "title": shot["title"],
			"caption": shot["caption"], "file": shot["file"], "kind": "detail"}
		row.merge(_portrait_metadata(shot["entry"]["seed"], shot["yaw"],
			shot["pitch"], 1.0))
		row["render_path"] = "mesh_only" if args.has("mesh-only") else "assembled"
		manifest.append(row)

	# ---- the landmark castles, three-quarter view from the GATE side ----
	# Every one of these puts its entrance at -Z, so the yaws below sit the
	# camera on that side: a castle shot from behind is a wall.
	for entry in _castles():
		var cspec: CastleSpec = _castle_spec(entry)
		var cfile: String = "castle_%s.jpg" % entry["key"]
		await _shoot_castle(cspec, cfile, entry.get("yaw", 0.72),
			entry.get("pitch", -0.30), entry.get("zoom", 1.0),
			"castle_krak_courtyard.jpg" if entry["key"] == "krak" else "")
		var row: Dictionary = _describe_castle(entry, cspec, cfile)
		row.merge(_portrait_metadata(entry["seed"], entry.get("yaw", 0.72),
			entry.get("pitch", -0.30), entry.get("zoom", 1.0)))
		row["render_path"] = "mesh_only" if args.has("mesh-only") else "assembled"
		manifest.append(row)
		if entry["key"] == "krak" and not args.has("mesh-only"):
			manifest.append({"key": "castle_krak_courtyard",
				"title": "Krak des Chevaliers courtyard", "kind": "castle",
				"file": "castle_krak_courtyard.jpg", "seed": entry["seed"],
				"render_path": "assembled",
				"camera": {"view": "bailey-facing aerial",
					"fov_degrees": _cam.fov},
				"bailey_ranges": CastleGenerator.bailey_buildings(cspec).size(),
				"well_planned": not CastleGenerator.bailey_well(cspec).is_empty(),
				"light": _light_metadata(0.0)})

	# ---- furnished cutaways, plus one roof-on multistory exterior ----
	for entry in _houses():
		var made: Array = _house_plan(entry)
		var hfile: String = "house_%s.jpg" % entry["key"]
		await _shoot_house(made[1], hfile, entry.get("yaw", 0.9),
			entry.get("pitch", -0.78), entry.get("zoom", 0.78))
		manifest.append(_describe_house(entry, made[0], made[1], hfile))
	# a close-up of one room, to show the furniture rather than the plan
	var close: Array = _house_plan(_houses()[4])
	await _shoot_house(close[1], "house_room.jpg", 1.5, -0.42, 0.34)
	manifest.append({"key": "house_room", "title": "The common room",
		"caption": "Table, benches drawn up to it, tableware set on it, sconces on the wall -- each placed by a rule and then checked.",
		"file": "house_room.jpg", "kind": "house"})

	# and one of them from outside, with its roof on
	var street: Array = _house_plan(_houses()[4])
	await _shoot_house(street[1], "house_exterior.jpg", 2.4, -0.22, 1.0, false)
	manifest.append({"key": "house_exterior", "title": "A two-storey inn from the lane",
		"caption": "The same generator with the roof left on: thatch, chimney, porch and shuttered windows.",
		"file": "house_exterior.jpg", "kind": "house"})

	# and the rich house from the street, roof on: the ornament is exterior, so
	# a cutaway would photograph none of the thing this style is for
	var rich_ext: Array = _house_plan(_houses()[5])
	await _shoot_house(rich_ext[1], "house_rich_exterior.jpg", 1.15, -0.28, 1.15, false)
	manifest.append({"key": "house_rich_exterior",
		"title": "A rich merchant's house from the street",
		"caption": "Three banded storeys: a crown at the wall head, a belt course at "
			+ "each storey line, pedimented upper windows and an obelisk on the ridge.",
		"file": "house_rich_exterior.jpg", "kind": "house"})

	# ---- the temples, from the door and from above ----
	for entry in _temples():
		var tspec: TempleSpec = _temple_spec(entry)
		await _shoot_temple(tspec, "temple_%s.jpg" % entry["key"], &"axis")
		manifest.append(_describe_temple(entry, tspec, "temple_%s.jpg" % entry["key"]))
	var plan_shot: TempleSpec = _temple_spec(_temples()[0])
	await _shoot_temple(plan_shot, "temple_plan.jpg", &"aerial")
	manifest.append({"key": "temple_plan", "title": "The plan from above",
		"caption": "Roof off: the axis from gate to altar to idol, columns flanking it, the pit bridged on the line, cells down the aisles.",
		"file": "temple_plan.jpg", "kind": "temple"})
	var out_shot: TempleSpec = _temple_spec(_temples()[2])
	await _shoot_temple(out_shot, "temple_exterior.jpg", &"exterior")
	manifest.append({"key": "temple_exterior", "title": "From the road",
		"caption": "The same generator with its roof on.",
		"file": "temple_exterior.jpg", "kind": "temple"})

	# ---- blueprint sheets ----
	for entry in _landmarks():
		if not entry.get("sheet", false):
			continue
		var spec: ChurchSpec = _landmark_spec(entry)
		var file: String = "sheet_%s.jpg" % entry["key"]
		await _shoot_sheet(spec, file)
		manifest.append({"key": "sheet_" + entry["key"],
			"title": "%s — blueprint sheet" % entry["title"],
			"caption": "Plan and south elevation, drawn from the same ChurchGeometry the mesh uses.",
			"file": file, "kind": "sheet"})

	var f := FileAccess.open(OUT_DIR + "/manifest.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(manifest, "\t"))
	f.close()
	print("wrote %d images to %s" % [manifest.size(), OUT_DIR])
	quit()


## The four blueprint references used by VIS-010, without rendering the full
## church/castle/house/temple portrait catalogue.
## Current assembled buildings, not historical-light comparison meshes.
## Usage: -- refinement [neuschwanstein bodiam chambord coiled_rotunda ...]
func _shoot_refinement(args: PackedStringArray) -> void:
	var selected := Array(args)
	selected.erase("refinement")
	var folder := "refinement"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR + "/" + folder))
	var records: Array[Dictionary] = []
	for entry in _castles():
		if not selected.is_empty() and not entry["key"] in selected:
			continue
		var cs := _castle_spec(entry)
		var file := "%s/castle_%s.jpg" % [folder, entry["key"]]
		await _shoot_castle(cs, file, entry.get("yaw", 2.5), entry.get("pitch", -0.3), 1.0,
			folder + "/castle_krak_courtyard.jpg" if entry["key"] == "krak" else "")
		records.append({"key": entry["key"], "seed": entry["seed"], "file": file})
	for entry in _temples():
		if not selected.is_empty() and not entry["key"] in selected:
			continue
		var ts := _temple_spec(entry)
		for mode in [&"axis", &"shrine", &"aerial"]:
			var file := "%s/temple_%s_%s.jpg" % [folder, entry["key"], mode]
			await _shoot_temple(ts, file, mode)
			records.append({"key": entry["key"], "seed": entry["seed"], "file": file})
	var revision: Array = []
	OS.execute("git", ["rev-parse", "HEAD"], revision)
	FileAccess.open(OUT_DIR + "/" + folder + "/manifest.json", FileAccess.WRITE).store_string(
		JSON.stringify({"base_revision": String(revision[0]).strip_edges() if not revision.is_empty() else "unknown",
			"working_tree": true, "utc": Time.get_datetime_string_from_system(true),
			"render_path": "assembled", "subjects": records}, "\t"))


func _shoot_vis010_acceptance() -> void:
	var out := "vis010"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(
		OUT_DIR + "/" + out))
	var keys := ["notre_dame", "chartres", "hagia_sophia", "florence_duomo", "st_basil"]
	var rendered := 0
	for entry in _landmarks():
		if entry["key"] not in keys:
			continue
		var spec: ChurchSpec = _landmark_spec(entry)
		await _shoot_sheet(spec, "%s/sheet_%s.jpg" % [out, entry["key"]])
		rendered += 1
	print("VIS-010 rendered %d blueprint sheets to %s/%s" % [rendered, OUT_DIR, out])


## Fixed-camera portraits of the two VIS-009 roofline subjects.
func _shoot_vis009_acceptance() -> void:
	var out := "visualqa/vis009"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR + "/" + out))
	var rendered := 0
	for entry in _castles():
		if String(entry.key) not in ["neuschwanstein", "chambord"]:
			continue
		var spec := _castle_spec(entry)
		# Chambord's dormered ranges sit inside a very large enceinte. The
		# catalogue-wide framing makes their hierarchy illegible, so this focused
		# acceptance portrait deliberately crops the outermost towers.
		var shot_zoom: float = float(entry.get("zoom", 1.0)) \
			* (0.68 if String(entry.key) == "chambord" else 0.90)
		await _shoot_castle(spec, "%s/%s_front.jpg" % [out, entry.key],
			float(entry.yaw), float(entry.pitch), shot_zoom)
		await _shoot_castle(spec, "%s/%s_raking.jpg" % [out, entry.key],
			float(entry.yaw) - 0.35, float(entry.pitch) - 0.08,
			shot_zoom)
		rendered += 2
	print("VIS-009 rendered %d focused castle views to %s/%s" % [rendered, OUT_DIR, out])


## A fixed camera/seed pair for each visual acceptance subject. The first image
## uses the historical stage; the second changes only the lighting. The sheet
## is ordered exactly like the manifest, two columns per subject.
func _shoot_visual_acceptance(selection := "") -> void:
	var out := "visualqa/acceptance"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR + "/" + out))
	var keys := ["notre_dame", "durham", "hagia_sophia", "bodiam", "krak",
		"himeji", "neuschwanstein"]
	var rows: Array[Dictionary] = []
	for key in keys:
		if not selection.is_empty() and key != selection:
			continue
		var entry: Dictionary = {}
		var church := false
		for candidate in _landmarks():
			if candidate["key"] == key:
				entry = candidate
				church = true
				break
		if entry.is_empty():
			for candidate in _castles():
				if candidate["key"] == key:
					entry = candidate
					break
		var yaw: float = 0.72 if church else float(entry.get("yaw", 0.72))
		var pitch: float = -0.28 if church else float(entry.get("pitch", -0.30))
		var zoom: float = 1.0 if church else float(entry.get("zoom", 1.0))
		var before := "%s/%s_before.jpg" % [out, key]
		var after := "%s/%s_after.jpg" % [out, key]
		var mesh: ArrayMesh
		var colors: Array
		if church:
			var spec: ChurchSpec = _landmark_spec(entry)
			mesh = ChurchBuilder.new().build(spec)
			colors = [spec.stone_color, spec.trim_color, spec.roof_color,
				Color("15171b")]
		else:
			var spec: CastleSpec = _castle_spec(entry)
			mesh = CastleBuilder.new().build(spec)
			colors = [spec.stone_color, spec.trim_color, spec.roof_color,
				Color("15171b")]
		_legacy_light = true
		await _shoot_mesh(mesh, colors, before, yaw, pitch, zoom)
		_legacy_light = false
		await _shoot_mesh(mesh, colors, after, yaw, pitch, zoom)
		rows.append({"key": key, "seed": entry["seed"], "before": before,
			"after": after, "camera": _camera_metadata(yaw, pitch, zoom),
			"before_light": _light_metadata(yaw, true),
			"after_light": _light_metadata(yaw, false)})
	var include_chevet: bool = selection.is_empty() or selection == "chartres_chevet"
	if include_chevet:
		var chapels: Dictionary = _detail_shots()[2]
		var chartres: ChurchSpec = _landmark_spec(chapels["entry"])
		var focus: Array = _focus_of(chartres, "chevet")
		await _shoot_church(chartres, out + "/chartres_chevet.jpg",
			chapels["yaw"], chapels["pitch"], 1.0, focus[0], focus[1])
	if not rows.is_empty():
		_save_acceptance_sheet(rows, out + "/contact_sheet.jpg")
	var data := {"subjects": rows, "columns": ["historical light", "camera-relative light"]}
	if include_chevet:
		data["chevet"] = out + "/chartres_chevet.jpg"
	var f := FileAccess.open(OUT_DIR + "/" + out + "/manifest.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	var image_count: int = rows.size() * 2 + int(not rows.is_empty()) + int(include_chevet)
	print("wrote %d acceptance images and manifest to %s/%s" %
		[image_count, OUT_DIR, out])


## VIS-004 material comparison. Seed, camera and lighting stay fixed in each pair.
func _shoot_vis004_acceptance() -> void:
	var out := "visualqa/vis004"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR + "/" + out))
	var rows: Array[Dictionary] = []
	for key in ["durham", "notre_dame", "bodiam", "himeji"]:
		var entry: Dictionary = {}
		var church := false
		for candidate in _landmarks():
			if candidate["key"] == key:
				entry = candidate
				church = true
				break
		if entry.is_empty():
			for candidate in _castles():
				if candidate["key"] == key:
					entry = candidate
					break
		var yaw: float = 0.72 if church else float(entry.get("yaw", 0.72))
		var pitch: float = -0.28 if church else float(entry.get("pitch", -0.30))
		var zoom: float = 1.0 if church else float(entry.get("zoom", 1.0))
		var mesh: ArrayMesh
		var colors: Array
		if church:
			var spec: ChurchSpec = _landmark_spec(entry)
			mesh = ChurchBuilder.new().build(spec)
			colors = [spec.stone_color, spec.trim_color, spec.roof_color, Color("15171b")]
		else:
			var spec: CastleSpec = _castle_spec(entry)
			mesh = CastleBuilder.new().build(spec)
			colors = [spec.stone_color, spec.trim_color, spec.roof_color, Color("15171b")]
		var before := "%s/%s_before.jpg" % [out, key]
		var after := "%s/%s_after.jpg" % [out, key]
		await _shoot_mesh(mesh, colors, before, yaw, pitch, zoom)
		await _shoot_mesh(mesh, colors, after, yaw, pitch, zoom, Vector3.INF, 0.0, true)
		rows.append({"key": key, "seed": entry["seed"], "before": before,
			"after": after, "camera": _camera_metadata(yaw, pitch, zoom)})
	_save_acceptance_sheet(rows, out + "/contact_sheet.jpg")
	var f := FileAccess.open(OUT_DIR + "/" + out + "/manifest.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"subjects": rows,
		"columns": ["flat materials", "VIS-004 runtime finish"]}, "\t"))
	f.close()
	print("wrote %d VIS-004 pairs and contact sheet to %s" % [rows.size(), out])


## Opening detail comparison. Run at the preceding commit as well as the
## candidate commit; the two runs use identical seeds, cameras and lights.
func _shoot_vis005_acceptance() -> void:
	var out := "visualqa/vis005"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR + "/" + out))
	var rows: Array[Dictionary] = []
	for entry in _landmarks():
		if entry["key"] not in ["notre_dame", "durham"]:
			continue
		var spec: ChurchSpec = _landmark_spec(entry)
		await _shoot_church(spec, "%s/%s_portrait.jpg" % [out, entry["key"]],
			0.72, -0.28)
		var subjects: Array[Dictionary] = [{"name": "west_portal",
			"focus": Vector3(0.0, 2.0, -spec.length / 2.0),
			"radius": 7.5, "yaw": PI, "pitch": -0.12}]
		if entry["key"] == "notre_dame":
			for opening in ChurchGeometry.clerestory_windows(spec):
				if opening.pos.x > 0.0 and absf(opening.pos.z) < spec.length * 0.25:
					subjects.append({"name": "clerestory", "focus": opening.pos,
						"radius": 5.0, "yaw": PI / 2.0, "pitch": -0.08})
					break
		for subject in subjects:
			for light in ["front", "raking"]:
				var file: String = "%s/%s_%s_%s_after.jpg" % [out, entry["key"],
					subject["name"], light]
				var before: String = "%s/%s_%s_%s_before.jpg" % [out,
					entry["key"], subject["name"], light]
				await _shoot_vis005_frame(spec, file, subject["yaw"],
					subject["pitch"], subject["focus"], subject["radius"],
					light == "raking")
				rows.append({"key": entry["key"], "seed": entry["seed"],
					"subject": subject["name"], "light": light,
					"before": before, "after": file,
					"camera": _camera_metadata(subject["yaw"], subject["pitch"], 1.0),
					"key_offset_degrees": -75.0 if light == "raking" else 0.0})
	var f := FileAccess.open(OUT_DIR + "/" + out + "/manifest.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"shots": rows}, "\t"))
	f.close()
	print("wrote %d VIS-005 opening details to %s" % [rows.size(), out])


func _shoot_vis005_frame(spec: ChurchSpec, file: String, yaw: float,
		pitch: float, focus: Vector3, radius: float, raking: bool) -> void:
	_mesh_inst.mesh = null
	var node: Node3D = ChurchAssembler.build(spec, false)
	_root3d.add_child(node)
	await process_frame
	var dist: float = radius / tan(deg_to_rad(_cam.fov) / 2.0) * 1.12
	var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	_cam.position = focus + dir * dist
	_cam.look_at(focus, Vector3.UP)
	_set_shot_lighting(yaw, dist + radius)
	_key_light.rotation.y = yaw + deg_to_rad(-75.0 if raking else 0.0)
	await _capture(file)
	_root3d.remove_child(node)
	node.free()
	_set_legacy_lighting()


## The VIS-005 views again, with the finished opening in the same frame.
func _shoot_vis012_acceptance() -> void:
	var out := "visualqa/vis012"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR + "/" + out))
	var rows: Array[Dictionary] = []
	for entry in _landmarks():
		if entry["key"] not in ["notre_dame", "durham"]:
			continue
		var spec: ChurchSpec = _landmark_spec(entry)
		await _shoot_church(spec, "%s/%s_portrait_after.jpg" % [out, entry["key"]],
			0.72, -0.28)
		var subjects: Array[Dictionary] = [{"name": "west_portal",
			"focus": Vector3(0.0, 2.0, -spec.length / 2.0),
			"radius": 7.5, "yaw": PI, "pitch": -0.12}]
		if entry["key"] == "notre_dame":
			for opening in ChurchGeometry.clerestory_windows(spec):
				if opening.pos.x > 0.0 and absf(opening.pos.z) < spec.length * 0.25:
					subjects.append({"name": "clerestory", "focus": opening.pos,
						"radius": 5.0, "yaw": PI / 2.0, "pitch": -0.08})
					break
		for subject in subjects:
			for light in ["front", "raking"]:
				var file := "%s/%s_%s_%s_after.jpg" % [out, entry["key"],
					subject["name"], light]
				await _shoot_vis005_frame(spec, file, subject["yaw"],
					subject["pitch"], subject["focus"], subject["radius"],
					light == "raking")
				rows.append({"key": entry["key"], "seed": entry["seed"],
					"subject": subject["name"], "light": light,
					"before": file.replace("_after.jpg", "_before.jpg"),
					"after": file,
					"camera": _camera_metadata(subject["yaw"], subject["pitch"], 1.0),
					"key_offset_degrees": -75.0 if light == "raking" else 0.0})
	var f := FileAccess.open(OUT_DIR + "/" + out + "/manifest.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"shots": rows}, "\t"))
	f.close()
	print("wrote %d VIS-012 opening details to %s" % [rows.size(), out])


## Representative exterior hosts after the remaining masonry cuts. The face
## logged by the builder also fixes the camera direction for each detail.
func _shoot_vis011_acceptance() -> void:
	var out := "visualqa/vis011"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR + "/" + out))
	var chosen := {"notre_dame": ["aisle", "tower"],
		"chartres": ["apse", "chapel"],
		"durham": ["crossing_tower"],
		"hagia_sophia": ["dome"],
		"florence_duomo": ["dome"]}
	var rows: Array[Dictionary] = []
	for entry in _landmarks():
		var key: String = entry["key"]
		if not chosen.has(key):
			continue
		var spec: ChurchSpec = _landmark_spec(entry)
		if key in ["notre_dame", "chartres", "florence_duomo"]:
			await _shoot_church(spec, "%s/%s_portrait_after.jpg" % [out, key],
				0.72, -0.28)
		var builder := ChurchBuilder.new()
		builder.build(spec)
		for host_name in chosen[key]:
			var selected: Dictionary = {}
			for part in builder.part_log:
				if part.get("kind", "") == "window" \
						and part.get("tag", "") == host_name \
						and part.get("aperture", "") == "through":
					selected = part
					break
			if selected.is_empty():
				push_error("VIS-011 has no %s window on %s" % [host_name, key])
				continue
			for light in ["front", "raking"]:
				var file := "%s/%s_%s_%s_after.jpg" % [out, key, host_name, light]
				await _shoot_vis005_frame(spec, file, selected.rot_y, -0.08,
					selected.pos, 5.0 if host_name != "dome" else 7.0,
					light == "raking")
				rows.append({"key": key, "seed": entry["seed"],
					"host": host_name, "light": light, "file": file,
					"focus": selected.pos, "face": selected.rot_y,
					"key_offset_degrees": -75.0 if light == "raking" else 0.0})
	var rose_spec := ChurchSpec.new()
	rose_spec.style = &"romanesque"
	rose_spec.width = 12.0
	rose_spec.length = 62.0
	rose_spec.height = 22.0
	ChurchGenerator.generate(rose_spec, 8110)
	rose_spec.rose_window = true
	rose_spec.aisles = 0
	rose_spec.tower = false
	rose_spec.west_towers = 0
	rose_spec.narthex = false
	var rose_builder := ChurchBuilder.new()
	rose_builder.build(rose_spec)
	for part in rose_builder.part_log:
		if part.get("kind", "") != "window" or part.get("tag", "") != "facade":
			continue
		for light in ["front", "raking"]:
			var file := "%s/rose_fixture_%s_after.jpg" % [out, light]
			await _shoot_vis005_frame(rose_spec, file, part.rot_y, -0.08,
				part.pos, 5.0, light == "raking")
			rows.append({"key": "rose_fixture", "seed": 8110,
				"host": "facade", "light": light, "file": file,
				"focus": part.pos, "face": part.rot_y})
		break
	var f := FileAccess.open(OUT_DIR + "/" + out + "/manifest.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"shots": rows}, "\t"))
	f.close()
	print("wrote %d VIS-011 host details to %s" % [rows.size(), out])


## Durham's pier and Notre-Dame's flyer at locked scale, view and light.
func _shoot_vis007_acceptance(label: String) -> void:
	var out := "visualqa/vis007"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR + "/" + out))
	var rows: Array[Dictionary] = []
	for entry in _landmarks():
		if entry["key"] not in ["notre_dame", "durham"]:
			continue
		var spec: ChurchSpec = _landmark_spec(entry)
		await _shoot_church(spec, "%s/%s_portrait_%s.jpg" % [out, entry["key"],
			label], 0.72, -0.28)
		var yaw := 1.25
		var pitch := -0.16
		var focus: Vector3
		var radius: float
		if entry["key"] == "notre_dame":
			var pair: Array = _focus_of(spec, "flyers")
			focus = pair[0]
			radius = pair[1]
		else:
			var bz0: float = -spec.length / 2.0 + 0.8
			if spec.tower:
				bz0 = -spec.length / 2.0 + ChurchGeometry.TOWER_EMBED \
					+ spec.tower_width + 0.4
			var bz1: float = ChurchGeometry.transept_front_z(spec) - 0.6 \
				if spec.transept else spec.length / 2.0 - 0.8
			var count: int = maxi(spec.buttress_count_per_side - 1, 1)
			var bz: float = bz0 + maxf(bz1 - bz0, 2.0) * float(count / 2) / count
			focus = Vector3(spec.width / 2.0 + spec.buttress_depth * 0.4,
				spec.height * 0.42, bz)
			radius = spec.height * 0.58
		var file: String = "%s/%s_%s.jpg" % [out, entry["key"], label]
		await _shoot_church(spec, file, yaw, pitch, 1.0, focus, radius)
		rows.append({"key": entry["key"], "seed": entry["seed"],
			"file": file, "focus": focus, "radius": radius,
			"camera": _camera_metadata(yaw, pitch, 1.0),
			"light": _light_metadata(yaw)})
	var f := FileAccess.open(OUT_DIR + "/" + out + "/manifest_" + label + ".json",
		FileAccess.WRITE)
	f.store_string(JSON.stringify({"shots": rows}, "\t"))
	f.close()
	print("wrote %d VIS-007 %s views" % [rows.size(), label])


## Diagnose the render path with one church and one castle. Both views in each
## pair use the mesh bounds for the camera, so the only change is assembly.
func _shoot_scene_acceptance() -> void:
	var out := "visualqa/scene"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR + "/" + out))
	var rows: Array[Dictionary] = []
	for key in ["notre_dame", "krak"]:
		var church: bool = key == "notre_dame"
		var entry: Dictionary = {}
		for candidate in (_landmarks() if church else _castles()):
			if candidate["key"] == key:
				entry = candidate
				break
		var yaw: float = 0.72 if church else float(entry["yaw"])
		var pitch: float = -0.28 if church else float(entry["pitch"])
		var zoom: float = 1.0 if church else float(entry["zoom"])
		var builder: MassBuilder
		var scene: Node3D
		var mesh: ArrayMesh
		var castle_spec: CastleSpec
		var cols: Array
		if church:
			var spec: ChurchSpec = _landmark_spec(entry)
			builder = ChurchBuilder.new()
			cols = [spec.stone_color, spec.trim_color, spec.roof_color,
				Color("15171b")]
			mesh = builder.build(spec)
			scene = ChurchAssembler.build(spec, false)
		else:
			var spec: CastleSpec = _castle_spec(entry)
			castle_spec = spec
			builder = CastleBuilder.new()
			cols = [spec.stone_color, spec.trim_color, spec.roof_color,
				Color("15171b")]
			mesh = builder.build(spec)
			scene = CastleAssembler.build(spec, false)
		var expected := 0
		for prop in builder.prop_log:
			if ResourceLoader.exists(PropCatalog.scene_path(prop["key"])):
				expected += 1
		var dressing := scene.get_node_or_null("Dressing")
		var actual: int = dressing.get_child_count() if dressing != null else 0
		if actual != expected:
			push_error("%s dressing count %d != %d" % [key, actual, expected])
		await _shoot_scene_pair(mesh, scene, cols, out, key, yaw, pitch, zoom,
			castle_spec)
		rows.append({"key": key, "seed": entry["seed"],
			"mesh": "%s/%s_mesh.jpg" % [out, key],
			"assembled": "%s/%s_assembled.jpg" % [out, key],
			"prop_log_count": builder.prop_log.size(),
			"available_prop_models": expected, "assembled_dressing_count": actual,
			"camera": _camera_metadata(yaw, pitch, zoom)})
		if key == "krak":
			rows.back()["bailey_ranges"] = CastleGenerator.bailey_buildings(castle_spec).size()
			rows.back()["well_planned"] = not CastleGenerator.bailey_well(castle_spec).is_empty()
			rows.back()["courtyard"] = out + "/krak_courtyard.jpg"
	var f := FileAccess.open(OUT_DIR + "/" + out + "/manifest.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(rows, "\t"))
	f.close()
	print("wrote %d scene acceptance images and manifest" % 5)


func _shoot_scene_pair(mesh: ArrayMesh, scene: Node3D, cols: Array,
		out: String, key: String, yaw: float, pitch: float, zoom: float,
		castle_spec: CastleSpec = null) -> void:
	var aabb: AABB = mesh.get_aabb()
	var centre: Vector3 = aabb.get_center()
	var radius: float = maxf(aabb.size.length() / 2.0, 1.0)
	await _shoot_mesh(mesh, cols, "%s/%s_mesh.jpg" % [out, key],
		yaw, pitch, zoom, centre, radius)
	await _shoot_scene(scene, "%s/%s_assembled.jpg" % [out, key],
		yaw, pitch, zoom, centre, radius, castle_spec,
		"%s/krak_courtyard.jpg" % out if castle_spec != null else "")


func _save_acceptance_sheet(rows: Array[Dictionary], file: String) -> void:
	var tile := Vector2i(550, 380)
	var sheet := Image.create(tile.x * 2, tile.y * rows.size(), false, Image.FORMAT_RGB8)
	sheet.fill(Color("22252a"))
	for i in range(rows.size()):
		for col in range(2):
			var path: String = rows[i]["before" if col == 0 else "after"]
			var img := Image.load_from_file(OUT_DIR + "/" + path)
			img.resize(tile.x, tile.y, Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, tile),
				Vector2i(col * tile.x, i * tile.y))
	sheet.save_jpg(OUT_DIR + "/" + file, 0.9)
	print("  ", file)


# ------------------------------------------------------------------ subjects

func _landmarks() -> Array[Dictionary]:
	return [
		{"key": "notre_dame", "style": &"gothic", "title": "Notre-Dame de Paris",
			"w": 12.0, "l": 127.0, "h": 33.0, "seed": 5001, "sheet": true,
			"feat": "flying buttresses, twin west towers, double aisles"},
		{"key": "cologne", "style": &"gothic", "title": "Cologne Cathedral",
			"w": 14.0, "l": 144.0, "h": 43.0, "seed": 5002,
			"feat": "five-aisled, twin spires, flying buttresses"},
		{"key": "chartres", "style": &"gothic", "title": "Chartres Cathedral",
			"w": 16.4, "l": 130.0, "h": 37.5, "seed": 5003, "sheet": true,
			"feat": "double ambulatory, seven radiating chapels"},
		{"key": "salisbury", "style": &"gothic", "title": "Salisbury Cathedral",
			"w": 12.0, "l": 135.0, "h": 26.0, "seed": 5004,
			"feat": "single dominant crossing spire"},
		{"key": "durham", "style": &"romanesque", "title": "Durham Cathedral",
			"w": 11.9, "l": 61.0, "h": 22.2, "seed": 5005,
			"feat": "central lantern tower plus twin west towers"},
		{"key": "hagia_sophia", "style": &"byzantine", "title": "Hagia Sophia",
			"w": 31.0, "l": 76.0, "h": 40.0, "seed": 5006, "sheet": true,
			"feat": "great dome on pendentives, braced by half-domes"},
		{"key": "florence_duomo", "style": &"renaissance", "title": "Florence Duomo",
			"w": 17.0, "l": 153.0, "h": 45.0, "seed": 5007,
			"feat": "octagonal drum, double-shell dome, lantern"},
		{"key": "st_basil", "style": &"russian", "title": "St Basil's Cathedral",
			"w": 24.0, "l": 30.0, "h": 26.0, "seed": 5008, "sheet": true,
			"feat": "onion domes over a cluster of chapels"},
	]


## Florence, St Basil and Hagia Sophia only: their portraits and close-ups
## under the standard names, plus a second and third camera on each so the
## composition (crossing and tribunes, cluster and podium, bearing and arches)
## can be judged from more than the one three-quarter view.
func _shoot_hero_domes() -> void:
	var keys := ["florence_duomo", "st_basil", "hagia_sophia"]
	var by_key := {}
	for entry in _landmarks():
		by_key[entry["key"]] = entry
	for key in keys:
		var entry: Dictionary = by_key[key]
		var spec: ChurchSpec = _landmark_spec(entry)
		await _shoot_church(spec, "%s.jpg" % key, 0.72, -0.28, 1.0)
	for shot in _detail_shots():
		if not (shot["entry"]["key"] in keys):
			continue
		var spec: ChurchSpec = _landmark_spec(shot["entry"])
		var f: Array = _focus_of(spec, shot["focus"])
		await _shoot_church(spec, shot["file"], shot["yaw"], shot["pitch"], 1.0, f[0], f[1])
	var extra := [
		{"key": "florence_duomo", "file": "hero_florence_east.jpg", "yaw": 2.45, "pitch": -0.30},
		{"key": "florence_duomo", "file": "hero_florence_south.jpg", "yaw": 1.45, "pitch": -0.22},
		{"key": "st_basil", "file": "hero_basil_west.jpg", "yaw": -0.55, "pitch": -0.24},
		{"key": "st_basil", "file": "hero_basil_east.jpg", "yaw": 2.5, "pitch": -0.20},
		{"key": "hagia_sophia", "file": "hero_hagia_south.jpg", "yaw": 1.45, "pitch": -0.18},
		{"key": "hagia_sophia", "file": "hero_hagia_east.jpg", "yaw": 2.6, "pitch": -0.30},
	]
	for row in extra:
		var spec: ChurchSpec = _landmark_spec(by_key[row["key"]])
		await _shoot_church(spec, row["file"], row["yaw"], row["pitch"], 1.0)


func _detail_shots() -> Array[Dictionary]:
	var lm: Array[Dictionary] = _landmarks()
	return [
		{"entry": lm[0], "file": "detail_flyers.jpg", "focus": "flyers",
			"yaw": 1.25, "pitch": -0.16, "title": "Flying buttresses",
			"caption": "Pier, parabolic flyer arch and pinnacle, sized to the wall they brace."},
		{"entry": lm[5], "file": "detail_dome.jpg", "focus": "dome",
			"yaw": 0.85, "pitch": -0.20, "title": "Dome on pendentives",
			"caption": "Pendentive course, the window corona round the drum, and the buttressing half-domes."},
		{"entry": lm[2], "file": "detail_chapels.jpg", "focus": "chevet",
			"yaw": 0.45, "pitch": -0.22, "title": "Radiating chapels",
			"caption": "Alcoves fanned off the ambulatory. The fan angle is solved from the geometry, not fixed."},
		{"entry": lm[7], "file": "detail_onion.jpg", "focus": "chapel_onion",
			"yaw": 0.70, "pitch": -0.14, "title": "Onion dome",
			"caption": "A chapel tower: windowed drum, then an ogee dome that bulges past its springing radius and draws in to a cross. Each chapel has its own height and colour."},
		{"entry": lm[6], "file": "detail_lantern.jpg", "focus": "dome",
			"yaw": 1.05, "pitch": -0.18, "title": "Octagonal drum and lantern",
			"caption": "Eight-sided drum carrying the shell, capped by a lantern."},
		{"entry": lm[4], "file": "detail_crossing.jpg", "focus": "crossing",
			"yaw": 0.95, "pitch": -0.24, "title": "Crossing tower",
			"caption": "A lantern tower on the crossing bay, hipped to the rectangle it stands on."},
	]


## Where to point the camera, and how much around it to fit in frame.
func _focus_of(spec: ChurchSpec, kind: String) -> Array:
	match kind:
		"flyers":
			var mid: int = int(ChurchGeometry.flyer_count(spec) / 2)
			return [Vector3(ChurchGeometry.flyer_pier_x(spec, 1.0), spec.height * 0.5,
				ChurchGeometry.flyer_z(spec, mid)), spec.height * 0.62]
		"dome":
			return [Vector3(0.0, ChurchGeometry.dome_base_height(spec)
				+ spec.dome_drum_height * 0.5 + ChurchGeometry.dome_shell_rise(spec) * 0.45,
				ChurchGeometry.crossing_center_z(spec)),
				ChurchGeometry.dome_plan_radius(spec) * 1.9]
		"chapel_onion":
			var tower: int = mini(3, spec.radiating_chapels - 1)
			var dc: Vector3 = ChurchGeometry.chapel_drum_center(spec, tower)
			var body: float = ChurchGeometry.chapel_body_height(spec, tower)
			return [Vector3(dc.x, body + ChurchGeometry.chapel_drum_height(spec, tower) * 0.8
				+ ChurchGeometry.chapel_onion_rise(spec) * 0.35, dc.z),
				ChurchGeometry.chapel_drum_radius(spec) * 5.0]
		"chevet":
			return [Vector3(0.0, spec.height * 0.22,
				ChurchGeometry.apse_springing_z(spec)
				+ ChurchGeometry.ambulatory_radius(spec) * 0.45),
				ChurchGeometry.ambulatory_radius(spec) * 2.8]
		"crossing":
			return [Vector3(0.0, spec.crossing_tower_height * 0.62,
				ChurchGeometry.crossing_center_z(spec)), spec.crossing_tower_height * 0.72]
	return [Vector3.ZERO, 20.0]


func _landmark_spec(entry: Dictionary) -> ChurchSpec:
	_family = &"church"
	var spec := ChurchSpec.new()
	spec.style = entry["style"]
	spec.width = entry["w"]
	spec.length = entry["l"]
	spec.height = entry["h"]
	ChurchGenerator.generate(spec, entry["seed"])
	_force_features(spec, entry["key"])
	return spec


## The generator is probabilistic; these portraits must show the feature the
## church is famous for, so force it on and give it a size if it has none.
func _force_features(spec: ChurchSpec, key: String) -> void:
	match key:
		"notre_dame":
			spec.west_towers = 2
			spec.aisles = 2
			spec.flying_buttresses = true
			spec.apse = true
		"cologne":
			spec.west_towers = 2
			spec.aisles = 2
			spec.flying_buttresses = true
			spec.tower_roof = &"spire"
		"chartres":
			spec.flying_buttresses = true
			spec.apse = true
			spec.ambulatory = true
			spec.radiating_chapels = 7
		"salisbury":
			spec.transept = true
			spec.crossing_tower = true
			spec.tower_roof = &"spire"
		"durham":
			spec.west_towers = 2
			spec.transept = true
			spec.crossing_tower = true
		"hagia_sophia", "florence_duomo", "st_basil":
			# composed, not rolled: ChurchGenerator.apply_landmark
			ChurchGenerator.apply_landmark(spec, key)
	# backfill any size the generator left at zero, then re-settle the ring
	if spec.tower and spec.tower_width <= 0.0:
		spec.tower_width = spec.width * 0.55
		spec.tower_height = spec.height * 1.5
	if spec.west_towers >= 2:
		spec.tower_width = minf(spec.tower_width, ChurchGeometry.max_twin_tower_width(spec))
	if spec.aisles > 0 and spec.aisle_width <= 0.0:
		spec.aisle_width = spec.width * 0.28
	if spec.apse and spec.apse_radius <= 0.0:
		spec.apse_radius = spec.width * 0.42
	if spec.crossing_tower and spec.crossing_tower_height <= 0.0:
		spec.crossing_tower_height = spec.height * 1.7
	if spec.dome:
		if spec.dome_radius <= 0.0:
			spec.dome_radius = spec.width * 0.45
		if spec.dome_drum_height <= 0.0:
			spec.dome_drum_height = spec.dome_radius * ChurchGeometry.DOME_DRUM_RATIO
		spec.roof_pitch = minf(spec.roof_pitch, 0.40)
		spec.dome_drum_height = maxf(spec.dome_drum_height,
			ChurchGeometry.min_drum_height(spec))
	if spec.radiating_chapels > 0:
		if spec.chapel_radius <= 0.0:
			spec.chapel_radius = spec.width * 0.2
		ChurchGenerator._fit_chapels(spec)
	if spec.flying_buttresses:
		spec.buttresses = true
		spec.buttress_count_per_side = maxi(spec.buttress_count_per_side, 5)


## The famous fortifications, from docs/CASTLES.md. Same rows the castle
## landmark suite builds, so a portrait here is a picture of a tested building.
func _castles() -> Array[Dictionary]:
	return [
		{"key": "bodiam", "style": &"edwardian", "tier": &"castle",
			"title": "Bodiam Castle", "w": 55.0, "l": 50.0, "h": 18.0, "seed": 6001,
			"feat": "quadrangular plan, four drum towers, twin-towered gatehouse",
			"yaw": 2.45, "pitch": -0.26},
		{"key": "krak", "style": &"crusader", "tier": &"fortress",
			"title": "Krak des Chevaliers", "w": 300.0, "l": 140.0, "h": 20.0,
			"seed": 6002, "feat": "concentric: two enceintes and a battered talus",
			"yaw": 2.30, "pitch": -0.17, "zoom": 0.86},
		{"key": "chambord", "style": &"french_chateau", "tier": &"fortress",
			"title": "Chateau de Chambord", "w": 156.0, "l": 117.0, "h": 32.0,
			"seed": 6003, "feat": "corner drums under conical roofs, dormered ranges",
			"yaw": 2.55, "pitch": -0.24},
		{"key": "caernarfon", "style": &"edwardian", "tier": &"castle",
			"title": "Caernarfon Castle", "w": 170.0, "l": 60.0, "h": 12.0,
			"seed": 6004, "feat": "polygonal mural towers along a long curtain",
			"yaw": 2.05, "pitch": -0.16, "zoom": 0.88},
		{"key": "himeji", "style": &"japanese", "tier": &"castle",
			"title": "Himeji Castle", "w": 60.0, "l": 50.0, "h": 15.0, "seed": 6005,
			"feat": "tiered tenshu on a battered stone base",
			"yaw": 2.50, "pitch": -0.24},
		{"key": "neuschwanstein", "style": &"bavarian", "tier": &"castle",
			"title": "Neuschwanstein", "w": 150.0, "l": 40.0, "h": 25.0,
			"seed": 6006, "feat": "a ridge of ranges under tall conical spires",
			"yaw": 2.10, "pitch": -0.20},
		{"key": "stokesay", "style": &"norman", "tier": &"manor",
			"title": "Stokesay Castle", "w": 30.0, "l": 24.0, "h": 10.0, "seed": 6007,
			"feat": "fortified manor: a hall between two towers",
			"yaw": 2.60, "pitch": -0.26},
		{"key": "longhouse", "style": &"norman", "tier": &"house",
			"title": "Medieval longhouse", "w": 6.5, "l": 18.0, "h": 4.5,
			"seed": 6008, "feat": "one range, one ridge, one chimney stack",
			"yaw": 2.35, "pitch": -0.22},
	]


func _castle_spec(entry: Dictionary) -> CastleSpec:
	_family = &"castle"
	var spec := CastleSpec.new()
	spec.style = entry["style"]
	spec.tier_override = entry["tier"]
	spec.width = entry["w"]
	spec.length = entry["l"]
	spec.height = entry["h"]
	CastleGenerator.generate(spec, entry["seed"])
	# the suite owns what makes each landmark itself; reusing it here is what
	# keeps the portraits honest about what is actually tested
	CastleLandmarkSuite._force_features(entry["key"], spec)
	return spec


func _describe_castle(entry: Dictionary, spec: CastleSpec, file: String) -> Dictionary:
	var bits: Array[String] = []
	if spec.corner_towers:
		bits.append("corner towers")
	if spec.side_towers > 0:
		bits.append("%d mural towers/side" % spec.side_towers)
	if spec.gatehouse:
		bits.append("twin-towered gatehouse" if spec.gate_towers else "gatehouse")
	if spec.inner_ward:
		bits.append("inner ward + causeway")
	if spec.barbican:
		bits.append("barbican")
	if spec.keep:
		bits.append("%s keep" % String(spec.keep_shape))
	if spec.hall:
		bits.append("great hall")
	if spec.chapel:
		bits.append("chapel")
	if spec.wings > 0:
		bits.append("%d cross wing%s" % [spec.wings, "s" if spec.wings > 1 else ""])
	if spec.courtyard:
		bits.append("courtyard range")
	if spec.chimneys > 0:
		bits.append("%d chimney stacks" % spec.chimneys)
	return {
		"key": "castle_" + entry["key"], "title": entry["title"], "file": file,
		"kind": "castle", "tier": String(spec.tier), "famous_for": entry["feat"],
		"dims": "%.0f x %.0f x %.0f m site" % [spec.width, spec.length, spec.height],
		"height": "%.1f m to the top" % CastleGeometry.total_height(spec),
		"built": ", ".join(bits),
		"variant": spec.variant_name,
	}


## The furnished dwellings, from docs/HOUSES.md. Same archetypes the house
## suite builds, so a portrait here is a picture of a tested house.
func _houses() -> Array[Dictionary]:
	return [
		{"key": "one_room_cottage", "style": &"cottage", "trade": &"none",
			"title": "One-room cottage", "w": 5.5, "l": 7.0, "h": 2.4, "seed": 8101,
			"feat": "one room: the bed in the corner, the table by the door",
			"yaw": 0.8, "pitch": -0.85},
		{"key": "family_cottage", "style": &"cottage", "trade": &"none",
			"title": "Family cottage", "w": 8.0, "l": 10.5, "h": 2.6, "seed": 8102,
			"feat": "hall, kitchen and a bedroom off the back",
			"yaw": 0.9, "pitch": -0.8},
		{"key": "smithy", "style": &"longhall", "trade": &"smith",
			"title": "Smith's house", "w": 11.0, "l": 13.0, "h": 2.8, "seed": 8103,
			"feat": "a forge in the workshop: anvil, bench, weapon stand",
			"yaw": 0.95, "pitch": -0.8},
		{"key": "alchemist", "style": &"witch_hut", "trade": &"alchemist",
			"title": "Alchemist's house", "w": 9.5, "l": 12.0, "h": 2.7, "seed": 8104,
			"feat": "bookcase, cauldron and a bench of bottles",
			"yaw": 0.75, "pitch": -0.82},
		{"key": "inn", "style": &"townhouse", "trade": &"innkeeper",
			"title": "Village inn", "w": 13.0, "l": 16.0, "h": 2.9, "storeys": 2,
			"seed": 8105,
			"feat": "common room, parlour, guest rooms and a cellar",
			"yaw": 1.05, "pitch": -0.85},
		{"key": "farmhouse", "style": &"farmhouse", "trade": &"farmer",
			"title": "Farmhouse", "w": 10.0, "l": 13.0, "h": 2.7, "seed": 8106,
			"feat": "stores of barrels and crates off the kitchen",
			"yaw": 0.85, "pitch": -0.82},
		{"key": "rich_merchant", "style": &"rich", "trade": &"innkeeper",
			"title": "Rich merchant's house", "w": 12.0, "l": 15.0, "h": 3.0,
			"storeys": 3, "seed": 8107, "ornament": true,
			"feat": "three banded storeys: a crown at the wall head, belt courses at "
				+ "each storey line, pedimented upper windows and an obelisk on the ridge",
			"yaw": 1.0, "pitch": -0.55},
	]


## A house for a portrait -- and it is put through the same harness the suites
## use before it is photographed. A render is documentation, and documenting a
## house that would fail its own checks is worse than not documenting one.
func _house_plan(entry: Dictionary) -> Array:
	var spec := HouseSpec.new()
	spec.style = entry["style"]
	spec.trade = entry["trade"]
	spec.width = entry["w"]
	spec.length = entry["l"]
	spec.height = entry["h"]
	spec.storeys = int(entry.get("storeys", 1))
	var plan: HousePlan = HouseGenerator.generate(spec, entry["seed"])
	var builder := HouseBuilder.new()
	builder.build(plan)
	var rep: Dictionary = HouseQA.new().check(plan, builder)
	if not rep["ok"]:
		printerr("  %s FAILS its own checks:" % entry["key"])
		for f in rep["failures"]:
			printerr("     " + str(f))
	if bool(entry.get("ornament", false)):
		var rich: Dictionary = RichHouseCheck.new().check(plan, builder)
		if not rich["ok"]:
			printerr("  %s FAILS the rich check:" % entry["key"])
			for f2 in rich["failures"]:
				printerr("     " + str(f2))
	var rooms: Array[String] = []
	for i in range(plan.room_count()):
		rooms.append("%s(%d)" % [String(plan.kind_of(i)), plan.furniture_of(i).size()])
	print("  %-18s %s" % [entry["key"], ", ".join(rooms)])
	return [spec, plan]


func _describe_house(entry: Dictionary, spec: HouseSpec, plan: HousePlan,
		file: String) -> Dictionary:
	var rooms: Array[String] = []
	for i in range(plan.room_count()):
		rooms.append(String(plan.kind_of(i)))
	return {
		"key": "house_" + entry["key"], "title": entry["title"], "file": file,
		"kind": "house", "trade": String(spec.trade), "famous_for": entry["feat"],
		"dims": "%.1f x %.1f m" % [spec.width, spec.length],
		"built": "%s; %d doors, %d windows, %d pieces of furniture"
			% [", ".join(rooms), plan.doors.size(), plan.windows.size(),
				plan.furniture.size()],
		"variant": spec.variant_name,
	}


## The temples, from docs/TEMPLES.md. Same archetypes the temple suite builds.
func _temples() -> Array[Dictionary]:
	return [
		{"key": "bloodpit_basilica", "needs": ["pit", "cells"], "form": &"basilica", "cult": &"blood",
			"title": "Bloodpit Basilica", "w": 26.0, "l": 46.0, "h": 13.0,
			"seed": 7301, "feat": "a nave of columns, a hole in the floor, cages down the aisles"},
		{"key": "starless_pylon", "needs": ["obelisks"], "form": &"pylon", "cult": &"void",
			"title": "Temple of the Starless Deep", "w": 34.0, "l": 58.0, "h": 15.0,
			"seed": 7302, "feat": "obelisks, a court, a forest of columns, a small dark room"},
		{"key": "ashen_ziggurat", "needs": [], "form": &"ziggurat", "cult": &"flame",
			"title": "Ziggurat of the Ashen Crown", "w": 40.0, "l": 46.0, "h": 16.0,
			"seed": 7303, "feat": "a stepped mountain with the fire on top of it"},
		{"key": "coiled_rotunda", "needs": ["pit"], "form": &"rotunda", "cult": &"serpent",
			"title": "Rotunda of the Coiled Fang", "w": 32.0, "l": 34.0, "h": 12.0,
			"seed": 7304, "feat": "a ring of columns round a hole, the altar bridged over it"},
		{"key": "ossuary_basilica", "needs": ["cells"], "form": &"basilica", "cult": &"bone",
			"title": "The Ossuary", "w": 24.0, "l": 42.0, "h": 12.0,
			"seed": 7305, "feat": "a cairn of skulls where the reredos should be"},
	]


func _temple_spec(entry: Dictionary) -> TempleSpec:
	var spec := TempleSpec.new()
	spec.form = entry["form"]
	spec.cult = entry["cult"]
	spec.width = entry["w"]
	spec.length = entry["l"]
	spec.height = entry["h"]
	TempleGenerator.generate(spec, entry["seed"])
	# the suite owns what makes each temple itself; reusing it here keeps a
	# portrait honest about what is actually tested
	TempleArchetypeSuite._force(spec, entry.get("needs", []))
	var builder := TempleBuilder.new()
	builder.build(spec)
	var rep: Dictionary = TempleQA.new().check(spec, builder)
	if not rep["ok"]:
		printerr("  %s FAILS its own rite:" % entry["key"])
		for f in rep["failures"]:
			printerr("     " + str(f))
	return spec


func _describe_temple(entry: Dictionary, spec: TempleSpec, file: String) -> Dictionary:
	return {
		"key": "temple_" + entry["key"], "title": entry["title"], "file": file,
		"kind": "temple", "famous_for": entry["feat"],
		"dims": "%.0f x %.0f x %.0f m" % [spec.width, spec.length, spec.height],
		"height": "%.1f m to the crown of the god" % TempleGeometry.idol_apex(spec),
		"built": "%s of %s; a %s idol, %d columns%s%s"
			% [TempleSpec.FORMS[spec.form]["label"],
				TempleSpec.CULTS[spec.cult]["label"], String(spec.idol_kind),
				TempleGeometry.column_positions(spec).size(),
				", a bridged pit" if spec.pit else "",
				", %d cells" % spec.cells if spec.cells > 0 else ""],
		"variant": spec.variant_name,
	}


# -------------------------------------------------------------------- stage

func _build_stage() -> void:
	_vp = SubViewport.new()
	_vp.size = SHOT
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(_vp)

	_root3d = Node3D.new()
	_vp.add_child(_root3d)

	var env := Environment.new()
	_stage_environment = env
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	# a long, soft haze band at the horizon and a deeper blue overhead
	sky_mat.sky_curve = 0.32
	sky_mat.ground_curve = 0.08
	sky_mat.sun_angle_max = 0.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = false
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_sky_affect = 0.0
	env.fog_depth_curve = 1.6
	# The project's mobile renderer does not use SSAO. Keep the stage honest.
	var we := WorldEnvironment.new()
	we.environment = env
	_root3d.add_child(we)
	# Directional shadows default to a 100 m reach, which is why a 300 m
	# fortress seen from 450 m cast nothing. The reach is set per shot below;
	# the atlas is the largest the renderer allows.
	RenderingServer.directional_shadow_atlas_set_size(8192, true)

	_key_light = DirectionalLight3D.new()
	_key_light.rotation = Vector3(deg_to_rad(-42.0), deg_to_rad(-131.0), 0.0)
	_key_light.light_energy = 1.5
	_key_light.shadow_enabled = true
	_key_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_key_light.directional_shadow_blend_splits = true
	_key_light.directional_shadow_max_distance = 600.0
	_root3d.add_child(_key_light)

	_fill_light = DirectionalLight3D.new()
	_fill_light.rotation = Vector3(deg_to_rad(-16.0), deg_to_rad(58.0), 0.0)
	_fill_light.light_energy = 0.35
	_root3d.add_child(_fill_light)

	# A plane far wider than the camera can see, with the fog doing the work of
	# an edge: by the time the eye reaches the border the earth is haze.
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(9000, 9000)
	ground.mesh = pm
	var gsh := Shader.new()
	gsh.code = GROUND_SHADER
	_ground_mat = ShaderMaterial.new()
	_ground_mat.shader = gsh
	ground.material_override = _ground_mat
	_root3d.add_child(ground)
	_set_atmosphere(&"church")

	_mesh_inst = MeshInstance3D.new()
	_root3d.add_child(_mesh_inst)

	_cam = Camera3D.new()
	_cam.fov = 48.0
	_cam.far = 4000.0
	_vp.add_child(_cam)


# -------------------------------------------------------------------- shoot

func _shoot_church(spec: ChurchSpec, file: String, yaw: float, pitch: float,
		zoom := 1.0, focus := Vector3.INF, frame_radius := 0.0) -> void:
	if _mesh_only:
		await _shoot_mesh(ChurchBuilder.new().build(spec),
			[spec.stone_color, spec.trim_color, spec.roof_color, Color("15171b")],
			file, yaw, pitch, zoom, focus, frame_radius)
	else:
		await _shoot_scene(ChurchAssembler.build(spec, false), file, yaw, pitch,
			zoom, focus, frame_radius)


func _shoot_castle(spec: CastleSpec, file: String, yaw: float, pitch: float,
		zoom := 1.0, courtyard_file := "") -> void:
	if _mesh_only:
		await _shoot_mesh(CastleBuilder.new().build(spec),
			[spec.stone_color, spec.trim_color, spec.roof_color, Color("15171b")],
			file, yaw, pitch, zoom)
	else:
		await _shoot_scene(CastleAssembler.build(spec, false), file, yaw, pitch,
			zoom, Vector3.INF, 0.0, spec if not courtyard_file.is_empty() else null,
			courtyard_file)


func _shoot_scene(node: Node3D, file: String, yaw: float, pitch: float,
		zoom := 1.0, focus := Vector3.INF, frame_radius := 0.0,
		courtyard_spec: CastleSpec = null, courtyard_file := "") -> void:
	_mesh_inst.mesh = null
	_root3d.add_child(node)
	await process_frame
	var aabb: AABB = SceneBounds.of_node(node)
	var centre: Vector3 = aabb.get_center()
	var radius: float = maxf(aabb.size.length() / 2.0, 1.0)
	if focus.x != INF:
		centre = focus
		radius = maxf(frame_radius, 1.0)
	var dist: float = radius / tan(deg_to_rad(_cam.fov) / 2.0) * 1.12 * zoom
	var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	_cam.position = centre + dir * dist
	_cam.look_at(centre, Vector3.UP)
	_set_shot_lighting(yaw, dist + radius)
	await _capture(file)
	if courtyard_spec != null:
		await _capture_krak_courtyard(courtyard_spec, courtyard_file)
	_root3d.remove_child(node)
	node.free()
	_set_legacy_lighting()


func _capture_krak_courtyard(spec: CastleSpec, file: String) -> void:
	var yard: Rect2 = CastleGeometry.bailey_rect(spec)
	var centre := Vector3(yard.get_center().x, 2.0, yard.get_center().y)
	var span: float = maxf(yard.size.x, yard.size.y)
	_cam.position = centre + Vector3(0.0, span * 0.62, -span * 0.48)
	_cam.look_at(centre, Vector3.UP)
	_set_shot_lighting(PI, _cam.position.distance_to(centre) + span * 0.6)
	await _capture(file)


## Same cameras as the archived Krak portrait and courtyard comparison. The
## existing files are the before views; this command writes only after views
## plus a manifest which binds both pairs and the measured yard report.
func _shoot_vis015_acceptance() -> void:
	var entry: Dictionary = {}
	for row in _castles():
		if row["key"] == "krak":
			entry = row
			break
	var spec: CastleSpec = _castle_spec(entry)
	var out := "visualqa/vis015"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR + "/" + out))
	var builder := CastleBuilder.new()
	builder.build(spec)
	var scene := CastleAssembler.build(spec, false)
	await _shoot_scene(scene, out + "/krak_assembled_after.jpg",
		float(entry["yaw"]), float(entry["pitch"]), float(entry["zoom"]),
		Vector3.INF, 0.0, spec, out + "/krak_courtyard_after.jpg")
	var manifest := {"task": "VIS-015", "seed": entry["seed"],
		"before": {"assembled": "../../castle_krak.jpg",
			"courtyard": "../scene/krak_courtyard.jpg"},
		"after": {"assembled": out + "/krak_assembled_after.jpg",
			"courtyard": out + "/krak_courtyard_after.jpg"},
		"yard_report": builder.yard_report,
		"camera": {"yaw": entry["yaw"], "pitch": entry["pitch"],
			"zoom": entry["zoom"], "courtyard": "bailey-facing aerial"},
		"notes": "Exterior yard fixtures are measured separately from range-interior props."}
	var file := FileAccess.open(OUT_DIR + "/" + out + "/manifest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()


## A furnished house: the shell plus every prop in it, framed from above so the
## rooms can be read. The roof comes off for these -- a furnished interior
## cannot be photographed through its own thatch.
func _shoot_house(plan: HousePlan, file: String, yaw: float, pitch: float,
		zoom := 1.0, cutaway := true) -> void:
	_mesh_inst.mesh = null
	var node: Node3D = HouseAssembler.build(plan, cutaway)
	_root3d.add_child(node)
	await process_frame
	var aabb: AABB = _node_aabb(node)
	var centre: Vector3 = aabb.get_center()
	var radius: float = maxf(aabb.size.length() / 2.0, 1.0)
	var dist: float = radius / tan(deg_to_rad(_cam.fov) / 2.0) * 1.12 * zoom
	var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	_cam.position = centre + dir * dist
	_cam.look_at(centre, Vector3.UP)
	_family = &"house"
	_set_shot_lighting(yaw, dist + radius)
	await _capture(file)
	node.queue_free()


## The bounds of an assembled scene, props included.
static func _node_aabb(node: Node) -> AABB:
	return SceneBounds.of_node(node)


## A temple. Three shots, and the first is the one that matters: standing in
## the gate, looking down the axis at the god, which is the view the whole plan
## exists to stage -- and the view the rite check spends three of its rules on.
func _shoot_temple(spec: TempleSpec, file: String, mode: StringName) -> void:
	_mesh_inst.mesh = null
	# A ziggurat keeps its roof: the god is on the summit, so the money shot is
	# the mountain from the foot of the stair rather than a room with the lid
	# off. Cutting it away would remove the very thing you came to look at.
	var mountain: bool = spec.form == &"ziggurat"
	var node: Node3D = TempleAssembler.build(spec, mode != &"exterior" and not mountain)
	_root3d.add_child(node)
	await process_frame
	var idol: Vector3 = TempleGeometry.idol_center(spec)
	match mode:
		&"shrine":
			# A detail accompanies, never replaces, the tested gate sightline.
			# This reveals the idol without enlarging it to suit a wide camera.
			var focus := idol + Vector3.UP * spec.idol_height * 0.45
			# Stay on the ritual axis: a sideways detail camera can hide the
			# shrine behind a column even when the tested sightline is clear.
			_cam.position = focus + Vector3(0, spec.idol_height * 0.15,
				-maxf(6.0, spec.idol_height * 2.4))
			_cam.look_at(focus, Vector3.UP)
		&"axis":
			# where the harness stands to check the sightline: a step inside the
			# threshold for three of the forms, the foot of the great stair for
			# the fourth. Shooting from anywhere else would be photographing a
			# view no rule has ever tested.
			var eye: Vector2 = TempleGeometry.sight_point(spec)
			var back: float = 0.0
			if mountain:
				# far enough out that the whole climb is in frame
				back = TempleGeometry.total_height(spec) * 1.9
			_cam.position = Vector3(0.0, 1.75, eye.y + 0.2 - back)
			_cam.look_at(Vector3(0.0, idol.y + spec.idol_height * 0.45, idol.z),
				Vector3.UP)
		&"aerial":
			var r: Rect2 = TempleGeometry.plan_extent(spec)
			var span: float = maxf(r.size.x, r.size.y)
			_cam.position = Vector3(span * 0.42, span * 1.05, -span * 0.35)
			_cam.look_at(Vector3(0.0, 0.0, r.get_center().y), Vector3.UP)
		_:
			var aabb: AABB = SceneBounds.of_node(node)
			var radius: float = maxf(aabb.size.length() / 2.0, 1.0)
			var dist: float = radius / tan(deg_to_rad(_cam.fov) / 2.0) * 1.05
			var dir := Vector3(sin(2.5) * cos(-0.22), 0.22, cos(2.5) * cos(-0.22))
			_cam.position = aabb.get_center() + dir * dist
			_cam.look_at(aabb.get_center(), Vector3.UP)
	var fwd: Vector3 = -_cam.global_transform.basis.z
	_family = &"temple_dusk" if mode == &"exterior" else &"temple_dark"
	var reach: float = _cam.position.distance_to(idol) + 40.0
	if mode == &"aerial":
		reach = _cam.position.length() * 1.3
	elif mode == &"exterior":
		reach = _cam.position.distance_to(SceneBounds.of_node(node).get_center()) 			+ SceneBounds.of_node(node).size.length() / 2.0
	_set_shot_lighting(atan2(-fwd.x, -fwd.z), reach)
	await _capture(file)
	node.queue_free()


## Choose the time of day. Colours only; the key and fill are placed per shot
## by `_set_shot_lighting`, which knows the camera.
func _set_atmosphere(name: StringName) -> void:
	_atmo = ATMOSPHERES[name].duplicate()
	_atmo["name"] = String(name)
	var sky_mat: ProceduralSkyMaterial = _stage_environment.sky.sky_material
	sky_mat.sky_top_color = Color(_atmo["sky_top"])
	sky_mat.sky_horizon_color = Color(_atmo["sky_horizon"])
	sky_mat.ground_horizon_color = Color(_atmo["haze"])
	sky_mat.ground_bottom_color = Color(_atmo["below"])
	_stage_environment.fog_light_color = Color(_atmo["haze"])
	_ground_mat.set_shader_parameter("earth_a", Color(_atmo["earth_a"]))
	_ground_mat.set_shader_parameter("earth_b", Color(_atmo["earth_b"]))


## Frame a built mesh and save one image. Both generators hand this the same
## four surfaces, so the stage does not need to know which it is looking at.
func _shoot_mesh(mesh: ArrayMesh, cols: Array, file: String, yaw: float,
		pitch: float, zoom := 1.0, focus := Vector3.INF,
		frame_radius := 0.0, architectural_finish := false) -> void:
	_mesh_inst.mesh = mesh
	for i in range(mesh.get_surface_count()):
		var m := StandardMaterial3D.new()
		# a fifth surface (the moat water) has no colour in the four-entry palettes
		m.albedo_color = cols[i] if i < cols.size() else Color("4b7a99")
		m.roughness = 0.92
		_mesh_inst.set_surface_override_material(i, m)
	if architectural_finish:
		ShellAssembler.architectural_materials(_mesh_inst, cols)

	var aabb: AABB = mesh.get_aabb()
	var centre: Vector3 = aabb.get_center()
	var radius: float = maxf(aabb.size.length() / 2.0, 1.0)
	if focus.x != INF:
		centre = focus
		radius = maxf(frame_radius, 1.0)
	var dist: float = radius / tan(deg_to_rad(_cam.fov) / 2.0) * 1.12 * zoom
	var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	_cam.position = centre + dir * dist
	_cam.look_at(centre, Vector3.UP)
	_set_shot_lighting(yaw, dist + radius)
	await _capture(file)
	_set_legacy_lighting()


## Place the key and fill for one camera. `reach` is the distance from the
## camera to the far side of the subject; it sets how far shadows are drawn
## and where the ground starts to fade into haze.
func _set_shot_lighting(yaw: float, reach := 0.0) -> void:
	if _legacy_light:
		_set_legacy_lighting()
		return
	if reach <= 0.0:
		reach = 120.0
	_set_atmosphere(_atmosphere_name())
	_key_light.rotation = Vector3(deg_to_rad(-float(_atmo["key_elevation"])),
		yaw + deg_to_rad(_key_offset()), 0.0)
	_key_light.light_color = Color(_atmo["key_color"])
	_key_light.light_energy = _atmo["key_energy"]
	_stage_environment.ambient_light_energy = _atmo["ambient"]
	_fill_light.rotation = Vector3(deg_to_rad(FILL_ELEVATION),
		yaw + deg_to_rad(FILL_CAMERA_OFFSET), 0.0)
	_fill_light.light_color = Color(_atmo["fill_color"])
	_fill_light.light_energy = _atmo["fill_energy"]
	# shadows: one orthogonal box (8192 px atlas) reaching just past the far
	# wall, so a 300 m fortress gets texels of about 6 cm; bias a little
	# harder as the texels get bigger.
	_key_light.directional_shadow_max_distance = reach * 1.25
	_key_light.directional_shadow_fade_start = 1.0
	_key_light.shadow_normal_bias = clampf(reach / 120.0, 1.0, 4.0)
	_key_light.shadow_bias = 0.05
	_key_light.shadow_blur = 1.8
	# a low sun throws shadows from casters well outside the receiving box, so
	# the pancake (default 20 m) must reach as far as the subject is deep
	_key_light.directional_shadow_pancake_size = reach
	# fog: the subject stays clear, the ground beyond it goes to haze
	var begin: float = reach * 1.25
	_stage_environment.fog_enabled = not _atmo.get("no_fog", false)
	_stage_environment.fog_depth_begin = begin
	_stage_environment.fog_depth_end = minf(begin + maxf(reach * 5.0, 500.0), 3600.0)


func _key_offset() -> float:
	return float(ATMOSPHERES[_atmosphere_name()].get("key_offset", KEY_CAMERA_OFFSET))


## Which time of day this family is shot in. Houses and temples set `_family`
## themselves; `_castle_spec` and `_landmark_spec` set it for the rest.
func _atmosphere_name() -> StringName:
	match _family:
		&"castle":
			return &"castle"
		&"house":
			return &"house"
		&"temple_dusk", &"temple_dark":
			return _family
	return &"church"


func _set_legacy_lighting() -> void:
	_set_atmosphere(&"legacy")
	_stage_environment.fog_enabled = false
	_key_light.rotation = Vector3(deg_to_rad(-42.0), deg_to_rad(-131.0), 0.0)
	_key_light.light_color = Color.WHITE
	_key_light.light_energy = 1.5
	_stage_environment.ambient_light_energy = 1.0
	_fill_light.rotation = Vector3(deg_to_rad(-16.0), deg_to_rad(58.0), 0.0)
	_fill_light.light_color = Color.WHITE
	_fill_light.light_energy = 0.35
	_key_light.directional_shadow_max_distance = 100.0


static func _camera_metadata(yaw: float, pitch: float, zoom: float) -> Dictionary:
	return {"yaw_degrees": rad_to_deg(yaw), "pitch_degrees": rad_to_deg(pitch),
		"zoom": zoom, "fov_degrees": 48.0}


func _light_metadata(yaw: float, historical := false) -> Dictionary:
	if historical:
		return {"key_azimuth_degrees": -131.0, "key_elevation_degrees": -42.0,
			"key_energy": 1.5, "key_color": "ffffff", "fill_azimuth_degrees": 58.0,
			"fill_elevation_degrees": -16.0, "fill_energy": 0.35,
			"fill_color": "ffffff", "ambient_energy": 1.0,
			"atmosphere": "legacy", "shadow_max_distance_m": 100.0,
			"ground": "6f7360 plane, 900 m, no fog"}
	var a: Dictionary = ATMOSPHERES[_atmosphere_name()]
	return {"key_azimuth_degrees": rad_to_deg(yaw) + _key_offset(),
		"key_elevation_degrees": -float(a["key_elevation"]),
		"key_energy": a["key_energy"], "key_color": a["key_color"],
		"fill_azimuth_degrees": rad_to_deg(yaw) + FILL_CAMERA_OFFSET,
		"fill_elevation_degrees": FILL_ELEVATION,
		"fill_energy": a["fill_energy"], "fill_color": a["fill_color"],
		"ambient_energy": a["ambient"],
		"atmosphere": String(_atmosphere_name()), "time_of_day": a["label"],
		"shadow_max_distance_m": _key_light.directional_shadow_max_distance,
		"ground": "mottled %s/%s earth, 9 km plane, depth haze %s from %.0f m"
			% [a["earth_a"], a["earth_b"], a["haze"],
				_stage_environment.fog_depth_begin],
		"sky": "%s overhead to %s at the horizon" % [a["sky_top"], a["sky_horizon"]]}


func _portrait_metadata(seed: int, yaw: float, pitch: float,
		zoom: float) -> Dictionary:
	return {"seed": seed, "camera": _camera_metadata(yaw, pitch, zoom),
		"light": _light_metadata(yaw)}


func _shoot_sheet(spec: ChurchSpec, file: String) -> void:
	var vp := SubViewport.new()
	vp.size = SHEET
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var view := BlueprintView.new()
	view.size = Vector2(SHEET)
	vp.add_child(view)
	view.setup(spec)
	view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	img.save_jpg(OUT_DIR + "/" + file, 0.92)
	print("  ", file)
	vp.queue_free()


func _capture(file: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = _vp.get_texture().get_image()
	img.save_jpg(OUT_DIR + "/" + file, 0.9)
	print("  ", file)


func _describe(entry: Dictionary, spec: ChurchSpec, file: String) -> Dictionary:
	var bits: Array[String] = []
	if spec.west_towers >= 2:
		bits.append("twin west towers")
	elif spec.west_towers == 1:
		bits.append("west tower")
	if spec.flying_buttresses:
		bits.append("%d flying buttresses/side%s"
			% [spec.buttress_count_per_side, ", 2 tiers" if spec.flyer_tiers > 1 else ""])
	if spec.aisles > 0:
		bits.append("%d aisle ring%s" % [spec.aisles, "s" if spec.aisles > 1 else ""])
	if spec.transept:
		bits.append("transept")
	if spec.crossing_tower:
		bits.append("crossing tower")
	if spec.dome:
		bits.append("%s dome%s" % [String(spec.dome_shape),
			" + lantern" if spec.dome_lantern else ""])
	if spec.half_domes:
		bits.append("half-domes")
	if spec.ambulatory:
		bits.append("ambulatory")
	if spec.radiating_chapels > 0:
		bits.append("%d chapels (%s)" % [spec.radiating_chapels,
			String(spec.chapel_arrangement)])
	if spec.narthex:
		bits.append("narthex")
	return {
		"key": entry["key"], "title": entry["title"], "file": file, "kind": "landmark",
		"famous_for": entry["feat"],
		"dims": "%.1f x %.0f x %.1f m" % [spec.width, spec.length, spec.height],
		"height": "%.1f m to the top" % ChurchGeometry.total_height(spec),
		"built": ", ".join(bits),
		"variant": spec.variant_name,
	}

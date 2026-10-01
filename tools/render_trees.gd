extends SceneTree
## Photographs the tree family to artifacts/tree_renders/.
##
## One portrait for every species of every style -- twenty-four photographs, so
## a reviewer can hold the voxel oak, the indie poplar, the natural pine and the
## magic world tree side by side and see whether they are four ALGORITHMS or one
## shape in four coats. Then two sheets that no single portrait can show: a wood
## of forty natural oaks, which is the only shot where the tree has company,
## and a line of all twenty-four at eye height, which is the only shot where two
## silhouettes can be compared without the eye lying about scale.
##
## Must run WITHOUT --headless: the headless dummy renderer cannot produce an
## image. It draws into a SubViewport, so no window content is captured.
##
## Run: godot --path . --script res://tools/render_trees.gd
##
## Nothing here decides anything about a tree. Every portrait is the same three
## steps the game takes -- `TreeGenerator.generate` decides, `TreeBuilder` emits,
## `TreeAssembler` dresses it into a scene -- so a picture in this folder is a
## picture of the thing that will actually be planted, not a drawing of it.

const OUT := "res://artifacts/tree_renders"
const SHOT := Vector2i(1100, 900)
## The comparison line is twenty-four trees side by side, so it gets a wide
## sheet; at 1100 px the tallest of them would be a smear, and 24 m of world
## per specimen is 150 px of picture, which is what a caption has to fit in.
const ROW := Vector2i(3600, 800)
const EYE := 1.7
const ROW_SPACING := 24.0

## Every species of every style, each with a height that suits its algorithm --
## a voxel crown is legible at 9 m and a wall of cubes at 12, and a world tree
## is not a world tree at 10 -- and a fixed seed, so this set is a fixed set:
## run it twice and get the same twenty-four trees.
const SUBJECTS: Array[Dictionary] = [
	{"key": "voxel_oak", "title": "Voxel oak, 9 m", "style": &"voxel",
		"species": &"oak", "height": 9.0, "seed": 7001},
	{"key": "voxel_birch", "title": "Voxel birch, 11 m", "style": &"voxel",
		"species": &"birch", "height": 11.0, "seed": 7002},
	{"key": "voxel_spruce", "title": "Voxel spruce, 12 m", "style": &"voxel",
		"species": &"spruce", "height": 12.0, "seed": 7003},
	{"key": "voxel_acacia", "title": "Voxel acacia, 8 m", "style": &"voxel",
		"species": &"acacia", "height": 8.0, "seed": 7004},
	{"key": "voxel_willow", "title": "Voxel willow, 10 m", "style": &"voxel",
		"species": &"willow", "height": 10.0, "seed": 7005},
	{"key": "voxel_palm", "title": "Voxel palm, 10.5 m", "style": &"voxel",
		"species": &"palm", "height": 10.5, "seed": 7006},

	{"key": "indie_oak", "title": "Indie oak, 11 m", "style": &"indie",
		"species": &"oak", "height": 11.0, "seed": 7011},
	{"key": "indie_birch", "title": "Indie birch, 13 m", "style": &"indie",
		"species": &"birch", "height": 13.0, "seed": 7012},
	{"key": "indie_poplar", "title": "Indie poplar, 14 m", "style": &"indie",
		"species": &"poplar", "height": 14.0, "seed": 7013},
	{"key": "indie_willow", "title": "Indie willow, 10 m", "style": &"indie",
		"species": &"willow", "height": 10.0, "seed": 7014},
	{"key": "indie_pine", "title": "Indie pine, 12.5 m", "style": &"indie",
		"species": &"pine", "height": 12.5, "seed": 7015},
	{"key": "indie_dead", "title": "Indie dead tree, 9 m", "style": &"indie",
		"species": &"dead", "height": 9.0, "seed": 7016},

	{"key": "natural_oak", "title": "Natural oak, 16 m", "style": &"natural",
		"species": &"oak", "height": 16.0, "seed": 7021},
	{"key": "natural_ash", "title": "Natural ash, 18 m", "style": &"natural",
		"species": &"ash", "height": 18.0, "seed": 7022},
	{"key": "natural_beech", "title": "Natural beech, 15 m", "style": &"natural",
		"species": &"beech", "height": 15.0, "seed": 7023},
	{"key": "natural_hawthorn", "title": "Natural hawthorn, 9 m",
		"style": &"natural", "species": &"hawthorn", "height": 9.0, "seed": 7024},
	{"key": "natural_pine", "title": "Natural pine, 20 m", "style": &"natural",
		"species": &"pine", "height": 20.0, "seed": 7025},
	{"key": "natural_willow", "title": "Natural willow, 12 m", "style": &"natural",
		"species": &"willow", "height": 12.0, "seed": 7026},

	{"key": "magic_worldtree", "title": "The World Tree, 30 m", "style": &"magic",
		"species": &"worldtree", "height": 30.0, "seed": 7031},
	{"key": "magic_crystal", "title": "The Singing Crystal, 22 m",
		"style": &"magic", "species": &"crystal", "height": 22.0, "seed": 7032},
	{"key": "magic_inverted", "title": "The Upside-Down, 20 m", "style": &"magic",
		"species": &"inverted", "height": 20.0, "seed": 7033},
	{"key": "magic_floating", "title": "The Wanderer, 18 m", "style": &"magic",
		"species": &"floating", "height": 18.0, "seed": 7034},
	{"key": "magic_weeping", "title": "The Mourner, 24 m", "style": &"magic",
		"species": &"weeping", "height": 24.0, "seed": 7035},
	{"key": "magic_ember", "title": "The Ember, 16 m", "style": &"magic",
		"species": &"ember", "height": 16.0, "seed": 7036},
]

## The wood the forest sheet is made of: forty natural oaks on a 60 m square.
const FOREST_SEED := 9021
const FOREST_SCATTER_SEED := 9051
const FOREST_ROWS := 4
const FOREST_COLS := 10
const FOREST_SPAN := 60.0

var _vp: SubViewport
var _cam: Camera3D
var _root3d: Node3D
var _shots := 0


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_build_stage()
	await process_frame

	var manifest: Array[Dictionary] = []

	# ---- the twenty-four portraits ----
	# The camera walks around the subject by a fixed step rather than standing
	# on one azimuth for all of them: a row of pictures taken from the same
	# angle is a row of the same picture, and half the point of a contact
	# sheet is seeing each tree from where its own shape is legible.
	for i in range(SUBJECTS.size()):
		var entry: Dictionary = SUBJECTS[i]
		var yaw: float = 0.55 + 0.31 * float(i % 6)
		manifest.append(await _shoot_subject(entry, yaw))

	# ---- the two sheets ----
	manifest.append(await _shoot_forest())
	manifest.append(await _shoot_row())

	var f := FileAccess.open(OUT + "/manifest.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(manifest, "\t"))
	f.close()
	print("wrote %d images to %s" % [_shots, OUT])
	quit()


# ------------------------------------------------------------------- portraits

## One species, one photograph: generate, build, dress, frame, shoot, free.
## The spec is generated first because the builder is a pure function of it --
## an ungenerated spec makes a different tree from the one a player would get.
func _shoot_subject(entry: Dictionary, yaw: float) -> Dictionary:
	var spec := TreeSpec.new()
	spec.style = entry["style"]
	spec.species = entry["species"]
	spec.height = entry["height"]
	TreeGenerator.generate(spec, int(entry["seed"]))

	var builder := TreeBuilder.new()
	builder.build(spec)
	var node: Node3D = TreeAssembler.build(spec, builder)
	_vote_materials(node)
	_root3d.add_child(node)
	await process_frame

	_frame(SceneBounds.of_node(node), yaw, -0.22, 1.0)
	var file: String = "%s.jpg" % entry["key"]
	await _capture(file)
	node.queue_free()

	return _describe(entry, spec, builder, file)


## The voxel grain, the bark streaks and the per-cell leaf jitter are all vertex
## colour. A tree shot with a material that does not read vertex colour as
## albedo comes out a smooth plastic blob, which is exactly the defect
## docs/VISUAL_QA.md is about, so every surface is put through the assembler's
## own material as a backstop -- with a white tint, because the assembler's
## material already carries the surface colour and laying two on top of each
## other would double it. An emissive surface is left alone: a magic tree's
## glow is emissive on purpose, and the assembler already lit it.
func _vote_materials(node: Node) -> void:
	for child in node.get_children():
		if not (child is MeshInstance3D):
			_vote_materials(child)
			continue
		var mi := child as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in range(mi.mesh.get_surface_count()):
			var m: Material = mi.get_surface_override_material(i)
			if m == null:
				m = mi.mesh.surface_get_material(i)
			if _reads_vertex_colour(m):
				continue
			mi.set_surface_override_material(i, TreeAssembler.tree_material(Color.WHITE))


## Does this surface already show the mesh's vertex colour, or is it a light
## source? Either way it is not the plastic blob, and it is left as it is.
static func _reads_vertex_colour(m: Material) -> bool:
	if m is ShaderMaterial:
		return bool((m as ShaderMaterial).get_shader_parameter("vertex_tint"))
	if m == null or not (m is StandardMaterial3D):
		return false
	var sm := m as StandardMaterial3D
	return sm.vertex_color_use_as_albedo or sm.emission_energy_multiplier > 0.0


func _describe(entry: Dictionary, spec: TreeSpec, builder: TreeBuilder,
		file: String) -> Dictionary:
	return {
		"key": entry["key"],
		"title": entry["title"],
		# style and species are read back off the spec, not off the table:
		# `TreeGenerator` falls back to a species the style does know, and the
		# manifest has to say what was actually built.
		"style": String(spec.style),
		"species": String(spec.species),
		"height": spec.height,
		"file": file,
		"variant": spec.variant_name,
		"built": "%d branches, %d crown lobes, %d cells"
			% [spec.branches.size(), spec.lobes.size(), _cell_count(builder)],
	}


# ----------------------------------------------------------------- forest sheet

## Forty oaks on a 60 m square, shot from a low three-quarter angle. A single
## tree is a specimen; a wood is a habitat, and the only things a single tree
## cannot show are the gaps a canopy is supposed to have and the trunks that
## are supposed to go on without it. The pitch stays shallow so the stand reads
## as a stand and not as a plan.
func _shoot_forest() -> Dictionary:
	var spec := TreeSpec.new()
	spec.style = &"natural"
	spec.species = &"oak"
	spec.height = 16.0
	TreeGenerator.generate(spec, FOREST_SEED)

	# No builder here: `scatter` grows its own tree per position, and this
	# sheet's subject is the wood. A natural oak stamps no voxels, so its cell
	# count is honestly zero rather than unmeasured.
	var spots: PackedVector3Array = _forest_spots()
	var node: Node3D = TreeAssembler.scatter(spec, spots, FOREST_SCATTER_SEED)
	_vote_materials(node)
	_root3d.add_child(node)
	await process_frame

	# The frame comes from WHERE THE TREES WERE PLANTED, not from
	# `SceneBounds.of_node(node)`. That walks declared mesh AABBs, and a wood
	# of forty Node3D roots each holding a MeshInstance3D is a lot of nesting to
	# ask a bounds helper to unwind; when it came back empty the camera framed
	# nothing and the sheet was a photograph of an empty field. The planting
	# sites are known exactly, and so is how tall a tree on them gets.
	var span := Rect2()
	var first := spots[0]
	span = Rect2(Vector2(first.x, first.z), Vector2.ZERO)
	for p in spots:
		span = span.expand(Vector2(p.x, p.z))
	var lo := Vector3(span.position.x, 0.0, span.position.y)
	var hi := Vector3(span.end.x, spec.height * 1.15, span.end.y)
	_frame(AABB(lo, hi - lo), 0.78, -0.22, 1.0)
	await _capture("forest.jpg")
	node.queue_free()

	# Forty trees of one spec, so the stand's tallies are the single tree's
	# multiplied out: a wood is not forty different pictures, it is one tree
	# planted forty times. The cells are zero because a natural oak has no
	# voxel pass to count.
	var n: int = FOREST_ROWS * FOREST_COLS
	return {
		"key": "forest", "title": "Forty natural oaks on 60 m of ground",
		"style": "scene", "species": "forest", "height": spec.height,
		"file": "forest.jpg", "variant": "the wood",
		"built": "%d branches, %d crown lobes, %d cells"
			% [spec.branches.size() * n, spec.lobes.size() * n, 0],
		"ground_m": FOREST_SPAN,
		"trees": n,
	}


## A jittered grid, not random points: a wood on a jittered grid still reads as
## standing ground, where a uniform scatter reads as a screensaver.
func _forest_spots() -> PackedVector3Array:
	var out := PackedVector3Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = FOREST_SEED
	var cell_x: float = FOREST_SPAN / float(FOREST_COLS)
	var cell_z: float = FOREST_SPAN / float(FOREST_ROWS)
	for r in range(FOREST_ROWS):
		for c in range(FOREST_COLS):
			var jx: float = rng.randf_range(-0.34, 0.34) * cell_x
			var jz: float = rng.randf_range(-0.34, 0.34) * cell_z
			out.append(Vector3(
				-FOREST_SPAN * 0.5 + (float(c) + 0.5) * cell_x + jx,
				0.0,
				-FOREST_SPAN * 0.5 + (float(r) + 0.5) * cell_z + jz))
	return out


# -------------------------------------------------------------------- row sheet

## All twenty-four in a line, square on, from eye height. This is the shot that
## makes the family honest: a silhouette read against the sky with nothing
## beside it for the eye to measure against, so a spruce is tall and thin and
## an acacia is flat and wide -- on the same ground, at the same distance.
func _shoot_row() -> Dictionary:
	var vp := SubViewport.new()
	vp.size = ROW
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(vp)

	var world := Node3D.new()
	vp.add_child(world)
	_dress_world(world)

	var cam := Camera3D.new()
	cam.fov = 48.0
	cam.far = 4000.0
	vp.add_child(cam)

	# The captions, collected here and drawn as a 2D overlay once the camera
	# is placed: `unproject_position` turns the ground under each tree into a
	# pixel, so a key is the same size of text wherever in the line it sits.
	var keys: Array[Dictionary] = []
	var tall := 1.0
	var span := 1.0
	var branches := 0
	var lobes := 0
	var cells := 0
	for i in range(SUBJECTS.size()):
		var entry: Dictionary = SUBJECTS[i]
		var spec := TreeSpec.new()
		spec.style = entry["style"]
		spec.species = entry["species"]
		spec.height = entry["height"]
		TreeGenerator.generate(spec, int(entry["seed"]))
		var builder := TreeBuilder.new()
		builder.build(spec)
		var node: Node3D = TreeAssembler.build(spec, builder)
		_vote_materials(node)
		node.position = Vector3((float(i) - float(SUBJECTS.size() - 1) * 0.5)
			* ROW_SPACING, 0.0, 0.0)
		world.add_child(node)
		keys.append({"text": String(entry["key"]),
			"at": node.position + Vector3(0.0, 0.4, 0.0)})
		tall = maxf(tall, spec.height)
		span = maxf(span, absf(node.position.x))
		branches += spec.branches.size()
		lobes += spec.lobes.size()
		cells += _cell_count(builder)
	await process_frame

	# Square on, at eye height, far enough back to hold the whole line. The
	# HORIZONTAL half-angle does the fitting, because the line is twenty-four
	# trees wide and the tallest of them is 30 m: a bounding-sphere fit would
	# push the camera so far back that every tree in it became a stalk. That
	# leaves it 174 m from the middle of a 552 m line, so the end trees are
	# twice as far off as the centre ones -- which is the honest cost of
	# putting twenty-four specimens in one frame, and the reason this is a
	# silhouette sheet and not a beauty sheet.
	var half_w: float = (span + ROW_SPACING * 0.5) * 1.06
	var aspect: float = float(ROW.x) / float(ROW.y)
	var dist: float = half_w / (tan(deg_to_rad(cam.fov) * 0.5) * aspect)
	cam.position = Vector3(0.0, EYE, -dist)
	cam.look_at(Vector3(0.0, tall * 0.5, 0.0), Vector3.UP)

	var overlay := Control.new()
	# A Control parented to a Viewport rather than to another Control is sized
	# by the viewport, so it is set outright as well as anchored.
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.size = Vector2(ROW)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp.add_child(overlay)
	overlay.draw.connect(_draw_keys.bind(overlay, cam, keys))
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_jpg(OUT + "/row.jpg", 0.92)
	_shots += 1
	print("  row.jpg  (%d specimens, %.0f m line, tallest %.1f m)"
		% [SUBJECTS.size(), span * 2.0, tall])
	vp.queue_free()

	return {
		"key": "row",
		"title": "All %d subjects in a line, square on at eye height"
			% SUBJECTS.size(),
		"style": "scene", "species": "row", "height": tall,
		"file": "row.jpg", "variant": "the family side by side",
		"built": "%d branches, %d crown lobes, %d cells" % [branches, lobes, cells],
		"line_m": span * 2.0,
	}


## The subject keys, drawn as flat 2D text under each silhouette. A `Label3D`
## in the world would need a font sized for a 174 m camera distance, and its
## apparent size would then depend on how far along the line its tree stood;
## unprojecting each key to a pixel and drawing it with a real font is the same
## text at the same size everywhere, which is what a comparison sheet needs.
func _draw_keys(overlay: Control, cam: Camera3D, keys: Array[Dictionary]) -> void:
	var font: Font = ThemeDB.fallback_font
	var size := 18
	for key in keys:
		var at: Vector3 = key["at"]
		if cam.is_position_behind(at):
			continue
		var text: String = key["text"]
		var px: Vector2 = cam.unproject_position(at)
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			size).x
		var box := Rect2(px.x - w * 0.5 - 8.0, px.y - size - 12.0, w + 16.0,
			float(size) + 12.0)
		overlay.draw_rect(box, Color(0.05, 0.06, 0.05, 0.62))
		overlay.draw_string(font, Vector2(px.x - w * 0.5, px.y - 8.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.95, 0.96, 0.92))


# ------------------------------------------------------------------ shoot/stage

## Frame a node's bounds the way tools/render_shots.gd frames a house: the
## bounding sphere, backed off far enough to clear the frustum at the shot's
## field of view, with a little air around it.
func _frame(aabb: AABB, yaw: float, pitch: float, zoom := 1.0) -> void:
	if aabb.size == Vector3.ZERO:
		return
	var centre: Vector3 = aabb.get_center()
	var radius: float = maxf(aabb.size.length() * 0.5, 1.0)
	var dist: float = radius / tan(deg_to_rad(_cam.fov) * 0.5) * 1.12 * zoom
	var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	_cam.position = centre + dir * dist
	_cam.look_at(centre, Vector3.UP)


func _capture(file: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = _vp.get_texture().get_image()
	img.save_jpg(OUT + "/" + file, 0.92)
	_shots += 1
	print("  ", file)


func _build_stage() -> void:
	_vp = SubViewport.new()
	_vp.size = SHOT
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(_vp)

	_root3d = Node3D.new()
	_vp.add_child(_root3d)
	_dress_world(_root3d)

	_cam = Camera3D.new()
	_cam.fov = 48.0
	_cam.far = 4000.0
	_vp.add_child(_cam)


## The same daylight, sky and grass every other render tool in this project
## uses, so a tree photographed here stands in the same world as a house
## photographed by tools/render_shots.gd. Nothing is dimmed: a magic tree is
## lit like everything else so its geometry is readable, and its own OmniLights
## come out of the assembler rather than from here.
func _dress_world(world: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("6b8cb5")
	sky_mat.sky_horizon_color = Color("cfd8e0")
	sky_mat.ground_bottom_color = Color("5b5b55")
	sky_mat.ground_horizon_color = Color("9aa0a0")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-42.0), deg_to_rad(-131.0), 0.0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	world.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-16.0), deg_to_rad(58.0), 0.0)
	fill.light_energy = 0.35
	world.add_child(fill)

	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(900, 900)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("6f7360")
	gm.roughness = 1.0
	ground.material_override = gm
	world.add_child(ground)


# ----------------------------------------------------------------------- stats

## How many cells the voxel stamper actually laid down. `voxel_log` carries one
## row per stamped cell, so its length IS the cell count, and only the voxel
## path fills it -- every other style legitimately reports zero cells here
## rather than being asked for a number it does not have.
static func _cell_count(builder: TreeBuilder) -> int:
	return 0 if builder == null else builder.voxel_log.size()

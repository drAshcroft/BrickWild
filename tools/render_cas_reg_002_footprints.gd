extends SceneTree
## Top-down diagnostic of production gate-tower and wall-stair mass bounds.

const WIDTH := 1100
const HEIGHT := 760
const LEFT := 100.0
const TOP := 68.0
const SCALE := 12.5
const WORLD_X_MIN := -36.0
const WORLD_Z_MIN := -88.0

class FootprintPlot extends Node2D:
	var records: Array[Dictionary] = []
	var overlaps: Array[Rect2] = []
	var label := ""

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(WIDTH, HEIGHT)), Color("f3f1e8"), true)
		var plot_rect := Rect2(Vector2(LEFT, TOP), Vector2(900, 575))
		draw_rect(plot_rect, Color("e6e4db"), true)
		for i in range(0, 73, 5):
			var x := LEFT + float(i) * SCALE
			if x <= LEFT + 900.0:
				draw_line(Vector2(x, TOP), Vector2(x, TOP + 575.0), Color("d3d2cc"), 1.0)
		for i in range(0, 47, 5):
			var y := TOP + float(i) * SCALE
			if y <= TOP + 575.0:
				draw_line(Vector2(LEFT, y), Vector2(LEFT + 900.0, y), Color("d3d2cc"), 1.0)
		draw_rect(plot_rect, Color("656a70"), false, 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(LEFT, 38), "Crusader fortress 9118 | production mass bounds | top-down, metres",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("252a31"))
		draw_string(ThemeDB.fallback_font, Vector2(LEFT, 665), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("252a31"))
		draw_string(ThemeDB.fallback_font, Vector2(LEFT, 695), "Ring 0 gate towers: blue  |  Ring 1 gate towers: orange  |  Wall stairs: green  |  Red: overlapping mass bounds",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("33383d"))
		for record in records:
			var p := _point(float(record.x), float(record.z))
			var size := Vector2(float(record.w), float(record.h)) * SCALE
			var rect := Rect2(p, size)
			var colour: Color
			if record.kind == "gate":
				colour = Color("434c57")
			elif record.kind == "tower":
				colour = Color("9ab8d6") if int(record.ring) == 0 else Color("efad78")
			else:
				colour = Color("73c49b") if int(record.ring) == 0 else Color("73b9d7")
			draw_rect(rect, colour, true)
			draw_rect(rect, Color("26313b"), false, 2.0)
			var label_pos := rect.position + Vector2(4.0, 19.0)
			draw_string(ThemeDB.fallback_font, label_pos, String(record.label),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("18222b"))
		for overlap in overlaps:
			var p := _point(overlap.position.x, overlap.position.y)
			var rect := Rect2(p, overlap.size * SCALE)
			draw_rect(rect, Color(0.93, 0.18, 0.13, 0.72), true)
			draw_rect(rect, Color("a51f19"), false, 3.0)
			draw_string(ThemeDB.fallback_font, rect.position + Vector2(3, -5), "OVERLAP",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("8b1713"))

	func _point(x: float, z: float) -> Vector2:
		return Vector2(LEFT + (x - WORLD_X_MIN) * SCALE,
			TOP + (z - WORLD_Z_MIN) * SCALE)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var label := String(args[0]) if not args.is_empty() else "after"
	var spec := CastleSpec.new()
	spec.style = &"crusader"
	spec.width = 90.0
	spec.length = 140.0
	spec.height = 20.0
	CastleGenerator.generate(spec, 9118)
	var builder := CastleBuilder.new()
	builder.spec = spec
	builder.begin(4)
	for ring in CastleGeometry.rings(spec):
		builder._build_ring(ring)
	builder._build_wall_stairs()
	var records: Array[Dictionary] = []
	var gate_rows: Array = []
	var stair_rows: Array = []
	for row in builder.mass_log:
		var name := String(row.name)
		if name.begins_with("tower_") and "_gate_" in name:
			gate_rows.append(row)
		elif name.begins_with("wall_stair_"):
			stair_rows.append(row)
		elif name.begins_with("gate_"):
			var gate_ring := int(name.get_slice("_", 1))
			records.append(_record(row.aabb, "gate", gate_ring, "GATE %d" % gate_ring))
	for row in gate_rows:
		var ring := int(String(row.name).get_slice("_", 1))
		var slot := int(String(row.name).get_slice("_", 3))
		records.append(_record(row.aabb, "tower", ring, "G%d-T%d" % [ring, slot]))
	for row in stair_rows:
		var ring := int(row.get("ring", -1))
		var slot := int(String(row.name).get_slice("_", 2))
		records.append(_record(row.aabb, "stair", ring, "R%d-S%d" % [ring, slot]))
	var overlaps: Array[Rect2] = []
	for gate in gate_rows:
		for stair in stair_rows:
			var hit: AABB = gate.aabb.intersection(stair.aabb)
			if hit.size.x > 0.001 and hit.size.z > 0.001:
				overlaps.append(Rect2(hit.position.x, hit.position.z, hit.size.x, hit.size.z))
	var plot := FootprintPlot.new()
	plot.records = records
	plot.overlaps = overlaps
	plot.label = "%s | %d tower/stair AABB intersections" % [label.to_upper(), overlaps.size()]
	var viewport := SubViewport.new()
	viewport.size = Vector2i(WIDTH, HEIGHT)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(plot)
	await process_frame
	await RenderingServer.frame_post_draw
	var output := "res://artifacts/cas_reg_002/renders/footprint_%s.png" % label
	var image: Image = viewport.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(output))
	print("CAS_REG_002_FOOTPRINT ", output, " intersections=", overlaps.size())
	quit()


func _record(bounds: AABB, kind: String, ring: int, label: String) -> Dictionary:
	return {"x": bounds.position.x, "z": bounds.position.z, "w": bounds.size.x,
		"h": bounds.size.z, "kind": kind, "ring": ring, "label": label}

class_name HouseSheet
extends RefCounted
## The blueprint sheet of a house, a shop or a hotel: one plan per storey, the
## front elevation, and the room schedule.
##
## A house is a plan, not a mesh, so this sheet is drawn from the HousePlan and
## from HouseGeometry, the module the builder reads. It owns no wall, door or
## roof arithmetic of its own: the walls are HouseGeometry.shell_runs() and the
## partitions HouseBuilder emits from HousePlanOpenings.shared_edge(); a room is
## HouseGeometry.room_floor_rect(); the roof is the faces of
## HouseGeometry.roof_of(), seen end on. `drawing()` is that model, in
## metres and in plan axes, with no paper in it; `draw()` only puts it on paper.
## The `hblueprint` suite compares `drawing()` with the plan and with the mesh,
## which is why the geometry is a plain Dictionary a test can read.
##
## The page is drawn the way an architect hands it over. Plans have the front
## (-Z) at the foot of the sheet and the elevation is looked at from the front,
## so both have the same hand: +X is on the left of the paper in both, and a
## wall in the plan stands directly above the same wall in the elevation.
## North is the spec's `orientation`; zero faces south, so north is up.

const PAPER := Color("f4f7fa")
const INK := Color("27476e")
const LIGHT := Color(0.15, 0.28, 0.43, 0.35)
const FAINT := Color(0.15, 0.28, 0.43, 0.14)
const FLOOR_FILL := Color("fcfdfe")
const ROOF_FILL := Color("dde6f0")
const COURT_FILL := Color("e6eedf")
const WALL_FILL := Color(0.15, 0.28, 0.43, 0.9)

var plan: HousePlan
var model: Dictionary


func _init(p_plan: HousePlan) -> void:
	plan = p_plan
	model = HouseSheet.drawing(p_plan)


# ===================================================================== model

## Every storey the sheet draws, lowest first: the cellars, then L1 upward.
static func levels_of(p: HousePlan) -> Array[int]:
	var cellars: int = maxi(0, int(p.spec.get("cellars")))
	var lo: int = -cellars
	var hi: int = maxi(1, p.spec.storeys) - 1
	for i in range(p.room_count()):
		lo = mini(lo, p.storey_of_room(i))
		hi = maxi(hi, p.storey_of_room(i))
	var out: Array[int] = []
	for level in range(lo, hi + 1):
		out.append(level)
	return out


static func level_label(level: int) -> String:
	if level < 0:
		return "CELLAR" if level == -1 else "CELLAR %d" % -level
	return "L%d" % (level + 1)


## The plan as drawn, in metres and plan axes (X, Z).
static func drawing(p: HousePlan) -> Dictionary:
	var levels: Array[int] = levels_of(p)
	var by_level := {}
	var extent := Rect2()
	var first := true
	for level in levels:
		var data: Dictionary = _level(p, level)
		by_level[level] = data
		for r in data["bounds"]:
			extent = Rect2(r) if first else extent.merge(Rect2(r))
			first = false
	return {
		"levels": levels,
		"by_level": by_level,
		"extent": extent,
		"entrance": p.entrance(),
		"north": north_local(p.spec),
		"elevation": elevation(p),
	}


## North, as a direction in the house's own plan axes. The spec's orientation is
## the yaw of local -Z relative to north and zero faces south, so at zero north
## is local +Z.
static func north_local(spec: HouseSpec) -> Vector2:
	return Vector2(-sin(spec.orientation), cos(spec.orientation))


static func _level(p: HousePlan, level: int) -> Dictionary:
	var spec: HouseSpec = p.spec
	var walls: Array[Dictionary] = _walls(p, level)
	var bounds: Array[Rect2] = [HouseGeometry.storey_rect(p, level)]
	var rooms: Array[Dictionary] = []
	for i in p.rooms_on_storey(level):
		var floor_rect: Rect2 = HouseGeometry.room_floor_rect(p, i)
		rooms.append({"room": i, "kind": p.kind_of(i), "floor": floor_rect,
			"poly": HouseGeometry.room_floor_poly(p, i), "size": floor_rect.size,
			"label": String(p.kind_of(i)).replace("_", " ")})
	for wall in walls:
		bounds.append(Rect2(Vector2(wall["from"]), Vector2.ZERO).expand(wall["to"]).grow(float(wall["thick"]) * 0.5))

	var doors: Array[Dictionary] = []
	for d in range(p.doors.size()):
		var door: Dictionary = p.doors[d]
		if HousePlan.record_storey(door) != level:
			continue
		var placed: Dictionary = _on_wall(walls, door["pos"])
		var width: float = float(door["width"])
		var along: Vector2 = placed["along"]
		var side: float = _swing_side(p, door)
		var hinge: Vector2 = Vector2(placed["centre"]) - along * (width * 0.5)
		var latch: Vector2 = Vector2(placed["centre"]) + along * (width * 0.5)
		var normal: Vector2 = door["normal"]
		doors.append({"door": d, "pos": door["pos"], "centre": placed["centre"],
			"normal": normal, "along": along, "width": width, "wall": placed["wall"],
			"off": placed["off"], "thick": placed["thick"], "hinge": hinge, "latch": latch,
			"tip": hinge + normal * side * width, "side": side,
			"exterior": bool(door["exterior"]), "front": d == p.entrance()})

	var windows: Array[Dictionary] = []
	for w in range(p.windows.size()):
		var win: Dictionary = p.windows[w]
		if HousePlan.record_storey(win) != level:
			continue
		var placed: Dictionary = _on_wall(walls, win["pos"])
		var along: Vector2 = placed["along"]
		var width: float = float(win["width"])
		windows.append({"window": w, "pos": win["pos"], "centre": placed["centre"],
			"normal": win["normal"], "along": along, "width": width, "wall": placed["wall"],
			"off": placed["off"], "thick": placed["thick"],
			"a": Vector2(placed["centre"]) - along * (width * 0.5),
			"b": Vector2(placed["centre"]) + along * (width * 0.5)})

	var furniture: Array[Dictionary] = []
	for fi in range(p.furniture.size()):
		var item: Dictionary = p.furniture[fi]
		var room: int = int(item["room"])
		if room < 0 or room >= p.room_count() or p.storey_of_room(room) != level:
			continue
		var key: String = String(item["key"])
		furniture.append({"index": fi, "key": key, "room": room, "rect": Rect2(item["rect"]),
			"yaw": float(item.get("yaw", 0.0)), "label": first_word(key),
			"on_host": int(item.get("host", -1)) >= 0, "mounted": bool(item.get("mounted", false))})

	var rugs: Array[Rect2] = []
	for rug in p.rugs:
		if HousePlan.record_storey(rug) == level:
			rugs.append(Rect2(rug["rect"]))

	var courts: Array[Dictionary] = []
	for ci in p.courts_on(level):
		courts.append({"court": ci, "rect": Rect2(p.courts[ci]["rect"]), "poly": p.court_outline(ci)})

	var stairs: Array[Dictionary] = []
	for si in range(p.stairs.size()):
		var stair: Dictionary = p.stairs[si]
		var lower := Rect2(stair.get("lower_rect", stair.get("rect", Rect2())))
		var upper := Rect2(stair.get("upper_rect", stair.get("rect", lower)))
		var steps: int = maxi(4, int(stair.get("steps", 10)))
		if int(stair.get("storey", 0)) == level:
			stairs.append({"stair": si, "rect": lower, "steps": steps, "up": true,
				"along_x": lower.size.x > lower.size.y})
		if int(stair.get("to_storey", level + 1)) == level:
			stairs.append({"stair": si, "rect": upper, "steps": steps, "up": false,
				"along_x": upper.size.x > upper.size.y})

	var hatches: Array[Rect2] = []
	for hatch in p.trapdoors:
		if int(hatch.get("upper_storey", 0)) == level:
			hatches.append(Rect2(hatch["rect"]))

	# The fire and the flue it shares with the stack. The stack stands outside
	# the wall and rises through every storey above the hearth.
	var hearth_storey: int = p.storey_of_room(p.hearth_room()) if p.hearth_room() >= 0 else 0
	var hearth: Dictionary = {}
	if spec.chimney and level >= hearth_storey:
		var stack: Rect2 = HouseGeometry.chimney_rect(p)
		hearth = {"stack": stack, "solid": level == hearth_storey,
			"breast": Rect2(p.hearth.get("breast", {}).get("rect", Rect2())) if level == hearth_storey else Rect2()}
		bounds.append(stack)
	var porch := Rect2()
	if level == 0:
		porch = HouseGeometry.porch_rect(p)
		if porch.size.x > 0.0:
			bounds.append(porch)
	return {"level": level, "walls": walls, "rooms": rooms, "doors": doors,
		"windows": windows, "furniture": furniture, "rugs": rugs, "courts": courts,
		"stairs": stairs, "hatches": hatches, "hearth": hearth, "porch": porch,
		"bounds": bounds}


## Wall centre-lines of one storey, as the builder lays them: the shell, then
## the partitions between rooms, then the walls round a court.
static func _walls(p: HousePlan, level: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for run in HouseGeometry.shell_runs(p, level):
		out.append({"from": run["from"], "to": run["to"], "thick": float(run["thickness"]),
			"kind": &"exterior", "normal": run["normal"], "side": run["side"]})
	var seen := {}
	for i in p.rooms_on_storey(level):
		for j in p.rooms_on_storey(level):
			if j <= i:
				continue
			var edge: Array = HousePlanOpenings.shared_edge(p, i, j)
			if edge.is_empty():
				continue
			var normal: Vector2 = edge[0]
			var key := "%.2f|%.2f|%.2f|%.2f" % [normal.x, edge[1], edge[2], edge[3]]
			if seen.has(key):
				continue
			seen[key] = true
			var from: Vector2
			var to: Vector2
			if normal.x > 0.5:
				from = Vector2(edge[1], edge[2])
				to = Vector2(edge[1], edge[3])
			else:
				from = Vector2(edge[2], edge[1])
				to = Vector2(edge[3], edge[1])
			out.append({"from": from, "to": to, "thick": HouseGeometry.INNER_WALL_T,
				"kind": &"partition", "normal": normal, "pair": Vector2i(i, j)})
	for ci in p.courts_on(level):
		var court := Rect2(p.courts[ci]["rect"])
		var corners: Array[Vector2] = [court.position, Vector2(court.end.x, court.position.y),
			court.end, Vector2(court.position.x, court.end.y)]
		for k in range(4):
			out.append({"from": corners[k], "to": corners[(k + 1) % 4],
				"thick": HouseGeometry.wall_thickness(p.spec), "kind": &"court",
				"normal": Vector2.ZERO})
	return out


## The wall a door or window stands in: the nearest wall centre-line, the point
## of it nearest the opening, and how far off it the opening is. Exterior doors
## and windows are recorded on the inner face of their wall, half a wall
## thickness from its centre-line.
static func _on_wall(walls: Array[Dictionary], pos: Vector2) -> Dictionary:
	var best := {"wall": -1, "off": INF, "centre": pos, "along": Vector2.RIGHT, "thick": HouseGeometry.WALL_T}
	for wi in range(walls.size()):
		var a: Vector2 = walls[wi]["from"]
		var b: Vector2 = walls[wi]["to"]
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(pos, a, b)
		var dist: float = q.distance_to(pos)
		# of two walls meeting at the opening, the one it is nearer the middle of
		if dist < float(best["off"]) - 0.001:
			best = {"wall": wi, "off": dist, "centre": q,
				"along": (b - a).normalized(), "thick": float(walls[wi]["thick"])}
	return best


## +1 when the leaf swings to the side the door's normal points, -1 when it
## swings the other way. A door swings into the room it belongs to (`a`).
static func _swing_side(p: HousePlan, door: Dictionary) -> float:
	var room: int = int(door["a"])
	if room < 0 or room >= p.room_count():
		room = int(door["b"])
	if room < 0 or room >= p.room_count():
		return -1.0
	var poly: PackedVector2Array = HouseGeometry.room_floor_poly(p, room)
	var pos: Vector2 = door["pos"]
	var normal: Vector2 = door["normal"]
	if Poly.contains_point(poly, pos + normal * 0.3, 0.01):
		return 1.0
	return -1.0


static func first_word(key: String) -> String:
	var words: PackedStringArray = key.replace("_", " ").strip_edges().to_lower().split(" ", false)
	return words[0] if not words.is_empty() else key


## The oriented footprint of a piece, from its measured size and its yaw.
static func footprint_corners(item: Dictionary) -> PackedVector2Array:
	var rect: Rect2 = item["rect"]
	var key: String = String(item["key"])
	if not PropCatalog.known(key):
		return Poly.from_rect(rect)
	var yaw: float = float(item["yaw"])
	# A quarter turn is the plan rectangle itself; only an odd yaw (a piece in a
	# polygonal room) needs turning, and it turns about the centre of its rect.
	if absf(sin(yaw * 2.0)) < 0.02:
		return Poly.from_rect(rect)
	var half: Vector2 = PropCatalog.footprint(key) * 0.5
	var c: Vector2 = rect.get_center()
	var out := PackedVector2Array()
	for corner in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)]:
		var v := Vector3(corner.x, 0, corner.y)
		v = Basis(Vector3.UP, yaw) * v
		out.append(c + Vector2(v.x, v.z))
	return out


# ================================================================== elevation

## The front elevation, looked at from -Z, in metres: X across, Y up. The roof
## is the faces of roof_of() projected end on, so a hipped roof, a half hip
## and a ridge that runs across the front all come out the way they are built.
static func elevation(p: HousePlan) -> Dictionary:
	var spec: HouseSpec = p.spec
	var storeys: int = maxi(1, spec.storeys)
	var h: float = spec.height
	var levels: Array[Dictionary] = []
	var x0 := INF
	var x1 := -INF
	for level in levels_of(p):
		var r: Rect2 = HouseGeometry.storey_rect(p, level)
		levels.append({"level": level, "y0": float(level) * h, "y1": float(level + 1) * h,
			"x0": r.position.x, "x1": r.end.x, "front": r.position.y})
		x0 = minf(x0, r.position.x)
		x1 = maxf(x1, r.end.x)

	var wall_x0: float = x0
	var wall_x1: float = x1
	var roof := {"drawn": false, "faces": [], "hull": PackedVector2Array(), "ridge_y": 0.0,
		"eave_y": h * storeys, "note": ""}
	if p.has_court():
		roof["note"] = "ranges roofed round a court: roof not drawn"
	else:
		var layout: Dictionary = HouseGeometry.roof_of(p)
		var xf: Transform3D = layout["transform"]
		var faces: Array = []
		var all := PackedVector2Array()
		var top := -INF
		for face in layout["faces"]:
			var pts := PackedVector2Array()
			for v in face:
				var w: Vector3 = xf * v
				pts.append(Vector2(w.x, w.y))
				top = maxf(top, w.y)
			faces.append(pts)
			all.append_array(pts)
		if not all.is_empty():
			roof = {"drawn": true, "faces": faces, "hull": Poly.convex_hull(all), "ridge_y": top,
				"eave_y": xf.origin.y, "note": ""}
			var rb := Poly.bounding_rect(all)
			x0 = minf(x0, rb.position.x)
			x1 = maxf(x1, rb.end.x)

	# Doors and windows on the front wall, at the heights the builder cuts them.
	var openings: Array[Dictionary] = []
	for d in range(p.doors.size()):
		var door: Dictionary = p.doors[d]
		if not bool(door["exterior"]) or Vector2(door["normal"]).dot(Vector2(0, -1)) < 0.5:
			continue
		var level: int = HousePlan.record_storey(door)
		if level < 0:
			continue
		var width: float = float(door["width"])
		var cx: float = Vector2(door["pos"]).x
		openings.append({"kind": &"door", "index": d, "level": level, "x0": cx - width * 0.5,
			"x1": cx + width * 0.5, "y0": float(level) * h + float(door.get("sill", 0.0)),
			"y1": float(level) * h + minf(float(door.get("head", HouseGeometry.DOOR_H)), h),
			"front": d == p.entrance()})
	for w in range(p.windows.size()):
		var win: Dictionary = p.windows[w]
		if Vector2(win["normal"]).dot(Vector2(0, -1)) < 0.5:
			continue
		var level: int = HousePlan.record_storey(win)
		if level < 0:
			continue
		var width: float = float(win["width"])
		var cx: float = Vector2(win["pos"]).x
		openings.append({"kind": &"window", "index": w, "level": level, "x0": cx - width * 0.5,
			"x1": cx + width * 0.5, "y0": float(level) * h + float(win["sill"]),
			"y1": float(level) * h + float(win["head"]), "front": false})

	var chimney := {}
	if spec.chimney:
		var c: Vector2 = HouseGeometry.chimney_center(p)
		var s: float = HouseGeometry.chimney_size(spec)
		chimney = {"x0": c.x - s * 0.5, "x1": c.x + s * 0.5, "y1": HouseGeometry.ridge_of(spec) + HouseGeometry.CHIMNEY_TOP,
			"cap_x0": c.x - s * 0.5 - 0.11, "cap_x1": c.x + s * 0.5 + 0.11,
			"cap_y1": HouseGeometry.ridge_of(spec) + HouseGeometry.CHIMNEY_TOP - HouseGeometry.CHIMNEY_POT_H,
			"in_front": c.y < 0.0}
		x0 = minf(x0, chimney["cap_x0"])
		x1 = maxf(x1, chimney["cap_x1"])

	# The porch roof is a small gable, seen end on, when the door is on the front.
	var porch := {}
	var entrance: int = p.entrance()
	if spec.porch and entrance >= 0 and Vector2(p.doors[entrance]["normal"]).dot(Vector2(0, -1)) > 0.5:
		var pr: Rect2 = HouseGeometry.porch_rect(p)
		var head: float = HouseGeometry.DOOR_H + 0.35
		porch = {"x0": pr.position.x, "x1": pr.end.x, "head": head, "rise": 0.42}
	return {"levels": levels, "x0": x0, "x1": x1, "wall_x0": wall_x0, "wall_x1": wall_x1, "roof": roof, "openings": openings,
		"chimney": chimney, "porch": porch,
		"jetty": HouseGeometry.jetty_front_reach(spec), "wall_top": h * storeys,
		"total_height": HouseGeometry.shell_top(spec), "height": h, "storeys": storeys}


# =================================================================== schedule

## The title and the one line under it.
static func titles(p: HousePlan) -> Array[String]:
	var spec: HouseSpec = p.spec
	var style: String
	var purpose: String
	if spec is HotelSpec:
		style = BigGlade.option_label(&"hotel", &"style", (spec as HotelSpec).style)
		purpose = "hotel"
	elif spec is ShopSpec:
		style = BigGlade.option_label(&"shop", &"style", spec.style)
		purpose = BigGlade.option_label(&"shop", &"purpose", (spec as ShopSpec).business)
	else:
		style = BigGlade.option_label(&"house", &"style", spec.style)
		purpose = BigGlade.option_label(&"house", &"purpose", spec.trade)
	var storeys := "%d storey%s" % [spec.storeys, "" if spec.storeys == 1 else "s"]
	if int(spec.get("cellars")) > 0:
		storeys += " and a cellar"
	return ["%s  —  %s, %s" % [spec.variant_name, style, purpose],
		"%.1f × %.1f m   %s at %.1f m   %d rooms   %d fittings   seed %d"
			% [spec.width, spec.length, storeys, spec.height, p.room_count(),
				p.furniture.size(), spec.seed]]


## One entry per room: its heading and what stands in it, for the schedule.
static func schedule(p: HousePlan) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for i in range(p.room_count()):
		var f: Rect2 = HouseGeometry.room_floor_rect(p, i)
		var counts := {}
		for fi in p.furniture_of(i):
			var name: String = String(p.furniture[fi]["key"]).replace("_", " ").to_lower()
			counts[name] = int(counts.get(name, 0)) + 1
		var items: Array[String] = []
		for name in counts:
			items.append(name if counts[name] == 1 else "%d %s" % [counts[name], name])
		rows.append({"room": i, "level": p.storey_of_room(i),
			"head": "%s %s  %.1f × %.1f m  %dD %dW" % [level_label(p.storey_of_room(i)),
				String(p.kind_of(i)).replace("_", " "), f.size.x, f.size.y,
				p.doors_of(i).size(), p.windows_of(i).size()],
			"items": ", ".join(items) if not items.is_empty() else "-"})
	return rows


# ===================================================================== layout

## Where everything goes on a page of `size`. Plans take the left of a wide
## page and the elevation and schedule the right; a tall page stacks them.
static func layout(m: Dictionary, size: Vector2) -> Dictionary:
	var main := Rect2(Vector2(0, 48), Vector2(size.x, size.y - 48 - 6))
	var plans: Rect2
	var elev: Rect2
	var sched: Rect2
	if size.x >= size.y * 1.15:
		var split: float = floorf(main.size.x * 0.58)
		plans = Rect2(main.position, Vector2(split, main.size.y))
		var rest := Rect2(main.position + Vector2(split, 0), Vector2(main.size.x - split, main.size.y))
		var eh: float = floorf(rest.size.y * 0.52)
		elev = Rect2(rest.position, Vector2(rest.size.x, eh))
		sched = Rect2(rest.position + Vector2(0, eh), Vector2(rest.size.x, rest.size.y - eh))
	else:
		var ph: float = floorf(main.size.y * 0.5)
		plans = Rect2(main.position, Vector2(main.size.x, ph))
		var eh: float = floorf((main.size.y - ph) * 0.55)
		elev = Rect2(main.position + Vector2(0, ph), Vector2(main.size.x, eh))
		sched = Rect2(main.position + Vector2(0, ph + eh), Vector2(main.size.x, main.size.y - ph - eh))

	var levels: Array = m["levels"]
	var ext: Rect2 = m["extent"]
	var best_cols := 1
	var best_scale := 0.0
	for cols in range(1, levels.size() + 1):
		var rows: int = ceili(float(levels.size()) / float(cols))
		var cell := Vector2(plans.size.x / cols, plans.size.y / rows)
		var sc: float = minf((cell.x - PLAN_PAD.x) / ext.size.x, (cell.y - PLAN_PAD.y) / ext.size.y)
		if sc > best_scale:
			best_scale = sc
			best_cols = cols
	var rows_n: int = ceili(float(levels.size()) / float(best_cols))
	var cell_size := Vector2(plans.size.x / best_cols, plans.size.y / rows_n)
	var cells := {}
	for k in range(levels.size()):
		cells[levels[k]] = Rect2(plans.position + Vector2((k % best_cols) * cell_size.x,
			(k / best_cols) * cell_size.y), cell_size)
	return {"plans": plans, "elevation": elev, "schedule": sched, "cells": cells,
		"scale": maxf(best_scale, 0.0), "cols": best_cols}


## Margins inside one plan cell: the label and the width dimension above the
## footprint, the front door's arrow and the scale below it, the length
## dimension to its right.
const PLAN_PAD := Vector2(84, 96)


## Model -> paper for one plan cell. The front (-Z) is at the foot of the cell
## and +X is on the left, so the plan has the hand of the elevation.
static func plan_to_paper(cell: Rect2, ext: Rect2, scale: float) -> Callable:
	var origin: Vector2 = cell.position + Vector2(PLAN_PAD.x * 0.35 + (cell.size.x - PLAN_PAD.x) * 0.5,
		44.0 + (cell.size.y - PLAN_PAD.y) * 0.5)
	var centre: Vector2 = ext.get_center()
	return func(q: Vector2) -> Vector2:
		return origin + Vector2(-(q.x - centre.x), -(q.y - centre.y)) * scale


# ====================================================================== paper

func draw(view: BlueprintView) -> void:
	var size: Vector2 = view.size
	view.draw_rect(Rect2(Vector2.ZERO, size), PAPER, true)
	if size.x < 120.0 or size.y < 120.0:
		return
	var font := ThemeDB.fallback_font
	var head: Array[String] = titles(plan)
	view.draw_string(font, Vector2(12, 22), head[0], HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 15, INK)
	view.draw_string(font, Vector2(12, 40), head[1], HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 11, LIGHT)
	var lay: Dictionary = layout(model, size)
	var scale: float = lay["scale"]
	if scale <= 0.0:
		return
	var ext: Rect2 = model["extent"]
	for level in model["levels"]:
		var cell: Rect2 = lay["cells"][level]
		_draw_plan(view, model["by_level"][level], cell, plan_to_paper(cell, ext, scale), scale, level)
	_draw_notes(view, lay, scale)
	_draw_elevation(view, lay["elevation"])
	_draw_schedule(view, lay["schedule"])


func _draw_plan(view: BlueprintView, data: Dictionary, cell: Rect2, to_paper: Callable, scale: float, level: int) -> void:
	var font := ThemeDB.fallback_font
	var tag: String = level_label(level)
	view.draw_string(font, cell.position + Vector2(8, 16), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)
	view.draw_string(font, cell.position + Vector2(8 + font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 8, 16),
		"plan, front (-Z) at the foot", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, LIGHT)

	# ground: courts are open to the sky, rooms are floor
	for court in data["courts"]:
		view.draw_colored_polygon(_paper_poly(court["poly"], to_paper), COURT_FILL)
	for room in data["rooms"]:
		view.draw_colored_polygon(_paper_poly(room["poly"], to_paper), FLOOR_FILL)
	for rug in data["rugs"]:
		view.draw_colored_polygon(_paper_poly(Poly.from_rect(rug), to_paper), FAINT)

	# walls, solid: the poche that makes a plan read as masonry and timber
	for wall in data["walls"]:
		view.draw_colored_polygon(_wall_quad(wall, to_paper), WALL_FILL)

	for item in data["furniture"]:
		_draw_piece(view, item, to_paper, scale)
	for hatch in data["hatches"]:
		var hp: PackedVector2Array = _paper_poly(Poly.from_rect(hatch), to_paper)
		view.draw_polyline(_closed(hp), INK, 1.0)
		view.draw_line(hp[0], hp[2], LIGHT, 1.0)
		view.draw_line(hp[1], hp[3], LIGHT, 1.0)
	for stair in data["stairs"]:
		_draw_stair(view, stair, to_paper, scale)
	_draw_hearth(view, data["hearth"], to_paper)
	if Rect2(data["porch"]).size.x > 0.0:
		view.draw_polyline(_closed(_paper_poly(Poly.from_rect(data["porch"]), to_paper)), LIGHT, 1.0)

	for win in data["windows"]:
		_draw_window(view, win, to_paper)
	for door in data["doors"]:
		_draw_door(view, door, to_paper, scale)

	for room in data["rooms"]:
		_draw_room_label(view, room, to_paper)

	# dimensions: outer width above the plan, outer length down its right side,
	# both clear of the chimney and the porch, which stand outside the walls
	var site: Rect2 = HouseGeometry.storey_rect(plan, level)
	var ext: Rect2 = model["extent"]
	var left: float = to_paper.call(Vector2(site.end.x, 0)).x
	var right: float = to_paper.call(Vector2(site.position.x, 0)).x
	var top: float = to_paper.call(Vector2(0, ext.end.y)).y - 14.0
	view._dim_line(Vector2(left, top), Vector2(right, top), "%.1f m" % site.size.x, INK, LIGHT)
	var rail: float = to_paper.call(Vector2(ext.position.x, 0)).x + 18.0
	var upper: float = to_paper.call(Vector2(0, site.end.y)).y
	var lower: float = to_paper.call(Vector2(0, site.position.y)).y
	view._dim_line_v(Vector2(rail, upper), Vector2(rail, lower), "%.1f m" % site.size.y, INK, LIGHT)


func _draw_room_label(view: BlueprintView, room: Dictionary, to_paper: Callable) -> void:
	var font := ThemeDB.fallback_font
	var r: Rect2 = room["floor"]
	var a: Vector2 = to_paper.call(r.position)
	var b: Vector2 = to_paper.call(r.end)
	var box := Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (a - b).abs())
	var name: String = String(room["label"])
	var dims: String = "%.1f × %.1f m" % [room["size"].x, room["size"].y]
	var fs := 10
	var name_w: float = font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var dim_w: float = font.get_string_size(dims, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var w: float = maxf(name_w, dim_w) + 6.0
	if box.size.x < w or box.size.y < 26.0:
		if box.size.x >= 18.0 and box.size.y >= 12.0:
			name = name.substr(0, 1).to_upper()
			view.draw_string(font, box.position + Vector2(3, 10), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, INK)
		return
	view.draw_rect(Rect2(box.position + Vector2(1, 1), Vector2(w, 24)), Color(1, 1, 1, 0.82), true)
	view.draw_string(font, box.position + Vector2(4, 12), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK)
	view.draw_string(font, box.position + Vector2(4, 22), dims, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, LIGHT)


func _draw_piece(view: BlueprintView, item: Dictionary, to_paper: Callable, scale: float) -> void:
	var corners: PackedVector2Array = _paper_poly(footprint_corners(item), to_paper)
	var small: bool = bool(item["on_host"]) or bool(item["mounted"])
	view.draw_colored_polygon(corners, Color(0.15, 0.28, 0.43, 0.05 if small else 0.10))
	view.draw_polyline(_closed(corners), Color(0.15, 0.28, 0.43, 0.5 if small else 0.9), 1.0 if small else 1.2)
	if small:
		return
	var r: Rect2 = item["rect"]
	var w: float = r.size.x * scale
	var h: float = r.size.y * scale
	var font := ThemeDB.fallback_font
	var text: String = String(item["label"])
	var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var c: Vector2 = to_paper.call(r.get_center())
	if tw + 2.0 <= w and h >= 9.0:
		view.draw_string(font, c + Vector2(-tw * 0.5, 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, INK)
	elif minf(w, h) >= 8.0:
		view.draw_string(font, c + Vector2(-3, 3), text.substr(0, 1).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, INK)


func _draw_door(view: BlueprintView, door: Dictionary, to_paper: Callable, scale: float) -> void:
	var along: Vector2 = door["along"]
	var t: float = float(door["thick"]) + 0.06
	var c: Vector2 = door["centre"]
	var half: Vector2 = along * (float(door["width"]) * 0.5)
	var across: Vector2 = Vector2(-along.y, along.x) * (t * 0.5)
	var gap := PackedVector2Array([c - half - across, c + half - across, c + half + across, c - half + across])
	view.draw_colored_polygon(_paper_poly(gap, to_paper), FLOOR_FILL)
	var hinge: Vector2 = to_paper.call(door["hinge"])
	var tip: Vector2 = to_paper.call(door["tip"])
	var latch: Vector2 = to_paper.call(door["latch"])
	var weight: float = 2.0 if door["front"] else 1.2
	view.draw_line(hinge, tip, INK, weight)
	# the swing: a quarter circle from the closed leaf to the open one
	var radius: float = float(door["width"]) * scale
	var a0: float = (latch - hinge).angle()
	var sweep: float = wrapf((tip - hinge).angle() - a0, -PI, PI)
	var arc := PackedVector2Array()
	for k in range(11):
		arc.append(hinge + Vector2.from_angle(a0 + sweep * float(k) / 10.0) * radius)
	view.draw_polyline(arc, LIGHT, 1.0)
	if door["front"]:
		# the way in: an arrowhead outside the door, pointing at it
		var out_dir: Vector2 = (to_paper.call(Vector2(door["centre"]) + Vector2(door["normal"]) * 1.0) - to_paper.call(door["centre"])).normalized()
		var base: Vector2 = to_paper.call(door["centre"]) + out_dir * (scale * 0.9 + 8.0)
		var side := Vector2(-out_dir.y, out_dir.x) * 4.0
		view.draw_colored_polygon(PackedVector2Array([base - out_dir * 9.0, base + side, base - side]), INK)
		view.draw_line(base, base + out_dir * 10.0, INK, 1.4)
		view.draw_string(ThemeDB.fallback_font, base + out_dir * 22.0 + Vector2(-14, 4), "front",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, INK)


func _draw_window(view: BlueprintView, win: Dictionary, to_paper: Callable) -> void:
	var along: Vector2 = win["along"]
	var t: float = float(win["thick"])
	var c: Vector2 = win["centre"]
	var half: Vector2 = along * (float(win["width"]) * 0.5)
	var across: Vector2 = Vector2(-along.y, along.x)
	var gap := PackedVector2Array([c - half - across * (t * 0.5 + 0.02), c + half - across * (t * 0.5 + 0.02),
		c + half + across * (t * 0.5 + 0.02), c - half + across * (t * 0.5 + 0.02)])
	view.draw_colored_polygon(_paper_poly(gap, to_paper), FLOOR_FILL)
	# three lines in the thickness of the wall: the two faces and the glass
	for off in [-0.5, 0.0, 0.5]:
		var a: Vector2 = to_paper.call(c - half + across * (t * off))
		var b: Vector2 = to_paper.call(c + half + across * (t * off))
		view.draw_line(a, b, INK, 1.2 if off == 0.0 else 0.9)
	for end_sign in [-1.0, 1.0]:
		var e: Vector2 = c + half * end_sign
		view.draw_line(to_paper.call(e - across * (t * 0.5)), to_paper.call(e + across * (t * 0.5)), INK, 1.0)


func _draw_stair(view: BlueprintView, stair: Dictionary, to_paper: Callable, scale: float) -> void:
	var r: Rect2 = stair["rect"]
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	var up: bool = stair["up"]
	var ink: Color = INK if up else LIGHT
	var poly: PackedVector2Array = _paper_poly(Poly.from_rect(r), to_paper)
	view.draw_colored_polygon(poly, Color(1, 1, 1, 0.9))
	view.draw_polyline(_closed(poly), ink, 1.3)
	var steps: int = stair["steps"]
	var along_x: bool = stair["along_x"]
	for s in range(1, steps):
		var t: float = float(s) / float(steps)
		var a: Vector2 = Vector2(r.position.x + r.size.x * t, r.position.y) if along_x else Vector2(r.position.x, r.position.y + r.size.y * t)
		var b: Vector2 = Vector2(r.position.x + r.size.x * t, r.end.y) if along_x else Vector2(r.end.x, r.position.y + r.size.y * t)
		view.draw_line(to_paper.call(a), to_paper.call(b), ink, 0.8)
	# the arrow climbs the way the builder lays the treads: toward +X or +Z
	var dir: Vector2 = Vector2(1, 0) if along_x else Vector2(0, 1)
	var mid: Vector2 = r.get_center()
	var half_run: float = (r.size.x if along_x else r.size.y) * 0.38
	var tail: Vector2 = to_paper.call(mid - dir * half_run * (1.0 if up else -1.0))
	var head: Vector2 = to_paper.call(mid + dir * half_run * (1.0 if up else -1.0))
	view.draw_line(tail, head, ink, 1.5)
	var d: Vector2 = (head - tail).normalized()
	var n := Vector2(-d.y, d.x) * 3.5
	view.draw_colored_polygon(PackedVector2Array([head, head - d * 7.0 + n, head - d * 7.0 - n]), ink)
	view.draw_string(ThemeDB.fallback_font, tail + Vector2(-6, -4), "UP" if up else "DN",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ink)


func _draw_hearth(view: BlueprintView, hearth: Dictionary, to_paper: Callable) -> void:
	if hearth.is_empty():
		return
	var stack: Rect2 = hearth["stack"]
	if stack.size.x > 0.0:
		var poly: PackedVector2Array = _paper_poly(Poly.from_rect(stack), to_paper)
		if hearth["solid"]:
			view.draw_colored_polygon(poly, Color(0.15, 0.28, 0.43, 0.32))
			view.draw_polyline(_closed(poly), INK, 1.3)
			view.draw_line(poly[0], poly[2], INK, 0.9)
			view.draw_line(poly[1], poly[3], INK, 0.9)
		else:
			_dashed(view, _closed(poly), LIGHT)
	var breast := Rect2(hearth["breast"])
	if breast.size.x > 0.0:
		var bp: PackedVector2Array = _paper_poly(Poly.from_rect(breast), to_paper)
		view.draw_colored_polygon(bp, Color(0.15, 0.28, 0.43, 0.22))
		view.draw_polyline(_closed(bp), INK, 1.0)


func _draw_notes(view: BlueprintView, lay: Dictionary, scale: float) -> void:
	var plans: Rect2 = lay["plans"]
	var font := ThemeDB.fallback_font
	# north arrow, in the corner of the plans
	var north: Vector2 = model["north"]
	var dir := Vector2(-north.x, -north.y).normalized()     # same hand as the plan
	var c: Vector2 = plans.position + Vector2(plans.size.x - 22.0, 30.0)
	view.draw_arc(c, 13.0, 0.0, TAU, 20, LIGHT, 1.0)
	var tip: Vector2 = c + dir * 12.0
	var tail: Vector2 = c - dir * 8.0
	view.draw_line(tail, tip, INK, 1.6)
	var n := Vector2(-dir.y, dir.x) * 3.5
	view.draw_colored_polygon(PackedVector2Array([tip, tip - dir * 7.0 + n, tip - dir * 7.0 - n]), INK)
	view.draw_string(font, c + dir * 24.0 + Vector2(-4, 4), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK)
	# scale bar, in whole metres
	var span: float = (plans.size.x * 0.22) / scale
	var metres := 1.0
	for nice in [1.0, 2.0, 5.0, 10.0, 20.0]:
		if nice <= span:
			metres = nice
	var origin: Vector2 = plans.position + Vector2(10.0, plans.size.y - 8.0)
	var length: float = metres * scale
	for k in range(2):
		var seg := Rect2(origin + Vector2(length * 0.5 * k, -4.0), Vector2(length * 0.5, 4.0))
		view.draw_rect(seg, INK if k == 0 else PAPER, true)
		view.draw_rect(seg, INK, false, 1.0)
	view.draw_string(font, origin + Vector2(-3, -8), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, INK)
	view.draw_string(font, origin + Vector2(length - 4, -8), "%d m" % int(metres), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, INK)


func _draw_elevation(view: BlueprintView, area: Rect2) -> void:
	var e: Dictionary = model["elevation"]
	var font := ThemeDB.fallback_font
	view.draw_string(font, area.position + Vector2(12, 14), "front elevation, -Z", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK)
	view.draw_string(font, area.position + Vector2(12, 27),
		"Roof from the builder's own roof faces; +X is on the left, as in the plans.",
		HORIZONTAL_ALIGNMENT_LEFT, area.size.x - 20, 8, LIGHT)
	var top: float = e["total_height"]
	var span: float = float(e["x1"]) - float(e["x0"])
	var cellar_depth: float = 0.0
	for lv in e["levels"]:
		cellar_depth = maxf(cellar_depth, -float(lv["y0"]))
	var sc: float = minf((area.size.x - 124.0) / span, (area.size.y - 64.0) / (top + cellar_depth))
	if sc <= 0.0:
		return
	var gy: float = area.end.y - 22.0 - cellar_depth * sc
	var xc: float = (float(e["x0"]) + float(e["x1"])) * 0.5
	var ox: float = area.position.x + (area.size.x - 54.0) * 0.5
	var fx := func(x: float) -> float: return ox - (x - xc) * sc
	var fy := func(y: float) -> float: return gy - y * sc
	var pt := func(x: float, y: float) -> Vector2: return Vector2(fx.call(x), fy.call(y))
	var box := func(x0: float, y0: float, x1: float, y1: float) -> Rect2:
		var a: Vector2 = pt.call(x1, y1)
		var b: Vector2 = pt.call(x0, y0)
		return Rect2(a, b - a)

	view.draw_line(Vector2(fx.call(float(e["x1"])) - 10, gy), Vector2(fx.call(float(e["x0"])) + 10, gy), INK, 2.0)

	var chimney: Dictionary = e["chimney"]
	var chimney_behind: bool = not chimney.is_empty() and not bool(chimney["in_front"])
	if chimney_behind:
		_draw_chimney(view, chimney, pt, box)

	for lv in e["levels"]:
		var r: Rect2 = box.call(lv["x0"], lv["y0"], lv["x1"], lv["y1"])
		if int(lv["level"]) < 0:
			view.draw_rect(r, FAINT, true)
			_dashed(view, _closed(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])), LIGHT)
			view.draw_string(font, r.position + Vector2(4, 12), "cellar", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, LIGHT)
			continue
		view.draw_rect(r, FLOOR_FILL, true)
		view.draw_rect(r, INK, false, 1.6)
	if float(e["jetty"]) > 0.0:
		var jy: float = float(e["height"])
		view.draw_line(pt.call(e["x0"] - 0.1, jy), pt.call(e["x1"] + 0.1, jy), INK, 2.4)
		view.draw_string(font, pt.call(e["x1"], jy) + Vector2(4, -3), "jetty +%.2f m" % float(e["jetty"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, LIGHT)

	var roof: Dictionary = e["roof"]
	if roof["drawn"]:
		var hull := PackedVector2Array()
		for v in roof["hull"]:
			hull.append(pt.call(v.x, v.y))
		view.draw_colored_polygon(hull, ROOF_FILL)
		for face in roof["faces"]:
			var fp := PackedVector2Array()
			for v in face:
				fp.append(pt.call(v.x, v.y))
			view.draw_polyline(_closed(fp), LIGHT, 1.0)
		view.draw_polyline(_closed(hull), INK, 1.8)
	elif String(roof["note"]) != "":
		view.draw_string(font, area.position + Vector2(12, 40), String(roof["note"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, LIGHT)

	if not chimney.is_empty() and not chimney_behind:
		_draw_chimney(view, chimney, pt, box)

	for op in e["openings"]:
		var r: Rect2 = box.call(op["x0"], op["y0"], op["x1"], op["y1"])
		view.draw_rect(r, FLOOR_FILL, true)
		view.draw_rect(r, INK, false, 1.3 if op["kind"] == &"door" else 1.1)
		if op["kind"] == &"window":
			view.draw_line(Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y), LIGHT, 1.0)
			view.draw_line(Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y), LIGHT, 1.0)
		elif op["front"]:
			view.draw_circle(Vector2(r.end.x - 3.0, r.get_center().y), 1.6, INK)

	var porch: Dictionary = e["porch"]
	if not porch.is_empty():
		var head: float = porch["head"]
		var pr: Rect2 = box.call(porch["x0"], 0.0, porch["x1"], head)
		view.draw_rect(pr, Color(1, 1, 1, 0.0), false, 1.2)
		view.draw_colored_polygon(PackedVector2Array([pt.call(porch["x1"], head), pt.call(porch["x0"], head),
			pt.call((porch["x0"] + porch["x1"]) * 0.5, head + porch["rise"])]), ROOF_FILL)
		view.draw_polyline(PackedVector2Array([pt.call(porch["x1"], head), pt.call((porch["x0"] + porch["x1"]) * 0.5, head + porch["rise"]),
			pt.call(porch["x0"], head), pt.call(porch["x1"], head)]), INK, 1.3)

	# storey heights down the left (the +X side), the overall height at right
	var left: float = fx.call(float(e["x1"])) - 14.0
	for lv in e["levels"]:
		if int(lv["level"]) < 0:
			continue
		view._dim_line_v(Vector2(left, fy.call(lv["y0"])), Vector2(left, fy.call(lv["y1"])), "", INK, LIGHT)
		view.draw_string(font, Vector2(left - 26, (fy.call(lv["y0"]) + fy.call(lv["y1"])) * 0.5 + 3),
			level_label(int(lv["level"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, INK)
	var rx: float = fx.call(float(e["x0"])) + 22.0
	view._dim_line_v(Vector2(rx, fy.call(top)), Vector2(rx, gy), "%.1f m" % top, INK, LIGHT)
	var ridge: float = roof["ridge_y"] if roof["drawn"] else e["wall_top"]
	var rx2: float = rx + 36.0
	if roof["drawn"]:
		view.draw_line(Vector2(fx.call(float(e["x0"])) + 4, fy.call(ridge)), Vector2(rx2 - 4, fy.call(ridge)), LIGHT, 0.8)
		view.draw_string(font, Vector2(rx - 64, fy.call(ridge) - 3), "ridge %.1f m" % ridge, HORIZONTAL_ALIGNMENT_RIGHT, 60, 8, INK)
	var foot: float = gy + 14.0 + cellar_depth * sc
	view._dim_line(Vector2(fx.call(float(e["wall_x1"])), foot), Vector2(fx.call(float(e["wall_x0"])), foot),
		"%.1f m" % (float(e["wall_x1"]) - float(e["wall_x0"])), INK, LIGHT)


func _draw_chimney(view: BlueprintView, c: Dictionary, pt: Callable, box: Callable) -> void:
	var stack: Rect2 = box.call(c["x0"], 0.0, c["x1"], c["cap_y1"] - 0.18)
	view.draw_rect(stack, FLOOR_FILL, true)
	view.draw_rect(stack, INK, false, 1.3)
	var cap: Rect2 = box.call(c["cap_x0"], c["cap_y1"] - 0.18, c["cap_x1"], c["cap_y1"])
	view.draw_rect(cap, INK, true)
	var pot: Rect2 = box.call((c["x0"] + c["x1"]) * 0.5 - HouseGeometry.CHIMNEY_POT_R,
		c["cap_y1"], (c["x0"] + c["x1"]) * 0.5 + HouseGeometry.CHIMNEY_POT_R, c["y1"])
	view.draw_rect(pot, INK, false, 1.2)


func _draw_schedule(view: BlueprintView, area: Rect2) -> void:
	var font := ThemeDB.fallback_font
	view.draw_line(area.position + Vector2(10, 2), area.position + Vector2(area.size.x - 10, 2), FAINT, 1.0)
	view.draw_string(font, area.position + Vector2(12, 16), "schedule  (D doors, W windows)", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, INK)
	var rows: Array[Dictionary] = schedule(plan)
	var y: float = area.position.y + 30.0
	var width: float = area.size.x - 24.0
	var shown := 0
	for row in rows:
		var items: String = String(row["items"])
		var body_h: float = font.get_multiline_string_size(items, HORIZONTAL_ALIGNMENT_LEFT, width - 10.0, 8).y
		var need: float = 11.0 + body_h + 3.0
		if y + need > area.end.y - 14.0:
			break
		view.draw_string(font, Vector2(area.position.x + 12, y + 8), String(row["head"]), HORIZONTAL_ALIGNMENT_LEFT, width, 9, INK)
		view.draw_multiline_string(font, Vector2(area.position.x + 22, y + 19), items,
			HORIZONTAL_ALIGNMENT_LEFT, width - 10.0, 8, -1, LIGHT)
		y += need + 2.0
		shown += 1
	if shown < rows.size():
		view.draw_string(font, Vector2(area.position.x + 12, y + 8), "... and %d more room%s" % [rows.size() - shown, "" if rows.size() - shown == 1 else "s"],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, LIGHT)


# ===================================================================== helpers

static func _paper_poly(poly: PackedVector2Array, to_paper: Callable) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in poly:
		out.append(to_paper.call(p))
	return out


static func _closed(poly: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array(poly)
	if not out.is_empty():
		out.append(out[0])
	return out


## A wall centre-line as a quad of its own thickness, run on half a thickness at
## each end so two walls that meet make a whole corner.
static func _wall_quad(wall: Dictionary, to_paper: Callable) -> PackedVector2Array:
	var a: Vector2 = wall["from"]
	var b: Vector2 = wall["to"]
	var t: float = float(wall["thick"])
	var d: Vector2 = (b - a).normalized()
	var n := Vector2(-d.y, d.x) * (t * 0.5)
	var e: Vector2 = d * (t * 0.5)
	return _paper_poly(PackedVector2Array([a - e - n, b + e - n, b + e + n, a - e + n]), to_paper)


static func _dashed(view: BlueprintView, line: PackedVector2Array, color: Color) -> void:
	for k in range(line.size() - 1):
		var a: Vector2 = line[k]
		var b: Vector2 = line[k + 1]
		var length: float = a.distance_to(b)
		var steps: int = maxi(1, int(length / 6.0))
		for s in range(0, steps, 2):
			view.draw_line(a.lerp(b, float(s) / steps), a.lerp(b, minf(float(s + 1) / steps, 1.0)), color, 1.0)

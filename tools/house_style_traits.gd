extends SceneTree
## LIVE-HOUSE-STYLES: the per-style trait table.
##
## For every `HouseSpec.STYLES` row, build the same fixed fixtures through the
## public path (BrickWild.default_request + public small/default/large scale,
## ordinary household, no trade) and MEASURE what a reviewer could see:
##
##   silhouette  roof form, pitch, overhang, total height over wall height,
##               storeys, the exterior component vocabulary (role set)
##   plan        room-kind multiset, room count, largest-room share, hall share
##   surfaces    wall thickness (reveal depth), glazing per floor area, sill
##   use         furniture count and the furniture key vocabulary
##   palette     wall/roof colour -- recorded, NEVER counted as identity
##
## Then, per style, the nearest other style on each axis and on the combined
## non-palette distance. A pair that is near on every axis is a confusion; the
## table says so rather than awarding identity for a label or a colour.
##
##   godot --headless --path . --script res://tools/house_style_traits.gd \
##       -- [seeds=1,8102] [sizes=small,default,large] [furnish=1] \
##          [out=res://artifacts/hstyles/traits]
##
## Writes <out>.json (every house) and <out>.md (the per-style table) and
## prints the markdown. Plan-only (`furnish=0`) is about ten times faster and
## drops the use axis.

const DEFAULT_SEEDS := [1, 8102]
const DEFAULT_SIZES := ["small", "default", "large"]
const DEFAULT_OUT := "res://artifacts/hstyles/traits"
## Axes that count towards identity. Palette is deliberately not one of them.
const AXES := ["silhouette", "exterior_vocab", "plan", "surfaces", "use"]


func _init() -> void:
	var opts := _options(OS.get_cmdline_user_args())
	var seeds: Array = []
	for s in String(opts.get("seeds", ",".join(DEFAULT_SEEDS.map(func(v): return str(v))))).split(","):
		seeds.append(int(s))
	var sizes: Array = Array(String(opts.get("sizes", ",".join(DEFAULT_SIZES))).split(","))
	var furnish := String(opts.get("furnish", "1")) != "0"
	var out := String(opts.get("out", DEFAULT_OUT))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))

	var rows: Array[Dictionary] = []
	var t0 := Time.get_ticks_msec()
	for style in HouseSpec.STYLES.keys():
		for size in sizes:
			for seed_value in seeds:
				var row := _measure(StringName(style), String(size), int(seed_value), furnish)
				if not row.is_empty():
					rows.append(row)
	var md := _report(rows, furnish)
	md += "\n_%d houses in %.1f s; seeds %s; sizes %s; furnish=%s_\n" % [rows.size(),
		(Time.get_ticks_msec() - t0) / 1000.0, str(seeds), str(sizes), str(furnish)]
	var f := FileAccess.open(out + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify(rows, "\t", true, true))
	f.close()
	f = FileAccess.open(out + ".md", FileAccess.WRITE)
	f.store_string(md)
	f.close()
	print(md)
	quit(0)


## One house, measured.
func _measure(style: StringName, size: String, seed_value: int, furnish: bool) -> Dictionary:
	var request: BuildingRequest = BrickWild.default_request(&"house", seed_value)
	request.style = style
	request.purpose = &"none"
	_apply_scale(request, BrickWild.describe_kind(&"house"), size)
	var plan: HousePlan
	var spec: HouseSpec
	if furnish:
		# The public path, so the table describes the same house the renders show.
		var building: GeneratedBuilding = BrickWild.generate(request)
		if not building.is_ok():
			printerr("generation failed %s %s %d: %s" % [style, size, seed_value, building.errors])
			return {}
		plan = building.plan
		spec = plan.spec
	else:
		spec = HouseSpec.new()
		spec.style = style
		spec.trade = &"none"
		spec.width = request.width
		spec.length = request.length
		spec.height = request.height
		spec.storeys = request.storeys
		plan = HouseGenerator.generate(spec, seed_value, false)
	var builder := HouseBuilder.new()
	var mesh: ArrayMesh = builder.build(plan)
	var aabb := mesh.get_aabb()

	var wall_top := spec.plinth_height + spec.height * float(spec.storeys)
	var roles := {}
	for c in builder.component_log:
		var role := String(c.get("role", ""))
		# strip a numeric tail so dormer_1 / window_7 read as one vocabulary word
		var stem := role.rstrip("0123456789_#")
		roles[stem] = int(roles.get(stem, 0)) + 1

	var kinds: Array[String] = []
	var floor_area := 0.0
	var largest := 0.0
	var hall_area := 0.0
	for i in plan.rooms.size():
		var rect: Rect2 = plan.rooms[i]["rect"]
		var a := rect.get_area()
		floor_area += a
		largest = maxf(largest, a)
		kinds.append(String(plan.kind_of(i)))
		if plan.kind_of(i) == &"hall":
			hall_area += a
	kinds.sort()

	var glazing := 0.0
	var sill := 0.0
	for w in plan.windows:
		glazing += float(w.get("width", 0.0)) * (float(w.get("head", 0.0)) - float(w.get("sill", 0.0)))
		sill += float(w.get("sill", 0.0))
	var furniture_keys := {}
	var furniture_cats := {}
	for p in plan.furniture:
		furniture_keys[String(p.get("key", ""))] = true
		furniture_cats[String(p.get("cat", ""))] = int(furniture_cats.get(String(p.get("cat", "")), 0)) + 1

	return {
		"style": String(style), "size": size, "seed": seed_value,
		"w": spec.width, "l": spec.length, "storeys": spec.storeys, "storey_h": spec.height,
		"roof_type": String(spec.roof_type), "roof_material": String(spec.roof_material),
		"roof_pitch": snappedf(spec.roof_pitch, 0.01),
		"height_ratio": snappedf(aabb.size.y / maxf(wall_top, 0.1), 0.01),
		"overhang": snappedf(maxf(aabb.size.x - spec.width, aabb.size.z - spec.length) * 0.5, 0.01),
		"plan_aspect": snappedf(maxf(spec.width, spec.length) / minf(spec.width, spec.length), 0.01),
		"wall_t": snappedf(HouseGeometry.wall_thickness(spec), 0.01),
		"flags": _flags(spec),
		"roles": roles,
		"rooms": kinds, "room_count": kinds.size(),
		"floor_area": snappedf(floor_area, 0.1),
		"largest_share": snappedf(largest / maxf(floor_area, 0.1), 0.01),
		"hall_share": snappedf(hall_area / maxf(floor_area, 0.1), 0.01),
		"glazing_per_m2": snappedf(glazing / maxf(floor_area, 0.1), 0.001),
		"mean_sill": snappedf(sill / maxf(float(plan.windows.size()), 1.0), 0.01),
		"windows": plan.windows.size(), "doors": plan.doors.size(),
		"furniture": plan.furniture.size(), "furniture_keys": furniture_keys.keys(),
		"furniture_cats": furniture_cats,
		"wall_color": spec.wall_color.to_html(false), "roof_color": spec.roof_color.to_html(false),
	}


func _flags(spec: HouseSpec) -> Array[String]:
	var out: Array[String] = []
	for f in ["porch", "chimney", "window_shutters", "timber_frame", "jetty", "dormers",
			"bargeboards", "cornice", "pediments", "parapet", "veranda", "eave_sweep",
			"thatch_roll", "corner_piers", "stone_ground_floor"]:
		if bool(spec.get(f)):
			out.append(f)
	return out


## The per-style table and the confusion list.
func _report(rows: Array[Dictionary], furnish: bool) -> String:
	var by_style := {}
	for r in rows:
		if not by_style.has(r["style"]):
			by_style[r["style"]] = []
		by_style[r["style"]].append(r)
	var styles: Array = by_style.keys()
	var md := "## Measured per-style traits\n\n"
	md += "| style | roof forms | material | pitch | height/wall | overhang m | storeys | wall t | flags (>=50%) | rooms (default) | largest share | glazing/m2 | sill | furniture | distinct keys |\n"
	md += "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|\n"
	for s in styles:
		var rs: Array = by_style[s]
		var forms := {}
		var flag_n := {}
		var keys := {}
		for r in rs:
			forms[r["roof_type"]] = true
			for f in r["flags"]:
				flag_n[f] = int(flag_n.get(f, 0)) + 1
			for k in r["furniture_keys"]:
				keys[k] = true
		var common: Array[String] = []
		for f in flag_n:
			if flag_n[f] * 2 >= rs.size():
				common.append(f)
		var default_rooms := ""
		for r in rs:
			if r["size"] == "default":
				default_rooms = ",".join(r["rooms"])
				break
		md += "| %s | %s | %s | %.2f | %.2f | %.2f | %s | %.2f | %s | %s | %.2f | %.3f | %.2f | %.1f | %d |\n" % [
			s, "/".join(forms.keys()), rs[0]["roof_material"], _mean(rs, "roof_pitch"),
			_mean(rs, "height_ratio"), _mean(rs, "overhang"), _range(rs, "storeys"),
			_mean(rs, "wall_t"), " ".join(common), default_rooms,
			_mean(rs, "largest_share"), _mean(rs, "glazing_per_m2"), _mean(rs, "mean_sill"),
			_mean(rs, "furniture"), keys.size()]

	md += "\n## Nearest neighbour per axis (0 = identical, 1 = disjoint)\n\n"
	md += "Distances are means over the matched fixtures (same size, same seed).\n"
	md += "Palette is excluded. A style whose nearest neighbour is under 0.15 on\n"
	md += "the combined distance is a confusion candidate for the unlabelled review.\n\n"
	md += "| style | silhouette | exterior vocab | plan | surfaces | use | combined nearest |\n|---|---|---|---|---|---|---|\n"
	var pairs := {}
	for a in styles:
		var cells: Array[String] = []
		var best_total := 9.0
		var best_name := ""
		var totals := {}
		for axis in AXES:
			var near := 9.0
			var near_name := ""
			for b in styles:
				if a == b:
					continue
				var d := _axis_distance(by_style[a], by_style[b], axis, furnish)
				totals[b] = float(totals.get(b, 0.0)) + d / float(AXES.size() - (0 if furnish else 1))
				if d < near:
					near = d
					near_name = b
			cells.append("%s %.2f" % [near_name, near])
		for b in totals:
			if totals[b] < best_total:
				best_total = totals[b]
				best_name = b
			var key := [a, b]
			key.sort()
			pairs["%s~%s" % key] = totals[b]
		md += "| %s | %s | %s %.2f |\n" % [a, " | ".join(cells), best_name, best_total]
	md += "\n## Closest pairs overall\n\n"
	var ordered: Array = pairs.keys()
	ordered.sort_custom(func(x, y): return pairs[x] < pairs[y])
	for k in ordered.slice(0, 10):
		md += "- %s: %.3f\n" % [k, pairs[k]]
	return md


## Distance between two styles on one axis, averaged over matched fixtures.
func _axis_distance(ra: Array, rb: Array, axis: String, furnish: bool) -> float:
	if axis == "use" and not furnish:
		return 0.0
	var total := 0.0
	var n := 0
	for x in ra:
		for y in rb:
			if x["size"] != y["size"] or x["seed"] != y["seed"]:
				continue
			total += _pair_distance(x, y, axis)
			n += 1
	return total / maxf(float(n), 1.0)


func _pair_distance(x: Dictionary, y: Dictionary, axis: String) -> float:
	match axis:
		"silhouette":
			var d := 0.0
			d += 0.0 if x["roof_type"] == y["roof_type"] else 1.0
			d += clampf(absf(x["roof_pitch"] - y["roof_pitch"]) / 0.6, 0.0, 1.0)
			d += clampf(absf(x["height_ratio"] - y["height_ratio"]) / 0.8, 0.0, 1.0)
			d += clampf(absf(x["overhang"] - y["overhang"]) / 0.8, 0.0, 1.0)
			d += 0.0 if x["storeys"] == y["storeys"] else 1.0
			return d / 5.0
		"exterior_vocab":
			return 1.0 - _jaccard(Array(x["roles"].keys()) + Array(x["flags"]),
				Array(y["roles"].keys()) + Array(y["flags"]))
		"plan":
			var d := 1.0 - _multiset_jaccard(x["rooms"], y["rooms"])
			d += clampf(absf(x["largest_share"] - y["largest_share"]) / 0.4, 0.0, 1.0)
			d += clampf(absf(x["hall_share"] - y["hall_share"]) / 0.4, 0.0, 1.0)
			return d / 3.0
		"surfaces":
			var d := clampf(absf(x["wall_t"] - y["wall_t"]) / 0.4, 0.0, 1.0)
			d += clampf(absf(x["glazing_per_m2"] - y["glazing_per_m2"]) / 0.08, 0.0, 1.0)
			d += clampf(absf(x["mean_sill"] - y["mean_sill"]) / 0.6, 0.0, 1.0)
			return d / 3.0
		"use":
			var d := 1.0 - _jaccard(x["furniture_keys"], y["furniture_keys"])
			d += clampf(absf(float(x["furniture"]) - float(y["furniture"]))
				/ maxf(float(maxi(int(x["furniture"]), int(y["furniture"]))), 1.0), 0.0, 1.0)
			return d / 2.0
	return 0.0


func _jaccard(a: Array, b: Array) -> float:
	var sa := {}
	for v in a:
		sa[v] = true
	var sb := {}
	for v in b:
		sb[v] = true
	var inter := 0
	for v in sa:
		if sb.has(v):
			inter += 1
	var union := sa.size() + sb.size() - inter
	return 1.0 if union == 0 else float(inter) / float(union)


func _multiset_jaccard(a: Array, b: Array) -> float:
	var ca := {}
	for v in a:
		ca[v] = int(ca.get(v, 0)) + 1
	var cb := {}
	for v in b:
		cb[v] = int(cb.get(v, 0)) + 1
	var inter := 0
	var union := 0
	var keys := ca.duplicate()
	keys.merge(cb)
	for k in keys:
		inter += mini(int(ca.get(k, 0)), int(cb.get(k, 0)))
		union += maxi(int(ca.get(k, 0)), int(cb.get(k, 0)))
	return 1.0 if union == 0 else float(inter) / float(union)


func _mean(rs: Array, field: String) -> float:
	var t := 0.0
	for r in rs:
		t += float(r[field])
	return t / maxf(float(rs.size()), 1.0)


func _range(rs: Array, field: String) -> String:
	var lo := 999
	var hi := -999
	for r in rs:
		lo = mini(lo, int(r[field]))
		hi = maxi(hi, int(r[field]))
	return str(lo) if lo == hi else "%d-%d" % [lo, hi]


## Same interpolation as tools/render_personality_baseline.gd._apply_scale.
func _apply_scale(request: BuildingRequest, descriptor: Dictionary, scale: String) -> void:
	for field in [&"width", &"length", &"height"]:
		if not descriptor.has(field):
			continue
		var envelope: Dictionary = descriptor[field]
		var minimum := float(envelope["min"])
		var maximum := float(envelope["max"])
		var normal := float(envelope.get("value", request.get(String(field))))
		var selected := normal
		if scale == "small":
			selected = lerpf(minimum, normal, 0.5)
		elif scale == "large":
			selected = lerpf(normal, maximum, 0.5)
		request.set(String(field), clampf(selected, minimum, maximum))
	if descriptor.has("storeys"):
		var envelope: Dictionary = descriptor["storeys"]
		var selected := int(envelope["value"])
		if scale == "small":
			selected = roundi(lerpf(int(envelope["min"]), selected, 0.5))
		elif scale == "large":
			selected = roundi(lerpf(selected, int(envelope["max"]), 0.5))
		request.storeys = clampi(selected, int(envelope["min"]), int(envelope["max"]))


func _options(args: PackedStringArray) -> Dictionary:
	var out := {}
	for a in args:
		var kv := a.split("=", false, 1)
		if kv.size() == 2:
			out[kv[0]] = kv[1]
	return out

class_name VillageVernacularCheck
extends RefCounted
## Is this village NORMAL for the regions it was built from? (VILLAGE-VERNACULAR;
## docs/VILLAGE_VERNACULAR.md)
##
## It measures what the generator MADE -- each dwelling's spec, generated from
## its request exactly as the village builds it -- and never the genome the
## programme drew, so a look the house generator ignored, a cluster drawn at the
## wrong weight or a roof the chassis quietly swapped is found here. Every
## colour is sorted into the dataset's clusters by its distance in CIE Lab to
## the nearest point of the cluster, its paint allowed to have weathered toward
## VillageVernacular.GRIME as far as the region lets it.
##
## Four rules:
##   membership  every dwelling's walls, trim and roof colour lie in a cluster
##               of a region the blend draws that group from, and its roof is a
##               material one of those regions' recipes uses
##   signature   a PURE region's village keeps that region's short trait list
##               (the dataset's `signature`: the few things that make it read
##               as Provence, the Cyclades, the North or Japan)
##   presence    in a blend, every region with BLEND_SEEN of a group shows up
##               in that group's dwellings (a blend must look like a blend)
##   variety     a village of VARIETY_MIN dwellings or more is not one colour
##
## report = {"ok": bool, "failures": [...], "warnings": [...], "stats": {...}}

const RULES: Array[StringName] = [&"membership", &"signature", &"presence", &"variety"]
## How far (CIE76 delta E) a colour may lie from its cluster: about the eye's
## "same paint, other light" threshold, well under the gap between clusters.
const COLOUR_TOL := 6.0
const VARIETY_MIN := 10
const BLEND_SEEN := 0.25
## Grid the cluster segment and its weathering are sampled on.
const SAMPLES_T := 11
const SAMPLES_S := 6

var failures: Array[String] = []
var warnings: Array[String] = []
var stats: Dictionary = {}


# ============================================================ measuring

## The facts of every dwelling (house or shop) and the landmark, from a list
## of requests -- a programme, or a plan's own buildings.
##   {"dwellings": [{kind, style, wall, trim, roof, roof_type, roof_material,
##     storeys, shutters, parapet}], "landmark": church style or &""}
static func measure_requests(requests: Array) -> Dictionary:
	var rows: Array[Dictionary] = []
	var landmark: StringName = &""
	for r in requests:
		var request := r as BuildingRequest
		if request == null:
			continue
		if request.kind == &"church" and landmark == &"":
			landmark = request.style
		if request.kind not in [&"house", &"shop"]:
			continue
		var spec := spec_of(request)
		if spec == null:
			rows.append({"kind": request.kind, "error": true})
			continue
		rows.append({"kind": request.kind, "style": spec.style, "wall": spec.wall_color,
			"trim": spec.trim_color, "roof": spec.roof_color, "roof_type": spec.roof_type,
			"roof_material": spec.roof_material, "storeys": spec.storeys,
			"shutters": spec.window_shutters, "parapet": spec.parapet})
	return {"dwellings": rows, "landmark": landmark}


static func measure_plan(plan: VillagePlan) -> Dictionary:
	var requests: Array = []
	for b in plan.buildings:
		if b.get("request") is BuildingRequest:
			requests.append(b["request"])
	return measure_requests(requests)


## The spec a request's building is generated with, through the family's own
## placement path (no furniture: a look is an exterior).
static func spec_of(request: BuildingRequest) -> HouseSpec:
	var out := GeneratedBuilding.new()
	out.request = request
	var family: BuildingFamilyAdapter = BuildingFamilyAdapter.of(request.kind)
	if family == null or not family.generate_for_placement(request, out):
		return null
	return out.spec as HouseSpec


# ============================================================ the rules

func check(measured: Dictionary, fs: VillageVernacular, overrides: Dictionary = {}) -> Dictionary:
	failures.clear()
	warnings.clear()
	stats.clear()
	var rows: Array = measured.get("dwellings", [])
	stats["dwellings"] = rows.size()
	if fs == null:
		failures.append("membership: the village has no vernacular to be judged by")
		return _report()
	stats["blend"] = fs.to_dict()
	var classified := _classify_all(rows, fs)
	stats["classified"] = classified
	RuleSet.run(self, RULES, {}, overrides, [measured, fs, classified],
		[measured, fs, classified], failures, warnings)
	return _report()


func _report() -> Dictionary:
	return {"ok": failures.is_empty(), "failures": failures, "warnings": warnings, "stats": stats}


func _check_membership(measured: Dictionary, fs: VillageVernacular, classified: Array) -> void:
	var rows: Array = measured.get("dwellings", [])
	var bad := 0
	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		if row.get("error", false):
			failures.append("membership: dwelling %d (%s) did not generate" % [i, String(row["kind"])])
			bad += 1
			continue
		var c: Dictionary = classified[i]
		for group in ["walls", "trim", "roof_colour"]:
			if c[group].is_empty():
				bad += 1
				if bad <= 6:
					failures.append("membership: dwelling %d's %s #%s is in no cluster of %s (nearest %s at %.1f)" % [
						i, group, (row[_field(group)] as Color).to_html(false), str(_group_regions(fs, group)),
						c[group + "_nearest"], float(c[group + "_dist"])])
		var materials := {}
		for id in fs.groups[&"roofs"]:
			for rid in VillageVernacular.region(id)["roofs"]:
				materials[String(VillageVernacular.region(id)["roofs"][rid]["material"])] = true
		if not materials.has(String(row["roof_material"])):
			bad += 1
			failures.append("membership: dwelling %d's roof is %s, which no recipe of %s uses" % [
				i, String(row["roof_material"]), str(fs.groups[&"roofs"].keys())])
	stats["outside"] = bad


func _check_signature(measured: Dictionary, fs: VillageVernacular, classified: Array) -> void:
	if not fs.is_pure():
		return
	var id: StringName = fs.dominant()
	var rows: Array = measured.get("dwellings", [])
	var results := {}
	for sig in VillageVernacular.region(id).get("signature", []):
		var r := evaluate(sig, measured, classified, rows.size())
		results[String(sig["id"])] = r
		if r["skipped"]:
			continue
		if not r["ok"]:
			failures.append("signature: %s %s -- %s" % [String(id), String(sig["id"]), r["why"]])
	stats["signature"] = results


## One signature row against the measured village:
##   {"ok": bool, "skipped": bool, "value": number, "why": text}
static func evaluate(sig: Dictionary, measured: Dictionary, classified: Array, n: int) -> Dictionary:
	var rows: Array = measured.get("dwellings", [])
	var m := String(sig.get("measure", ""))
	if m == "landmark":
		var have: StringName = measured.get("landmark", &"")
		if have == &"":
			return {"ok": true, "skipped": true, "value": 0, "why": "no church in a village this size"}
		var ok := String(have) == String(sig["church"])
		return {"ok": ok, "skipped": false, "value": String(have),
			"why": "the landmark is %s, not %s" % [String(have), String(sig["church"])]}
	if n == 0:
		return {"ok": false, "skipped": false, "value": 0, "why": "no dwellings"}
	if m == "distinct":
		if n < VARIETY_MIN:
			return {"ok": true, "skipped": true, "value": 0, "why": "too few dwellings to ask"}
		var seen := {}
		var group := String(sig["group"])
		for c in classified:
			if not String(c.get(group, "")).is_empty():
				seen[c[group]] = true
		var ok := seen.size() >= int(sig["min"])
		return {"ok": ok, "skipped": false, "value": seen.size(),
			"why": "%d %s clusters (%s), wants at least %d" % [seen.size(), group, str(seen.keys()), int(sig["min"])]}
	var hits := 0
	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		if row.get("error", false):
			continue
		var hit := false
		match m:
			"walls", "trim", "roof_colour":
				hit = String(classified[i].get(m, "")) in sig["clusters"]
			"roof_form":
				hit = String(row["roof_type"]) in sig["types"]
			"roof_material":
				hit = String(row["roof_material"]) in sig["materials"]
			"storeys":
				hit = float(row["storeys"]) in (sig["storeys"] as Array).map(func(s): return float(s))
			"styles":
				hit = String(row["style"]) in sig["styles"]
			"shutters":
				hit = bool(row["shutters"])
			"parapet":
				hit = bool(row["parapet"])
		hits += int(hit)
	var share := float(hits) / float(n)
	var ok := true
	var want := ""
	if sig.has("min"):
		ok = share >= float(sig["min"]) - 1e-9
		want = "at least %.2f" % float(sig["min"])
	if sig.has("max"):
		ok = ok and share <= float(sig["max"]) + 1e-9
		want += (", " if not want.is_empty() else "") + "at most %.2f" % float(sig["max"])
	return {"ok": ok, "skipped": false, "value": share,
		"why": "%s share %.2f (%d of %d), wants %s" % [m, share, hits, n, want]}


func _check_presence(measured: Dictionary, fs: VillageVernacular, classified: Array) -> void:
	if fs.is_pure() or classified.size() < VARIETY_MIN:
		return
	for group in ["walls", "trim", "roof_colour"]:
		var key := StringName("roofs" if group == "roof_colour" else group)
		var w: Dictionary = fs.groups[key]
		var seen := {}
		for c in classified:
			var region := String(c.get(group + "_region", ""))
			if not region.is_empty():
				seen[region] = true
		for id in w:
			if float(w[id]) >= BLEND_SEEN and not seen.has(String(id)):
				failures.append("presence: %s carries %.0f%% of the %s but none of the village's %s is theirs" % [
					String(id), float(w[id]) * 100.0, group, group])


func _check_variety(measured: Dictionary, _fs: VillageVernacular, classified: Array) -> void:
	if classified.size() < VARIETY_MIN:
		return
	var colours := {}
	for row in measured.get("dwellings", []):
		if not row.get("error", false):
			colours[(row["wall"] as Color).to_html(false) + (row["trim"] as Color).to_html(false)] = true
	stats["distinct_paint"] = colours.size()
	if colours.size() < 3:
		failures.append("variety: %d dwellings in only %d paint schemes" % [classified.size(), colours.size()])


# ============================================================ classifying

static func _field(group: String) -> String:
	return {"walls": "wall", "trim": "trim", "roof_colour": "roof"}[group]


static func _group_regions(fs: VillageVernacular, group: String) -> Array:
	var key := StringName("roofs" if group == "roof_colour" else group)
	return (fs.groups[key] as Dictionary).keys()


## Each dwelling's colours, named: {walls, trim, roof_colour} the cluster (""
## when none is within COLOUR_TOL), with *_region, *_nearest and *_dist.
static func _classify_all(rows: Array, fs: VillageVernacular) -> Array:
	var out: Array = []
	for row in rows:
		var c := {}
		if row.get("error", false):
			for group in ["walls", "trim", "roof_colour"]:
				c[group] = ""
			out.append(c)
			continue
		for group in ["walls", "trim", "roof_colour"]:
			var best := {"name": "", "region": "", "dist": INF}
			for id in _group_regions(fs, group):
				var found := nearest(row[_field(group)], id, group)
				if float(found["dist"]) < float(best["dist"]):
					best = found
			c[group] = best["name"] if float(best["dist"]) <= COLOUR_TOL else ""
			c[group + "_region"] = best["region"] if float(best["dist"]) <= COLOUR_TOL else ""
			c[group + "_nearest"] = best["name"]
			c[group + "_dist"] = best["dist"]
		out.append(c)
	return out


## The region's nearest cluster to `colour` in `group` ("walls", "trim" or
## "roof_colour"), over the region's own clusters and every house type's,
## each allowed to have weathered as far as the region's poorest paint.
static func nearest(colour: Color, region_id: StringName, group: String) -> Dictionary:
	var row := VillageVernacular.region(region_id)
	var weather := 0.0
	for tier in row.get("wealth", {}).get("weathering", {}):
		weather = maxf(weather, float(row["wealth"]["weathering"][tier]))
	var clusters: Array = []
	if group == "roof_colour":
		weather *= VillageVernacular.ROOF_WEATHER
		for rid in row.get("roofs", {}):
			clusters.append_array(row["roofs"][rid].get("colours", []))
	else:
		clusters.append_array(row.get(group, []))
		for tid in row.get("houses", {}):
			clusters.append_array(row["houses"][tid].get(group, []))
	var lab := _lab(colour)
	var grime := VillageVernacular.grime(region_id)
	# a place left to rot weathers further than six samples can follow
	var steps := maxi(SAMPLES_S, int(ceil(weather * 16.0)) + 1)
	var best := {"name": "", "region": String(region_id), "dist": INF}
	for cl in clusters:
		var a := Color(String(cl["hex"][0]))
		var b := Color(String(cl["hex"][1]))
		for ti in range(SAMPLES_T):
			var base := a.lerp(b, float(ti) / float(SAMPLES_T - 1))
			for si in range(steps):
				var s := weather * float(si) / float(steps - 1)
				var d := lab.distance_to(_lab(base.lerp(grime, s)))
				if d < float(best["dist"]):
					best = {"name": String(cl["name"]), "region": String(region_id), "dist": d}
	return best


## sRGB to CIE Lab (D65).
static func _lab(c: Color) -> Vector3:
	var r := _linear(c.r)
	var g := _linear(c.g)
	var b := _linear(c.b)
	var x := (r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047
	var y := (r * 0.2126 + g * 0.7152 + b * 0.0722)
	var z := (r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883
	var fx := _f(x)
	var fy := _f(y)
	var fz := _f(z)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


static func _linear(u: float) -> float:
	return u / 12.92 if u <= 0.04045 else pow((u + 0.055) / 1.055, 2.4)


static func _f(t: float) -> float:
	return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0

class_name VillageCharacterCheck
extends RefCounted
## VTER-VISUAL-CHARACTER: does a village planned on a real ground carry the few
## traits that make the place itself? Measured on the PLAN, so it is seconds.
##
## A trait row is {"style": name, "style_min": share of dwellings in that style,
## "storeys_min": median storeys of the houses, "gap_max": the median clear
## metres from a dwelling to its nearest neighbour}. Three traits at most per
## site (the owner's bounded-acceptance rule); see docs/VILLAGE_TERRAIN.md.

const CHARACTER_FILE := "res://tests/fixtures/terrain/real30/character.json"

const TRAITS := {
	"manarola": {"style": &"mediterranean", "style_min": 0.9, "storeys_min": 3.0, "gap_max": 2.0, "share_min": 0.9},
	"hallstatt": {"style": &"townhouse", "style_min": 0.9, "storeys_min": 2.0, "gap_max": 3.5, "share_min": 0.5},
	"monpazier": {"style": &"townhouse", "style_min": 0.9, "storeys_min": 2.0, "gap_max": 3.0, "share_min": 0.6},
}


## Gives a real-site grid its character (character.json). Returns the grid.
static func apply(ground: VillageTerrain, site: String) -> VillageTerrain:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(CHARACTER_FILE))
	if d is Dictionary and (d as Dictionary).get(site, null) is Dictionary:
		ground.character = (d[site] as Dictionary).duplicate(true)
	return ground


## style_share, storeys (median), gap (median nearest-neighbour clear metres).
static func measure(plan: VillagePlan, gap_max := 3.0) -> Dictionary:
	var dwellings: Array[int] = []
	for i in range(plan.buildings.size()):
		var req: BuildingRequest = plan.buildings[i]["request"]
		if req.kind in [&"house", &"shop"]:
			dwellings.append(i)
	var styles := {}
	var storeys: Array[float] = []
	var gaps: Array[float] = []
	for i in dwellings:
		var req: BuildingRequest = plan.buildings[i]["request"]
		styles[req.style] = int(styles.get(req.style, 0)) + 1
		if req.kind == &"house":
			storeys.append(float(req.storeys))
		var a: PackedVector2Array = VillageMeasure.bounds_poly(plan.buildings[i])
		var nearest := INF
		for j in range(plan.buildings.size()):
			if j != i:
				nearest = minf(nearest, VillageMeasure.poly_distance(a, VillageMeasure.bounds_poly(plan.buildings[j])))
		gaps.append(nearest)
	var near := 0
	for g in gaps:
		if g <= gap_max:
			near += 1
	return {"dwellings": dwellings.size(), "styles": styles,
		"storeys": _median(storeys), "gap": _median(gaps), "near": near}


static func problems(m: Dictionary, want: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var n := maxi(1, int(m["dwellings"]))
	var share := float((m["styles"] as Dictionary).get(want["style"], 0)) / float(n)
	if share < float(want["style_min"]):
		out.append("style: %.0f%% of dwellings are %s, want at least %.0f%%" % [
			share * 100.0, want["style"], float(want["style_min"]) * 100.0])
	if float(m["storeys"]) < float(want["storeys_min"]):
		out.append("storeys: median %.1f, want at least %.1f" % [m["storeys"], want["storeys_min"]])
	var near_share := float(m["near"]) / float(n)
	if near_share < float(want["share_min"]):
		out.append("gap: %.0f%% of dwellings have a neighbour within %.1f m, want at least %.0f%% (median nearest gap %.1f m)" % [
			near_share * 100.0, want["gap_max"], float(want["share_min"]) * 100.0, m["gap"]])
	return out


static func _median(v: Array[float]) -> float:
	if v.is_empty():
		return 0.0
	var s := v.duplicate()
	s.sort()
	return s[s.size() / 2]

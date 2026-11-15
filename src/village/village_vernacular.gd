class_name VillageVernacular
extends RefCounted
## What a village of a REGION looks like, and how two regions blend
## (VILLAGE-VERNACULAR; docs/VILLAGE_VERNACULAR.md).
##
## Two halves. The DATASET (`vernacular_regions.json`, beside this file) says
## what is normal for each region as distributions: wall, trim and roof colour
## clusters, roof recipes, the house types each wealth tier lives in and their
## storeys and sizes, the landmark, the plants, the ground and the place names.
## The FEATURE SET is an instance of this class: a blend of regions, with a
## weight per region for each feature GROUP, from which every house draws its
## genome with a seeded stream of its own.
##
## Blending is per group, not per colour: a house takes its type from one
## region, its walls from one, its trim from one and its roof from one, each
## chosen by that group's weights. Half Norse and half Japanese is therefore a
## village where some houses carry turf and some kawara tile, never a roof
## the colour of the average of the two. `coherence` is the chance a house
## takes every group from ONE region -- 1.0 is two peoples living side by
## side, 0.0 (the default) a single hybrid people.
##
## Nothing here draws from a spec's own `rng`, and a village with no
## vernacular never reaches this file, so every village that existed before it
## is byte for byte the same.

const DATASET_FILE := "vernacular_regions.json"
## The addon's copy first (tools/brick_wild_addon_manifest.json ships it beside
## this script), then the repository's.
const DATASET_ROOTS: Array[String] = ["res://addons/brick_wild/families/village/", "res://src/village/"]
const SCHEMA := "brickwild.vernacular"

## Every group a blend may weight on its own.
const GROUPS: Array[StringName] = [&"houses", &"walls", &"trim", &"roofs", &"landmark",
	&"plants", &"ground", &"names"]
## The groups every house draws a parent region for.
const HOUSE_GROUPS: Array[StringName] = [&"houses", &"walls", &"trim", &"roofs"]
const TIERS: Array[StringName] = [&"poor", &"middle", &"rich"]
## The colour paint weathers toward: dust, soot and rain.
const GRIME := Color("6e685e")
## A roof weathers at this share of its walls' rate.
const ROOF_WEATHER := 0.5
## Village wealth moves the rich share up and the poor share down by this
## factor at the ends (wealth 0 and 1), about the dataset's share at 0.5.
const WEALTH_SPREAD := 3.0
const TIER_MAX := 0.9
## A region whose plant weight is under this adds nothing to the palette
## unless it is the dominant one: a tenth of a region is not its forest.
const PLANT_MIN_WEIGHT := 0.2
## The dataset's ground names, as VillageBuilder surfaces.
const GROUND_SURFACES := {
	"ground": VillageBuilder.SURF_GROUND, "road": VillageBuilder.SURF_ROAD,
	"common": VillageBuilder.SURF_COMMON, "verge": VillageBuilder.SURF_VERGE,
	"yard": VillageBuilder.SURF_YARD, "field": VillageBuilder.SURF_FIELD,
	"wear": VillageBuilder.SURF_WEAR, "tread": VillageBuilder.SURF_TREAD,
}
## The words a signature row may measure (VillageVernacularCheck).
const MEASURES: Array[String] = ["walls", "trim", "roof_colour", "roof_form", "roof_material",
	"storeys", "styles", "shutters", "parapet", "distinct", "landmark"]

static var _dataset: Dictionary = {}
static var _custom: Dictionary = {}

## Region id -> weight, summing to 1.
var blend: Dictionary = {}
## Group -> {region id: weight}, each summing to 1; a group the caller did not
## name has the blend's own weights.
var groups: Dictionary = {}
var coherence: float = 0.0


# ================================================================== dataset

## The parsed dataset file, read once.
static func dataset() -> Dictionary:
	if _dataset.is_empty():
		for root in DATASET_ROOTS:
			var path: String = root + DATASET_FILE
			if not FileAccess.file_exists(path):
				continue
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary and (parsed as Dictionary).has("regions"):
				_dataset = parsed
			break
		if _dataset.is_empty():
			push_error("VillageVernacular: %s is missing or unreadable" % DATASET_FILE)
			_dataset = {"schema": SCHEMA, "regions": {}}
	return _dataset


## Every region a blend may name: the dataset's and the registered ones.
static func region_ids() -> Array[StringName]:
	var names: Array[String] = []
	for id in dataset()["regions"]:
		names.append(String(id))
	for id in _custom:
		if not names.has(String(id)):
			names.append(String(id))
	names.sort()
	var out: Array[StringName] = []
	for n in names:
		out.append(StringName(n))
	return out


## A region's row, by id or alias; {} when there is none.
static func region(id: Variant) -> Dictionary:
	var key := String(resolve_id(id))
	if _custom.has(StringName(key)):
		return _custom[StringName(key)]
	return dataset()["regions"].get(key, {})


## The region id an id or alias names (lower case); the id itself when it
## names nothing, so the caller's error can say what was asked for.
static func resolve_id(id: Variant) -> StringName:
	var s := String(id).to_lower()
	if _custom.has(StringName(s)) or (dataset()["regions"] as Dictionary).has(s):
		return StringName(s)
	for rid in region_ids():
		var row: Dictionary = _custom.get(rid, dataset()["regions"].get(String(rid), {}))
		if s in row.get("aliases", []):
			return rid
	return StringName(s)


## Add a region for this run (a fantasy people: elves, dwarves, a drowned
## kingdom). It is validated exactly as the shipped ones are; the errors are
## returned and nothing is added when there are any. A registered id shadows a
## shipped one of the same name.
static func register(id: StringName, row: Dictionary) -> Array[String]:
	var errs := region_errors(row)
	if errs.is_empty():
		_custom[StringName(String(id).to_lower())] = row.duplicate(true)
	return errs


static func unregister(id: StringName) -> void:
	_custom.erase(StringName(String(id).to_lower()))


## Everything wrong with a region row; empty is a row the generator can draw
## every house of without a single refused look.
static func region_errors(row: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if not row.get("label", "") is String or String(row.get("label", "")).is_empty():
		out.append("a region needs a label")
	if not StringName(String(row.get("culture", ""))) in VillageSpec.CULTURES:
		out.append("culture '%s' is not one of VillageSpec.CULTURES" % str(row.get("culture", "")))
	for group in ["walls", "trim"]:
		_cluster_errors(row.get(group, null), group, out)
	var roofs: Variant = row.get("roofs", null)
	if not roofs is Dictionary or (roofs as Dictionary).is_empty():
		out.append("roofs: at least one roof recipe")
		roofs = {}
	for rid in roofs:
		_recipe_errors(String(rid), roofs[rid], out)
	var houses: Variant = row.get("houses", null)
	if not houses is Dictionary or (houses as Dictionary).is_empty():
		out.append("houses: at least one house type")
		houses = {}
	for tid in houses:
		_type_errors(String(tid), houses[tid], roofs, out)
	if not houses.has(String(row.get("shop", ""))):
		out.append("shop: '%s' is not one of the region's house types" % str(row.get("shop", "")))
	var wealth: Variant = row.get("wealth", {})
	if not wealth is Dictionary or not _num01(wealth.get("rich", -1)) or not _num01(wealth.get("poor", -1)) \
			or float(wealth.get("rich", 0)) + float(wealth.get("poor", 0)) > TIER_MAX:
		out.append("wealth: rich and poor shares 0..1, together at most %.1f" % TIER_MAX)
	elif wealth.has("weathering"):
		for tier in wealth["weathering"]:
			if not StringName(String(tier)) in TIERS or not _num01(wealth["weathering"][tier]):
				out.append("wealth.weathering: '%s' wants a tier and a share 0..1" % str(tier))
	var scale: Variant = row.get("size", {}).get("area_scale", 1.0)
	if not _num(scale) or float(scale) < 0.4 or float(scale) > 2.0:
		out.append("size.area_scale wants 0.4..2.0")
	var landmark: Variant = row.get("landmark", null)
	if not landmark is Dictionary or not ChurchSpec.STYLES.has(StringName(String(landmark.get("church", "")))):
		out.append("landmark: 'church' must be one of ChurchSpec.STYLES")
	else:
		for key in landmark.get("look", {}):
			if not BuildingFamilyAdapter.LOOK_COLOUR_FIELDS.has(String(key)):
				out.append("landmark.look: '%s' is not a colour (wall, trim, roof)" % str(key))
		for why in HouseSpec.look_errors(&"cottage", landmark.get("look", {})):
			out.append("landmark." + why)
	var plants: Variant = row.get("plants", {})
	if not plants is Dictionary:
		out.append("plants: slot -> catalogue keys")
	else:
		for slot in plants:
			if not plants[slot] is Array:
				out.append("plants.%s: a list of catalogue keys" % str(slot))
	var ground: Variant = row.get("ground", {})
	if not ground is Dictionary:
		out.append("ground: surface -> hex")
	else:
		for key in ground:
			if not GROUND_SURFACES.has(String(key)) or not Color.html_is_valid(String(ground[key])):
				out.append("ground: '%s' wants one of %s and a hex colour" % [str(key), str(GROUND_SURFACES.keys())])
	var names: Variant = row.get("names", {})
	if not names is Dictionary or (names.get("roots", []) as Array).is_empty() \
			or (names.get("endings", []) as Array).is_empty():
		out.append("names: roots and endings")
	for sig in row.get("signature", []):
		if not sig is Dictionary or not String(sig.get("measure", "")) in MEASURES:
			out.append("signature: '%s' measures nothing VillageVernacularCheck knows" % str(sig))
	return out


static func _cluster_errors(clusters: Variant, where: String, out: Array[String]) -> void:
	if not clusters is Array or (clusters as Array).is_empty():
		out.append("%s: at least one colour cluster" % where)
		return
	for c in clusters:
		if not c is Dictionary or not _num(c.get("w", null)) or float(c["w"]) <= 0.0 \
				or String(c.get("name", "")).is_empty():
			out.append("%s: a cluster wants a name and a weight over 0" % where)
			continue
		var hexes: Variant = c.get("hex", null)
		if not hexes is Array or (hexes as Array).size() != 2:
			out.append("%s.%s: hex wants [hex, hex]" % [where, c["name"]])
			continue
		for h in hexes:
			if not Color.html_is_valid(String(h)):
				out.append("%s.%s: '%s' is not a hex colour" % [where, c["name"], str(h)])


static func _recipe_errors(rid: String, r: Variant, out: Array[String]) -> void:
	if not r is Dictionary or not _num(r.get("w", null)) or float(r["w"]) <= 0.0:
		out.append("roofs.%s: a weight over 0" % rid)
		return
	var types: Variant = r.get("types", {})
	if not types is Dictionary or (types as Dictionary).is_empty():
		out.append("roofs.%s: types {form: weight}" % rid)
	else:
		for t in types:
			if not StringName(String(t)) in HouseSpec.LOOK_NAMES["roof_types"]:
				out.append("roofs.%s: no roof form '%s'" % [rid, str(t)])
	var pitch: Variant = r.get("pitch", null)
	if not pitch is Array or pitch.size() != 2 or not _num(pitch[0]) or not _num(pitch[1]) \
			or float(pitch[0]) > float(pitch[1]) or float(pitch[0]) < 0.0 or float(pitch[1]) > 1.8:
		out.append("roofs.%s: pitch [min, max] in 0..1.8" % rid)
	if not StringName(String(r.get("material", ""))) in HouseSpec.LOOK_NAMES["roof_material"]:
		out.append("roofs.%s: material one of %s" % [rid, str(HouseSpec.LOOK_NAMES["roof_material"])])
	if r.has("eave"):
		var eave: Variant = r["eave"]
		if not eave is Array or eave.size() != 2 or not _num(eave[0]) or not _num(eave[1]):
			out.append("roofs.%s: eave [span_out, along_out]" % rid)
	_cluster_errors(r.get("colours", null), "roofs.%s.colours" % rid, out)


static func _type_errors(tid: String, t: Variant, roofs: Dictionary, out: Array[String]) -> void:
	if not t is Dictionary:
		out.append("houses.%s: a house type row" % tid)
		return
	var style := StringName(String(t.get("style", "")))
	if not HouseSpec.STYLES.has(style):
		out.append("houses.%s: style '%s' is not a HouseSpec style" % [tid, String(style)])
		return
	var tiers: Variant = t.get("tiers", {})
	if not tiers is Dictionary or (tiers as Dictionary).is_empty():
		out.append("houses.%s: tiers {poor|middle|rich: weight}" % tid)
	else:
		for tier in tiers:
			if not StringName(String(tier)) in TIERS or not _num(tiers[tier]) or float(tiers[tier]) < 0.0:
				out.append("houses.%s: tier '%s' wants poor, middle or rich and a weight" % [tid, str(tier)])
	var storeys: Variant = t.get("storeys", {})
	if not storeys is Dictionary or (storeys as Dictionary).is_empty():
		out.append("houses.%s: storeys {\"1\": weight, ...}" % tid)
	else:
		for s in storeys:
			if not String(s) in ["1", "2", "3"] or not _num(storeys[s]):
				out.append("houses.%s: storeys '%s' wants 1, 2 or 3" % [tid, str(s)])
	if not _num(t.get("area", 1.0)) or float(t.get("area", 1.0)) < 0.4 or float(t.get("area", 1.0)) > 2.5:
		out.append("houses.%s: area wants 0.4..2.5" % tid)
	for why in HouseSpec.look_errors(style, t.get("look", {})):
		out.append("houses.%s.%s" % [tid, why])
	for group in ["walls", "trim"]:
		if t.has(group):
			_cluster_errors(t[group], "houses.%s.%s" % [tid, group], out)
	var allowed: Array = HouseSpec.LOOK_ROOFS.get(style, HouseSpec.STYLES[style].get("roof_types", []))
	for rid in t.get("roofs", []):
		if not roofs.has(String(rid)):
			out.append("houses.%s: no roof recipe '%s' in the region" % [tid, str(rid)])
			continue
		var types: Dictionary = t.get("roof_types", roofs[String(rid)].get("types", {}))
		var fits := false
		for form in types:
			fits = fits or StringName(String(form)) in allowed
		if not fits:
			out.append("houses.%s: a %s cannot build any form of roof '%s'" % [tid, String(style), String(rid)])


static func _num(v: Variant) -> bool:
	return (v is float or v is int) and is_finite(float(v))


static func _num01(v: Variant) -> bool:
	return _num(v) and float(v) >= 0.0 and float(v) <= 1.0


## For the public description: each region's label, summary, culture, house
## types and the signature it is held to, in words.
static func describe() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in region_ids():
		var row := region(id)
		var says: Array[String] = []
		for sig in row.get("signature", []):
			says.append(String(sig.get("say", "")))
		out.append({"id": id, "label": row.get("label", ""), "summary": row.get("summary", ""),
			"culture": row.get("culture", ""), "aliases": row.get("aliases", []),
			"houses": (row.get("houses", {}) as Dictionary).keys(), "signature": says})
	return out


# ============================================================ the blend

## A vernacular request read and judged: {"blend", "groups", "coherence",
## "errors"}. Accepts a plain {region: weight} or {"blend": {...}, "groups":
## {group: {region: weight}}, "coherence": 0..1}. Weights are normalised; ids
## and aliases are folded to the region id.
static func parse(v: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var blend_in: Variant = v
	var groups_in: Variant = {}
	var coh: Variant = 0.0
	var structured := v.has("blend") or v.has("groups") or v.has("coherence")
	if structured:
		for key in v:
			if not String(key) in ["blend", "groups", "coherence"]:
				errors.append("vernacular: '%s' is not blend, groups or coherence" % str(key))
		blend_in = v.get("blend", {})
		groups_in = v.get("groups", {})
		coh = v.get("coherence", 0.0)
	var out_blend := _weights(blend_in, errors, "blend")
	if out_blend.is_empty() and errors.is_empty():
		errors.append("vernacular: the blend names no region with a weight over 0")
	var out_groups := {}
	if not groups_in is Dictionary:
		errors.append("vernacular: groups wants {group: {region: weight}}")
	else:
		for g in groups_in:
			if not StringName(String(g)) in GROUPS:
				errors.append("vernacular: no group '%s' (one of %s)" % [str(g), str(GROUPS)])
				continue
			var w := _weights(groups_in[g], errors, "groups.%s" % String(g))
			if not w.is_empty():
				out_groups[StringName(String(g))] = w
	if not _num01(coh):
		errors.append("vernacular: coherence wants 0..1")
		coh = 0.0
	return {"blend": out_blend, "groups": out_groups, "coherence": float(coh), "errors": errors}


static func _weights(d: Variant, errors: Array[String], where: String) -> Dictionary:
	if not d is Dictionary:
		errors.append("vernacular: %s wants {region: weight}" % where)
		return {}
	var out := {}
	var total := 0.0
	for k in d:
		var id := resolve_id(k)
		if region(id).is_empty():
			errors.append("vernacular: no region '%s' (one of %s)" % [str(k), str(region_ids())])
			continue
		var w: Variant = d[k]
		if not _num(w) or float(w) < 0.0:
			errors.append("vernacular: %s.%s wants a weight of 0 or more" % [where, str(k)])
			continue
		if float(w) > 0.0:
			out[id] = float(out.get(id, 0.0)) + float(w)
			total += float(w)
	for id in out:
		out[id] = float(out[id]) / total
	return out


## The feature set a vernacular request names, or null when it is wrong
## (parse() says why).
static func resolve(v: Dictionary) -> VillageVernacular:
	var p := parse(v)
	if not (p["errors"] as Array).is_empty():
		return null
	var fs := VillageVernacular.new()
	fs.blend = p["blend"]
	fs.coherence = p["coherence"]
	for g in GROUPS:
		fs.groups[g] = (p["groups"] as Dictionary).get(g, fs.blend)
	return fs


## The feature set as a plain document (what was asked for, normalised).
func to_dict() -> Dictionary:
	var g := {}
	for k in groups:
		if groups[k] != blend:
			g[String(k)] = groups[k]
	return {"blend": blend, "groups": g, "coherence": coherence}


## The blend in words: "Provence", "Norse 50% + Japanese 50%",
## "Cyclades; roofs: Japanese", "...; coherence 1.0". The Studio, the walk
## rig and its pin records all say it this way.
func label() -> String:
	var parts := PackedStringArray()
	# the larger share first, then by id
	var order := _sorted_keys(blend)
	order.sort_custom(func(a, b) -> bool:
		if absf(float(blend[a]) - float(blend[b])) > 1e-9:
			return float(blend[a]) > float(blend[b])
		return String(a) < String(b))
	for id in order:
		var name := _short_label(id)
		parts.append(name if blend.size() == 1 else "%s %d%%" % [name, roundi(float(blend[id]) * 100.0)])
	var out := " + ".join(parts)
	for g in GROUPS:
		var w: Dictionary = groups.get(g, blend)
		if w != blend:
			var names := PackedStringArray()
			for id in _sorted_keys(w):
				names.append(_short_label(id))
			out += "; %s: %s" % [String(g), ", ".join(names)]
	if coherence > 0.0:
		out += "; coherence %.1f" % coherence
	return out


static func _short_label(id: StringName) -> String:
	return String(region(id).get("label", String(id))).get_slice(" (", 0)


## The region with the most weight in `group`; ties go to the first id.
func dominant(group: StringName = &"houses") -> StringName:
	var w: Dictionary = groups.get(group, blend)
	var best: StringName = &""
	var best_w := -1.0
	for id in _sorted_keys(w):
		if float(w[id]) > best_w + 1e-9:
			best = id
			best_w = float(w[id])
	return best


## The culture everything the dataset does not say is built in: the castle,
## the real-layout sizes and spacing, the form tables.
func culture() -> StringName:
	return StringName(String(region(dominant(&"houses")).get("culture", "english")))


## The weight of `id` in `group` (0 when it is not in the blend).
func weight(id: StringName, group: StringName = &"houses") -> float:
	return float((groups.get(group, blend) as Dictionary).get(resolve_id(id), 0.0))


## Is this one region and nothing else -- every group drawn from the one
## region the blend names?
func is_pure() -> bool:
	if blend.size() != 1:
		return false
	var only: StringName = blend.keys()[0]
	for g in GROUPS:
		var w: Dictionary = groups[g]
		if w.size() != 1 or not w.has(only):
			return false
	return true


# ============================================================ wealth

## The share of households in each tier at a village wealth: the houses
## regions' own shares at 0.5, the rich share multiplied and the poor share
## divided by WEALTH_SPREAD at wealth 1 (the other way at 0).
func tier_shares(wealth: float) -> Dictionary:
	var rich := 0.0
	var poor := 0.0
	var w: Dictionary = groups[&"houses"]
	for id in w:
		var row: Dictionary = region(id).get("wealth", {})
		rich += float(w[id]) * float(row.get("rich", 0.15))
		poor += float(w[id]) * float(row.get("poor", 0.3))
	var k := pow(WEALTH_SPREAD, (clampf(wealth, 0.0, 1.0) - 0.5) * 2.0)
	rich *= k
	poor /= k
	var both := rich + poor
	if both > TIER_MAX:
		rich *= TIER_MAX / both
		poor *= TIER_MAX / both
	return {&"poor": poor, &"middle": 1.0 - rich - poor, &"rich": rich}


## Each household's tier, by its footprint: the biggest houses are the rich
## ones and the smallest the poor, in the shares tier_shares() gives. Equal
## areas keep their household order, so the result is a pure function.
func tiers_by_area(areas: Array[float], wealth: float) -> Array[StringName]:
	var n := areas.size()
	var shares := tier_shares(wealth)
	var n_rich := int(roundf(float(shares[&"rich"]) * n))
	var n_poor := mini(int(roundf(float(shares[&"poor"]) * n)), n - n_rich)
	var order: Array[int] = []
	for i in range(n):
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		return areas[a] > areas[b] or (areas[a] == areas[b] and a < b))
	var out: Array[StringName] = []
	out.resize(n)
	for rank in range(n):
		var tier: StringName = &"middle"
		if rank < n_rich:
			tier = &"rich"
		elif rank >= n - n_poor:
			tier = &"poor"
		out[order[rank]] = tier
	return out


# ============================================================ the houses

## One household's genome: which region each group came from, the house type,
## the chassis style, its storeys and size factor, and the `look` the house
## request carries. `key` names the household (its own stream); `tier`,
## `purpose` and `trade` weight the type.
##   {type, region, style, storeys, area, look, parents, tier, clusters}
func house(key: String, tier: StringName, purpose: StringName = &"",
		trade: StringName = &"") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("vernacular|house|" + key)
	var parents := _parents(rng)
	var home_id: StringName = parents[&"houses"]
	var home := region(home_id)
	var type_id := _pick_type(home, tier, purpose, trade, rng)
	var type: Dictionary = home["houses"][type_id]
	return _genome(rng, parents, type_id, type, tier)


## One house of a NAMED type of one region, painted and roofed from that
## region alone: what the dataset's own tests build of every type, so a type
## that cannot be built is found before any village draws it.
static func house_of_type(region_id: StringName, type_id: String, key: String,
		tier: StringName = &"middle") -> Dictionary:
	var fs := resolve({String(region_id): 1.0})
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("vernacular|type|" + key)
	var parents := fs._parents(rng)
	rng.randf()
	return fs._genome(rng, parents, type_id, region(region_id)["houses"][type_id], tier)


## A shop's shell: the house type the region builds its shops as, painted
## and roofed from the blend like a middling house.
func shop(key: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("vernacular|shop|" + key)
	var parents := _parents(rng)
	var home := region(parents[&"houses"])
	var type_id := String(home.get("shop", ""))
	if not (home["houses"] as Dictionary).has(type_id):
		type_id = String(_sorted_keys(home["houses"])[0])
	rng.randf()   # the type draw a house takes, so a shop's stream reads alike
	return _genome(rng, parents, type_id, home["houses"][type_id], &"middle")


func _genome(rng: RandomNumberGenerator, parents: Dictionary, type_id: String,
		type: Dictionary, tier: StringName) -> Dictionary:
	var home_id: StringName = parents[&"houses"]
	var home := region(home_id)
	var style := StringName(String(type["style"]))
	var storeys := int(String(_pick(rng, type.get("storeys", {"1": 1.0}))))
	var look: Dictionary = (type.get("look", {}) as Dictionary).duplicate(true)
	var wall := _colour(rng, _clusters(parents[&"walls"], home_id, type, "walls"),
		_weathering(parents[&"walls"], tier))
	var trim := _colour(rng, _clusters(parents[&"trim"], home_id, type, "trim"),
		_weathering(parents[&"trim"], tier))
	var roof := _roof(rng, parents[&"roofs"], home_id, type, style, tier)
	look["wall"] = [_hex(wall["colour"]), _hex(wall["colour"])]
	look["trim"] = [_hex(trim["colour"]), _hex(trim["colour"])]
	for k in roof["keys"]:
		look[k] = roof["keys"][k]
	look = _prune(style, look)
	return {
		"type": type_id, "region": home_id, "style": style, "storeys": storeys,
		"area": float(type.get("area", 1.0)) * float(home.get("size", {}).get("area_scale", 1.0)),
		"look": look, "parents": parents, "tier": tier,
		"clusters": {"walls": wall["name"], "trim": trim["name"], "roof": roof["recipe"],
			"roof_colour": roof["colour_name"], "roof_form": roof["form"]},
	}


## Which region each house group comes from. Every draw is always taken, so
## changing the coherence or one group's weights moves no other draw.
func _parents(rng: RandomNumberGenerator) -> Dictionary:
	var roll := rng.randf()
	var one: StringName = _pick(rng, blend)
	var out := {}
	for g in HOUSE_GROUPS:
		out[g] = _pick(rng, groups[g])
	if roll < coherence:
		for g in HOUSE_GROUPS:
			out[g] = one
	return out


## The house type, weighted by tier (falling back to the next tier when a
## region has none for this one), purpose and trade.
static func _pick_type(home: Dictionary, tier: StringName, purpose: StringName,
		trade: StringName, rng: RandomNumberGenerator) -> String:
	var order: Array = {&"poor": [&"poor", &"middle", &"rich"],
		&"middle": [&"middle", &"poor", &"rich"], &"rich": [&"rich", &"middle", &"poor"]}.get(tier, [&"middle"])
	var weights := {}
	for try in order:
		for id in home["houses"]:
			var t: Dictionary = home["houses"][id]
			var w := float(t.get("tiers", {}).get(String(try), 0.0))
			w *= float(t.get("purposes", {}).get(String(purpose), 1.0))
			w *= float(t.get("trades", {}).get(String(trade), 1.0))
			if w > 0.0:
				weights[String(id)] = w
		if not weights.is_empty():
			break
	if weights.is_empty():
		rng.randf()
		return String(_sorted_keys(home["houses"])[0])
	return String(_pick(rng, weights))


## A type's own clusters when the group came from the type's own region and
## the type names some, else the group region's.
static func _clusters(group_region: StringName, home_id: StringName, type: Dictionary,
		group: String) -> Array:
	if group_region == home_id and type.has(group):
		return type[group]
	return region(group_region)[group]


static func _weathering(region_id: StringName, tier: StringName) -> float:
	return float(region(region_id).get("wealth", {}).get("weathering", {}).get(String(tier), 0.0))


## A colour from weighted clusters: the cluster, a point along it, and up to
## `weather` of the way toward GRIME (half to all of it, by a draw).
static func _colour(rng: RandomNumberGenerator, clusters: Array, weather: float) -> Dictionary:
	var c: Dictionary = clusters[_pick_index(rng, clusters)]
	var col := Color(String(c["hex"][0])).lerp(Color(String(c["hex"][1])), rng.randf())
	col = col.lerp(GRIME, weather * (0.5 + 0.5 * rng.randf()))
	return {"name": String(c["name"]), "colour": col}


## The roof: a recipe from the roof region (the type's own list when it is
## the type's region; else every recipe whose form the chassis can build, else
## any, keeping only its material and colour), a form from the recipe that
## the chassis can build, its pitch and eave, and a colour.
static func _roof(rng: RandomNumberGenerator, roof_region: StringName, home_id: StringName,
		type: Dictionary, style: StringName, tier: StringName) -> Dictionary:
	var recipes: Dictionary = region(roof_region)["roofs"]
	var allowed: Array = HouseSpec.LOOK_ROOFS.get(style, HouseSpec.STYLES[style].get("roof_types", []))
	var own := roof_region == home_id
	var names := {}
	if own and type.has("roofs"):
		for n in type["roofs"]:
			names[String(n)] = float(recipes[String(n)]["w"])
	else:
		for n in recipes:
			if _fits(recipes[n].get("types", {}), allowed):
				names[String(n)] = float(recipes[n]["w"])
		if names.is_empty():
			for n in recipes:
				names[String(n)] = float(recipes[n]["w"])
	var rid := String(_pick(rng, names))
	var r: Dictionary = recipes[rid]
	var types: Dictionary = type["roof_types"] if own and type.has("roof_types") else r.get("types", {})
	var fit := {}
	for form in types:
		if StringName(String(form)) in allowed:
			fit[String(form)] = float(types[form])
	var form: Variant = _pick(rng, fit) if not fit.is_empty() else null
	if fit.is_empty():
		rng.randf()
	var keys := {"roof_material": String(r["material"])}
	if form != null:
		keys["roof_types"] = [String(form)]
		keys["roof_pitch"] = [float(r["pitch"][0]), float(r["pitch"][1])]
		if r.has("eave"):
			keys["span_out"] = float(r["eave"][0])
			keys["along_out"] = float(r["eave"][1])
		# a level roof stands behind its parapet: a slab with nothing round
		# its edge is a lid (HS-SAHEL-RESIDUE)
		if String(form) == "flat":
			keys["parapet"] = 1.0
	var colour := _colour(rng, r["colours"], _weathering(roof_region, tier) * ROOF_WEATHER)
	keys["roof"] = [_hex(colour["colour"]), _hex(colour["colour"])]
	return {"recipe": rid, "keys": keys, "colour_name": colour["name"],
		"form": String(form) if form != null else ""}


static func _fits(types: Dictionary, allowed: Array) -> bool:
	for form in types:
		if StringName(String(form)) in allowed:
			return true
	return false


## Only what the chassis's own row has, and only what it will honour: a look
## is a patch over a row, never a new key (HouseSpec.look).
static func _prune(style: StringName, look: Dictionary) -> Dictionary:
	var row: Dictionary = HouseSpec.STYLES.get(style, {})
	var out := {}
	for k in look:
		if not row.has(String(k)):
			continue
		if HouseSpec.look_errors(style, {k: look[k]}).is_empty():
			out[k] = look[k]
	return out


# ============================================================ the village

## The landmark: the landmark group's dominant region's church style and its
## colours. `fallback` marks a region whose own sacred building BrickWild
## cannot build yet (its `wants` says what it should be).
func landmark() -> Dictionary:
	var id := dominant(&"landmark")
	var row: Dictionary = region(id).get("landmark", {})
	return {"region": id, "church": StringName(String(row.get("church", "romanesque"))),
		"look": (row.get("look", {}) as Dictionary).duplicate(true),
		"fallback": bool(row.get("fallback", false)), "wants": String(row.get("wants", ""))}


## The plant palette: every slot of every region with at least
## PLANT_MIN_WEIGHT of the plants group (and always the dominant one), in
## region then file order, each key once.
func plant_palette() -> Dictionary:
	var w: Dictionary = groups[&"plants"]
	var top := dominant(&"plants")
	var out := {}
	for id in _sorted_keys(w):
		if float(w[id]) < PLANT_MIN_WEIGHT and id != top:
			continue
		var plants: Dictionary = region(id).get("plants", {})
		for slot in plants:
			var keys: Array = out.get(String(slot), [])
			for k in plants[slot]:
				if not keys.has(String(k)):
					keys.append(String(k))
			out[String(slot)] = keys
	return out


## {VillageBuilder surface: Color}: the ground group's colours, averaged by
## weight (ground is a field of colour, not a set of things to tell apart).
## A surface no region names keeps the builder's own.
func ground_colours() -> Dictionary:
	var w: Dictionary = groups[&"ground"]
	var sums := {}
	var weights := {}
	for id in _sorted_keys(w):
		var ground: Dictionary = region(id).get("ground", {})
		for name in ground:
			var surf: int = GROUND_SURFACES[String(name)]
			var c := Color(String(ground[name]))
			var acc: Color = sums.get(surf, Color(0, 0, 0, 0))
			sums[surf] = Color(acc.r + c.r * float(w[id]), acc.g + c.g * float(w[id]),
				acc.b + c.b * float(w[id]), 1.0)
			weights[surf] = float(weights.get(surf, 0.0)) + float(w[id])
	var out := {}
	for surf in sums:
		var s: Color = sums[surf]
		var k := float(weights[surf])
		out[surf] = Color(s.r / k, s.g / k, s.b / k, 1.0)
	return out


## A place name in the names group's dominant region's tongue.
func village_name(p_seed: int) -> String:
	var names: Dictionary = region(dominant(&"names")).get("names", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("vernacular|name|%d" % p_seed)
	var patterns: Array = names.get("patterns", ["{root}{ending}"])
	var pattern := String(patterns[rng.randi_range(0, patterns.size() - 1)])
	var roots: Array = names.get("roots", ["Vern"])
	var endings: Array = names.get("endings", ["a"])
	var root := String(roots[rng.randi_range(0, roots.size() - 1)])
	var ending := String(endings[rng.randi_range(0, endings.size() - 1)])
	return pattern.replace("{root}", root).replace("{ending}", ending)


# ============================================================ helpers

static func _hex(c: Color) -> String:
	return c.to_html(false)


static func _sorted_keys(d: Dictionary) -> Array:
	var names: Array[String] = []
	for k in d:
		names.append(String(k))
	names.sort()
	var out: Array = []
	for n in names:
		for k in d:
			if String(k) == n:
				out.append(k)
				break
	return out


## A key of `weights`, by weight, in sorted key order (so a dictionary built
## in another order draws the same key).
static func _pick(rng: RandomNumberGenerator, weights: Dictionary) -> Variant:
	var keys := _sorted_keys(weights)
	var total := 0.0
	for k in keys:
		total += maxf(0.0, float(weights[k]))
	var x := rng.randf() * total
	for k in keys:
		x -= maxf(0.0, float(weights[k]))
		if x < 0.0:
			return k
	return keys[keys.size() - 1] if not keys.is_empty() else null


## An index into a list of {"w": weight} rows, by weight, in list order.
static func _pick_index(rng: RandomNumberGenerator, rows: Array) -> int:
	var total := 0.0
	for r in rows:
		total += maxf(0.0, float(r.get("w", 0.0)))
	var x := rng.randf() * total
	for i in range(rows.size()):
		x -= maxf(0.0, float(rows[i].get("w", 0.0)))
		if x < 0.0:
			return i
	return rows.size() - 1

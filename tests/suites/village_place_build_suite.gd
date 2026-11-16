extends RefCounted
## VILLAGE-PLACE (`vplacebuild`; docs/VILLAGE_PLACE.md): the house types the
## presets' features make are BUILT through the public path and pass
## BrickWild.check, and so is each kind of shop. A look the synthesiser wrote
## that a chassis cannot build is found here, before a village draws it.
##
## Eighteen presets make some eighty types, most of them the same chassis in
## another colour, so a type is built once per distinct build: chassis,
## storeys, roof form and covering, and the look's structural keys. Colours
## are not structure. `PLACE_PRESET=<id>` builds one preset's types, all of
## them.

const BuildSuite := preload("res://tests/suites/village_vernacular_build_suite.gd")
const STRUCTURAL: Array[String] = ["timber", "jetty", "stone_ground", "parapet", "veranda", "framing", "dormers"]


static func run() -> SuiteResult:
	var res := SuiteResult.new("vplacebuild")
	var t0 := Time.get_ticks_msec()
	var only := OS.get_environment("PLACE_PRESET")
	var seen := {}
	var shops := {}
	var skipped := 0
	for preset in VillagePlace.preset_ids():
		if not only.is_empty() and preset != only:
			continue
		var made := VillagePlace.ensure({"like": preset})
		res.checked += 1
		if not (made["errors"] as Array).is_empty():
			res.fail("%s: %s" % [preset, str(made["errors"])])
			continue
		var id: StringName = made["id"]
		var row := VillageVernacular.region(id)
		for type_id in row["houses"]:
			var g := VillageVernacular.house_of_type(id, type_id, "build|0")
			var key := _key(g)
			if only.is_empty() and seen.has(key):
				skipped += 1
				continue
			seen[key] = true
			var dims := VillageProgrammer.house_dims(g["style"], 85.0 * float(g["area"]), 2000)
			var req := BuildingRequest.house(2000, g["style"], &"none", dims.x, dims.y, 2.6, int(g["storeys"]))
			req.look = g["look"]
			BuildSuite._build(res, "%s %s" % [preset, type_id], req)
		var fs := VillageVernacular.resolve({"place": {"like": preset}})
		var shop := fs.shop("build|0")
		var shop_key := "%s|%d|%s" % [shop["style"], int(shop["storeys"]), str(shop["look"].get("roof_types", []))]
		if only.is_empty() and shops.has(shop_key):
			skipped += 1
			continue
		shops[shop_key] = true
		var sreq := BuildingRequest.shop(3000, &"tavern", shop["style"], 7.5, 10.0, 2.8, int(shop["storeys"]))
		sreq.look = shop["look"]
		BuildSuite._build(res, "%s shop" % preset, sreq)
	res.note("%d distinct builds, %d repeats of a build already made, total %.1f s" % [seen.size() + shops.size(),
		skipped, (Time.get_ticks_msec() - t0) / 1000.0])
	return res


static func _key(g: Dictionary) -> String:
	var look: Dictionary = g["look"]
	var parts := PackedStringArray([String(g["style"]), str(int(g["storeys"])), str(look.get("roof_types", [])),
		String(look.get("roof_material", ""))])
	for k in STRUCTURAL:
		if look.has(k):
			var v: Variant = look[k]
			parts.append("%s=%s" % [k, str(float(v) >= 0.5) if (v is float or v is int) else str(v)])
	return "|".join(parts)

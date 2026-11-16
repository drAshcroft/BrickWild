extends SceneTree
## VILLAGE-PLACE: what a place's features make. Prints, for every preset (or
## the ones named, or a place given as JSON), the derived features, the house
## types by tier, the roof coverings, the wall and trim clusters, the village
## settings and what 400 drawn households come to.
##
##   godot --headless --path . --script res://tools/probe_village_place.gd
##   godot --headless --path . --script res://tools/probe_village_place.gd -- british_hamlet congo_forest
##   godot --headless --path . --script res://tools/probe_village_place.gd -- '{"heat":0.2,"rain":0.8}'
##   ... -- brief            one line a place


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var brief := args.has("brief")
	var places: Array = []
	for a in args:
		if a == "brief":
			continue
		if a.begins_with("{"):
			var parsed: Variant = JSON.parse_string(a)
			if parsed is Dictionary:
				places.append(parsed)
			else:
				print("not JSON: %s" % a)
		else:
			places.append({"like": a})
	if places.is_empty():
		for id in VillagePlace.preset_ids():
			places.append({"like": id})
	var bad := 0
	for place in places:
		bad += int(not _show(place, brief))
	print("\n%d places, %d refused" % [places.size(), bad])
	quit(1 if bad > 0 else 0)


func _show(place: Dictionary, brief: bool) -> bool:
	var made := VillagePlace.ensure(place)
	var name := String(place.get("like", JSON.stringify(place)))
	if not (made["errors"] as Array).is_empty():
		print("\n== %s REFUSED\n   %s" % [name, "\n   ".join(PackedStringArray(made["errors"]))])
		return false
	var row := VillageVernacular.region(made["id"])
	var f: Dictionary = row["place"]["features"]
	var drawn := _draw(place, 400)
	if brief:
		print("%-20s %-14s %s | %s" % [name, row["culture"], _top(drawn["style"], 3), _top(drawn["material"], 3)])
		return true
	print("\n== %s  [%s]  culture %s" % [name, row["label"], row["culture"]])
	print("   %s" % VillagePlace.words(f))
	var nums := PackedStringArray()
	for k in VillagePlace.FEATURES:
		if String(VillagePlace.FEATURES[k]["kind"]) == "share":
			nums.append("%s %.2f%s" % [k, float(f[k]), "" if (row["place"]["stated"] as Dictionary).has(k) else "~"])
	print("   features (~ derived): %s" % ", ".join(nums))
	print("   hues %s  sacred %s  tongue %s  name '%s'" % [str(f["hues"]), f["sacred"], f["tongue"],
		VillageVernacular.resolve({"place": place}).village_name(7)])
	print("   settings %s" % str(VillagePlace.settings(place)))
	print("   wealth %s" % str(row["wealth"]))
	for tid in row["houses"]:
		var t: Dictionary = row["houses"][tid]
		print("   house %-22s %-14s tiers %s storeys %s roofs %s" % [tid, t["style"], str(t["tiers"]),
			str(t["storeys"]), str(t["roofs"])])
	for rid in row["roofs"]:
		var r: Dictionary = row["roofs"][rid]
		print("   roof  %-12s w %.2f pitch %s %s" % [rid, float(r["w"]), str(r["pitch"]), str((r["types"] as Dictionary).keys())])
	print("   walls %s" % _names(row["walls"]))
	print("   trim  %s" % _names(row["trim"]))
	print("   shop '%s'  landmark %s" % [row["shop"], row["landmark"]["church"]])
	print("   400 households: styles %s" % _top(drawn["style"], 6))
	print("                   roofs  %s | forms %s" % [_top(drawn["material"], 5), _top(drawn["form"], 5)])
	print("                   walls  %s" % _top(drawn["walls"], 6))
	print("                   storeys %s  jank>0 %.2f" % [_top(drawn["storeys"], 3), float(drawn["jank"]) / 400.0])
	return true


func _names(clusters: Array) -> String:
	var parts := PackedStringArray()
	for c in clusters:
		parts.append("%s %.2f" % [c["name"], float(c["w"])])
	return ", ".join(parts)


## `n` households drawn the way a village draws them, at the place's wealth.
func _draw(place: Dictionary, n: int) -> Dictionary:
	var fs := VillageVernacular.resolve({"place": place})
	var wealth := float(VillagePlace.derive(VillagePlace.parse(place)["features"])["wealth"])
	var areas: Array[float] = []
	for i in range(n):
		areas.append(200.0 - float(i) * 0.4)
	var tiers := fs.tiers_by_area(areas, wealth)
	var out := {"style": {}, "material": {}, "form": {}, "walls": {}, "storeys": {}, "jank": 0}
	for i in range(n):
		var g := fs.house("probe|%d" % i, tiers[i], &"farming", &"")
		_count(out["style"], String(g["style"]))
		_count(out["material"], String(g["look"].get("roof_material", "?")))
		_count(out["form"], String(g["clusters"]["roof_form"]))
		_count(out["walls"], String(g["clusters"]["walls"]))
		_count(out["storeys"], str(g["storeys"]))
		out["jank"] = int(out["jank"]) + int(float(g["jank"]) > 0.0)
	return out


func _count(d: Dictionary, k: String) -> void:
	d[k] = int(d.get(k, 0)) + 1


func _top(d: Dictionary, n: int) -> String:
	var keys: Array = d.keys()
	keys.sort_custom(func(a, b) -> bool: return int(d[a]) > int(d[b]) or (int(d[a]) == int(d[b]) and String(a) < String(b)))
	var total := 0
	for k in d:
		total += int(d[k])
	var parts := PackedStringArray()
	for i in range(mini(n, keys.size())):
		parts.append("%s %d%%" % [keys[i], roundi(100.0 * float(d[keys[i]]) / float(maxi(total, 1)))])
	return ", ".join(parts)

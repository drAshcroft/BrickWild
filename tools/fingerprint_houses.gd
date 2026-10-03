extends SceneTree
## Fingerprint the FIVE house styles that existed before HOUSE-RICH, across the
## whole canonical sweep: the plan text, every vertex of the shell, and how many
## rich ornament components that shell logged.
##
## The style list is written out literally rather than read from
## `HouseSpec.STYLES`, because the point is to compare this checkout against one
## where `rich` does not exist -- if it read the table, the two checkouts would
## not be running the same fixtures.
##
##   godot --headless --path . --script res://tools/_rich_fingerprint.gd > new.txt
##
## Identical output means adding rich moved not one room, door, window, piece of
## furniture or vertex in a house that was already there, and logged no
## ornament on any of them.

const OLD_STYLES := [&"cottage", &"farmhouse", &"townhouse", &"longhall", &"witch_hut"]
const ORNAMENT_ROLES := [&"cornice_bed", &"cornice_corona", &"cornice_crown",
	&"string_course", &"pediment_cornice", &"pediment_face",
	&"pediment_rake", &"ridge_crown_plinth", &"ridge_crown"]


func _init() -> void:
	for style in OLD_STYLES:
		for trade in HouseSpec.TRADES.keys():
			for i in HouseSweep.SIZES.size():
				var row: Dictionary = HouseSweep.SIZES[i]
				var s := HouseSpec.new()
				s.style = style
				s.trade = trade
				s.width = float(row["w"])
				s.length = float(row["l"])
				s.height = float(row["h"])
				var seed_value := HouseSweep.seed_at(style, trade, i)
				var plan: HousePlan = HouseGenerator.generate(s, seed_value, false)
				var builder := HouseBuilder.new()
				var mesh := builder.build(plan)
				var acc := 0
				for si in range(mesh.get_surface_count()):
					for p in mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]:
						acc = (acc * 31 + roundi(p.x * 100000.0)) % 1000000007
						acc = (acc * 31 + roundi(p.y * 100000.0)) % 1000000007
						acc = (acc * 31 + roundi(p.z * 100000.0)) % 1000000007
				print("%s %s %d plan=%s shell=%d ornament=%d"
					% [String(style), String(trade), seed_value,
						_plan_text(plan), acc, _ornament(builder)])
	quit()


## The plan as stable text.
##
## `var_to_str` renders an Object as its instance id, so hashing `plan`
## wholesale measures a pointer rather than the plan -- and the pointer differs
## between two processes even when the plan is identical. Every field is taken
## explicitly and `spec` is left out for that reason; what is left is exactly
## the rooms, doors, windows, stairs, furniture and dressing the planner wrote.
func _plan_text(plan: HousePlan) -> String:
	var rows := {}
	for prop in plan.get_property_list():
		var key := String(prop["name"])
		if not (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) or key == "spec":
			continue
		rows[key] = plan.get(key)
	return ("%s" % var_to_str(rows)).md5_text()


func _ornament(builder: HouseBuilder) -> int:
	var n := 0
	for row in builder.component_log:
		if String(row.get("role", "")) in ORNAMENT_ROLES:
			n += 1
	return n
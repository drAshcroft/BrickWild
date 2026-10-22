extends SceneTree
## Which bailey shop plans a castle would show a window the castle log cannot.
##
## Cheap: it plans each yard building (a shop plan plus its house shell) but
## never builds the castle. It applies CastleOccupancyCheck's own pose/match
## rule to the child's wall apertures.
##
##   godot --headless --path . --script res://tools/castle_yard_aperture_sweep.gd -- fortress
##   arguments: tiers (comma list, default fortress) styles (comma list or all)
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var tiers: Array = String(args[0] if args.size() > 0 else "fortress").split(",")
	var styles: Array = CastleSweep.styles()
	if args.size() > 1 and args[1] != "all":
		styles = String(args[1]).split(",")
	var interiors = preload("res://src/castle/castle_interiors.gd")
	var bad := 0
	var cases := 0
	for style in styles:
		for tier in tiers:
			for i in 3:
				var spec := CastleSweep.spec_at(StringName(style), StringName(tier), i)
				for entry in CastleGenerator.bailey_buildings(spec):
					var row: Dictionary = interiors.yard(spec, entry)
					var plan: HousePlan = row.get("plan")
					if plan == null or plan.spec == null:
						print("FAIL %s %s %d %s: no plan %s" % [style, tier, i,
							String(entry.business), str(row.get("errors", []))])
						bad += 1
						continue
					cases += 1
					var child := HouseBuilder.new()
					child.build(plan, false)
					var missing: Array[String] = []
					for wi in plan.windows.size():
						var window: Dictionary = plan.windows[wi]
						var room := int(window.get("room", -1))
						if room < 0 or room >= plan.rooms.size():
							continue
						var opening := CastleOccupancyCheck._pose(plan, row.transform,
							window, room, false)
						var found := false
						for part in child.part_log:
							if String(part.get("kind", "")) != "window":
								continue
							if String(part.get("opening_kind", "")) == "door":
								continue
							var world := part.duplicate(true)
							world.pos = row.transform * Vector3(part.pos)
							world.facing = (row.transform.basis * Vector3(part.facing)).normalized()
							if CastleOccupancyCheck._matches(opening, world):
								found = true
								break
						if not found:
							missing.append("window %d room %d hatch=%s pos=%s" % [wi, room,
								str(window.get("hatch", false)), str(window.get("pos", Vector2.ZERO))])
					if missing.is_empty():
						continue
					bad += 1
					print("FAIL %s %s %d seed=%d %s: %d of %d windows" % [style, tier, i,
						spec.seed, String(entry.business), missing.size(), plan.windows.size()])
					for line in missing:
						print("     " + line)
	print("yard plans %d, with unforwarded windows %d" % [cases, bad])
	quit()

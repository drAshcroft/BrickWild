extends SceneTree
## BG-015 scratch: a flat plan's export, hashed, so "a flat plan stays
## byte-identical" is a diff. Prints one line per part.
const EXPORTER := preload("res://tools/export_village_plan.gd")

func _init() -> void:
	for c in [[&"street", 4242, 30], [&"green", 11, 40]]:
		var s := VillageSpec.new(int(c[1]))
		s.population = int(c[2])
		s.generate(int(c[1]))
		s.form = c[0]
		var plan := VillageLotPlanner.plan(s)
		var site: Dictionary = EXPORTER.site_plan(plan, {})
		var walk: Dictionary = VillageWalk.projection(plan, "flat")
		var rows: Array = EXPORTER._buildings(plan, "flat")
		var text := JSON.stringify(site, "", true)
		print("%s site=%s walk=%s buildings=%s bytes=%d" % [c[0], text.sha256_text().substr(0, 16),
			JSON.stringify(walk, "", true).sha256_text().substr(0, 16),
			JSON.stringify(rows, "", true).sha256_text().substr(0, 16), text.length()])
		var f := FileAccess.open("res://scratch/bg015_flat_%s.json" % String(c[0]), FileAccess.WRITE)
		f.store_string(text)
		f.close()
	quit()

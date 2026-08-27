class_name TempleArchetypeSuite
extends RefCounted
## 18. The temples the brief asked for: the ones a fantasy author would want to
##     walk into and then write about.
##
## Each row names a building, gives it a form and a cult and a size, and then
## says what it must CONTAIN -- never where anything goes. A test that says
## where the altar is has stopped testing the generator and started testing
## itself.
##
## Every one is built at four sizes and put through the whole harness: the
## structural rules, and every rule about the rite.

const SCALES: Array[float] = [0.7, 1.0, 1.35, 1.8]

const ARCHETYPES: Array[Dictionary] = [
	{"key": "bloodpit_basilica", "form": &"basilica", "cult": &"blood",
		"w": 26.0, "l": 46.0, "h": 13.0,
		"needs": ["pit", "cells", "columns"],
		"about": "a nave of columns, a hole in the floor, and cages down the aisles"},
	{"key": "starless_pylon", "form": &"pylon", "cult": &"void",
		"w": 34.0, "l": 58.0, "h": 15.0,
		"needs": ["obelisks", "columns"],
		"about": "obelisks, a court, and a forest of columns before the dark room"},
	{"key": "ashen_ziggurat", "form": &"ziggurat", "cult": &"flame",
		"w": 40.0, "l": 46.0, "h": 16.0,
		"needs": ["terraces", "stairs"],
		"about": "a stepped mountain with the fire on top of it"},
	{"key": "coiled_rotunda", "form": &"rotunda", "cult": &"serpent",
		"w": 32.0, "l": 34.0, "h": 12.0,
		"needs": ["pit", "columns", "bridge"],
		"about": "a ring of columns round a hole, and the altar on the bridge over it"},
	{"key": "ossuary_basilica", "form": &"basilica", "cult": &"bone",
		"w": 22.0, "l": 40.0, "h": 11.0,
		"needs": ["columns", "spire_or_cells"],
		"about": "a cairn of skulls where the reredos should be"},
	{"key": "drowned_rotunda", "form": &"rotunda", "cult": &"blood",
		"w": 26.0, "l": 28.0, "h": 10.0,
		"needs": ["pit", "bridge"],
		"about": "small, round, and mostly hole"},
	{"key": "hungering_pylon", "form": &"pylon", "cult": &"bone",
		"w": 28.0, "l": 52.0, "h": 13.0,
		"needs": ["columns"],
		"about": "a bone cult keeping Egyptian hours"},
]


static func run() -> SuiteResult:
	var res := SuiteResult.new("temple archetype")
	for row in ARCHETYPES:
		var key: String = row["key"]
		var defects := 0
		for scale in SCALES:
			var spec := TempleSpec.new()
			spec.form = row["form"]
			spec.cult = row["cult"]
			spec.width = float(row["w"]) * scale
			spec.length = float(row["l"]) * scale
			spec.height = float(row["h"]) * sqrt(scale)
			TempleGenerator.generate(spec, _seed_for(key, scale))
			_force(spec, row["needs"])
			var builder := TempleBuilder.new()
			builder.build(spec)
			res.checked += 1
			var who := "%s scale=%.2f" % [key, scale]
			var before: int = res.failures.size()

			# what makes it that temple. A small one may not manage all of it;
			# at full size and above it must.
			if scale >= 1.0:
				for need in row["needs"]:
					if not _has(spec, builder, String(need)):
						res.fail("%s: no %s" % [who, String(need)])

			var rep: Dictionary = TempleQA.new().check(spec, builder)
			for f in rep["failures"]:
				res.fail("%s: %s" % [who, str(f)])
			for w in rep["warnings"]:
				res.warn("%s: %s" % [who, str(w)])
			if res.failures.size() > before:
				defects += 1
		res.note("  %-18s %d scales, %d defects -- %s"
			% [key, SCALES.size(), defects, row["about"]])
	return res


## Set the features this archetype is defined by, overriding the generator's
## coin flips -- a roll should never be the reason the Bloodpit Basilica has no
## pit. Sizes the generator already settled are left alone; only the flags that
## make the building what it is are forced, and everything downstream of them
## is then re-settled by the generator's own fitting rules.
static func _force(spec: TempleSpec, needs: Array) -> void:
	for need in needs:
		match String(need):
			"pit", "bridge":
				if not spec.pit:
					spec.pit = true
					TempleGenerator.fit_pit(spec)
			"cells":
				spec.cells = maxi(spec.cells, 2)
			"obelisks":
				spec.obelisks = true
			"spire_or_cells":
				if not spec.spire:
					spec.cells = maxi(spec.cells, 2)


static func _seed_for(key: String, scale: float) -> int:
	return 41000 + absi(key.hash()) % 900 + int(scale * 100.0)


static func _has(spec: TempleSpec, builder: TempleBuilder, need: String) -> bool:
	match need:
		"pit":
			return spec.pit and TempleGeometry.pit_rect(spec).size.x > 0.0
		"bridge":
			return TempleGeometry.bridge_rect(spec).size.x > 0.0
		"cells":
			return spec.cells > 0 and not TempleGeometry.cell_rects(spec).is_empty()
		"columns":
			return not TempleGeometry.column_positions(spec).is_empty()
		"obelisks":
			return builder.has_mass("obelisk_left")
		"terraces":
			return builder.has_mass("terrace_1")
		"stairs":
			return builder.has_mass("stair_left") and builder.has_mass("stair_right")
		"spire_or_cells":
			return spec.spire or spec.cells > 0
	return false

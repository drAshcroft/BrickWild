class_name CastleSweep
extends RefCounted
## The canonical castle variant sweep: every style x every tier x three sizes
## inside that tier, on fixed seeds. Every castle suite iterates the same set,
## so a seed named in one suite's output means the same building in another's.
##
## Sizes are chosen INSIDE each tier's area band rather than at round numbers,
## because the tier boundary is the interesting place for the massing to break:
## a site one square metre over the line becomes a different building.

## Three footprints per tier: near the bottom of its band, in the middle, and
## near the top. Height rises with the tier, as it does in the real buildings.
const SIZES := {
	&"house": [
		{"w": 6.0, "l": 9.0, "h": 4.5},
		{"w": 8.0, "l": 20.0, "h": 5.5},
		{"w": 12.0, "l": 24.0, "h": 6.5},
	],
	&"manor": [
		{"w": 14.0, "l": 24.0, "h": 8.0},
		{"w": 26.0, "l": 40.0, "h": 10.0},
		{"w": 32.0, "l": 60.0, "h": 12.0},
	],
	&"castle": [
		{"w": 40.0, "l": 55.0, "h": 14.0},
		{"w": 60.0, "l": 90.0, "h": 18.0},
		{"w": 80.0, "l": 145.0, "h": 22.0},
	],
	&"fortress": [
		{"w": 90.0, "l": 140.0, "h": 20.0},
		{"w": 140.0, "l": 200.0, "h": 24.0},
		{"w": 200.0, "l": 300.0, "h": 28.0},
	],
}

const COUNT := 3


static func styles() -> Array:
	return CastleSpec.STYLES.keys()


static func tiers() -> Array:
	return SIZES.keys()


## Build spec number `i` for (style, tier), generated and ready to build.
static func spec_at(style: StringName, tier: StringName, i: int) -> CastleSpec:
	var row: Dictionary = SIZES[tier][i]
	var spec := CastleSpec.new()
	spec.style = style
	spec.width = float(row["w"])
	spec.length = float(row["l"])
	spec.height = float(row["h"])
	CastleGenerator.generate(spec, seed_at(tier, i))
	return spec


static func seed_at(tier: StringName, i: int) -> int:
	return 9000 + absi(String(tier).hash()) % 500 + i


## Every (style, tier, index) triple in the sweep, in a stable order.
static func each() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for style in styles():
		for tier in tiers():
			for i in range(COUNT):
				out.append({"style": style, "tier": tier, "index": i})
	return out

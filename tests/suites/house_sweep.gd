class_name HouseSweep
extends RefCounted
## The canonical house variant sweep: every style, every trade, four sizes,
## fixed seeds. Every house suite iterates the same set, so a seed named in one
## suite's output means the same house in another's.
##
## The sizes start below the one-room threshold and end large enough to force
## the planner up to six rooms, because the interesting failures are at both
## ends: a hut too small to hold a bed, and a house with enough rooms that one
## of them ends up behind another.

const SIZES := [
	{"w": 5.5, "l": 7.0, "h": 2.4},     # one room, and only just
	{"w": 8.0, "l": 10.0, "h": 2.6},    # two or three
	{"w": 11.0, "l": 14.0, "h": 2.7},   # four or five
	{"w": 14.0, "l": 18.0, "h": 2.9},   # the full programme
]

const COUNT := 4


static func styles() -> Array:
	return HouseSpec.STYLES.keys()


static func trades() -> Array:
	return HouseSpec.TRADES.keys()


## Build spec number `i` for (style, trade), generated and furnished.
## Returns [spec, plan].
static func at(style: StringName, trade: StringName, i: int) -> Array:
	var row: Dictionary = SIZES[i]
	var spec := HouseSpec.new()
	spec.style = style
	spec.trade = trade
	spec.width = float(row["w"])
	spec.length = float(row["l"])
	spec.height = float(row["h"])
	var plan: HousePlan = HouseGenerator.generate(spec, seed_at(style, trade, i))
	return [spec, plan]


static func seed_at(style: StringName, trade: StringName, i: int) -> int:
	return 11000 + absi(String(style).hash()) % 400 + absi(String(trade).hash()) % 90 + i


## Every (style, trade, index) triple in the sweep, in a stable order.
static func each() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for style in styles():
		for trade in trades():
			for i in range(COUNT):
				out.append({"style": style, "trade": trade, "index": i})
	return out

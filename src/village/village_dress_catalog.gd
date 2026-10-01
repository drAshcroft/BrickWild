class_name VillageDressCatalog
extends RefCounted
## Exterior recipes, palettes, and clearance policy.

# ------------------------------------------------------------- the recipes

## Metres of clear ground a prop wants around it before it is worth placing.
const PROP_CLEAR := 0.35
## Nothing stands within this of a door's own swing, ever.
const DOOR_CLEAR := 1.2
## Nothing stands on a road, and this is how far off one it stays.
const ROAD_CLEAR := 0.4
## A trunk stays this far off any road polygon and any building's bounds.
const TRUNK_CLEAR := 1.0
## A canopy may not hang over a roof at all; this is the slack allowed.
const CANOPY_SLACK := 0.1
## How many places along a building's front a `wall` or `verge` step is
## offered, per step out from the wall.
const FRONT_SPOTS := 6
## How far apart the trees of the edge band stand. Â§9.6 walks the edge and
## refuses a run longer than 25 m with nothing within 6 m of it, so the band
## is PLANTED ALONG the edge at a pitch rather than scattered near it.
const EDGE_PITCH := 6.0

## Â§7's recipe table, by host. A host is a building (by its programme role),
## or one of the places that is not a building at all -- the common, a gate,
## the water, the strand, the edge.
##
## `n` is [min, max] and `opt` is the same die HouseFurnisher rolls: 1.0 is a
## piece the host is not that host without, and anything less can be left out
## when there is nowhere to put it.
const RECIPES := {
	# any house: what a household leaves outside its own front door
	&"house": [
		{"cat": "barrel", "rule": &"wall", "n": [1, 1], "opt": 0.7},
		{"cat": "bench", "rule": &"wall", "n": [0, 1], "opt": 0.4},
		{"cat": "bush", "rule": &"verge", "n": [2, 2], "opt": 0.6, "plant": true},
	],
	&"farm": [
		{"cat": "crate", "rule": &"yard", "n": [1, 3], "opt": 0.9},
		{"cat": "sack", "rule": &"yard", "n": [1, 2], "opt": 0.9},
		{"cat": "wagon", "rule": &"yard", "n": [0, 1], "opt": 0.6},
		{"cat": "haystack", "rule": &"yard", "n": [1, 1], "opt": 0.8, "built": true},
		{"cat": "tree", "rule": &"row", "n": [3, 3], "pitch": 5.0, "opt": 1.0, "plant": true, "orchard": true},
	],
	&"smithy": [
		{"cat": "anvil", "rule": &"wall", "n": [1, 1], "opt": 1.0},
		{"cat": "barrel", "rule": &"wall", "n": [1, 1], "opt": 1.0},
		{"cat": "cookware", "rule": &"wall", "n": [0, 1], "opt": 0.8},
		{"cat": "sconce", "rule": &"light", "n": [1, 1], "opt": 1.0},
	],
	&"tavern": [
		{"cat": "bench", "rule": &"verge", "n": [2, 2], "opt": 1.0},
		{"cat": "barrel", "rule": &"verge", "n": [1, 2], "opt": 1.0},
		{"cat": "sconce", "rule": &"light", "n": [1, 1], "opt": 1.0},
		{"cat": "banner", "rule": &"wall", "n": [1, 1], "opt": 0.6},
	],
	&"stable": [
		{"cat": "wagon", "rule": &"yard", "n": [1, 1], "opt": 0.8},
		{"cat": "sack", "rule": &"wall", "n": [1, 2], "opt": 0.8},
	],
	&"market": [
		{"cat": "stall", "rule": &"row", "n": [3, 6], "pitch": 4.0, "opt": 1.0},
		{"cat": "crate", "rule": &"on", "n": [1, 2], "opt": 0.9},
		{"cat": "wall_torch", "rule": &"light", "n": [2, 2], "opt": 1.0},
	],
	# the common: the well first, and it is the reason a common is a common
	&"common": [
		{"cat": "well", "rule": &"centre", "n": [1, 1], "opt": 1.0, "built": true},
		{"cat": "bench", "rule": &"scatter", "n": [2, 2], "opt": 0.7},
		{"cat": "tree", "rule": &"centre", "n": [1, 1], "opt": 0.5, "plant": true,
			"palette": "green"},
		{"cat": "flower", "rule": &"scatter", "n": [2, 4], "opt": 0.6, "plant": true},
	],
	&"church": [
		{"cat": "tree", "rule": &"ring", "n": [4, 6], "opt": 0.8, "plant": true,
			"palette": "edge"},
	],
	&"gate": [
		{"cat": "signpost", "rule": &"beside", "n": [1, 1], "opt": 1.0, "built": true},
		{"cat": "lamp_post", "rule": &"beside", "n": [2, 2], "opt": 1.0, "built": true},
	],
	&"water": [
		{"cat": "rock", "rule": &"bank", "n": [2, 5], "opt": 0.8, "plant": true},
		{"cat": "plant", "rule": &"bank", "n": [2, 4], "opt": 0.7, "plant": true},
	],
	# rushes along the bank, planted LAST so they take only what nothing else
	# wanted: never the strand's aprons, never a road or a door
	&"reeds": [
		{"cat": "reed", "rule": &"reeds", "n": [1, 1], "opt": 1.0, "plant": true,
			"palette": "reed", "fill": true},
	],
	&"strand": [
		{"cat": "boat", "rule": &"bank", "n": [1, 2], "opt": 1.0, "built": true},
		{"cat": "drying_rack", "rule": &"bank", "n": [1, 2], "opt": 1.0, "built": true},
		{"cat": "crate", "rule": &"bank", "n": [1, 2], "opt": 0.7},
	],
	# the edge: what bounds the village, at the culture's own density
	# `fill` because an edge is as long as the village is round: Â§9.6 walks
	# the perimeter and refuses a run over twenty-five metres with nothing
	# within six of it, so the count cannot be a number in a recipe -- a
	# fourteen-tree edge round a three-hundred-metre village leaves six
	# hundred metres of nothing. The rule supplies the places and the step
	# takes all of them.
	&"edge": [
		{"cat": "tree", "rule": &"band", "n": [6, 14], "opt": 1.0, "plant": true,
			"palette": "edge", "fill": true},
		{"cat": "ground", "rule": &"band", "n": [4, 10], "opt": 0.6, "plant": true,
			"palette": "ground"},
	],
}

## Â§8's palette, by culture. Four slots, and a village plants from one row and
## no other: `edge` at the boundary and behind the farms, `green` the one tree
## on the common, `hedge` along a lot's side boundaries and the verges,
## `ground` the cover on the verges and the common, `wild` the dead and
## storm-broken trees an old edge always has one or two of.
##
## The keys are catalogue keys, not categories, because a palette is exactly
## the business of naming WHICH birch. A `*` suffix takes every catalogue key
## with that prefix, so a pack that ships a sixth pine is planted without this
## table changing.
const PALETTES := {
	&"english": {"edge": ["Wild_CommonTree_*", "Nature_MapleTree_*"],
		"green": ["Wild_CommonTree_*"], "hedge": ["Wild_Bush_Common*"],
		"ground": ["Wild_Grass_Common_*", "Wild_Clover_*", "Nature_Flower_*_Clump"],
		"wild": ["Nature_DeadTree_1", "Nature_DeadTree_2"]},
	&"frankish": {"edge": ["Wild_CommonTree_*", "Nature_MapleTree_*"],
		"green": ["Wild_CommonTree_*"], "hedge": ["Wild_Bush_Common*"],
		"ground": ["Wild_Grass_Common_*", "Wild_Clover_*", "Nature_Flower_*_Clump"],
		"wild": ["Nature_DeadTree_1", "Nature_DeadTree_2"]},
	&"norse": {"edge": ["Wild_Pine_*", "Nature_BirchTree_*"],
		"green": ["Nature_BirchTree_*"], "hedge": ["Nature_Bush_Small*"],
		"ground": ["Wild_Grass_Wispy_*", "Wild_Rock_Medium_*"],
		"wild": ["Nature_DeadTree_1", "Nature_DeadTree_2"]},
	&"alpine": {"edge": ["Wild_Pine_*", "Nature_BirchTree_*"],
		"green": ["Nature_BirchTree_*"], "hedge": ["Nature_Bush_Small*"],
		"ground": ["Wild_Grass_Wispy_*", "Wild_Rock_Medium_*"],
		"wild": ["Nature_DeadTree_1", "Nature_DeadTree_2"]},
	&"moorish": {"edge": ["Wild_TwistedTree_*", "Wild_CommonTree_*"],
		"green": ["Wild_TwistedTree_*"], "hedge": ["Wild_Plant_1*", "Wild_Plant_7*"],
		"ground": ["Wild_Pebble_*", "Wild_Grass_Common_Short"],
		"wild": ["Nature_DeadTree_1"]},
	&"eastern": {"edge": ["Wild_TwistedTree_*", "Wild_CommonTree_*"],
		"green": ["Wild_TwistedTree_*"], "hedge": ["Wild_Plant_1*", "Wild_Plant_7*"],
		"ground": ["Wild_Pebble_*", "Wild_Grass_Common_Short"],
		"wild": ["Nature_DeadTree_1"]},
	# no green tree at all: nothing grows on a blighted common
	&"blighted": {"edge": ["Nature_DeadTree_*", "Wild_DeadTree_*"],
		"green": [], "hedge": ["Wild_Mushroom_*"],
		"ground": ["Wild_Mushroom_*", "Wild_Pebble_Square_*"]},
}

## Rushes and sedge for a bank. Every culture's water has them, so they are
## not a row of PALETTES: `palette_keys` falls back to this for the `reed` slot.
const REEDS: Array = ["Wild_Grass_Wispy_Tall", "Wild_Grass_Common_Tall", "Nature_Grass_Large"]

## The props that are BUILT rather than loaded (VIL-010). A recipe step marked
## `built` names one of these instead of a catalogue category; the assembler
## emits it from `PropKit` and the checks measure the AABB it returns.
const BUILT := {
	"well": {"size": Vector2(2.1, 2.1), "zone": 1.0},
	"signpost": {"size": Vector2(0.8, 0.8), "zone": 0.0},
	"lamp_post": {"size": Vector2(0.6, 0.6), "zone": 0.0, "light": true},
	"haystack": {"size": Vector2(2.8, 2.8), "zone": 0.0},
	"boat": {"size": Vector2(1.6, 4.4), "zone": 0.8},
	"drying_rack": {"size": Vector2(1.6, 3.0), "zone": 0.8},
	"mill_wheel": {"size": Vector2(3.8, 0.8), "zone": 0.0},
	"adit": {"size": Vector2(2.4, 1.2), "zone": 1.2},
	"fence_gate": {"size": Vector2(2.0, 0.4), "zone": 1.2},
}

## How thick the planted band outside the enclosure is, by enclosure kind --
## the same table Â§1 sizes the edge band with.
const EDGE_BAND := {&"none": 4.0, &"hedge": 5.0, &"palisade": 8.0, &"wall": 10.0}
## A `forest` village plants its edge at twice the density.
const FOREST_DENSITY := 2.0
## The green tree stands this far off the well.
const GREEN_TREE_CLEAR := 4.0


## Dress a planned village: fills `plan.props` and `plan.plants` and nothing
## else. Mutates the plan it is given, like the furnisher does; returns it for
## convenience.


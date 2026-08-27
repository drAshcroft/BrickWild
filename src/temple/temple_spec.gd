class_name TempleSpec
extends RefCounted
## One temple to something that should not be worshipped.
##
## Two independent choices decide what comes out. FORM is the architecture --
## the plan a real temple of that kind would have been built to. CULT is what
## is done in it, which decides the dressing: the idol, the fittings, the
## colour of the stone and how much of it is stained.
##
## Keeping them apart is the point. A basilica of the Ossuary and a ziggurat of
## the Ossuary are the same religion in different buildings, and a basilica of
## the Blood Choir is a different religion in the same building.

var seed: int
var rng: RandomNumberGenerator

# ---- user-specified (never randomized) ----
var form: StringName = &"basilica"
var cult: StringName = &"blood"
var width: float = 26.0     # X, metres, outside face to outside face
var length: float = 44.0    # Z; the way in is at -Z, the god is at +Z
var height: float = 12.0    # floor to the ceiling of the great hall

# ---- derived from seed + form + cult ----
var variant_name: String
var wall_t: float
var column_rows: int          # rows of columns each side of the processional way
var column_bays: int          # how many down the length
var column_r: float
var aisle_width: float
var dais_steps: int
var dais_height: float
var altar_w: float
var altar_l: float
var altar_h: float
var idol_kind: StringName     # &"monolith", &"figure", &"coil", &"cairn", &"pyre"
var idol_height: float
var idol_width: float
var pit: bool
var pit_radius: float
var bridge_width: float
var cells: int                # cages or holding chambers off the aisles
var brazier_bays: int         # braziers down the processional way
var spire: bool
var spire_height: float
var terraces: int             # ziggurat only
var obelisks: bool            # pylon only
var stain: float              # 0..1: how much of the stone is discoloured
var stone_color: Color
var trim_color: Color
var roof_color: Color
var glow_color: Color         # braziers, glyphs, the light the place is lit by

## The forms, each a plan a real temple was actually built to, bent to a
## purpose it was not.
const FORMS := {
	&"basilica": {
		"label": "Basilica",
		# the cathedral plan, corrupted: nave, aisles, apse, and a spire over
		# the place where the altar stands
		"rows": [1, 1, 2], "bays": [5, 9], "aisles": true, "apse": true,
		"spire": 0.75, "pit": 0.45, "cells": [0, 2, 4], "roof": &"ridge",
	},
	&"pylon": {
		"label": "Pylon",
		# Egyptian: a wall of a gate, an open court, a forest of columns, and a
		# small dark room at the end that almost nobody ever entered
		"rows": [2, 3], "bays": [4, 7], "aisles": false, "apse": false,
		"spire": 0.0, "pit": 0.3, "cells": [0, 2], "roof": &"flat",
		"obelisks": 0.85, "court": 0.35,
	},
	&"ziggurat": {
		"label": "Ziggurat",
		# a stepped mountain with a stair up the front, a shrine on the summit
		# and the real work done in the chamber inside the base
		"rows": [1, 2], "bays": [3, 5], "aisles": false, "apse": false,
		"spire": 0.0, "pit": 0.6, "cells": [2, 4], "roof": &"terraced",
		"terraces": [3, 4, 5],
	},
	&"rotunda": {
		"label": "Rotunda",
		# a ring of columns round a hole in the world, with the altar on a
		# bridge over it
		"rows": [1, 1], "bays": [0, 0], "aisles": false, "apse": false,
		"spire": 0.35, "pit": 1.0, "cells": [0, 3], "roof": &"dome",
	},
}

## The cults. `idol` is what stands behind the altar, `dress` the props the
## place is fitted out with, and `stain` how much of the stone shows what has
## been done on it.
const CULTS := {
	&"blood": {
		"label": "The Crimson Choir",
		"idol": [&"figure"], "stain": [0.55, 0.9], "brazier": [3, 6],
		"cells": 1.0, "chains": 1.0,
		"stone": ["6e5b57", "4a3b39"], "trim": ["8d2f2a", "5e1f1c"],
		"roof": ["3a2b28", "241a18"], "glow": "d8452f",
	},
	&"void": {
		"label": "The Starless Deep",
		"idol": [&"monolith"], "stain": [0.0, 0.2], "brazier": [2, 4],
		"cells": 0.3, "chains": 0.4,
		"stone": ["2f3138", "1b1d22"], "trim": ["46506b", "2a3247"],
		"roof": ["24262c", "141519"], "glow": "5b74c8",
	},
	&"flame": {
		"label": "The Ashen Crown",
		"idol": [&"pyre"], "stain": [0.3, 0.6], "brazier": [5, 9],
		"cells": 0.5, "chains": 0.6,
		"stone": ["6b5a4a", "473a2f"], "trim": ["c86a1e", "8a4413"],
		"roof": ["3d2f24", "241b14"], "glow": "ff8a2b",
	},
	&"bone": {
		"label": "The Ossuary",
		"idol": [&"cairn"], "stain": [0.2, 0.5], "brazier": [3, 5],
		"cells": 0.8, "chains": 0.7,
		"stone": ["9e9a8c", "7a7466"], "trim": ["ded4bd", "b3a98e"],
		"roof": ["4a453a", "2e2b24"], "glow": "b9d68a",
	},
	&"serpent": {
		"label": "The Coiled Fang",
		"idol": [&"coil"], "stain": [0.25, 0.5], "brazier": [3, 6],
		"cells": 0.6, "chains": 0.5,
		"stone": ["55604f", "39412f"], "trim": ["7fae4b", "4d7030"],
		"roof": ["2f3a2c", "1c231a"], "glow": "8ede4a",
	},
}


func _init(p_seed := 0) -> void:
	seed = p_seed
	rng = RandomNumberGenerator.new()
	rng.seed = seed

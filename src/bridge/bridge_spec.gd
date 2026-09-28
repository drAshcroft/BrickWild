class_name BridgeSpec
extends RefCounted
## Plan data for the bridge family (BRG-001..004).
##
## A bridge is the first family here whose SUBJECT is a span between two
## things that are not part of it. A church is a building; a tree is a plant;
## a bridge is a length of deck with a bank at each end, and every question
## about it -- is the deck supported, does it meet the ground, is the channel
## clear -- is a question about the relationship between the structure and a
## site the structure does not own.
##
## So the site is IN the spec. `span`, `bank_height` and `water_level` are
## chosen by a caller, `BridgeGeometry.bank_height_at()` is the single source of
## truth for the ground, and the abutments, the render tool's terrain and every
## QA rule read that one function. A bridge whose feet do not match the ground
## it stands on is a bridge drawn on a picture of a bridge.
##
## Four kinds, and they are four different STRUCTURES rather than four skins:
##
##   stone   masonry arches on piers. The load goes sideways into compression
##           and down into the ground, and the whole point is that you can see
##           it.
##   covered a timber gallery with a gable roof over the deck. The load is
##           carried by posts and beams, and the roof is half the silhouette.
##   rope    a suspension. Two towers, a main cable, hangers, an anchored deck.
##           The most dramatic profile in the family and the easiest to get
##           wrong, because a cable with the wrong curve is a rope bridge with
##           a slack rope.
##   mobile  a span that MOVES: a vertical lift, a swing, a pontoon that rises
##           with the tide, a drawbridge leaf. The mechanism is the building.
##
## Model axes: +X along the span, +Y up, +Z across the deck. The datum, y = 0,
## is the WATER. The deck runs from x = -span/2 to +span/2.

# ---- what a person chooses ----
var kind: StringName = &"stone"
## A sub-kind for `mobile`: lift, swing, pontoon or drawbridge. Ignored otherwise.
var motion: StringName = &"lift"
var seed := 0
var rng := RandomNumberGenerator.new()

## Bank to bank, along X. The deck spans all of it.
var span := 24.0
## The walking surface, across Z.
var width := 3.0
## Height of the walking surface at the ABUTMENTS, above the water. A stone
## arch camber rises above this toward midspan; the other three are level.
var deck_height := 4.0
## How high the ground stands at each end, before the bridge's abutments.
var bank_height := 4.0
var water_level := 0.0
## How steep the bank face is: the horizontal run of ground between the water's
## edge and the top. Steeper is a gorge, shallower is a meadow crossing.
var bank_run := 14.0

# ---- shape controls. All written by TreeGenerator -- er, BridgeGenerator, and
# ---- all read by BridgeGeometry, so there is one number per idea. ----
## Thickness of the walking slab.
var deck_thickness := 0.45
## How much a stone deck rises at midspan over its height at the abutments.
var camber := 0.0
## Thickness of a pier or an abutment wall, along X.
var pier_width := 1.8
## Height of a suspension tower ABOVE the deck.
var tower_height := 9.0
## How far the main cable hangs below the tower tops at midspan.
var cable_sag := 0.0
## Rise of a covered bridge's gable, from the eaves to the ridge.
var roof_rise := 2.2
## How wide a covered bridge's roof overhangs its deck, per side.
var roof_overhang := 0.7
## Pitch of that gable, as rise over half the roof's width.
var roof_pitch := 0.55
## Spacing of a covered bridge's roof posts, and of its side beams.
var bay_pitch := 3.0
## Spacing of a suspension bridge's hangers.
var hanger_pitch := 2.2
## How far the masonry parapet stands above the walking surface.
var parapet_height := 0.9
## Thickness of that parapet.
var parapet_width := 0.35
## How many arches, or how many spans. One for a covered or rope bridge.
var bays := 1
## How far a suspension tower leans IN, as a multiple of the deck width.
var tower_tilt := 0.10
## How far a movable span swings or lifts, in metres.
var travel := 6.0
## How deep a pontoon floats, and how wide one is.
var pontoon_draft := 0.8
var pontoon_width := 2.4

# ---- what the generator derives ----
## The x of every support standing in the water or on the ground. The ends are
## always there, so `piers[0]` and `piers[-1]` are the abutments.
var piers: Array[Dictionary] = []
## {"x": float, "w": float, "top": float, "kind": StringName} where kind is
## abutment, pier, tower or pontoon.
## The deck's centreline, sampled, as {"x", "y"} -- flat for three kinds, a
## camber for stone.
var deck: Array[Vector2] = []
## Everything the builder will draw, as data: {"role", "a": Vector3, "b": Vector3,
## "r0", "r1", "surf", "carries": PackedFloat32Array} where `carries` is the
## x range this member is responsible for holding up. A deck point with no
## member carrying it is a cantilever nobody asked for.
var members: Array[Dictionary] = []
## Lights the assembler turns into OmniLight3D: {"pos", "colour", "energy",
## "range"}. A lantern at each end of a covered bridge is the whole reason
## anybody sees one at night.
var glow: Array[Dictionary] = []

# ---- materials ----
var stone_color := Color("9a9284")
var timber_color := Color("6b543c")
var deck_color := Color("7d6a4e")
var metal_color := Color("4a4a52")
var roof_color := Color("5a4436")
var variant_name := ""

# ---- the four surfaces, in TreeGeometry's order ----
const SURF_STONE := 0
const SURF_TIMBER := 1
const SURF_DECK := 2
const SURF_METAL := 3
const SURFACE_COUNT := 4

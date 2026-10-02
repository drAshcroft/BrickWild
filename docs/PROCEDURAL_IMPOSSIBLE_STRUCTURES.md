# Impossible structures: coherent spaces that the real world cannot build

Fantasy architecture can break gravity, Euclidean distance, material strength,
and even the continuity of space. A generator still needs rules: a player must
know where a doorway leads, where a floor can be walked, and what a view from
each side will show. The useful distinction is between **what exists in the
world graph** and **where its meshes are embedded for display**. Those may
disagree on purpose.

## 1. Choose the impossible premise first

| Premise | Design effect | Representation | Main failure to test |
|---|---|---|---|
| Unsupported mass | Floating citadel, hanging stair, bridge of light | Separate mass and support policy | Player sees a gap but collision treats it as solid ground |
| Bigger inside | Small hut opens into a great hall | Separate interior cell/scene and threshold transform | Interior visible or audible through wrong exterior wall |
| Folded route | Two remote doors touch in travel time | Portal edge between room graph nodes | AI route and player route disagree |
| Looping corridor | Return to a room after an impossible sequence | Directed graph with repeated or transformed room instances | Minimap, breadcrumbs, or seed state lose identity |
| Changed gravity | Rooms on walls or ceilings | Gravity frame per region and transition rule | Camera or props snap while crossing |
| Shifting building | Stairs or rooms move on a schedule or trigger | State-dependent adjacency graph | A reachable objective becomes stranded |
| False perspective | Distant tower looks connected at one viewpoint | Camera-specific projection/occlusion rule | Illusion breaks from an ordinary approach angle |
| Recursive room | Door appears to lead to a copy of the room | Instanced room with bounded recursion and unique identity | Infinite rendering or unbounded traversal |

These are **design patterns for a game world**, not claims about physical
architecture. They derive from BrickWild's plan-first and QA approach, and from
portal and virtual-environment research. A portal demonstration uses paired
cameras and a viewport texture, while research on redirected walking and
change blindness shows that perceived space can differ from the underlying
walk space. See [Godot Portal Demo](https://github.com/io12/godot-portal-demo),
[Redirected Walking in Infinite Virtual Indoor Environment](https://arxiv.org/abs/2212.13733),
and [Godot Viewport](https://docs.godotengine.org/en/4.5/classes/class_viewport.html).

## 2. Keep three models separate

**Semantic graph.** Rooms, floors, thresholds, portals, destination links,
ownership, quest locks, and active building state. Use stable IDs such as
`citadel/west_tower/level_3/door_2`; do not infer identity from position.

**Physical cells.** Every traversable room has its own local geometry,
collision, navigation and gravity frame. Cells may be placed far apart in
engine coordinates even when they look adjacent, or overlap in engine
coordinates while remaining separate worlds. A portal edge carries a
transform from source frame to destination frame.

**Presentation.** Exterior shell, portal view, occluder, light, sound,
weather, and map representation. The presentation can hide a cut or sell an
illusion, but it must represent the same active semantic state as collision
and navigation.

For each threshold, record at least `source_cell`, `destination_cell`,
`source_frame`, `destination_frame`, `usable_width`, `one_way`, `state_gate`,
and `render_mode`. Define how position, facing, velocity, gravity, camera,
held objects, sound, and AI path state transform through it. A simple door
is the identity case; a portal is the general case.

## 3. Three implementation families

### A. Visually impossible, physically ordinary

Use a continuous walkable mesh and bend, hide, or reshape it visually.
Floating masses can have magical support with no visible column. A forced
perspective hallway can compress or expand objects while its collision path
remains conventional. A roof may fold into itself above the player's reach.
This is the cheapest technique and preserves ordinary navigation.

Even here, write the exception into the plan. BrickWild's grounded-mass check
should accept a named `levitation_field` or `magic_anchor` relation instead of
silencing support checks for every building. Ask the generator to provide a
readable visual cue: runes, chains, a beam, a levitating shadow, or a break in
falling debris. The cue is a composition rule, not a physics proof.

### B. Discontinuous space behind a threshold

Build an exterior shell and an independent interior cell. Crossing the door
maps the player to the cell; the reverse threshold maps back. This supports a
larger interior, an underground refuge, or a tower whose rooms are farther
apart than its facade. The room graph includes portal edges; the world-space
AABB of the facade says nothing about interior capacity.

For a live view through the threshold, render the destination with a paired
camera into a texture. The [MIT-licensed Godot Portal Demo](https://github.com/io12/godot-portal-demo)
shows that basic approach and explicitly lists seams, clipping, lighting,
physics, and performance problems. It is an older reference to study, not a
drop-in Godot 4.5 component. Bound portal recursion depth and render-target
resolution, and use a static/occluded door treatment when a live view is not
needed. The [Godot Viewport](https://docs.godotengine.org/en/4.5/classes/class_viewport.html)
API provides the separate view/render target primitive.

### C. State-dependent topology

Use a finite set of authored or generated cell graphs. A moving stair changes
which two landings connect; a castle rotates a wing; a loop corridor selects a
different next node after each traversal. Evaluate the active graph as one
transaction: close old edges, move or swap geometry, update navigation and
collision, then open new edges. Preserve an escape route or make entrapment an
explicit authored challenge.

For a recursive room, instantiate a finite sequence of cells with stable
instance IDs. The visual pattern may repeat indefinitely, while the playable
graph has a cap or a rule that exits after a measurable event. Never recurse
the scene graph or camera rendering without a limit.

## 4. Generation recipe

1. Pick one impossible premise and one *legibility anchor*: door frame,
   central stair, distant landmark, color shift, gravity indicator, or sound.
2. Generate a normal semantic programme for the building: purpose, required
   rooms, service spaces, goals, entrances, and emergency return route.
3. Place a conventional graph of cells. Mark exactly which edges break
   ordinary embedding; keep the rest familiar so the trick has contrast.
4. Assign each exceptional edge a transform and presentation mode. Generate
   local meshes, collision, nav, and audio for every cell.
5. Compose exterior and interior appearances independently, while sharing
   semantic features such as entrance count, heraldry, and story state.
6. Run hard checks: every required room reachable in the intended states,
   all transitions reversible where required, no arrival inside collision,
   enough standing room after crossing, and bounded rendering cost.
7. Capture views before and after each threshold and inspect whether the
   impossible premise is visible and understandable.

## 5. Worked generator sketches

**Floating monastery.** Make a court-and-cloister plan first. Split it into
three floating platforms connected by bridges, mark all three as supported by
a common magical anchor, and let only the central platform carry a tall
landmark. The nav check tests each bridge and the escape route. The visual
check requires visible air below each platform, bridge attachment at actual
edges, and a consistent magical cue. Do not let a giant AABB bridge a gap in
QA that the emitted triangles leave open.

**Pocket inn.** Place a small exterior on a street lot. The entrance portal
leads to a larger hall, and upstairs doors lead to separate lodging cells.
The exterior lot check uses the true exterior porch and door; the interior
furnishing and walk checks use each interior cell. The inn's map shows a
threshold symbol instead of pretending that the hall fits the lot. Test
returning to the same street door, including when the inn has been regenerated
from the same seed.

**Looping archive.** Generate four ordinary library rooms and a ring corridor.
After the player reads a clue, one corridor edge switches destination from
room 2 to room 4. The graph change is recorded as an explicit state event.
Test both graph states, including an AI route, a carried object, sound, and
save/load at the threshold.

## 6. QA matrix

| Layer | Evidence |
|---|---|
| Plan | Reachable mandatory rooms; state-specific connectivity; bounded cycles |
| Mesh | Portal aperture is truly open; floor exists at arrival; no exposed cut surfaces |
| Collision | Entrance and exit clearances; moving geometry cannot crush an occupant |
| Navigation | AI and player use the same active portal graph; transformed arrival point valid |
| Rendering | Correct destination frame, clipping, recursion cap, and no impossible leak around portal edge |
| Story/UI | Maps, labels, quest triggers, saves, and audio identify the intended cell |
| Art | The trick reads from normal player approach distances and has a stable visual cue |

The chapter's governing rule is: **break one spatial law deliberately and keep
the rest of the building's promises measurable.**

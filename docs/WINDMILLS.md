# Windmills

A windmill is not one building. It is at least five, and what separates them is
not size or ornament -- it is **which part turns**:

| type | what turns | what it stands on | rotor |
|---|---|---|---|
| `tower` | the cap, on a curb | the ground | four sails on a stage |
| `smock` | the cap | a low brick stump | four sails on a stage |
| `post` | **the whole body** | a mound, or a timber trestle | four or six sails |
| `windpump` | **the whole head** | a lattice tower | 16 to 24 pitched blades |
| `paddle` | nothing — water does | the ground, in its own race | an undershot scoop wheel |

All five answer to the same three numbers, and all five are the same machine
seen from a different century. That is why this is one family rather than five
kinds: `style` picks which one, and the vocabulary of a windmill does not change
when you cross the Atlantic or the North Sea.

## The three numbers

They are the request's own `width`, `length` and `height`, and
`BrickWild.describe_kind(&"windmill")` says what they mean:

- **sail span** (`width`, 2.5–20 m) — the rotor's diameter, tip to tip. A sail
  span on a tower mill, a fan diameter on a windpump, the wheel across a polder
  mill. Each family keeps the same number and means something native by it.
- **body** (`length`, 2.0–10.0 m) — the body's own width outside face to
  outside face. A tower's base diameter, a post mill's burr, a windpump's leg
  spread.
- **tower height** (`height`, 3–24 m) — how tall the mill stands.

They are **clamped, not obeyed**. `WindmillGeometry.legal()` takes the number
the caller gave and answers with the largest one that type can actually be built
as: a windpump asked for a twenty-metre sail span is answered with a fan it can
turn, and the row in `BuildingLibrary.KIND_ROWS` says so with `"clamps": true`.
The clamp always lands inside the published envelope, which is what
`libraryquick` checks.

## The constraints a miller actually solved

These are not style rules. They are why a mill of a given size is the shape it
is, and the generator solves each of them rather than hoping the caller's
numbers happened to satisfy them.

**The rotor clears the ground.** `TIP_CLEAR` is 0.6 m, measured from the
top of the mound under a post mill — so a mill whose sails would drag in the
grass is not built. This is the rule that decides how tall a post mill's post
is: `WindmillGeometry.required_floor_y()` solves for the burr's own floor.

**The sail plane stands in front of the cap.** `CAP_CLEAR` is 0.35 m. A windshaft
emerges from the cap's front wall and the stocks go on from there, so a mill whose
sail circle ran *inside* its own cap could not turn at all. This is what fixes
the stage, and therefore the whole upper silhouette.

**A person can walk in.** The first four constraints are the miller's; this one
is the visitor's, and it was missing until the 26 Oct walk. A door is a hole in
a wall, not a rectangle painted on one, and the way up to it is treads a person
steps. So: a tower, smock or polder mill's door is CUT (`_cut_drum` leaves the
door's face out of the lower band of wall and closes it with jamb and lintel
panels), the leaf stands open inside, and the smock's door is at the foot of its
stump (`STUMP_H` is 2.7-3.4 m, taller than the door; the miller's floor is the
ground) rather than three metres up on the frame. A polder mill's wheel and race
are BEHIND it (`wheel_axle`, `race_rect`, `race_site`), because they stood in
front of the door and a wheel is not a thing to walk through. A windpump has no
door: a door in an open lattice is a door a walker walks round.

**The post mill's stair runs along the wall, between the wall and the sails.**
The old stock ladder was drawn in the world's frame while the burr stood turned
off it, so it never met the door. Now the door is in the front wall's middle, a
1.2 m landing stands level with the sill, and a straight flight (`STAIR_RISE`
0.2, `STAIR_TREAD` 0.3, 1 m wide with a rail each side) leaves the landing's edge
along the wall towards whichever side leads away from the sail plane
(`stair_dir`). `DOOR_STEP_REACH` (1.45 m) keeps the sail plane past the landing
and rail, so nothing of the stair is ever in the rotor's path. Its length
follows from how high the floor stands, so a tall post is a long stair, not a
steep one. There is no stage on a post mill (the deck stood where the landing
is), no trestle (its legs stand where the flight runs) and the burr is turned at
most 0.22 rad off the axis, so the door is still on the footprint's -Z edge the
placement contract names. The stair is published beside the placement
(`stair_site`), as the polder mill's race is.

**Why the ladder was off the axis.** A post mill's stock ladder was off the
axis because a ladder under the sails is a ladder the miller cannot climb — and
that is also why a post mill's **door** is off the axis. The door follows the
ladder; the ladder follows the sails.

**An undershot wheel stands in water and off the bed.** A polder mill's wheel
dips its buckets into the flow, because the current is what pushes them round.

**The tail is what turns it.** A cap mill's tailpole carries a fantail, which
walks the cap round into the wind by itself; a post mill's carries a great
wheel, which turns the post's pinion and so turns the whole body.

## Layout

- `src/windmill/windmill_spec.gd` — the spec and `TYPES`, the five rows with the
  bands each is held to and its own palette.
- `src/windmill/windmill_geometry.gd` — every dimension, as pure functions. The
  single source of truth: the generator clamps against it, the builder draws it,
  the check measures the mesh against it.
- `src/windmill/windmill_generator.gd` — a seed and a type, in a fixed order, so
  a mill is the same mill twice.
- `src/windmill/windmill_builder.gd` — the mesh, and the `mass_log` /
  `component_log` rows the checks read.
- `src/windmill/windmill_assembler.gd` — materials, at the very end.
- `qa/windmill_check.gd` — twelve rules, all measured against the emitted mesh.
- `tests/suites/windmill_suite.gd` — `lane:windmill`.
- `tools/render_windmills.gd` — one portrait per type, through the public path.

## Five surfaces, and why

| slot | what it is |
|---|---|
| 0 `SURF_WALL` | masonry, weatherboarding, lattice, the body |
| 1 `SURF_TRIM` | iron: gearing, wheels, the frame of every sail |
| 2 `SURF_SAIL` | cloth, thatch, and any painted panel that catches wind |
| 3 `SURF_DARK` | doorways, window slits, the dark inside |
| 4 `SURF_WATER` | the race a polder mill turns in |

Four is the contract nearly every other family keeps, and this one has five
deliberately: a windmill has iron in it, and iron is not the colour of anything
else on the building. Folding it into "trim" dressed the whole gearing as
straw. Water is **last** on purpose — a mill with no race leaves an empty
*trailing* surface, which moves nothing, where a hole in the middle would shift
every later slot and break the component log's surface indices against the mesh.

## Rules in `WindmillCheck`

Each is a statement somebody who has looked at windmills would make out loud:

- `standing` — it stands on the ground, and it stands on something. A polder
  mill's race is a channel *cut into* the ground, so its footing is the bed.
- `rotor` — the drawn tips reach the span asked for, and the number of sails
  drawn is the number the spec promised.
- `clearance` — the rotor clears the ground it sweeps over. THE rule.
- `cap_clear` — the sail plane stands in front of the cap, and nothing of the
  cap crosses that plane in the mesh.
- `winding` — something reaches out behind the mill to turn it; a post mill's
  tail carries the wheel that does the turning; a fantail mill drew a fantail.
- `access` — a post mill's stair is a stair: a landing level with the sill,
  risers at most 0.23 m, treads at least 0.25 m deep, 0.9 m wide.
- `entry` — a person walks in. `WindmillGeometry.approach_path` names the way
  (from the ground outside, over the sill, into the room; a post mill's from the
  stair's foot) and the check walks it on the drawn mesh, on three lines (the
  middle and 0.3 m either side): each step up at most the walk rig's 0.4 m, a
  body's height of air above, nothing across the line, and the walk ends on the
  miller's floor. `faulty_windmill_entry_builder.gd` (a doorway left uncut, a
  stair without treads) is the failing control, driven from the `wwalk` suite,
  which also walks seed 1 of all five types. Why the room checks never saw it:
  `wwalk` measured the published room and `access` measured the ladder's
  bounding box; nothing walked from the ground to the room.
- `gear` — a windpump's rod runs from its crank down to its pump.
- `wheel` — a polder mill's wheel stands in its own water and off its own bed.
- `swept` — the DISC the rotor sweeps (radius `sail_r`, as thick as the sails,
  plus 0.2 m each way) holds no wall, door step, rail, deck, lattice leg or
  boom. Only the shaft, gear and rod that drive it may reach in. Boxes are
  sampled through their volume, the drum through `radius_at`. The stage's rail
  stands `STAGE_SETBACK` behind the sail plane; a post mill's plane stands past
  its yawed burr's corner (`burr_front`); a windpump's fan is carried forward
  of the lattice (`fan_reach`). `faulty_windmill_rotor_builder.gd` is the
  failing control.
- `envelope`, `solid`, `facing`, `component` — the shared four.

Two measurement notes, because they are the difference between a check and a
tautology:

- **The rotor is measured off the component log, not off a whole surface.** A
  mill's cap and its sails share `SURF_SAIL`, so a surface-wide maximum measures
  the cap and calls it a sail. `WindmillCheck.rotor_points()` takes the cloth's
  own polygon for a mill, the blades' corners for a windpump, and the wheel mass
  for a polder mill — and `ComponentCheck` proves every one of those rows is in
  the mesh.
- **Every union of logged volumes starts from a flag, not from `AABB()`.**
  `AABB.merge` takes the union of two boxes and an empty box still sits at the
  *origin*, so `var out := AABB(); out = out.merge(box)` drags every result back
  to zero. It cost an afternoon and it will cost the next person an afternoon.

## What the harness does not check

A mill's interior is a round empty drum with a windshaft through it, so
`WindmillAssembler.build()` takes no `cutaway`: hiding the cap would show a
miller a hole, not a room. Everything above the assembler works in metres and
never loads a model, so the whole suite runs headless in milliseconds a mill.

Silhouette is the one thing a headless check cannot read, which is what
`tools/render_windmills.gd` is for:

```
godot --path . --script res://tools/render_windmills.gd
```

→ `artifacts/renders/windmills/`, a portrait per type plus rear views (the tail
and fantail are behind the mill) and two close-ups (a windpump's head, a polder
mill's wheel).
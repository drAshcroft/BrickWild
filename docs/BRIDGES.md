# Bridges

The ninth generator, and the first one whose subject is not a thing.

Everything else in this repository builds an OBJECT: a church, a castle, a
house, a tree, a temple. A bridge is a **length of deck with a bank at each
end**, and almost every question worth asking about one is a question about
the relationship between the structure and a site the structure does not own.
Does it meet the ground? Is anything holding up the middle? Is the water
between the piers still water?

So the site is **in the spec**. `span`, `bank_height` and `bank_run` are chosen
by a caller, `BridgeGeometry.bank_height_at()` is the single source of truth
for the ground, and the abutments' footings, the render tool's terrain and
every QA rule read that one function. A bridge whose feet do not match the
ground it is drawn against is a bridge drawn on a picture of a bridge — and
because the site is built from the same function, that defect is invisible in a
render, which is exactly why it needs a rule instead.

```
BridgeSpec ──▶ BridgeGenerator ──▶ BridgeBuilder ──▶ ArrayMesh ──▶ BridgeAssembler
               decides           pure fn        4 surfaces      materials, lamps
               (kind, span,      of the        stone/timber/    + the SITE
                width,           spec           deck/metal
                deck, seed)              ▲
                        │                │
                  BridgeGeometry ────────┘  and qa/bridge_check.gd
                  the massing,            the ten rules
                  the ground, the
                  cables, the arches
```

Same three-part contract as every other family. The generator decides and
writes down, as DATA, the piers, the deck and — the part that matters —
**the x RANGE every member is responsible for holding up**. The builder only
emits, and the check reads the same lists.

---

## 1. The four kinds

They are four different **structures**, not four skins. Each is judged in
profile, because a bridge is.

### stone

A row of masonry arches on battered piers. The load goes sideways into
compression and down into the ground, and the whole point of the kind is that
you can see that happening from the bank.

The load path is the *reason* the family is called a bridge family: an arch
carries its load by pushing DOWN AND OUT along its own curve, which is why an
arch bridge needs nothing under its middle and a beam bridge needs something
every few metres. The three details that make it read:

- **The arch is a semicircle, so it is vertical at the springing and horizontal
  at the crown** — and it rises `clear_span / 2` above the springing. That is
  why a masonry arch bridge's roadway humps and a beam bridge's does not, and
  `camber` is the generator writing that down.
- **The springing is DERIVED from the arch**, not authored. Choose it
  independently and a 4.6 m arch on a 3.4 m springing comes up *through* the
  deck: the first render pass produced a fan of voussoirs standing on top of
  the bridge like a crown.
- **The ring is cut into VOUSSOIRS with mortar joints between them**, each a
  little deeper at the crown than at the springing. A smooth band along the
  same semicircle is a tunnel roof. The joints are the whole difference.

Plus a string course that PROJECTS past the wall face (a horizontal is what
masonry is for), a coping that overhangs so the top of a pier catches a
shadow, a cutwater on every pier standing in water, and a parapet pierced with
narrow lights and finished with a coping that catches light from above.

The piers are **not evenly spaced** — the seed jitters them by a few per cent
of a bay, which reads as masonry cut by different masons and is the only
continuous seed variation in the family. Six seeds of a stone bridge give six
different bridges.

### covered

A masonry abutment at each end, a timber deck between, and a gabled roof over
the whole thing on posts and side beams. It is a timber bridge with stone ends,
and the roof is half the silhouette.

The posts and the roof are drawn on **one bay rhythm**, because a covered
bridge whose posts do not line up with its rafters is a shed with a fence
under it. Closed wall panels between the posts, a hand rail at head height,
gable ends closing the triangle over each abutment.

It is also the only kind that carries **lamps** — two at the ends, through
`LightKit` like every other light in the project — because a covered bridge is
a roof over a deck and a lantern at each end is the only reason anybody ever
sees one at night. `BridgeCheck.LANTERN` fails a covered bridge with no
lantern, which is a sentence that sounds silly until you have looked at a lit
bridge and an unlit one.

### rope

Two towers, a main cable over each handrail, hangers down to the deck at
every pitch, backstays to the anchorages, and a rail.

Two things about it are worth knowing before writing it:

**The cable is a PARABOLA and not a catenary.** A catenary is the true curve
of a loose chain; a bridge cable is tensioned to a chosen sag against a chosen
deck load, and what comes out is a parabola. Draw the true catenary and the
cable bottoms out off midspan, the hangers on one side go slack, and the whole
thing reads as a rope bridge with a rope bridge's slack in it. The reason is
written on `BridgeGeometry.cable_height_at()`.

**The towers stand AT the abutment line, not inboard of it.** The cable sags
to midspan and rises to the tower tops, so a tower halfway along the span is
standing where the cable is already at its lowest. The first render pass
produced a suspension bridge with no towers on it at all — a catenary between
two thin air columns.

The towers lean **in**, because a tower that leans out is a pylon and a tower
that stands dead straight is a mast, and the lean is what says *it holds
something up*.

### mobile

A span that MOVES, in four mechanisms, because the mechanism is the building:

| motion | what it is | what says so |
|---|---|---|
| `lift` | a span that rises in a pair of towers | the ropes down each tower and the beam across the top |
| `swing` | a span that rotates on a pivot pier | the pivot drum and the boom standing at the angle it is drawn open to |
| `pontoon` | a raft on floats | the floats under the deck, at their draught |
| `drawbridge` | a leaf hinged at one abutment | the counterweight backstay and the chain |

All four are drawn in the **open** position, which is the one that has to be
interesting, and the reach is seed-jittered, because a bridge that always
opens the same distance is a stamp with a lever on it.

---

## 2. The clearance contract — and this family's own version of it

The trees' lesson, applied at the first attempt rather than the six-hundredth:

> **An envelope is a post-condition of a builder, not a prediction of a
> generator.**

`BridgeGeometry.expected_extent()` is the box the spec promises, and
`fit_mesh()` corrects the finished mesh into it. Three things had to be got
right, and all three are the same mistake wearing different clothes:

1. **The fit aims AT the box, and the rule's tolerance sits on top of it.**
   Aiming the fit at `box × (1 + allowance)` while the rule allows
   `box × (1 + smaller)` is a builder shipping geometry its own check rejects.
2. **The fit scales about the BOX's centre, not the mesh's.** Scaling about the
   mesh's own middle makes it the right *size* and leaves it in the wrong
   *place*, and a bridge that is exactly as tall as its box and sitting three
   metres low is untouched by a size-only fit.
3. **The fit SEATS as well as scales.** On a clamped axis the scaled mesh is
   moved so its minimum lands on the box's minimum, because a bridge sits *on*
   its site rather than floating in the middle of the room the box makes for it.

And the box has to know what the kind *is*:

- a **covered** bridge's box reaches its ridge, not its deck, or it cuts off the
  one thing anybody came to look at — the first pass failed every tall covered
  bridge for having a perfectly good roof on it;
- a **pontoon's** box reaches under the water for its draught;
- **every** bridge's box reaches below the waterline, because a pier is carried
  down and an abutment is carried into the bank, and a box that stops at the
  surface fails every bridge in the family for the one thing they all do;
- the box is **longer than the span**, because the wing walls splay back into
  the bank and are legitimately longer than the crossing they carry.

---

## 3. The ten rules

`qa/bridge_check.gd`. Each is a statement somebody who has looked at bridges
would make out loud.

| rule | what it asks | what it caught |
|---|---|---|
| `SPAN` | the deck runs the whole way, with no hole in it | the deck's length, not the mesh's — the wing walls are longer than the span and crediting the bridge with reaching further than it does |
| `LEVEL` | the deck is where the profile says, at every station | a camber applied to some slabs and not others |
| `SUPPORTED` | **every station of the deck has something under it** | a deck that touches both abutments and nothing between — a plank with ambition, invisible from the bank |
| `ABUTMENT` | both ends land in the bank, against `bank_height_at` | — |
| `CHANNEL` | the widest gap between supports is open | a pier on the centreline counted as a pier on *both* banks, closing every channel in the family |
| `ENVELOPE` | the mesh is inside the promised box | see §2 |
| `SOLID` | at most four surfaces, no zero-area triangles | — |
| `FACING` | every triangle winds the way its own normal says | — |
| `MECHANISM` | a movable bridge carries a mechanism, and the right one | — |
| `LANTERN` | a covered bridge has lamps; nothing else does | — |

**`SUPPORTED` is the rule this family exists for.** The spec's members each
declare the x range they are responsible for, the check unions them and looks
for a gap. It is measured on the union rather than on the picture because a
ten-metre cantilever looks *exactly* like a supported span from the far bank.

**`CHANNEL` needed the two mistakes written down**, because they produce the
same wrong answer — zero — from opposite causes. Measuring it from the
centreline treats a single mid-river pier as a pier on both banks at once.
Leaving the abutments out of the face list gives a one-arch bridge a single
face and therefore no gap. The right question is the widest gap between the
inner faces of two supports, with the abutments as the outer boundary.

---

## 4. What the first render pass found

The images in `artifacts/bridge_renders/` are the evidence, and two of the
findings were about the tool rather than the bridges — which is worth saying,
because both would have been attributed to the geometry.

**A bridge runs along X, so its profile is a shot from ±Z.** Every first-pass
shot used yaw π/2, which is a shot from ±X — down the END of the span — and
that puts the near bank between the camera and the subject. The tool
photographed terrain with a bridge in the middle distance, thirteen times in a
row, and it looked like a modelling failure. `tools/render_bridges.gd` now says
so at the top of the file.

**A site built as a stack of boxes stepping down reads as a ziggurat.** Not a
matter of taste — that is what a staircase looks like, and a bridge on one is
a bridge on a Mayan pyramid. The site is now five solids: a flat top each side,
**one sloped slab** rotated to the batter, and a flat bed. The slope and the
abutment footings agree because they are both `bank_height_at`.

**The voussoirs were lying flat.** Their depth was measured across the channel
instead of radially, so each block sat like a louvre blade and the arch read
as a fan of plates. A voussoir's depth runs along the arch's own normal,
pointing at the centre of the ring; that is the whole difference.

**The arch crown came up through the deck** — see §1, `stone`.

**The suspension bridge had no towers** — see §1, `rope`.

---

## 5. The suite

```
godot --headless --path . --script res://tests/run_all.gd -- lane:bridge
```

`tests/suites/bridge_suite.gd` — 218 checks, and the ones a per-bridge check has
no business holding:

- **PURITY.** Two builds of one spec produce identical vertex arrays, on every
  surface, and a reused builder does not accumulate between calls.
- **FEET.** The abutments land in the bank, measured against the same function
  the site is built from. This is the contract no other family in the
  repository has, and it is the one this family most needs.
- **VARIETY.** Six seeds, four kinds, on a **positional checksum** of the
  vertices rather than a triangle count — a pier moved forty centimetres
  changes where everything is and changes nothing about how many triangles
  there are, and keying on counts called six seeds of a stone bridge one
  bridge. The bar is four of six, and the reason is written down: two of the
  four kinds vary over a small DISCRETE set (a covered bridge's bay count, a
  mobile bridge's four mechanisms) and two seeds landing on the same one is the
  size of the set, not a stamp. The kind that varies *continuously* is the
  stone bridge, and that one gives six of six.

## 6. Renders

```
godot --path . --script res://tools/render_bridges.gd     # NOT headless
```

Fifteen images to `artifacts/bridge_renders/` with a `manifest.json`: each kind
in three-quarter and in **profile**, the four mobile mechanisms in profile, and
a size sweep from a 9 m footbridge to a 180 m gorge crossing.

## 7. What is not here yet

- **No traffic.** A bridge with nobody on it is a diagram; the town that
  needed it is in `VillagePlan` already.
- **No water.** The site draws a flat plane at the waterline. The river the
  bridge crosses does not run under it.
- **No masonry course, no timber grain.** Flat albedo plus the envelope fit, and
  the houses already ship a slate/thatch course shader.
- **Not placed in a world.** `BridgeAssembler.build()` returns a self-contained
  node with its own site, which is exactly what a caller wants and is not the
  same as a bridge in a landscape with a road leading onto it. That join is
  where `WorldFamilies` would want it.
- **The covered kind's roof has no ridge tiles, finials or bargeboards**, and
  the stone kind's parapet has no refuges — the cutwater detail has no
  parapet equivalent above it yet.

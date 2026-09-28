# Trees

The eighth generator, and the first one made of nothing but a seed.

Everything else in this repository builds a thing whose parts are known: a
church has a nave and an apse, a castle has a curtain and a gatehouse, a house
has rooms. A tree has none of that. It is a trunk, some branches, and a
crown — and all three are decisions, every time, from a number. That is why it
was worth writing, and why the harness for it is about *proportion* rather than
about presence.

Until now the project's plants were a **model library**: 104 `.gltf` files in
`assets/props/nature/` and `assets/props/wild/`, measured once by
`tools/build_prop_catalog.gd` into `assets/props/catalog.json` and re-measured by
`tests/suites/house_assets_suite.gd`. That library is not going anywhere, and a
village still draws its edge from it. What is new is that you can now *ask for
a tree* — a 22 m spruce, a flat acacia, a weeping willow — and get a different
one back for a different seed, with no file on disk.

```
TreeSpec ──▶ TreeGenerator ──▶ TreeBuilder ──▶ ArrayMesh ──▶ TreeAssembler ──▶ Node3D
             decides           pure fn        4 surfaces      materials
             (style,          of the         bark/leaf/      + glow
              species,        spec           accent/glow     lights
              height, seed)
                    │              ▲
                    │              │
              TreeGeometry ─────────┘  and qa/tree_check.gd
              the maths, shared        the ten rules
```

Same three-part contract as `ChurchGenerator` / `ChurchGeometry` /
`ChurchBuilder`, and for the same reason: a builder that re-rolls a die while
emitting blinds the checks to precisely the cases that forced the roll. So the
crown is not "some blobs" by the time the builder runs — it is `spec.lobes`,
a list of `{pos, radius, squash, kind}` the generator wrote, and `spec.branches`
a list of `{from, to, r0, r1, level, phyl}` likewise. The voxel stamper, the
indie prisms, the natural tubes, the six magic emitters and all ten QA rules
read those two lists. There is exactly one tree per
`(style, species, height, seed)`, and everybody agrees on what it is.

---

## 1. The four styles

They are four different **algorithms**, not four palettes on one shape. A reskin
of one tree four times is not a tree family, and the first render pass proved
it: three styles, one silhouette, three flat slabs on a stick.

| style | the algorithm | what it is for |
|---|---|---|
| `voxel` | a cubic grid, stamped and greedy-meshed | the Minecraft look, and the cheapest tree to draw a hundred of |
| `indie` | 6-sided tapered tubes, golden-angle forks, faceted clumps | reads at 60 px and at 6 m; the style a stylised game wants |
| `natural` | an L-system-ish skeleton with taper and tropism, 3–4 concentric crown shells | what a village or a forest wants |
| `magic` | six named supernaturals, each a different SILHOUETTE | the ones a fantasy author asks for by name |

### voxel

Bark and leaves are **cell materials**, not separate meshes. A voxel dictionary
maps `Vector3i → surface index`; a face is emitted where a solid cell meets air
*or meets a different material*; coplanar runs of the same material are then
merged into single quads by `TreeShapes.voxel()`.

The merge is the point but not the whole of it, and the honest figure is worth
stating because the obvious one is a lie. A 20 m voxel oak is around 1,900
cells; unmerged those would be 5,100 faces with roughly half of them interior
ones you can see straight through. Greedy merging lands at about **0.32 of the
unmerged count** — a saving of 68%. The reason it is not 0.05 is structural: on
a curved surface every row of a slice has a different extent, so a run almost
never extends downward. A solid ball of the same envelope only reaches 0.41.
`tree_suite.gd` holds it to a floor a curved surface can actually reach.

Foliage gets a per-cell value jitter from `TreeShapes.cell_hash()`. That is not
decoration: the mesher writes no vertex colour, and a solid green block is the
single cheapest tell there is.

### indie

A 6-sided tapered stem with a per-node radius wobble, 6-sided level-0 forks,
5-sided tips, and `rings = 2, segs = 7` ellipsoid clumps individually rotated by
a hash of their position so no two line up. A conifer's skirts are drawn flat;
an oak's are drawn round. It has to read at sixty pixels and at six metres, and
those two scales want different facet counts from the same primitive.

### natural

A 7-sided stem, every branch drawn as two spans sampled from
`TreeGeometry.branch_radius_at()`, and a crown built from **three or four
concentric ellipsoid shells per lobe** — the outer at full radius, the inner
smaller, lifted and rotated. One ball of foliage reads as a lollipop; three
shells read as depth.

Branches leave the trunk at the **golden angle** (137.5°), never evenly spaced.
Even spacing is instantly readable as a manufactured object; it is the
difference between a tree and a Christmas tree.

### magic

Six emitters, because a magic family that is six tints of one silhouette is six
colours and not six trees. Each is named in `TreeGeometry.MAGIC_TITLES` and
gets its own silhouette:

| species | what makes it itself |
|---|---|
| `worldtree` | colossal, and BUTTRESSED — seven to nine splayed limbs off the trunk shoulder, each running out and then down to a flat ankle on the earth |
| `crystal` | prismatic: hex prisms, shard clusters at every tip, no wood anywhere, a rune circle on the ground |
| `inverted` | the crown points at the sky and the root mass hangs; it is still rooted, and that is the joke |
| `floating` | a rock island in the air with vines under it, and it does not touch down |
| `weeping` | a dome from which fourteen to twenty-two strands fall; the strands *are* it |
| `ember` | bare and burning: charred spurs, coal tips, rising embers, and no leaf surface at all |

Each writes at least one `spec.glow` entry, and `TreeCheck.GLOW` holds a
magical tree to lighting itself. A coloured tree that emits no light is a failed
magic tree even when it is a beautiful one.

---

## 2. The species

Twenty-four, six per style, in `TreeGenerator.STYLES`. Every proportion is a
fraction of `spec.height`, so a 4 m hedge tree and a 40 m veteran are the same
tree at two sizes.

The one number that does the most work is **`lobe_h`**, the crown's
height-to-radius ratio, and it is the entire silhouette:

| | `lobe_h` | what it makes |
|---|---|---|
| palm | 0.30 | a shrapnel burst on a bare stick |
| acacia | 0.42 | flat and wide |
| oak | 0.80–0.85 | a squat ball |
| poplar | 1.85 | a tall spindle |
| spruce, pine | 1.95–2.20 | a cone |

`squash` **multiplies**: a lobe's true half-height is `radius * squash`, which
is what `TreeGeometry.in_lobe()` computes. It divided, once, in `_lobe_top()`,
so the crown was fitted against an envelope twice the wrong size.

---

## 3. The clearance contract — and why it is the load-bearing one

`SceneBounds.plant_of_node()` already computes a pair of radii for the 104
**imported** plants in `catalog.json`:

- **canopy** — the furthest any vertex reaches from the plant's own vertical
  axis. This is what must not hang over a roof.
- **trunk** — the same measure at or below `TRUNK_HEIGHT` (1.8 m). This is what
  must stay off a road.

`TreeGeometry.expected_radii()` returns the same two numbers for a **generated**
tree, from the spec alone, and `TreeCheck.CLEARANCE` holds the mesh against the
promise. That is the whole reason a generated tree can stand in a village beside
a loaded one: both answer `VillageDressCheck` the same question the same way,
and the clearance rules do not have to know which is which.

The direction matters and the rule is a **bound, not an equality**:

> fail when the tree reaches *further* than it promised — a crown over a roof,
> a trunk in a road. Warn when it reaches much *less* — the envelope was
> authored generously and nobody has tightened it.

Testing it for equality instead produced three hundred failures, all the same
shape: every species, every height, `canopy measures 4.09 m, the spec promised
3.60 m`. A promise is a bound on what a generator may do to the world, not a
measurement of what it did.

Three things claim the head-height band, and all three are in the promise:

1. **the root flare** — `trunk_radius * (1 + root_flare)`;
2. **the roots themselves** — `TreeGeometry.root_spread()`. They were not in the
   promise at all, and the first sweep measured 0.86 m against a promised
   0.34 m, entirely foot of splayed roots;
3. **for four of the six magic kinds, the crown** — a rune circle, a dome below
   the ground, a curtain that reaches it, vines under a floating island.
   `TreeGeometry.TRUNK_CLAIM` is what makes the promise true for those four
   instead of exempting them from the rule that holds every other tree.

---

## 4. The ten rules

`qa/tree_check.gd`. Each one is a statement a person would make out loud about a
tree, and each one has a reason it exists.

| rule | what it asks | what it caught |
|---|---|---|
| `ROOTED` | it meets the ground — or, for the one magic kind that floats, conspicuously does not | keyed on `style`, which for a magic tree is always `magic`, so the floating one was required to stand on the earth |
| `FITTED` | the crown stays inside the height the caller locked, and reaches it | a 12 m oak whose foliage stopped at 9.3 m |
| `CLEARANCE` | the mesh does not **exceed** the promised radii | 308 failures, all of them the equality-vs-bound mistake |
| `CROWN` | there is a crown, wider than the trunk, with depth | a tree with lobes on the spec and no foliage on the mesh |
| `SKELETON` | every **level-0** branch starts on the stem | checked child branches too, which leave the stem by definition — a rule asking whether a branch is a branch |
| `SUPPORTED` | voxel only: no leaf block with nothing under it | a voxel crown stamped in mid-air; the flood fill marks a clump carried if any of its cells is anchored |
| `SOLID` | at most four surfaces, no zero-area triangles, foliage where foliage is owed | a dead tree that emitted no leaf geometry |
| `FACING` | every triangle winds the way its own normal says it does | the quad emitters declared one normal and wound another |
| `GLOW` | a magical tree lights itself; an ordinary one does not | — |

**VARIETY is not in that list on purpose.** "A stand is not a clone stamp" is a
property of a *stand*, not of one tree: two builds of one spec are supposed to
be identical, so a per-tree version could only ever fail on its own subject. It
is `TreeCheck.stand_spread()`, called once per species by the suite.

It is measured as **distinctness**, not as a spread, and that took three tries.
A spread over height reports zero by construction — `_refit_crown` fits every
tree to the exact height it promised. A spread over the crown's depth reports
zero too, once the envelope fit below was added. A spread over a *digest* of
the branch and lobe coordinates converges on its own mean. What a generator
cannot normalise away is whether two seeds drew the **same tree**, so that is
what is counted: six seeds, and how many of them are distinct by triangle count
plus a positional checksum. A species is a stamp when fewer than five of six
are.

---

## 3a. The envelope is a post-condition, not a prediction

This is the single most important thing the harness taught, and it took a day
of 600 failures to arrive at.

`spec.canopy_radius` and `spec.trunk_clear` are **promises**, and for most of
the family's life they were kept by having the *generator* predict what each
emitter would draw. It cannot. A voxel cell's face sits half a block past the
lobe that filled it. A tube is wider than the segment's nominal radius. A
palm's leaf fill runs a cell long. A crystal's shard cluster grows past the lobe
it hangs on. A willow's lowest branch is inside the head-height band while its
trunk-clearance promise says it is not. Every one of those was a `CLEARANCE` or
`FITTED` failure on geometry that looked correct in the render.

So the prediction is replaced by a **correction**, and it lives on `TreeShapes`
so that both `TreeBuilder` and `TreeMagic` get it — a fit held in one builder and
not the other applies to three quarters of a family, which is exactly how the
crystal's trunk stayed a metre past its promise after the other three styles had
been fitted. After the mesh exists it is:

- lifted if its underside is below the ground clearance (only `floating` hangs);
- scaled about y = 0 if it overshoots the promised height;
- scaled about the trunk axis if it reaches further out than `canopy_radius`,
  and **separately** if it reaches further out at or below `TRUNK_HEIGHT` than
  `trunk_clear` — the two are different promises and a tree can be honest on one
  and over on the other.

Both corrections are uniform, so a tree that was already the right shape stays
the right shape: a two per cent squeeze is invisible, and it is only ever
applied to a tree that was genuinely over.

`TreeGeometry.DRAW_ALLOWANCE` (8%, plus half a voxel cell) is the margin the
lobes do not cover, and the **rule and the promise use the same one**. A rule
with one tolerance and a promise with another is a rule that fails on the
difference between them.

Two bugs in this mechanism are worth writing down, because both were silent:

- the trigger condition needs an **epsilon**. The mesh reaches the promised
  height to within a float epsilon, so `hi > height` was true by 1e-7, the
  correction fired on every tree, and the whole family came out as bonsai.
- the target needs **`(1.0 + allowance)`, not `allowance`**. Written as the
  bare allowance it aimed each crown at eight per cent of its height. The same
  line existed twice, once per builder, and both had to be found.

---

## 5. What the first render pass found, and what it cost

Twenty-four portraits plus a forest and a comparison row, from
`tools/render_trees.gd`. Reading them found more than the harness did.

**The crown was a stack of separate plates with sky between them.** Lobes were
sized for *packing* — `R / cbrt(n)` — and then drawn, so neighbouring clumps
just touched. The oak was three flat green slabs; the pine was five plates and a
floating cube. A crown has to **overlap**: a lobe's radius is about a quarter of
the whole crown, and the tips are pulled inward to make room, so
tip + clump still lands inside the envelope the spec promised. Sizing for
packing and drawing what you sized is the mistake.

**A leader lobe was the wrong tool for "the crown does not reach the top".** Put
on the stem's own top it is a single blob with a metre of daylight under it, and
pinned to the promised height it just moves the gap above the crown instead of
below. The real fix is that every branch tip lands at much the same height — the
branches leave the clear trunk with a small lift and stop when they have spent
their reach — so the crown is a thick disc floating a third of the way up a tall
tree. Scaling the tips' **heights** (never their radius, never their azimuth)
opens the crown into the full vertical space `canopy_base`/`height` allotted it.

**A conifer tip is a point, and that is a statement about the last tier only.**
Letting the taper run to 8% of the crown put the top three tiers inside one
another's width and every pine ended in a needle as thin as a pencil.

**Three winding bugs, all invisible from outside a solid.** Godot's front faces
are clockwise, so a triangle wound `(a,b,c)` has outward normal
`(c-a).cross(b-a)`. The quad emitters computed their normal one way and wound
another, so the declared normal and the actual winding disagreed — the geometry
rendered and the shading was inverted. The second was the **caps**: both caps of
a tube share one ring order, and reversing it for the near cap is the whole fix.
A short five-sided root is half caps, so a quarter of all bark triangles were
inside out.

**And one measurement bug that sent the winding hunt in a circle**: `FACING`
counted a near-vertical cap sitting on the axis as "inward". It is correct — it
points down, into the joint it shares with the next segment — and the axis test
has no opinion about up and down. Judging caps by a horizontal rule reported a
third of every trunk's triangles as broken and sent the rule after a bug that
was not there.

---

## 6. The suite

```
godot --headless --path . --script res://tests/run_all.gd -- lane:tree
```

`tests/suites/tree_suite.gd` sweeps **every species of every style, at three
heights, over three seeds** — 216 trees — and adds the four things a per-tree
check has no business holding:

- **PURITY.** Two builds of one spec produce identical vertex arrays, on every
  surface, and a reused `TreeBuilder` does not accumulate cells between calls.
- **MERGE.** The greedy mesher's own `{"cells", "raw", "emitted", "merged"}`,
  per species and height, held to a floor a curved surface can reach.
- **GRID.** Every vertex of a voxel tree lands on a multiple of `block` from the
  grid origin, and its foot lands on an exact multiple too — so two voxel trees
  side by side tile.
- **VARIETY.** Six seeds per species, measured once each.

Every species row is a real assertion. `TreeGenerator` falls back to the first
species of a style when it is handed a name it does not know, so a sweep over
the table is the only thing that notices a species that stopped existing.

---

## 7. Renders

```
godot --path . --script res://tools/render_trees.gd     # NOT headless
```

Twenty-six images to `artifacts/tree_renders/` with a `manifest.json`: one
portrait per species, a forty-tree wood, and a 24-specimen comparison row with
the silhouettes side by side at eye height.

The stage is `tools/render_shots.gd`'s, deliberately: the same SubViewport, the
same procedural sky, the same sun. Two things it is missing and the building
renders do not want are documented in `docs/VISUAL_QA.md` §4 — the key light
does not follow the camera, and there is no fog. Both are worth fixing here
too, in one pass, for every render in the project.

## 8. What is not here yet

- **No LOD.** One mesh per tree, one draw call each. The whole family is sized
  for a village's edge band, not for a wood you walk through. `docs/
  KNOWLEDGE_AUDIT_BUILDINGS_BIOMES_FORESTS.md` §`Procedural/forests` FO-04 is
  the right shape for when it arrives: a LOD band is a *coverage* band and its
  failure is invisible standing still.
- **No wind.** A tree is a static mesh. Vertex-shader sway keyed off
  `TreeShapes`' existing UVs is a day.
- **Not in the village yet.** `VillageDresser.PALETTES` still draws its edge
  from the imported library. `TreeAssembler.scatter()` is the seam: it is
  already the only way to plant a wood of N from one spec, and the fence row is
  a handful of lines in `village_dresser.gd`.
- **No bark or leaf material.** The trees use flat albedo plus a voxel vertex
  jitter, where the houses already ship a slate/thatch course shader. Carrying
  `ShellAssembler.house_materials`' approach across is the single biggest
  remaining visual win, and `docs/VISUAL_QA.md` §4 S3 says the same thing for
  the other families.

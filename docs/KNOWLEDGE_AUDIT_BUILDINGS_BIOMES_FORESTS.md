# Audit: `Procedural/buildings`, and the missing `biomes` and `forests` branches

All counts below are the state **before** the repairs this audit performed. After
them the store holds 1526 entries, `procedural/biomes` and `procedural/forests`
hold 10 each, `procedural/buildings/organic-mass` holds 7, the singular and
hyphenated roots are empty, and `source_repo_url` is populated on 9 entries
rather than none.
Date: 2026-09-26. Scope: the 61 entries under `procedural/building*` in the global
WaterFree store, this repository, and the prior art reachable for the gaps.

## 0. Verdict

- The branch is an **index, not a body of rules**. 28 of its 61 entries have prose
  context and no code, and that prose is one to three sentences pointing at
  `docs/WORLD_BUILDINGS.md`, `docs/PROCEDURAL_ARCHITECTURE_RULES.md` or
  `docs/PROCEDURAL_EXTERIOR_INTERIOR.md` plus a disclaimer. The retrieval unit is
  too coarse to answer a question.
- **Every form lesson is orthogonal.** All 27 form-class entries are about plan
  graphs, storey grids, room packing, circulation or emitted-mesh QA. Not one
  describes a massing surface that is not made of axis-aligned boxes, and the
  repository cannot emit one either.
- **The cosy organic village builder is a missing family, not a missing detail.**
  It is shipped as **Tiny Glade** (Steam app 2198150, Pounce Light, 23 Sep 2024);
  "Little Glade" was its earlier name and returns nothing on Steam's index. Five
  of its mechanisms — reactive assembly, support inference, hosted vegetation, a
  no-failure repair loop, gridless massing — have no entry and no code anywhere.
- **`Procedural/biomes` and `Procedural/forests` do not exist.** The knowledge
  does; it is filed under `simulation/worldgen`, `godot/voxelgames/*`,
  `gamedev/terrain/*`, `unity/environment/*`, `procedural/villages/landscape` and
  `procedural/dungeons/09-theme`. A search for "biome" in the branch a world
  builder would look in returns nothing.
- **The book promises a source per entry; the data has none.** `source_repo_url`
  is empty on 0 of 1499 entries store-wide. Three entries carry a DOI in prose.
- The taxonomy was broken in six places and is now repaired. `tools/reindex_procedural_knowledge.py`
  also listed one title that no longer exists, so it had never run clean; fixed.

## 1. Method and counts

Global store at `~/.waterfree/global/knowledge.db`, read-only. 1499 entries,
113 distinct hierarchy paths.

| Measure | Value |
|---|---|
| Entries under `procedural/building*` (before repair) | 61 |
| — under `procedural/buildings/` | 56 |
| — under `procedural/building/` (singular, orphaned) | 5 |
| Entries under `procedural/*` | 235 |
| Buildings share of `procedural/*` | 26.0% (dungeons take the other 44%) |
| Entries with `source_repo_url` | 0 / 1499 |
| Entries with context under 300 chars | 47 / 61 |
| Entries with both context and code | 23 / 61 |
| Entries sourced from this repo | 50 / 61 |
| Reindex candidates / changes / stale titles | 66 / 6 / 1 |

Branch shape, counted by mechanism rather than by title keyword:

| Mechanism | Entries |
|---|---|
| Plan graph, storey grid, room packing, circulation | 13 |
| Emitted-mesh QA of a form already chosen | 6 |
| Abstract composition / design-rule prose | 7 |
| Material and weather masks | 1 |
| Pipeline, RNG identity, transport, validation, performance, authoring, impossible | 34 |

## 2. Critique A — the branch stores pointers, not knowledge

Three form-class entries, verbatim context:

> `[procedural/buildings/families] Compose architecture from archetype, structure, and style`
> BrickWild survey: docs/WORLD_BUILDINGS.md, plus docs/CASTLES.md, docs/TEMPLES.md,
> docs/HOTELS.md. The survey is a generator design reference, not a claim of
> historical universality; verify cultural and period details with specialist
> sources before publication.

> `[procedural/buildings/composition] Compose site, mass, facade, and detail at separate scales`
> Design chapter: docs/PROCEDURAL_ARCHITECTURE_RULES.md. CGA's mass-to-facade-to-detail
> hierarchy is a useful research basis: https://doi.org/10.1145/1179352.1141931 .
> BrickWild examples: docs/CASTLES.md, docs/HOTELS.md and docs/ROOF_AUDIT.md.

> `[procedural/buildings/exteriors] Exterior weather and material masks follow exposure and use`
> Design chapter: docs/PROCEDURAL_EXTERIOR_INTERIOR.md. Keep UV scale and hard normals
> coherent across adjacent emitted components. This is an art-direction heuristic;
> environment and material palette may change the effect.

The rule is in the doc; the entry is a pointer plus a hedge. A search for
"how do I stop the facade reading as noise" returns a sentence that says the
answer is somewhere else. That is a worse outcome than no entry, because it
looks like a hit.

Three of these chapters are also **design essays, not descriptions of shipped
behaviour**, and the entries do not say so. `docs/PROCEDURAL_ARCHITECTURE_RULES.md`
§3 states that a building on a slope needs stairs descending in the correct
direction, and that a watermill needs a real water relationship rather than a
wheel prop on any wall. There is no height sampling in `src/` or `core/`; the
mill race does exist (`VillageWaterPlan.mill_race`) but the mill building is a
house fitted to measured walls. `docs/PROCEDURAL_IMPOSSIBLE_STRUCTURES.md` and
`docs/WORLD_BUILDINGS.md` are research inventories: `WorldFamilies.FAMILIES`
registers only `courtyard_house` and `timber_hall`, and `WorldFamilies.generate()`
returns `false` for everything else.

`docs/KNOWN_ISSUES.md` is stale in a way that matters: it describes
`src/building/building_spec.gd`, `spec_generator.gd`, `building_builder.gd`,
`main.gd` and `scenes/main.tscn` as a live draft. None of them exist; `scenes/`
holds only `studio.tscn`. Its remaining-duplication item is also resolved.

**Required shape for an entry**: claim, reason, failure mode, the evidence
command that could refute it, and a source. A chapter reference is a reading
list, not an entry.

## 3. Critique B — every form lesson is orthogonal, and so is the emitter

Grouping the 27 form-class entries by the mechanism they actually use:

| Mechanism | Entries |
|---|---|
| Plan graph / room packing / adjacency | courtyard ×2, timber hall ×2, temple columns, vertical storeys, shops, service compounds, plans, buildings-before-silhouette, site-adaptation, subtractive |
| Split grammar on an integer grid | facade split, CGA cumulative rounding |
| Emitted-mesh QA of a chosen form | castle facade bands, gothic clerestory, houses jetty, exterior↔interior promise, timber hall pond, composition scales |
| Material and weather masks | exteriors |
| Abstract prose | families, design-rules, interiors |

Every one is a plan, a grid, or a check. The repository agrees:

- `core/mesh_kit.gd` is the only source of curved geometry: `revolve()`,
  `drum()`, `cone()`, `prism()`, `half_cylinder()`, `oval_ring()`,
  `inverted_batter()`, `balcony_ring()`, `spike()`, `arc_ribbon()`. **Every
  profile is a hand-authored `PackedVector2Array`.** No metaball, marching
  cubes, surface nets, quad remesh, subdivision, vertex relaxation, noise, fbm
  or perlin anywhere in `src/` or `core/`.
- `core/mass_builder.gd` `MassBuilder.box()` / `component_box()` is the only mass
  primitive most buildings use. Every mass sits on `y = 0` or on a declared
  `ground` for a cellar; `qa/mass_rules.gd` `grounded()` is the rule that
  *proves the absence* of terrain adaptation.
- `VillageBuilder._ground()` is one flat 0.2 m box over `plan.site` at
  `Y_GROUND = 0.005`. No heightfield, no slope, no drape.
- 123 registered `class_name` classes; none is a world, terrain, climate or
  atmosphere type.

This is not a defect. The box-and-polygon contract is excellent for orthogonal
load-bearing architecture and it is validated hard. It is a **missing sibling
contract**, and the store currently has no vocabulary for it.

One precision worth keeping: the obstacle to a rounded mass is **not** a missing
curve primitive. `MeshKit.revolve()` already emits curved surfaces. The obstacle
is that a revolved surface is anchored to an axis, and a wall that bulges, a
roof that sags and a tower that leans are all non-axis-anchored. A bulging wall
also has one continuous normal, and this project's entire facade grammar depends
on a crisp normal per architectural surface — `MeshKit.commit()` deliberately
refuses `generate_normals()` because one smooth group spans the whole building.

## 3A. Holes, numbered, and one correction to my own framing

**The correction first.** `docs/VILLAGES.md` ends by stating the ordering as
"roads, lots, houses, then Terrain last, if at all" — terrain is an explicit
non-goal, not an oversight. A biome or forest branch is therefore the *boundary*
of this project's declared scope, not a hole in a commitment it made. Sections 6
and 7 are a description of what a world layer would have to bring with it, written
down now so the seam is cheap to cross later. Read them that way.

Holes that **are** inside the declared scope:

1. **Composition has no test.** `src/ui/studio.gd::_frame` is untested, no test or
   check file references a `Camera3D`, and a search of `tests/` and `qa/` for
   `Image`, `get_texture`, `save_png` and image extensions returns nothing. Every
   visual assertion in the repository is a human looking at a PNG. This project
   is unusually good at proving a wall is closed and unusually silent on whether
   the result is good.
2. **The runner's own registry is the only enumeration of what exists.**
   `tests/run_all.gd::_run_one` is a flat match and the single registry; a suite
   absent from it is not in the default run. There are about forty standalone
   `test_*.gd` scripts outside it. A capability that exists only in a standalone
   test is invisible to `run_all` and to the store.
3. **LOD, instancing and occlusion are absent**, and `src/village/village_builder.gd`
   emits eight flat surfaces at `Y_GROUND 0.005`, `Y_WATER 0.01`, `Y_ROAD 0.02`,
   `Y_COMMON 0.03` — millimetres apart purely to beat z-fighting. What keeps this
   safe is the scale ceiling (`SITE_MAX_SIDE = 400`, `VillageSpec.POP_MAX = 500`),
   not a design. Nothing in the store records that the ceiling is load-bearing.
4. **The book's sixth chapter is LOD and no code implements it.** Chapter 6 of the
   proposed book list is "Mesh construction, material slots, UVs, topology, and
   LOD". There is no `LODGroup`, no `visibility_range`, no `MultiMesh`, no
   `InstancedMesh` in the repository.
5. **The mutation-first idiom has no answer for a no-failure generator.** The
   dominant test pattern is: build a real plan, break exactly one thing, assert
   the named rule fires. `tests/fixtures/faulty_house_builder.gd` is the generic
   fixture. A family whose contract is "there are no wrong answers" has no defect
   to break, so the harness needs a different negative control — see OM-04.
6. **Two of the three design essays are cited by the store as if they described
   the code.** See §2. `docs/KNOWN_ISSUES.md` additionally describes a
   `src/building/` tree and a `scenes/main.tscn` that do not exist.
7. **Culture is tested; place is not.** `VillageDresser.PALETTES` has seven
   cultures, and `tests/suites/village_archetype_suite.gd` asserts real
   per-archetype vegetation predicates — `green_village` needs an orchard,
   `pine_hold` doubles its trees, `blight` requires dead trees, mushrooms and no
   green. That is a genuine per-row vegetation contract. What is missing is the
   environmental axis beside it: `terrain.rock` and `terrain.fertility` in the
   `SiteRequest` fixtures are read by nothing.
8. **`FOREST_DENSITY` is a floor, not a cap, and that is worth writing down.**
   The one-line form of a generator's intent is currently only discoverable by
   reading `src/village/village_dresser.gd`.

Two things the survey found that deserve credit rather than a hole:

- `qa/rule_set.gd` validates override names against the union of every `RULES`
  array, so a suite cannot silently disable a rule it misspelled. That is the
  same class of defence as the store's "a check that selects what it measures can
  pass by measuring nothing", and it is the only place the two meet.
- `tools/render_shots.gd` deliberately reuses the same fixture rows the landmark
  suites build, on the stated principle that a render is documentation and
  documenting a house that would fail its own checks is worse than not
  documenting one. That principle should be stated in the book, not just in a
  tool.

## 4. Critique C — Tiny Glade, the missing family

### 4.1 Name

Steam's own search index returns **Tiny Glade** for "glade" and no "Little
Glade" at all. Little Glade was the pre-release name. The next session that
searches the store for the term you just used will find nothing, so the branch
and its tags use **Tiny Glade**.

### 4.2 What the game is, in its publisher's words

From the Steam page for app 2198150 (Pounce Light, released 23 Sep 2024):

> Tiny Glade is a small diorama builder where you doodle whimsical castles,
> cozy cottages & romantic ruins. Explore **gridless building chemistry** as the
> game adorns your glades with procedural detail.

> **Explore gridless building chemistry**, and watch the game carefully assemble
> every brick, pebble and plank, adapting to your whim. **Draw a path through a
> building? A door pops up! Raise the building? Columns and beams line up to
> support it.**

> There are **no wrong answers** or failure states. You can change your mind at
> any time, and whatever you make will look cozy out of the box.

> Let yourself unwind to the chill vibes, and escape into a world that feels
> alive. **Ivy envelops your buildings**, sheep waddle through your paths, and
> fireflies light up the night.

### 4.3 The five mechanisms, and what the store has instead

| Mechanism | Nearest entry in the store | Why it is not the same thing |
|---|---|---|
| Reactive assembly: a drawn mark becomes structure | `procedural/buildings/authoring` bulk stamps; `procedural/villages/infrastructure` crossings | Both *edit* a fixed grammar. Reactive assembly *infers* a grammar that does not exist yet. |
| Support inferred bottom-up after a mass moves | `procedural/buildings/exterior-interior` "exterior promises require interior evidence" | That is the **opposite direction**: a door promises a route, checked against the plan. Support inference is geometry proposing and structure catching up. BrickWild's checks are all "does the mesh match the plan", never "is the plan still buildable now the mesh changed". |
| Vegetation as an architectural layer | `procedural/buildings/decoration` furnishing; `procedural/villages/landscape` land use | Both place plants. A plant on a wall has a host surface, a normal, a contact point and a support extent, and belongs to the building's dressing stage. |
| Gridless organic massing | — | Nothing. No entry, no emitter, no primitive (see §3). |
| A no-failure generator | `Procedural/buildings/validation`: "generate candidates, measure, repair, **reject irreparable candidates**"; `procedural/buildings/plans`: "a budget hit is not a proof... **report exhausted**" | The whole constraint stack assumes rejection is available. A toy that forbids failure needs a third answer to an unsatisfiable constraint: absorb it into the mass. |

### 4.4 The prior art the book never mentions

The one published thing closest to organic building generation was found only by
searching the literal phrase "organic building generation" — a phrase that
appears nowhere in the store, and therefore never in any search run against it.

- **Organic Building Generation in Minecraft** — Michael Cerny Green, Christoph
  Salge, Julian Togelius, PCG workshop at FDG 2019, [arXiv:1906.05094](https://arxiv.org/abs/1906.05094).
  Fills a 3D volume with a combination of constrained growth and cellular
  automata, producing organic-looking buildings complete with rooms, windows and
  doors. **Its grammar is the inverse of this project's**: grow a solid, then
  *carve* rooms and openings out of it, rather than pack rooms and then emit a
  solid. Carve-after-grow is exactly what "draw a wall, get a house" needs.
- **ArcPro: Architectural Programs for Structured 3D Abstraction of Sparse Points**
  (CVPR 2025, [arXiv:2503.02745](https://arxiv.org/abs/2503.02745)) — building
  structure as a program in a domain-specific language, converted to a mesh.
  Supports "the plan is a program, not a room table".
- **Semi-Supervised Adversarial Recognition of Refined Window Structures for
  Inverse Procedural Façade Modeling** ([arXiv:2201.08977](https://arxiv.org/abs/2201.08977))
  and **Single-view 3D reconstruction via inverse procedural modeling**
  ([arXiv:2310.13373](https://arxiv.org/abs/2310.13373)) — the grammar is the
  thing you fit, which is the strongest argument for keeping grammar as data.

**A negative result worth recording.** arXiv `cs.CG` × (`vegetation` OR `forest`
OR `L-system`) returns 69 hits that are airborne-LiDAR forestry, Steiner-forest
approximation and graph theory. `cs.CV` × (`procedural vegetation` OR `tree
generation` OR `forest generation`) returns 12, of which one is about trees. There
is **no arXiv literature on procedural forest composition for games**. The book
has no forest chapter because there is no literature to cite. That knowledge has
to be built from measurement, and the only real material is outside arXiv:
Deussen et al. on plant ecosystems (IEEE VIS 2002,
[doi:10.1109/visual.2002.1183778](https://doi.org/10.1109/visual.2002.1183778)),
Palubicki et al. on self-organizing tree models (SIGGRAPH 2009,
[doi:10.1145/1576246.1531364](https://doi.org/10.1145/1576246.1531364)), Runions
et al. on attraction-based generation (SIGGRAPH 2005,
[doi:10.1145/1186822.1073251](https://doi.org/10.1145/1186822.1073251)),
Bridson on Poisson-disk sampling (SIGGRAPH 2007,
[doi:10.1145/1278780.1278807](https://doi.org/10.1145/1278780.1278787)), and
Deussen et al. on inverse procedural tree modelling (CGF 2014,
[doi:10.1111/cgf.12282](https://doi.org/10.1111/cgf.12282), 148 citations).

## 5. Critique D — taxonomy defects, now repaired

| Defect | Count | Repair |
|---|---|---|
| `procedural/building/` — singular root, the book never mentions it | 5 | folded into `procedural/buildings/` and `procedural/villages/` |
| `procedural-buildings/distribution/validation` — hyphenated root | 1 | → `procedural/buildings/distribution` |
| `reindex_procedural_knowledge.py` listed a title that no longer exists in the store | 1 | stale line removed, so the tool runs clean |
| `procedural/social sim/*` (space) and `procedural/social_sim/*` (underscore) as two roots for one branch | 2 roots | **not touched** — that is the Village project's branch, out of scope here; flagging it for whoever owns it |
| No `procedural/biomes`, no `procedural/forests` | 0 | created, §6 and §7 |

`waterfree knowledge` has no way to list or filter by hierarchy path, which is
why these six survived a migration that was written and committed. The reindex
script is the only enumeration, and it was broken.

## 6. Proposed branch: `Procedural/biomes`

Ten entries, in the shape §2 requires. Seeds: `simulation/worldgen/climate-and-ecology`,
`procedural/dungeons/09-theme` ("a biome is an ordered threshold table, not a
label"), `simulation/procedural-generation/climate`, and this repository's
`SiteRequest` terrain contract.

**BI-01 — A biome is an ordered threshold table over a climate vector, not a label.**
*Rule:* classify a cell by testing an ordered list of `(field, op, value)` rules
against a climate vector; first match names the biome. Keep it a pure function and
run it before every stage that consumes it. *Reason:* a label map cannot explain
itself; a threshold table is testable and a cell's biome is re-derivable from the
fields. *Failure:* a switch on a biome id is a lookup, so changing a field changes
nothing downstream; an un-ordered table makes the last rule silently win. *BrickWild:*
no biome code exists. The vocabulary is written down and unread —
`tests/fixtures/site_requests/*.json` carry
`terrain.{elevation, slope, water_edges, forest, fertility, rock}`, and
`tools/export_village_plan.gd` reads only `water_edges` and `forest`. *Source:*
promote `procedural/dungeons/09-theme`'s `climate_to_theme()` entry into this branch.

**BI-02 — Measure the distribution, never the map.** *Rule:* when a world looks
wrong, print per-field quantiles and per-biome/per-species area shares across at
least three seeds before looking at a picture. *Reason:* a map hides the fact that
one class owns 90% of the cells; the distribution names the cause. *Failure:* a
prior diagnosis blamed flora content and missed the climate cause entirely.
*BrickWild:* the same shape as "a check that selects what it measures can pass by
measuring nothing" — compare counts, not impressions. *Source:* the
`climate-and-ecology` entry.

**BI-03 — Rainfall is a transported quantity, not a per-cell maximum.**
*Rule:* compute precipitation as inflow minus outflow across a grid with an
explicit transport step. A max of a noise field has no catchment. *Reason:* wet
and dry cells then sit side by side with no river between them, and no band can
saturate. *Failure:* max-normalized rainfall with no moisture recycling produced a
world with **no forests at all**. *Source:* the `climate-and-ecology` entry.

**BI-04 — Temperature needs an explicit lapse rate, and the rate is a bug until measured.**
*Rule:* `temperature = base − lapse · (elevation − sea_level)`, then measure the
share of land below freezing. *Reason:* the lapse rate decides which bands exist.
*Failure:* an over-steep rate put **44% of land below freezing**, leaving no room
for a cold-forest band; the map looked plausible and the biome list was
unreachable. *BrickWild:* `terrain.elevation` is an unread fixture field here, so
the rule has no consumer yet. *Source:* the `climate-and-ecology` entry.

**BI-05 — Ecology needs succession, or the lowest-stress species wins.**
*Rule:* if a species' biomass over settle steps is peak-then-collapse, diffusion is
carrying it into hostile ground where stress mortality kills it — that is
survivorship, not fitness. Add nursery and mature stages, or stop letting the
dominant species diffuse past its tolerance. *Failure:* one species dominates
regardless of tuning. *Source:* the `climate-and-ecology` entry.

**BI-06 — Cache the expensive field, re-run only the loop.** *Rule:* habitat
fields are the expensive half; cache them and re-run only the ecology loop when
tuning. *Reason:* a harness that recomputes fields per iteration cannot be tuned,
because each run costs a world. *BrickWild:* the identical split already exists as
`BrickWild test lanes` — the slow house suites are slow because they run the
furnisher search, not because they check more. *Source:* the `climate-and-ecology`
entry plus the lane entry.

**BI-07 — A biome edge is a band with a width, not a boundary.** *Rule:* two
biomes meet through a transition band whose width is authored, and that band is
where scatter density and material blending live. *Reason:* a zero-width edge puts
a tree half in a wood and half in a field. *Failure:* a hard edge reads as a fence
the world did not build. *BrickWild:* the settlement already has the concept at
village scale — `VillageDresser.EDGE_BAND` is a hand-authored band-width table
(`none 4`, `hedge 5`, `palisade 8`, `wall 10`) with `EDGE_PITCH 6.0` and
`EDGE_REACH 6.0`. The same rule about a treeline is not written anywhere.
*Source:* `src/village/village_dresser.gd`.

**BI-08 — A biome is a material set, not a colour.** *Rule:* a biome owns
`(surface, material, UV scale, normal strength)` plus the plant catalogue slots it
may draw from. *Reason:* a colour-only biome collapses the moment the sun moves;
a material set survives it. *Failure:* uniform random grime loses the
construction story — the lesson already recorded for buildings. *BrickWild:*
`HouseSpec.roof_material` is a spec enum plus a shader `uniform bool thatch` in
`ShellAssembler.house_materials()`; no reed, course or tile geometry is ever
emitted. Village ground is one flat untextured colour `6f7a4a`. The only doc that
even names the problem is `docs/PROCEDURAL_OPEN_SOURCE.md` lines 70-71, as a
recommendation with no implementation. *Source:* `procedural/buildings/exteriors`.

**BI-09 — A climate refresh after a terrain change is a diagnostic, never a second
feedback loop.** *Rule:* when the pipeline reorders, re-reading climate must not
write back into erosion. *Reason:* a feedback loop makes the output depend on
iteration count, which is a determinism bug wearing a physics costume.
*Failure:* an oorographic-contrast fix that fed back would silently re-order its
own inputs. *BrickWild:* the same shape as "hash the seed WITH the element id" —
do not add a second draw to fix a first-draw problem. *Source:*
`simulation/procedural-generation/climate`.

**BI-10 — The biome must select the building family, not only the ground material.**
*Rule:* the biome is the upstream input to a settlement's architecture. A village
in a marsh and a village on a limestone slope share a road graph and share almost
nothing else: materials, plot size, water strategy, which props exist, whether
there is a ford or a bridge. *Reason:* without this axis the biome is wallpaper.
*Failure:* seven culture palettes over one ground colour is a reskin — the same
defect as "a theme that only changes the tileset is a reskin", one level up.
*BrickWild:* `VillageDresser.PALETTES` is a per-village **culture** row
(english / frankish / norse / alpine / moorish / eastern / blighted) crossed with
slots (edge / green / hedge / ground). That is a palette, not a place. The missing
axis is environmental, and `terrain.rock` and `terrain.fertility` in the
SiteRequest fixtures are exactly the two fields that would carry it — both unread.
*Source:* the reskin entry plus the fixtures.

## 7. Proposed branch: `Procedural/forests`

Ten entries. Seeds: `godot/voxelgames/rendering/*`,
`godot/voxel-tools/instancing/lod-bands`, `gamedev/terrain/*`, and this
repository's `VillageDresser` / `VillageDressCheck` / `SceneBounds`.

**FO-01 — Scatter is Poisson-disk with a radius that is a function.** *Rule:*
blue-noise sampling with a minimum radius `r(x)` that is a function of the local
field. *Reason:* uniform-density sampling cannot express thinning, clearing or
avoidance, so the field never reaches the scatter. *Failure:* a constant radius
over a moisture field gives the same density in a bog and on a hill, and the
result reads as a plantation. *BrickWild:* `FOREST_DENSITY 2.0`, `TRUNK_CLEAR 1.0`
and `GREEN_TREE_CLEAR 4.0` are constants; `_scatter()` is the only
density-driven generator and `_wood()` is a separate authored path. *Source:*
Bridson 2007 for the sampler; the store has **no** entry on Poisson-disk sampling
at all, which is itself the finding.

**FO-02 — A plant is two radii, not a box.** *Rule:* measure a plant as
`(canopy, trunk)`. Canopy is the maximum horizontal reach about the model's own
axis and is what must clear a roof; trunk is the same measure at or below a fixed
trunk height and is what must stay off a road. *Reason:* one AABB is wrong for
every plant and worst for a birch — two metres of mostly air around a 16 cm stem.
*Failure:* an AABB-driven placement either clears a 4 m circle for a stem or lets
a crown through a roof. *BrickWild:* **this is the strongest vegetation fact in the
project and it is filed under `procedural/buildings/assets`.** `core/scene_bounds.gd`
`plant_of_node()` / `_gather_radii()` and `SceneBounds.TRUNK_HEIGHT`; `PropCatalog.canopy()`
and `.trunk()`; `assets/props/catalog.json` carries `canopy` and `trunk` for all
**104** plant keys — 36 `Nature_*` and 68 `Wild_*` — and for no other key;
`tests/suites/house_assets_suite.gd` re-loads each plant, re-measures, and fails on
drift or on `canopy <= 0`. *Action:* promote to this branch and cross-reference from
`procedural/buildings/assets`.

**FO-03 — Vertical stratification is the composition, not an afterthought.**
*Rule:* a forest is layers — overstory, midstory, understory, ground cover — each
with its own species set, radius, count and LOD. *Reason:* a stand built from one
species at one height is a field of lollipops. *Failure:* the trade is real, not a
bug: on real airborne-LiDAR data, stratifying the canopy raised understory
detection from 46% to 68% while raising over-segmentation from 1% to 16%. *BrickWild:*
`qa/village_dress_check.gd` `COVER_CATS` (grass, flower, ground_cover, pebble,
stepping_stone, mushroom) is a ground layer with no upper layers above it; trees
come from `_wood()` / `_scatter()` as a single class. *Source:* Hamraz et al.,
*Vertical stratification of forest canopy…*, ISPRS J. Photogrammetry 130C (2017)
385-392, [doi:10.1016/j.isprsjprs.2017.07.001](https://doi.org/10.1016/j.isprsjprs.2017.07.001).
Those percentages are theirs, measured on LiDAR; they are cited here for the shape
of the trade-off, not as a claim about a game forest.

**FO-04 — A LOD band is a coverage band, and its failure is invisible standing
still.** *Rule:* if an instancer registers per LOD band, that index is a **spatial
coverage** band. Test it while the camera moves: the defect appears only at the
instant the band changes underneath you. *Failure:* a still frame cannot catch it,
so every screenshot review of a LOD change is a false pass. *BrickWild:* no
`LODGroup`, no `visibility_range`, no `MultiMesh` anywhere;
`VillageAssembler._model()` does `load()` plus `instantiate()` per plant. The
project is therefore currently safe from this bug and has no defence if it ever
adds one — what keeps it safe is the scale ceiling, `SITE_MAX_SIDE = 400` and
`VillageSpec.POP_MAX = 500`. *Source:* `godot/voxel-tools/instancing/lod-bands`.

**FO-05 — One CPU field for tone, two dials for density.** *Rule:* separate the
field that decides *which* blades from the dials that decide *how many*. *Reason:*
with a near dial and a far dial, the near one dominates what the player actually
sees, and a screenshot tests only the near dial. *Failure:* the far dial is never
exercised by any visual review and drifts indefinitely. *BrickWild:* nothing to
apply yet; the deferral is bought by `SITE_MAX_SIDE = 400`. *Source:*
`godot/voxelgames/rendering/grass-density` and the calico field entry.

**FO-06 — An impostor needs unlit albedo and the mesh's own automatic LOD.**
*Rule:* when a tree is swapped for a card, keep automatic mesh LOD and do not bake
lighting into the impostor's albedo. *Reason:* lighting baked into albedo
double-lights at the swap distance and the two bands disagree exactly where the
player is looking. *BrickWild:* no impostors, and no foliage shader at all —
`core/shell_assembler.gd` holds two shaders, roof courses and floor textile.
*Source:* `godot/voxelgames/rendering/asset-lod`, which itself records that atlas
grid, depth blending and transition pixels were **not** benchmarked on the target
GPU. A rule whose own entry flags its unbenchmarked half should be read with that
flag attached.

**FO-07 — Clear the paths, then plant; clearance is a measured radius.** *Rule:*
order the stages architecture → circulation → planting, and clear by the measured
trunk radius, not a bounding box. *Reason:* a plant placed later on a route cuts
the route, and the later stage always wins. *Failure:* the shore case, verbatim —
reserving the apron is insufficient because a later bush can cut its upstream yard
route. *BrickWild:* this one is already right, and it is the store's best runnable
rule. `VillageDresser` runs `_spots_for()` candidates through `_prop_is_clear()` /
`_plant_is_clear()` with `PROP_CLEAR 0.35`, `DOOR_CLEAR 1.2`, `ROAD_CLEAR 0.4`,
`TRUNK_CLEAR 1.0`, `CANOPY_SLACK 0.1`, and `qa/village_dress_check.gd`
`VillageDressCheck` re-derives 13 rules from the placements alone. *Source:*
`procedural/villages/decoration`.

**FO-08 — A plant that meets a building is a hosted attachment, not a scatter.**
*Rule:* when a plant is planted against or over a structure it acquires a host: a
surface, a normal, a contact point, a support extent and a growth constraint. It
then belongs to the building's dressing stage and is measured by the building's
QA, not the landscape's. *Failure:* a plant's bounding box is not the wall it
grows on — the general form of the trap already recorded as "a terrain sampler is
not what a 0.2 m object stands on". *BrickWild:* **no ivy, vine, creeper, climber,
foliage or overgrowth anywhere** — 0 hits over `src/`, `core/`, `qa/`, `tools/`,
`docs/`. Vegetation is instanced art and never grows onto a wall;
`HouseExterior.dress()` places wall props only. The measurement substrate is
already there (FO-02); only the attachment is missing. *Source:* the
`terrain sampler` entry plus the Tiny Glade store page.

**FO-09 — The forest edge is where a settlement becomes legible.** *Rule:* the
outermost band of trees is the silhouette. Give it its own species, height and
density rather than letting the scatter run out. *Reason:* a forest that thins to
nothing has no edge, and a settlement with no edge has no shape from a distance.
*Failure:* grass and pebbles left in the edge band read as litter. *BrickWild:*
`VillageDresser._edge_band()` / `_hedges()` and `VillageDressCheck` already do the
settlement-edge version — `EDGE_PITCH 6.0`, `EDGE_REACH 6.0`, `EDGE_RUN_MAX 25.0`,
`GREEN_TREES_MAX 3`, and `_visible_edge_plant()` rejects grass and pebbles as edge
shrubs. The same rule applied to a wood is not written anywhere. *Source:*
`procedural/villages/landscape` ("a farming field must touch a track, orchards
belong behind farms").

**FO-10 — A forest is a space-colonization skeleton or a catalogue, never a
generated mesh per instance.** *Rule:* there are two ways to get a tree. Instantiate
from a measured catalogue — cheap, art-directed, the right default — or grow a
skeleton by attraction-based colonization and attach a leaf and instancing system,
which is expensive, per-tree, and only worth it where one tree is the subject.
*Reason:* colonization gives a believable branch graph from an attractor set at the
cost of an iteration loop per tree. *Failure:* a self-organizing model re-run for
every tree in a stand is the same mistake as re-running the furnisher search per
prop. *BrickWild:* 104 measured plant models exist and are regression-tested; the
answer here is unambiguously the catalogue, and there is correctly no tree
generation. *Source:* Runions et al. (SIGGRAPH 2005,
[doi:10.1145/1186822.1073251](https://doi.org/10.1145/1186822.1073251)),
Palubicki et al. (SIGGRAPH 2009,
[doi:10.1145/1576246.1531364](https://doi.org/10.1145/1576246.1531364)),
Deussen et al. (IEEE VIS 2002,
[doi:10.1109/visual.2002.1183778](https://doi.org/10.1109/visual.2002.1183778)).

## 8. Proposed branch: `Procedural/buildings/organic-mass`

Seven entries for the Tiny Glade family, at the same standard as §6 and §7.

**OM-01 — The organic grammar carves after it grows; this project's packs then emits.**
*Rule:* keep both. Pack rooms into a footprint and emit a shell; or grow a solid
and carve rooms, doors and windows out of it. *Failure:* the pack-then-emit grammar
cannot produce a building whose outline is the gesture the player drew, and no
amount of facade detail will disguise the rectangle. *Source:* Green, Salge,
Togelius, [arXiv:1906.05094](https://arxiv.org/abs/1906.05094).

**OM-02 — Reactive assembly belongs in the plan stage, not the mesh stage.**
*Rule:* a drawing tool makes a mark; a separate stage turns marks into structure
(closed loop → walls, gap → door, raised mass → columns). *Reason:* inferring
during mesh emission leaves nothing to check the inference against, and makes undo
impossible. *Failure:* structure that exists only as emitted triangles cannot be
queried, cannot be validated, and cannot be re-derived. *Tiny Glade:* "Draw a path
through a building? A door pops up!" *BrickWild:* the reverse direction already
exists as a good check — "exterior promises require interior evidence" says a
front door promises an entry route. Reactive assembly needs the other direction,
and both are cheap once both exist.

**OM-03 — Support is inferred bottom-up and re-derived on every edit.** *Rule:*
when a mass is raised, derive the shortest support path to the ground, snap it to a
column grid, add beams where the span is long. Treat a support change as a plan
change, not a mesh patch. *Failure:* authored columns drift from the mass they hold
the moment the mass moves, and nothing re-checks. *Tiny Glade:* "Raise the
building? Columns and beams line up to support it." *BrickWild:* `qa/mass_rules.gd`
`grounded()` proves every mass touches its declared ground — a support check with
exactly one permitted relation. It cannot express "held by these columns", because
nothing in the codebase models a column as anything but a mass. The primitive
exists (`MeshKit.drum()`, `TempleBuilder` column emission at
`src/temple/temple_builder.gd:136-141`); the inference does not.

**OM-04 — "There are no wrong answers" is a generator contract, and it needs a
repair loop that cannot fail.** *Rule:* a no-failure generator must supply (a) a
repair pass guaranteed to terminate with something, (b) a soft score, and (c) an
explicit ban on a failure state — including a ban on a "budget exhausted" flag.
*Reason:* every constraint in this project assumes rejection is available, so
reusing the stack for a cosy toy produces a generator that sometimes emits
nothing, which the toy forbids. *Failure:* a rejected candidate is a hole in the
world where the player drew a wall. *Tiny Glade:* "There are no wrong answers or
failure states. You can change your mind at any time, and whatever you make will
look cozy out of the box." *BrickWild:* the store's shape is the opposite —
"repair where possible, and reject irreparable candidates", and "a budget hit is
not a proof... return an exhausted flag". The third answer is to absorb the
violation into the mass.

**OM-05 — Vegetation on a wall is the cheapest "not a box" signal available.**
*Rule:* if organic massing is out of reach, let plants attach to walls and roofs
with measured support first. *Reason:* it breaks the box read immediately, needs
no new mass primitive, and reuses the `SceneBounds` measurement this project
already has. *Failure:* unattached vegetation is a level-dressing pass, which is
what it is. *Tiny Glade:* "Ivy envelops your buildings." *BrickWild:* substrate
measured and tested (FO-02), attachment absent (FO-08). *This is the
highest value-per-effort move on the list.*

**OM-06 — A rounded mass is a different primitive AND a different normal contract.**
*Rule:* before promising a curved wall, check the normal and winding contract, not
just the geometry. *Reason:* this project's facade grammar assumes one plane per
face with a crisp normal per architectural surface; a bulged wall has one
continuous normal, and the crispness that makes stone read correctly is gone.
*Failure:* a single smooth group spans the whole building and every edge goes soft.
*BrickWild:* `MeshKit._face_normal` is the single winding authority — Godot's front
faces are clockwise, so a triangle wound (a, b, c) has outward normal
`(c - a).cross(b - a)` — and `MeshKit.commit()` deliberately does **not** call
`generate_normals()`. `revolve()` already emits curved surfaces, so the obstacle is
not the primitive: a revolved surface is axis-anchored, and a wall that bulges is
not. Generate normals per material role, never per smooth group.

**OM-07 — A cosy product's acceptance test is a picture, and this project has no
picture test.** *Rule:* a family whose whole claim is how it looks owes an
automated visual gate, and it needs a different kind of one from the geometric
checks. *Reason:* geometric checks are exhaustive and cheap; a composition check
is neither, and a human staring at a PNG is the current substitute. *Failure:*
the failure is invisible until someone happens to render that seed — and
`src/ui/studio.gd::_frame`, the function that decides what a viewer sees, is
itself untested, so a regression in framing passes every check in the repository.
*BrickWild:* no test or `qa/` file references a `Camera3D`; there is no image
comparison anywhere. `tools/render_shots.gd` sets the right principle — a render
is documentation, so it reuses the same fixture rows the landmark suites build and
would rather document nothing than document a house that fails its own checks.
The missing piece is turning "documented" into "compared". *Source:* the
`check that selects what it measures` entry, which is the same defect at the level
of a check count.

## 9. Ranked list of what to file

Highest value first, because effort is not free:

1. FO-02 (promote, the project already implements and tests it) — highest value, lowest cost.
2. OM-05 and FO-08 (the attachment seam; substrate exists, only the link is missing).
3. BI-10 (the axis that turns `PALETTES` from a reskin into a place).
4. OM-04 (a contract no existing entry covers, and the one most likely to be got wrong).
5. BI-02, BI-03, BI-04, BI-05 (one coherent cluster, already written up in
   `simulation/worldgen`; splitting it out costs one script run).
6. FO-01, FO-03, FO-04, FO-05, FO-06, FO-09.
7. OM-01, OM-02, OM-03, OM-06.

## 10. What I could not verify

- **No web search provider was reachable** in this session, so Little Glade /
  Tiny Glade design commentary beyond the publisher's own store page could not be
  gathered. The store page is a primary source and is quoted verbatim above;
  everything else about the game is inference from that text and is marked as such.
- The classic tree and grass literature was verified through the Crossref API by
  title, venue, year and DOI. **Author lists were not verified for every entry** —
  `Inverse Procedural Modelling of Trees` (CGF 2014) is cited by title and DOI only.
- The repository survey was read-only and cross-checked against search hits, but no
  Godot run confirmed it. Absence claims are backed by named searches over
  `src/`, `core/`, `qa/`, `tests/`, `tools/`, `scenes/`, `packaging/`, `assets/`
  and `docs/`, not by a build.

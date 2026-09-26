# Procedural buildings, villages, meshes, and decoration

## Contents

- [Core generation principles](#1-the-generation-stack) (sections 1-7 below)
- [Impossible structures](PROCEDURAL_IMPOSSIBLE_STRUCTURES.md): spatial tricks, portals, gravity, and QA
- [Permissive open source implementations](PROCEDURAL_OPEN_SOURCE.md): verified code references and reuse rules
- [Architecture concepts and rules](PROCEDURAL_ARCHITECTURE_RULES.md): massing, rhythm, circulation, structure, and style
- [Exterior and interior design](PROCEDURAL_EXTERIOR_INTERIOR.md): facade, site, furnishing, lighting, and dressing
- [Biomes](#8-biomes-are-fields-not-labels) and [forests](#9-forests-are-composition-not-scatter)
- [Organic and reactive buildings](#10-organic-and-reactive-buildings)
- [Knowledge audit and holes](KNOWLEDGE_AUDIT_BUILDINGS_BIOMES_FORESTS.md): what the branches miss, measured
- [Book chapter plan](#11-proposed-book-chapters)

This is the reading map for the WaterFree knowledge base. Search or browse the
`Procedural/buildings`, `Procedural/villages`, `Procedural/meshes`,
`Procedural/biomes` and `Procedural/forests` branches. Each entry is a reusable
rule with a reason, a failure mode and a BigGlade example; a minority also carry
a source, in prose or in `source_repo_url`. The branches can become chapters of
a practical book; the project documents below provide case studies and numeric
fixtures. Treat the numbers in those documents as BigGlade design choices, not
historical laws.

[KNOWLEDGE_AUDIT_BUILDINGS_BIOMES_FORESTS.md](KNOWLEDGE_AUDIT_BUILDINGS_BIOMES_FORESTS.md)
measured this map on 2026-09-26 and found the form lessons almost entirely
orthogonal, the `biomes` and `forests` branches absent until that audit created
them, and six entries filed outside every branch this page names. Read it before
adding to any of these branches.

The branches include the original BigGlade lessons that had been scattered
under `godot/bigglade`, `procedural-generation`, and `world/buildings`, plus
transferable building and settlement patterns from other projects. Their
original entry IDs, content, source repositories, and scopes are preserved;
only their hierarchy paths changed. The explicit, repeatable mapping lives in
[`tools/reindex_procedural_knowledge.py`](../tools/reindex_procedural_knowledge.py).
Asset inventory rows, villager simulation rules, and unrelated tooling remain
in their own catalogs.

## 1. The generation stack

Start with a brief and deterministic seed. Derive a semantic plan before making
geometry: site and road graph, lots, building programme, room graph, structural
mass, openings, surfaces, fixtures, and small clutter. Keep a stable identifier
for every generated part. Each stage consumes the previous stage's measured
output and records enough information to reproduce or diagnose a failure.

BigGlade's building families follow Spec -> Geometry -> Plan -> Builder ->
Assembler. `HousePlan` and `VillagePlan` are data contracts. Assemblers load
models; builders emit geometry. This allows plan and circulation checks without
loading scenes. See [HOUSES.md](HOUSES.md), [VILLAGES.md](VILLAGES.md), and
[AGENTS.md](../AGENTS.md). The same separation is useful outside Godot.

## 2. Buildings are programmes with circulation

Choose a building's use before its shape. A house needs sleeping, work,
hearth, storage, and access; a shop needs a public threshold and working area;
a castle needs logistics inside its defences; a temple needs a legible path to
its focus. Turn these into a room adjacency graph, place the graph inside a
footprint, then reserve doors, stairs, working clearances, and sightlines.
Generate the shell from this plan. A plausible silhouette with unreachable
rooms or a blocked altar is incomplete.

Use measured footprints and door positions when a building joins a village.
A requested width can differ from the final porch, stairs, jetty, or wall.
See [HOUSES.md](HOUSES.md), [CASTLES.md](CASTLES.md), [TEMPLES.md](TEMPLES.md),
[SHOPS.md](SHOPS.md), and [HOTELS.md](HOTELS.md). Layout graphs constrained by a
building boundary are also central to [Graph2Plan](https://arxiv.org/abs/2004.13204).

## 3. Building families need distinct spatial grammars

Create archetypes from structural relations, then add style and decoration as
separate parameters. Courtyard buildings organize rooms around open space;
tower houses stack a small footprint; hypostyle halls require a column field
with a clear route; pagodas repeat tapering tiers; stepwells organize a
descending route to water. A single rectangle-and-roof template cannot encode
these differences. BigGlade's [WORLD_BUILDINGS.md](WORLD_BUILDINGS.md) surveys
Mediterranean, East and South-East Asian, and Indian families and identifies
representation changes each requires. Its examples are design references to
verify against specialist historical sources before claiming authenticity.

The classic [CGA building paper](https://doi.org/10.1145/1179352.1141931)
shows a useful hierarchy: mass model, facade subdivision, and detailed
components, with context-sensitive rules. [Inverse Procedural Modeling of
Facade Layouts](https://arxiv.org/abs/1308.0419) and
[FaçAID](https://arxiv.org/abs/2406.01829) show how split grammars can recover
editable facade structure from examples. A facade grammar must still honor
the underlying rooms, openings, and structural supports.

## 4. Meshes are geometry with contracts

Represent a solid's surfaces explicitly: vertices, winding, normals, UVs,
material role, host, and stable component id. Godot uses clockwise front
faces. BigGlade's `MeshKit._face_normal` is the single winding authority, and
its building emitters assign per-face normals so neighboring architectural
planes remain crisp. Index vertices only across faces that may share the same
normal and attributes. Group surfaces by named material role because empty
surfaces can be dropped and numeric surface positions can shift.

Use polygons for footprints and roof regions, and a shared roof descriptor for
roof skin, wall profile, openings, and attachments. Intersect dormers with the
host roof plane. Place a window on the actual battered or tiered wall surface,
not its bounding box. Distinguish an intentional internal roof seam from an
exposed crack before deleting faces. See [ROOF_AUDIT.md](ROOF_AUDIT.md) and
[ROOF_REGION_CONTRACTS.md](ROOF_REGION_CONTRACTS.md).

For Godot 4, [ArrayMesh](https://docs.godotengine.org/en/4.5/tutorials/3d/procedural_geometry/arraymesh.html)
and [SurfaceTool](https://docs.godotengine.org/en/4.5/tutorials/3d/procedural_geometry/surfacetool.html)
build static geometry; [MeshDataTool](https://docs.godotengine.org/en/4.5/tutorials/3d/procedural_geometry/meshdatatool.html)
exposes edge and face topology when an algorithm needs it. The tool choice is
about required data and update frequency, not architectural style.

## 5. Assets and decoration are placed by function

Maintain a measured catalogue of model extents, pivots, support surfaces,
collision footprints, and optional canopy/trunk radii. BigGlade regenerates
`assets/props/catalog.json` from the actual models. A room recipe says what a
space must contain and which relation each item has to a host: against wall,
beside table, on shelf, facing focus, near entrance. Reserve circulation and
work zones before filling secondary gaps. Recheck reachability after every
high-impact placement and repair an invalid arrangement.

Separate fixed architecture, usable furniture, and optional clutter. A
required table or altar should not be silently discarded to make a navigation
test pass; record the sacrifice as a warning. The same principle applies to
outdoor dressing: paths to doors, stall aisles, gates, roads, and the well
remain clear. Plant trunks and canopies have different clearance rules. See
[HOUSES.md](HOUSES.md), [VILLAGES.md](VILLAGES.md), and
[FURNISHING_WALLS.md](FURNISHING_WALLS.md). [Make it Home](https://web.cs.ucla.edu/~dt/papers/siggraph11/siggraph11.pdf)
models furniture relations and ergonomics as an optimization problem;
[Infinigen Indoors](https://arxiv.org/abs/2406.11824) combines procedural
asset generation with constraint-based arrangement.

## 6. Villages are a hierarchy of networks and places

Start with a reason for the settlement: crossing, market, river power,
fishing, farming, pilgrimage, mine, or fortification. Place the defining
landmark and water constraints, then the through road, common, streets, lots,
buildings, paths, enclosure, and outside land use. A road graph alone cannot
make a village: doors must face reachable frontage; the common and work sites
need appropriate neighbors; houses and services must match population.

BigGlade's [VILLAGES.md](VILLAGES.md) defines street, green, crossroads,
round, strand, planted, and gate forms as road/common/lot patterns. Its
population thresholds and dimensions are game design rules, not universal
demography. [Procedural Modeling of Cities](https://people.eecs.berkeley.edu/~sequin/CS285/PAPERS/Parish_Muller01.pdf)
is a foundational pipeline from population and environment to road networks
and building placement. Read it for decomposition, then use local context to
choose morphology and scale.

## 7. Constraints make diversity usable

Use hard constraints for buildability and use: no overlap, route continuity,
door access, structural support, water crossing, lot fit, and required focus.
Use soft preferences for composition: density, symmetry, style, landmark
visibility, frontage rhythm, and decoration. Generate candidates, measure
them, repair where possible, and reject irreparable candidates. Keep reason
codes so failures teach the generator. Preserve deterministic sub-seeds by
stage or stable identity so adding a prop does not reshuffle the road graph.

BigGlade's checks inspect emitted vertices and geometry logs as well as plan
data. The logs must describe what the builder actually emitted. Test at
several seeds and scales, and introduce faulty geometry to prove that each
check can reject a defect. A rendered view adds visual evidence; headless
geometry tests cannot judge composition by themselves. See [AGENTS.md](../AGENTS.md)
and [HOUSE_RULES_EVALUATION.md](HOUSE_RULES_EVALUATION.md).

## 8. Biomes are fields, not labels

A biome is a pure function from a climate vector to a name, tested as an ordered
threshold table. A label map cannot explain itself, and a lookup cannot be
re-derived from the fields that produced it. Put the function before every stage
that consumes it, keep it pure, and record the reason codes.

The fields are the hard part, and each one fails in its own way. Precipitation
must be transported — inflow minus outflow on a grid — because a per-cell maximum
has no catchment; max-normalized rainfall with no moisture recycling produced a
world with **no forests at all** in one recorded case. Temperature needs an
explicit lapse rate, and the rate is a bug until you measure the share of land
below freezing: an over-steep rate put 44% of land under ice and left no room for
a cold-forest band. Ecology needs succession, or the lowest-stress species wins on
survivorship and one species dominates regardless of tuning.

**Diagnose by distribution, not by map.** Print per-field quantiles and
per-biome area shares across several seeds before looking at a picture; a map
hides the fact that one class owns ninety per cent of the cells. A biome edge is
a band with an authored width, and a biome is a material set with a UV scale, not
a colour. And the biome must select the building family: a marsh village and a
limestone village may share a road graph and share almost nothing else.

Terrain is an explicit non-goal in `docs/VILLAGES.md` — "roads, lots, houses,
then Terrain last, if at all". BigGlade therefore has no consumer for these rules
yet. The vocabulary exists as unread data in the `SiteRequest` fixtures
(`terrain.elevation`, `slope`, `water_edges`, `forest`, `fertility`, `rock`), of
which `tools/export_village_plan.gd` reads only `water_edges` and `forest`. That
contract is the seam a world layer would arrive through. The ten drafted entries,
with reasons and failure modes, are in
[the audit](KNOWLEDGE_AUDIT_BUILDINGS_BIOMES_FORESTS.md#6-proposed-branch-proceduralbiomes).

There is no useful arXiv literature on this: `cs.CG` searched for vegetation,
forest and L-system returns LiDAR forestry, Steiner forests and graph theory. The
seed material was a hard-won simulation failure, not a paper, and it is filed at
`simulation/worldgen/climate-and-ecology`.

## 9. Forests are composition, not scatter

A forest is layers — overstory, midstory, understory, ground cover — each with its
own species set, radius, count and LOD. A stand built from one species at one
height is a field of lollipops. The stratification trade is real, not a bug: on
airborne-LiDAR data, stratifying the canopy raised understory detection from 46%
to 68% while raising over-segmentation from 1% to 16%.

Scatter is Poisson-disk with a **minimum radius that is a function of the local
field**. A constant radius gives the same density in a bog and on a hill, and the
result reads as a plantation. A plant is **two radii, not a box**: canopy is the
reach that must clear a roof, trunk is the reach at or below a fixed trunk height
that must stay off a road, because a birch's bounding box is two metres of mostly
air around a 16 cm stem. BigGlade already does this and tests it — `SceneBounds`
measures both, all 104 plant keys in `assets/props/catalog.json` carry them, and
the assets suite fails on drift.

Order the stages architecture, circulation, planting, and clear by the measured
trunk radius: the later stage always wins, so the earlier one has to hold. A plant
that meets a building is a **hosted attachment** with a surface, a normal, a
contact point and a support extent — it belongs to the building's dressing stage,
not the landscape's. The forest edge is the settlement's silhouette and needs its
own species and density band, or the forest simply thins to nothing.

If you grow a tree, grow a skeleton by attraction-based colonization and attach a
leaf and instancing system. Do not generate a tree mesh per instance of a
thousand; a self-organizing model re-run per tree is the same mistake as
re-running the furnisher search per prop. A LOD band is a **spatial coverage**
band whose failure is invisible standing still, so test it while the camera
moves. The ten drafted entries are in
[the audit](KNOWLEDGE_AUDIT_BUILDINGS_BIOMES_FORESTS.md#7-proposed-branch-proceduralforests).

## 10. Organic and reactive buildings

This project emits axis-aligned boxes, planar slabs, and surfaces of revolution
around an axis. `MeshKit.revolve()` already makes curved geometry, so the missing
thing is not a curve primitive; it is a mass that is not axis-anchored — a wall
that bulges, a roof that sags, a tower that leans. A bulged wall also breaks the
normal contract: this grammar assumes one crisp normal per architectural surface,
and a bulged wall has one continuous normal. Generate normals per material role,
never per smooth group. See `MeshKit._face_normal` and the fact that
`MeshKit.commit()` deliberately refuses `generate_normals()`.

The closest published prior art was found only by searching the literal phrase
"organic building generation", which no entry in the store contains: Green, Salge
and Togelius fill a 3D volume by constrained growth and cellular automata, then
produce organic buildings complete with rooms, windows and doors
([arXiv:1906.05094](https://arxiv.org/abs/1906.05094)). **Its grammar is the
inverse of this one** — grow a solid, then *carve* — and carve-after-grow is
exactly what a player-drawn wall needs.

The cosy organic village builder is shipped as **Tiny Glade** (Steam app 2198150,
Pounce Light, 23 Sep 2024); "Little Glade" was its earlier name and returns
nothing on Steam's index, so future entries should use Tiny Glade. In the
publisher's own words: "gridless building chemistry", "Draw a path through a
building? A door pops up! Raise the building? Columns and beams line up to
support it", "There are no wrong answers or failure states", and "Ivy envelops
your buildings". Four consequences, none of which this project has a rule for:

- **Reactive assembly belongs in the plan stage.** A drawing tool makes a mark; a
  separate stage turns marks into structure. Inferring during mesh emission leaves
  nothing to check the inference against. The reverse direction already exists
  here as a good check — a front door promises an entry route.
- **Support is inferred bottom-up and re-derived on every edit.** `grounded()`
  proves every mass touches its declared ground; it cannot express "held by these
  columns", because nothing here models a column as anything but a mass.
- **"No wrong answers" is a generator contract.** It needs a repair pass that
  cannot fail, a soft score, and a ban on a "budget exhausted" flag. This
  project's stack assumes rejection is available, so reused as-is it emits
  nothing, which a toy forbids. The mutation-first test idiom also needs a
  different negative control, because a family with no failure state has no
  defect to break.
- **Vegetation on a wall is the cheapest not-a-box signal available.** The
  measurement substrate exists and is tested; only the attachment is missing.
  Zero hits for ivy, vine, creeper, climber, foliage or overgrowth.

The seven drafted entries are at `Procedural/buildings/organic-mass`; the working
is in [the audit](KNOWLEDGE_AUDIT_BUILDINGS_BIOMES_FORESTS.md#8-proposed-branch-proceduralbuildingsorganic-mass).

## 11. Proposed book chapters

1. Semantic briefs, seeds, and reproducible variants.
2. Site morphology, terrain, roads, water, and parceling.
3. Building programmes, room graphs, doors, stairs, and visibility.
4. Architectural families across regions and periods.
5. Shape grammars for masses, facades, roofs, and openings.
6. Mesh construction, material slots, UVs, topology, and LOD.
7. Procedural props and measured asset catalogues.
8. Furnishing and exterior dressing by functional constraints.
9. Village economy, services, edges, fields, and vegetation.
10. Biomes as climate fields, and forests as layered composition.
11. Organic massing, reactive assembly, and the no-failure contract.
12. Validation, repair, mutation tests, performance, and visual review.
13. Impossible geometry, impossible circulation, and fantasy structure.
14. Architectural composition and context-sensitive design rules.
15. Exterior and interior design from large forms to lived-in detail.
16. Permissively licensed implementation studies and attribution.

Chapter 11 is the one this project is weakest at, and the audit is specific about
why: no test or check file references a `Camera3D`, there is no image comparison
anywhere, and `src/ui/studio.gd::_frame` — the function that decides what a
viewer sees — is itself untested. Every visual assertion in the repository is a
human looking at a PNG. `tools/render_shots.gd` already holds the right principle,
reusing the same fixture rows the landmark suites build because a render is
documentation and documenting a house that would fail its own checks is worse than
not documenting one. What is missing is turning *documented* into *compared*.

Each chapter should pair a general algorithm with one BigGlade case study,
an alternate building tradition, a failure example, and a measurable exercise.

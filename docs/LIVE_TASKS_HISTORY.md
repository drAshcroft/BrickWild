# The LIVE programme: what it established

The LIVE-* tasks (2026-10-06 to 2026-10-26) turned "pins fixed" into
"inhabited buildings": rooms planned around activities, furniture in complete
groups, real hearths, sacred interiors with real structure, and a visual
evidence trail. This page is the manual they leave behind. It keeps the rules,
where the evidence lives and what was left open. Per-task narration is not
kept.

Related records, not repeated here:

* [FAMILY_STYLE_LEDGER.md](FAMILY_STYLE_LEDGER.md): the 149-row coverage
  ledger of every published kind, style and purpose, with its evidence-state
  rules. It is a living document, not a gate.
* [INHABITED_BUILDINGS_PLAN.md](INHABITED_BUILDINGS_PLAN.md): the original
  plan, the design contracts and the review rubric.
* [BUILDING_PERSONALITY_BRIEFS.md](BUILDING_PERSONALITY_BRIEFS.md): the briefs
  and, since 2026-10-24, the named traits for each style.
* [PERSONALITY_PROGRESS.md](PERSONALITY_PROGRESS.md): the dated evidence log
  from 2026-10-06 to 2026-10-14.
* [TODO_REVIEW_2026_10_13.md](TODO_REVIEW_2026_10_13.md): the 13 October
  furnishing and hearth closures.
* [LIVE_WITCH_HISTORY.md](LIVE_WITCH_HISTORY.md), [WITCH.md](WITCH.md): the
  witch hut. [HOUSE_STYLES.md](HOUSE_STYLES.md): the HS-* trait reviews.
  [SHOPS.md](SHOPS.md): the counter-trade checklist.
  [SACRED_REVIEW.md](SACRED_REVIEW.md): the sacred families.
* [FLOOR_SEAT_NAVIGATION.md](FLOOR_SEAT_NAVIGATION.md),
  [API_QUICK_PARTITIONS.md](API_QUICK_PARTITIONS.md),
  [PLACEMENT_QUICK_PARTITIONS.md](PLACEMENT_QUICK_PARTITIONS.md),
  [VISUAL_DESIGN_TARGETS.md](VISUAL_DESIGN_TARGETS.md).

The verbatim pre-rescope notes of LIVE-SACRED, LIVE-HOUSE-STYLES, LIVE-SHOPS,
LIVE-FAMILY-STYLES, LIVE-REVIEW, SACRED-IDENTITY and SACRED-BASILICA-FOCUS
were in an earlier file of this name. It was removed in the 2026-10-26 repo
cleanup. Read it with `git show ae76e3a^:docs/LIVE_TASKS_HISTORY.md`.

## The rescope of 2026-10-24

The open-ended tasks never closed. Their acceptance said "recognizable",
"believable" or "every published style" with no list of traits, and their
reviews could return needs_changes forever. The user rescoped them:

* LIVE-REVIEW and LIVE-FAMILY-STYLES were retired (skipped). The ledger stays
  as a record. Its one concrete defect became SHOP-PALACE-BANNER.
* LIVE-HOUSE-STYLES became one trait task per style (HS-*), plus LHS-STAIRS
  and LHS-FALLBACKS. Closed 2026-10-26, each style with an independent tick in
  HOUSE_STYLES.md. Residue: HS-*-RESIDUE, CULTURE-FURNISH-VOCAB.
* LIVE-WITCH became a small 7 x 9 m hut with four sub-tasks. Closed
  2026-10-25. Residue: WITCH-REVIEW-FOLLOWUPS.
* LIVE-SHOPS became a four-point checklist over 11 counter trades: counter
  visible from the customer door, trade wares on display, a staff work station,
  a store off the work area. Closed 2026-10-24; misses are SHOP-*-TRAITS and
  SHOP-STORE-VIEW.
* LIVE-SACRED closed 2026-10-24 on six measurable sub-tasks (SACRED-ZIGGURAT-
  FOCUS, -ROTUNDA-FOCUS, -BASILICA-FOCUS, -IDENTITY, -ROMANESQUE-LARGE,
  -BYZANTINE-DOME).

**Rule.** A design task needs three to five named traits per style, each
measurable, one independent tick-box review, and one new task per miss. A
concept board is a guide, not a target. A task gated on a review that may
never pass is not a task.

## Briefs and baseline (LIVE-BRIEF)

* Nine family briefs and the 81-row public style inventory. Frozen requests:
  seed 1 plus two other seeds, small/default/large, recorded before tuning
  (`visualQA/personality/frozen_requests.json`, `baseline_requests.json`,
  `pin_status.json`, `style_inventory.json`; the inventory is stale).
* Historical pins are labelled fixed, reproduced or unverified with evidence.
  Do not reopen a fixed pin without a current reproduction.
* No pin count or density score stands in for design approval.

## Room planning and thresholds

* **LIVE-ROOMS.** Ordinary house styles plan from an authored
  `domestic_program`: activities and privacy decide the room graph before
  rectangle packing. Explicit trades keep the legacy programme; converting the
  innkeeper broke it. An impossible brief replans or reports failure; it never
  silently becomes an unfurnished rectangle. Entrance hall and eating hall are
  distinct; bedrooms have protected access. Narrow-room corner storage slides
  along the long wall to keep passage clearance.
* **LIVE-THRESHOLDS.** The plan reserves a full stair run, integer steps, end
  landings and a continuous 0.9 m carrying route before furniture. An
  infeasible stair is recorded and emits neither a flight nor a nav edge.
  Ordinary interior doors are 0.95 m wide with 2.1 m finished headroom. Door
  and landing clear floor may be shared; flights, wells and guards may not.
  The threshold mesh probe (both directions, three lateral positions, three
  body heights through assembled triangles) supplements the walk grid; it is
  not capsule physics.

## Furnishing: groups, surfaces, navigation, storage

* **LIVE-ASSETS.** The owned wood/iron palette is in
  [INHABITED_ASSET_PALETTE.md](INHABITED_ASSET_PALETTE.md). A keyword hit is
  not a suitable period model; say a role is unavailable rather than
  disguising it with an arbitrary prop. Its "tall nightstand as storage" note
  is superseded by the clothes-storage rule below.
* **LIVE-GROUPS.** Cooking (prep, heat, storage, water), sleeping (protected
  bed access, bedside surface, storage, light) and eating (table, seats, use
  zones) are complete groups. A required function may not disappear into an
  optional roll or a nav repair: bounded retry, or an honest unsatisfied
  brief. A reduced table or prep footprint keeps adult working height through
  `PropCatalog.placement_height_scale` (uniform scaling once put a tabletop at
  0.504 m, chair-seat height). A trial placement must not apply elevation
  twice; a floor-height assertion guards it. A 7 x 7 m two-room cottage cannot
  seat its dining group; that is an architectural limit, not a furnisher bug.
* **LIVE-SURFACES.** Every reviewed wall has one role: opening, structure,
  activity support or quiet surface. Each activity room keeps one deliberate
  quiet interval (`house_plan_features.gd`); reservations are clipped to each
  already-clear span. Wall hosts follow the surviving activity anchors.
  Reading binds a measured bedside support, a supported book and a task lamp.
  Timber bays follow the facade stations. Uniform clutter is not acceptance.
* **LIVE-FLOOR-SEAT-NAV, LIVE-NAV-REPAIR-PRESERVE-GROUPS.** A chair hosted by
  a table still stands on the floor. NavCheck filters by the catalogue's
  floor-blocking and mounted status, not by the host index. Room-end repair
  acts only on failures that room caused. Global repair trials hosted floor
  pieces, appends named unreachable items beyond its size cap, and prefers
  optional losses, then complete repairs, then smaller losses. Details and
  tests: FLOOR_SEAT_NAVIGATION.md. The stair-foot check
  (`HouseFurnisher._keep_the_stair_foot_reachable`) is the same idea for the
  flight approach (PERSONALITY_PROGRESS.md, 2026-10-14).
* **LIVE-SLEEP-CLOTHES-STORAGE.** Closed clothes capacity belongs to Cabinet
  and Chest_Wood and scales with measured size (`PropCatalog.clothes_capacity`).
  An open Nightstand_Shelf never counts. QA re-derives the clear opening and
  standing space. Base-HouseSpec innkeeper guest rooms need bed, low head-end
  stand and a closed cupboard. The Cabinet glTF has its fittings on raw +Z;
  `face=PI` turns them to the use zone.
* **Dining tuck.** Tucked seat candidates use long sides only; the innkeeper
  parlour reserves its table with two matching seats.
* **LIVE-TOWNHOUSE-OFFICE, LIVE-TOWNHOUSE-WRITING.** Small Townhouses invent no
  office. Default and large ones have a desk with Chair_1 centred on its long
  edge, the ledger placed from the chair's facing, and records facing the
  desk. Measured: Chair_1 seat 0.5011 m, desk top 0.76075 m. Book rows on
  Bookcase_2 name a real shelf board and are checked against its upward
  triangles. A chair and a supported book are not yet an office.

## Hearths

* **LIVE-HEARTH-MESH-CONTRACT.** A recessed fireplace mouth is not missing
  front-face masonry. The centre-plane probe was wrong; collision, backing and
  surround checks stayed. 24 false probes went; 18 real complaints remained.
* **LIVE-DOMESTIC-HEARTH-DESIGN, LIVE-HEARTH-TENDING.** The native fireplace
  has no proxy furniture row, so prep-to-heat reach uses the measured
  structural breast. Ordinary breast: up to 1.90 m wide within the clear wall
  span, 0.72 m deep. The firebrick backer sits 60 mm roomward of the shell's
  lower band (25 mm clear in Cottage/Farmhouse, 85 mm in Thatch); the pale
  strip behind the fire was shell geometry. Dark reveals keep a 2 mm face
  separation. One plan-owned tending patch keeps the cooking Workbench and
  hosted Pot_1. Every fire needs an emitted chimney outlet.
* **Witch hearth.** The lower chimney once projected 35 cm into the firebox.
  Shared mouth dimensions now cut only the intersecting chimney masonry. The
  cooking Cauldron sits in a measured stone recess on a 0.14 m seat. Before
  the 7 x 9 m clamp, default and large plans had two Cauldrons (cooking in the
  hall, witchwork in the Workshop): identify a station by measurement, never
  by the first matching node.
* **LIVE-HEARTH-FUEL-READABILITY.** Split billets need thick irregular cut
  profiles, dark bark and broad contrasting cuts, with outward-wound caps
  (Godot fronts are clockwise; no double-sided material). Use unequal narrow
  flame tongues, not cones. Triangle counts do not prove recognition.
* A fixture that reads scene-global transforms before the node enters the
  tree is invalid. Start it deferred and cache the transforms.

## Sacred interiors

* **LIVE-SACRED-ENTRY.** Ziggurat forecourt paving joins the chamber
  entrance; the first occupied chamber keeps 2 m headroom.
* **LIVE-SACRED-BASILICA.** A raised nave, lower aisles, a supported pronaos
  and real clerestory openings, with bearing checks and broken controls.
  Vertical gable slabs extrude along their normal, not in-plane.
* **LIVE-SACRED-BASILICA-EAVES.** At an actual bearing, omit the duplicate
  roof side face; keep roof skins and supports. `MeshKit.slab_poly`
  `open_edges` are source-edge indices and must survive polygon cleanup and
  winding normalisation.
* **LIVE-SACRED-CHURCH.** Nave frames, crossing towers and hollow domes on real
  bearings; open annular ambulatory floor and roof. A string course is named
  perimeter trim split at openings, never a slab across the nave. Check
  populated logical material slots (Nordic timber has its own), not surface
  counts. A bearing-removal control removes the bearing and keeps the wall
  base.
* **LIVE-SACRED-CHURCH-BAYS.** Lower nave and aisle lights follow the
  structural bays; no duplicate piers at buttress stations. Controls remove an
  exact named-component multiset, never a region of triangles.
* **LIVE-SACRED-CHURCH-ARCADES.** Bay openings pass through the nave wall and
  every adjoining aisle wall, on supported piers with floor continuity. Never
  paint a decorative arch over a closed aisle. Prove it with body-height
  cross-wall rays and an inserted-wall negative.
* **LIVE-CHAPEL-PASSAGE.** Remove only connected radial chapel end caps; cut
  the annular host face with jamb and head returns; keep threshold and chapel
  floors continuous. Unsupported arrangements stay closed.
* **LIVE-SACRED-ROTUNDA.** A true circular drum: a lower continuous drum, an
  open upper arcade whose piers bear on the drum panel crowns, and a shallow
  annular roof with a real oculus. Rectangular overlap rules misread adjacent
  curved walls; measure the oriented panels instead of suppressing the check.
  Wall-hit and brazier witnesses derive from emitted panel bounds. The
  roofquick oracle follows the emitted annular roof.
* **LIVE-SACRED-PYLON.** Court depth `max(4 m, 40 % of interior depth)`,
  capped to keep the hall and shrine. First column row 1.4 m inside the hall.
  Paired battered towers 22 % of site length, clamped to 4-6 m; they replace
  the front piers. The sanctum reserves return-wall thickness and full
  lower-dais tread growth. Face probes are body-height horizontal rays outside
  the stone; the portal lintel sits above the ritual sight line
  (`temple_geometry.gd`).
* **LIVE-MESH-SUPPORT-EDGE, LIVE-WALK-FLOOR-EDGE.** Shared floor edges and
  vertices count as support (inclusive metric containment). The walk grid
  closes floor-only seams within `WalkGrid.FLOOR_COVERAGE_EDGE_EPS`
  (0.00005 m); gaps, pits, obstacles and step levels stay.

## Rendering and evidence

* **LIVE-RENDER-CAMERAS.** Eye stations come from reached WalkGrid cell
  centres with measured prop clearance; sacred axis cameras from reached floor
  stations. Sacred body clearance is not measured. A room-filling prop is the
  negative control. `tools/render_house_style_gallery.gd`,
  `tools/render_sacred_acceptance.gd`.
* Every capture records source fingerprints at start and end.
  `source_changed=true` makes the capture diagnostic only. The sacred renderer
  hashes every GDScript under src/core/qa/tests, so any concurrent edit
  invalidates it.
* A render tool's output argument needs the `--` separator; without it the
  images go to the default destination.
* Compare failures by identity against a clean baseline (diff the FAIL
  lines). Equal totals hid eight new storage complaints replacing seven old
  ones.
* A combined lane that times out is not a pass. Bounded partitions with a
  coverage-union validator are: see API_QUICK_PARTITIONS.md and
  PLACEMENT_QUICK_PARTITIONS.md (`tools/*_partition_driver.gd`,
  `tools/validate_*_partitions.ps1`).
* **LIVE-API-SCENE-LIFETIME.** A suite frees every scene it instantiates;
  264 passing assertions still produced renderer leak ERRORs at exit.

## Where the visual evidence lives

Tracked, under `visualQA/` (git stores the capital; Windows also answers to
`visualqa/`):

* Concept boards: 21 `targets/design_board_v1.png`, each with `prompt.txt` and
  a README of limitations, under `visualQA/styles/<family>/<style>/`, room
  boards under `rooms/<function>/targets/`. Families: all twelve house styles,
  Cottage cooking and sleeping, Townhouse work and circulation, the Townhouse
  bakery shop, Gothic, and the basilica, pylon and rotunda temples. Index:
  `visualQA/styles/index.html`, `target_index.json`.
* Actual renders: `visualQA/styles/house/<style>/renders/<run>/`, indexed by
  `visualQA/styles/house/index.html`, `render_index.json` and
  `assistant_review.json`. Named runs: `target_comparison_restart23` (eight
  styles), `fire_composition_restart44`, `firewood_restart48`,
  `hearth_stone_20261013_v2`, `witch_recess_20261013_v2`,
  `office_activity_restart42`, `office_nav_restart50`,
  `nav_inventory_restart56`, `nav_group_repair_final_20261009`,
  `writing_20261013_v2`, `innkeeper_20261013_v4`. Gothic chapel runs are under
  `visualQA/styles/church/gothic/renders/`.
* LIVE review records: `visualQA/personality/*_REVIEW.md` (groups, surfaces,
  sacred entry, cameras, basilica, basilica bearings, church structure, bays,
  arcades, hearth mesh, mesh support edge, walk floor edge), with evidence
  folders `brief_evidence`, `room_evidence`, `threshold_evidence`,
  `asset_evidence`, `group_evidence`, `surface_evidence`.
* Archive tool: `python tools/organize_visualqa_renders.py` (dry run; add
  `--apply`). It refuses changed destinations and keeps human ratings.

Untracked, local only (`artifacts/` is gitignored): temple renders and
receipts under `artifacts/personality/resumed/` (for example
`rotunda_fresh_preview`, `pylon_public_review_20261011_retry1`,
`restart5_library_parts`, `restart5_placement_parts`, `witch_heat_*`) and
`artifacts/personality/sacred_acceptance/`; shop renders and plan facts under
`artifacts/goal/LIVE-SHOPS/`. No temple render was copied into `visualQA/`.

## Fixtures removed on 2026-10-26

The repo cleanup (`ae76e3a`) dropped tests that nothing referenced, including
most LIVE native fixtures. Their invariants now rest on the suites and code
named above. Recover one with
`git show ae76e3a^:tests/<name>.gd > tests/<name>.gd`, then run the editor
import. LIVE fixtures among them:

`pylon_native_architecture_test`, `rotunda_native_architecture_test`,
`sacred_structural_contract_test`, `sacred_render_selector_test`,
`temple_circular_public_api_focus`, `temple_ground_entry_contract_test`,
`church_arcade_contract_test`, `mesh_support_closed_edge_test`,
`walk_floor_edge_test`, `meshkit_open_edge_mapping_test`,
`house_threshold_test`, `upper_flight_approach_test`,
`house_activity_groups_test`, `house_activity_coverage_test`,
`domestic_groups_fixture`, `house_surface_host_test`,
`house_sleep_surface_fallback_test`, `house_clothes_storage_test`,
`house_hearth_mesh_contract_test`, `domestic_hearth_tending_test`,
`domestic_hearth_flue_trace_test`, `domestic_hearth_flue_scope_test`,
`witch_cauldron_heat_test`, `townhouse_office_recipe_test`,
`house_personality_camera_test`, `test_visualqa_organizer.py`.

Kept: `house_nav_hosted_floor_test`, `room_local_nav_guard_test`,
`house_nav_group_repair_test`, `domestic_hearth_heat_assembly_test`,
`sacred_basilica_architecture_test`, `witch_firebox_lining_test`.

Decision (owner, 2026-10-28): triage, do not restore wholesale. A removed
fixture comes back only if no current suite fails when its rule is broken.
The work is LIVE-FIXTURE-TRIAGE; record each fixture's outcome here.

## Open at close

* Whole-style visual acceptance was never claimed by any LIVE task; the HS-*,
  SACRED-* and SHOP-* trait tasks own it now.
* Sacred interiors: dark basilica interiors, repeated braziers, plain church
  walls, pale Nordic timber, Rotunda blocky piers, Pylon relief and court
  planting, cult-specific shrine dressing.
* Houses: bare repeated bedrooms, the free-standing hall Cabinet fallback,
  the 29 converted-style layout fallbacks and legacy trade stairs (taken by
  LHS-FALLBACKS and LHS-STAIRS).
* Since resolved: the Romanesque walk-pin z-fight (94 against a budget of 92
  in October) now has a budget of 12 in `walk_pin_suite.gd`.

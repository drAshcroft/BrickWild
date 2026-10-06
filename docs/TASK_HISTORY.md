# Task history

Completed backlog tasks, condensed when the WaterFree todo store was pruned on 2026-10-05.
Durable lessons from these tasks went into the WaterFree knowledge base under `procedural/buildings/`; KB ids are cited where they apply.
Tasks already fully recorded in another `docs/*.md` file were dropped without an entry here.
Completion dates come from task notes; the store did not record them, so some are missing.

## Houses

### HOUSE-STORIES-001 Add planned multi-story houses with top roofs — date unknown
HouseSpec/BuildingRequest gained 1-3 storeys: floor-aware HousePlan, explicit stair graph with emitted flights/openings, elevated structural bands, exactly one top roof, Studio storey/cutaway controls. Verified library+hmultistory 22/22, house 123/123, houseqa 120/120, installer 266 files, VoxelGames integration 6/6. One-storey output stays deterministic. See docs/HOUSES.md.

### LAY-001 Planner owns the hearth wall; builder and furnisher both read it — date unknown
HousePlan.hearth {room,wall}; HousePlanner._choose_hearth (kitchen>hall>workshop on storey 0, longest unbroken exterior run); builder chimney and furnisher both read it; HouseFurnishCheck._check_hearth plus a 200-house sweep (0 complaints, 1 chimney each). Side incident: a tail rewrite deleted another agent's _check_row body (restored later in INT-001). See docs/HOUSES.md.

### LAY-002 Add per-category affinity block to PropCatalog and an _affinity() scorer used by all four placers — date unknown
PropCatalog entries gained an affinity dict; HouseFurnisher._affinity replaces the randf() term in all five placers, JITTER 0.1 (was 0.5/0.35). Sweep: corner_clutter 96%, sconce_pair 96.2%, chandelier_over 100%, table_focus 89.5%, shelf_over 85.5%. houseqa 570 checks green. Hotel's 15 failures predate it (fixed by LAY-008). See docs/HOUSES.md.

### LAY-003 Grow HouseFurnishCheck's feng shui section from one rule to a dozen, one per affinity — date unknown
HouseFurnishCheck feng shui section grew to ten rules (eight affinities plus hearth and command), each with a hand-built failing fixture (_feng_shui_fixtures) and a 200-house sweep (0 failures, warnings counted). check() returns groups; bed_window warns when no dark wall exists.

### LAY-004 Give the upper storey its own programme: bedrooms up, service rooms down — date unknown
Upper storeys renamed from the stair landing outwards (_name_upstairs) instead of cloning ground kinds; _can_sleep_upstairs guard; stairwell runs along the room's long axis; rule upstairs_programme in house_plan_check. Shops/hotels with room_program keep the clone. See docs/HOUSES.md.

### LAY-007 SLEEPING kinds list; privacy check refuses to walk through any sleeping room — date unknown
HouseGeometry.SLEEPING = bedroom, guest_room, suite; the privacy check refuses all of them, landed before the hotel fix so it was proven to catch it. At that point hotel_test showed 15 failures (privacy plus hearth-without-chimney), cleared by LAY-008. See docs/HOTELS.md.

### INT-001 A `row` placement rule in HouseFurnisher: N copies along an axis at a pitch with a shared use zone — date unknown
HouseFurnisher._place_row (n range, pitch, aisle, along wall/axis, seat_clearance), HouseFurnishCheck._check_row (collinear 0.05 m, pitch 0.02 m, aisle >= PATH_MIN), dining_room trestles use it; _row_fixture in house_qa_suite. house 123/123, houseqa 323/323. Concurrent agents' Godot contention forced isolated runs.

### INT-002 A `focus` on the HousePlan that placers score toward and checks read — date unknown
HousePlan.focus {room,cat,pos,facing,faces_door}; HousePlanner._choose_focus (hearth), ShopSpec.BUSINESSES focus; furnisher _pin_bonus/PIN_W/FACE_W; check rule focus (0.3 m position, 45 deg to door, Sightline warning). TempleRiteCheck carries a pointer comment.

### Add medieval shops and civic buildings — date unknown
13 plan-first businesses (blacksmith, stable, food and retail trades, town hall, guildhall) with public API and Studio support, shared house QA recipes, shop contract/archetype suites, addon packaging. See docs/SHOPS.md.

### Build a Grand Budapest-inspired procedural hotel l — date unknown
Grand Budapest-inspired hotel family: symmetric pavilion facade, mansard roofs, dormers, corner cupolas, balconies, ceremonial entrance, furnished interior plan, Studio/API integration, landmark QA. See docs/HOTELS.md.

### LAY-005 Stair against a hall wall, out of line with the front door, and a check for it — date unknown
HousePlanner._stair_spot slides the well along walls clear of door swings, door line and windows; may slide the front door; stair_line rule in HousePlanCheck. Sweep of 200 two-storey houses: 200/200 against a wall, 199/200 out of line, 198/200 halls keep a table.

### LAY-006 Two-pole privacy gradient (front/service) and no front-to-back door alignment — date unknown
HousePlanner.KIND_POLES front/service weights; back door goes to the kitchen at the far end of its wall, omitted if it cannot clear the front door's line; doors_in_line rule. Sweep: kitchen 197, store 3; kitchen on back wall 200/200; 0 doors in line.

### LAY-008 Hotel gets a real plan: a double-loaded gallery corridor with rooms off both sides — date unknown
HotelPlanner rewritten as a double-loaded gallery (2.6 m) with front and back ranks, two facade bays per room; HotelQA gallery and bays rules; hotel and hlandmark pass. See docs/HOTELS.md.

### LAY-009 Shops get a focus fixture, a door width and a shopfront: BUSINESSES gains door_w, front_open, focus — date unknown
ShopSpec.BUSINESSES gained door_w (stable 1.5, blacksmith 2.4, shops 1.0), front_open hatch (bakery, butcher, apothecary, general store, tailor) and focus; forge before anvil, tavern casks near the counter; shopfront_rules in archetype suite. See docs/SHOPS.md.

### LAY-011 Lights that light: every LIGHT-tagged prop gets an OmniLight3D in the shared assembler — date unknown
core/light_kit.gd creates an OmniLight3D per LIGHT-tagged prop at the measured light offset (catalogue records top centre of AABB); HouseAssembler.furnish is the shared path for house/shop/hotel; TempleAssembler uses it too. KNOWN_ISSUES 0d removed. Roof-on render check not done (needs non-headless render). See docs/HOUSES.md.

### INT-014 (GEO-002) - polygon rooms
Optional room outline is the truth, rect stays the bounding box; additive so all families unmoved. Walls per edge, floors via MeshKit.slab_poly, furnisher and walk grid read the outline. Commit ac1e559.
### INT-015 (GEO-003) - courtyards in HousePlan
HousePlan.courts; court = floor/sky/outside; qa/court_check.gd; court roofs as per-range plates; door_graph joins rooms on one court. Commit 5af15b3.
### INT-016 - negative storeys
HouseSpec.cellars (0..1), pit_-1 dug mass, per-mass ground level in MassRules.grounded; archetype cellar_house (storeys -1..1) 0 defects.
### LAY-012 - inn privacy
ShopSpec gains a gallery third with corridor_at 5; ShopPlanner._open_up_lodging repair; sarchetype 52 checks (was 13), 0 failures.
### HOUSE-EXT-005 - component log (2026-09-17)
core/mass_builder.gd component_log (box/slab/note), stable role#n ids, hosts roof/dormer_N/porch/frame_N. See docs/HOUSE_EXTERIOR_TASKS.md, HOUSE_ROOF_FIX.md.

### HOUSE-EXT-007 (dormer openings and joins) - 2026-09-17, commit 9cabc81
Dormer geometry was already correct (accepted face/storey/opening records, cuts through all host slab layers, slope-intersecting cheeks and rooflets). This task added the durable contract and checks.
One roof-hole schema: {id, kind, storey, face, polygon (roof-local XZ), room}. HousePlan.roof_openings is the AUTHORED slot (compluvium, oculus, court sky) and stays empty; INT-018 owns it. HouseGeometry.roof_openings(plan) is the merged view (authored + fitted dormers), derived per call, never cached.
Refused candidates are recorded. See docs/HOUSE_ROOF_FIX.md, docs/ROOF_REGION_CONTRACTS.md.

### HOUSE-EXT-009 (exact exterior bounds) - 2026-09-17, commit 36fb53a
total_height missed 1.33 m of chimney (CHIMNEY_CLEAR 0.6 + crown 0.18 + pot 0.55) and the cottage finial (0.495 m, emitted only with bargeboards on a full gable). plan_extent assumed the chimney on +X whatever wall the hearth used.
Added HouseGeometry.exterior_bounds(plan) -> AABB, exact to within 5e-4 on seeds 4413/4411/4414/4412, no looser than BOUNDS_TOL 0.16; a spec-level bound also exists. Cameras, placement and lot checks should ask for it.

### HOUSE-EXT-016 (exterior QA integration) - 2026-09-22
Runtime HouseQA now composes actual component triangles, envelope planes, coverage, conflicts, gable bearing, opening and trim clearance, bounds and real jetty checks. Independent hjetty/henvelope/hsky actual-mesh mutation fixtures reject missing, retracted, floating, crossed and duplicate geometry.
Evidence: lane:geom 6955 pass; hjetty/henvelope 226; hsky 18; court 105 pass; houseqa 258 + harchetype 34. Artifacts under artifacts/roof_fix and artifacts/p1p2_house/comparison.html (40 matched pairs). Obsolete polygon code forced stopping an old harchetype log, so a whole-old-log pass was not claimed.

### Tiered house/roof tests (fast vs exhaustive lanes)
No production change. Added roofquick (2452 checks, 2.64 s), hotelroof smoke, houseqacore/plan/furnish, quick houseqa (24-case deterministic sweeps, 16 variety pairs) and houseqafull (original 200/40/all-size populations). Known full-only baseline for seed 60068 is a warning only when the complete message matches. Documented in AGENTS.md and docs/QA_FAST_PROTOCOL.md.

### Mesh integrity for every HouseBuilder surface - 2026-10-02, commit 863c15c
qa/mesh_integrity_check.gd (no class_name, preloaded by HouseQA) checks finite data, malformed arrays, degenerate triangles and winding; hmesh suite, 12 checks, 35 s, in lane:geom (9196 checks / 11 suites / 277 s). Proves face integrity only.

### INT-018 roof openings — 2026-09-21
Plan roof openings `{storey, room, rect, kind: compluvium|oculus|open}`; HouseGeometry normalizes (oculus = 24-gon), HouseBuilder subtracts from RoofShape faces, splits ridge_cap, emits roof_opening_log. CourtCheck.sky/water and RoofOpeningCheck probe the cuts. hsky+hroof+hopening 774 checks, 0 failures. Renders: artifacts/renders/sky_openings. KB 92fcc188.

### INT-011 throne hall / palace — 2026-09-30 (commit 65d0002)
Antechamber, throne room, treasury, royal chamber on the plan.focus axis, throne on a dais, banners. Palace selector 6 checks, 0 failures, 9 retained warnings (daylight in huge ceremonial rooms; throne chair not tied to a table).

### INT-017 colonnade wall kind — 2026-09-30 (c9f5804, 0e7f5d2, af5b070)
Market-hall open-sided walls with a solid entrance portal split, posts planned equal emitted, lintels not ground-bound. First run failed 26 checks; final markethall selector 1 fixture, 0 failures, 35 s. KB d04da68c.

### DMV-EXPORT-002 — 2026-09-30
tools/export_building_plan.gd writes a BuildingPlan JSON (rooms in SITE coordinates, doors, stairs) for one building of a SitePlan; contract Dm_View c2-building.md. All 8 supported interiors of a 30-person village export deterministically with containment and front-door reachability; rotated two-storey townhouse passes. Church/castle/temple/timber-hall lack a HousePlan and return structured unsupported_interior rather than invented plans (task stayed open on that escalation). See docs/PUBLIC_API_TRANSPORT.md.

### DMV-BRIEF-001 — 2026-09-30
VillageSpec accepts an external C1 SiteRequest (population, regime, wealth, culture, tongue, terrain, mythsim city['built']). Outgoing enclosure string preserved, enclosure_kept_fraction exported separately; tests pick brief-authored requests by stable seed. dmvbrief 19 checks, 32 s. Commits 15d33c4, 7830ee2. KB 7237e5d2.

### harchetype one_room_cottage bed at scale 1.00 — 2026-09
Pre-existing failure (bed is WALL_ESSENTIAL, no wall took it, no compromise recorded). Fixed so all four canonical one-room cottage sizes keep full-length beds. Final houseqa 258 + harchetype 34 = 292 checks, 0 failures, 43 existing warnings; assets 489 pass.

### houseqa feng shui seed 60068 longhall/alchemist — 2026-09-22
shelf_over missing for the workshop bench; existing 6 cm mounted-station fix plus durable HouseQASuite._seed_60068_shelf_over regression and tests/furnishing_regressions_test.gd. No threshold changed.

### HOUSE-EXT-012/013 jetty — 2026-09-22
Real upper-storey jetty: optional storey args on HouseGeometry site_rect/interior_rect/exterior_runs; all upper floors share one front extension, ground/cellar unchanged; upper rooms grow before window fitting; PlanFamily footprint includes upper rooms. Emission (floors, walls, framing, roof/dormers, bressummer/joists/brackets) follows the storey envelope; ground hearth flue avoids jetty front. hjetty 198 checks, hmultistory 210 checks, geom 6955 checks. KB fa0c2c7b.

### HOUSE-EXT-014 roof/glazing materials — 2026-09-22
Four surfaces kept (including cutaway); vertex marker selects fixed blue reflective glazing; house-only shader draws shingle/slate/thatch from spec.roof_material with no extra RNG; slab metre UVs. hmaterials 470, component 1526, geom 6955, all clean. Headless keeps base materials (dummy renderer). KB 1cd4bda1.

### HOUSE-EXT-015 — 2026-09-22
Documented five-style silhouette/material intent; generator scales broad-span pitch by style reference span (witch hut gentler taper), jambs set stud bay rhythm. 40-pair comparison sheet (5 styles x 4 sizes x 1/2 storeys) with numeric roof-rise ratios (tools/render_house_roofs.gd --matrix, tools/house_art_report.py). Art targets are preferences, not structural caps. See docs/HOUSE_EXTERIOR_COMPLETION.md.

### EVAL-C06, EVAL-B06, EVAL-U02, EVAL-C12 — 2026-10-01
C06: courtyard ranges subdivided into rooms glazed onto the court (court had 454 warnings). B06: house yard, fence, woodpile, cart dressing (c15b7dc); no chicken/hay prop; village lot allowance 1.5-2.0 m is narrower than yard apron 2-3 m. U02: Studio draws the house blueprint sheet; dormers, colonnades, courtyard roofs not drawn in elevation. C12: farmhouse seed 21100 chimney in back door fixed in HousePlanFeatures. See docs/EVALUATION_2026-10-01.md.

### INT-012 / INT-013 / INT-021 — 2026-09-30
INT-012: thieves_den with HousePlan door `secret` flag (commits abb1d24, d9c6489); int012 7 checks; optional thievesden100 scheduled. INT-013: recipe-only alchemist, bathhouse, hospice, school (462a08e, 17e85f4); int013 16 checks, 128 s. INT-021: BuildingRequest orientation and period metadata, placement north in local frame (3d28d1e, 0663deb); int021 20 checks, 280 s. KB entries exist for each.

### Workbench_Drawers review — 2026-09-30
Workbench_Drawers is a 0.42x0.24x0.30 m insert (CC0 Quaternius), reclassified non-placeable workbench_insert (d920f2e); no catalogue change.

### CULTURE-CAPTURE
GPU renders, 12 images: exterior, entrance and cutaway for Mediterranean, Asian, thatched and Pueblo houses, with native API and vernacular QA records.

## Castles

### CAS-001 plan_kind on CastleSpec and a polygonal enceinte in CastleGeometry (rect is N=4) — date unknown
CastleSpec plan_kind/sides with its own RNG; CastleGeometry.enceinte_polygon (rect = N=4), wall_segments, vertex towers, inner_polygon, etc.; CastleBuilder poly wall emitters. Forced-rect mass-log dump of all 84 sweep castles byte-identical to baseline; 18 of 84 became polygonal. castle/cnormals/cmassing/clandmark/cvoxelqa all pass, 392 checks. See docs/CASTLES.md.

### CAS-002 A great_tower slot: one corner tower 1.5-2x the others, and a massing rule that wants it — date unknown
CastleSpec.great_tower/great_tower_scale (1.5-2.0x across, height x(1+0.75(s-1))) from its own RNG; per-vertex tower sizes through CastleGeometry; massing rule great_tower (one tallest by >=1.3x). Caernarfon Eagle Tower 28 m at 100%, Alhambra Torre de la Vela 26.8 m. See docs/CASTLES.md.

### CAS-003 Courtyard-side windows on hall and chapel, and an apse on the chapel — date unknown
Hall and chapel get courtyard-face windows (RANGE_BAY 3 m) and nothing through the curtain; chapel apse (half-drum plus half-cone) shrinks to fit the ward polygon or is dropped with a warning; massing rules hall_windows and chapel_apse.

### CAS-005 Plan kind: motte and bailey (mound + shell keep, separate lower bailey) — date unknown
plan_kind motte_bailey: bailey rect, truncated-cone motte (batter 30-40 deg, 6-15 m), oval shell keep (MeshKit.oval_ring), climb wall grounded at its foot; massing rule motte. Windsor forced to motte_bailey with Round Tower 30.5 x 27.5 m. Per-mass ground level (INT-016) was not needed.

### CAS-006 Plan kind: tower house (house tier grown upward, L or Z plan, no curtain) — date unknown
plan_kind tower_house (height >= 2x longer side): stacked storeys with thicker foot walls, platform, raised door sill >= 2 m, L/Z jog; qa/tower_check.gd (slender, lift, foot, no_gaps, grounded) with tampering fixtures. Landmark merchants_tower 8x8x45.

### CAS-007 Plan kind: ridge castle (ranges along a polyline spine, towers at the bends, no bailey) — date unknown
plan_kind ridge: 3-6 point spine with 15-45 deg bends, one rotated range per segment, towers at vertices, no enclosure; massing rule ridge. Neuschwanstein forced to ridge: spine >= 120 m, great tower 65 m.

### CAS-011 Ten new landmark rows in docs/CASTLES.md and the landmark suite — date unknown
Ten rows in docs/CASTLES.md and castle_landmark_suite (Tower of London, Conwy, Carcassonne, Malbork, Castel del Monte, Edinburgh, Eilean Donan, Caerphilly, Dover, Mont-Saint-Michel). Five pass at 40/70/100/150%; Conwy, Malbork, Edinburgh, Eilean Donan, Caerphilly, Mont-Saint-Michel carry EXPECTED_FAIL with the blocking reason. clandmark 92 checks. New CastleSpec.keep_offset.

### INT-003 Castle great hall as a HousePlan: dais, high table, trestle rows, hearth, screens passage — date unknown
CastleGenerator.hall_plan(spec) returns the hall as a single-room HousePlan (kind great_hall, MIN_AREA 16, MIN_SIDE 3.0); plan.dais {room,rect,rise} 0.4 m up (WalkGrid.MAX_STEP 0.6); plan.zones for the screens passage; plan.hearth on a long wall; high table as focus; great_hall recipe with 'behind' rule and two row steps. WalkGrid gained per-cell levels/add_step; HouseFurnishCheck rule clear, HouseNavCheck rule steps. Committed cf5a980 (note says CAS-010).

### INT-004 (CAS-011) - keep as stacked storeys
CastleGenerator.keep_plan(spec) returns 3-4 stacked one-room storeys in the keep's own frame (store, hall, parlour on a 4-storey keep, lord's chamber on top with bed and hearth on wall 2); one stair via HousePlanner._add_stair. New src/castle/keep_spec.gd (KeepSpec). HouseGeometry.MAX_STOREYS := 4 replaced a hardcoded 3 in four checks. Commit e7ba7b2. See docs/CASTLE_INTERIORS.md.
### INT-006 (CAS-012) - bailey layout
CastleGenerator.bailey_buildings/bailey_shop/bailey_well. BAILEY_ROSTER by tier: castle = stable + restaurant (cookshop); fortress adds blacksmith (smithy) and general_store (granary). Existing ShopSpec businesses reused on purpose. Buildings hug the side walls, yaw +-PI/2, kept off the gate axis strip; _yard_rect shrinks bailey_rect on polygonal castles; yard buildings are 3.2 m single-storey ranges. Commit 1136490.
### INT-007 - stone interior shells, CastleQA composes HouseQA
Hall, keep, chapel and bailey-shop HousePlans emit stone shells; CastleQA groups plan/furnishing/nav reports and walks gate to lord's chamber. Required suites: castle 344, cnormals 84, cmassing 100, clandmark 92, cvoxelqa 84 (704 checks, 0 failures). Evidence: docs/tasks/int007_progress.md, docs/CASTLE_INTERIORS.md.

### RIDGE-ROOF-001 (ridge castle roofs and floating merlons)
Pre-existing defect (identical on b0b6f8a and its parent). Fixed the ridge-only roof/deck envelope in castle_builder.gd. ctroof 1941 checks pass, lane:geom 5939. Required non-headless tools/render_ridge_castle.gd for small/default/large. Broad lane:castle was stopped after 38 min and not claimed.

### Motte tower routes (README Norman motte seed 8856) - 2026-10-03
Completed missing courtyard_network, coping graph and stair/headroom proof. cmotteroute passes: 5 checks, 87.6 s, seven required routes connect through two physically clear stairs. Mesh-only missing-stair, roof-obstruction and omitted-record controls reject. Fixes: gallery junction guards, door wall sill, stair-arrival tower-envelope reservation, per-side previous-floor tracking. See docs/MOTTE_ROUTE_REPAIR.md.

### CAS-012 fantasy castles — 2026-09 (after user visual review)
Wizard tower (tower-house tier, conical cap, balcony ring), dark fortress (black stone, spiked merlons, spire keep), sky citadel (7-8 staggered turret islands, hanging tapered tails, paired ring arches, floating rock rising from a single y=0 point). Fixed oval_ring winding with a semantic normals regression (outer/inner skins and caps face the physical direction); dark ridge roofs stop at tower centres and the central spire replaces its drum. Renders include castle_dark_joins.jpg.

### INT-005 chapel as temple-lite — 2026-09
One nave room plus apse, altar on the axis as idol, benches in rows; shared plan axis/sightline helpers; centre-aisle reservation. Chapel 14 checks, 0 failures; temple+rite+tarchetype 2255 checks, 0 failures, 11 known warnings. See docs/CASTLES.md.

### VIS-009 — 2026-10-01
Ridge/chateau hierarchy (f1ba781, 9985143): principal/secondary ridge cadence, measured seated dormers, transformed host roof cuts, range-owned logs; RoofShape.exposed boundary repaired. vis009 12/0/0, geom 6975, castle-change 214/0/5 warnings. Blocked earlier by CAS-REG-004. KB 547afe96.

### VIS-015 — 2026-10-01
Bailey yard programme area-budgeted and measured separately from range furniture (a0f1660, 2fdf7d8): exact arbitrary-yaw PropCatalog footprints, apse/range/well/stair/axis reservations, transport/smithing/training/store zones, blocked-route control. Krak 6002 ward 23918 m2, 140 exterior fixtures on 370 m2; fortress 6003 75 fixtures on 209 m2. vis015 26094 checks, 123 s. KB ec6fa5aa.

### EVAL-B07 — 2026-10-01
CastleFurnisher dresses sky turret islands (watch brazier, table in largest island, banners); dressing-suite exemption removed; cground 391 checks pass.

### VIS-013 — 2026-09-29 (ef9b1ed)
Fallback round/shell keep gets real facet-cut windows; planned Bodiam/Krak keeps already had 40 windows each. caperture+cgateaccess 88 checks.

## Churches

### VIS-003 metric stone UVs - commit 6b2447c
Metric UVs opt in for church/castle; house UVs unchanged. Swatch checked on box, wall, sloped roof, half cylinder, 12/16-sided drums. lane:geom 6975 checks.

### VIS-004 shared stone and roof shader - commit de66292
One shader for ChurchAssembler and CastleAssembler through ShellAssembler, using VIS-003 UVs; four slots and cutaway roof hiding preserved; subtle courses with low distance noise.

### VIS-005 church host-wall cuts - commit da81cc7
Gothic clerestory and west portals cut through the host wall; twin-tower walls split. Ray fixture 44/44, church 92/92, massing 90/90, blueprint 90/90, landmark 32/32.

### VIS-006 castle slit/window cuts - commit 34e0a09
Straight and polygonal curtain, battered tower facet, square keep shell get true cuts with returns. caperture 34/34, gate access 16/16. Full lane:castle could not pass: cmassing had 16 failures (CAS-REG-001/002/003); exhaustive runs recorded incomplete (QA-PERF-001). Evidence in artifacts/vis006.

### VIS-007 buttresses and flyers - commit 254cf66
Three-stage nave/tower buttresses, corrected twin-tower corner placement, stronger Gothic flyer arch with coping, logged as components. Church/blueprint/landmark 993 checks.

### VIS-011 remaining church windows - commit eb15450
Apse, chapel, drum, tower, narthex and rose window cut through emitted walls. Focused rays 184/184, lane 1308/1308 (three pre-existing Russian warnings).

### VIS-012 church glazing and portal finish - commit fefd4dd
Stone spandrels, leaded-glass shader on marked inner panes, mullion and transom, portal jambs and pointed hoods; portals deliberately open for route QA. Church lane 1052 checks, aperture/load 652.

### VIS-008 / VIS-016 — 2026-09-29 and 2026-09-30
Hagia Sophia shell rounder with continuous faceted support (c07edf4); then curved loft, hero corbel courses and radius-aware bearing height (b45e742..80e00cc), three stepped bands. Florence stays eight-sided. Dome fixture 20/20 then 43/0/0, roof seams 49/49, church roofs 5325. lane:church exceeded 12 min and was recorded INCOMPLETE. KB 30b550e8, cd89a62c.

### VIS-014 — 2026-09-29
Narthex and single axial tower exterior-to-nave routes cut only the relevant host walls (b34b375); churchaperture + churchload 930/930; adjacent piers remain. Broad normals/massing stopped after nine CPU minutes (led to QA-PERF-002).

### EVAL-B03 — 2026-10-01
Florence proportions and clerestory band, St Basil onion cluster, Hagia support collar. Master confirmation: 42 suites, 66960 checks, 0 failures.

## Temples

### INT-019 temple column plan data — 2026-09
TempleGenerator writes the final filtered spec.columns; TempleBuilder, TempleGeometry obstacles and TempleRiteCheck read one list (ColumnGrid). Temple lane 2227 checks (2167 temple + 60 rite), 0 failures, 7 dominance warnings; mass parity asserted per column against mass_log AABB. KB 3fa214b1.

### EVAL-C09 — 2026-10-01
Idol dominance (7 of 60 rite checks warned at 35-40% of room height) and dark starless pylon interior (90% black) fixed.

## Villages

### VIL-001 VillageSpec with derived fields and VillagePlan, the one thing everyone agrees about — date unknown
VillageSpec (population 12-500, culture, purpose, wealth, enclosure, water, seed; derived households round(pop/4.5) +-10%, form, programme, site) and VillagePlan (pure data, no Node3D/Mesh, equals() deep compare). 13-check 'village' suite incl. grep guard. See docs/VILLAGES.md.

### VIL-003 SitePlanner for the `street` and `green` forms: through road, common, streets and lanes — date unknown
VillageSitePlanner for street and green forms: through road first (two-harmonic gentle curve), common, landmark site reserved before lots, then form roads (street: 2 dead-end lanes <=22 m; green: 3-street ring). ROAD_CLASSES table; Poly.ribbon/bend_radius helpers. 'vsite' suite 161 checks over 50 seeds per form. See docs/VILLAGES.md.

### VIL-004 LotPlanner: cut frontages along every road, front edges on the road, corner lots to the more important road — date unknown
VillageLotPlanner: lots per straight road segment, front edge on the offset line, sized from measured footprints via BigGlade.generate()+placement(); setbacks clamped to VILLAGES band (cottage 3, townhouse ~1, farm 7, church 8, manor 22); fire gaps 1.5/6/1; corner-lot rule; landmark and manor get service lanes. See docs/VILLAGES.md.

### VIL-005 Programmer: population -> programme table, house trades and styles by culture, BuildingRequests per lot — date unknown
VillageProgrammer.programme(spec) -> BuildingRequests; thresholds per VILLAGES section 4 (well/60, shrine/20, smithy/30, tavern/40, church+store/60, ...), culture style map, wealth->storeys (1 below 0.3, 2 above 0.6). 'village' suite 1421 checks, 0 failures; grep guard keeps src/village free of HousePlanner/HouseBuilder.

### VIL-002 - placement() contract
BigGlade.placement() returns bounds (full mesh AABB), footprint (walls' outline, per-family source) and door, local space. Footprint/bounds split added after a first `-- placement library` run showed bounds were too wide for lots.
### VIL-006 to VIL-009 - ScaleCheck, RoadCheck, LotCheck, PlaceCheck
qa/village_scale_check.gd (housed +-10%, density 0.05-0.30), village_road_check.gd (10 rules, road_components joins T-junctions), village_lot_check.gd (faces road <= 15 deg, back_to_front < 8 m, variety share 45% when wealth >= 0.55), village_place_check.gd (13 rules; six rules the planners do not yet meet are listed in VillageCheckSuite.PLANNER_FOLLOW_UPS). All fixtured in vcheck. See docs/VILLAGES.md section 9.
### VIL-010 - arrangement pass
VillageLotPlanner.SITING table; vcheck 12/24 bad to 0/24; gradient 7/24 to 1/24, tavern 9/24 to 3/24; 1718 checks pass.
### VIL-011, VIL-012 - props and catalogue
core/prop_kit.gd (ten props, true AABBs, PropKitSuite 'props'). Nature Kit (pack 'nature', 36 models) and Stylized Nature MegaKit (pack 'wild', 68) imported; six dungeon village pieces; catalogue 238 rows, 104 with radii; assets 461 checks.
### VIL-013, VIL-014 - VillageDresser, DressCheck
RECIPES by host with outdoor rules; PALETTES per culture; 12-30 props and 13-88 plants per village. DressCheck 12 rules, vcheck 72 checks.
### VIL-015 - VillageBuilder and VillageAssembler
8-surface builder (site slab, roads, verges, commons, water, bridges, enclosure, gates, built props); assembler adds models, plants and OmniLights via LightKit. village suite 1441 checks.
### VIL-016, VIL-019 - NavCheck, VillageQA
One WalkGrid over the site (cell 0.25-0.5 m, 2-4 s per village), six rules; VillageQA composes six checks plus family QA per building; vcheck 76 checks; residue in PLANNER_FOLLOW_UPS.
### VIL-020 - archetype suite
Twelve archetype rows, 108-case matrix (not run in full by instruction). Thorpe focused run: varchetypecontracts 19 checks PASS; hamlet-only bands pinned by negative controls at population 25. Commit 1976916.
### VIL-022 - village kind in the public API
VillageFamily adapter, 'village' row in BuildingLibrary.KIND_ROWS; width = population, length = wealth percent; library 69 checks (~20 min).
### DMV-EXPORT-001 - headless exporter
tools/export_village_plan.gd, five fixtures, byte-identical reruns, building counts 8/42/49/54/58; VILLAGES 10a.

### VIL-APPEARANCE decoration and upkeep controls
Independent bare-to-lush planting/paint/street dressing, with neglect separate from wealth; API and Studio sliders. Commits 7054dbc, fd62503, 30a52ea (numbered yard groups, purity clone fix), c369512 (comparison renderer/docs). Gates: village-fast+appearance 91 checks (170 s), API 390 (221 s), full-plan appearance 62, material 11. Eight captures under artifacts/renders/building_audit/village-appearance. Detail in docs/VILLAGE_APPEARANCE.md.

### VIL-017 — 2026-09-23
Remaining forms: crossroads, round, strand, planted, gate. True round fans with common-sector ranking and common-facing farms; crossroads corner inn/stable; planted form has a 32 m square, two grid blocks and eight usable stalls; civic frontage depth reserved from native temple stairs. Round0 edge dressing retries smaller cultural trees on a boundary-grazing farm track (edge run 36 m to 6 m). Focused layout 286 checks, canonical five plans 298 checks. See docs/VILLAGE_FORMS.md.

### VIL-018 — 2026-09-30
Enclosure and water: VillageWaterPlan runs pre-lot in SitePlanner for pond/stream/river/coast (Strand coast preserved); VillageBuilder dedups sampled road crossings into one clipped bridge or ford. venclosure matrix 752 checks 0 failures; pure water recheck 201 pass; actual non-headless renders of pond/stream/river/coast accepted. Full 50-seed lot matrix bounded to site plus representative-lot fixture. See docs/VILLAGE_ENCLOSURES.md, VILLAGE_CROSSINGS.md; KB 6880a8eb.

### EVAL-C07, EVAL-B05 — 2026-10-01
C07: vquick had 17 standing failures (path verge, junction spacing, common overlapping roads) fixed; gate form keeps ring/rectangle-corner overlap for the manor lane. B05: village ground, orchard variation, river banks; vformslayout not rerun, reeds near boat aprons and road ribbons under decks unchecked.

## World

### WLD-000 - world family entry
src/world/world_families.gd registry; world kind with family/sub-kind; tests/suites/world_archetype_suite.gd at 70/100/140/190%.
### WLD-001 - courtyard houses
Domus, riad, palazzo on a six-range inward planner; bounded matrix evidence logs; renders under artifacts/renders/world_courtyards/.
### WLD-008 - timber hall on platform
TimberHallSpec/Geometry/Generator/Builder, HallCheck; Great Hall East and Phoenix Pavilion; 46/46 focused, lane:geom 5963 checks.

All focused selectors passed 2026-09-30 with zero failures; evidence in artifacts/qa_fast/<selector>; overview in docs/WORLD_BUILDINGS.md. First-run lessons: KB 620e853d.

### WLD-002 insula — 06142c1, 95f0e7e, 4ee01f4
Tabernae below, flats round a medianum, one stair. First run 52 failures (windowless laundry, medianum via bedroom, stair 0.77 m off walls, stair foot in door line). Final wld002: 13 checks, 77 s.

### WLD-003 tower house — fd51ae0, 1775005, 3654102, 2698b0c
First run rejected by envelopes (generic world max 40 vs tower family 85.5; 70 percent below 31.5). wld003: 13 checks, 283 s.

### WLD-004 hypostyle mosque — ea01643, 5ac1c7d, 60c086a
QiblaCheck, mihrab, sahn, minaret; wld004 8 checks, 31 s.

### WLD-005 hammam — 31f743e, a53f74a
Steam Baths, revolved domes with oculi, furnace, explicit daylight replacement, HammamCheck; wld005 13 checks, 26 s. See docs/HAMMAM_MESH_SUPPORT.md.

### WLD-006 caravanserai — c40ddf6, 3b35368, 29ad88a
Sultan Han, HanCheck; wld006 14 checks, 16 s.

### WLD-007 siheyuan — cbaf673 (as 69413aa), 66cc020
SiheyuanCheck on CourtCheck; repaired a long-site hall narrower than the gate and a centred negative fixture; wld007 13 checks, 12 s.

### WLD-009 pagoda — aaad8ce, ced4e94
Square/octagonal/dodecagonal, odd tapered tiers, mast, finial, linked stairs, eight negative controls; wld009 11 checks, 18 s.

### WLD-010 tulou — 173a6ae, aae4714
Earth ring, one gate, inward galleries, ancestral hall; wld010 18 checks, 16 s.

### WLD-011 temple mountain — c395d4f, 0194758
MountainCheck extends TempleRiteCheck; wld011 9 checks, 42 s.

### WLD-012 cruciform temple — 7fc8356, 5001b24, b174e8a
Four porches and images, two ambulatory rings, centred sikhara; wld012 10 checks, 14 s.

### WLD-013 nagara temple — 3f17cae, 047e3bd
ShikharaCheck; a duplicate solid wall blocked the sanctum sightline and was removed; wld013 9 checks, 14 s. See docs/NAGARA_MESH_SUPPORT.md.

### WLD-014 Dravida compound — f53f1aa, a3cc16c
PrakaraCheck, period-sensitive dominance (period < 1200 taller vimana, else taller gopurams); wld014 11 checks, 14 s. KB c426a937.

### WLD-015 rock-cut temple — 847a3e3
82x46x30 m retained pit, per-building ground datum, negative occupied storeys, pit-wall gallery, bridge, six negative controls; wld015 9 checks, 16 s.

### WLD-016 stepwell — 98cd51a, 63d60a8
Queen's Well, VavCheck; basin slab datum and route reachability fixed; wld016 15 checks, 21 s.

### WLD-017 stupa — d3f1bfd, 1e69f18, cd958fa
Solid dome, drum terrace, four toranas, harmika, chatra; wld017 7 checks, 28 s.

### WLD-018 vihara — 236af3f, 473d412
ViharaCheck on CourtCheck; wld018 15 checks, 16 s.

### WLD-019 haveli / vastu — 6043c89
Centred 9x9 mandala, SE kitchen, NE well, upper jharokhas; wld019 8 checks, 25 s.

### EVAL-B04 — 2026-10-01 (833a835)
Materials and openings for courtyard houses, timber halls and bridges, which were flat boxes.

## Windmills

### WINDMILL-FAMILY — procedural windmill family — 2026-10-04 (7751ce2, bd3bd53)
Post mill, tower mill, smock mill, windpump and polder paddle mill under src/windmill/ (spec, geometry, builder, generator, assembler), judged by qa/windmill_check.gd. Published through BuildingLibrary (`windmill`), WindmillFamily adapter and BuildingCodec. lane:windmill; lane:api ALL PASS 2026-10-05 (390 checks, windmills 195). Portraits: tools/render_windmills.gd. Detail: docs/WINDMILLS.md.

## QA/Tooling

### Introduce Godot-native BigGlade generation facade — date unknown
Added the stable request/result facade (BigGlade) over church, castle, house and temple generation; Studio generation migrated through it with generator and builder behaviour unchanged. Descriptors, validation and mesh/scene output added. Library plus four family suites: 376 checks, 0 failures. See docs/PUBLIC_API_TRANSPORT.md and README.

### LIB-VOXEL-001 Publish relocatable addon and prove VoxelGames integration — date unknown
Published the relocatable addon 0.1.0: 29-script/UID runtime closure, 203-file prop tree, managed SHA-256 installer, measured placement metadata, opt-in shell collision. Installer harness 266 files; packaged smoke passed all four families under VoxelGames Godot 4.6 double precision. Core suites 376/376. See docs/RELEASES.md.

### Add public API descriptors and structured request  — date unknown
src/api/building_library.gd: one table per kind (label, size envelope, defaults, style/purpose tables); describe_kind, default_request, option_label and validation all delegate to it; Studio reads only the descriptor. library+placement PASS (59+123 checks).

### Separate Godot-native generation documents from me — date unknown
BuildingDocument and BigGlade.generate_document: family-native payload plus placement; build_mesh(document) equals build_mesh(generation) vertex for vertex; to_dict JSON round-trip. GDScript String(variant) throws on ints so to_dict uses str().

### Introduce registered building-family adapters — date unknown
src/api/building_family_adapter.gd: base adapter plus an inner class per family and a static registry; facade 444 -> 187 lines naming no family. PlanFamily shared by house/shop/hotel. Use for_building(building) from the retained spec; HotelSpec/ShopSpec tested before HouseSpec.

### Provide uniform mesh and scene outputs for every f — date unknown
ShellAssembler.surface_materials is the single material loop; adapter colours(spec) names surface colours per family; DEFAULT_ROUGHNESS 0.92 for all (was 0.88-1.0). No asset loading in headless mesh generation. 11 suites green including dressing (401557 checks).

### Define API compatibility and seeded reproducibilit — date unknown
README 'Compatibility and reproducibility': Godot 4.5 source / 4.6 double-precision addon, API_VERSION 1, metres, -Z front, door on footprint -Z edge, y=0 ground, four surfaces in fixed order, plain-data serialisation ignoring unknown keys, seed stability within a version not across releases. LibrarySuite._check_contract is the smoke contract.

### INT-020 - RuleSet and Sightline
qa/rule_set.gd, qa/sightline.gd; rules replaced by name in House/Temple/Castle/Tower/Village checks.
### HOUSE-EXT-001 to 006 and two roof bug reports
Tracked roof harness (tests/house_roof_test.gd, hroof/hexterior), RoofShape descriptor, joined hip faces (commit 1870c0b, hroof 445 checks), gable closure (452 checks), dormer capacity. All detail in docs/HOUSE_ROOF_FIX.md and docs/HOUSE_EXTERIOR_TASKS.md.

### QA-RUNNER-002 five-minute routine gates - 2026-09-30, commit 7cc48dd
tools/run_qa_lane.ps1 records native exit, stdout/stderr, wall time and verdict; stops only its own PID at 300 s. Host wall: geom 116 s, castle-change 209, church-change 20, house-plan-fast 206, house-furnish-fast 194, house-exterior-fast 112, assets-fast 40, temple 52, village-fast 113 (red on 17 real VIL-017 defects). A 24-house furnishing candidate took 343 s and was rejected. Asset-catalogue rebuild is a named exception (QA-ASSET-CATALOG-001). See docs/QA_FAST_PROTOCOL.md.

### EVAL-C02 dressing sweep after INT-007 - 2026-10-01
Castle hall/keep furniture moved into interior HousePlans, so the shell prop_log no longer holds table/light and dressing failed 83 castles. Redefined what the sweep measures, confirmed fire remains in the shell, added bounded dressingquick.

### EVAL-C14 HouseYardCheck scope
Road-edge access rule now excludes shaped/courtyard plans and exterior_props=false castle interiors (HouseYard.has_road_edge). Confirmed with 62635 checks, zero failures.

### Deterministic capture helper - 2026-10-03, commit 49215c5
One-family assembled capture with camera/request metadata, QA manifest, nonzero exit on generation, capture, manifest or QA failure. Verified on house (six images, two fixtures) and shop (three images, 39 s). Status in docs/VISUAL_BUILDING_AUDIT_STATUS.md; full visual audit still unfinished.

### API-TRANSPORT (versioned request/document serialization) — 2026-09
Schema 1 BuildingRequest and BuildingDocument with dictionary/JSON round trips; int64 seeds as decimal strings, allowlisted data classes, no RNG/runtime objects, INF furniture sentinels kept valid in JSON. tests/api_transport_test.gd: 78 checks, 0 failures, byte and mesh parity for 7 families, edited derived state, malformed requests, C2 village interiors. Detail: docs/PUBLIC_API_TRANSPORT.md. KB 4a785a95.

### API-CLI (headless JSON generation tool) — 2026-09
tools/generate_building.gd reads a JSON request, writes lossless document, optional shell mesh and structured QA. Exit codes 0 success, 2 IO/usage, 3 invalid request, 4 QA. tools/test_building_cli.ps1 showed byte-identical document, mesh and QA hashes across two runs.

### API-ADDON (installable Godot addon) — 2026-09-23 snapshot
Verified in a clean Godot 4.5.2 project: 724 managed files, all runtime scripts with UID sidecars, API docs and example, four CC0 catalogue asset trees with licences. Castle resource paths made relative. Installer tests assert source closure, 7-family generation, idempotency, stale-managed cleanup, unmanaged preservation. Frozen-source snapshot used because a source changed mid-run; CAS004/LAY work after the snapshot needs a fresh package run. A compact 24x24 h16 temple seed 731 column overlap, found by a consumer, was handed to the temple owner. Detail: docs/RELEASES.md. KB 03ff7967.

### ROOF-AUDIT-003 — 2026-09
Authored roof-region contracts: 24 cases + 11 controls, 16971 checks, 0 fail/warn (courts, polygon oculi, ziggurat chambers, all four castle tiers at two sizes, open battlements, hotel cupola seams, placed village buildings). Each covered region removes its actual cover as a negative; unsupported registry kinds stay uncovered. Fixed zig column/cell ceiling, idol summit fit, turret deck 0.125 m gap. See docs/ROOF_REGION_CONTRACTS.md.

### QA-PERF-001/002/003 — 2026-09-29
lane:castle-change (e155a3c): 127 checks, 91 s host wall, controls solid window / inverted normals / missing mass / seed 9118 gate-stair overlap; caccess alone 707.87 s. lane:church-change (29e30e8): 5,369 checks, churchroof 163 s wall. Byzantine 5003 clip fix (0d42342): seed 5003 builder 710 ms, Hagia 539 ms, roof height exact to 1 mm on 286/289 rays. See docs/QA_PERF_001.md, QA_PERF_003.md. KB dd587dbc.

### QA-RUNNER-001 — 2026-09-30
Runner now fails on GDScript script errors. Selector/executor moved to tests/run_all_impl.gd; tests/run_all.gd is a minimal bootstrap logger. Opt-in runnererror and runnerfail suites prove exit 1; valid poly exits 0 (28 checks); unknown suite exits 2. Commit 625bc8b.

### QA-ASSET-CATALOG-001 — 2026-10-01
Incremental, source-fingerprinted prop catalogue rebuild (commits a488c16, cdbe09a). Full 238-prop measure plus cache-backed generation byte-identical in 17.9 s; warm incremental 2.46 s, 0 measured, 4 packs reused. Flags: --incremental, --verify-parity. lane:assets-fast 19 s.

### EVAL-U01 / EVAL-U03 — 2026-10-01
Lane tables and timings refreshed (KNOWN_ISSUES, HOTELS, QA_FAST_PROTOCOL, AGENTS); scheduled lane for dressing, hlandmark, court, wld001. library (was 25 min) and placement (did not finish in 35 min) bounded, with libraryquick/placementquick (merged 1204daf). See docs/EVALUATION_2026-10-01.md.

### QA-CASTLE-SWEEP-001 — 2026-10-01
Routine multi-hour castle batch replaced by lane:castle-spot (castlechange + Himeji four-scale chimeji, commit b0e45eb): 89.5 s, 93 checks, 5 classified opening-probe warnings. Bounded spot evidence only; the exhaustive style x tier x seed matrix is not claimed.

## Other

### GEO-001 Polygon geometry helpers and WalkGrid polygon rasterisation — date unknown
core/poly.gd (area, signed area, contains_point, convex clip, offset with exact round-corner area, hull, bounding rect) and WalkGrid.add_floor_poly/add_obstacle_poly, purely additive. New 'poly' suite 21 checks; normals/massing and temple suites unchanged. Foundation for polygon rooms, village lots/roads and moats.

### EVAL-B02 castle yards, moat, ground - 2026-10-02
Moat palette subdued, palatial towers get outward window tiers and floor bands (no occupied interior floors added); cground 391 checks, castle-change 282 with five known opening-probe warnings. See docs/EVALUATION_2026-10-01.md, artifacts/renders/refinement.

### Visual refinement pass - 2026-10-02
42 home views over seven fixtures; fixed mounted fixture bounds, metre-scale floors/paths, hotel-opening decoration, palatial tiers, timber framing, temple brazier clearance, green-village well access, Thorpe church depth. Gates all zero failures (hotelroof+hassembly 1749, geom 8768, exterior 1925, castle 282, vsite 311, village-fast 10). No third-party assets imported. Gallery artifacts/visual_refinement/homes_after/index.html; detail in docs/EVALUATION_2026-10-01.md.

### EVAL-C10 — 2026-10-01
Tree crowns under a quarter of height: 142 of 835 tree checks warned on birch, spruce, oak canopies and trunk clearance; fixed.

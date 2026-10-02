"""Idempotently publish the procedural-building reading map to WaterFree Knowledge.

Run from the BrickWild root: python tools/seed_procedural_knowledge.py
The source map is docs/PROCEDURAL_GENERATION_BOOK.md. Entries are prose-only.
"""

import json
import subprocess


BOOK = "docs/PROCEDURAL_GENERATION_BOOK.md"

# title, branch, description, context, tags, scope, source file
ENTRIES = [
    (
        "Procedural generation stack: brief to validated scene",
        "Procedural/buildings/pipeline",
        "Derive semantic plans before emitting assets: brief and seed, site graph, lots, building programme, room graph, mass, openings, surfaces, furnishings, then scene assembly. Give each stage explicit inputs, measured outputs, and stable part identities so generation can be reproduced and failures localized.",
        "BrickWild uses Spec -> Geometry -> Plan -> Builder -> Assembler; HousePlan and VillagePlan remain data. Use the same separation for other engines. Project: docs/HOUSES.md, docs/VILLAGES.md. Research: https://doi.org/10.1145/1179352.1141931 and https://people.eecs.berkeley.edu/~sequin/CS285/PAPERS/Parish_Muller01.pdf",
        ["architecture", "pipeline", "planning", "determinism"], "global", BOOK,
    ),
    (
        "Building use before silhouette: programme, adjacency, and route",
        "Procedural/buildings/plans",
        "Define required activities and their adjacency graph before packing rooms into a footprint. Reserve doors, stairs, access widths, work clearances, and important sightlines before shell or furniture generation; reject layouts that only look plausible from outside.",
        "BrickWild: HousePlan, qa/walk_grid.gd, qa/temple_rite_check.gd; docs/HOUSES.md and docs/TEMPLES.md. Research: Graph2Plan https://arxiv.org/abs/2004.13204 converts layout graphs and a boundary to floor plans. Use exact clearance values appropriate to the intended characters and scale.",
        ["floorplan", "room-graph", "circulation", "constraints"], "global", BOOK,
    ),
    (
        "Compose architecture from archetype, structure, and style",
        "Procedural/buildings/families",
        "Model an archetype through structural relations, then vary style, materials, and ornament independently. Courtyard compounds, towers, hypostyle halls, pagodas, stepped temples, and stepwells require different spatial grammars; repeating a rectangular shell with a new facade will not preserve their use or form.",
        "BrickWild survey: docs/WORLD_BUILDINGS.md, plus docs/CASTLES.md, docs/TEMPLES.md, docs/HOTELS.md. The survey is a generator design reference, not a claim of historical universality; verify cultural and period details with specialist sources before publication.",
        ["archetypes", "architecture", "typology", "style"], "global", BOOK,
    ),
    (
        "Shape grammar from mass to facade to component",
        "Procedural/buildings/grammars",
        "Start with a volumetric mass, subdivide facade scopes by floors and bays, and expand terminal scopes into openings and details. Attach semantic roles to scopes and use context rules to prevent a door, window, or ornament from crossing a structural boundary or conflicting with another component.",
        "CGA building paper: https://doi.org/10.1145/1179352.1141931 . Editable inverse facade grammars: https://arxiv.org/abs/1308.0419 and https://arxiv.org/abs/2406.01829 . BrickWild roofs and openings: docs/ROOF_AUDIT.md. Treat facade grammar as a consumer of the interior plan and structure.",
        ["shape-grammar", "facade", "massing", "openings"], "global", BOOK,
    ),
    (
        "Facade split arithmetic must consume the whole scope",
        "Procedural/buildings/grammars",
        "When a facade bay or wall run is split into absolute and relative pieces on an integer grid, round cumulative boundaries and obtain each width from successive boundaries. This preserves the full parent extent and avoids a seam or overlap from independently rounded child widths.",
        "Related WaterFree entry 'CGA-style split needs CUMULATIVE rounding' (VoxelGames, pattern/procgen/split-rounding). BrickWild should preserve fractional measurements where possible and apply cumulative rounding only at the final discrete representation. Research context: https://doi.org/10.1145/1179352.1141931",
        ["split", "grammar", "rounding", "facade"], "global", BOOK,
    ),
    (
        "Architectural mesh faces carry winding, normal, UV, and material role",
        "Procedural/Meshes/surfaces",
        "For every emitted face, define vertex order, outward normal, UV basis, material role, and semantic host. Share vertices only where their full attributes may match; hard architectural corners need separate normals. Resolve materials by named role because omitted empty surfaces may shift numeric indices.",
        "Godot front faces are clockwise; BrickWild MeshKit._face_normal centralizes the convention and MeshKit.commit does not smooth the entire building. See core/mesh_kit.gd and AGENTS.md. Godot docs: https://docs.godotengine.org/en/4.5/tutorials/3d/procedural_geometry/surfacetool.html",
        ["mesh", "normals", "uv", "materials", "godot"], "global", "core/mesh_kit.gd",
    ),
    (
        "Choose mesh generation API by required topology and update pattern",
        "Procedural/Meshes/godot",
        "Use ArrayMesh arrays for direct static mesh construction, or SurfaceTool when incremental vertex emission is clearer. Use MeshDataTool when editing or inspecting face and edge adjacency; do not pay its conversion cost for simple creation. Rebuild-per-frame geometry warrants a separate performance decision.",
        "Godot 4.5 primary docs: https://docs.godotengine.org/en/4.5/tutorials/3d/procedural_geometry/arraymesh.html , https://docs.godotengine.org/en/4.5/tutorials/3d/procedural_geometry/surfacetool.html , https://docs.godotengine.org/en/4.5/tutorials/3d/procedural_geometry/meshdatatool.html . BrickWild uses MeshKit to keep family emitters consistent.",
        ["godot", "arraymesh", "surfacetool", "topology"], "global", BOOK,
    ),
    (
        "Roof descriptor is shared by skin, walls, openings, and attachments",
        "Procedural/Meshes/roofs",
        "Compute one roof description of polygons, planes, ridges, valleys, thickness, and occupied regions. Derive roof triangles, gable or wall profiles, dormer seats, drainage, and QA contracts from that descriptor so they cannot drift into separate geometries.",
        "BrickWild: core/roof_shape.gd, src/house/house_geometry.gd, docs/ROOF_AUDIT.md, docs/ROOF_REGION_CONTRACTS.md. Intersect a dormer with its host plane and distinguish covered regions from deliberate sky openings. Related roof-mesh research: https://arxiv.org/abs/2303.11215",
        ["roof", "planes", "topology", "dormer"], "global", "core/roof_shape.gd",
    ),
    (
        "Place openings on actual wall surfaces, not AABBs",
        "Procedural/Meshes/openings",
        "Project a door or window onto the host surface at its intended elevation and orientation. Battered walls, drums, curved towers, and tiered masses withdraw from their axis-aligned boxes, so a box-face opening can float outside the structure.",
        "BrickWild: castle and church shell opening helpers, AGENTS.md. The mass AABB is useful for broad clearance, never a substitute for a support surface. Add a geometric support check and test shrinking or sloped walls.",
        ["openings", "surface", "aabb", "geometry"], "global", BOOK,
    ),
    (
        "Measure emitted components independently of their planned records",
        "Procedural/Meshes/validation",
        "Record stable host and role ids for named pieces as they are emitted, then verify those records against actual mesh triangles. Compare planned occupancy, emitted bounds, and connected components; a plan or log that agrees with itself cannot prove the geometry was built.",
        "BrickWild: core/mass_builder.gd part_log/mass_log/prop_log/component_log; qa/component_check.gd; tests/fixtures/faulty_house_builder.gd. docs/ROOF_REGION_CONTRACTS.md separates coverage, material, and support. Use faulty emitters as negative controls.",
        ["mesh", "qa", "components", "mutation-testing"], "project", "core/mass_builder.gd",
    ),
    (
        "Measure asset bounds and pivots from imported models",
        "Procedural/buildings/assets",
        "Build a catalogue from actual model geometry: dimensions, pivot or support point, collision footprint, and relevant clearance extents. Use those measurements for placement and navigation, and rebuild the catalogue when source assets change; authored sizes drift silently.",
        "BrickWild: tools/build_prop_catalog.gd writes assets/props/catalog.json and the asset suite remeasures models. For trees, distinguish trunk radius from canopy radius; for wall props, know the back contact plane. See docs/HOUSES.md and docs/VILLAGES.md.",
        ["assets", "catalogue", "bounds", "placement"], "project", "tools/build_prop_catalog.gd",
    ),
    (
        "Furnish rooms by host relations and preserve required activities",
        "Procedural/buildings/decoration",
        "Define furniture recipes in terms of room purpose and relations such as against wall, facing focus, beside table, on support, and near entrance. Reserve activity zones and circulation before optional clutter; evaluate collisions and reachability after placement and repair invalid scenes.",
        "BrickWild: HouseFurnisher recipes and qa/walk_grid.gd; docs/HOUSES.md, docs/FURNISHING_WALLS.md. If repair removes a required item, retain a warning on the plan. Research: https://web.cs.ucla.edu/~dt/papers/siggraph11/siggraph11.pdf and https://arxiv.org/abs/2406.11824",
        ["furnishing", "interiors", "recipes", "navigation"], "global", BOOK,
    ),
    (
        "Decorate village hosts without blocking their use",
        "Procedural/villages/decoration",
        "Attach outdoor recipes to specific hosts: house yard, shop doorway, market aisle, common, gate, bank, field, and edge. Reserve roads, paths, door approaches, stall aisles, and working clearance before placing props. Treat plant trunks as navigation obstacles and canopies as roof-clearance volumes.",
        "BrickWild: src/village/village_dresser.gd and docs/VILLAGES.md sections 7-9. Recipes use wall, yard, verge, corner, row, on, and light relations; QA remeasures their zones against road polygons. Culture palettes are project art direction, not a botanical fact.",
        ["village", "props", "plants", "clearance"], "project", "src/village/village_dresser.gd",
    ),
    (
        "Village morphology is road graph plus common plus frontage",
        "Procedural/villages/forms",
        "Choose a settlement form as a relationship among through road, common, streets, and lot frontages. Street, green, crossroads, round, strand, planted, and gate forms need distinct graph and public-space geometry; orient each building entrance to a reachable road-facing front.",
        "BrickWild: docs/VILLAGES.md sections 2-5 and src/village/site_planner.gd. A form name alone is insufficient: test road connectivity, lot orientation, common area, and approach to the real door. Research foundation: https://people.eecs.berkeley.edu/~sequin/CS285/PAPERS/Parish_Muller01.pdf",
        ["village", "roads", "lots", "morphology"], "global", BOOK,
    ),
    (
        "Settlement reason precedes its road and building programme",
        "Procedural/villages/planning",
        "Place the site's defining resource or destination first: crossing, mill water, mine, market, shrine, fishing shore, or fortification. Route the main road and locate the common in relation to it, then size housing and services to the population and economy instead of sprinkling all building types at random.",
        "BrickWild: VillageSpec purpose and programmer, docs/VILLAGES.md sections 1, 2, 4, and 6. Its service thresholds are gameplay recipes, not historical demographic laws. Research: https://people.eecs.berkeley.edu/~sequin/CS285/PAPERS/Parish_Muller01.pdf",
        ["village", "economy", "landmarks", "programme"], "global", BOOK,
    ),
    (
        "Parcel from road frontage and fit measured buildings",
        "Procedural/villages/lots",
        "Cut lots from actual road edges with a stored front edge, depth, and yard. Place corner buildings toward the higher-order road and test the final emitted building bounds, porch, stairs, and entrance route against the lot and neighboring fire gap.",
        "BrickWild: src/village/lot_planner.gd and docs/VILLAGES.md section 5. The requested building envelope may differ from measured placement bounds. Keep a separate corridor to the true door for open courts; do not exempt a closed wall from collision checks.",
        ["parcel", "frontage", "lot", "placement"], "project", "src/village/lot_planner.gd",
    ),
    (
        "Water, enclosure, and roads form one circulation contract",
        "Procedural/villages/infrastructure",
        "Whenever a road crosses water or an enclosure, plan a bridge, ford, or gate as a persistent feature of the site. Clip barriers at real crossings, keep the wet channel open, and verify emitted passage and walkability rather than trusting marker records.",
        "BrickWild: docs/VILLAGE_CROSSINGS.md, docs/VILLAGE_ENCLOSURES.md, docs/VILLAGE_MILL.md; src/village/village_water_plan.gd. A mill race and a gate are infrastructure with flow and route constraints, not decorative props.",
        ["village", "water", "roads", "gates"], "project", "docs/VILLAGE_CROSSINGS.md",
    ),
    (
        "Village edge and outside land use make the settlement legible",
        "Procedural/villages/landscape",
        "Define an inside and an outside through enclosure, rear yards, fields, orchards, pasture, woodland, or shore. Place land uses by purpose and access to tracks or water; use density and vegetation palettes to communicate the transition without filling circulation space.",
        "BrickWild: docs/VILLAGES.md sections 6 and 8. A farming field must touch a track, orchards belong behind farms, and shore activity belongs near the water. These are generator composition rules to calibrate against the setting.",
        ["landscape", "fields", "edge", "village"], "project", "docs/VILLAGES.md",
    ),
    (
        "Procedural QA needs hard invariants, soft preferences, and negative controls",
        "Procedural/buildings/validation",
        "Separate hard validity rules such as support, collision, and reachability from soft composition goals such as rhythm, style, and prominence. Sweep multiple seeds and scales, inspect rendered examples, and deliberately mutate plans or emitted geometry to prove each claimed check can fail.",
        "BrickWild: qa/ checks, tests/suites/ archetype suites, docs/HOUSE_RULES_EVALUATION.md, docs/ROOF_AUDIT.md. The temple axis is a functional invariant; exact numeric thresholds elsewhere are project-specific. A headless mesh check cannot judge visual readability alone.",
        ["qa", "constraints", "mutation-testing", "archetypes"], "global", BOOK,
    ),
    (
        "Courtyard buildings require a shared sky and circulation void",
        "Procedural/buildings/courtyards",
        "Represent the court as a hole in room packing and roof coverage, while retaining it as walkable floor. Turn neighboring rooms inward, connect their thresholds by a gallery or open ring, and choose an entrance sightline rule appropriate to the archetype: screened for privacy or axial for procession.",
        "BrickWild design survey: docs/WORLD_BUILDINGS.md sections 1.1, 2.1, 2.4, 3.6, and 3.7. Domus, riad, siheyuan, tulou, and vihara share an open court but differ in entry, privacy, axis, and room hierarchy. Do not erase those differences with one generic courtyard template.",
        ["courtyard", "roof", "circulation", "typology"], "global", "docs/WORLD_BUILDINGS.md",
    ),
    (
        "Vertical families need a floor graph as well as a tapered silhouette",
        "Procedural/buildings/vertical",
        "For towers, apartment blocks, pagodas, and stepped buildings, plan storeys and stairs as a connected graph before stacking masses. Make each tier's usable floor, openings, support, and route agree with its footprint; a decorative stack of shrinking roofs does not prove a climbable building.",
        "BrickWild design survey: docs/WORLD_BUILDINGS.md sections 1.2, 1.3, and 2.3. A pagoda may have more interior levels than visible eave tiers; a tower house and insula impose different ground-level access. Numeric proportions in that survey are archetype fixtures to validate, not universal limits.",
        ["tower", "pagoda", "stairs", "floorplan"], "global", "docs/WORLD_BUILDINGS.md",
    ),
    (
        "Timber hall geometry starts from bay and column grids",
        "Procedural/buildings/timber-halls",
        "Generate a platform, symmetric bay grid, column support, deep eaves, and roof as one structural system. Reserve the central axis and standing area between columns, then place the ceremonial focus; mirror optional wings and treat their approach and foreground as part of the composition.",
        "BrickWild design survey: docs/WORLD_BUILDINGS.md section 2.2 and HallCheck; docs/TEMPLES.md for axis and sightline checks. The grid and eave relations are reusable; bracket forms and regional details need specific references before making historical claims.",
        ["timber", "columns", "bays", "roof"], "global", "docs/WORLD_BUILDINGS.md",
    ),
    (
        "Processional buildings are judged by route, focus, and visibility",
        "Procedural/buildings/ritual",
        "Plan gate, approach, congregation or court, altar or intermediary, and final focus as an ordered route. Test both walkable width and eye-height sightline against actual structural masses; check the focus's prominence and access around required fixtures. A route may ascend, descend, or circle rather than stay on one straight floor.",
        "BrickWild: docs/TEMPLES.md and docs/WORLD_BUILDINGS.md sections 2.5, 3.1, 3.2, 3.4, 3.5. TempleRiteCheck is a project functional model, not a general statement about every tradition. Stupa-like forms make circumambulation, not interior entry, the primary route.",
        ["temple", "axis", "sightline", "navigation"], "global", "docs/TEMPLES.md",
    ),
    (
        "Subtractive buildings invert support and sky assumptions",
        "Procedural/buildings/subtractive",
        "For rock-cut temples, stepwells, caves, and sunken courts, model ground and excavated voids before adding bridges, galleries, stairs, and pavilions. Validate that the route descends or crosses the cut, that open sky remains where intended, and that columns or bridges meet supporting rock or floor.",
        "BrickWild design survey: docs/WORLD_BUILDINGS.md sections 3.3 and 3.4. A surface-level massing rule that assumes every building rises above zero will misclassify a carved site; adapt ground/support contracts to the excavation.",
        ["rock-cut", "stepwell", "void", "support"], "global", "docs/WORLD_BUILDINGS.md",
    ),
    (
        "Castle yards and service compounds need working logistics",
        "Procedural/buildings/service-compounds",
        "Treat an enclosed yard as a small working settlement: reserve a gate-to-core route, then place stable, food preparation, storage, forge, and water where workers and vehicles can reach them. Reuse ordinary building families for service structures and keep the primary yard axis clear.",
        "BrickWild: docs/CASTLES.md section 'The bailey is a yard, not a lawn'; CastleGenerator.bailey_buildings reuses ShopSpec, with masses and props tested against gate clearance. The same pattern applies to caravanserai and walled market compounds in docs/WORLD_BUILDINGS.md.",
        ["castle", "bailey", "logistics", "yard"], "global", "docs/CASTLES.md",
    ),
    (
        "Impossible buildings separate room graph, physical cells, and presentation",
        "Procedural/buildings/impossible",
        "For a larger-inside house, looping corridor, or gravity-shifted tower, keep semantic adjacency separate from local mesh/collision cells and from what the camera shows. Give every cell and threshold stable identity; world-space proximity is not proof of connectivity.",
        "Design chapter: docs/PROCEDURAL_IMPOSSIBLE_STRUCTURES.md. A portal edge maps frames, while the room graph states what is actually reachable. Godot Viewport API: https://docs.godotengine.org/en/4.5/classes/class_viewport.html ; portal case study: https://github.com/io12/godot-portal-demo",
        ["fantasy", "portal", "topology", "navigation"], "global", "docs/PROCEDURAL_IMPOSSIBLE_STRUCTURES.md",
    ),
    (
        "Portal thresholds transform more than player position",
        "Procedural/buildings/impossible",
        "A portal record needs source and destination cells and frames, opening width, directionality, active state, and render mode. Apply its mapping consistently to facing, velocity, gravity, camera, held objects, sound, and AI paths; otherwise the view and traversal tell different stories.",
        "Design chapter: docs/PROCEDURAL_IMPOSSIBLE_STRUCTURES.md. The MIT Godot Portal Demo uses paired cameras and viewport textures but documents clipping, lighting, physics and performance limitations: https://github.com/io12/godot-portal-demo . Treat it as a reference, not a Godot 4.5 drop-in.",
        ["portal", "transform", "camera", "physics"], "global", "docs/PROCEDURAL_IMPOSSIBLE_STRUCTURES.md",
    ),
    (
        "Moving architecture changes a finite state-specific connectivity graph",
        "Procedural/buildings/impossible",
        "When stairs rotate or corridors change destination, update geometry, collision, navigation and graph edges as one state transition. Verify required goals and exits in every intended state, and cap recursive room instances and portal rendering depth.",
        "Design chapter: docs/PROCEDURAL_IMPOSSIBLE_STRUCTURES.md. Use deterministic state events and stable room IDs so save/load and breadcrumbs survive a topology change. The rule is a BrickWild design proposal, not current engine behavior.",
        ["fantasy", "moving-building", "state-graph", "qa"], "global", "docs/PROCEDURAL_IMPOSSIBLE_STRUCTURES.md",
    ),
    (
        "Fantasy support exceptions need named causes and visible cues",
        "Procedural/buildings/impossible",
        "Permit a floating or inverted mass through an explicit support relation such as magic anchor or levitation field, not a global bypass of grounded-geometry checks. Validate playable floor/collision separately and give the scene a cue that makes the broken physical law legible.",
        "Design chapter: docs/PROCEDURAL_IMPOSSIBLE_STRUCTURES.md. BrickWild's MassRules.grounded and voxel checks should keep detecting accidental floaters outside named fantasy exceptions. This is a proposed generator pattern.",
        ["fantasy", "support", "floating", "validation"], "global", "docs/PROCEDURAL_IMPOSSIBLE_STRUCTURES.md",
    ),
    (
        "Use permissive implementation references with code and media provenance",
        "Procedural/buildings/open-source",
        "For an MIT-target procedural architecture project, pin the exact dependency commit and license for imported code, then inspect models, textures, fonts and datasets separately. Preserve required notices; a permissively licensed wrapper does not automatically license bundled art or data.",
        "Verified shortlist and direct license links: docs/PROCEDURAL_OPEN_SOURCE.md. Godot license guidance: https://docs.godotengine.org/en/stable/about/complying_with_licenses.html . Prefer MIT, BSD-3-Clause, ISC or BSL-1.0 sources for this book; do not copy copyleft code.",
        ["open-source", "licenses", "assets", "attribution"], "global", "docs/PROCEDURAL_OPEN_SOURCE.md",
    ),
    (
        "Clip polygons before triangulating building and village surfaces",
        "Procedural/Meshes/polygons",
        "Use polygon boolean/offset operations to form valid roads, courts, water cuts, roof regions and enclosure gaps, then triangulate the resulting rings including holes. Validate area, winding and coverage against the semantic region instead of assuming a library output proves the intended opening.",
        "Permissive references: Clipper2 BSL-1.0 https://github.com/AngusJohnson/Clipper2 and earcut.hpp ISC https://github.com/mapbox/earcut.hpp . Clipper2's current README warns that its triangulation code is buggy; use it for clipping/offsetting and assess triangulation separately. BrickWild core/poly.gd remains suitable for its narrower operations.",
        ["polygon", "clipping", "triangulation", "mesh"], "global", "docs/PROCEDURAL_OPEN_SOURCE.md",
    ),
    (
        "Architectural generator rules name host, relation, measure, exception, evidence",
        "Procedural/buildings/design-rules",
        "Express each design rule as a host and relationship with a measurable condition, an explicit archetype or fantasy exception, and independent evidence. For example, a porch belongs to a front wall, faces a reachable road, and joins its host roof; a named open-court arrival may change the ordinary doorstep rule.",
        "Design chapter: docs/PROCEDURAL_ARCHITECTURE_RULES.md. Use plan, emitted mesh, navigation and render evidence where relevant. Numeric thresholds are project/archetype fixtures, not universal architectural laws.",
        ["architecture", "rules", "qa", "relations"], "global", "docs/PROCEDURAL_ARCHITECTURE_RULES.md",
    ),
    (
        "Compose site, mass, facade, and detail at separate scales",
        "Procedural/buildings/composition",
        "Establish site approach and context, then primary/subordinate masses and voids, then floor/bay facade rhythm, then details that explain joints or use. Variation at every scale without hierarchy reads as noise; choose deliberate exceptions for entrance, corner or landmark.",
        "Design chapter: docs/PROCEDURAL_ARCHITECTURE_RULES.md. CGA's mass-to-facade-to-detail hierarchy is a useful research basis: https://doi.org/10.1145/1179352.1141931 . BrickWild examples: docs/CASTLES.md, docs/HOTELS.md and docs/ROOF_AUDIT.md.",
        ["composition", "facade", "massing", "rhythm"], "global", "docs/PROCEDURAL_ARCHITECTURE_RULES.md",
    ),
    (
        "Exterior promises require interior evidence",
        "Procedural/buildings/exterior-interior",
        "A front door promises an entry route; a chimney promises a hearth and flue; a dormer promises usable attic space; a window bay promises a room at that floor. Derive both sides from the same plan and geometry descriptors, and compare real emitted openings, floors and routes.",
        "Design chapter and agreement table: docs/PROCEDURAL_EXTERIOR_INTERIOR.md. BrickWild examples: docs/HOUSES.md, docs/ROOF_REGION_CONTRACTS.md, docs/CASTLES.md. This principle can be relaxed deliberately for ruins or magical deception, but the exception belongs in the plan.",
        ["exterior", "interior", "facade", "plan"], "global", "docs/PROCEDURAL_EXTERIOR_INTERIOR.md",
    ),
    (
        "Exterior weather and material masks follow exposure and use",
        "Procedural/buildings/exteriors",
        "Assign material roles to foundations, walls, timber, roof, trim, glazing and paving. Modulate wear from runoff, splash, soot, traffic and orientation, with restrained noise as variation; uniform random grime loses the building's construction and use story.",
        "Design chapter: docs/PROCEDURAL_EXTERIOR_INTERIOR.md. Keep UV scale and hard normals coherent across adjacent emitted components. This is an art-direction heuristic; environment and material palette may change the effect.",
        ["exterior", "materials", "weathering", "uv"], "global", "docs/PROCEDURAL_EXTERIOR_INTERIOR.md",
    ),
    (
        "Interior dressing places focus and activities before clutter",
        "Procedural/buildings/interiors",
        "Place fixed architecture and primary activity objects before supporting furniture and small props. Use measured support/contact surfaces and host-relative relations, reserve circulation, then repair optional clutter without silently deleting required room functions.",
        "Design chapter: docs/PROCEDURAL_EXTERIOR_INTERIOR.md. BrickWild's HouseFurnisher and qa/walk_grid.gd apply this contract; docs/HOUSES.md and docs/TEMPLES.md show activity and ritual examples. Research: https://web.cs.ucla.edu/~dt/papers/siggraph11/siggraph11.pdf",
        ["interior", "furnishing", "focus", "navigation"], "global", "docs/PROCEDURAL_EXTERIOR_INTERIOR.md",
    ),
    (
        "Hierarchical seeds preserve buildings while varying details",
        "Procedural/buildings/variation",
        "Derive stable random streams for site, family, structure, facade, interior and clutter from a root seed and stable IDs. A new basket or surface variation should not reroll roads, room topology or names; this makes comparisons, saves and QA fixtures meaningful.",
        "Design chapter: docs/PROCEDURAL_EXTERIOR_INTERIOR.md. Related transferred knowledge in Procedural/buildings/pipeline covers identity RNG streams and seed-with-element-ID decisions. Validate repeatability across regeneration and scene assembly.",
        ["seed", "variation", "determinism", "assets"], "global", "docs/PROCEDURAL_EXTERIOR_INTERIOR.md",
    ),
]


def call(*args):
    result = subprocess.run(["waterfree", "knowledge", *args], capture_output=True, text=True, check=True)
    return json.loads(result.stdout)


def main():
    added = 0
    skipped = 0
    for title, branch, description, context, tags, scope, source_file in ENTRIES:
        found = call("search", title, "--limit", "100")
        if any(row["title"] == title for row in found["entries"]):
            skipped += 1
            continue
        args = ["add", "--title", title, "--description", description,
                "--context", context, "--hierarchy-path", branch,
                "--source-repo", "BrickWild", "--source-file", source_file,
                "--scope", scope]
        for tag in tags:
            args += ["--tag", tag]
        result = call(*args)
        print(json.dumps({"title": title, "id": result.get("entry", {}).get("id", result.get("id")), "added": result.get("added")}))
        added += 1
    print(json.dumps({"added": added, "skipped": skipped, "total": len(ENTRIES)}))


if __name__ == "__main__":
    main()

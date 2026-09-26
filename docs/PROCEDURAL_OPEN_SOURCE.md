# Permissive open source implementations for procedural architecture

This is a study and reuse list for a project that may publish its own code
under MIT. The list includes **MIT, BSD-3-Clause, ISC, and BSL-1.0** code,
with a direct repository or license link for each. It does not propose copying
copyleft code. Licenses can change by version or file, so record the exact
commit and inspect the files actually imported before adopting a dependency.
Code licenses do not automatically cover sample models, textures, fonts,
maps, screenshots, or downloaded datasets.

| Implementation | Verified repository license | What to study or use | BigGlade fit |
|---|---|---|---|
| [Godot Engine](https://godotengine.org/license/) | MIT | `ArrayMesh`, `SurfaceTool`, `MeshDataTool`, `SubViewport`, `MultiMesh` and navigation APIs | Runtime and reference API for mesh, instancing and portal chapters |
| [Godot demo projects](https://github.com/godotengine/godot-demo-projects) | MIT repository | Small runnable examples of viewport, 3D and rendering behavior | Reproduce a narrow engine behavior before changing `MeshKit` or assembly |
| [Godot Portal Demo](https://github.com/io12/godot-portal-demo) | MIT | Paired portal cameras, viewport textures, teleport/clone idea, documented failure list | Study for an impossible-space prototype; older project, not a 4.5 drop-in |
| [Clipper2](https://github.com/AngusJohnson/Clipper2) | BSL-1.0 | Polygon intersection, difference and offsets | Roads, water, enclosure cuts, courtyards, roof regions |
| [earcut.hpp](https://github.com/mapbox/earcut.hpp) | ISC | Fast triangulation of polygon rings and holes | Mesh floors, roads, courtyards after plan geometry is validated |
| [NetworkX](https://github.com/networkx/networkx/blob/main/LICENSE.txt) | BSD-3-Clause | Graph algorithms and reference checks | Offline prototypes for room adjacency, road connectivity and circulation |
| [FastNoise Lite](https://github.com/Auburn/FastNoiseLite) | MIT | Coherent noise and domain warp | Terrain or controlled surface variation; keep semantic structure separate |
| [Godot procedural generation examples](https://github.com/John-Harris/godot-procedural-generation) | MIT source code per repository | Small algorithm demonstrations | Study seeding and algorithm presentation; inspect demo media separately |
| [Godot Road Generator](https://github.com/TheDuckCow/godot-road-generator) | MIT | Cross-section road meshes, intersections, edge curves, lane paths | Study village road emission and reusable street furniture hosts; current main supports Godot 4.4+ |
| [Procedural City Truck Sim](https://github.com/stavguo/procedural-city-truck-sim) | MIT repository | Small Godot example of oriented-box parcel splitting | Study parcel recursion, not as a complete village planner; bundled palette/model and add-ons need separate review |

The listed licenses come from the maintainers' repository or license pages:
[Godot](https://godotengine.org/license/),
[Godot demos](https://github.com/godotengine/godot-demo-projects/blob/master/LICENSE.md),
[Portal Demo](https://github.com/io12/godot-portal-demo/blob/master/LICENSE),
[Clipper2](https://github.com/AngusJohnson/Clipper2/blob/main/LICENSE),
[earcut.hpp](https://github.com/mapbox/earcut.hpp/blob/master/LICENSE),
[NetworkX](https://github.com/networkx/networkx/blob/main/LICENSE.txt),
[FastNoise Lite](https://github.com/Auburn/FastNoiseLite/blob/master/LICENSE), and
[Godot procedural generation examples](https://github.com/John-Harris/godot-procedural-generation/blob/master/LICENSE),
[Godot Road Generator](https://github.com/TheDuckCow/godot-road-generator/blob/main/LICENSE), and
[Procedural City Truck Sim](https://github.com/stavguo/procedural-city-truck-sim/blob/main/LICENSE).

## How each implementation maps to a building problem

**Polygon clipping and offsetting.** A village planner must subtract roads
and water from lots, cut a wall at a gate, and keep an apron clear in front
of a door. A polygon library can calculate these regions, but the semantic
plan must decide *which* subtraction is allowed. [Clipper2](https://github.com/AngusJohnson/Clipper2)
supports boolean and offset operations. Its current README flags its own
triangulation code as buggy; use it for clipping/offsetting and validate a
separate triangulation path. Use BigGlade's `core/poly.gd` where its narrower
operations already suffice.

**Triangulation.** A footprint, floor with courtyard hole, irregular roof
region, or road ribbon must be converted to triangles without filling its
holes. [earcut.hpp](https://github.com/mapbox/earcut.hpp) is a permissive
reference for rings and holes. Its README emphasizes practical robustness and
speed rather than a universal guarantee. Validate orientation, area, no
zero-area triangles, and coverage against the input polygons.

**Graph algorithms.** Room and village planners are graph generators before
they are mesh generators. [NetworkX](https://github.com/networkx/networkx)
is useful in offline Python experiments to inspect connected components,
shortest paths, articulation points, and reachability. The shipped Godot
runtime can retain its own compact graph routines; using NetworkX to check a
fixture does not require a Python dependency in the game.

**Roads and parcels.** [Godot Road Generator](https://github.com/TheDuckCow/godot-road-generator)
is a Godot 4 reference for road cross-sections, intersections, lane paths and
decoration edge curves; its README says the plugin is not feature complete.
[Procedural City Truck Sim](https://github.com/stavguo/procedural-city-truck-sim)
is a compact oriented-box parcel experiment. Its own roadmap still lists
building collision and other city features as future work. Neither replaces
BigGlade's semantic village checks for frontage, common, purpose or walking.

**Noise.** [FastNoise Lite](https://github.com/Auburn/FastNoiseLite) supplies
multiple coherent noise families. Noise is best used for secondary variation:
terrain undulation, material wear masks, plant scatter, or slight height
changes. Never let a random noise field replace the road hierarchy, facade
rhythm, room graph, or building support relation. In Godot, first inspect the
engine's built-in `FastNoiseLite` before importing an external copy.

**Portals.** The [Godot Portal Demo](https://github.com/io12/godot-portal-demo)
provides a concrete paired-camera and viewport-texture experiment and
documents its seams, lighting, physics, and performance limits. Use its
failure list as a checklist. For a production 4.5 implementation, design
portal transitions around the current [Viewport API](https://docs.godotengine.org/en/4.5/classes/class_viewport.html)
and BigGlade's semantic door graph; a copied old scene is unlikely to satisfy
current rendering or navigation behavior.

## Reuse protocol for an MIT-target project

1. Pin a repository URL, commit hash, exact paths, and the license file that
   applies to those paths. Do this separately for code and media.
2. Record what is copied, linked, translated, or only studied. Ideas and
   algorithms can be reimplemented from a paper or description; copied code
   carries its source notice obligations.
3. Preserve copyright and license notices required by the source license in
   the distributed source or binary package. Keep a third-party notice list.
4. Review transitive dependencies and generated/embedded data. A permissive
   wrapper is not proof that every bundled asset or dataset is permissive.
5. Add a tiny fixture that exercises the imported feature and documents its
   failure boundary: a polygon with a hole, two crossing roads, a portal with
   a held object, or a multi-seed graph.
6. Keep BigGlade's own code and asset licenses explicit when publishing. An
   MIT code license does not relicense someone else's models or textures.

The [Godot license guidance](https://docs.godotengine.org/en/stable/about/complying_with_licenses.html)
also distinguishes the engine license from third-party notices and assets.
This chapter is a technical selection record; final release notices should
match the exact dependencies and files actually shipped.

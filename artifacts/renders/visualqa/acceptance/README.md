# VIS-001 reference stage acceptance

Rendered 2026-09-29 with Godot 4.5.2 Forward Mobile using
`tools/render_shots.gd -- visual-qa`. The [contact sheet](contact_sheet.jpg)
has the historical light in the left column and camera-relative light in the
right. Rows follow the seven subjects below. Each pair uses the same generated
mesh, seed, camera and material. [manifest.json](manifest.json) records those
inputs and both light rigs. These are visual judgments, not automated scores.

| Subject | Silhouette | Structure | Surface | Openings | Hierarchy |
|---|---|---|---|---|---|
| Notre-Dame | Long ridge and west towers remain readable. | Flyers and apse courses gain a clearer light/shadow edge. | Large walls remain a single tone. | Black windows remain shallow. | West towers and crossing still lead; light alone does not strengthen their scale. |
| Durham | Crossing tower remains identifiable. | Narrow buttresses separate more clearly from the wall. | Transept wall remains broad and plain. | Repeated black windows remain flat. | Lantern is clearer; roof and wall detail still weak. |
| Hagia Sophia | Central dome reads more clearly against the sheds. | Half-domes show a little more volume; supports remain schematic. | Pale wall nears the highlight limit and has no courses. | Small dark openings remain visible but lack depth. | Dome is the focal point; long plain walls still dominate. |
| Bodiam | Towers and curtain separate more clearly. | Merlons and tower faces show useful cast shade. | Masonry remains flat. | Slits are visible but uncut. | Great tower remains prominent; this is a light improvement, not a tower change. |
| Krak | The concentric plan remains readable. | Raking light separates the wall rings. | The 300 m surfaces remain plain. | Slits stay tiny at this distance. | Yard still looks sparse in this mesh-only portrait; VIS-002 must photograph the assembled scene. |
| Himeji | Repeated tiered roofs still obscure the tenshu. | Tower faces separate, while the base lacks a terrace. | White wall highlights remain strong. | Small slits remain visible. | Main keep still loses to similar surrounding towers; CAS-010 owns the raised terrace. |
| Neuschwanstein | Ridge ranges and spires remain readable. | Light gives the tall tower more volume. | Long walls stay flat. | Window rows remain uniform dashes. | Entrance and roof hierarchy still need VIS-009. |

The key is 62 degrees to one side of the camera at 30 degrees elevation, with
warm energy 1.8, cool fill 0.45 and ambient 0.8. The historical key was fixed
at -131 degrees azimuth, -42 degrees elevation, energy 1.5, with white fill
0.35 and ambient 1.0. The new setup improves face separation on Bodiam,
Durham and Notre-Dame without hiding their openings. It gives Hagia Sophia and
Himeji bright white walls, so material and form work remain necessary.

The [Chartres chevet shot](chartres_chevet.jpg) now contains the chapel ring,
ambulatory and apse. The earlier `detail_chapels.jpg` frame was aimed into an
aisle roof and did not show its stated subject.

The ordinary 41-shot reference run is recorded separately in
`artifacts/vis001/full_render.log`. The shell-only portrait path is deliberate
for this light comparison. VIS-002 will change the normal church and castle
portraits to their full assembled scenes.

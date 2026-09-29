# VIS-004 material acceptance

Fixed-seed, fixed-camera pairs. Left: the four flat surface overrides. Right: the runtime stone and roof finish. Camera and camera-relative lighting are held constant within each pair.

| Subject | Stone readability | Roof treatment | Distance noise | Observation |
|---|---|---|---|---|
| Durham | Courses read on the broad nave walls when viewed at portrait size. | Warm tile rows remain quiet and follow the roof plane. | Low. | The stone gets a little value separation without competing with the long nave silhouette. |
| Notre-Dame | Subtle courses show on the nave and tower faces. | Slate remains dark and legible; no new high-frequency pattern. | Low. | Buttresses and openings remain the dominant details. |
| Bodiam | Courses are visible on curtain walls and round towers. | Blue-grey tiles retain their palette and read at this distance. | Low. | Large faces gain scale; merlons and towers stay clear. |
| Himeji | White stone gains faint block variation without losing its bright style. | Repeated dark roof tiers stay readable; courses are visible at close inspection. | Low. | The material does not solve the keep hierarchy, which is a separate silhouette issue. |

The first shader draft looked noisy and made surfaces sort as transparent because it wrote `ALPHA`. The accepted render removes that output, enlarges the courses, and lowers contrast. The palette inputs for stone and roof are opaque; the trim/opening slots retain their original materials and cutaway roof hiding is applied last.

Files: `contact_sheet.jpg`, plus each subject's `_before.jpg` and `_after.jpg` pair. Render with `Godot_v4.5.2-stable_mono_win64_console.exe --path . --script res://tools/render_shots.gd -- vis004`.

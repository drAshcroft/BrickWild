# VIS-005 masonry aperture acceptance

Six fixed-camera pairs compare the church geometry before and after the host-wall cuts. The baseline uses the VIS-004 material path at commit `de66292`; the candidate changes only the church builder. `manifest.json` records seeds, camera and key-light offsets. In each pair, `front` puts the key along the view and `raking` turns it 75 degrees. The directory also holds current full-building portraits for both subjects. All shots use the roof-on `ChurchAssembler` scene.

| Subject | What changed | Remaining visual issue |
|---|---|---|
| Notre-Dame west portal | The former dark slit over solid tower and nave masonry is now a continuous route with visible stone jambs and lintel. | The door has no leaf or Gothic arch profile. |
| Notre-Dame clerestory | The dark panel is now an opening through the nave wall; side returns and sill read in both lights. A plain dark pane sits at the inner lip so the full portrait does not show sky through the windows. | The pane has no coloured glass or tracery. The rectangular lintel does not carry the old pointed visual cue. |
| Durham west portal | Two formerly obscured doors now open through the twin-tower and nave host walls. | Door leaves and mouldings remain absent. |

The ray fixture in `tests/suites/church_aperture_suite.gd` probes masonry at each opening, its neighbouring wall, and its jamb, head and sill. It ignores the pane surface, so a dark pane over solid stone still fails; the old solid wall control blocks the same ray. Other church windows are still shallow: aisle, transept, apse, tower upper stages, narthex, ambulatory chapel, crossing tower and dome drum. The rose window is also still a surface treatment. Those hosts need their own surface-aware cuts; this task does not claim them.

Render the candidate with `Godot_v4.5.2-stable_mono_win64_console.exe --path . --script res://tools/render_shots.gd -- vis005`. The `*_before.jpg` files were captured with the same VIS-005 shot definitions on the preceding builder.

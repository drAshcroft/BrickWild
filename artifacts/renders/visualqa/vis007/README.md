# VIS-007 buttress and flyer acceptance

The `before` frames use the assembled church scenes at VIS-005 commit `da81cc7`. The `after` frames keep each seed, camera, frame radius and camera-relative light fixed. Detail views show multiple bays, and the portrait pair checks whether the change survives normal building scale. Render with `Godot_v4.5.2-stable_mono_win64_console.exe --path . --script res://tools/render_shots.gd -- vis007`.

| Subject | Visible change | Limit |
|---|---|---|
| Durham nave buttresses | Two clear set-backs and three stone shoulders interrupt the former straight strip. Each stage casts a separate shadow. The twin-tower corner buttresses are placed at their actual tower centres. | The full portrait still gives these narrow supports few pixels; their rhythm is clearer than their profile from far away. |
| Notre-Dame flyers | The arch web is thicker, with a thin coping line running from pier to clerestory. The detail view shows a continuous bearing path and keeps the windows between landing bays. | The coping is restrained at whole-building scale; the very broad nave/aisle/roof proportions still govern the silhouette. |

`manifest_before.json` and `manifest_after.json` record detail focus, radius, seed, camera and light. The portrait before files are copied from the VIS-005 acceptance run at the same seed and hero camera. The focused `churchload` fixture re-emits the logged arch and coping triangles, measures all logged box components in the finished mesh, checks three shaft stages and shoulders, and compares component identities across seeded regeneration.

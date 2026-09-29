# Assembled scene comparison

Run `Godot_v4.5.2-stable_mono_win64_console.exe --path . --script res://tools/render_shots.gd -- scene-qa` to reproduce these five images. The two portraits in each pair use the same seed, camera, mesh bounds, and light. The mesh image contains only the builder's four surface mesh. The assembled image uses the normal roof-on assembler, its shell materials, its `prop_log`, and any castle room plans.

| Subject | Mesh-only omission | Verified scene dressing |
|---|---|---:|
| Notre-Dame (seed 5001) | Pews, lights, banners and other church models | 150 of 150 available models instantiated |
| Krak (seed 6002) | Yard and room props; interior room models | 129 of 129 available `prop_log` models instantiated; four bailey range shells and a well are generated |

The roof-on exteriors conceal most furniture. This is visible in the near-identical mesh and assembled hero images, so an exterior portrait cannot serve as proof that the furnisher is empty. The separate Krak courtyard image looks from the gate toward the inner yard. It shows the range shells and well; the props remain small at the scale of this 300 m fortress. The remaining plain masonry, narrow dark openings, and sparse-looking court are generator or presentation tasks, not a missing assembler call. The render path does not alter the bailey plan.

The machine-readable [manifest](manifest.json) records seeds, camera values, `prop_log` counts, instantiated model counts, and the generated range/well count. The diagnostic `-- mesh-only` flag keeps the former portrait path available for geometry comparisons; normal reference renders use the assemblers.

Working watermills
==================

The population-50 bakery request is retained when a village has water. Its
furnished shop, kitchen and storage remain normal generated rooms. The mill
is fitted to measured walls and the existing road frontage; the usual lot
retries can add a service lane when the first bank has no legal frontage.

`VillageWaterPlan.mill_race` tries side and rear walls, keeping the entrance
dry. A 1.2 m wide working channel lies along the wheel, with a short headrace
into a natural pond, stream, river or coast. It clears roads, commons,
reserved landmarks and every other lot. The shore clips only the unbuilt
mill yard; the measured building must still fit entirely on dry land.

Each `VillagePlan.water` race record carries its polygon, natural source
index, host building, wheel centre, wall point and outward wall normal. This
is planned geometry, shared by the dresser, emitter and checks. Only a race
whose host owns the lot may overlap that lot's yard. Other water/lot overlaps
remain failures.

The dresser reserves the wheel before ordinary props and plants. The axle
stands 1.15 m above the water; a 1.4 m radius PropKit wheel dips its paddles
below the surface while clearing the eave. Native opening records select a
blank wall bay, preserving every window and doorway. Its shaft points into
the real outer wall, not the interior footprint. Low timber
channel edges leave the mouth in natural water open. The builder raises the
wheel from the plan's elevation instead of burying half of it at ground zero.
No external models or textures were added.

Enclosures stop at natural shorelines. A narrow race through a masonry or
palisade edge receives a 0.6 m high hydraulic opening; a hedge stops on either
side. This is separate from road gates and planned bridges. Coastal sites
reserve a 20% water band, and the mill may reach the wider bank with a longer
headrace while still clearing roads and other lots.

`VillagePlaceCheck` independently measures race-to-water, race-to-wall,
road/other-lot clearance, wheel position, axle height and axle alignment.
The focused suite uses native bakery placement measurements across water,
enclosure and seed combinations; the reference renders build the fully
furnished shop through the public assembler. Mutations disconnect the race, move the
wheel, bury the axle, rotate it away from the wall and move it over glazing.
Actual mesh rays at 0.32 m also prove the channel and natural shoreline are
not dammed by the enclosure. Separate faulty builders put real masonry in
the water to show those checks fail. Planned bridge rails use their own
crossing checks and are excluded from the enclosure dam probe.

Reproduction (use the console executable beside the Godot path in AGENTS.md):

```
godot_console --headless --path . --script res://tests/run_all.gd -- vmill
godot_console --headless --path . --script res://tests/run_all.gd -- vmillfull
godot_console --path . --script res://tools/render_village_mill.gd
```

`vmillfull` uses 50 seeds for each of three enclosures and four natural water
types. It exercises the production site/frontage retry path and dresser for
the measured mill, without furnishing unrelated households repeatedly.
Roof-on and furnished cutaway references go to
`artifacts/p1p2_house/mill_renders/`.

The final matrix passed all 600 cases: 4,868 checks with zero failures or
warnings in `mill_shore_matrix_final.log` (254.01 seconds). This includes the
actual shore/race flow probes and three valid plus three dammed-shore controls.
`mill_shore_renders.log` records all eight completed rendered references.

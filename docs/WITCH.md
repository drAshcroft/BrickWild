# Witch hut

Notes on the witch house style: the independent visual review and what came of it. Size, wall, roof and eave rules are in `docs/HOUSES.md` ("The witch hut is small").

Props: a procedural cast-iron box stove (`WitchWoodStove`) set on the hearth recess slab, with its bay added after furnishing (`HouseWitchProps.add_stove_bay`); a catalogue Cauldron beside it; two procedural brooms. The brooms are procedural because the owned broom models (TFP_Broom_01/02, TEM_Broom_01) are under the Unity Asset Store EULA and must never reach a public repo.

## WITCH-REVIEW (2026-10-25)

Independent reviewer: fresh agent, from the renders of commit 67f6b3f

Render command: `godot --path . --script res://tools/render_witch_review.gd`

Images: `C:\Projects\BrickWild\artifacts\witch_review\renders\<case>_exterior.png`, `<case>_interior.png`, `<case>_broom.png`
for each case below. All 21 images were opened and judged from the pixels only.

Traits: (a) small, one storey; (b) rustic; (c) short walls under a high thatch roof; (d) cauldron AND wood-burning stove both identifiable; (e) broom visible.

| case | (a) small | (b) rustic | (c) short walls, high thatch | (d) cauldron + stove | (e) broom |
|---|---|---|---|---|---|
| witch_small_1 | ✓ | ✓ (borderline) | ✓ | ✓ | ✓ |
| witch_small_8102 | ✓ | ✓ (borderline) | ✓ | ✓ | ✓ (borderline) |
| witch_small_21325 | ✓ | ✓ (borderline) | ✓ | ✓ | ✓ |
| witch_tiny_1 | ✓ | ✓ (borderline) | ✓ | ✓ | ✓ |
| witch_tiny_8102 | ✓ | ✓ (borderline) | ✓ | ✓ | ✓ |
| witch_tiny_21325 | ✓ | ✓ (borderline) | ✓ | ✓ | ✓ |
| witch_oversize_clamp | ✓ (borderline) | ✓ (borderline) | ✓ | ✓ | ✓ (borderline) |

Notes on the borderline ticks:

- (b) all cases: thatch, stone plinth, plank floor, lean-to awnings and wooden furniture read as rustic. The walls are smooth flat plaster between regular, sawn-straight dark timbers, with glazed mullioned windows and shutters. That is a tidy half-timbered cottage, not a hand-made hovel. Passes only just.
- (a) oversize_clamp: one storey, roughly the size of the small cases. The three oversize images are the same as the small_8102 images, so the clamp is consistent with a 7 x 9 m one-storey hut. The render cannot show the 17 x 18 m request or the 2 storeys, so the clamp itself is not proved by the images.
- (e) small_8102 and oversize_clamp: the "broom close-up" is mostly hidden behind the workbench. Only the yellow head and a thin sliver of handle show. It is a broom, but not a good close-up.
- Broom in every case: a smooth yellow cone on a thin brown pole. No straw or twig detail, so it reads as a cone on a stick. Identifiable in context.

## Open

No trait fails outright. Every tick is below a clean pass in these places:

1. (b) rustic is borderline in all 7 cases: plaster and timber are too regular and clean, windows are glazed with mullions.
2. (e) small_8102 and oversize_clamp: broom close-up is occluded by the workbench.
3. (a) oversize_clamp: the clamp from 17 x 18 m, 2 storeys is not demonstrable from the images alone.
4. The broom head has no bristle detail (all cases).

## Observed

- Three of the seven cases are visually near-identical: small_1 and small_21325 have the same exterior and interior (only the table-top clutter in the broom view differs). oversize_clamp is identical to small_8102 in all three images. The seeds produce very little variety.
- A stove flue pipe is drawn in every interior, but only small_8102 and oversize_clamp have a chimney stack on the roof. The other five have no visible chimney through the thatch, so the flue ends nowhere.
- The box stove stands inside the masonry fireplace opening, next to the cauldron. A stove is normally a free-standing unit. Here it looks like an object placed inside the hearth.
- tiny cases: a second yellow broom head shows at the far end of the room, beside the fireplace (about x 455, y 420 in tiny_1 and tiny_8102 interiors). That may be a second broom, or the same broom seen twice.
- small_1 and small_21325: the cauldron awning (right side) slab runs into the thatch eave at the roof corner. Its high edge overlaps the roof edge.
- small_8102 and oversize_clamp: the left lean-to awning runs into the left wall at the eave.
- Hard-edged dark rectangle across the ground at the bottom of the exterior frames (small cases, a band beginning at about y 685). It looks like a shadow-map extent edge, not a building defect.
- A cauldron and fire stand outside under the awning in addition to the one in the hearth (small and tiny exteriors). Two cauldrons per hut. This may be intended.
- No z-fighting seen. No object seen floating clear of a surface other than as noted above.

## WITCH-REVIEW-FOLLOWUPS (2026-10-26)

What became of each item in "Open" and "Observed" above.

1. **Chimney "missing" on five huts.** Not missing: `hwitchflue` and the stack code (`HouseBuilder._build_chimney`) emit it on every hut. On those five it leaves the roof on the slope away from the door, and the high ridge hides a stack that stands 0.6 m clear of its own roof. `tools/render_witch_review.gd` now also writes `<case>_exterior_back.png`, the same three-quarter view from the opposite corner, so every hut shows its stack from at least one exterior view.
2. **Rustic reads tidy.** The style row sets `"unglazed": true` (read by `HouseGenerator` for the witch, outside the culture block): the windows are shuttered holes, with no glass, mullion or stone hood. The small gable casement keeps its own light. The plaster between the timbers is still smooth; an irregular infill or a rougher wall material is the next step if the hut still reads as a cottage.
3. **Second broom in the tiny huts.** Intended. `HouseWitchProps.plan_props` places one broom by the entrance door and a second by the stove. In a 5.5 x 7 hut the stove broom stands at the far end of the same room, so the camera sees both.
4. **Awning clips the eave.** Fixed (2026-10-27). The shelter roof now starts at the thatch's edge on the same plane (`HouseYard._witch_thatch_edge` marches out from the wall until `RoofShape.height_at` leaves the roof; `_witch_shelter_module_parts` shortens the slab to start there), the thatch itself roofs the strip against the wall, and the wall ledger is dropped where the roof bears on the thatch (it would stand in the door's reserved approach). The wing's side returns stop at the thatch's underside. `WitchAwningCheck` (`qa/witch_awning_check.gd`, run by `hwitchsize`) samples the shelter roof against the house roof slab: old code put 54 to 162 samples up to 6.5 cm inside the thatch on every hut, now none; a control hangs the roof from the wall again and the check must fire.
5. **Broom is a smooth cone.** `HouseWitchProps._add_twigs` lays 18 loose twigs over the flare, from the binding to just past the foot, splayed and of uneven length, in a darker straw. Fixed pattern, no randomness; the twigs stay inside the broom's plan rect.
6. **Little variety between seeds.** Not addressed. small_1 and small_21325 share a plan; the clamp control is the 8102 hut by design.

The deep eave (WITCH-DEEP-EAVE, 0.6 m on ashlar posts) also lands in the next render.

## WITCH-THATCH-FORM (2026-10-27)

A walker said the thatch "does not make sense: thatch has round corners and a brush end". Seen from the walk camera the hut had a five-point faceted eave hump, a tent-shaped ridge roll whose apex stood up as a spike at each gable, and flat square-cut verges with nothing on the rakes. `HouseBuilder._build_thatch_roll` and the new `_build_witch_thatch_edges` now give it:

- **Round eaves.** The Witch eave is the cottage's elliptical bundle (`_cottage_eave_bolster`, 14 vertices, no corner over 26 degrees), not the hump.
- **Saddle ridge.** The ridge roll is the cottage saddle (`_cottage_ridge_saddle`), crown turn 22.5 degrees, not the tent.
- **Rolled verges.** `thatch_verge`: an ellipse (`VERGE_ROLL_A/B`) run up each of the four gable rakes, centred its own half-width in from the verge so it stays inside the roof's plan. A half-hipped hut has no rakes and gets none.
- **Brushed ends.** `thatch_brush`: sawn reed ends 0.07 to 0.20 m long hang under every eave and verge edge at a 0.14 m pitch, lengths from a fixed low-discrepancy sequence (`HouseGeometry.brush_length`), so no two neighbours match and the edge is not a dentil course.

`ThatchFormCheck` (`qa/thatch_form_check.gd`, run by `hwitchsize` on every hut) measures all four; its controls are the old hump, the old tent and a thatched cottage (soft eave and saddle but no verge roll or brush). `tools/render_witch_thatch.gd` renders the gable, side, eave and apex close-ups (`THATCH_TAG=name` prefixes the files in `artifacts/witch_followups/thatch/`). Blind review from the walk camera is still the user's; the renders show round eaves and verges and a ragged edge. Known: where the two verge rolls meet at the apex they cross as two cylinders and make a small round knob above the ridge; it reads as a thatcher's finial, not a spike.

## Still open (2026-10-28)

- Seed variety (FOLLOWUPS item 6): small_1 and small_21325 share a plan. The clamp control is the 8102 hut by design.
- Rustic: the windows are now unglazed, but the plaster infill is still smooth. A rougher infill is the next step if the hut still reads as a cottage.
- WITCH-THATCH-FORM: the blind review from the walk camera is still the user's to do.
- `harchetype` has no `witch_hut` row of its own. Its nearest case is `alchemist` (style `witch_hut`, trade alchemist). The trade-less hut's stove, cauldron and brooms are proved by `witch_firebox_lining_test`, `hwitchcompact` and `hwitchsize`, not by harchetype.

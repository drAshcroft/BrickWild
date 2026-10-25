# Witch hut

Notes on the witch house style. This file currently holds the independent visual review only.

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

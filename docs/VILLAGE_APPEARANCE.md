# Village decoration and upkeep

Villages have two independent controls, both from `0.0` to `1.0`:

| Control | Low end | High end | Default |
| --- | --- | --- | --- |
| `decoration_level` | Bare, functional streets and muted finishes | Lush plants, flowers, street ornaments and colorful finishes | `0.5` |
| `upkeep` | Weathered finishes and neglected dressing | Cared-for finishes and planting | `1.0` |

The defaults retain the previous appearance. Culture still chooses the
architecture and planting palette. Wealth still chooses the settlement's
programme. Appearance does not move roads, lots, doors or households.
This controls dressing and finish; it does not replace the architecture with
concrete towers or simulate structural decay.

```gdscript
var request := BuildingRequest.compact_village(741, 40, &"mediterranean")
request.decoration_level = 1.0
request.upkeep = 1.0
var village := BrickWild.generate(request)
var scene := BrickWild.instantiate(village)
```

Both fields survive request copying and JSON transport. Default values are
omitted from JSON so older request documents retain their shape. The public
village descriptor publishes their ranges and defaults. The site-request
exporter accepts the same normalized fields. Studio exposes both sliders;
choose **Grow village** to apply them.

| Scene idea | Culture | Decoration | Upkeep | Wealth |
| --- | --- | --- | --- | --- |
| Sunny Italian fantasy village | `mediterranean` | `1.0` | `1.0` | Any |
| Green village with an Irish fantasy mood | `english` or `frankish` | `1.0` | `1.0` | Any |
| Neglected settlement or slum | Your chosen culture | `0.15` | `0.0` | Set separately |
| Buildings and functional basics | Your chosen culture | `0.0` | `1.0` | Any |

There is no dedicated Irish architectural culture yet. The second row is a
starting point using existing vernacular buildings, rather than a claim of
historical Irish accuracy.

Essential wells, trade equipment, gates, lighting, enclosure planting and
productive landscape remain where needed. Optional planting uses measured
trunk and canopy bounds and the existing door and road clearance rules.
A lush request can place fewer objects when a compact site has little space.
Below `0.5`, household planting groups thin deterministically along with
village dressing. Paired beds remain paired. At zero their models and any
collision children are removed.

## Open ground

A native (non-compact) village's site is sized for its roads, so there can be
tens of metres of land between the last lot and the edge band that is not a
lot, a road, the common or a field. `VillageDresser.open_ground` finds that
land by measurement -- grid points with nothing planned within 7 m -- and
dresses the most open of them, 15 m apart: a copse from the culture's edge,
hedge and ground palettes, or in a farming or forest village every other patch
a hay meadow (a built haystack with cover round it). Only plants and built
pieces go there, because open land is not walk-grid floor. The pass runs last
on its own named streams, so every earlier placement is unchanged. Decoration
`0.0` places none; `0.5` dresses every patch found; above it the patches are
fuller. Low upkeep turns some copse trees to dead wood. Compact displays keep
their own gap planting and skip this pass. Open-ground plants carry
`zone = &"open"`.

Every assembled model is checked against the ground by `VillageGroundCheck`
(`-- vground`, in `lane:village-fast`): props by their lowest vertex, plants by
their ground line, and each house's yard and facade models against the height
their own plan row gives. See the walk-QA note in `SceneBounds.plant_seat`.

## Asset ideas

The first implementation uses the project's existing measured catalogue.
No new asset pack is required. An owned-library search found CC0 flower
models (`flower_purpleA/B/C`, `flower_redA/B/C`) and oak/palm variants in
`kenney_nature-kit`, plus `planter` in `kenney_city-kit-suburban_20`.
These are candidates for later catalogue integration, not newly imported
assets. Searching owned CC0 3D assets for ivy returned no matches.

Useful additions for the next pass:

- Climbing ivy, grape vines and wall trellises for Italian courtyards.
- Olive and cypress trees to distinguish Mediterranean planting.
- Flower boxes, terracotta urns and hanging baskets for cottage streets.
- Low dry-stone walls, gates and thick hedges for an Irish fantasy mood.
- Laundry lines, patched awnings, scrap piles and boarded shutters for
  neglected districts.

Measure each addition and its use space before placing it. Wall-mounted
plants also need a support surface and door/window clearance. Imported art
must go through the catalogue rebuild and asset QA gate.

## Checks and comparison views

```powershell
& tools/run_qa_lane.ps1 -Selectors lane:village-fast,lane:village-appearance-fast
```

The combined bounded gate passed 91 checks in 169 seconds on 5 October 2026,
with no failures or warnings. It includes a deliberately blocked doorway
which the plant-clearance check must reject. Material tests also check that
painting preserves mesh identity and clones shared materials.
The subsequent full appearance gate passed 62 checks in 80 seconds;
the final 11-check material fixture also verifies numbered household groups,
paired planting and removal of ornamental collision children. The public
API lane passed 390 checks in 221 seconds.

Render the same Mediterranean compact village with basics, neglected,
legacy and storybook profiles:

```powershell
godot --path . --script res://tools/render_building_audit.gd -- --family:village-appearance
```

Use the installed Godot executable from `AGENTS.md`. Rendering requires a
real renderer. Captures and their request/camera/QA manifest go to
`artifacts/renders/building_audit/village-appearance/`. The comparison reuses
one retained settlement plan and fixes the camera framing to its site and
architecture. It includes both an overview and a street-height view.
The four-profile audit passed full village plan QA and captured eight images.
For this seed, native village plant counts are 2 (basics), 6 (neglected),
14 (legacy), and 22 (storybook). These counts exclude household yard models.

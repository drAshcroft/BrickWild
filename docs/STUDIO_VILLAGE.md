# Village Studio

Choose Village in the Studio to grow a seeded settlement. Population, culture,
purpose, wealth, water and edge controls come from `BigGlade.describe_kind()`;
the UI has no separate option tables. Set the controls and press **Grow village**.
**New seed** keeps the controls and grows another settlement.

The preview uses `VillageAssembler`, so it shows the same buildings, gardens and
street furniture as an instantiated village. The sheet beneath it draws the
actual plan's roads, lots, frontages, common, water and enclosure. Its enclosure
comes from `VillageEnclosurePlan`, the same geometry source as the builder.

![Village Studio with a pond, hedge, four houses and its plan](screenshots/studio_village.png)

The screenshot is seed 42021, population 16, English farming, wealth 45%, pond
and hedge. Reproduce it with a visible renderer:

```powershell
godot --path . --script res://tools/shoot_studio.gd -- village
```

The capture writes both `artifacts/renders/studio_village.png` and the tracked
documentation image above. `tests/studio_village_test.gd` checks that UI options
match the public descriptor, the seed control exists, water/edge survive request
JSON, zero wealth is valid, small defensive walls are refused, and the blueprint
retains the actual VillagePlan. The capture additionally exercises real generation
and assembled model assets. The three-column Studio uses an `HBoxContainer`;
`HSplitContainer` only lays out two children.

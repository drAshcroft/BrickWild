# Grand hotels

The Grand Budapest-inspired hotel is a landmark family with a real furnished
interior behind its storybook elevation. It is not a scaled-up house facade.

```
HotelSpec -> HotelPlanner -> HouseFurnisher -> HousePlan
                                      |-> HotelBuilder -> ArrayMesh
                                      `-> HotelAssembler -> furnished scene
```

## Landmark vocabulary

The supplied front elevation was translated into measurable rules:

- a broad facade at least 1.55 times its depth;
- an odd rhythm of 11-21 tall paired-window bays;
- strict bilateral window symmetry;
- three corniced wall zones and a raised central pavilion;
- a steep dark mansard-like roof with repeated dormers;
- two end towers with onion-profile cupolas and finials;
- three balustraded balconies;
- a columned, arched ceremonial entrance on the central axis.

Pink plaster, cream trim, dark blue roofs, and red interior floors are separate
mesh surfaces so callers can replace the materials without rebuilding geometry.

## Interior

Every hotel carries 18 rooms over three walkable storeys. The ground level has
the lobby, dining room, lounge, kitchen, office, and stores. Upper levels have
guest rooms, suites, galleries, laundries, and a central stair spine. Furniture
uses the same measured prop catalogue and clearance-aware placer as houses.

## Harness

`HotelQA` composes the complete house plan, furnishing, daylight, navigation,
and shell checks with landmark-specific proportion and symmetry rules.

```
godot --headless --path . --script res://tests/run_all.gd -- hotel hlandmark
```

The landmark suite builds the reference at 78%, 100%, and 130% scale. It says
what the building must contain, never where the generator must place every
piece beyond the defining axial and symmetry constraints.

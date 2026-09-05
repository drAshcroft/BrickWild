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

A hotel is a corridor building. Every level has one **gallery** running the
full length of the plan, and rooms off it on both sides: two facade bays to a
room, so the room count follows the elevation's rhythm rather than a
constant. The ground floor keeps the public programme along the street --
dining room, lobby under the centre pavilion, lounge -- and the service
programme along the yard -- kitchen with the back door, office, laundry,
store, and any cells left over as ground-floor guest rooms. Above, the front
rank is guest rooms with the suite in the middle and the back rank is guest
rooms all along. Every guest room and suite has exactly one door, onto the
gallery; the stairs rise in the gallery, against its back wall, as near the
axis as the doors allow, and join gallery to gallery. `HotelQA` measures all
of that (`gallery`, `bays`) on top of the house harness, whose privacy rule
is what the old six-room level used to fail. Furniture uses the same measured
prop catalogue and clearance-aware placer as houses.

## Harness

`HotelQA` composes the complete house plan, furnishing, daylight, navigation,
and shell checks with landmark-specific proportion and symmetry rules.

```
godot --headless --path . --script res://tests/run_all.gd -- hotel hlandmark
```

The landmark suite builds the reference at 78%, 100%, and 130% scale. It says
what the building must contain, never where the generator must place every
piece beyond the defining axial and symmetry constraints.

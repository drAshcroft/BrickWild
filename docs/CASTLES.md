# Castle reference

Real dimensions and defining features for the fortifications the castle
generator is expected to be able to build. Sources at the bottom.

## Tiers

One input decides what KIND of building comes out: the footprint. The bands are
in `CastleSpec.TIERS`, and `CastleSpec.tier_for(w, l)` is the only place the
rule is written down.

| Tier | Footprint area | What it builds |
|---|---|---|
| house | up to 300 m² | one hall block, a porch, an annexe, external chimney stacks |
| manor | up to 2 000 m² | a main range with cross wings round a court, optionally closed by a front range, with towers on the wing ends |
| castle | up to 12 000 m² | a curtain wall with corner and mural towers, a gatehouse, and a keep, hall and chapel inside the bailey |
| fortress | above that | all of the above, plus a second enceinte inside the first, a barbican, and a walled causeway joining the two gatehouses |

A tier can be pinned with `CastleSpec.tier_override`, which is how the landmark
sweep below scales a real building without it turning into a different kind of
building on the way down.

## Landmarks

| Building | Style | Site W x L x H (m) | Tier | Defining features |
|---|---|---|---|---|
| Medieval longhouse | Norman | 6.5 x 18 x 4.5 | house | one range under a single ridge, gable **chimney stack**, no defences |
| Stokesay Castle | Norman | 30 x 24 x 10 | manor | earliest English **fortified manor house**: great hall 16.6 x 9.4 m between a north and a south **tower** |
| Hampton Court range | French Château | 40 x 28 x 11 | manor | Tudor **courtyard house**: ranges on all four sides of a base court, a **forest of chimney stacks** |
| Bodiam Castle | Edwardian | 55 x 50 x 18 | castle | textbook **quadrangular castle**: four **round drum towers** 9 m across and 18 m high, walls ~2 m thick, **twin-towered gatehouse**, moat |
| Caernarfon Castle | Edwardian | 170 x 60 x 12 | castle | **polygonal** rather than cylindrical towers -- seven of them -- two twin-towered gates, curtain to 12 m, walls 6 m thick in places; Eagle Tower 28 m to the parapet |
| Neuschwanstein | Bavarian Romantic | 150 x 40 x 25 | castle | a **150 m ridge of ranges**, slender stair towers under tall **conical spires**, the northern one 65 m |
| Himeji Castle | Japanese | 60 x 50 x 15 | castle | **tiered tenshu**: a 15 m battered stone base carrying a 31.5 m timber keep, five storeys outside and seven within, with yagura turrets |
| Château de Chambord | French Château | 156 x 117 x 32 | fortress | 156 m facades, an enceinte round a 44 m-square **keep**, **round corner towers** under conical roofs, a **dormered roofscape**, 56 m tall |
| Krak des Chevaliers | Crusader | 300 x 140 x 20 | fortress | the **concentric** castle: two enceintes, 300 m at its longest and 140 at its widest, outer curtain ~9 m tall and 3 m thick with seven round towers 8-10 m across, inner walls over 4 m thick, and a great **battered talus** |
| Alhambra (Alcazaba) | Moorish | 200 x 70 x 16 | fortress | **square mural towers** and flat roofs; the Torre de la Vela is 16 x 16 m in plan and 26.8 m high |
| Windsor Castle (upper ward) | Norman | 200 x 120 x 18 | fortress | a **shell keep** -- the Round Tower, 30.5 x 27.5 m internally, 20 m above the ward -- inside a walled bailey |

## Feature checklist this drives

- curtain walls with a battered talus, a wall walk and crenellations
- towers: round drums, square towers, polygonal towers; conical, pyramidal,
  flat and tiered caps
- gatehouses with flanking drums, murder holes and a barbican outwork
- concentric planning: an inner ward, and the causeway that ties it to the
  outer gate
- keeps: great square towers, drums, shell keeps, tiered tenshu
- domestic ranges: great hall, chapel, cross wings, courtyard ranges, porches,
  dormers, chimney stacks

## What the suites check

`castle`, `castle normals`, `castle massing`, `castle landmark` and
`castle voxel QA` -- run with
`godot --headless --path . --script res://tests/run_all.gd -- castle cnormals cmassing clandmark cvoxelqa`.

The landmark sweep builds every row above at 40%, 70%, 100% and 150% of its
real size, forces the features that make it that building, and then requires
both that the geometry for those features exists and that the massing is still
sound. Krak is the exception worth knowing about: below full size there is no
room between two enceintes for the inner ring's towers to clear the outer
ring's, so it generates as a large single-ward castle, and the suite asserts
that it IS concentric at full size.

## Sources

- https://en.wikipedia.org/wiki/Bodiam_Castle
- https://great-castles.com/bodiamplan.html
- https://en.wikipedia.org/wiki/Krak_des_Chevaliers
- https://archeologie.culture.gouv.fr/crac-chevaliers/en/about-castle
- https://madainproject.com/outer_ward_of_krak_des_chevaliers
- https://en.wikipedia.org/wiki/Caernarfon_Castle
- https://medievalheritage.eu/en/main-page/heritage/wales/caernarfon-castle/
- https://en.wikipedia.org/wiki/Ch%C3%A2teau_de_Chambord
- https://en.wikipedia.org/wiki/Neuschwanstein_Castle
- https://en.wikipedia.org/wiki/Himeji_Castle
- https://www.hyogo-c.ed.jp/~rekihaku-bo/historystation/sp/rekihaku-db/castle/himeji/ca1_en.html
- https://www.english-heritage.org.uk/visit/places/stokesay-castle/history-and-stories/description/
- https://en.wikipedia.org/wiki/Stokesay_Castle
- https://en.wikipedia.org/wiki/Hampton_Court_Palace
- https://www.alhambradegranada.org/en/info/alcazaba/watchtower.asp
- https://castlestudiesgroup.org.uk/wp-content/uploads/2024/10/Shell-Keeps-Catalogue1-Windsor-low-res-07-09.pdf

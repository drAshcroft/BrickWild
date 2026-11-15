# Interior layout rules for a procedural house generator: the guides

Research for BrickWild house interiors. This file covers design guides, standards,
pattern books, the computer graphics layout papers, and historic room use. It does
NOT cover datasets; a separate agent handles those.

Compiled 2026-11-14. Every number is in metres (1 in = 0.0254 m, 1 ft = 0.3048 m).
Where a number is my estimate rather than a source's, it says **ESTIMATE**.

Tags: **[MODERN]** = a modern residential standard; **[HISTORIC]** = how pre-modern
or vernacular rooms were actually arranged; **[UNIVERSAL]** = human body or physics,
true in any period.

---

## 0. Conventions used by the `check:` lines

The checks assume this data model:

* `room`: oriented rect, `kind`, `storey`.
* `door`: `pos`, `normal`, `width`, the two rooms it joins, `swing_side` if known.
* `window`: `pos`, `normal`, `width`, `sill`.
* `hearth`: footprint rect, `kind` (open central / wall fireplace / stove / irori /
  kamado), `facing` normal (none for an open central hearth).
* `furniture`: `key`, `category`, `pos`, `yaw`, `footprint` (oriented rect). "Front" is
  the item's use face. "Back" is the opposite face.

Helper terms:

* `front_zone(f, d)`: rect of depth `d` against f's front face, as wide as f.
* `side_zone(f, side, d)`: the same rect against a side face.
* `swing(door)`: quarter disc of radius `door.width`, hinged at the jamb, on the swing
  side. If the swing side is unknown, use a half disc on both faces.
* `walk(room, r)`: the room's free floor after dilating every footprint and wall by
  radius `r`. Default `r = 0.457 m`, a person disc of 18 in (Merrell 2011, citing Panero).
* `dist(a, b)`: shortest rect-to-rect distance.
* `faces(f, p, tol)`: the angle between f's forward vector and `p - f.pos` is at most
  `tol`. Default `tol = 30 deg` (**ESTIMATE**. Merrell uses a smooth cosine, not a cutoff).
* `wall_gap(f)`: distance from f's back face to the nearest wall segment.
* `depth(room)`: door-steps from the main entrance in the room graph.
* `focal(room)`: the hearth if the room has one; otherwise the largest window, or a
  declared focal item.

---

## 1. Anthropometric clearances

The primary books (Panero & Zelnik, *Human Dimension and Interior Space*, 1979; Neufert,
*Architects' Data*; *Time-Saver Standards*) could not be fetched in text form. The
Panero numbers below come through Merrell et al. 2011, Table 1, which quotes Panero &
Repetto 1975 directly. Other numbers are from NKBA (a published standard) and from named
architects in trade press. Treat those as secondary.

### A1. Person-sized circulation everywhere [UNIVERSAL]
* Rule: a person must be able to walk to every part of the room and to every item.
  Model the person as a disc.
* Number: disc radius **0.457 m** (18 in). The free space should be ONE connected
  component.
* Source: Merrell et al. 2011, sec. 2.1 "Circulation", citing Panero & Repetto 1975.
  https://graphics.stanford.edu/projects/furniture/ (PDF: https://paulmerrell.org/furnitureLayout2.pdf)
* check: build `walk(room, 0.457)`. Count connected components. Require exactly one, and
  require it to touch every door's inside threshold and every item's use zone (A3-A8).
  Historic interiors were tighter, so you may relax `r` to 0.30 m for pre-1700 rooms
  (**ESTIMATE**).

### A2. Walkway widths [MODERN, UNIVERSAL core]
* Rule: a walkway (a path someone takes to pass through) needs a clear width.
* Numbers:
  * Kitchen walkway: **0.914 m** (36 in). NKBA KPG 7.
  * Living room circulation: **0.76-0.91 m** (30-36 in). Architect Steven Randel, Houzz.
  * Movement between pieces of furniture: **0.61 m** (24 in). Same source.
* Sources: NKBA Kitchen Planning Guidelines with Access Standards,
  https://kb.nkba.org/uploads/2022/05/Kitchen-Planning-Guidelines.pdf ; Houzz "Measurements
  to Know", https://www.houzz.com.sg/ideabooks/109239110
* check: for each door pair in a room, shortest path in `walk(room, w/2)` with
  w = 0.76 m. Fail if none exists. Between two adjacent items, `dist >= 0.61 m`, or else
  the gap must be under 0.05 m (pieces deliberately abutted). A gap of 0.1-0.5 m is a
  dead sliver that reads as a mistake (**ESTIMATE** for the sliver band).

### A3. Clearance in front of seating [UNIVERSAL]
* Rule: a seat needs free floor in front for legs and for getting up.
* Number: **0.762 m** (30 in) in front.
* Source: Merrell 2011 Table 1 (Panero & Repetto 1975).
* check: `front_zone(seat, 0.762)` holds no other footprint except an allowed partner:
  a coffee table at 0.41-0.46 m (A7), a dining table (A6), a desk, or a footstool. It
  must not cross a wall or a door swing.

### A4. Clearance in front of cabinets, shelving, chests and wardrobes [UNIVERSAL]
* Rule: storage must be openable and reachable.
* Numbers:
  * Cabinets and shelving: **0.61 m** (24 in) in front. Merrell 2011 Table 1 (Panero).
  * Walkway in front of a wardrobe with hinged or sliding doors: **0.76-0.91 m**
    (30-36 in). Prozfile, via Houzz.
  * Wardrobe depth: 0.60-0.65 m. Same source.
* check: `front_zone(storage, 0.61)` is free. For a hinged-door wardrobe or a lidded
  chest, the zone must be at least the door-leaf or lid depth, and at least 0.76 m for
  a wardrobe. A chest whose lid opens against a wall or under a shelf fails.

### A5. Clearance beside a bed [UNIVERSAL]
* Rule: you get in on a side and you make the bed from the sides and the foot.
* Numbers:
  * Comfortable: **0.914 m** (36 in) "to the side". Merrell 2011 Table 1 (Panero).
  * Minimum at the sides and foot of a double bed: **0.50-0.55 m**. Architect Eva Byrne,
    Houzz.
  * A single bed may have one long side against a wall. Same source.
* check: for a double bed, both long sides need `side_zone(bed, s, 0.50)` free, and the
  foot needs `front_zone(foot, 0.50)` free. For a single bed, one long side needs 0.50 m
  free and the other may have `wall_gap <= 0.05`. A historic box bed, bed alcove or
  curtained bed is exempt from the wall sides (see H-rules).

### A6. Dining table clearances [MODERN numbers, UNIVERSAL principle]
* Rule: chairs pull out, and people pass behind seated diners.
* Numbers:
  * All round a dining table: **0.914 m** (36 in). Merrell 2011 Table 1 (Panero).
  * Table edge to a wall with no traffic behind: **0.813 m** (32 in). NKBA KPG 8.
  * Someone edging past a seated diner: **0.914 m** (36 in). NKBA KPG 8a.
  * Someone walking past a seated diner: **1.118 m** (44 in). NKBA KPG 8b.
  * Width per diner (knee space): **0.61 m** (24 in), with depth 0.457 m at a 0.76 m table
    height. NKBA KPG 9a.
  * Place setting width about 0.60 m, attributed to Neufert and Time-Saver Standards by a
    student handout (Studio Matrx); unverified against the book.
* Sources: NKBA PDF above; Merrell; https://www.studiomatrx.org/students/space-planning-ergonomics/space-standards-and-clearances
* check: for each seated side of a table, the band from the table edge outwards must be
  free for 0.813 m (no passage) or 1.118 m (if any door-to-door path crosses it). Seat
  count must be at most floor(edge length / 0.61) per side. A chair that cannot be
  pulled 0.45 m back without hitting something fails (**ESTIMATE** for the 0.45 m
  pull-out).

### A7. Coffee table to seat [MODERN]
* Rule: a low table is within reach of the seat in front of which it stands.
* Number: **0.41-0.46 m** (16-18 in) from the seat front.
* Source: Merrell 2011 Table 1 (Panero).
* check: for each coffee/low table, find the nearest seat whose front zone it occupies.
  The gap must be 0.41-0.46 m (soft band 0.30-0.60 m).

### A8. End table and nightstand [MODERN, UNIVERSAL principle]
* Rule: a side table touches or almost touches its partner, at the side of a seat or at
  the side of a bed's head.
* Number: **0-0.30 m** (0-12 in).
* Source: Merrell 2011 Table 1 (Panero).
* check: each nightstand has `dist(nightstand, bed) <= 0.30`. It sits beside the head
  half of a long side, and its front faces the same way as the bed's foot. Each end table
  has `dist <= 0.30` to a seat's side or back. An orphan side table with no partner
  within 0.30 m is a failure.

### A9. Conversation distance [UNIVERSAL]
* Rule: seats in one conversation group are close enough to talk at normal volume, and
  angled toward each other.
* Numbers:
  * Seat to seat: **1.22-2.44 m** (4-8 ft). Merrell 2011 sec. 2.1, citing Panero.
  * A grouping arc of about **2.44 m** (8 ft). Steven Randel, Houzz.
* Angle term (Merrell): maximise (cos θfg + 1)(cos θgf + 1) for each seat pair, where θ is
  the angle between a seat's forward vector and the direction to the other seat.
* check: cluster the seats in a sitting room or hall by single linkage at 2.44 m. Within
  each cluster, every pair is 1.22-2.44 m apart centre to centre. Their mean pairwise
  (cos+1)(cos+1) is at least 1.0, out of a maximum of 4 (**ESTIMATE** threshold).

### A10. The hearth: clear floor and keep-out [UNIVERSAL physics; MODERN code numbers]
* Rule: a non-combustible hearth extends in front of and beside a fireplace opening.
  Nothing combustible stands on it.
* Numbers (IRC R1001.10):
  * **0.406 m** (16 in) in front and **0.203 m** (8 in) beyond each side, when the
    opening is under 0.557 m² (6 ft²).
  * **0.508 m** (20 in) in front and **0.305 m** (12 in) beyond each side, when the
    opening is 0.557 m² or more.
  * These are minimums.
* Sources: https://inspectapedia.com/chimneys/Fireplace_Hearth_Specifications.php ;
  https://rumford.com/code/IRC12.html
* Open central hearth: no code applies. Use a keep-out of **0.5 m** from the hearth edge
  for any combustible footprint, and put the seats in a ring **0.5-1.5 m** from the edge
  (**ESTIMATE**, made by analogy with IRC and Holodeck's "near" band).
* check: `front_zone(fireplace, 0.41 or 0.51)`, widened by the side margins, is free of
  every footprint except fire irons, andirons, a fire screen, and a cooking pot or crane.
  For an open hearth, no bed, chest or textile item lies within 0.5 m of the hearth rect.

### A11. Doors: width, interference and swing [UNIVERSAL]
* Rule: a door has a clear opening, and its leaf sweeps an arc that must stay empty.
  Appliance and furniture doors must not collide with entry doors.
* Numbers: clear opening at least **0.813 m** (32 in), which takes a 0.864 m (34 in) door.
  NKBA KPG 1. Historic internal doors were often narrower; keep at least 0.70 m
  (**ESTIMATE**). Holodeck uses a 1 m single door and a 2 m double door.
* Sources: NKBA KPG 1 and 2; Holodeck (CVPR 2024), https://arxiv.org/html/2312.09067v2
* check: `swing(door)` intersects no footprint. Every door's threshold rect (door.width x
  0.6 m on each face, **ESTIMATE**) is free. No two item opening zones (wardrobe door,
  oven door, chest lid) overlap each other or a door swing.

### A12. Toilet and bath fixture clearances [MODERN]
* Rule: a toilet needs clear width.
* Numbers: at least **0.76 m** wide clear (30 in); **0.81-0.91 m** is more comfortable.
  Steven Randel, Houzz.
* check: the toilet's footprint, widened sideways to 0.76 m, overlaps no wall or item,
  with 0.53 m free in front (**ESTIMATE**, matching NKBA's 21 in standing space).

---

## 2. Kitchens: modern NKBA guidelines and pre-modern hearth kitchens

### 2a. NKBA Kitchen Planning Guidelines (KPG), the ones that bear on layout

Source for all: https://kb.nkba.org/uploads/2022/05/Kitchen-Planning-Guidelines.pdf
(read in full; guideline numbers are NKBA's own).

| ID | Rule | Number (m) | check |
|---|---|---|---|
| K1 (KPG 3) [MODERN] | Work triangle: cooking surface, cleanup/prep sink and refrigerator. Each leg is measured centre-front to centre-front. | total **<= 7.92**; each leg **1.22-2.74**; a leg may cross an island by no more than **0.305** | find the three centres, sum the legs, test each leg. Intersect each leg segment with the footprints and allow at most 0.305 m inside one. |
| K2 (KPG 4) [MODERN] | No full-height, full-depth tall item (tall cabinet, refrigerator) between two primary work centres. | - | along the counter run between two centres, no item with height above 1.5 m (**ESTIMATE** for "tall"). |
| K3 (KPG 5) [UNIVERSAL] | No major traffic path crosses the work triangle. | - | intersect every door-to-door shortest path with the triangle polygon. Fail if a through-path crosses it. |
| K4 (KPG 6) [UNIVERSAL] | Work aisle between facing counters or appliances. | **>= 1.067** for one cook, **>= 1.219** for several | the distance between opposite counter fronts is at least 1.067 m. |
| K5 (KPG 7) [UNIVERSAL] | Walkway. | **>= 0.914** | as A2. |
| K6 (KPG 10) [MODERN] | A single sink stands next to or across from the cooking surface and the refrigerator. | - | the sink is on the same run as one of them, or faces it within 1.22 m. |
| K7 (KPG 11) [MODERN] | Landing area at the sink. | **0.61** one side, **0.457** the other | free counter length on each side of the sink. |
| K8 (KPG 12) [MODERN] | Continuous prep area right next to the sink. | **0.914 x 0.61** | a counter segment of that size adjoins the sink. |
| K9 (KPG 16) [MODERN] | Refrigerator landing area. | **0.381** on the handle side, or across within **1.219** | free counter next to the fridge. |
| K10 (KPG 17) [UNIVERSAL] | Landing either side of the cooking surface. | **0.305** one side, **0.381** the other; island counter **0.229** behind | free surface on both sides. A cooker hard against a side wall fails. |
| K11 (KPG 18) [UNIVERSAL] | Clearance above the cooking surface. | **0.61** to a protected surface above | nothing combustible within 0.61 m above the hob. |
| K12 (KPG 20a) [UNIVERSAL] | Cooking surface not under an operable window. | - | no window whose footprint projects over the hob. |
| K13 (KPG 24) [MODERN] | Two adjacent landing areas: take the longer requirement and add 0.305. | **+0.305** | where two landing areas share a counter, their length must be at least max + 0.305. |
| K14 (KPG 25) [MODERN] | Total countertop frontage. | **4.013** of frontage, 0.61 deep | sum the counter lengths. Scale down for a historic or small kitchen (see K18). |

Christopher Alexander gives a looser, period-neutral version:

### K15. Cooking Layout (A Pattern Language #184) [UNIVERSAL]
* Rule: place the stove, the sink, the food storage and the counter so that no two of
  the four are more than 10 ft apart. The counter totals at least 12 ft, excluding sink,
  stove and refrigerator. No counter section is under 4 ft. The counter may be
  free-standing tables.
* Numbers: pairwise distance **<= 3.05**; total counter **>= 3.66**; each section
  **>= 1.22**.
* Source: https://urbigenous.net/a-pattern-language/pattern-184.html
* check: map fire/stove -> `hearth` (or kamado), water -> sink/basin/water barrel,
  storage -> larder/pantry door or meal chest or dresser, counter -> work tables. All
  pairwise centre distances must be at most 3.05 m. This version fits a hearth kitchen
  better than K1.

### K16. Sunny Counter (#199) [UNIVERSAL]
* Rule: put the main counter on the south and south-east side of the kitchen, with big
  windows round it.
* Source: https://urbigenous.net/a-pattern-language/pattern-199.html
* check: the main work table or counter lies against a wall whose outward normal points
  between E and S (northern hemisphere) and is within 1.5 m of a window
  (**ESTIMATE** for 1.5 m).

### K17. Farmhouse Kitchen (#139) [UNIVERSAL; HISTORIC for farm and cottage]
* Rule: make the kitchen big enough to include the family room. Put it near the centre of
  the commons, with a good big table and chairs, and counters, stove and sink round the
  edge.
* Source: https://urbigenous.net/a-pattern-language/pattern-139.html
* check: in a cottage or farm house, the kitchen (or the hall/"house" that cooks) holds a
  table with at least 4 seats in the middle, and its work fixtures are against the
  walls. Its `depth()` is at most 1.

### 2b. How pre-modern kitchens were laid out [HISTORIC]

### K18. Where the cooking happened
* In the standard medieval English plan the kitchen was often a **separate building**,
  reached through a central door at the service end. The doors to the pantry and buttery
  flanked it. Sources: https://en.wikipedia.org/wiki/Great_hall ;
  https://en.wikipedia.org/wiki/Hall_house
* In 1570-1665 London, halls and parlours were heated but "only a small residue of cooking
  equipment" appears in halls. Cooking had moved to the kitchen. Outside London, cooking
  stayed in the hall:
  * Kent: hall in 94% of inventories 1600-29, 83% in 1660-89, 42% in 1720-49, and
    "cooking is very common in these halls".
  * Hertford: "Cooking was taking place in the hall and the kitchen".
  * Lincoln: a room called the "house" plays the hall's part, and it holds cooking gear.
* Source: Eleanor John, "At home with the London middling sort", *Regional Furniture*
  XXII (2008),
  https://regionalfurnituresociety.org/wp-content/uploads/2013/02/at-home-with-the-london-middling-sort-the-inventory-evidence-for-furnishings-and-room-use-1570-1720-eleanor-john.pdf
* check: in a rural or provincial house dated before 1700, the cooking hearth may be in
  the hall. In a London or urban merchant house after about 1600, it should be in a
  separate kitchen on the ground floor (see S-rules). A medieval manor kitchen may be a
  detached building.

### K19. The hearth kitchen work set
* Rule: a hearth kitchen has the fire on a wall (chimney, smoke hood) or in the middle.
  Round it stand the pot crane or hook, a work table, a water vessel or stone sink, and
  the store (larder, pantry or buttery) one door away.
* Number: apply K15 (all pairs within 3.05 m). The store door may be up to 6 m away, since
  in a hall house the services were across the cross passage (**ESTIMATE**).
* Sources: Hall house (Wikipedia, above); Hurstwic on the Norse pantry (matbúr) whose food
  "was brought to the main-room fire for cooking",
  https://www.hurstwic.org/history/articles/daily_living/text/longhouse.htm
* check: the cooking hearth has a work table within 2 m. The room or its neighbour holds a
  storage item (meal chest, dresser, barrel, shelf).

### K20. The Dutch and English kitchen as a display room [HISTORIC, 17th century]
* Rule: in the 17th-century Dutch house the kitchen was the most important room. Its
  walls displayed polished copper and brass, linens, china and silver. In London
  inventories brass and pewter are usually listed in the kitchen.
* Sources: Rybczynski, *Home* (1986), via a review at
  https://lorenwebster.net/category/longer-works/witold-rybczynskis-em-home-em/ ; John 2008.
* check: a 17th-century urban kitchen carries wall shelves or racks with metal ware on at
  least one wall that is not the hearth wall.

### K21. Japanese doma kitchen [HISTORIC]
* Rule: in minka, cooking on the kamado (stove) happens in the doma, the earth-floored
  entrance and work area. The irori (sunken hearth) is in the raised living floor
  (hiroma) next to it. The irori also cooks and heats, from pots on an adjustable hook
  (jizaikagi) hung from the beams.
* Numbers: the hiroma floor is about **0.50 m** above the doma. An irori averages
  **0.9 x 0.9 m** and ranges from 0.45 x 0.45 m to 2 x 1 m.
* Sources: JAANUS "irori", https://projects.mcah.columbia.edu/jaanus/node/3759 ;
  https://en.wikipedia.org/wiki/Minka
* check: the kamado lies in the doma zone (earth floor, entrance side). The irori lies in
  the raised room that adjoins the doma, at least 1 m from that room's walls on its
  seated sides (**ESTIMATE**), with a hook above it.

---

## 3. Furniture relations in the computer graphics literature

### L1. Merrell et al. 2011, "Interactive Furniture Layout Using Interior Design Guidelines" (SIGGRAPH)
Source: https://paulmerrell.org/furnitureLayout2.pdf (read in full). The layout's density
is a weighted sum of these terms. The designers' guidelines came from layout manuals
(Talbott 1999, Ward 1999, Sharp 2008) and from interviews. The anthropometric numbers
are from Panero & Repetto 1975.

| Term | Definition | Defaults | check |
|---|---|---|---|
| Clearance violation `m_cv` | Each item's footprint is grown by its clearance zone (Table 1, below). Minimise the overlap area of the grown regions with each other and with the outside of the room. | Table 1 | the summed overlap of the zones from A3-A8 is 0. |
| Circulation `m_ci` | The number of connected components of the free configuration space of a disc person (furniture and walls Minkowski-summed with the disc). | radius 18 in = **0.457** | as A1. One component. |
| Pairwise distance `m_pd` | A plateau function t(d, m, M) over each constrained pair: flat inside [m, M], decaying outside. | Table 1 | the pair distance lies in [m, M]. |
| Pairwise angle `m_pa` | Relative direction for constrained pairs: "in front of seat", "to the side of bed". | Table 1 | the partner lies in the named sector (±45 deg, **ESTIMATE**). |
| Conversation distance `m_cd` | For seats in a user-declared group, t(d, 4 ft, 8 ft). | **1.22-2.44** | as A9. |
| Conversation angle `m_ca` | -Σ (cos θfg + 1)(cos θgf + 1) over seat pairs. | - | as A9. |
| Visual balance `m_vb` | Distance from the area-weighted centroid of the footprints to the room centroid. | - | ‖Σ A(f)p(f)/Σ A(f) − c(room)‖ ≤ 0.2 × the room's short side (**ESTIMATE** threshold). |
| Furniture alignment `m_fa` | -Σ cos 4(θf − θg) within a group: items parallel or at right angles. | - | the yaw difference within a group is a multiple of 90 deg ±5 deg. |
| Wall alignment `m_wa` | -Σ cos 4(θf − θwall(f)) against the nearest wall. | - | each item is ±5 deg from parallel or perpendicular to its nearest wall. |
| Emphasis `m_ef` | Items in a group face the group's focal point (fireplace, large window, entertainment centre). | - | `faces(f, focal, 30deg)` for every seat in the focal group. |
| Symmetry `m_sy` | Matching items (seat with seat) mirror across the focal axis. | - | for each seat, a seat of the same category exists near its mirror image across the axis through `focal` (tolerance 0.3 m, **ESTIMATE**). |

Merrell Table 1 (Panero & Repetto 1975), converted:

| Constraint | Distance | Direction |
|---|---|---|
| Bedside | 0.914 | to the side |
| Seat | 0.762 | in front |
| Cabinets and shelving | 0.610 | in front |
| Dining table | 0.914 | all round |
| Coffee table to seat | 0.406-0.457 | in front of seat |
| End table to seat | 0-0.305 | to the back or side of the seat |
| Nightstand to bed | 0-0.305 | to the side of the bed |

Finding worth keeping: in their study, layouts made with these terms were preferred by
professional designers over layouts made by untrained people without them. Their Figure 3
(from Ward 1999) is the canonical before/after: seats too far apart to talk, and no
visual anchor. Afterwards: a tight group that faces the fireplace.

### L2. Yu et al. 2011, "Make It Home" (SIGGRAPH)
Source: https://ww3.math.ucla.edu/camreport/cam11-49.pdf (read). Cost =
wa·Ca + wv·Cv + wpath·Cpath + wprd·Cprd + wprθ·Cprθ + wpd·Cpd + wpθ·Cpθ.

* **Accessibility `Ca`**: each item has an "accessible space" on each usable face,
  sized from examples, or else to an average adult. Cost rises when another item enters
  it. check: as A3-A5.
* **Visibility `Cv`**: an item that must be seen (TV, painting) has a viewing frustum,
  approximated by rectangles. Cost rises when anything enters it. check: for a
  picture, mirror, hearth, tokonoma or Herrgottswinkel, a cone from the item to the
  room's seating holds no item taller than 1.0 m (**ESTIMATE**).
* **Pathway connecting doors `Cpath`**: a smooth path between each pair of doors, a cubic
  Bezier made of rectangles of body width, kept free. Paths should be short and must not
  be "circuitous and narrow". check: for each door pair in a room, the clear path is at
  most 1.3 × the straight door-to-door distance (**ESTIMATE**).
* **Prior distance and orientation to the nearest wall `Cprd`, `Cprθ`**: learned per item
  type from examples (clustered means). A bed's back is on a wall. A wardrobe's back is
  on a wall. check: for each category keep a target `wall_gap` (wall types ≤ 0.05 m) and a
  target relative yaw (back to wall). Their Figure 8h/8i failure is "too far from the
  wall" and "randomly oriented".
* **Pairwise distance and orientation `Cpd`, `Cpθ`**: TV and sofa, desk and work chair,
  chair and table, couch and tea table. check: as L1 pairwise.
* **Hierarchy**: first-tier items stand on the floor or the wall. Second-tier items stand
  on a first-tier item's surface (a vase on a cupboard, a candelabrum on a table).
* Their ablation figure lists the believability failures one by one:
  * (c) collisions;
  * (d) a plant blocking the TV and the armchair;
  * (e) the work chair too far from the desk;
  * (f) the armchair facing away from the TV;
  * (g) the desk and work chair blocking the door;
  * (h) items too far from the wall;
  * (i) random orientation.

  Each is a check. See section 6.

### L3. Fisher et al. 2012, "Example-based Synthesis of 3D Object Arrangements" (SIGGRAPH Asia)
Source: https://graphics.stanford.edu/projects/scenesynth/ ;
https://www.cs.princeton.edu/~funk/sigasia12.pdf (abstract and overview only).
* There are two models. The **occurrence model** (a Bayesian network) decides WHICH
  objects appear and how many. The **arrangement model** (a mixture of Gaussians over
  relative positions) decides WHERE they go relative to the items that support them and
  their neighbours. Objects are clustered by local neighbourhood, so that similar items
  can be swapped.
* The lesson for BrickWild: decide the room's inventory (occurrence) separately from
  placement, and condition it on room kind and period. Probate inventories (section 5)
  are exactly an occurrence model for 1570-1720.
* check: every room's item multiset has non-zero likelihood under the per-kind table
  (see L4 room weights, H-inventory tables).

### L4. ProcTHOR (Deitke et al., NeurIPS 2022)
Source: https://ar5iv.labs.arxiv.org/html/2206.06994 (Appendix B).
* **Room weight** per object type per room type, 0-3: 0 never (a fridge in a bathroom),
  1 unlikely, 2 often, 3 nearly always (a bed in a bedroom).
* **Position annotation** per type: edge, corner, middle. A **multiple-instances flag**
  (two toilets may not share a room).
* Placement: the free floor is cut into rectangles. With probability **0.8** the next item
  goes in the largest rectangle, otherwise in one chosen by area. Each placed footprint,
  plus a margin, is removed from the free floor.
* **Semantic Asset Groups** (18 of them): chairs round a dining table, pillows on a bed, a
  desk with a chair. A child is anchored to its parent at Top/Centre/Bottom by
  Left/Centre/Right, with an offset. Groups are rejection-sampled if they clip.
* Order: floor items, then wall items (windows, paintings), then surface items.
* Room graph: open-plan and door-frame connections only between kitchen and living room
  (probability 0.375 each, a doorway 0.25). The exterior door goes in the kitchen or the
  living room when possible. A bathroom may not have two doors.
* check: hold a per-(period, room kind) weight table. Reject an item with weight 0. Warn
  when a room lacks every weight-3 item. Every item has an allowed position class, and a
  "middle" item must not have `wall_gap < 0.3`.

### L5. Holodeck (Yang et al., CVPR 2024)
Source: https://arxiv.org/html/2312.09067v2 . The constraint vocabulary, in full:
* **Global**: `edge` (at the room's edge, close to a wall; "most objects") or `middle`.
  One is required per object.
* **Distance**: `near(obj)` = **0.5 < d < 1.5 m**; `far(obj)` = **d >= 1.5 m**.
* **Position**: `in front of(obj)`, `side of(obj)` (left or right), `above(obj)` (wall
  items over a floor item), `on top of(obj)`.
* **Alignment**: `center aligned(obj)` (shares the x or the z centre).
* **Rotation**: `face to(obj)` (faces the other's centre). Yaw is restricted to
  0/90/180/270 deg.
* **Hard** constraints: no collision, inside the room. Everything else is soft. The DFS
  solver keeps the layout that satisfies the most soft constraints. An **anchor object**
  is placed first (e.g. a sofa at the edge), and the rest relative to it.
* Rooms: sides 3-8 m, area at most 48 m², at least 9 m². Doors: 1 m single, 2 m double.
* check: express every placement rule in BrickWild as one of these relations, and log
  which ones held. That gives a per-room satisfaction ratio that you can trend.

### L6. A merged relation vocabulary for BrickWild [UNIVERSAL]
Combining L1-L5 with the clearances. All distances are in metres. Each relation gives a
`check:` predicate directly.

| Relation | Meaning | Default band |
|---|---|---|
| `against_wall(f)` | back face to a wall, `wall_gap <= 0.05`, yaw parallel | gap 0-0.05 |
| `in_corner(f)` | two faces within 0.05 of two walls meeting at a corner | - |
| `middle(f)` | `wall_gap >= 0.6` on all sides | ≥ 0.6 (ESTIMATE) |
| `in_front_of(a, b, d)` | a lies in `front_zone(b, d)` | per pair (A7: 0.41-0.46) |
| `beside(a, b)` | a lies in `side_zone(b, ·, 0.30)` | 0-0.30 (A8) |
| `around(table, chairs)` | chairs on the table's edges, facing its centre, 0.61 per place, seats 0-0.15 from the edge | KPG 9 |
| `faces(a, b)` | a's forward vector within 30 deg of b's centre | ESTIMATE tol |
| `near(a, b)` | 0.5-1.5 | Holodeck |
| `far(a, b)` | ≥ 1.5 | Holodeck |
| `center_aligned(a, b)` | shared axis ±0.05 | Holodeck |
| `flank(a, a', axis)` | mirror pair across a focal axis | Merrell symmetry |
| `under(a, window)` | a against the window wall, inside the window's width span | - |
| `clear(zone)` | no footprint in the zone | A3-A12 |
| `on(a, b)` | a's footprint inside b's top, second tier | Yu hierarchy |

---

## 4. Room zoning and the order of rooms

Primary source: Christopher Alexander et al., *A Pattern Language* (1977). Pattern texts
were read from https://urbigenous.net/a-pattern-language/pattern-NNN.html (the URL takes the
pattern number). Each entry gives the pattern's own "therefore" and its checkable core.
Alexander is prescriptive (about what makes rooms good), not descriptive (about what
people built). Most of it nonetheless matches the vernacular evidence in section 5.

### Z1. Intimacy Gradient (#127) [UNIVERSAL]
* Rule: lay out the spaces as a sequence. It begins at the entrance and the most public
  parts, leads to slightly more private areas, and ends at the most private domains.
* check: give each room kind a privacy rank (shop/zaure/porch/entrance = 0;
  hall/kitchen/common = 1; parlour/dining = 2; chamber/bedroom/solar/nando = 3;
  closet/strongroom = 4). For each room, `depth(room)` must not decrease as rank rises.
  More strictly: on every path from the entrance, rank is non-decreasing except for
  service rooms, which hang off rank 1. Fail if a rank-3 room is the only route to a
  rank-1 or rank-2 room.

### Z2. Common Areas at the Heart (#129) [UNIVERSAL]
* Rule: one common area for each social group. Put it at the centre of gravity of the
  group's spaces, so that the paths in and out of the building lie tangent to it.
* check: the common room (hall, house-place, kitchen-living, hiroma, longhouse central
  room) contains or is the room nearest to the area-weighted centroid of the dwelling's
  rooms on its storey. The entrance-to-stair path passes through or along it (and does
  not route round it).

### Z3. Entrance Room (#130) and Entrance Transition (#112) [UNIVERSAL]
* Rule: at the main entrance, make a light-filled room that straddles indoors and out,
  porch outside and hall or sitting room inside. Between the street and the door, a
  transition with a change of surface, level or enclosure, and of view.
* Historic forms of it: the cross passage of the hall house; the minka doma; the Hausa
  zaure; the longhouse antechamber with its "airlock" double doors (Hurstwic).
* check: the main door opens into a room of rank 0, or into a passage that is part of a
  rank-1 room. It never opens straight into a rank-3 room. A threshold zone (door.width ×
  1.2 m, **ESTIMATE**) inside the door is free.

### Z4. The Flow Through Rooms (#131), Short Passages (#132) [UNIVERSAL]
* Rule: avoid corridors. Use the common rooms for movement, chained or looped, and let the
  private rooms open off them. Keep any passages short and room-like.
* check: corridor area ≤ 10% of the storey's floor (**ESTIMATE**). Each bedroom's door
  opens from a common room, a landing or a short passage. No bedroom lies on the only
  path between two other rooms.

### Z5. Staircase as a Stage (#133) [MODERN-leaning]
* Rule: put the main stair in a central, visible position, and treat it as part of a room.
* Historic counterpoint: in the hall house the solar was reached "by a ladder or steep
  companionway" (Wikipedia, Hall house). Do NOT apply a grand stair before about 1600 in
  vernacular buildings.
* check: in a modern or urban house after 1650, the stair foot lies in or next to a
  common room or entrance hall. A pre-1600 cottage may use a ladder or a stair in the
  corner beside the stack.

### Z6. Couple's Realm (#136), A Room of One's Own (#141) [MODERN]
* Rule: the couple's room is distinct from the common areas and the children's rooms,
  with a quick path to the children. Private rooms lie at the far end of the intimacy
  gradient. The minimum is an alcove with a desk, shelves and a curtain.
* check: the main bedroom has the highest `depth()` on its storey, or is on an upper
  storey. Its route to a child's room has at most 2 door-steps.

### Z7. Sleeping to the East (#138), Indoor Sunlight (#128) [UNIVERSAL]
* Rule: the common area takes the full south light; bedrooms face south-east; the porch
  faces south-west. Sleep on the east side, or on the west if there is a courtyard to the
  east.
* check: the common room has a window whose normal is within 45 deg of S. Bedrooms have
  windows within 60 deg of E (northern hemisphere; flip it south of the equator). This is
  soft. In a terrace house it is overridden by the street side.

### Z8. Light on Two Sides of Every Room (#159) [UNIVERSAL]
* Rule: each room should have outdoor space on at least two sides, with windows on both.
  People "gravitate to" two-side-lit rooms and leave one-side-lit rooms "unused and
  empty".
* check: count the distinct exterior wall normals that carry windows, per room. The
  common room needs at least 2. Flag any room of rank 1 or 2 with fewer than 1.

### Z9. Sequence of Sitting Spaces (#142), Sitting Circle (#185) [UNIVERSAL]
* Rule: graded sitting places, from formal and fully enclosed to corners of other rooms.
  Each sitting place is protected, "not cut by paths or movement", and roughly circular,
  with "a few too many" seats.
* check: no door-to-door path (L2 `Cpath`) crosses the convex hull of a conversation
  group (A9). Group seat count ≥ the household's adult count, plus 1 (**ESTIMATE** for
  "a few too many").

### Z10. The Fire (#181) [UNIVERSAL; HISTORIC core]
* Rule: build the fire in a common space, perhaps the kitchen. Place it so that the
  social spaces round it each get a glimpse of it. Give the room a window or other focus
  for when the fire is out.
* check: the main hearth is in a rank-1 room. Every seat in that room `faces` the hearth
  or the room's table. A line of sight from the hearth reaches the door of each adjoining
  common room, when open-plan (soft).

### Z11. Window Place (#180) [UNIVERSAL]
* Rule: in every room where you spend time by day, make at least one window into a
  "window place": a seat, a bay, a low sill with a chair drawn up.
* check: each room of rank 1-3 with windows has a seat, a table or a work item (loom,
  bench, desk) within 1.0 m of a window, `faces` along or across the window
  (**ESTIMATE** for 1.0 m). In a Norse longhouse with no windows this rule moves to the
  door and the smoke hole (H-rules).

### Z12. Eating Atmosphere (#182), Communal Eating (#147) [UNIVERSAL]
* Rule: a heavy table in the centre of the eating space, big enough for the household,
  with a pool of light over it. The space is big enough for chairs to pull back. Shelves
  and counters stand close at hand.
* check: the eating table's seat count ≥ the household size. A6 clearances hold. A
  storage item (court cupboard, dresser, sideboard, shelf) is within 2.5 m of it
  (**ESTIMATE**).

### Z13. Workspace Enclosure (#183) [UNIVERSAL]
* Rule: each workspace is at least 60 ft², enclosed on 50-75% of its perimeter (windows
  count half), open for 8 ft in front into a larger space, with a view out to the front
  or side.
* Numbers: area **≥ 5.57 m²**; open front **2.44 m**.
* check: for a desk, workbench or loom, the user's position has 2.44 m free in front or
  to the side towards the room, and its back or side is near a wall.

### Z14. Alcoves (#179), Bed Alcove (#188), Bed Cluster (#143), Communal Sleeping (#186), Marriage Bed (#187) [HISTORIC and UNIVERSAL]
* Rule: small places at the edge of a common room, **≤ 1.83 m** (6 ft) wide and
  **0.91-1.83 m** (3-6 ft) deep, big enough for a desk or a table. A bed in an alcove off a
  room with other uses is better than a lone bed in an empty "bedroom". For a very small
  house (300-400 ft² = **27.9-37.2 m²**) put the alcoves off the family room. Children's
  beds go in curtained alcoves round a shared space. The marriage bed is slightly
  enclosed, with a low ceiling or a canopy.
* Historic match: the Norse master's box bed in an enclosed closet (Hurstwic); curtained
  and testered beds in English chambers (John 2008); the minka nando.
* check: in a cottage under 40 m² of floor, a bed may stand in an alcove or a curtained
  corner of the main room. That is not a failure. A bed alcove is ≤ 2.2 m wide and
  ≥ bed length + 0.1 m deep, with its open side facing the room (**ESTIMATE**).

### Z15. Dressing Room (#189) [MODERN]
* Rule: a dressing area between bed and bath, with **1.83 m** (6 ft) diameter of open
  floor, about **1.83 m** of hanging, 1.83 m of open shelves, 2-3 drawers and a mirror.
* check: only for wealthy modern houses. The wardrobe zone has a 1.83 m clear disc.

### Z16. Ceiling Height Variety (#190) [UNIVERSAL]
* Rule: high ceilings in public rooms, **3.05-3.66 m** (10-12 ft); lower in rooms for
  small gatherings, **2.13-2.74 m** (7-9 ft); very low in alcoves for one or two,
  **1.83-2.13 m** (6-7 ft).
* Historic match: the open hall rose to the roof (e.g. Plas Uchaf about 7.6 m to the
  ridge), while chambers and solars had low ceilings (Hall house, Wikipedia).
* check: the ceiling height of the common room ≥ that of every bedroom on its storey. An
  open hall may be open to the roof.

### Z17. Corner Doors (#196) [UNIVERSAL]
* Rule: except in very large rooms and entrance rooms, put doors near the corners. If a
  room has two doors that people pass between, keep both at one end of the room.
* A companion rule from the CUNY space-planning sheet: "Ideally there should be no
  through-traffic. If such traffic is necessary, it should be at one end, with the
  remaining portion of the room a dead-end space."
  https://openlab.citytech.cuny.edu/arch3512f2024/files/2024/01/Human-Dimensions-and-Space-Planning.pdf
* check: for rooms under 20 m² (**ESTIMATE**), each door's near jamb is within 0.9 m of a
  room corner (**ESTIMATE**). For a two-door through room, both doors lie in the same
  third of the long axis, or the through-path leaves at least 50% of the floor as a
  dead-end zone (**ESTIMATE**).

### Z18. Thick Walls (#197), Closets Between Rooms (#198), Open Shelves (#200), Waist-High Shelf (#201) [UNIVERSAL]
* Rule: closets go on interior walls between rooms and passages, never on exterior walls,
  because those carry the light. Shelves are shallow, one object deep. A waist-high shelf,
  **0.23-0.38 m** (9-15 in) deep, runs round part of the main rooms and is interrupted for
  seats, windows and doors.
* check: no wardrobe, press or closet backs onto an exterior wall within 1 m of a window
  (**ESTIMATE**). Tall storage (> 1.5 m) never covers any part of a window's width.

### Z19. Built-In Seats (#202), Different Chairs (#251), Pools of Light (#252), Child Caves (#203) [UNIVERSAL]
* Rules: put a built-in seat where you would put a good armchair: at a window or by the
  fire, with a view. Never furnish a place with identical chairs. Light low and in pools,
  over tables and chairs, with darker places between. Children's caves are **0.76-1.22 m**
  high, under stairs or counters.
* check: in a rank-1 room with 3+ seats, at least 2 distinct seat keys (benches, stools,
  a great chair). A historic hall with only forms and a "great chair" for the master
  passes, and is in fact typical (John 2008). Each light source sits over or beside a
  table or seat group.

### Z20. Bulk Storage (#145), Home Workshop (#157) [UNIVERSAL]
* Rule: bulk storage is at least **15-20%** of the building's area, in cheap
  places (loft, garret, outbuilding). A home workshop of "a few hundred square feet" can
  be seen from the street.
* check: storage-kind rooms (buttery, pantry, garret, loft, store, byre loft, granary)
  plus storage items make up at least 15% of the gross floor area of a farmhouse or shop
  house (**ESTIMATE** to apply it per-house). A workshop on a shop house faces the street.

---

## 5. Historic room use: what goes where, and why

### 5a. The English medieval and early-modern hall house (about 1300-1600) [HISTORIC]
Sources: https://en.wikipedia.org/wiki/Hall_house ; https://en.wikipedia.org/wiki/Great_hall ;
Margaret Wood, *The English Mediaeval House* (1965), cited via those articles.

### H1. Bay order: services | passage | hall | upper end
* Rule: the simplest plan has four bays. The open hall takes the **two middle bays**. The
  **lower** (service) bay holds the pantry (food) and buttery (drink), both unheated. The
  **upper** bay holds the parlour on the ground floor and the solar above, reached by a
  ladder or a steep companionway. Opposed external doors make a **cross passage** at the
  lower end of the hall, later screened off as the screens passage. A centre door from
  the passage leads to the kitchen, with the pantry and buttery doors either side. By
  about 1300 this plan "had become commonplace".
* Number: Rufford Old Hall's hall is **14.2 x 6.7 m** in 5 bays (c.1530), about 2.8 m a
  bay. In general a bay is one structural frame interval (**ESTIMATE**: 3.5-5 m for
  timber halls).
* check: along the long axis, the room order must be [service rooms] - cross passage -
  hall - [parlour/chamber]. The two external doors face each other across the hall's
  lower end. The service rooms' doors open off the passage, never off the upper end.

### H2. The open hearth sits in the hall, lower of centre
* Rule: an open hearth "in the middle of the hall" sends smoke to a roof vent (louvre).
  Wikipedia notes that it was deliberately set toward the lower end, where the draught
  between the two doors could control it. When a wall fireplace was added it was
  "generally at the dais end of the hall with the bay window".
* check: an open hearth in a hall lies on the long axis, within the central 50% of the
  hall's length, offset toward the passage end (soft). Its 0.5 m keep-out (A10) is
  clear. No floor or ceiling lies over it unless a chimney or smoke hood is present.

### H3. The upper end: dais, high table, bay window
* Rule: the upper end has a low platform (the dais) with the high table across the hall's
  width, facing down the hall toward the screens. The lord's private rooms lie beyond the
  dais. Later halls added a canopy and a bay window at the dais end.
* check: the hall's largest table lies within 2 m of the upper end wall (**ESTIMATE**),
  with its long axis across the hall. Its seats are on the wall side, facing the passage
  end. The door to the parlour or chamber is in the upper end wall, never the lower.

### H4. Hall seating: forms and benches along the walls, the table as the centre
* Rule: medieval furniture was sparse. People sat on benches to eat. Trestle tables were
  set up and taken down. The 18th-century step of "arranging chairs and sofas in the room
  instead of along its walls" is "a landmark moment in the evolution of domestic
  comfort". Before that, seats rested along the walls.
* London, c.1690, a painted parlour: "cane chairs are set to the sides of the room. The
  table and chairs would have been brought out into the room as required."
* Sources: Rybczynski, *Home: A Short History of an Idea* (1986), via reviews
  https://americanheritage.com/home-short-history-idea and
  https://www.kirkusreviews.com/book-reviews/witold-rybczynski-6/home-a-short-history-of-an-idea/print/ ;
  John 2008, figs. 10-11 caption.
* check: **in a room dated before about 1720, idle seats (forms, stools, chairs not at a
  laid table) stand `against_wall`.** A loose conversation group in mid-floor is an
  anachronism. This is the reverse of the modern M2 rule, so branch on the period.

### H5. Later: chimney stack and floored hall
* Rule: the open hearth was abandoned in the early modern period. A chimney was built
  "near the cross passage", sometimes blocking it, which produced the lobby entrance
  against the stack. Once the open hearth went, the hall was floored over to make a
  chamber above. Smoke bays came first, and smoke hoods (early 16th century in Surrey, late
  17th in the North). Hall houses built after 1570 are rare.
* check: in a 1570-1700 vernacular house, the main fireplace backs onto the entry
  (lobby) or the passage, and the hall below has a chamber above it.

### 5b. What the probate inventories put in each room (1570-1720) [HISTORIC]
Source for all: John 2008 (London, 85 inventories, with a comparison to Bristol,
Marlborough, Hertford, Lincoln, Norwich and Kent). Also Pirton,
https://pirtonhistory.org.uk/inventories , and the Suffolk Records Society transcriptions,
https://www.suffolkrecordssociety.com/images/PDF_Files/Probate-Inventories-from-St.-Andrew-Ilketshall.pdf

| Room | Typical contents | Evidence |
|---|---|---|
| Hall (London 1570-1665) | draw-leaf table with joined stools (13 of 20 halls), a court cupboard, a few chairs and sometimes a "great chair". The fireplace is "well-furnished" with andirons, tongs and a fire shovel. Curtains in half the halls. Pictures (10/20), books, playing tables, virginals. **No beds** in London halls. | Table 2 |
| Hall (provinces) | the same, plus **cooking**: very common in Kent halls, also in Hertford, Marlborough and Lincoln ("house"). | John p. 47-48 |
| Parlour (London) | furnished like the hall but "a little smarter": a draw-leaf table, joined stools, a court cupboard, curtains (over two-thirds), pictures. No beds in 1570-1665. After 1665: tables and a suite of chairs (18 of 23), a mirror (12/23), a clock (6/23), beds in 3/23. | Table 2 |
| Parlour (provinces) | often **the best bedroom**. Beds in 72% of Lincoln parlours (1661-1714); in 54% of Norwich parlours (1580-1604), falling to 18% (1705-30). At Pirton the parlour stayed the best bedroom until the early 18th century. | John p. 48; Pirton |
| Chamber | beds, "often more than one in each room": the main bed and a truckle/trundle bed that slides under it, with chests, and perhaps one or two chairs. The great chamber adds a large table and upholstered seats (it is a second dining space). | John p. 34-35 |
| Dining room (London after 1659) | an oval gate-leg table (often more than one), a suite of 8-14 turkey-work or cane chairs, a looking glass (21 of 36 rooms), a clock (11/36), pictures (17/36). The table and glass stand on the window pier, flanked by stands. | Table 2, p. 40-44 |
| Kitchen | cooking gear, plus brass and pewter stored and shown, even candlesticks. | John p. 26 |
| Buttery / pantry | casks of drink / bread and food, unheated. Servants could sleep above the pantry and buttery, or in the hall. A bed is sometimes found in a buttery. | Great hall (Wikipedia); Pirton |
| Garret | at the top of the house. Storage, and servants' sleeping. | John p. 29 |
| Shop / warehouse / counting house | in "most houses" of the London sample. | John p. 29 |

### H6. Room inventory by period and place
* Rule: draw each room's inventory from the table above for the house's period and region.
  A 1600 London hall gets table, stools, court cupboard and fire irons, and no bed. A 1600
  Lincolnshire parlour has a 72% chance of a bed.
* check: an occurrence test (L3/L4). Each required item for (room kind, period, region)
  is present; each item has a non-zero weight there.

### H7. Pier furniture and symmetry (late 17th century) [HISTORIC]
* Rule: in the new dining room or parlour, a table stands against the window pier (the
  wall between two windows) with a looking glass above it and a stand on either side.
  This is "an arrangement" seen repeatedly.
* check: when a room has two windows on one wall and a pier ≥ 0.8 m between them, a
  table centred on that pier (`center_aligned`) with a mirror above passes. Flanking items
  are `flank` pairs.

### H8. Multi-use rooms, before specialisation [HISTORIC]
* Rule: households of "sometimes up to 25" people, with work and business in the house.
  Medieval people "didn't so much live in their houses as camp in them". Specialised rooms
  (nursery, study, dining room) "are fairly rare" before 1665.
* Sources: Rybczynski via Kirkus and the lorenwebster review; John 2008 p. 35.
* check: in a pre-1650 house, the hall may legitimately hold eating, sitting, work and
  (in the provinces) cooking items at once. Do not fail it for "mixed function". Do fail
  a pre-1650 vernacular house that has a "study", "nursery" or "dining room" unless it is
  of high status.

### 5c. Norse longhouse (Viking age to the medieval period) [HISTORIC]
Sources: Hurstwic, https://www.hurstwic.org/history/articles/daily_living/text/longhouse.htm ;
Milek et al. 2014, "Interpreting social space and social status in the Viking Age house at
Hrísbrú", https://scandinavian.washington.edu/sites/scandinavian/files/documents/research/milek_et_al_2014_social_space_hrisbru.pdf

### H9. Three aisles: hearth in the middle, platforms at the sides
* Rule: two rows of roof posts split the house into three aisles. The central aisle has an
  earth floor (covered with ash) with the hearth: a long fire pit, or separate fire
  circles. Raised wooden platforms ("benches") fill both side aisles, between the posts
  and the walls, for sitting, eating, working and sleeping. Storage lay under the benches
  (Stöng).
* Numbers: width **5-7 m**; length **15-75 m**. The walls bow out, so the house is wider
  in the middle.
* check: in the main room, the hearth is centred on the long axis. Two bench strips run
  along both long walls, and each is 1.0-1.8 m deep (**ESTIMATE**: no source gave bench
  widths). The central aisle stays clear except for the hearth. No free-standing bed
  stands in the central aisle.

### H10. Sleeping and the box bed
* Rule: only the master and mistress had a box bed in an enclosed bed closet. Everyone
  else slept on the benches, on hay or grass bedding (attested at Hrísbrú by
  micromorphology).
* check: exactly one enclosed bed (or none) in a longhouse. The household's other sleeping
  places are bench segments.

### H11. Tables are temporary, chests are seats
* Rule: trestle tables were probably stored on the cross beams and brought down for meals.
  Wooden chests served as storage and as seats. There were three-legged stools and a
  vertical loom.
* check: a longhouse main room needs no fixed dining table. If one is placed, it is a
  trestle table parallel to a bench, `in_front_of` that bench at 0.3-0.6 m (**ESTIMATE**).
  Chests stand against the bench front or a wall.

### H12. Ends: entrance antechamber (food), gable rooms (byre, work)
* Rule (Hrísbrú): an entrance passage separated the central hall from the gable rooms.
  Just inside the main entrance was a small antechamber used for food storage and
  preparation: a barrel pit, and bone chopped in place, "a búr, or pantry". The western
  gable room held a loom opposite the entrance near a pit (looms need light, and the door
  gave it). The eastern gable room had level floors, no hearth and hay floors. It was most
  likely an **animal byre**, also used for ironworking when animals were out. The central
  hall was "the only area with clear sitting and sleeping areas", and so the public room.
* Hurstwic adds: one end housed cattle, stored crops and tools; the other end was often
  for crafts. There was a pantry (matbúr), an outside store (útibúr), and antechambers
  with double doors as an airlock.
* check: the longhouse room order is [byre or work end] - [entrance + pantry] - [central
  hall with hearth and benches] - [work/loom end]. The loom stands within 2 m of a door,
  facing it (**ESTIMATE**). The byre has no hearth.

### H13. Light comes from the door and the smoke hole
* Rule: windows were typically absent. Light came from smoke holes and open doors. Lamps
  burned fish or seal oil.
* check: Z8 and Z11 do not apply. Instead, work items (loom, workbench) lie near doors or
  under a smoke hole.

### 5d. Japanese minka [HISTORIC]
Sources: JAANUS, https://projects.mcah.columbia.edu/jaanus/node/3759 ;
https://en.wikipedia.org/wiki/Minka

### H14. Doma, then the raised hiroma with the irori, then tatami rooms
* Rule: the **doma** is an earth-floored entrance and work area (the precursor of the
  genkan), where the lowest-ranked people sat. The **hiroma** (raised about 0.5 m) holds
  the built-in irori and is "the focus of daily life", where meals were eaten and informal
  visitors entertained. Big farmhouses add a **hiroshiki**, a raised timber floor up to
  **2.5 m** wide between the doma and the tatami rooms, where servants apparently slept.
  The **zashiki** (tatami) is the formal room, and honoured guests sit with their backs to
  the tokonoma. The *yomadori* is a four-room plan in the raised part, beside the doma.
  The **engawa** is a timber veranda under the eaves, closed by storm shutters. Sliding
  fusuma and shoji change the room sizes. Upper floors served sericulture and storage in
  gasshō houses.
* check: the order from the entrance is doma (rank 0) → hiroma (rank 1) → zashiki/nando
  (rank 2-3). The zashiki is the farthest raised room from the doma. Its tokonoma is on
  the wall facing the engawa's opposite side (**ESTIMATE**), and the guest seat has its
  back to the tokonoma.

### H15. Irori seat ranks
* Rule (JAANUS):
  * **yokoza**, the master's seat, is at the upper end (kamite), facing and overlooking
    the doma;
  * **kijiri**, opposite him, is the lowest rank (junior members, servants, or fuel
    storage);
  * **kakaza/nyōbōza**, the wife's seat, is toward the back, near the kitchen;
  * **kyakuza**, opposite her near the entry, is for visitors or the eldest son.

  The irori averages 0.9 x 0.9 m, with a **jizaikagi** pot hook hung from the beams.
  Tōhoku houses often had two irori.
* check: the four sides of the irori have seat cushions or mats. The side away from the
  doma (yokoza) faces the doma. The kijiri side, nearest the doma, may hold firewood
  instead of a seat. Nothing taller than 0.5 m within 1 m of the irori edge
  (**ESTIMATE**: floor sitting).

### 5e. Iron Age roundhouse [HISTORIC]
Sources: ScARF Iron Age panel, "5.4 How were roundhouses used?",
https://scarf.scot/national/iron-age-panel-report/5-building-in-the-round-house-scapes-of-the-iron-age/5-4how-were-roundhouses-used/ ;
Danebury guide (Wessex overview), https://gallica.co.uk/papers/danebury%20guide.pdf ;
Davis on Danebury, https://orca.cardiff.ac.uk/id/eprint/61524/

### H16. Central hearth, work at the front, sleep at the back
* Rule: a central hearth gives even heat and light and limits fire risk. It sleeps an
  extended family of **12-20**, with organic beds at the house rear. Food preparation and
  craft happen at the front, by the door, in the day, and round the hearth at night. All
  the light came from the wide doorway, which often faces away from the prevailing wind.
  The east/south-east "cosmological" doorway and sunwise use are commonly proposed but
  **contested**. At least one wetland roundhouse faces south. Low sleeping or storage
  areas run round the wall.
* check: the hearth lies within 15% of the radius of the centre (**ESTIMATE**). Beds and
  bedding lie in the rear half, away from the door, against the wall ring. Work items
  (quern, loom, workbench) lie in the front third, near the door. The door's normal
  points within 90 deg of E/SE by default, as a soft rule (contested).

### 5f. Ancestral Pueblo [HISTORIC]
Sources: Turkey Creek Pueblo household study, https://ltrr.arizona.edu/node/700 ;
Potter 2010 (Colorado archaeology),
https://archaeologycolorado.org/sites/default/files/Potter%2C%20James%20M.%20%282010%29%20The%20House%20and%20Household..pdf ;
Crow Canyon site testing, https://crowcanyon.org/ResearchReports/SiteTesting/Text/Ts_14

### H17. Room suite: one living room, activity rooms, storage rooms
* Rule: three room types. **Habitation** rooms are large, with a rectangular, often
  slab-lined hearth. **Miscellaneous activity** rooms are mid-sized, with a circular hearth.
  **Storage** rooms are small, have no hearth and usually no interior features, and are
  entered by a small raised door. A typical household is 1 habitation room, 1-2 activity
  rooms and 2-3 storage rooms. **Mealing rooms** hold several fixed grinding bins (mano and
  metate) and "little or no space" for anything else. Rooms changed use (bins filled in,
  hearths installed).
* check: each household suite has exactly one room with a rectangular hearth. Storage
  rooms have no hearth and no furniture except jars and bins. A mealing room's bins line
  one wall, side by side. The "storage at the back, living toward the plaza" pattern is
  widely reported but was **not verified** in this pass.

### 5g. Sahel / Hausa compound [HISTORIC]
Sources: https://en.wikipedia.org/wiki/Hausa_architecture ;
https://www.ajlajournal.org/articles/harnessing-indigenous-spatial-practices-for-contemporary-landscape-design-in-katsina-state-nigeria ;
Moughtin, *Hausa Architecture* (1985), cited there.

### H18. Zaure → outer court → inner zaure → inner court (women's quarters)
* Rule: the **zaure** is the entrance hall on the street. The master receives friends and
  guests there, and "a stranger never goes beyond it". Behind it is the outer courtyard
  (kofar gida), then a smaller inner zaure for the head's male socialising, then the
  inner courtyard (cikin gida), the women's quarters, which "takes up most of the
  compound". Each wife has her own single-storey unit in its own walled enclosure. Boys'
  quarters and storage rooms are in the back range. The head's room may open onto both
  courts so that he oversees both.
* check: the compound's graph from the street is zaure → outer court → (head's
  room | inner zaure) → inner court → wives' units. No wife's unit connects to the outer
  court. The inner court is the largest open area. Granaries and stores sit in the back
  range (Wikipedia does not detail granaries; Moughtin would).

### 5h. Alpine farmhouse Stube [HISTORIC]
Sources: German Wikipedia, "Herrgottswinkel", https://de.wikipedia.org/wiki/Herrgottswinkel ;
museum-digital Sachsen records of Bauernstube drawings and a Kachelofen "mit umlaufender
Ofenbank", https://sachsen.museum-digital.de/pdf/object/33901.pdf?lang=en

### H19. Stove in one corner, God's corner diagonally opposite, the table under it
* Rule: the Herrgottswinkel "is often in a room corner opposite the stove". It is placed
  "where it can be seen when entering the room and from the table". "The family sits on
  the bench under the Herrgottswinkel" for household devotions. A Stube's inventory: an
  **Eckbank** (corner bench), a table, a plank chair (Brettstuhl), a buffet, and a **stove
  with an Ofenbank** (a bench built round the stove).
* check: in an alpine farmhouse living room, the stove footprint is in one corner. A corner
  bench occupies the two walls of the corner diagonally opposite it, and the dining table
  stands `in_front_of` that bench, in the same corner. That corner's walls carry windows
  (soft: the corner faces the light). A bench rings at least one side of the stove.
  Stoking the stove from the kitchen behind it is common in the literature, but was
  **not verified** here.

### 5i. Shop houses (medieval to 17th century) [HISTORIC]
Sources: Weald & Downland Living Museum, Horsham shop, https://www.wealddown.co.uk/?p=16828 ;
"Living over the shop in the City of London" (Architectural History),
https://www.cambridge.org/core/journals/architectural-history/article/abs/living-over-the-shop-in-the-city-of-london/E30CA02108757DB5BE1FCF0F913611BE ;
LAMAS vol. 40, "Shop and office in medieval and Tudor London",
https://archaeologydataservice.ac.uk/catalogue/adsdata/arch-4072-1/dissemination/pdf/LAMAS_Vol40_189-206_ShopAndOfficeInMedievalAndTudorLondon.pdf ;
John 2008.

### H20. Shop at the street, kitchen behind it, living rooms above
* Rule: the shop is on the ground floor, with rooms above. The London inventories put "the
  shop and kitchen ... on the ground floor with the hall, parlour and chambers on the
  floors above terminating with the garrets at the top". A 1410 contract for three Friday
  Street houses: a ground-floor shop with a sale room and office; a first floor with a
  hall, larder and kitchen. "Shop" could mean a workshop or a retail room. At Horsham goods
  were sold over a counter through a wide, **unglazed** opening onto the street, closed by
  a heavy shutter at night. London Bridge shops were sometimes about **10 ft (3.05 m)**
  wide.
* check: storey 0 has the shop room on the street face, with a counter or stall board
  `under` the widest street opening, inside it, parallel to it. The kitchen or workshop is
  behind the shop on storey 0. Or, per the 1410 pattern, the kitchen is on storey 1 with
  the hall. Chambers are on storey 1 or above, the garret on top. The shop's street door is
  not the only way to the stair if a side passage exists (soft).

### H21. The workshop and the shop are a work zone, not a sitting room
* Rule: a shop has a counter at the opening, storage (shelves, chests, barrels) on the
  walls, and a work bench in the light. It has no beds (in London; apprentices might sleep
  in the shop in practice, which is **unverified** here).
* check: the shop's items come from {counter, shelves, chests, workbench, stool, scales,
  goods}. Every workbench is within 1.5 m of the street opening or a window
  (**ESTIMATE**).

---

## 6. Common layout mistakes designers call out

Each is a failure test. Where the source is a trade article, it is cited as such.

### M1. Furniture blocks a door, or a desk and chair block the door [UNIVERSAL]
* Source: Yu 2011 fig. 8g ("the desk and work-chair are blocking the door"); NKBA KPG 2.
* check: A11 (swing) plus a threshold zone plus a door-to-door path (L2).

### M2. Everything pushed to the walls in a big room (modern) [MODERN]
* Rule: "One of the biggest layout mistakes we see is all the living room furniture
  shoved against the walls." Pull the sofa a few inches off the wall and anchor the group
  with a rug.
* Sources: Apartment Therapy,
  https://www.apartmenttherapy.com/living-room-furniture-layout-mistake-37690680 ;
  Rugs.com, "The floating furniture problem",
  https://rugs.com/blog/the-floating-furniture-problem-how-rugs-fix-bad-room-layouts/
* check: for MODERN rooms only, wider than 4.5 m (**ESTIMATE**), at least one seating
  group has its centroid ≥ 1.2 m from every wall (**ESTIMATE**). **Inverted for
  pre-1720 rooms**: see H4.

### M3. Floating furniture with nothing to anchor it [MODERN]
* Rule: a rug that sits only under the coffee table makes the group look like it is
  drifting. At least the front legs of every major piece sit on the rug, and the rug runs
  0.15-0.30 m (6-12 in) past the sides of the furniture.
* Source: Rugs.com (above).
* check: for a modern seating group, the rug rect contains the front 30% of each seat's
  footprint, with a margin of 0.15-0.30 m beyond the group's side extents. More generally,
  a group in mid-floor must be anchored by a rug, a table or a focal item it faces.

### M4. Seat facing away from the thing it is for [UNIVERSAL]
* Source: Yu 2011 fig. 8f ("the armchair is facing away from the television"); Merrell
  emphasis.
* check: every seat `faces` its table, its hearth, its conversation partner or its window.
  Fail any seat whose front zone faces a wall within 1.0 m, unless it is at a desk, a
  table or a built-in bench (**ESTIMATE**).

### M5. A tall item blocks the view or the light [UNIVERSAL]
* Source: Yu 2011 fig. 8d ("a potted plant is blocking the television and the armchair").
  The rest is extrapolation.
* check: no item over 1.2 m high (**ESTIMATE**) overlaps any window's width span within
  0.5 m of the window wall. No item over 1.0 m enters the visibility cone (L2) of the focal
  item.

### M6. Partner too far away [UNIVERSAL]
* Source: Yu 2011 fig. 8e ("the work-chair is too far from the desk"); Merrell pairwise.
* check: chair to desk or table ≤ 0.15 m (tucked) or in front at ≤ 0.5 m. Nightstand
  ≤ 0.30 m. Coffee table 0.41-0.46 m.

### M7. Items standing off the wall for no reason, randomly rotated, colliding [UNIVERSAL]
* Source: Yu 2011 figs. 8c, 8h, 8i; Merrell wall alignment.
* check: for a category whose prior is against-wall (bed head, wardrobe, chest, dresser,
  cupboard, shelf, bench, counter), `wall_gap ≤ 0.05`. Every item's yaw is within ±5 deg of
  the nearest wall's axis or its perpendicular. No footprint overlap.

### M8. Bed in the door line, under a window, or with its head not on a solid wall [MODERN guidance with practical reasons; UNIVERSAL core]
* Rule: the head goes against a solid wall. The door should be visible from the pillows,
  diagonally, but the bed should not be directly in line with the doorway (the "coffin
  position", which "every source warns against"). Avoid a bed under a window, because of
  draughts, condensation, early light and winter cold.
* Sources: Homes & Gardens,
  https://www.homesandgardens.com/interior-design/bedrooms/where-should-a-bed-be-placed-in-a-room ;
  Homebuilding, https://homebuilding.co.uk/advice/feng-shui-bedroom-layout ; Livingetc,
  https://www.livingetc.com/us/advice/feng-shui-bedroom-layout
* check: the bed head is `against_wall` on a wall with no window spanning the head. The
  ray from the door centre along the door normal does not cross the bed footprint's foot
  edge squarely, i.e. within ±20 deg of the bed axis (**ESTIMATE**). From the head centre,
  a door is visible (the line is not occluded by tall items).

### M9. Traffic through the conversation area or across the work triangle [UNIVERSAL]
* Source: Alexander #185; NKBA KPG 5; CUNY sheet (through traffic at one end only);
  Woman & Home ("ignoring natural pathways"),
  https://www.womanandhome.com/us/homes/living-room-design-mistakes/
* check: Z9 and K3.

### M10. Table in a passage [UNIVERSAL]
* Source: NKBA KPG 8 (a seated diner with traffic behind needs 0.914-1.118 m).
* check: if a door-to-door path passes within 1.118 m of a table edge that has seats,
  the band must be clear for that width. Otherwise move the table or the path.

### M11. No focal point, or competing focal points [UNIVERSAL]
* Source: Merrell emphasis ("a dominant focal point ... so that the eye can rest without
  suffering competing demands for visual attention"). In homes the focal point is often a
  fireplace, a large window or an entertainment centre.
* check: each rank-1 or rank-2 room has exactly one `focal()`. Its seat group faces it
  (L1 `m_ef`). If two fireplaces share a room, one group faces each.

### M12. Visual imbalance [UNIVERSAL]
* Source: Merrell visual balance.
* check: L1 `m_vb` threshold. Also, no half of the room (split along either axis) holds
  more than 75% of the total footprint area (**ESTIMATE**).

### M13. Too much, too little, wrong scale [UNIVERSAL]
* Sources: ProcTHOR's room weights and its aim that "rooms continue to have adequate floor
  space for agents to navigate"; Steven Randel's note that a modest apartment wants a
  1.83 m (72 in) sofa, not a larger one. Houzz.
* check: furniture footprint coverage of 15-45% of the room's floor (**ESTIMATE** band;
  no source gives one). Each item's longest side is ≤ 60% of the wall it stands against
  (**ESTIMATE**). Every weight-3 item for the room kind is present.

### M14. Identical chairs, uniform light, one-use rooms in a cottage [UNIVERSAL]
* Source: Alexander #251, #252, #188.
* check: Z19 and Z14.

### M15. A cooker under a window, or with no landing either side [UNIVERSAL]
* Source: NKBA KPG 17 and 20.
* check: K10 and K12. For a hearth: no window directly over an open cooking fire unless a
  hood is present.

---

## 7. Where modern rules and historic evidence disagree

| Topic | Modern guide | Historic evidence | What to do |
|---|---|---|---|
| Seats at rest | pull the groups off the walls (M2) | seats along the walls until the 18th century; tables brought out when needed (H4) | branch on `period`: walls before about 1720 |
| Bedrooms | one bed per bedroom; a couple's realm (Z6) | beds in parlours (72% Lincoln), truckle beds, servants in the hall, benches in a longhouse (H5, H10) | allow beds in parlours and halls by period and region |
| Corridors | avoid them (Z4); there is no historic corridor either | cross passage, screens passage | treat the cross passage as part of the hall (rank 1) |
| Kitchen | NKBA triangle (K1) | separate kitchen building, cooking in the hall, doma (K18-K21) | use K15 (Alexander 3.05 m) for hearth kitchens |
| Windows | light on two sides (Z8) | none in a longhouse; small in a roundhouse | per-type: door and smoke hole as the light source (H13, H16) |
| Clearances | 0.76-0.91 m walkways | tighter rooms (estimate 0.6 m) | relax `r` for pre-1700 (A1) |

---

## 8. Top 25 rules by impact on believability (ranked)

Ranked by my judgement of how quickly a person would notice the failure and say "no human
would do this". The rule IDs point to the full text above.

1. **Everything faces its use, and its back is to a wall or a partner** (M4, M7, L2 prior
   orientation, L1 alignment). A chest, bed or cupboard turned sideways in mid-floor is the
   single loudest tell. [UNIVERSAL]
2. **One connected walkable region at person scale reaches every door and every item's
   use face** (A1, L1 circulation). Disc 0.457 m (0.30 m historic). [UNIVERSAL]
3. **Door swings, thresholds and the door-to-door path are clear** (A11, M1, L2 pathway).
   Path ≤ 1.3 × straight distance (ESTIMATE). [UNIVERSAL]
4. **Activity groups are placed as units**: table with chairs round it at 0.61 m per place;
   bed with nightstand ≤ 0.30 m; desk with chair; hearth with seats (L4 SAGs, A6, A8,
   L1 pairwise). [UNIVERSAL]
5. **The room's inventory matches its kind and its period** (L3 occurrence, L4 room
   weights, H6 inventories). No beds in a London hall in 1600, a bed likely in a
   Lincolnshire parlour, no study in a cottage. [HISTORIC/UNIVERSAL]
6. **The hearth is the focal point of the common room. Seats face it, and its hearth
   extension is clear** (Z10, M11, A10: 0.41/0.51 m in front, 0.20/0.30 m to the sides; open
   hearth 0.5 m keep-out, ESTIMATE). [UNIVERSAL]
7. **Intimacy gradient: privacy rank never decreases with depth from the entrance, and no
   bedroom is a through-room** (Z1, Z4). [UNIVERSAL]
8. **Period-correct resting position**: pre-1720 seats stand along the walls; modern large
   rooms have an anchored group off the walls (H4 vs M2/M3). [HISTORIC vs MODERN]
9. **Use-zone clearances**: seat front 0.76 m, storage front 0.61 m (wardrobe 0.76 m), bed
   side 0.50-0.91 m, chest lid openable (A3-A5). [UNIVERSAL]
10. **Bed placement**: head on a solid wall, not in line with the door, not under a window,
    door visible from the pillow (M8). [UNIVERSAL core]
11. **Type grammar for each vernacular kind** (H1-H3 hall house bay order; H9-H12 longhouse
    aisles, benches and byre end; H14-H15 minka doma/hiroma/irori ranks; H16 roundhouse;
    H17 pueblo; H18 compound; H19 Stube corner). A wrong grammar reads as "not that
    culture". [HISTORIC]
12. **Dining clearance behind seats: 0.81 m against a wall, 0.91 m to edge past, 1.12 m
    with traffic; no table in a passage** (A6, M10). [UNIVERSAL]
13. **Kitchen work set within reach**: fire, water, store and table pairwise ≤ 3.05 m;
    counters ≥ 1.22 m a section; aisle ≥ 1.07 m; NKBA legs 1.22-2.74 m in modern kitchens
    (K15, K4, K1). [UNIVERSAL/MODERN]
14. **Conversation group**: seats 1.22-2.44 m apart, angled toward each other, not crossed
    by any through-path (A9, Z9). [UNIVERSAL]
15. **Wall alignment and no dead slivers**: yaw within ±5 deg of a wall axis; gaps between
    items are either ≥ 0.61 m or ≤ 0.05 m (M7, A2, L1). [UNIVERSAL]
16. **The shop house stack**: shop at the street on storey 0 with a counter at the opening,
    kitchen behind it (or with the hall on storey 1), chambers above, garret at the top
    (H20). [HISTORIC]
17. **The common room at the heart, and the entry passing it** (Z2, Z3). [UNIVERSAL]
18. **Windows are used**: in day rooms a seat, table or work item stands within 1.0 m of a
    window; no tall storage covers a window; no cooker under a window (Z11, M5, K12).
    [UNIVERSAL]
19. **Doors near corners; through-traffic kept to one end** (Z17). [UNIVERSAL]
20. **One dominant focal point per room, with symmetry about it**: flanking pairs, and
    pier table with glass between windows (M11, L1 symmetry, H7). [UNIVERSAL/HISTORIC]
21. **Furnishing density and scale** in band (15-45% coverage, ESTIMATE); items sized to
    their wall (M13). [UNIVERSAL]
22. **Visual balance**: the footprint-weighted centroid near the room centre (M12, L1).
    [UNIVERSAL]
23. **Storage placement**: chests at the bed foot or against walls; presses on interior
    walls, not across windows; bulk storage in garret, loft or service rooms, ≥ 15% of
    area (Z18, Z20). [UNIVERSAL]
24. **Multi-use rooms and alcove beds are legitimate in small and old houses** (H8, Z14).
    The checker must not fail a cottage hall for holding eating, sitting, work and a bed
    alcove. [HISTORIC]
25. **Variety**: not all identical chairs; a "great chair" for the head of the house in a
    hall of forms and stools; light in pools (Z19). [UNIVERSAL/HISTORIC]

---

## 9. Source list (all fetched or searched 2026-11-14)

* Merrell, Schkufza, Li, Agrawala, Koltun 2011. Interactive Furniture Layout Using Interior
  Design Guidelines. https://paulmerrell.org/furnitureLayout2.pdf (full text read)
* Yu, Yeung, Tang, Terzopoulos, Chan, Osher 2011. Make It Home.
  https://ww3.math.ucla.edu/camreport/cam11-49.pdf (full text read)
* Fisher, Ritchie, Savva, Funkhouser, Hanrahan 2012. Example-based Synthesis of 3D Object
  Arrangements. https://graphics.stanford.edu/projects/scenesynth/ (abstract only)
* Deitke et al. 2022. ProcTHOR. https://ar5iv.labs.arxiv.org/html/2206.06994 (Appendix B)
* Yang et al. 2024. Holodeck. https://arxiv.org/html/2312.09067v2
* NKBA Kitchen Planning Guidelines with Access Standards.
  https://kb.nkba.org/uploads/2022/05/Kitchen-Planning-Guidelines.pdf (full text read)
* Alexander et al. 1977, A Pattern Language, pattern texts at
  https://urbigenous.net/a-pattern-language/ (41 patterns read)
* Eleanor John 2008. At home with the London middling sort: the inventory evidence for
  furnishings and room use, 1570-1720. Regional Furniture XXII. (full text read; URL in 5b)
* Milek et al. 2014. Social space at Hrísbrú. (full text read; URL in 5c)
* Hurstwic, the Viking-age longhouse. (URL in 5c)
* JAANUS, irori. Wikipedia: Minka; Hall house; Great hall; Hausa architecture;
  de.wikipedia: Herrgottswinkel.
* ScARF Iron Age panel 5.4; Turkey Creek Pueblo study; Weald & Downland Horsham shop; the
  Architectural History article "Living over the shop".
* IRC R1001.10 hearth extension, via InspectAPedia and rumford.com.
* Houzz "Measurements to Know" (Steven Randel, Eva Byrne, Prozfile); Studio Matrx (a
  student handout; its Neufert attributions are unverified).
* Rybczynski 1986, Home: A Short History of an Idea, via reviews (American Heritage,
  Kirkus, lorenwebster.net). The book itself was not read.

**Not obtained**: the Panero & Zelnik, Neufert and Time-Saver Standards primary texts (the
PDFs were unreachable or image-only). Margaret Wood's book. Primary data on Norse bench
widths. Every number attributed to Panero above comes through Merrell's Table 1.

Rich houses — HOUSE-RICH
========================

A rich house is an ordinary house whose storeys are **articulated**. It is not
a cottage with the height turned up: the extra metre is bought with named
pieces of architecture that can be counted, that sit inside the planned
exterior bounds, and that a check refuses to let disappear.

It is a **style**, `&"rich"` in `HouseSpec.STYLES`, not a family. That is a
deliberate choice and it is the reason this cost one working day rather than a
week:

* `HouseSweep.styles()` is `HouseSpec.STYLES.keys()`, so every house suite that
  already swept the five styles now sweeps rich as well — `house`, `houseqa`,
  `hmultistory`, `hexterior`, `hbounds`, `hroof`, `hcomponent`, `henvelope`.
* `BuildingLibrary.styles(&"house")` returns that same table, so the Studio
  dropdown and `BrickWild.describe_kind()` publish it with no extra code and
  **no API_VERSION change**.
* The planner, the furnisher, the walking check and the assembler are used
  **unmodified**. A rich house is a real house; it just has a crown on it.

A separate `BuildingFamilyAdapter` kind was considered and rejected: it would
have meant a `RichSpec` class, a `BuildingCodec.CLASSES` entry, a
`BuildingDocument.spec_types` row, `for_building()` reordering, and coverage in
`libraryquick`/`placementquick` — all of that for what is fundamentally a
different chance table plus one emitter pass.

## The four switches

All derived from the style row, seeded like every other exterior feature, so a
rich house is still reproducible from `(style, trade, size, storeys, seed)`:

| field | meaning |
|---|---|
| `HouseSpec.cornice` | a three-step crown at the wall head on every elevation |
| `HouseSpec.string_courses` | belt bands at that many storey lines, from the top down |
| `HouseSpec.pediments` | a pediment over every upper window that has room for one |
| `HouseSpec.ridge_finial` | a plinth and an obelisk crowning the ridge cap |

A style row with **no** `cornice` key is an ordinary house. That is the whole
extension seam, and it is what makes the following true:

> `HouseGenerator` draws all four behind one `if s.has("cornice")`. Adding rich
> consumed **zero** RNG for the five existing styles, so not one seeded plan,
> roof, window or piece of furniture moved.

`hrich` proves the same thing from the other end — it builds all five
non-rich styles at one and two storeys and requires each to emit **zero**
ornament components.

The style row also carries `"min_storeys": 2`. A rich house is read as banded
storeys and a single storey has no band to read, so the floor is in the table
rather than invented in the generator. It is deterministic, exactly like
`ShopGenerator` forcing one storey for a prison or a market hall.

## The vocabulary

Everything is emitted through `component_box`/`component_slab`, so each piece is
a **named component** with a stable `<role>#<n>` identity and a host — the same
evidence `qa/component_check.gd` re-emits against the mesh. A piece that is
logged but never built fails `ComponentCheck` before it ever reaches the rich
check.

| role | what it is |
|---|---|
| `cornice_bed` / `cornice_corona` / `cornice_crown` | the three steps of the crown; the corona is the one that oversails, by `CORNICE_OUT` |
| `string_course` | a belt band, broken where an opening comes through |
| `pediment_cornice` / `pediment_face` / `pediment_rake` | a horizontal cornice, the tympanum, and the two raking cornices |
| `ridge_crown_plinth` / `ridge_crown` | the obelisk on the ridge cap |

Hosts are `cornice`, `band_<level>` and `pediment_<window index>`, so exterior
QA can say *which* band or *which* window lost a piece rather than that a
count fell.

Every number lives in `HouseGeometry` (`CORNICE_*`, `BAND_*`, `PEDIMENT_*`,
`CROWN_*`) and the emitter reads them from there. The bound reads them from
there too. That is the whole defence against a bound that drifts away from the
thing it bounds.

## The bound

`HouseGeometry.exterior_bounds()` grows by `CORNICE_OUT` when the house has a
crown, and `roof_top_above_walls()` adds `RIDGE_CAP_TOP + CROWN_BASE_H +
CROWN_H` to the rise when it has a ridge crown. `house_bounds_suite` runs the
**full cross product** — two orientations × two roof types × two storey counts ×
cornice × bands × pediments × crown, 128 fixtures — and asserts both halves:
nothing sticks out (0.5 mm), and nothing is more than `BOUNDS_TOL` loose.

`hbounds` also asserts `total_height(spec)` equals the mesh top to 0.5 mm.
Because the crown is emitted at exactly the height the bound adds, that is an
identity rather than a tolerance.

## The rules that make the word mean something

`qa/rich_house_check.gd`, seven rules, each replaceable through `RuleSet`:

| rule | what it refuses |
|---|---|
| `storeys` | a rich house with one storey, or a storey with no rooms |
| `cornice` | a crown that does not reach every elevation — counted against `shell_runs()`, not the literal four |
| `bands` | fewer belt bands than the spec asked for, or one that skips an elevation |
| `pediment` | a tympanum for the wrong number of dressable windows, or a missing role |
| `crown` | a spec that asked for an obelisk and did not get one |
| `density` | **fewer than three ornament components per storey** |
| `bounds` | ornament outside the planned exterior, or a bound loose by more than `BOUNDS_TOL` |

The bands and the pediments hang inside the crown's reach by construction
(`BAND_OUT` and `PEDIMENT_OUT` are both smaller than `CORNICE_OUT`), so the
bounds matrix crosses the two switches that actually move the bound — 32
fixtures — and leaves the other two to `hrich` and to the `houseqa` sweep,
which now includes rich and measures containment for every house it builds.

One trap worth naming, because it is easy to write and impossible to see: the
wall builder hands `_wall_run` **storey-relative** opening heights and adds the
storey offset itself, so a band that compared a *world* `y0` against
`op["bottom"]` would never see a doorway to break at, and would run its belt
straight across the front door. `_moulding` therefore takes `y0` in the
storey's own frame plus an explicit `y_offset`, exactly like the wall path.

`density` is the rule the whole file exists for. Without it a two-storey
cottage passes every other rule and is still a cottage. `hrich` proves it by
offering the rich check an **unmutated two-storey cottage** and requiring a
`density:` failure.

## Negative controls

`hrich` builds a subclass per rule that drops exactly one piece and requires the
same check to notice: `NoCornice`, `NoBands`, `NoPediments`, `NoCrown`. A
fifth fixture, `WideMouldings`, triples the projection of every moulding and
requires a `bounds:` failure — which is only true because the bound grows by
`CORNICE_OUT` rather than by a generous constant. The control house is asserted
clean first, or the failures below it would mean nothing.

## Running it

```
godot --headless --path . --script res://tests/run_all.gd -- hrich
godot --headless --path . --script res://tests/run_all.gd -- lane:rich
```

`lane:rich` composes `hrich` with `hbounds`, `hcomponent`, `hopening`,
`henvelope` and `hjetty` — the suites that would notice a trim mistake. Add
`lane:geom` when the emitter itself moved, because `hbounds` and `henvelope`
are the ones that catch a piece reaching further than it promised.

## What it deliberately is not

* **Not a new family.** See the rejected alternative at the top.
* **Not stretched.** `density`, plus the control cottage.
* **Not unbounded.** The storey clamp stays 1..3; `max_storeys()` is 4 and was
  already the harness's own cap for a castle keep.
* **Not a new material stream.** The four surface slots (wall, trim, roof,
  floor) are a load-bearing contract — the glazing vertex marker and the rug
  marker both live inside it. Richness is expressed as *geometry and palette*,
  and the style row's `wall`/`trim`/`roof` colours do the rest.
* **Not in villages.** `village/programmer.gd` names its own styles per culture
  and none of them is rich, so nothing there changed.

## Evidence, measured

| suite | checks | result | host time |
|---|---:|---|---:|
| `hrich` | 69 | PASS, 0 failures, 0 warnings | 31 s |
| `hbounds` (incl. the 32 rich fixtures) | 1933 | PASS, 0 failures | 51 s |
| `hcomponent` | 1648 | PASS, 0 failures | 17 s |
| `hopening` | 306 | PASS, 0 failures | 13 s |
| `henvelope` | 25 | PASS, 0 failures | 15 s |
| `hjetty` | 202 | PASS, 0 failures | 8 s |
| **`lane:rich`, all six** | **4183** | **PASS** | **135 s** |
| `hmultistory` (200-house programme sweep) | 210 | PASS, 1 warning | 69 s |
| `hexterior` | 1838 | PASS, 0 failures | 295 s |
| `house` (the contract sweep) | 147 | PASS, 0 failures | 494 s |
| `houseqa` (statistical) | 279 | PASS, 0 failures, 25 warnings | 663 s |
| `harchetype` (incl. `rich_merchant` × 4 scales) | — | PASS, 0 defects | 414 s |

The four bottom rows matter because adding a sixth style widens
`HouseSweep.styles()`, which they all iterate: `house` went from 123 to 147
checks — exactly one style × six trades × four sizes — and `houseqa` from 257
to 279. Both pass, so a rich house is a real house and not merely a decorated
exception.

These were driven suite by suite rather than through `-- lane:rich`, because
`tests/run_all.gd` will not compile: `qa/castle_route_check.gd` calls
`courtyard_network()`, which is defined nowhere in the tree. That break is
present at `HEAD` and is not HOUSE-RICH's — but it does leave the *selector
plumbing* for `hrich` unproven, which is the one thing still open.

The strongest single result is the fingerprint. `tools/fingerprint_houses.gd`
was run against a detached `HEAD` worktree and against this tree:

```
fixtures: 120
ornament base: ornament=0
ornament new:  ornament=0
diff base.txt new.txt  ->  IDENTICAL - no existing house moved
```

120 fixtures — five styles × six trades × four canonical sizes — with the plan
text hash and the shell vertex hash byte-for-byte equal, and **not one rich
ornament component on any of them**. That is the claim "adding rich moved no
existing seed" measured rather than asserted.

`harchetype` reports its usual warnings on `rich_merchant` at 1.9× — daylight
per square metre, and the odd walkable-but-cut-off pocket. Those are the same
documented compromises every other archetype reports at that scale, and they
are reported rather than quietened.
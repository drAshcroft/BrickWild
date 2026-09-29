# Code quality plan

This plan follows the generation pipeline's existing boundaries: a family
chooses a spec, a planner makes a plan, a builder emits geometry, and QA checks
the result. Splits should preserve seed output and the public API. Line count
is a signal to inspect cohesion, not a reason to make one-line forwarding
classes.

## This pass

1. **Furnishing:** Keep the room loop in `HouseFurnisher`. Put recipe data,
   candidate placement, affinity scoring, and navigation repair in separate
   classes. Remove static mutable state so one plan cannot change the next
   furnishing run. Add a polygon outline regression check.
2. **Castle plans:** Move hall, chapel, and range planning out of
   `CastleGenerator`. Keep procedural spec generation there, and keep the
   occupied keep plan in `CastleKeepPlan`.
3. **Family API:** Dispatch quality checks through the same family adapter
   used for generation and building. A new family then has one place to define
   its QA behavior.
4. **Shared boundaries:** Let `MassBuilder` import mapped surfaces and
   `HouseBuilder` extend upper walls. Castle interiors should not access
   either builder's private mesh state. Share the repeated RNG draws used by
   house, castle, church, and temple generators. Remove the shop furnisher
   forwarding class.
5. **Lot rules:** Give site, lane, purpose, and neighbor constraints named
   functions. Commit a trimmed lot polygon and mill race only after the whole
   candidate passes.

## Next passes

These remain substantial and deserve behavior-focused changes of their own:

1. Split `HouseFurnishPlacement` by placement strategy only where the wall,
   floor, and surface searches can have narrow interfaces. It is still over
   1,000 lines. Keep candidate validity shared; do not duplicate clearance
   rules to make the file smaller. Name the resulting cross-class entry points
   as public methods instead of relying on underscore-prefixed helpers.
2. Separate room naming, openings, and upper storey circulation in
   `HousePlanner`; they already form named stages. In `HouseBuilder`, roof
   emission is a large, coherent tail and is the first extraction candidate.
   Give a roof collaborator a narrow emission interface so it does not reach
   into `_kit` or builder logs. `CastleBuilder` has distinct tower house,
   enclosure, and keep emitters, but they share mass logging: extract one
   variant at a time behind `MassBuilder` methods.
3. Separate `VillageDresser` recipe data, placement spot searches, and
   clearance checks. Keep its seeded RNG order stable. `LotPlanner` still
   mixes frontage search with legality checks; the named predicates added in
   this pass make a later frontage extraction easier to test.
4. Split `HouseFurnishCheck` by independent rules once the warning contract is
   documented. The current warning behavior is intentional; moving a rule
   must not quietly change its severity.
5. Reduce test suite files by moving reusable fixtures and generators out of
   test cases. A long test file is lower priority than production coupling.

## Verification for a split

Register any new `class_name` scripts with a headless editor pass. Run the
lane for the touched code, then compare deterministic seeds and warning counts
where a refactor claims to preserve behavior. The QA harness has expensive
furnishing searches, so use the named lanes in `tests/run_all.gd` instead of
running the full sweep after every edit.

## Baseline failures observed during this pass

- `vlot` passes its 50 seed street and green sweep, but its manor frontage
  fixture reports `the manor found no frontage`. The same fixture fails on a
  clean `HEAD` checkout.
- `ckfurnish` reports `stair_line` for the same five castle cases on both the
  edited tree and a clean `HEAD` checkout (55 checks, five failures, eight
  warnings). Keep this as a separate functional repair; changing the planner
  to make a refactor lane green would mix two causes.

## Verification completed

- The headless editor registered the new global classes without parse errors.
- Geometry and furnishing lanes: 13 suites, 8,131 checks, no failures.
- Castle range plans and polygon sconces: two suites, 89 checks, no failures.
- Temple and rite lane: two suites, 2,247 checks, no failures.
- Focused public quality dispatch probes returned well-formed reports for
  church, castle, house, shop, hotel, temple, world, and village.

The full castle sweep and the 200 case interior sweep were stopped after they
ran far beyond the documented lane estimates without a final summary. Their
completed focused checks are listed above; those exhaustive results remain
unverified in this pass.

# Shared floor-edge review — 2026-10-09

The repair gives floor rectangles closed edges with a fixed 0.05 mm tolerance. Obstacle rectangles keep their existing semantics. Floor levels and the maximum traversable step remain unchanged. No emitter or building geometry changes.

Large Rotunda diagnostic cells failed floor coverage at a shared band seam even with all obstacles removed. The repaired grid restores all five large cult routes, each with 2.72 m processional clearance. All fifteen rite reports have no failures. Small/default altar-fit and lantern complaints remain separate; the diagnostic's native zero does not certify full temple QA.

Six focused controls pass: local and 500 m translated seams, a real 1 mm gap sampled at its midpoint, a pit, an obstruction, and a 2 m level change. The seam witnesses must lie on the shared edge and reach the far floor. Physical gaps and hazards remain blocked.

## Native evidence

- `restart18_walk_floor_edge_focus`: native 0, 0.641 s, six controls, no failures.
- `restart18_rotunda_axis_cells`: baseline diagnostic, native 0, 20.107 s; all five large routes fail at uncovered floor cells without obstacles.
- `restart18_rotunda_closed_floor_axis`: candidate diagnostic, native 0, 18.279 s; all five large routes restored. Root inspected the actual rite and QA reports.
- `restart18_walk_floor_house_plan`: native 1, 167.465 s; planning passes 56 checks. Multistory and walk-pin suites retain 28 failures and 32 warnings.
- `restart19_walk_floor_baseline_consumers`: unchanged floor code, native 1, 194.705 s; identical 28 failures and 32 warnings, with no changed complaint rows. Both runs use the same isolated project and every other source remains fixed. Comparison is saved in that receipt directory.
- `restart19_walk_floor_world_consumers`: native 0, 49.993 s; all 43 Hammam, Nagara, stepwell, mountain and Dravida mesh-support checks pass.

The reproduced failures include sparse rooms, table/bedside placement and multistory stairs, plus Basilica and Romanesque coplanar surfaces. They remain work for the inhabited-building plan. This repair does not close house design, sacred identity, or the broader visual matrix.

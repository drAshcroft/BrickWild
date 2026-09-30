# CAS-REG-002: gate tower and wall stair clearance

The original Crusader fortress seed 9118 placed both outer-ring wall stairs
across the logged bounds of the inner-ring gate towers. Each intersection
measured 1.966 m by 2.52 m in plan. This was a pre-existing castle massing
failure, reproduced before the aperture changes.

`CastleAccessGeometry.wall_stairs()` now reserves the mass envelopes of towers
on other enceinte rings while it scores stair positions. It retains exact
outline tests for every tower, so a stair can still meet its own curtain and
the gate passage stays clear. The repaired seed retains four gate towers and
four wall stairs, two connected stair routes on each ring, clear tread
headroom, and matching component geometry.

The [same-scale footprint diagnostic](../artifacts/cas_reg_002/README.md)
uses production mass logs: two tower/stair intersections before, zero after.
The evidence folder also contains fixed-camera geometry renders and the
focused logs. `cgatestairs` checks the affected seed, and `cgateaccess`
checks gate routes across castle styles. The broader geometry-only `caccess`
suite checks stair routes, emitted treads and headroom. The full castle
furnishing, normals and massing sweeps remain separate scheduled checks.

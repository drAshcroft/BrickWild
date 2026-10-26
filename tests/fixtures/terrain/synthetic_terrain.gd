extends RefCounted
## Landforms with a known answer, for the terrain reader and for anything that
## judges a plan against ground. No class_name: tests preload this file.
##
## Frame: SITE metres, x east, z south. A slope of s % is a gradient of s/100.
## Every landform is a plain formula, so a test can state the slope at a
## defining point and the relief without measuring anything first. Defaults
## cover Rect2(-400, -400, 800, 800) at 5 m. Relief is over that default rect.
##
##   plane_5/15/30/50  h = 100 - s*z with s = 0.05 / 0.15 / 0.30 / 0.50
##                     (rises toward the north). Slope s everywhere; relief
##                     = s * 800 = 40 / 120 / 240 / 400 m.
##   valley            h = 20 + 0.30 * max(0, |z| - 30). Floor 60 m wide along
##                     x at 20 m, sides at 30 % (dh/dz = +-0.30 for |z| > 30).
##                     Relief 0.30 * 370 = 111 m.
##   river_valley      valley, but |z| <= 6 is a 12 m channel 3 m below the
##                     floor (17 m); water_level_m 17.5. Relief 114 m.
##   spur              h = (100 - 0.10 * (z + 400)) - 0.25 * |x|: a ridge
##                     running out from the north along x = 0, crest falling
##                     10 % to the south, flanks 25 % either side
##                     (|dh/dx| = 0.25, dh/dz = -0.10). Relief over the rect
##                     is 100 (crest at z=-400) - (20 - 100) = 180 m.
##   crest             round hill: 60 m at r <= 20 (a 40 m flat top), then
##                     falling 20 % to 0 at r = 320, 0 beyond. Relief 60 m.
##   saddle            h = 40 + 0.0005 * (x^2 - z^2): a pass along x. Gradient
##                     (0.001 x, -0.001 z); at (100, 0) slope 10 %. Relief
##                     0.0005 * 160000 * 2 = 160 m.
##   cliff_band        10 m for z < 50, 25 m from z = 50: a 15 m vertical step,
##                     which a 5 m grid shows as a 300 % ramp across one cell.
##   lake_shore        h = 20 - 0.08 * z (falls 8 % to the south); water_level
##                     4 m = the ground at z = 200, so the southern quarter
##                     (z > 200) is wet. Relief 0.08 * 800 = 64 m.
##   island            cone h = max(-10, 40 - 0.16 * r), r from the centre: 40 m
##                     peak, 16 % flanks, sea floor at -10 m beyond r = 312.5;
##                     water_level 0 (a sea). Relief 50 m.
##   islet             (make("islet") only; not in names()) Isola dei Pescatori:
##                     an ellipse 350 x 120 m (3.3 ha), a dome 2.4 m over the lake,
##                     the bed falling away round it. water_level 0.
##   lagoon            a shallow lagoon south of a gentle shore (VTER-FORM-WATER):
##                     the shore line z_s = 20 + 10 sin(x / 70); land north of
##                     it h = 0.6 + 0.03 (z_s - z) (3 %), the lagoon south of it
##                     h = max(-2.6, 0.6 - 0.06 (z - z_s)): wet (h <= 0, the
##                     level) from z_s + 10, the bed 2.6 m down from z_s + 53.
##                     water_level 0. The 400 m form window is 42 % wet and the
##                     450 m disc 46 %: the ground derives `water` (row 2), not
##                     `shore` (row 1). Relief 0.6 + 0.03 * 430 + 2.6 = 16.1 m.

const _NAMES := ["plane_5", "plane_15", "plane_30", "plane_50", "valley", "river_valley",
	"spur", "crest", "saddle", "cliff_band", "lake_shore", "island", "lagoon"]


static func names() -> PackedStringArray:
	return PackedStringArray(_NAMES)


static func make(p_name: String, rect := Rect2(-400, -400, 800, 800), cell_m := 5.0) -> VillageTerrain:
	var water := NAN
	var f: Callable
	match p_name:
		"plane_5":
			f = func(_x: float, z: float) -> float: return 100.0 - 0.05 * z
		"plane_15":
			f = func(_x: float, z: float) -> float: return 100.0 - 0.15 * z
		"plane_30":
			f = func(_x: float, z: float) -> float: return 100.0 - 0.30 * z
		"plane_50":
			f = func(_x: float, z: float) -> float: return 100.0 - 0.50 * z
		"valley":
			f = func(_x: float, z: float) -> float: return 20.0 + 0.30 * maxf(0.0, absf(z) - 30.0)
		"river_valley":
			water = 17.5
			f = func(_x: float, z: float) -> float:
				if absf(z) <= 6.0:
					return 17.0
				return 20.0 + 0.30 * maxf(0.0, absf(z) - 30.0)
		"spur":
			f = func(x: float, z: float) -> float: return 100.0 - 0.10 * (z + 400.0) - 0.25 * absf(x)
		"crest":
			f = func(x: float, z: float) -> float:
				var r := Vector2(x, z).length()
				return 60.0 if r <= 20.0 else maxf(0.0, 60.0 - 0.20 * (r - 20.0))
		"saddle":
			f = func(x: float, z: float) -> float: return 40.0 + 0.0005 * (x * x - z * z)
		"cliff_band":
			f = func(_x: float, z: float) -> float: return 10.0 if z < 50.0 else 25.0
		"lake_shore":
			water = 4.0
			f = func(_x: float, z: float) -> float: return 20.0 - 0.08 * z
		"island":
			water = 0.0
			f = func(x: float, z: float) -> float: return maxf(-10.0, 40.0 - 0.16 * Vector2(x, z).length())
		"lagoon":
			water = 0.0
			f = func(x: float, z: float) -> float:
				var zs := 20.0 + 10.0 * sin(x / 70.0)
				if z < zs:
					return 0.6 + 0.03 * (zs - z)
				return maxf(-2.6, 0.6 - 0.06 * (z - zs))
		"islet":
			# Isola dei Pescatori's size (VTER-ISLAND-FILL): an ellipse 350 m by 120
			# m, a dome 2.4 m over the lake, the bed falling away round it. Not in
			# names(): it is a fixture for the island fill, not a landform every
			# suite sweeps. water_level 0.
			water = 0.0
			f = func(x: float, z: float) -> float:
				var rho2 := (x / 175.0) * (x / 175.0) + (z / 60.0) * (z / 60.0)
				if rho2 <= 1.0:
					return 2.4 * (1.0 - rho2)
				return maxf(-3.0, -1.2 * (rho2 - 1.0))
		_:
			push_error("synthetic_terrain: unknown landform '%s'" % p_name)
			return VillageTerrain.flat(rect, 0.0, cell_m)
	var t := VillageTerrain.from_sampler(f, rect, cell_m, water)
	t.source = "synthetic:" + p_name
	return t

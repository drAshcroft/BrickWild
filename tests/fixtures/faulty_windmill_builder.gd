extends WindmillBuilder
## A windmill builder that places its openings the way the Rook Mill walk pin
## (1a10f8c7e57ac727ae3 #1, #4) found them: a vertical quad on the CIRCLE the
## polygon drum is inscribed in -- on the bounding shape, not on the surface.
## `WindmillCheck`'s `openings` rule must fail it; if it does not, the rule is
## a tautology.


func _openings() -> void:
	tag("openings")
	host("openings")
	var floor: float = WindmillGeometry.floor_y(spec)
	var h: float = WindmillGeometry.door_h(spec)
	_quad_opening(Vector3(0.0, floor + h * 0.5, -spec.base_r), Vector3.FORWARD,
		Vector3.UP, WindmillGeometry.door_w(spec), h, SURF_DARK, "door")
	for i in range(maxi(spec.windows, 1)):
		var t: float = (float(i) + 1.2) / (float(maxi(spec.windows, 1)) + 0.4)
		var wy: float = lerpf(floor + 1.7, spec.curb_y - 1.5, t)
		var swing: float = deg_to_rad(-62.0 if i % 2 == 0 else 62.0)
		var outward := Vector3(sin(swing), 0.0, -cos(swing))
		var at: Vector3 = outward * WindmillGeometry.radius_at(spec, wy)
		_quad_opening(Vector3(at.x, wy, at.z), outward, Vector3.UP, WINDOW_W,
			WINDOW_H, SURF_DARK, "window")

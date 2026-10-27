extends WindmillBuilder
## A windmill builder that draws the way in as the 26 Oct bug walk found it
## (1a17afdf-1, 1a17b003-1, 1a17b028-2, 1a17afe6-4): the door is a frame on an
## UNBROKEN wall -- nothing is cut away behind it -- and a post mill's stair is
## a landing with its treads left off. `WindmillCheck`'s `entry` rule must fail
## every one of them; if it does not, the rule is a tautology.


## The wall whole, the way it was drawn before the doorway was cut.
func _tapered_drum(base_y: float, base_r: float, top_r: float, height: float,
		thickness: float, surf: int, sides: int, _with_door := false) -> AABB:
	return super._tapered_drum(base_y, base_r, top_r, height, thickness, surf, sides, false)


## The stair without its treads: a landing in the air, level with a sill nobody
## can climb to.
func _stair() -> void:
	tag("access")
	host("access")
	var n: Vector3 = WindmillGeometry.door_normal(spec)
	var at: Vector3 = WindmillGeometry.door_point(spec)
	component_box("landing", Vector3(1.4, 0.12, WindmillGeometry.LANDING_DEPTH),
		Transform3D(Basis(Vector3.UP, atan2(n.x, n.z)),
			Vector3(at.x, 0.0, at.z) + n * (WindmillGeometry.LANDING_DEPTH * 0.5)
			+ Vector3(0.0, WindmillGeometry.floor_y(spec) - 0.06, 0.0)), SURF_WALL)

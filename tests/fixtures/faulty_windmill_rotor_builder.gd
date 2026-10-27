extends WindmillBuilder
## A windmill builder that does what the 26 Oct bug walk found (pins
## 1a17afe6-1 and 1a17b00f-3): a stage whose rail stands IN the sail plane, so
## every sail comes round through it, and a windpump whose head -- the collar's
## big brother -- sits in the plane of its own fan. `WindmillCheck`'s `swept`
## rule must fail both; if it does not, the rule is a tautology.


## The stage the way it was drawn: the ring and its rail at the sail plane's own
## radius rather than behind it.
func _stage() -> void:
	tag("stage")
	host("stage")
	var start: float = -PI * 0.5 - spec.stage_arc * 0.5
	_rail(spec.stage_r, spec.stage_y, start, spec.stage_arc, 7, "stage_rail")


## The head, and a drum of gearbox standing where the fan's hub is.
func _windpump_head() -> void:
	super._windpump_head()
	var at: Vector3 = WindmillGeometry.axle_point(spec)
	component_box("head_gearbox", Vector3(spec.head_r * 2.0, spec.head_r * 2.0,
		spec.head_r * 2.0), Transform3D(Basis(), at + Vector3(spec.sail_r * 0.6, 0.0, 0.0)),
		SURF_TRIM)

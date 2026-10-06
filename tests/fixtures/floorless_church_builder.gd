extends ChurchBuilder
## A church builder with no floor, as every church was until WALK-QA 6 Oct
## (Abbey Ivo pin 2, "stuck in door"): each room a closed shell whose bottom
## faces DOWN at y=0, so there is nothing to stand on inside and a walker on
## the ground jams its foot on those undersides' edge in the doorway.
## church_aperture_suite's floor probe must fail it, or that probe is a
## tautology.


func _build_floor() -> void:
	pass

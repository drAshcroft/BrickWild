class_name HotelSpec
extends HouseSpec
## A palatial storybook hotel: a plan-first interior behind a landmark facade.

const HOTEL_STYLES := {
	&"grand_budapest": {
		"label": "Grand Budapest",
		"wall": ["d66f9b", "ef9fbd"],
		"trim": ["f5e4c5", "fff2d8"],
		"roof": ["243657", "3e5278"],
		"floor": ["7b2948", "a94b68"],
		"roof_rise": [4.8, 6.2],
		"ornament": [0.85, 1.0],
	},
	&"alpine_palace": {
		"label": "Alpine Palace",
		"wall": ["c9838d", "e5a9ad"],
		"trim": ["eee1ca", "fff5df"],
		"roof": ["30435d", "50647d"],
		"floor": ["70413b", "966158"],
		"roof_rise": [4.2, 5.6],
		"ornament": [0.65, 0.9],
	},
}

var facade_bays: int = 15
var centre_fraction: float = 0.34
var roof_rise: float = 5.4
var ornament: float = 0.95
var balconies: int = 3
var cupolas: bool = true


func _init(p_seed := 0) -> void:
	super(p_seed)
	# dormer_count is HouseSpec's now; a hotel simply has more of them
	dormer_count = 9
	style = &"grand_budapest"
	trade = &"none"
	storeys = 3
	width = 48.0
	length = 24.0
	height = 3.6


## The footprint of the facade dressing, which stands out in front of the wall:
## the end cornices, the balconies and the entrance canopy. HouseGeometry
## merges it into exterior_bounds so the planned exterior includes it.
func landmark_footprint() -> Rect2:
	var front := HotelGeometry.front_z(self) - HotelGeometry.FACADE_REACH
	var half := width * 0.5 + 0.55
	return Rect2(Vector2(-half, front), Vector2(half * 2.0, length * 0.5 + 0.5 - front))


## Highest point of the silhouette: the dormer and cupola finials, which rise
## above the ridge.
func landmark_height() -> float:
	return HotelGeometry.wall_top(self) + maxf(roof_rise, HotelGeometry.FINIAL_RISE)

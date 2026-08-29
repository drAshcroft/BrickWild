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
var dormer_count: int = 9
var balconies: int = 3
var cupolas: bool = true


func _init(p_seed := 0) -> void:
	super(p_seed)
	style = &"grand_budapest"
	trade = &"none"
	storeys = 3
	width = 48.0
	length = 24.0
	height = 3.6

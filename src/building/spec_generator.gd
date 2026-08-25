class_name SpecGenerator
extends RefCounted
## Turns a seed into a BuildingSpec. All "interesting variety" decisions live here.

const EUROPEAN_SUBTYPES := ["townhouse", "cottage", "barn", "tower_house", "shop"]
const ASIAN_SUBTYPES := ["pagoda", "teahouse", "farmhouse", "merchant_house", "storehouse"]

const EU_WALL_COLORS: Array[Color] = [
	Color("d8cdb4"), Color("cbb896"), Color("e2dac6"), Color("bfa98a"), Color("9c9484"),
]
const EU_TIMBER_COLORS: Array[Color] = [
	Color("5a4633"), Color("6b5236"), Color("4a3826"), Color("74573b"),
]
const EU_ROOF_COLORS: Array[Color] = [
	Color("8a4a35"), Color("6f4436"), Color("55606a"), Color("7a5c42"), Color("3f4a52"),
]

const AS_WALL_COLORS: Array[Color] = [
	Color("efe8da"), Color("e6dcc8"), Color("f5f0e6"), Color("ddd2ba"),
]
const AS_TIMBER_COLORS: Array[Color] = [
	Color("7a3b2a"), Color("8a4a30"), Color("5f3322"), Color("a05a36"),
]
const AS_ROOF_COLORS: Array[Color] = [
	Color("3a4750"), Color("2f3a42"), Color("51565e"), Color("4a4038"), Color("274a52"),
]

static func generate(p_seed: int) -> BuildingSpec:
	var s := BuildingSpec.new(p_seed)
	var r := s.rng

	s.style = &"european" if r.randi_range(0, 1) == 0 else &"east_asian"
	if s.style == &"european":
		_gen_european(s)
	else:
		_gen_asian(s)
	return s

static func _gen_european(s: BuildingSpec) -> void:
	var r := s.rng
	s.subtype = _pick(r, EUROPEAN_SUBTYPES)
	match s.subtype:
		"tower_house":
			s.width = r.randf_range(5, 7)
			s.depth = r.randf_range(5, 8)
			s.floors = r.randi_range(3, 5)
			s.roof_type = &"pyramidal" if r.randf() < 0.5 else &"gable"
			s.chimney = true
			s.porch = false
		"barn":
			s.width = r.randf_range(8, 13)
			s.depth = r.randf_range(6, 10)
			s.floors = r.randi_range(1, 2)
			s.roof_type = &"gable"
			s.dormer_count = 0
			s.chimney = false
		"cottage":
			s.width = r.randf_range(4.5, 6.5)
			s.depth = r.randf_range(4, 6)
			s.floors = r.randi_range(1, 2)
			s.roof_type = &"hipped_gable"
			s.chimney = true
			s.porch = r.randf() < 0.5
		"shop":
			s.width = r.randf_range(5, 8)
			s.depth = r.randf_range(5, 7)
			s.floors = r.randi_range(2, 3)
			s.roof_type = &"hip"
			s.chimney = true
			s.porch = true
		_: # townhouse
			s.width = r.randf_range(5.5, 9)
			s.depth = r.randf_range(5, 8)
			s.floors = r.randi_range(2, 4)
			s.roof_type = &"gable" if r.randf() < 0.7 else &"hipped_gable"
			s.chimney = r.randf() < 0.8
			s.porch = false

	s.floor_height = r.randf_range(2.6, 3.2)
	s.roof_pitch = r.randf_range(0.55, 0.95)          # rise/run multiplier
	s.roof_overhang = r.randf_range(0.35, 0.7)
	s.wall_material = r.randi_range(0, 4)
	s.wall_color = _pick(r, EU_WALL_COLORS)
	s.timber_color = _pick(r, EU_TIMBER_COLORS)
	s.roof_color = _pick(r, EU_ROOF_COLORS)
	s.plaster_worn = r.randf_range(0.2, 0.9)
	s.dormer_count = r.randi_range(0, 2) if s.floors >= 2 and s.subtype != "barn" else 0
	s.window_cols = clampi(int(s.width / 2.2), 1, 4)
	s.door_side = r.randi_range(0, 3)
	s.upturned_eaves = 0.0
	s.roof_tiers = 1

static func _gen_asian(s: BuildingSpec) -> void:
	var r := s.rng
	s.subtype = _pick(r, ASIAN_SUBTYPES)
	match s.subtype:
		"pagoda":
			s.width = r.randf_range(5, 8)
			s.depth = s.width * r.randf_range(0.85, 1.0)
			s.floors = r.randi_range(3, 6)
			s.roof_type = &"tiered"
			s.roof_tiers = s.floors + 1
			s.floor_height = r.randf_range(2.2, 2.8)
			s.chimney = false
			s.porch = false
		"teahouse":
			s.width = r.randf_range(4.5, 6.5)
			s.depth = r.randf_range(4.5, 6.5)
			s.floors = r.randi_range(1, 2)
			s.roof_type = &"hip"
			s.porch = true
			s.chimney = false
		"storehouse":
			s.width = r.randf_range(5, 7)
			s.depth = r.randf_range(4, 6)
			s.floors = r.randi_range(1, 2)
			s.roof_type = &"hipped_gable"
			s.chimney = false
			s.porch = false
		"merchant_house":
			s.width = r.randf_range(6, 9)
			s.depth = r.randf_range(5, 8)
			s.floors = r.randi_range(2, 3)
			s.roof_type = &"hip"
			s.porch = true
			s.chimney = false
		_: # farmhouse
			s.width = r.randf_range(6, 10)
			s.depth = r.randf_range(5, 8)
			s.floors = r.randi_range(1, 2)
			s.roof_type = &"gable"
			s.porch = r.randf() < 0.4
			s.chimney = false
			s.floor_height = r.randf_range(2.6, 3.0)

	if s.floor_height == 0.0:
		s.floor_height = r.randf_range(2.5, 3.0)
	s.roof_pitch = r.randf_range(0.5, 0.8)
	s.roof_overhang = r.randf_range(0.7, 1.2)         # generous eaves
	s.wall_color = _pick(r, AS_WALL_COLORS)
	s.timber_color = _pick(r, AS_TIMBER_COLORS)
	s.roof_color = _pick(r, AS_ROOF_COLORS)
	s.plaster_worn = r.randf_range(0.0, 0.3)
	s.dormer_count = 0
	s.window_cols = clampi(int(s.width / 2.5), 1, 3)
	s.door_side = r.randi_range(0, 3)
	s.upturned_eaves = r.randf_range(0.4, 1.0)

static func _pick(r: RandomNumberGenerator, arr: Array):
	return arr[r.randi_range(0, arr.size() - 1)]

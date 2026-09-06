extends SceneTree
## Scratch probe: the four overlapping pairs the dressing suite reported.

const CASES := [
	{"style": &"norman", "tier": &"house", "i": 0},
	{"style": &"crusader", "tier": &"house", "i": 0},
	{"style": &"bavarian", "tier": &"fortress", "i": 0},
	{"style": &"bavarian", "tier": &"fortress", "i": 2},
]

func _init() -> void:
	for case in CASES:
		for i in range(CastleSweep.COUNT):
			var spec: CastleSpec = CastleSweep.spec_at(case["style"], case["tier"], i)
			var props: Array = CastleFurnisher.dress(spec)
			_look(spec, props, "%s/%s/%d" % [String(case["style"]),
				String(case["tier"]), i])
	quit(0)


func _look(spec: CastleSpec, props: Array, label: String) -> void:
	for a in range(props.size()):
		for b in range(a + 1, props.size()):
			var pa: Dictionary = props[a]
			var pb: Dictionary = props[b]
			var ra: Rect2 = Rect2(pa["rect"]).grow(-0.06)
			var rb: Rect2 = Rect2(pb["rect"]).grow(-0.06)
			if ra.size.x <= 0.0 or rb.size.x <= 0.0 or not ra.intersects(rb):
				continue
			var ya: float = (pa["pos"] as Vector3).y
			var yb: float = (pb["pos"] as Vector3).y
			var ta: float = ya + PropCatalog.height(pa["key"]) * float(pa["scale"])
			var tb: float = yb + PropCatalog.height(pb["key"]) * float(pb["scale"])
			if minf(ta, tb) - maxf(ya, yb) <= 0.05:
				continue
			print("%s  ridge=%s tower_house=%s enclosed=%s" % [label,
				CastleGeometry.is_ridge(spec), CastleGeometry.is_tower_house(spec),
				CastleGeometry.is_enclosed(spec)])
			print("    %s yaw=%.3f scale=%.2f rect=%s" % [pa["key"], pa["yaw"],
				pa["scale"], str(pa["rect"])])
			print("    %s yaw=%.3f scale=%.2f rect=%s" % [pb["key"], pb["yaw"],
				pb["scale"], str(pb["rect"])])
			return

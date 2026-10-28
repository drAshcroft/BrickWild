extends SceneTree
## Probe: rooms and doors of shops by trade, style and size.
## args: style w l seed trade...
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	for t in a.slice(4):
		var spec := ShopSpec.new()
		spec.business = StringName(t)
		spec.style = StringName(a[0])
		spec.width = float(a[1]); spec.length = float(a[2]); spec.height = 2.8
		var p := ShopGenerator.generate(spec, int(a[3]))
		print("== ", t, " ", a[0], " rooms=", spec.room_count, " back_door=", spec.back_door)
		for i in p.room_count():
			print("  room ", i, " ", p.kind_of(i), " ", Rect2(p.rooms[i]["rect"]))
		for d in p.doors:
			print("  door ", d["a"], "->", d["b"], " ext=", d.get("exterior", false), " pos=", d["pos"], " n=", d["normal"])
	quit()

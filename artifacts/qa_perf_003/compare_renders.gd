extends SceneTree

func _init() -> void:
	for name in ["hagia_front.png", "hagia_raking.png", "florence_front.png", "florence_raking.png"]:
		var before := Image.load_from_file("res://artifacts/vis008/after/" + name)
		var after := Image.load_from_file("res://artifacts/qa_perf_003/renders/" + name)
		before.convert(Image.FORMAT_RGBA8)
		after.convert(Image.FORMAT_RGBA8)
		var old_bytes := before.get_data()
		var new_bytes := after.get_data()
		var changed := 0
		var largest := 0
		var sum := 0
		for pixel in range(before.get_width() * before.get_height()):
			var delta := 0
			for channel in range(3):
				delta = maxi(delta, absi(int(old_bytes[pixel * 4 + channel]) - int(new_bytes[pixel * 4 + channel])))
			if delta > 0:
				changed += 1
				largest = maxi(largest, delta)
				sum += delta
		print(name, " changed_pixels=", changed, " total_pixels=", before.get_width() * before.get_height(),
			" max_channel_delta=", largest, " mean_changed_delta=", float(sum) / maxf(changed, 1))
	quit()

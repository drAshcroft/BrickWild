extends "res://tools/render_shots.gd"
func _init() -> void:
 _build_stage()
 await process_frame
 var spec := HouseSpec.new()
 spec.style = &"cottage"
 spec.width = 8.0
 spec.length = 10.5
 spec.height = 2.6
 var plan := HouseGenerator.generate(spec, 21325)
 var house := HouseAssembler.build(plan, true)
 _root3d.add_child(house)
 await process_frame
 _cam.position = Vector3(9,16,12)
 _cam.look_at(Vector3.ZERO)
 for frame in 4:
  await process_frame
  await RenderingServer.frame_post_draw
 _vp.get_texture().get_image().save_png("res://artifacts/p1p2_furnishing/family_dining.png")
 print("family dining render complete")
 quit()

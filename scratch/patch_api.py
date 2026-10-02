import io
p = "src/api/brick_wild.gd"
s = io.open(p, encoding="utf-8").read()

old = """## Create a fresh scene instance. Houses and temples include their prop models;
## churches and castles receive the same material treatment as the Studio.
## When `with_collision` is true, only the generated architectural shell gets
## trimesh collision; furniture and dressing remain visual details."""
new = """## Create a fresh scene instance. Every family includes its prop models: a
## house and a hotel their furniture, a temple its braziers and cages, a church
## its pews and candelabra, a castle its trestles, banners and courtyard.
## When `with_collision` is true, only the generated architectural shell gets
## trimesh collision; furniture and dressing remain visual details."""
assert s.count(old) == 1
s = s.replace(old, new)

old2 = """	elif building.spec is TempleSpec:
		root = TempleAssembler.build(building.spec as TempleSpec, cutaway)
	else:
		var mesh: ArrayMesh = build_mesh(building)
		if mesh == null:
			return null
		var instance := MeshInstance3D.new()
		instance.name = building.name()
		instance.mesh = mesh
		var colors := [building.spec.get("stone_color"), building.spec.get("trim_color"),
			building.spec.get("roof_color"), Color("1a1c20")]
		for surface in range(mesh.get_surface_count()):
			var material := StandardMaterial3D.new()
			material.albedo_color = colors[surface]
			material.roughness = 0.9
			instance.set_surface_override_material(surface, material)
		root = instance
"""
new2 = """	elif building.spec is TempleSpec:
		root = TempleAssembler.build(building.spec as TempleSpec, cutaway)
	elif building.spec is ChurchSpec:
		root = ChurchAssembler.build(building.spec as ChurchSpec, cutaway)
	elif building.spec is CastleSpec:
		root = CastleAssembler.build(building.spec as CastleSpec, cutaway)
	else:
		var mesh: ArrayMesh = build_mesh(building)
		if mesh == null:
			return null
		var instance := MeshInstance3D.new()
		instance.name = building.name()
		instance.mesh = mesh
		var colors := [building.spec.get("stone_color"), building.spec.get("trim_color"),
			building.spec.get("roof_color"), Color("1a1c20")]
		for surface in range(mesh.get_surface_count()):
			var material := StandardMaterial3D.new()
			material.albedo_color = colors[surface]
			material.roughness = 0.9
			instance.set_surface_override_material(surface, material)
		root = instance
"""
assert s.count(old2) == 1
s = s.replace(old2, new2)
io.open(p, "w", encoding="utf-8", newline="\n").write(s)
print("patched")

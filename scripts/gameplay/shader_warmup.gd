extends RefCounted

# Compatibility compiles a material when it is first drawn, not when loaded.
# Render both ordinary and automatically instanced geometry behind the load fade.
static func prepare(world: Node3D) -> void:
	var materials: Dictionary = {}
	for node: MeshInstance3D in world.find_children("*", "MeshInstance3D", true, false):
		if not node.mesh: continue
		for surface in node.mesh.get_surface_count():
			var material := node.get_active_material(surface)
			if material: materials[material.get_instance_id()] = material
		if node.material_overlay:
			materials[node.material_overlay.get_instance_id()] = node.material_overlay
	for shader in [preload("res://materials/focus_outline.gdshader"),preload("res://materials/focus_halo.gdshader")]:
		var rim := ShaderMaterial.new()
		rim.shader = shader
		materials[rim.get_instance_id()] = rim
	var viewport := SubViewport.new()
	viewport.size = Vector2i(128,128)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	world.add_child(viewport)
	var scene := Node3D.new()
	viewport.add_child(scene)
	var environment := WorldEnvironment.new()
	environment.environment = world.get_world_3d().environment
	scene.add_child(environment)
	var count := materials.size()
	var columns := ceili(sqrt(float(count)))
	var extent := float(columns)*3.0
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = extent+4.0
	camera.position = Vector3(extent/2.0,extent/2.0,20)
	scene.add_child(camera)
	camera.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-25,-25,0)
	sun.shadow_enabled = SettingsStore.graphics>0
	scene.add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = camera.position
	fill.omni_range = extent*2.0
	scene.add_child(fill)
	var box := BoxMesh.new()
	var sphere := SphereMesh.new()
	sphere.radial_segments = 8
	sphere.rings = 4
	var index := 0
	for material: Material in materials.values():
		var origin := Vector3((index%columns)*3.0, (index/columns)*3.0, 0)
		for sample in 3:
			var mesh := MeshInstance3D.new()
			mesh.mesh = sphere if sample==0 else box
			mesh.material_override = material
			mesh.position = origin+Vector3((sample-1)*0.85,0,0)
			mesh.scale = Vector3.ONE*0.65
			scene.add_child(mesh)
		index += 1
		if index%12==0:
			SceneManager.loading_status("Preparing the facility visuals...",65+30*float(index)/maxi(count,1))
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	viewport.queue_free()
	await world.get_tree().process_frame

extends SceneTree
func _initialize() -> void:
	call_deferred("inspect")
func inspect() -> void:
	for path in ["rocket/stages/first_stage_body", "rocket/stages/second_stage_body", "rocket/stages/interstage", "rocket/stages/booster_medium", "rocket/fairings/fairing_closed", "rocket/engines/merlin_1d", "rocket/stages/rocket_marking"]:
		var model := load("res://assets/models/%s.glb" % path).instantiate() as Node3D
		root.add_child(model)
		var bounds := AABB()
		var first := true
		for mesh in model.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = model.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
		print(path, " ", bounds)
		for socket in model.find_children("SOCKET*", "Node3D", true, false):
			print("  ", socket.name, " ", socket.global_position)
		model.free()
	quit()

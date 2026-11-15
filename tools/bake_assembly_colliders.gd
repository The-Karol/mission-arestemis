extends SceneTree

func _initialize() -> void:
	call_deferred("bake")

func bake() -> void:
	var shapes := Resource.new()
	for path in ["rocket/stages/first_stage_body","rocket/engines/merlin_1d","rocket/stages/interstage","rocket/stages/second_stage_body","rocket/fairings/fairing_closed"]:
		var model := (load("res://assets/models/"+path+".glb") as PackedScene).instantiate() as Node3D
		root.add_child(model)
		var triangles := PackedVector3Array()
		for part: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
			triangles.append_array((model.global_transform.affine_inverse()*part.global_transform)*part.mesh.get_faces())
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = triangles
		var shell := ArrayMesh.new()
		shell.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		shapes.set_meta(path.get_file(),shell.create_convex_shape(true,false))
		model.free()
	quit(ResourceSaver.save(shapes,"res://data/assembly_colliders.tres"))

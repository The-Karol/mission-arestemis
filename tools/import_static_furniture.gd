@tool
extends EditorScenePostImport

# Batch the rigid opaque pieces of each furnishing during import, before the
# scene is ever shipped to the browser. Keep named work surfaces and glass.
func _post_import(scene: Node) -> Object:
	if not scene.find_children("*", "AnimationPlayer", true, false).is_empty():
		return scene
	if get_source_file().ends_with("/double_door.glb"):
		for name_leaf in ["DoorLeft","DoorRight"]:
			_batch(scene.find_child(name_leaf,true,false))
	else:
		_batch(scene)
	return scene

func _batch(scene: Node) -> void:
	var groups := {}
	for item in scene.find_children("*", "MeshInstance3D", true, false):
		var part := item as MeshInstance3D
		if str(part.name).begins_with("LABEL_"):
			part.free()
			continue
		if not _can_merge(part):
			continue
		var transform_in_asset := part.transform
		var parent := part.get_parent()
		while parent != scene:
			if parent is Node3D: transform_in_asset = parent.transform * transform_in_asset
			parent = parent.get_parent()
		if transform_in_asset.basis.determinant() <= 0: continue
		for surface in part.mesh.get_surface_count():
			var mat := part.get_active_material(surface)
			if not groups.has(mat): groups[mat] = {}
			# The attribute mask distinguishes e.g. textured and vertex-painted geometry.
			var format_bits: int = part.mesh.surface_get_format(surface)
			if not groups[mat].has(format_bits):
				var batch := SurfaceTool.new()
				batch.begin(Mesh.PRIMITIVE_TRIANGLES)
				batch.set_material(mat)
				groups[mat][format_bits] = batch
			var batch: SurfaceTool = groups[mat][format_bits]
			batch.append_from(part.mesh, surface, transform_in_asset)
		part.free()
	if groups.is_empty(): return
	var baked := ArrayMesh.new()
	for mat in groups:
		for batch: SurfaceTool in groups[mat].values():
			batch.commit(baked)
	var combined := MeshInstance3D.new()
	combined.name = "RigidFurnishing"
	combined.mesh = baked
	scene.add_child(combined)
	combined.owner = scene.owner if scene.owner else scene

func _can_merge(part: MeshInstance3D) -> bool:
	if not part.visible or part.get_child_count() > 0 or part.skin != null or not part.mesh is ArrayMesh or part.mesh.get_blend_shape_count() > 0:
		return false
	var title := str(part.name).to_lower()
	for retained in ["desk_top", "lab_top", "bed", "tray_surface", "display_screen"]:
		if title.contains(retained): return false
	for index in part.mesh.get_surface_count():
		var mat := part.get_active_material(index) as BaseMaterial3D
		if mat == null or mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or part.mesh.surface_get_primitive_type(index) != Mesh.PRIMITIVE_TRIANGLES:
			return false
	return true

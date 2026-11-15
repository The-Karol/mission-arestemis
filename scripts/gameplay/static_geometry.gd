class_name SpaceStaticGeometry
extends RefCounted

# Preserve physics bodies and named replacement anchors, but combine repeated
# box visuals by material and spatial cell. Small cells retain light selection
# and frustum culling; the web renderer submits far fewer individual draw calls.
static func combine(world: Node3D, roots: Array) -> void:
	var batches: Dictionary = {}
	var count := 0
	for source in roots:
		for candidate in source.find_children("*", "MeshInstance3D", true, false):
			var instance := candidate as MeshInstance3D
			if not instance.mesh is BoxMesh or instance.layers == 0 or not instance.is_visible_in_tree():
				continue
			var material: Material = instance.material_override
			if material == null:
				continue
			var at := instance.global_position
			var key := "%d:%d:%d:%d:%d:%d" % [material.get_instance_id(), instance.layers, instance.cast_shadow, floori(at.x / 16), floori(at.y / 4), floori(at.z / 16)]
			if not batches.has(key):
				var surface := SurfaceTool.new()
				surface.begin(Mesh.PRIMITIVE_TRIANGLES)
				batches[key] = {"surface": surface, "material": material, "layers": instance.layers, "shadows": instance.cast_shadow}
			var builder: SurfaceTool = batches[key].surface
			builder.append_from(instance.mesh, 0, instance.global_transform)
			# Keep attached lamp lenses, supports and tread markings visible.
			instance.layers = 0
			count += 1
	var container := Node3D.new()
	container.name = "StaticVisualBatches"
	world.add_child(container)
	for key in batches:
		var instance := MeshInstance3D.new()
		instance.mesh = batches[key].surface.commit()
		instance.layers = batches[key].layers
		instance.cast_shadow = batches[key].shadows
		instance.material_override = batches[key].material
		container.add_child(instance)
	world.set_meta("static_box_count", count)
	world.set_meta("static_batch_count", batches.size())

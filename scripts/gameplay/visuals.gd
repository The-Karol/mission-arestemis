class_name SpaceVisuals
extends RefCounted

static var _materials: Dictionary = {}
static var _prefab_layout: Dictionary = {}

static func material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var key := "%s:%s" % [color.to_html(), unshaded]
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.78
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_materials[key] = mat
	return mat

static func box(parent: Node3D, title: String, dimensions: Vector3, at: Vector3, color: Color, collision: bool = false, unshaded: bool = false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = title
	var shape := BoxMesh.new()
	shape.size = dimensions
	mesh.mesh = shape
	mesh.material_override = material(color, unshaded)
	mesh.position = at
	parent.add_child(mesh)
	if collision:
		var body := StaticBody3D.new()
		var collider := CollisionShape3D.new()
		var solid := BoxShape3D.new()
		solid.size = dimensions
		collider.shape = solid
		body.position = at
		parent.add_child(body)
		body.add_child(collider)
	return mesh

static func label(parent: Node3D, text: String, at: Vector3, color: Color = Color(0.86, 0.91, 0.89), size: int = 30) -> Label3D:
	var sign := Label3D.new()
	sign.font = SpaceUI.FONT
	sign.text = text
	sign.position = at
	sign.font_size = size
	sign.pixel_size = 0.006
	sign.modulate = color
	sign.outline_size = 5
	sign.outline_modulate = Color(0.025, 0.04, 0.045)
	sign.no_depth_test = false
	parent.add_child(sign)
	return sign

static func model(parent: Node3D, path: String, at: Vector3, yaw: float = 0.0, width: float = 0.0, solid: bool = true) -> Node3D:
	var scene := load("res://assets/models/%s.glb" % path) as PackedScene
	if not scene:
		return null
	var holder := Node3D.new()
	holder.name = path.get_file().to_pascal_case()
	parent.add_child(holder)
	var instance := scene.instantiate() as Node3D
	holder.add_child(instance)
	for label in instance.find_children("LABEL_*","MeshInstance3D",true,false):label.free()
	if not _prefab_layout.has(path):
		var screens := {}
		for mesh: MeshInstance3D in instance.find_children("*","MeshInstance3D",true,false):
			for surface in mesh.mesh.get_surface_count():
				var mat := mesh.get_active_material(surface)
				if mat and str(mat.resource_name).to_lower().contains("screen"):
					var key := instance.get_path_to(mesh)
					if not screens.has(key): screens[key] = PackedInt32Array()
					screens[key].append(surface)
		_prefab_layout[path] = {"bounds": bounds_of(instance), "screens": screens}
	var layout: Dictionary = _prefab_layout[path]
	for key: NodePath in layout.screens:
		var mesh := instance.get_node(key) as MeshInstance3D
		for surface in layout.screens[key]:
			mesh.set_surface_override_material(surface,preload("res://materials/terminal_screen.tres"))
	var bounds: AABB = layout.bounds
	var factor := width / bounds.size.x if width > 0.0 and bounds.size.x > 0.001 else 1.0
	instance.scale *= factor
	instance.position -= Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * factor
	if solid:
		var body := StaticBody3D.new()
		body.name = "SimpleCollision"
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = bounds.size * factor
		shape.shape = box_shape
		body.position.y = box_shape.size.y * 0.5
		holder.add_child(body)
		body.add_child(shape)
	holder.position = at
	holder.rotation.y = yaw
	holder.set_meta("asset_path",path)
	holder.set_meta("model_bounds",AABB(Vector3(-bounds.size.x*factor*0.5,0,-bounds.size.z*factor*0.5),bounds.size*factor))
	return holder

static func surface_height(holder: Node3D, keyword: String = "top") -> float:
	var height := 0.0
	for candidate in holder.find_children("*", "MeshInstance3D", true, false):
		if str(candidate.name).to_lower().contains(keyword):
			var box: AABB = holder.global_transform.affine_inverse()*candidate.global_transform*candidate.get_aabb()
			height = maxf(height,box.end.y)
	return height if height > 0 else bounds_of(holder).end.y

static func bounds_of(node: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	var to_local_space := node.global_transform.affine_inverse()
	for candidate in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := candidate as MeshInstance3D
		var local_box: AABB = to_local_space * mesh.global_transform * mesh.get_aabb()
		bounds = local_box if first else bounds.merge(local_box)
		first = false
	return bounds

static func interaction_shape(area: Area3D, dimensions: Vector3, at: Vector3 = Vector3.ZERO) -> void:
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collider.shape = shape
	collider.position = at
	area.add_child(collider)

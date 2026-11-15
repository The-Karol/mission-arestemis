extends Node3D
# An off-axis frustum through the real mirror corners gives a planar reflection
# even when the player stands to one side. The camera clips at the glass.
var viewport: SubViewport
var reflection: Camera3D
var plane: MeshInstance3D
var width: float
var height: float
var elapsed := 0.0

func install(original: MeshInstance3D) -> void:
	var box: AABB = original.global_transform * original.get_aabb()
	global_position = box.get_center() - Vector3(0,0,box.size.z*0.5+0.004)
	width = box.size.x
	height = box.size.y
	original.hide()
	viewport = SubViewport.new()
	viewport.size = Vector2i([128,240,360][SettingsStore.graphics], roundi([128,240,360][SettingsStore.graphics]*height/width))
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.positional_shadow_atlas_size = 0
	viewport.mesh_lod_threshold = 8.0
	viewport.world_3d = get_world_3d()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	reflection = Camera3D.new()
	reflection.cull_mask = (1<<20)-1 ^ (1<<18)
	viewport.add_child(reflection)
	plane = MeshInstance3D.new()
	var rect := QuadMesh.new()
	rect.size = Vector2(width,height)
	plane.mesh = rect
	plane.rotation.y = PI
	plane.layers = 1<<18
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var glass := ShaderMaterial.new()
	glass.shader = preload("res://materials/lift_mirror.gdshader")
	glass.set_shader_parameter("reflection",viewport.get_texture())
	plane.material_override = glass
	add_child(plane)

func _process(delta: float) -> void:
	if not reflection: return
	var resolution:int=[128,240,360][SettingsStore.graphics]
	if viewport.size.x!=resolution:viewport.size=Vector2i(resolution,roundi(resolution*height/width))
	var eye := get_viewport().get_camera_3d()
	if not eye: return
	var relative := eye.global_position-global_position
	var depth := -relative.z
	if depth < 0.06 or depth>6.5 or eye.is_position_behind(global_position): return
	elapsed += delta
	if elapsed < [0.25,0.10,0.066][SettingsStore.graphics]: return
	elapsed = 0
	reflection.global_position = global_position+Vector3(relative.x,relative.y,depth)
	reflection.set_frustum(height,Vector2(-relative.x,-relative.y),depth+0.001,24)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

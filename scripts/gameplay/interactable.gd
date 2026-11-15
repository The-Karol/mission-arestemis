class_name SpaceInteractable
extends Area3D

@export var interaction_text := "Interact"
@export var enabled := true
var _outline_meshes: Array[MeshInstance3D] = []
var highlight_root: Node3D

static var _outline_materials := {}
var _original_overlays: Array[Material] = []

func set_focused(value: bool) -> void:
	if value and _outline_meshes.is_empty():
		var source: Node3D=highlight_root if is_instance_valid(highlight_root) else self
		for mesh: MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):
			_outline_meshes.append(mesh)
			_original_overlays.append(mesh.material_overlay)
	for i in _outline_meshes.size():
		var mesh:=_outline_meshes[i]
		if not is_instance_valid(mesh):continue
		if not value:
			mesh.material_overlay=_original_overlays[i]
			continue
		var scale_key:=maxi(1,roundi(mesh.global_basis.get_scale().x*1000))
		if not _outline_materials.has(scale_key):
			var rim:=ShaderMaterial.new()
			rim.shader=preload("res://materials/focus_outline.gdshader")
			rim.set_shader_parameter("thickness",9.0/scale_key)
			var halo:=ShaderMaterial.new()
			halo.shader=preload("res://materials/focus_halo.gdshader")
			halo.set_shader_parameter("thickness",18.0/scale_key)
			rim.next_pass=halo
			_outline_materials[scale_key]=rim
		mesh.material_overlay=_outline_materials[scale_key]

func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	monitoring = false

func get_interaction_text(_player: Node) -> String:
	return interaction_text

func can_interact(_player: Node) -> bool:
	return enabled and is_visible_in_tree()

func interact(_player: Node) -> void:
	pass

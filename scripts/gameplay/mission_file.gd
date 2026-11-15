extends SpaceInteractable

var mission: Dictionary = {}
var title_label: Label3D
var closed_model: Node3D
var open_model: Node3D
var _hover_tween: Tween
var _opened := false
var cover_hinge: Node3D

func _ready() -> void:
	super._ready()
	closed_model = SpaceVisuals.model(self, "props/mission_folder_closed", Vector3.ZERO, 0.0, 0.48, false)
	open_model = SpaceVisuals.model(self, "props/mission_folder_open", Vector3.ZERO, 0.0, 0.972, false)
	open_model.hide()
	highlight_root = closed_model
	cover_hinge = Node3D.new()
	closed_model.add_child(cover_hinge)
	cover_hinge.position = Vector3(-0.24,0.02,0)
	for part in closed_model.find_children("*","MeshInstance3D",true,false):
		if str(part.name) in ["folder_front","label_area","metal_corner","metal_corner_001","red_band"]:
			part.reparent(cover_hinge)
	var stamp := MeshInstance3D.new()
	var plate := QuadMesh.new()
	var design:=preload("res://scripts/gameplay/design_data.gd")
	var image: Texture2D=design.texture(design.BUSES[mission.spacecraft_type][2])
	plate.size=Vector2(0.19,0.13)*image.get_size()/maxf(image.get_size().x,image.get_size().y)
	stamp.mesh=plate
	stamp.position=Vector3(0.24,0.039,0.14)
	stamp.rotation.x=-PI/2
	var print_ink:=StandardMaterial3D.new()
	print_ink.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	print_ink.albedo_color=Color("354035")
	print_ink.albedo_texture=image
	stamp.material_override=print_ink
	cover_hinge.add_child(stamp)
	SpaceVisuals.interaction_shape(self, Vector3(0.43, 0.12, 0.52), Vector3(0, 0.045, 0))
	title_label = SpaceVisuals.label(self, mission.get("short_title", "MISSION"), Vector3(0, 0.04, 0.0), Color(0.11, 0.20, 0.21), 18)
	title_label.rotation.x = -PI / 2.0
	title_label.outline_size = 0
	title_label.pixel_size = 0.0016
	GameState.files_changed.connect(_update_visibility)
	_update_visibility()

func _update_visibility() -> void:
	visible = GameState.files_available

func can_interact(player: Node) -> bool:
	return super.can_interact(player) and GameState.files_available

func get_interaction_text(_player: Node) -> String:
	return "Read Mission File  /  " + str(mission.get("title", ""))

func interact(player: Node) -> void:
	player.ui.open_mission_table(get_parent())

func hover(active: bool) -> void:
	if _opened: return
	if is_instance_valid(_hover_tween): _hover_tween.kill()
	_hover_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self,"scale",Vector3.ONE*(1.12 if active else 1.0),0.18)

func unfold() -> void:
	GameAudio.play_effect("paper")
	_opened = true
	if is_instance_valid(_hover_tween): _hover_tween.kill()
	scale = Vector3.ONE
	title_label.hide()
	var tween := create_tween()
	tween.tween_property(cover_hinge,"rotation:z",PI,0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func():
		closed_model.hide()
		open_model.show())
	await tween.finished

func fold() -> void:
	_opened = false
	closed_model.scale = Vector3.ONE
	cover_hinge.rotation.z = 0
	closed_model.show()
	open_model.hide()
	title_label.show()
	scale = Vector3.ONE

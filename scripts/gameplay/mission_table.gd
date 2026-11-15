extends SpaceInteractable

var folders: Array[Node3D] = []
var top := 1.04

func _ready() -> void:
	super._ready()
	var desk := SpaceVisuals.model(self, "environment/mission_table", Vector3.ZERO, 0.0, 2.8)
	top = SpaceVisuals.surface_height(desk,"tray_surface") + 0.003
	SpaceVisuals.interaction_shape(self,Vector3(2.8,0.22,1.35),Vector3(0,top,0))
	add_to_group("mission_tables")
	for index in range(3):
		var file := preload("res://scenes/missions/mission_file.tscn").instantiate()
		file.name = "MissionFile%d" % (index + 1)
		file.mission = GameState.offered_missions[index]
		file.position = Vector3((index - 1) * 0.79, top, -0.02)
		add_child(file)
		folders.append(file)

func can_interact(player: Node) -> bool:
	return super.can_interact(player) and GameState.files_available

func get_interaction_text(_player: Node) -> String:
	return "Examine mission folders"

func interact(player: Node) -> void:
	player.ui.open_mission_table(self)

func camera_pose() -> Transform3D:
	var pose := Transform3D(Basis.from_euler(Vector3(-PI/2,0,0)),to_global(Vector3(0,top+1.9,0)))
	return pose

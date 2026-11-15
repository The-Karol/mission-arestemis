extends CharacterBody3D

signal arrived

@export var speaker_name := "Engineer"
@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var visual: Node3D = $VisualRoot
var player: CharacterBody3D
var active := false
var state := "greeting"
var waiting := false
var destination := Vector3(-31.5, 4, 1.8)
var _introduced := false
var _arrival_dialogue := false
var pose := preload("res://scripts/gameplay/crew_pose.gd").new()
var animation: AnimationPlayer

func _ready() -> void:
	collision_layer = 2
	collision_mask = 9
	floor_snap_length = 0.4
	_connect_model()
	var interaction := SpaceInteractable.new()
	interaction.set_script(preload("res://scripts/gameplay/engineer_interaction.gd"))
	interaction.name = "InteractionArea"
	add_child(interaction)
	SpaceVisuals.interaction_shape(interaction, Vector3(0.8, 1.95, 0.8), Vector3(0, 0.98, 0))
	GameState.mission_changed.connect(_on_mission_selected)

func _connect_model() -> void:
	var model := $VisualRoot/Model as Node3D
	var bounds := SpaceVisuals.bounds_of(model)
	var factor := 1.74 / bounds.size.y
	model.scale = Vector3.ONE * factor
	model.position.y = -bounds.position.y * factor
	animation = model.find_child("AnimationPlayer",true,false) as AnimationPlayer
	for clip in ["Idle","Walk"]:
		animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	animation.play("Idle")
	model.find_children("*","Skeleton3D",true,false)[0].add_child(pose)
	add_to_group("guide")

func begin() -> void:
	active = true
	visible = true

	GameState.set_objective("Meet the Engineer", "Walk out of the lift. Your guide is waiting ahead.", global_position)

func talk() -> void:
	if not active or not is_instance_valid(player) or player.ui.is_open():
		return
	if not _introduced:
		_introduced = true
		player.ui.show_dialogue(speaker_name, [
			"Welcome to Hyperion. I'm your mission engineer. I'll help you prepare your first space mission.",
			"We need to choose a mission, assemble its spacecraft and build a launcher. Our computers exchange designs on a physical data cartridge.",
			"Your blank cartridge was left on a desk in Mission Planning, in Launch Control on Level 01. Cross the enclosed passage to reach it.",
			"Find the cartridge and bring it back to me here. Then we'll go upstairs and choose your mission."
		], _finish_introduction)
	elif state=="waiting_cartridge":
		if GameState.starter_found:
			player.ui.show_dialogue(speaker_name,["You found it. Keep the cartridge with you; every workstation needs it.","Now follow me to the Project Office upstairs. Three mission proposals are waiting."],_start_guiding)
		else:
			player.ui.show_dialogue(speaker_name,["The cartridge is on a desk in Mission Planning, Launch Control Level 01. Cross the enclosed passage and follow the blue guidance line.","Bring it back here before we choose a mission."])

	elif state == "guiding":
		player.ui.show_dialogue(speaker_name, ["Follow me to the Project Office upstairs. Take the marked stairs in the assembly hall, then turn toward the west wing."])
	elif GameState.selected_mission.is_empty():
		player.ui.show_dialogue(speaker_name, ["Read the three proposals on the table and choose one. The mission brief tells you which kind of spacecraft you'll need."])
	else:
		player.ui.show_dialogue(speaker_name, ["Your current task: " + GameState.objective + ".", "The Spacecraft Design computer is in KKA on Level 02. Carry your data cartridge between stations; the design travels with the cartridge.", "A rocket carries its own oxidizer. Its engine can work in the vacuum of space, where there is no air to breathe."])

func _finish_introduction() -> void:
	GameState.intro_briefed=true
	if GameState.starter_found:
		_start_guiding()
	else:
		state="waiting_cartridge"
		GameState.set_objective("Find your data cartridge","CUZ  /  Level 01  /  Mission Planning. Check the desk, then return to the Engineer.",GameState.starter_location)

func _start_guiding() -> void:
	state = "guiding"
	agent.target_position = destination
	GameState.set_objective("Follow the Engineer", "Project Office  /  Level 02  /  Your guide waits if you fall behind.", destination)

func _physics_process(delta: float) -> void:
	if not active or not is_instance_valid(player):
		return
	if (not _introduced or state=="waiting_cartridge" and GameState.starter_found) and player.controls_enabled and global_position.distance_to(player.global_position) < 5.2:
		talk()
	var moving := false
	if state == "guiding" and player.controls_enabled:
		var distance := global_position.distance_to(player.global_position)
		if distance > 8.0:
			waiting = true
		elif distance < 5.0:
			waiting = false
		if not waiting and NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()) > 0:
			if global_position.distance_to(destination) < 0.8:
				state = "at_office"
				arrived.emit()
			elif not agent.is_navigation_finished():
				var next := agent.get_next_path_position()
				var direction := next - global_position
				direction.y = 0
				if direction.length() > 0.06:
					direction = direction.normalized()
					velocity.x = direction.x * 2.15
					velocity.z = direction.z * 2.15
					visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), delta * 8)
					moving = true
	if not moving:
		velocity.x = 0
		velocity.z = 0
		var direction := player.global_position - global_position
		if direction.length() > 0.5 and direction.length()<5.5 and absf(direction.y)<1.2:
			var sight:=PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*1.48,player.global_position+Vector3.UP*1.48,1)
			if get_world_3d().direct_space_state.intersect_ray(sight).is_empty():
				visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), delta * 3)
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0
	move_and_slide()
	var clip := "Walk" if moving else "Idle"
	pose.stride = move_toward(pose.stride,1.0 if moving else 0.0,delta*4)
	pose.speaking = player.mode == "dialogue" and player.global_position.distance_to(global_position)<5.5 and player.ui.modal != null and player.ui.modal.get("speaker_name") == speaker_name and player.ui.modal.line.visible_characters >= 0 and player.ui.modal.line.visible_characters < player.ui.modal.line.get_total_character_count()
	pose.phase = animation.current_animation_position / maxf(0.01,animation.current_animation_length)*TAU
	if animation.current_animation != clip: animation.play(clip,0.2)
	if state == "at_office" and not _arrival_dialogue and player.controls_enabled and global_position.distance_to(player.global_position) < 5.0:
		_arrival_dialogue = true
		player.ui.show_dialogue(speaker_name, ["Here are the three mission proposals. Read each file and choose the one you want to lead.", "Once you choose, we'll start with the spacecraft. The brief will guide your first design."], func() -> void:
			GameState.files_available = true
			GameState.set_objective("Choose a mission", "Read the three files on the Project Office table. Select one and confirm.", Vector3(-32, 4, 0)))

func _on_mission_selected() -> void:
	if GameState.selected_mission.is_empty() or not active or not is_instance_valid(player):
		return
	if player.ui.is_open(): await player.ui.modal_closed
	player.ui.show_dialogue(speaker_name, ["Good choice. Start with your " + str(GameState.mission().spacecraft_type).to_lower() + " at the Spacecraft Design computer in KKA.", "Our stations exchange designs through physical data cartridges. Save your design, take the cartridge from the reader and carry it to the next station. You can carry one at a time."])

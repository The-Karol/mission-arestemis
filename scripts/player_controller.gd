extends CharacterBody3D

signal pause_requested
signal message_requested(text: String)

@export var walk_speed := 4.5
@export var run_speed := 7.0
@export var ground_acceleration := 18.0
@export var ground_deceleration := 22.0
@export var air_acceleration := 5.0
@export var jump_velocity := 5.2
@export var mouse_sensitivity := 0.0025
@export var head_bob_enabled := false

const COYOTE_TIME := 0.12
const JUMP_BUFFER_TIME := 0.14
const LOOK_LIMIT := deg_to_rad(80.0)

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var debug_label: Label = $HUD/DebugLabel
@onready var astronaut: Node3D = $Astronaut
@onready var astronaut_animation: AnimationPlayer = astronaut.find_child("AnimationPlayer", true, false) as AnimationPlayer
@onready var interaction_ray: RayCast3D = $Head/Camera3D/InteractionRay
@onready var carry_anchor: Marker3D = $Head/Camera3D/PlayerCarryAnchor

var carried_item: Node3D
var ui: CanvasLayer
var mode := "arrival"
var focused_interactable: SpaceInteractable
var _show_mission := false
var _show_cartridge := false

var controls_enabled := false
var _pitch := 0.0
var _coyote_remaining := 0.0
var _jump_buffer_remaining := -1.0
var _show_fps := false
var _show_position := false
var _mouse_delta := Vector2.ZERO
var _look_guard_frames := 0
var _last_safe_position := Vector3(-32, 0.1, 16)
var _mouse_dragging := false
var _edge_look := Vector2.ZERO
var suit_pose := preload("res://scripts/gameplay/crew_pose.gd").new()
var _step_distance := 0.0

func update_eye_offset() -> void:
	camera.position.z = -0.30*smoothstep(0.08,1.34,-_pitch)

var turn_filter := ColorRect.new()
var shutter := ShaderMaterial.new()

func _ready() -> void:
	var fx_layer := CanvasLayer.new()
	fx_layer.layer=-1
	add_child(fx_layer)
	fx_layer.add_child(turn_filter)
	SpaceUI.fill(turn_filter)
	turn_filter.mouse_filter=Control.MOUSE_FILTER_IGNORE
	shutter.shader=preload("res://materials/turn_blur.gdshader")
	turn_filter.material=shutter
	turn_filter.hide()
	mouse_sensitivity = SettingsStore.mouse_sensitivity
	debug_label.visible = false
	add_to_group("player")
	Input.use_accumulated_input = false
	get_viewport().size_changed.connect(_reset_mouse_motion)
	# The helmet remains available for shadows and external cameras, but cannot
	# cover the first-person camera inside it.
	var helmet := astronaut.find_child("AstronautHelmet", true, false) as GeometryInstance3D
	if helmet:
		helmet.layers = 2
	suit_pose.role = "pilot"
	astronaut.find_children("*","Skeleton3D",true,false)[0].add_child(suit_pose)
	if astronaut_animation:
		for animation_name in ["Idle", "Walk"]:
			if astronaut_animation.has_animation(animation_name):
				astronaut_animation.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
		astronaut_animation.play("Idle")

func _browser_has_lock() -> bool:
	return bool(JavaScriptBridge.eval("document.pointerLockElement === document.querySelector('canvas')"))

func request_walk_capture() -> void:
	_reset_mouse_motion()
	if not OS.has_feature("web"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if _browser_has_lock(): return
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	# Escape can suppress a fresh lock. Keep the game's hidden-cursor look mode
	# throughout the request, including a rejected Promise in Chromium.
	JavaScriptBridge.eval("""(() => {
		const canvas = document.querySelector('canvas');
		if (!canvas || !canvas.requestPointerLock || !navigator.userActivation?.isActive) return;
		try { canvas.requestPointerLock()?.catch(() => { canvas.style.cursor = 'none'; }); }
		catch (_) { canvas.style.cursor = 'none'; }
	})()""")

func set_controls_enabled(enabled: bool) -> void:
	_reset_mouse_motion()
	_mouse_dragging = false
	controls_enabled = enabled
	mode = "walking" if enabled else "blocked"
	if enabled:
		if not OS.has_feature("web"):
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif not _browser_has_lock():
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	else:
		if OS.has_feature("web") and _browser_has_lock():
			JavaScriptBridge.eval("document.exitPointerLock()")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not enabled:
		velocity = Vector3.ZERO
	$HUD/Crosshair.visible = enabled
	_jump_buffer_remaining = -1.0
	if not enabled and is_instance_valid(ui):
		ui.set_prompt("")

func enter_mode(next_mode: String) -> void:
	set_controls_enabled(false)
	mode = next_mode

func notify(text: String) -> void:
	message_requested.emit(text)

func take_item(item: Node3D) -> bool:
	if is_instance_valid(carried_item):
		notify("You are already carrying an item.")
		return false
	carried_item = item
	item.attach_to_hand(self)
	return true

func drop_carried_item() -> bool:
	if not is_instance_valid(carried_item):
		return false
	# A forward obstruction clips the drop point, then a downward world-only ray
	# finds the supporting floor or desk, including the upper floor.
	var origin := camera.global_position
	var forward := -head.global_basis.z
	var reach := origin + forward * 1.15
	var space := get_world_3d().direct_space_state
	var wall_query := PhysicsRayQueryParameters3D.create(origin, reach, 1)
	var wall := space.intersect_ray(wall_query)
	if not wall.is_empty():
		reach = wall.position + wall.normal * 0.22
	var floor_query := PhysicsRayQueryParameters3D.create(reach, reach + Vector3.DOWN * 3.0, 1)
	var hit := space.intersect_ray(floor_query)
	if hit.is_empty() or hit.normal.y < 0.65:
		notify("No safe surface here. Face a floor or a desk.")
		return false
	var item := carried_item
	carried_item = null
	item.place_in_world(hit.position + Vector3.UP * 0.03, get_tree().current_scene)
	notify("Cartridge placed. Look at it and press E to take it.")
	return true

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_mission"):
		_show_mission = not _show_mission
		return
	if event.is_action_pressed("debug_cartridge"):
		_show_cartridge = not _show_cartridge
		return
	if event.is_action_pressed("debug_fps"):
		_show_fps = not _show_fps
		_update_debug_text()
		return
	if event.is_action_pressed("interact") and controls_enabled:
		_update_interaction()
		if is_instance_valid(focused_interactable) and focused_interactable.can_interact(self):
			focused_interactable.interact(self)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("drop_item") and controls_enabled:
		drop_carried_item()
		get_viewport().set_input_as_handled()
		return
	var walk_gesture: bool = event is InputEventMouseButton and event.pressed
	if OS.has_feature("web") and event is InputEventKey and event.pressed and not event.echo:
		walk_gesture = event.physical_keycode in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_SHIFT,KEY_SPACE]
	if walk_gesture and controls_enabled and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		request_walk_capture()
	if event.is_action_pressed("debug_position"):
		_show_position = not _show_position
		_update_debug_text()
		return
	if event.is_action_pressed("ui_cancel") and controls_enabled:
		set_controls_enabled(false)
		pause_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("jump") and controls_enabled:
		_jump_buffer_remaining = JUMP_BUFFER_TIME

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_dragging = event.pressed and controls_enabled
	if event is InputEventMouseMotion and controls_enabled and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or _mouse_dragging or OS.has_feature("web")):
		_queue_mouse_motion(event)
		if OS.has_feature("web") and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			# Keep turning at the canvas boundary if the browser declined pointer lock after Escape.
			var uv: Vector2 = event.position/get_viewport().get_visible_rect().size
			var axis := uv*2.0-Vector2.ONE
			_edge_look = Vector2.ZERO
			if maxf(absf(axis.x),absf(axis.y)) > 0.97 and not _browser_has_lock():
				_edge_look = axis.sign()*Vector2(smoothstep(0.97,1.0,absf(axis.x)),smoothstep(0.97,1.0,absf(axis.y)))

func _queue_mouse_motion(event: InputEventMouseMotion) -> void:
		# Raw screen motion is independent of canvas stretch / browser zoom.
		# Pointer-lock/focus transitions can emit a synthetic cursor-warp event.
	var motion: Vector2 = event.screen_relative
	if _look_guard_frames == 0 and motion.is_finite() and motion.length() < 300.0:
		_mouse_delta += motion

func _reset_mouse_motion() -> void:
	turn_filter.hide()
	_edge_look = Vector2.ZERO
	_mouse_delta = Vector2.ZERO
	_look_guard_frames = 2

func _process(delta: float) -> void:
	if _look_guard_frames > 0:
		_look_guard_frames -= 1
		_mouse_delta = Vector2.ZERO
		return
	if not controls_enabled or (Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not _mouse_dragging and not OS.has_feature("web")):
		_mouse_delta = Vector2.ZERO
		return
	if OS.has_feature("web") and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_mouse_delta += _edge_look * delta * 390.0
	_apply_pending_mouse_look(delta)

func _apply_pending_mouse_look(delta: float = 1.0/60.0) -> void:
	var rotation_delta := _mouse_delta * SettingsStore.mouse_sensitivity
	_mouse_delta = Vector2.ZERO # Never retain motion: no camera inertia.
	rotation_delta = rotation_delta.limit_length(deg_to_rad(35.0))
	var speed := rotation_delta.length()/maxf(0.001,delta)
	turn_filter.visible = SettingsStore.graphics>0 and speed>1.7
	if turn_filter.visible:
		shutter.set_shader_parameter("shutter_pixels",rotation_delta.normalized()*smoothstep(1.7,7.0,speed)*4.4)
	head.rotate_y(-rotation_delta.x)
	_pitch = clampf(_pitch - rotation_delta.y, -LOOK_LIMIT, LOOK_LIMIT)
	camera.rotation.x = _pitch

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_mouse_dragging = false
		_reset_mouse_motion()
		if controls_enabled:
			set_controls_enabled(false)
			pause_requested.emit()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_reset_mouse_motion()

func _physics_process(delta: float) -> void:
	if _show_fps or _show_position or _show_mission or _show_cartridge:
		_update_debug_text()
	else:
		debug_label.visible = false
	_update_interaction()
	if not controls_enabled:
		_update_astronaut_animation(0.0, true)
		return
	# Arrow-key look provides a browser-friendly fallback for trackpads and
	# users who have not captured the pointer yet.
	var turn := float(Input.is_physical_key_pressed(KEY_LEFT)) - float(Input.is_physical_key_pressed(KEY_RIGHT))
	head.rotate_y(turn * delta * 1.5)
	astronaut.rotation.y = head.rotation.y + PI
	var tilt := float(Input.is_physical_key_pressed(KEY_UP)) - float(Input.is_physical_key_pressed(KEY_DOWN))
	_pitch = clampf(_pitch + tilt * delta * 1.1, -LOOK_LIMIT, LOOK_LIMIT)
	camera.rotation.x = _pitch
	update_eye_offset()
	var grounded := is_on_floor()
	if grounded:
		_coyote_remaining = COYOTE_TIME
	else:
		_coyote_remaining = maxf(0.0, _coyote_remaining - delta)
	if _jump_buffer_remaining >= 0.0:
		_jump_buffer_remaining -= delta
	var move_input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var local_direction := Vector3(move_input.x, 0.0, move_input.y)
	var direction := (head.global_basis * local_direction).normalized()
	var target_speed := run_speed if Input.is_action_pressed("sprint") else walk_speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if direction.length_squared() > 0.001:
		horizontal = horizontal.move_toward(direction * target_speed, (ground_acceleration if grounded else air_acceleration) * delta)
	else:
		horizontal = horizontal.move_toward(Vector3.ZERO, (ground_deceleration if grounded else air_acceleration) * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if not grounded:
		velocity.y -= float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)) * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
	if _jump_buffer_remaining >= 0.0 and _coyote_remaining > 0.0:
		velocity.y = jump_velocity
		_jump_buffer_remaining = -1.0
		_coyote_remaining = 0.0
	move_and_slide()
	if grounded and is_on_floor():
		_step_distance += Vector2(velocity.x,velocity.z).length()*delta
		if _step_distance >= (2.35 if target_speed == run_speed else 1.78):
			_step_distance = 0
			var metal := global_position.z>20 or (global_position.x>-22 and global_position.x<0)
			GameAudio.play_effect("metal" if metal else "step",-24.0 if metal else -16.0)
	var bounds := get_tree().get_first_node_in_group("world_bounds")
	if bounds and is_on_floor() and bounds.contains_position(global_position):
		_last_safe_position = global_position
	if bounds and not bounds.contains_position(global_position):
		global_position = _last_safe_position
		reset_physics_interpolation()
		velocity = Vector3.ZERO
	_update_astronaut_animation(Vector2(velocity.x, velocity.z).length(), is_on_floor())
	if global_position.y < -8.0:
		global_position = _last_safe_position
		velocity = Vector3.ZERO
		notify("Returned to the arrival area.")

func _update_interaction() -> void:
	var previous := focused_interactable
	focused_interactable = null
	if controls_enabled:
		interaction_ray.force_raycast_update()
		if interaction_ray.is_colliding():
			var hit := interaction_ray.get_collider()
			if hit is SpaceInteractable and hit.can_interact(self):
				focused_interactable = hit
	if previous != focused_interactable:
		if is_instance_valid(previous): previous.set_focused(false)
		if is_instance_valid(focused_interactable): focused_interactable.set_focused(true)
	if is_instance_valid(ui):
		ui.set_prompt("[E]  " + focused_interactable.get_interaction_text(self) if is_instance_valid(focused_interactable) else "")

func _update_astronaut_animation(speed: float, grounded: bool) -> void:
	if not astronaut_animation:
		return
	suit_pose.stride = clampf(speed / walk_speed,0,1) if grounded else 0.0
	suit_pose.phase = astronaut_animation.current_animation_position/maxf(0.01,astronaut_animation.current_animation_length)*TAU
	var animation_name := "Walk" if grounded and speed > 0.15 else "Idle"
	if astronaut_animation.current_animation != animation_name or not astronaut_animation.is_playing():
		astronaut_animation.play(animation_name, 0.15)
	astronaut_animation.speed_scale = clampf(speed / walk_speed, 0.7, 1.55) if animation_name == "Walk" else 1.0

func _update_debug_text() -> void:
	debug_label.visible = true
	var lines: PackedStringArray = []
	if _show_fps:
		lines.append("FPS %d" % Engine.get_frames_per_second())
	if _show_position:
		lines.append("POS %.1f  %.1f  %.1f" % [global_position.x, global_position.y, global_position.z])
	if _show_mission:
		lines.append("Mission: %s\nStage: %s\nPlayer: %s" % [GameState.selected_mission, GameState.STAGE_NAMES[GameState.mission_stage], mode])
	if _show_cartridge:
		lines.append("Carried: %s" % str(carried_item.snapshot() if is_instance_valid(carried_item) else "NONE"))
	debug_label.text = "\n".join(lines)


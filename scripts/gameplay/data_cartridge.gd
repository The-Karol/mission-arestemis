class_name DataCartridge
extends SpaceInteractable

enum DataType { NONE, SPACECRAFT_DESIGN, ROCKET_DESIGN, VERIFIED_DESIGN }

var cartridge_id := ""
var data_type := DataType.NONE
var mission_id := ""
var spacecraft_design: Dictionary = {}
var rocket_design: Dictionary = {}
var verification_status := "NOT_CHECKED"
var state := "world"
var holder: Node3D

func _ready() -> void:
	super._ready()
	cartridge_id=cartridge_id.replace("ORION-","HYPERION-")
	if cartridge_id.is_empty():
		cartridge_id = GameState.next_cartridge_id()
	SpaceVisuals.model(self, "interactive/data_cartridge", Vector3(0, -0.01, 0), 0.0, 0.18, false)
	SpaceVisuals.interaction_shape(self, Vector3(0.28, 0.10, 0.20), Vector3(0, 0.025, 0))
	add_to_group("cartridges")

func can_interact(player: Node) -> bool:
	return super.can_interact(player) and state == "world"

func get_interaction_text(_player: Node) -> String:
	return "Take Cartridge  /  %s" % cartridge_id

func interact(player: Node) -> void:
	player.take_item(self)

func attach_to_hand(player: Node3D) -> void:
	if has_meta("starter_cartridge"):GameState.collect_starter()
	state = "carried"
	holder = player
	collision_layer = 0
	reparent(player.carry_anchor, false)
	transform = Transform3D.IDENTITY
	rotation.x = 0.4

func place_in_world(at: Vector3, parent: Node3D) -> void:
	state = "world"
	holder = null
	reparent(parent, false)
	global_position = at
	global_rotation = Vector3.ZERO
	collision_layer = 4

func snapshot() -> Dictionary:
	return {"cartridge_id": cartridge_id, "data_type": DataType.keys()[data_type], "mission_id": mission_id,
		"spacecraft_design": spacecraft_design.duplicate(true), "rocket_design": rocket_design.duplicate(true), "verification_status": verification_status}

func write_spacecraft(mission: String, design: Dictionary) -> void:
	if not mission_id.is_empty() and mission_id!=mission:rocket_design.clear()
	mission_id = mission
	spacecraft_design = design.duplicate(true)
	verification_status = "NOT_CHECKED"
	data_type = DataType.ROCKET_DESIGN if not rocket_design.is_empty() else DataType.SPACECRAFT_DESIGN

func write_rocket(design: Dictionary) -> void:
	rocket_design = design.duplicate(true)
	verification_status = "NOT_CHECKED"
	data_type = DataType.ROCKET_DESIGN

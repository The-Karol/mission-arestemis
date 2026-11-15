extends Node

signal starter_retrieved
signal mission_changed
signal objective_changed
signal stage_changed
signal files_changed

const STAGE_NAMES := ["NOT_SELECTED", "SPACECRAFT_DESIGN", "ROCKET_DESIGN", "PRELAUNCH_CHECK", "READY_FOR_LAUNCH"]
enum Stage { NOT_SELECTED, SPACECRAFT_DESIGN, ROCKET_DESIGN, PRELAUNCH_CHECK, READY_FOR_LAUNCH }

var missions: Array = []
var offered_missions: Array = []
var selected_mission := ""
var mission_started := false
var mission_stage := Stage.NOT_SELECTED
var objective := "Arrive at Hyperion Space Complex"
var objective_hint := "The elevator is taking you to the main level."
var objective_target := Vector3.ZERO
var files_available := false:
	set(value):
		files_available = value
		files_changed.emit()
var intro_briefed := false
var starter_found := false
var starter_location := Vector3(56.4,0.9,-19)
var _serial := 0
var sandbox := false
var flight_results:Dictionary={}
var editor_drafts:Dictionary={}
var sandbox_design := {}
var sandbox_parts: Array = []
var sandbox_spacecraft := "Satellite"

func _ready() -> void:
	missions = JSON.parse_string(FileAccess.get_file_as_string("res://data/missions.json"))
	new_session()

func new_session(free_workshop: bool = false) -> void:
	sandbox = free_workshop
	flight_results.clear()
	editor_drafts.clear()
	sandbox_parts.clear()
	sandbox_design.clear()
	sandbox_spacecraft = "Satellite"
	intro_briefed = free_workshop
	starter_found = free_workshop
	selected_mission = ""
	mission_started = false
	mission_stage = Stage.NOT_SELECTED
	files_available = false
	_serial = 0
	var pool := missions.duplicate()
	pool.shuffle()
	offered_missions = [pool.pop_back()]
	for entry in pool:
		if entry.spacecraft_type != offered_missions[0].spacecraft_type and entry.difficulty != offered_missions[0].difficulty:
			offered_missions.append(entry)
			pool.erase(entry)
			break
	offered_missions.append(pool.pop_back())
	set_objective("Meet the Engineer","Leave the lift and speak to your mission engineer.",Vector3(-31.58,0,17.8))
	mission_changed.emit()
	stage_changed.emit()
	if sandbox:
		set_objective("Choose your spacecraft", "Use the Spacecraft Design computer beside the scientist. All designs are available.",Vector3(10,4,5.5))

func mission() -> Dictionary:
	for entry in missions:
		if entry.id == selected_mission:
			return entry
	return {}

func select_mission(id: String) -> bool:
	if selected_mission != "" or not files_available or not starter_found:
		return false
	for offer in offered_missions:
		if offer.id == id:
			GameAudio.play_effect("assignment")
			selected_mission = id
			mission_started = true
			set_stage(Stage.SPACECRAFT_DESIGN)
			mission_changed.emit()
			return true
	return false

func set_stage(value: Stage) -> void:
	mission_stage = value
	match value:
		Stage.SPACECRAFT_DESIGN:
			set_objective("Go to Spacecraft Design", "KKA  /  Level 02  /  Cross the assembly gallery to the east wing.", Vector3(9, 4, 5))
		Stage.ROCKET_DESIGN:
			set_objective("Carry the spacecraft design to Rocket Assembly", "Remove the cartridge. MIK  /  Level 01  /  Assembly hall.", Vector3(-16, 0, -5))
		Stage.PRELAUNCH_CHECK:
			set_objective("Take the rocket design to Pre-launch Verification", "KKA  /  Level 02  /  Test Laboratory. Insert your cartridge.", Vector3(9, 4, 12))
		Stage.READY_FOR_LAUNCH:
			set_objective("Deliver the verified cartridge to Mission Control", "CUZ  /  Level 01  /  Use the enclosed passage. Flight is a later stage.", Vector3(54, 0, 6.35))
	stage_changed.emit()

func set_objective(text: String, hint: String = "", target: Vector3 = Vector3.ZERO) -> void:
	objective = text
	objective_hint = hint
	objective_target = target
	objective_changed.emit()

func next_cartridge_id() -> String:
	_serial += 1
	return "HYPERION-%04d" % _serial

func collect_starter() -> void:
	if starter_found or sandbox:return
	starter_found=true
	GameAudio.play_effect("assignment")
	set_objective("Return to the Engineer","MIK  /  Level 01  /  The arrival lift. Carry your cartridge to the guide.",Vector3(-31.58,0,17.8))
	starter_retrieved.emit()

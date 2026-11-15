extends Control
signal exit_requested
var mission:Dictionary
func _ready() -> void:
	SpaceUI.fill(self)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var shade:=ColorRect.new()
	shade.color=Color(0.015,0.025,0.025,.94)
	add_child(shade)
	SpaceUI.fill(shade)
	var margins:=MarginContainer.new()
	add_child(margins)
	SpaceUI.fill(margins)
	for side in ["left","right"]:margins.add_theme_constant_override("margin_"+side,70)
	for side in ["top","bottom"]:margins.add_theme_constant_override("margin_"+side,30)
	var paper:=SpaceUI.briefing_panel(margins,24)
	var column:=SpaceUI.column(paper,10)
	SpaceUI.label(column,"MISSION DOSSIER",13,Color("c7ae82"))
	SpaceUI.label(column,mission.get("title","Mission"),27,Color("fff0d4"),true)
	var scroll:=ScrollContainer.new()
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var body:=SpaceUI.column(scroll,8)
	body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	preload("res://scripts/gameplay/design_data.gd").mission_plate(body,mission,110,Color("e3d6b9"))
	for row in [["OBJECTIVE",mission.get("primary_objective","")],["BRIEF",mission.get("description","")],["TARGET ORBIT",mission.get("recommended_orbit","")],["SPACECRAFT",mission.get("spacecraft_type","")],["CONSTRAINTS",mission.get("constraints","")]]:
		SpaceUI.label(body,row[0],12,Color("c7ae82"))
		SpaceUI.label(body,str(row[1]),17,Color("f0e6d1"),true)
	var minimums:=preload("res://scripts/gameplay/design_help.gd").minimums(mission)
	SpaceUI.label(body,"MINIMUM EQUIPMENT",12,Color("c7ae82"))
	SpaceUI.label(body,"Battery %.1f kWh | Memory %.2f TB\nGeneration and power distribution must both cover electrical load."%[minimums.battery,minimums.storage],16,Color("f0e6d1"),true)
	for capability in mission.get("required",[]):SpaceUI.label(body,"- "+preload("res://scripts/gameplay/design_help.gd").capability(str(capability)),15,Color("e3d6b9"))
	SpaceUI.briefing_button(column,"Close dossier  /  J or Esc",func():exit_requested.emit()).grab_focus()
func _input(event:InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode==KEY_J or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		exit_requested.emit()

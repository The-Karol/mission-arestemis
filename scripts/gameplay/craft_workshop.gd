extends VBoxContainer
const Design = preload("res://scripts/gameplay/design_data.gd")
const PAPER := Color("e5dcc1")
const INK := Color("273d33")
var terminal: Node
var kind: String
var ids: Array
var category := "Science"
var categories: VBoxContainer
var parts: VBoxContainer
var installed_index := -1
var requirements: VBoxContainer
var stats: Label
var drawing_board: ColorRect
var saved: Label
var preview: SubViewportContainer
var remove_button: Button
# Kept so the terminal tour can still focus the toggle region without a crash.
var system_tab: Button
var internal_scroll: ScrollContainer
var internal_tiles: HBoxContainer

func open(t: Node) -> void:
	terminal=t
	var initial := Design.payload_design(t)
	kind=initial.type
	ids=initial.module_ids.duplicate()
	size_flags_vertical=Control.SIZE_EXPAND_FILL
	if GameState.sandbox:
		_choose_spacecraft()
		return
	_build_editor()

func _build_editor() -> void:
	if GameState.sandbox:SpaceUI.button(self,"CHANGE SPACECRAFT",func():
		_save()
		SpaceUI.clear(self)
		_choose_spacecraft())
	var row := HBoxContainer.new()
	row.size_flags_vertical=Control.SIZE_EXPAND_FILL
	add_child(row)
	categories=_pane(row,130)
	parts=_pane(row,200)
	var middle := SpaceUI.column(row,5)
	middle.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var m := GameState.mission()
	# Mission goal card: a readable objective and the short orbit call-out.
	var goal_panel := SpaceUI.panel(middle,8)
	goal_panel.add_theme_stylebox_override("panel",SpaceUI.style(PAPER,8,Color("9e9c84")))
	var goal_col := SpaceUI.column(goal_panel,3)
	SpaceUI.label(goal_col,"MISSION",12,SpaceUI.ACCENT)
	var goal_label := SpaceUI.label(goal_col,str(m.get("primary_objective","Design a spacecraft")),18,INK,true)
	goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	SpaceUI.label(goal_col,str(m.get("recommended_orbit","")),13,Color("596b5a"),true)
	var hint := SpaceUI.label(middle,"Click a module in the drawing to select it. Press Delete or use Remove to delete.",12,SpaceUI.MUTED,true)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview=preload("res://scripts/gameplay/craft_view.gd").new()
	preview.module_picked.connect(_pick_installed)
	drawing_board=ColorRect.new()
	drawing_board.color=Color("173a31")
	drawing_board.size_flags_vertical=Control.SIZE_EXPAND_FILL
	middle.add_child(drawing_board)
	drawing_board.add_child(preview)
	SpaceUI.fill(preview)
	SpaceUI.label(middle,"ONBOARD SYSTEMS  /  internal modules appear here",12,SpaceUI.MUTED,true)
	internal_scroll = ScrollContainer.new()
	internal_scroll.custom_minimum_size.y = 67
	internal_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	middle.add_child(internal_scroll)
	internal_tiles = HBoxContainer.new()
	internal_tiles.add_theme_constant_override("separation",5)
	internal_scroll.add_child(internal_tiles)
	system_tab = Button.new()
	system_tab.visible = false
	middle.add_child(system_tab)
	var right := _pane(row,184)
	SpaceUI.label(right,"CURRENT / MINIMUM",13,INK)
	requirements=SpaceUI.column(right,2)
	right.add_child(HSeparator.new())
	stats=SpaceUI.label(right,"",15,INK,true)
	var actions := HBoxContainer.new()
	add_child(actions)
	remove_button=SpaceUI.button(actions,"Remove selected",_delete_selected)
	SpaceUI.button(actions,"Clear all",_clear_all)
	saved=SpaceUI.label(actions,"",13,SpaceUI.GREEN,true)
	saved.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	SpaceUI.button(actions,"SAVE CONCEPT" if GameState.sandbox else "SAVE TO CARTRIDGE",_save)
	_refresh()

func _pane(parent: Node, width: int) -> VBoxContainer:
	var panel:=SpaceUI.panel(parent,8)
	panel.custom_minimum_size.x=width
	panel.add_theme_stylebox_override("panel",SpaceUI.style(PAPER,8,Color("9e9c84")))
	var scroll:=ScrollContainer.new()
	panel.add_child(scroll)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	var col:=SpaceUI.column(scroll,4)
	col.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	return col

func _available(p: Dictionary) -> bool:
	return p.family in ["Common",kind] or p.category=="Storage" and p.id in ["E9","E10"]

func _refresh() -> void:
	var sections: Array=[]
	for p in Design.catalog():
		if _available(p) and not sections.has(p.category): sections.append(p.category)
	if category not in sections: category=sections[0]
	SpaceUI.clear(categories)
	SpaceUI.label(categories,"MODULE SYSTEMS",13,INK)
	for section in sections:
		var tab:=_chip(categories,section,section==category,func():
			category=section
			_refresh())
		tab.tooltip_text=preload("res://scripts/gameplay/design_help.gd").category(section)
	SpaceUI.clear(parts)
	SpaceUI.label(parts,category.to_upper(),13,INK)
	for p in Design.catalog():
		if p.category!=category or not _available(p): continue
		var button := _chip(parts,p.name,false,func():
			var issue:=preload("res://scripts/gameplay/craft_assembly_rules.gd").addition_error(kind,ids,p)
			if not issue.is_empty():
				saved.text=issue
				GameAudio.play_effect("error",-19)
				return
			ids.append(p.id)
			installed_index=ids.size()-1
			_update_design())
		button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		button.tooltip_text=Design.part_help(p)
	_update_design()

func _chip(parent: Node, title: String, active: bool, action: Callable) -> Button:
	var b:=SpaceUI.button(parent,title,action,31)
	b.add_theme_font_size_override("font_size",14)
	var tab:=SpaceUI.style(Color("546954") if active else Color("f0e7ce"),5,Color("ada78e"))
	tab.shadow_size=0
	tab.set_corner_radius_all(3)
	b.add_theme_stylebox_override("normal",tab)
	b.add_theme_color_override("font_color",Color.WHITE if active else INK)
	return b

func _update_design() -> void:
	saved.text=""
	var d:=Design.craft(kind,ids)
	var m:=GameState.mission()
	var extra := float(m.get("delivery_kg",0))
	SpaceUI.clear(requirements)
	var missing := Design.missing_systems(d,m)
	var required_tags: Array = m.get("required",[])
	var done := 0
	for tag in required_tags:
		if tag in d.capabilities: done += 1
	for tag in required_tags:
		var ready:bool=tag in d.capabilities
		var label:=SpaceUI.label(requirements,("[OK] " if ready else "[ ] ")+preload("res://scripts/gameplay/design_help.gd").capability(str(tag)),13,Color("355c3d") if ready else Color("8d4031"),true)
		label.mouse_filter=Control.MOUSE_FILTER_PASS
		var matches:Array=[]
		for part in Design.catalog():
			if _available(part) and tag in part.get("capabilities",[]):matches.append(part.name)
		label.tooltip_text="Required mission capability. Fit: "+", ".join(matches)
	var minimums:=preload("res://scripts/gameplay/design_help.gd").minimums(m)
	var targets:Array=[
		["Generation",d.generation_w,d.load_w,"W","Generation must cover the spacecraft's total electrical load."],
		["Distribution",d.pcdu_w,d.load_w,"W","Fit a PCDU with a rating at least as large as the electrical load."],
		["Battery",d.battery_kwh,minimums.battery,"kWh","Minimum stored energy required for this mission's shadow periods."],
		["Memory",d.storage_tb,minimums.storage,"TB","Minimum onboard storage for this mission's measurements."]]
	if m.get("code","")=="M07":targets.append(["Deliverable fuel",d.cargo_kg*.99,800,"kg","At least 800 kg must remain available for delivery."])
	for target in targets:
		var ready:bool=float(target[1])>=float(target[2])
		var label:=SpaceUI.label(requirements,("%s %s
%.2f / %.2f %s"%["[OK]" if ready else "[ ]",target[0],target[1],target[2],target[3]]),13,Color("355c3d") if ready else Color("8d4031"),true)
		label.mouse_filter=Control.MOUSE_FILTER_PASS
		label.tooltip_text=target[4]+" Current / required minimum."

	stats.text="%.0f kg    /    spacecraft\n%.0f W / %.0f W    /    supply / load\n%.1f kWh    /    battery\n%.1f TB    /    storage" % [d.mass_kg,d.generation_w,d.load_w,d.battery_kwh,d.storage_tb]
	if extra>0: stats.text+="\n%.0f kg    /    with delivery system" % (d.mass_kg+extra)
	preview.rebuild(kind,ids,installed_index)
	SpaceUI.clear(internal_tiles)
	for i in ids.size():
		if preview.modules.has(i): continue
		var p: Dictionary=Design.by_id[ids[i]]
		var tile:=SpaceUI.button(internal_tiles,"",_pick_installed.bind(i),51)
		tile.custom_minimum_size.x=58
		tile.icon=Design.texture(p.model)
		tile.expand_icon=true
		tile.add_theme_constant_override("icon_max_width",36)
		tile.text="Battery" if p.get("battery_kwh",0)>0 else ("PCDU" if p.get("pcdu_w",0)>0 else str({"Storage":"Data","Computing":"CPU","Navigation":"NAV","Thermal":"Thermal","Science":"Instrument"}.get(p.category,p.category)))
		tile.custom_minimum_size.y=58
		tile.add_theme_font_size_override("font_size",11)
		tile.custom_minimum_size.x=78
		tile.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		tile.tooltip_text="Internal / equipment bay  /  "+p.name+"\nRemoving this block changes onboard mass, power and capabilities.\n"+Design.part_help(p)
		tile.set_meta("installed_index",i)
	internal_scroll.visible=internal_tiles.get_child_count()>0
	_pick_installed(installed_index)

func _pick_installed(i: int) -> void:
	installed_index=i if i>=0 and i<ids.size() else -1
	preview.mark(installed_index)
	for tile in internal_tiles.get_children():
		var chosen:bool=tile.get_meta("installed_index")==installed_index
		var box:=SpaceUI.style(Color("23463b"),5,Color("ffd186") if chosen else Color("678477"))
		box.set_border_width_all(3 if chosen else 1)
		tile.add_theme_stylebox_override("normal",box)
	remove_button.disabled=installed_index<0
	remove_button.text="Remove selected" if installed_index<0 else "Remove   /   "+str(Design.by_id[ids[installed_index]].name)

func _delete_selected() -> void:
	if installed_index<0 or installed_index>=ids.size():return
	ids.remove_at(installed_index)
	installed_index=-1
	GameAudio.play_effect("separation",-21)
	_update_design()

func _unhandled_key_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_DELETE and installed_index>=0:
		_delete_selected()
		get_viewport().set_input_as_handled()

func _save() -> void:
	var errors:=preload("res://scripts/gameplay/craft_assembly_rules.gd").validate(kind,ids)
	if not errors.is_empty():
		saved.text=errors[0]
		return
	var design:=Design.craft(kind,ids)
	if GameState.sandbox:
		GameState.sandbox_spacecraft=kind
		GameState.sandbox_design=design
		GameAudio.play_effect("saved")
		saved.text="Workshop spacecraft saved."
	else:
		saved.text=terminal.save_spacecraft(design).get_slice("\n",0)

func _clear_all() -> void:
	ids.clear()
	installed_index=-1
	_update_design()
	saved.text="All modules removed. Save to update the cartridge."

func _choose_spacecraft() -> void:
	SpaceUI.label(self,"CHOOSE YOUR SPACECRAFT",26)
	SpaceUI.label(self,"Choose a platform first. Next, fit its instruments and onboard systems.",17,SpaceUI.MUTED,true)
	var scroll:=ScrollContainer.new()
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	add_child(scroll)
	var grid:=GridContainer.new()
	grid.columns=3
	scroll.add_child(grid)
	var descriptions:={"Rover":"Explore a surface, drill and analyze samples.","Satellite":"Observe Earth or support communications and navigation.","Space Telescope":"Observe distant stars, planets and galaxies.","Interplanetary Probe":"Survey asteroids and comets with remote instruments.","Automated Cargo Spacecraft":"Deliver fuel and supplies to an orbital station."}
	for family in Design.BUSES:
		var card:=SpaceUI.panel(grid,12)
		card.custom_minimum_size=Vector2(240,225)
		var col:=SpaceUI.column(card,7)
		Design.illustration(col,Design.BUSES[family][2],110,SpaceUI.GREEN)
		SpaceUI.label(col,descriptions[family],15,SpaceUI.MUTED,true)
		SpaceUI.button(col,family,func():
			kind=family
			ids=GameState.sandbox_design.get("module_ids",[]).duplicate() if GameState.sandbox_design.get("type","")==kind else []
			GameState.sandbox_spacecraft=kind
			installed_index=-1
			SpaceUI.clear(self)
			_build_editor())

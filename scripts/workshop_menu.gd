extends Control
const Store=preload("res://scripts/workshop_store.gd")
var listing:VBoxContainer
var status:Label
var callback:JavaScriptObject

func _ready() -> void:
	SpaceUI.fill(self)
	var bg:=ColorRect.new()
	bg.color=Color("07171b")
	add_child(bg)
	SpaceUI.fill(bg)
	var panel:=SpaceUI.panel(self,25)
	SpaceUI.fill(panel)
	panel.offset_left=36
	panel.offset_top=30
	panel.offset_right=-36
	panel.offset_bottom=-30
	var col:=SpaceUI.column(panel,12)
	SpaceUI.label(col,"ROCKET WORKSHOP",32)
	SpaceUI.label(col,"Save successful launches, share blueprints and open them in Sandbox.",17,SpaceUI.MUTED,true)
	var row:=HBoxContainer.new()
	col.add_child(row)
	SpaceUI.button(row,"IMPORT BLUEPRINT",_import)
	SpaceUI.button(row,"BACK TO MENU",func():SceneManager.change_scene("res://scenes/ui/main_menu.tscn"))
	status=SpaceUI.label(col,"",15,SpaceUI.GREEN,true)
	var scroll:=ScrollContainer.new()
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	listing=SpaceUI.column(scroll,12)
	listing.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_refresh()

func _refresh() -> void:
	SpaceUI.clear(listing)
	var entries:=Store.all()
	if entries.is_empty():SpaceUI.label(listing,"No saved rockets yet. Complete a mission and select SAVE TO WORKSHOP.",21,SpaceUI.MUTED,true)
	for i in entries.size():
		var entry:Dictionary=entries[i]
		if not Store.validate(entry).is_empty():continue
		var card:=SpaceUI.panel(listing,12)
		var row:=HBoxContainer.new()
		card.add_child(row)
		var drawing:=preload("res://scripts/gameplay/rocket_blueprint.gd").new()
		drawing.parts=Store.parts(entry)
		drawing.read_only=true
		drawing.compact=true
		drawing.custom_minimum_size=Vector2(220,240)
		row.add_child(drawing)
		var details:=SpaceUI.column(row,8)
		details.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		SpaceUI.label(details,entry.name,25)
		SpaceUI.label(details,"%s  /  %d rocket parts"%[entry.spacecraft.type,entry.parts.size()],17,SpaceUI.MUTED)
		SpaceUI.button(details,"OPEN IN SANDBOX",func():
			GameState.new_session(true)
			GameState.sandbox_parts=Store.parts(entry)
			GameState.sandbox_spacecraft=entry.spacecraft.type
			GameState.sandbox_design=Store.Design.craft(entry.spacecraft.type,entry.spacecraft.module_ids)
			SaveStore.pending.clear()
			SceneManager.change_scene("res://scenes/world/world.tscn"))
		SpaceUI.button(details,"EXPORT FILE",_export.bind(entry))
		SpaceUI.button(details,"DELETE",func():
			var confirmation:=ConfirmationDialog.new()
			confirmation.dialog_text="Delete this saved blueprint?"
			add_child(confirmation)
			confirmation.confirmed.connect(func():
				var current:=Store.all()
				current.remove_at(i)
				if not Store.write(current):status.text="Could not delete this blueprint. Storage is unavailable."
				confirmation.queue_free()
				_refresh())
			confirmation.popup_centered())

func _import() -> void:
	if OS.has_feature("web"):
		callback=JavaScriptBridge.create_callback(func(args):_read(str(args[0])))
		var window:=JavaScriptBridge.get_interface("window")
		window.arestemisImport=callback
		JavaScriptBridge.eval("(()=>{const i=document.createElement('input');i.type='file';i.accept='.json,.arestemis';i.onchange=async()=>{const f=i.files[0];if(!f)return;if(f.size>1048576){window.arestemisImport('');return;}window.arestemisImport(await f.text());};i.click();})()",true)
	else:
		var dialog:=FileDialog.new()
		dialog.access=FileDialog.ACCESS_FILESYSTEM
		dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE
		dialog.filters=PackedStringArray(["*.json,*.arestemis ; Rocket blueprints"])
		add_child(dialog)
		dialog.file_selected.connect(func(path):
			var f:=FileAccess.open(path,FileAccess.READ)
			_read(f.get_as_text() if f and f.get_length()<=1048576 else "")
			dialog.queue_free())
		dialog.popup_centered_ratio(.7)

func _read(text:String) -> void:
	if text.to_utf8_buffer().size()>1048576:status.text="Blueprint is too large (maximum 1 MB).";return
	var parser:=JSON.new()
	if parser.parse(text)!=OK:status.text="Invalid JSON blueprint.";return
	var value:Variant=parser.data
	var issue:=Store.validate(value)
	if issue.is_empty():issue=Store.save(value)
	status.text="Blueprint imported." if issue.is_empty() else issue
	status.add_theme_color_override("font_color",SpaceUI.GREEN if issue.is_empty() else Color("ffa48c"))
	_refresh()

func _export(entry:Dictionary) -> void:
	var text:=JSON.stringify(entry,"\t")
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(text.to_utf8_buffer(),"arestemis-rocket.json","application/json")
	else:
		var dialog:=FileDialog.new()
		dialog.access=FileDialog.ACCESS_FILESYSTEM
		dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE
		dialog.current_file="arestemis-rocket.json"
		add_child(dialog)
		dialog.file_selected.connect(func(path):
			var f:=FileAccess.open(path,FileAccess.WRITE)
			if f:f.store_string(text)
			status.text="Blueprint exported." if f else "Could not write this file."
			dialog.queue_free())
		dialog.popup_centered_ratio(.7)

func _exit_tree() -> void:
	if OS.has_feature("web") and callback!=null:
		JavaScriptBridge.eval("window.arestemisImport=()=>{}",true)

extends CanvasLayer
@onready var fade_rect:ColorRect=$ColorRect
var loading:Control
var status:Label
var progress:ProgressBar
func _ready() -> void:process_mode=Node.PROCESS_MODE_ALWAYS
func fade_out() -> void:
	fade_rect.color=Color.BLACK
	fade_rect.modulate.a=0
	var tween:=create_tween()
	tween.tween_property(fade_rect,"modulate:a",1.,.25)
	await tween.finished
func show_loading() -> void:
	if is_instance_valid(loading):return
	loading=Control.new()
	fade_rect.add_child(loading)
	SpaceUI.fill(loading)
	var background:=ColorRect.new()
	background.color=Color("080e15")
	loading.add_child(background)
	SpaceUI.fill(background)
	var center:=CenterContainer.new()
	loading.add_child(center)
	SpaceUI.fill(center)
	var card:=SpaceUI.briefing_panel(center,30)
	card.custom_minimum_size=Vector2(640,330)
	var column:=SpaceUI.column(card,16)
	SpaceUI.label(column,"MISSION ARESTEMIS",32,Color("f3cb8b"))
	SpaceUI.label(column,"FLIGHT ACADEMY / PREPARING YOUR MISSION",13,Color("c3ac83"))
	var drawing:=TextureRect.new()
	drawing.texture=preload("res://assets/ui/plates/engine_m.png")
	drawing.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	drawing.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	drawing.custom_minimum_size.y=92
	drawing.modulate=Color("d1ddc5")
	column.add_child(drawing)
	status=SpaceUI.label(column,"Opening the facility...",19,Color("f1e8d6"))
	progress=ProgressBar.new()
	progress.custom_minimum_size.y=14
	progress.show_percentage=false
	progress.add_theme_stylebox_override("background",SpaceUI.style(Color("182728"),0,Color("344c48")))
	progress.add_theme_stylebox_override("fill",SpaceUI.style(Color("c7a06a"),0,Color("e5c389")))
	column.add_child(progress)
	SpaceUI.label(column,"The first visit may take longer. Your mission will open when ready.",14,Color("b0bfb4"),true)
func update_loading(text:String,value:float) -> void:
	if not is_instance_valid(loading):return
	status.text=text
	progress.value=maxf(progress.value,value)
func fade_in() -> void:
	update_loading("Ready for your mission",100)
	await get_tree().process_frame
	var tween:=create_tween()
	tween.tween_property(fade_rect,"modulate:a",0.,.42)
	await tween.finished

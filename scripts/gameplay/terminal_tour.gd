extends Control

signal finished
var steps: Array
var step := 0
var title: Label
var body: Label
var next: Button
var previous: Button
var progress: HBoxContainer
var card: PanelContainer
var pulse := 0.0

func start(parent: Node, sequence: Array) -> void:
	steps=sequence
	parent.add_child(self)
	SpaceUI.fill(self)
	mouse_filter=Control.MOUSE_FILTER_STOP
	card=SpaceUI.briefing_panel(self,20)
	card.anchor_left=0.17
	card.anchor_right=0.83
	card.anchor_top=0.65
	card.anchor_bottom=0.65
	var col:=SpaceUI.column(card,9)
	var header:=HBoxContainer.new()
	col.add_child(header)
	var badge:=SpaceUI.label(header,"HYPERION  /  WORKSTATION TRAINING",12,Color("c5ab7f"))
	badge.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	progress=HBoxContainer.new()
	progress.add_theme_constant_override("separation",6)
	header.add_child(progress)
	title=SpaceUI.label(col,"",23,Color("fff0d4"))
	body=SpaceUI.label(col,"",16,Color("e0d2bb"),true)
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	col.add_child(row)
	previous=SpaceUI.briefing_button(row,"<- Back",retreat)
	next=SpaceUI.briefing_button(row,"Next ->",advance,true)
	var gap:=Control.new()
	gap.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	SpaceUI.briefing_button(row,"Skip tour",dismiss)
	next.grab_focus()
	refresh()
	modulate.a=0
	create_tween().tween_property(self,"modulate:a",1.0,0.22)

func refresh() -> void:
	title.text="%02d   %s" % [step+1,steps[step][0]]
	body.text=steps[step][1]
	next.text="Start working ->" if step==steps.size()-1 else "Next ->"
	previous.disabled=step==0
	var target:Control=steps[step][2]
	var top:float=0.14 if is_instance_valid(target) and target.get_global_rect().get_center().y>get_viewport_rect().size.y*0.68 else 0.65
	card.anchor_top=top
	card.anchor_bottom=top
	card.offset_top=0
	card.offset_bottom=0
	SpaceUI.clear(progress)
	for i in steps.size():
		var mark:=ColorRect.new()
		mark.custom_minimum_size=Vector2(24,4)
		mark.color=Color("e9c58a") if i<=step else Color("655b49")
		progress.add_child(mark)
	queue_redraw()

func _process(delta: float) -> void:
	pulse+=delta
	queue_redraw()

func _draw() -> void:
	if steps.is_empty():return
	var target: Control=steps[step][2]
	var shade:=Color(0.015,0.02,0.02,0.66)
	if not is_instance_valid(target):
		draw_rect(Rect2(Vector2.ZERO,size),shade)
		return
	var box:=Rect2(target.global_position-global_position,target.size).grow(6)
	box=box.intersection(Rect2(Vector2.ZERO,size))
	draw_rect(Rect2(0,0,size.x,maxf(0,box.position.y)),shade)
	draw_rect(Rect2(0,box.end.y,size.x,maxf(0,size.y-box.end.y)),shade)
	draw_rect(Rect2(0,box.position.y,maxf(0,box.position.x),box.size.y),shade)
	draw_rect(Rect2(box.end.x,box.position.y,maxf(0,size.x-box.end.x),box.size.y),shade)
	var border:=StyleBoxFlat.new()
	border.bg_color=Color(0,0,0,0)
	border.border_color=Color(1,0.83,0.55,0.75+0.2*sin(pulse*2.5))
	border.set_border_width_all(2)
	border.set_corner_radius_all(9)
	draw_style_box(border,box)
	var corner:=Color("fff1d1")
	for point in [box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y)]:
		var direction: Vector2=(box.get_center()-point).sign()
		draw_line(point,point+Vector2(direction.x*16,0),corner,3,true)
		draw_line(point,point+Vector2(0,direction.y*16),corner,3,true)

func retreat() -> void:
	step=maxi(0,step-1)
	refresh()

func advance() -> void:
	step+=1
	if step>=steps.size():dismiss()
	else:refresh()

func dismiss() -> void:
	finished.emit()
	queue_free()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		dismiss()

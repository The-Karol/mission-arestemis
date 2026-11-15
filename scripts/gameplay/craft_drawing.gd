extends Control

var viewport_control: SubViewportContainer

func _draw() -> void:
	var paper := Color("a6c6a4")
	draw_rect(Rect2(Vector2.ZERO,size),Color(paper,0.42),false)
	for axis in 2:
		var length:=size.x if axis==0 else size.y
		for n in range(0,int(length),19):
			var start:=Vector2(n,0) if axis==0 else Vector2(0,n)
			var end:=start+(Vector2(0,size.y) if axis==0 else Vector2(size.x,0))
			draw_line(start,end,Color(paper,0.06 if n%95 else 0.14))
	if viewport_control.subject==null:return
	var anchors: Array=viewport_control.callouts
	var font:=SpaceUI.FONT
	for i in mini(anchors.size(),4):
		var record: Dictionary=anchors[i]
		var point: Vector2=viewport_control.camera.unproject_position(record.anchor.global_position)*size/Vector2(viewport_control.view.size)
		point=point.clamp(Vector2(6,6),size-Vector2(6,6))
		var side:= -1 if i%2==0 else 1
		var text_x:=12.0 if side<0 else size.x*0.75
		var y:=size.y*(0.20+0.49*floori(i/2.0))+i%2*20
		var elbow:=Vector2(size.x*0.27 if side<0 else size.x*0.71,y)
		var end:=Vector2(text_x if side<0 else size.x-12,y)
		var color:=Color("e9be72") if record.active else paper
		draw_polyline(PackedVector2Array([point,elbow,end]),Color(color,0.70),1,true)
		draw_circle(point,2,color)
		draw_string(font,Vector2(text_x,y-4),record.label,HORIZONTAL_ALIGNMENT_LEFT,size.x*0.25-10,12,color)

extends Control

var progress := 0.0
var destination := "Earth"
var transfer := false

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("030912"))
	for i in 180:
		var at:=Vector2(fposmod(i*237.71,size.x),fposmod(i*131.31,size.y))
		draw_circle(at,.6,Color(.5,.64,.76,.5))
	var center := size*Vector2(0.55,0.51)
	var radius := minf(size.x*0.105,size.y*0.24)
	draw_circle(center,radius,Color("163d60"))
	draw_arc(center,radius+3,0,TAU,100,Color("65b6dc"),2,true)
	var font := SpaceUI.FONT
	draw_string(font,center+Vector2(-24,radius+30),"EARTH",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("bdd7dd"))
	# Ellipse with Earth at a focus, not an ever-expanding spiral.
	var points := PackedVector2Array()
	var eccentricity:=.42 if transfer else .08
	var semi_major:=radius*2.15 if transfer else radius*1.55
	for i in 161:
		var a:float=-PI/2+float(i)/160.0*TAU
		var distance:=semi_major*(1-eccentricity*eccentricity)/(1+eccentricity*cos(a))
		points.append(center+Vector2(cos(a),sin(a))*distance*Vector2(1,.73))
	var ap:=center+Vector2(-semi_major*(1+eccentricity),0)
	var pe:=center+Vector2(semi_major*(1-eccentricity),0)
	draw_string(font,ap+Vector2(-10,-12),"Ap",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("73cbe2"))
	draw_string(font,pe+Vector2(2,-12),"Pe",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("73cbe2"))
	for i in 160:
		if i%4<2:draw_line(points[i],points[i+1],Color("47657a"),2,true)
	var end := clampi(int(progress*160),1,160)
	draw_polyline(points.slice(0,end+1),Color("6ad9ef"),3,true)
	draw_circle(points[end],6,Color.WHITE)
	draw_arc(points[end],12,0,TAU,32,Color("76d9e6"),1,true)
	draw_string(font,points[end]+Vector2(18,-12),"VEHICLE",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
	var target := points[110] if transfer else points[28]
	draw_arc(target,16,0,TAU,36,Color("f8c276"),2,true)
	draw_string(font,target+Vector2(22,8),destination.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("f8c276"))
	draw_string(font,Vector2(38,size.y-38),"ORBITAL TRACKING  /  TIME WARP  /  NOT TO SCALE",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("8eabb8"))

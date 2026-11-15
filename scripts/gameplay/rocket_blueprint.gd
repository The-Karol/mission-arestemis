extends Control

const PLATES := {
	"be4":preload("res://assets/ui/plates/be4.png"),
	"be3u":preload("res://assets/ui/plates/be3u.png"),
	"rl10c2":preload("res://assets/ui/plates/rl10c2.png"),
	"booster_heavy":preload("res://assets/ui/plates/booster_heavy.png"),
	"engine_s":preload("res://assets/ui/plates/engine_s.png"),
	"engine_m":preload("res://assets/ui/plates/engine_m.png"),
	"engine_l":preload("res://assets/ui/plates/engine_l.png"),
	"tank_s":preload("res://assets/ui/plates/tank_s.png"),
	"tank_m":preload("res://assets/ui/plates/tank_m.png"),
	"tank_l":preload("res://assets/ui/plates/tank_l.png"),
	"booster_s":preload("res://assets/ui/plates/booster_s.png"),
	"booster_m":preload("res://assets/ui/plates/booster_m.png"),
	"interstage":preload("res://assets/ui/plates/interstage.png"),
	"fairing_s":preload("res://assets/ui/plates/fairing_s.png"),
	"fairing_l":preload("res://assets/ui/plates/fairing_l.png"),
	"avionics":preload("res://assets/ui/plates/avionics.png"),
	"payload":preload("res://assets/ui/plates/payload.png")
}
const RANK := {"ENGINES":0,"FUEL TANKS":1,"INTERSTAGES":2,"SEPARATION":2,"AVIONICS":3,"PAYLOAD":4,"FAIRINGS":5}
const REFERENCE := [{"id":"engine_m","category":"ENGINES","name":"Engine"},{"id":"tank_m","category":"FUEL TANKS","name":"Stage body"},{"id":"interstage","category":"INTERSTAGES","name":"Interstage"},{"id":"fairing_s","category":"FAIRINGS","name":"Fairing"}]
const PEN := Color("cfdcc6")
signal picked(index: int)
var parts: Array = []
var selected := -1
var targets: Array[Dictionary] = []

func _gui_input(event: InputEvent) -> void:
	if read_only:return
	if parts.is_empty():
		targets.clear()
		return
	if event is InputEventMouseMotion:
		tooltip_text=""
		for hit in targets:
			if hit.index>=0 and hit.index<parts.size() and hit.rect.has_point(event.position):
				tooltip_text=str(parts[hit.index].name)+"\nClick to select  /  Delete to remove"
				break
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		for i in range(targets.size()-1,-1,-1):
			if targets[i].index>=0 and targets[i].index<parts.size() and targets[i].rect.has_point(event.position):
				picked.emit(targets[i].index)
				accept_event()
				return
		picked.emit(-1)

func _plate(tex: Texture2D, rect: Rect2, idx: int, ink: Color) -> void:
	if not parts.is_empty():
		targets.append({"rect":rect, "index":idx})
	if idx == selected and not parts.is_empty():
		# Thick halo + double outline so the selected part reads at a glance.
		for offset in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN,Vector2.LEFT+Vector2.UP,Vector2.RIGHT+Vector2.UP,Vector2.LEFT+Vector2.DOWN,Vector2.RIGHT+Vector2.DOWN]:
			draw_texture_rect(tex,Rect2(rect.position+offset*3.6,rect.size),false,Color("ffca6d"))
		draw_rect(rect.grow(5),Color("ffe59a"),false,4.5)
		draw_rect(rect.grow(2),Color("ffca6d"),false,2.5)
	draw_texture_rect(tex,rect,false,ink)



var edit_stage:=0
var read_only:=false
var compact:=false

func _texture(part:Dictionary) -> Texture2D:
	var key:String=part.get("plate",part.id)
	if PLATES.has(key):return PLATES[key]
	return load("res://assets/ui/plates/"+key+".png") as Texture2D

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("1f4038"))
	for tick in range(0,int(size.x),16):draw_line(Vector2(tick,0),Vector2(tick,size.y),Color(PEN,.065))
	for tick in range(0,int(size.y),16):draw_line(Vector2(0,tick),Vector2(size.x,tick),Color(PEN,.065))
	draw_rect(Rect2(Vector2(8,8),size-Vector2(16,16)),Color(PEN,.4),false)
	draw_string(SpaceUI.FONT,Vector2(20,29),"LAUNCHER" if compact else ("LAUNCH VEHICLE ASSEMBLY" if read_only else "STAGE %d SELECTED"%[edit_stage+1]),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("e6c281"))
	targets.clear()
	if parts.is_empty():
		draw_string(SpaceUI.FONT,Vector2(28,size.y*.47),"Add an engine and fuel tank",HORIZONTAL_ALIGNMENT_LEFT,size.x-50,14,PEN)
		draw_string(SpaceUI.FONT,Vector2(28,size.y*.47+26),"Stage 2 is optional",HORIZONTAL_ALIGNMENT_LEFT,size.x-50,12,Color(PEN,.65))
		return
	var core:Array=[]
	var upper:Array=[]
	var fittings:Array=[]
	var boosters:Array=[]
	var electronics:Array=[]
	var joints:Array=[]
	for i in parts.size():
		var part:Dictionary=parts[i].duplicate()
		part["_index"]=i
		match part.category:
			"BOOSTERS":boosters.append(part)
			"AVIONICS":electronics.append(part)
			"INTERSTAGES","SEPARATION":joints.append(part)
			"PAYLOAD","FAIRINGS":fittings.append(part)
			_:
				if int(part.get("stage",0))==0:core.append(part)
				else:upper.append(part)
	for list in [core,upper,fittings]:list.sort_custom(func(a,b):return RANK.get(a.category,0)<RANK.get(b.category,0))
	var units:=0.0
	for part in core+upper+fittings:
		units+=minf(_aspect(part),.28) if part.category=="PAYLOAD" else _aspect(part)
	var diameter:=minf(size.x*.19,(size.y-100)/maxf(units,2.))
	var axis:=size.x*(.5 if compact else .39)
	var bottom:=size.y-40.
	var y:=bottom
	var labels:Array=[]
	var first_bottom:=y
	for part in core:
		var height:=diameter*_aspect(part)
		var width:=diameter*_width(part.category)
		_plate(_texture(part),Rect2(axis-width/2,y-height,width,height),part._index,PEN)
		labels.append([Vector2(axis+width*.45,y-height*.5),part.name])
		y-=height
	var boundary:=y
	var upper_bottom:=y
	for part in upper:
		var height:=diameter*_aspect(part)
		var width:=diameter*_width(part.category)
		var rect:=Rect2(axis-width/2,y-height,width,height)
		_plate(_texture(part),rect,part._index,PEN)
		if part.category=="ENGINES":
			for joint in joints:
				if joint.category=="INTERSTAGES":
					var housing:=Rect2(axis-diameter*.52,y-height,diameter*1.04,height)
					set_meta("interstage_housing",housing)
					draw_rect(housing,Color(PEN,.045))
					draw_rect(housing,Color("ffc985") if joint._index==selected else PEN,false,3 if joint._index==selected else 1.4)
					for side in [-1.,1.]:
						targets.append({"rect":Rect2(axis+side*diameter*.52-5,y-height,10,height),"index":joint._index})
					labels.append([Vector2(housing.end.x,y-height*.45),"Interstage / nozzle inside"])
		labels.append([Vector2(axis+width*.45,y-height*.5),part.name])
		y-=height
	for joint in joints:
		if joint.category=="SEPARATION" or upper.is_empty():
			var line_y:=boundary+3 if joint.category=="SEPARATION" else boundary-5
			var rect:=Rect2(axis-diameter*.54,line_y-3,diameter*1.08,6)
			draw_rect(rect,Color("ffcf8c") if joint._index==selected else Color(PEN,.8),false,3 if joint._index==selected else 1)
			targets.append({"rect":rect.grow(4),"index":joint._index})
	for part in fittings:
		var height:=diameter*(minf(_aspect(part),.28) if part.category=="PAYLOAD" else _aspect(part))
		var width:=diameter*_width(part.category)
		_plate(_texture(part),Rect2(axis-width/2,y-height,width,height),part._index,PEN)
		labels.append([Vector2(axis+width*.45,y-height*.5),part.name])
		y-=height
	for part in electronics:
		var at_y:float=lerpf(first_bottom,boundary,.55) if int(part.get("stage",0))==0 else lerpf(upper_bottom,y,.45)
		var rect:=Rect2(axis+diameter*.68,at_y-13,29,25)
		_plate(_texture(part),rect,part._index,PEN)
		draw_dashed_line(Vector2(axis+diameter*.45,at_y),Vector2(rect.position.x,at_y),Color(PEN,.7),1,3)
		labels.append([rect.get_center(),part.name])
	for i in boosters.size():
		var part:Dictionary=boosters[i]
		var width:=diameter*.26
		var height:=minf(bottom-50,width*_texture(part).get_height()/_texture(part).get_width())
		var side:=1. if i%2==0 else -1.
		var x:=axis+side*(diameter*.6+floori(i/2.)*(width+3))
		_plate(_texture(part),Rect2(x-width*.5,bottom-height,width,height),part._index,PEN)
	var stage_color:=Color("e6c281")
	if boundary<bottom-20:
		draw_line(Vector2(19,boundary+6),Vector2(19,bottom-4),stage_color if edit_stage==0 else Color(PEN,.4),3)
		draw_string(SpaceUI.FONT,Vector2(26,bottom-12),"1",HORIZONTAL_ALIGNMENT_LEFT,-1,13,stage_color)
	if not upper.is_empty():
		draw_line(Vector2(19,y),Vector2(19,boundary-6),stage_color if edit_stage==1 else Color(PEN,.4),3)
		draw_string(SpaceUI.FONT,Vector2(26,y+16),"2",HORIZONTAL_ALIGNMENT_LEFT,-1,13,stage_color)
	for i in (0 if compact else labels.size()):
		var level:=lerpf(bottom-4,48.,(float(i)+.5)/labels.size())
		var text_x:=size.x*.68
		var anchor:Vector2=labels[i][0]
		draw_polyline(PackedVector2Array([anchor,Vector2(text_x-10,level),Vector2(text_x,level)]),Color(PEN,.5),1,true)
		draw_string(SpaceUI.FONT,Vector2(text_x+3,level+3),labels[i][1],HORIZONTAL_ALIGNMENT_LEFT,size.x-text_x-12,11,PEN)

func _width(category:String) -> float:
	return .68 if category in ["ENGINES","PAYLOAD","AVIONICS"] else 1.
func _aspect(part:Dictionary) -> float:
	var texture:=_texture(part)
	return _width(part.category)*float(texture.get_height())/maxi(texture.get_width(),1)

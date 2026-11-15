extends Node3D

# A continuous exterior envelope, independent of the modular room partitions.
# Shared faces are omitted; roofs and walls include actual physics collision.
const FOOTPRINTS := [Rect2(-37,-20,37,40), Rect2(0,-16,14,32), Rect2(14,1.5,14,5), Rect2(28,-2.5,14,9), Rect2(42,-22,34,44), Rect2(-33.9,19,3.8,5.1)]
const HALL := Rect2(-22,-16,22,36)

func _ready() -> void:
	add_to_group("world_bounds")
	var xs: Array[float] = []
	var zs: Array[float] = []
	for rect in FOOTPRINTS:
		for x in [rect.position.x, rect.end.x]:
			if not xs.has(x): xs.append(x)
		for z in [rect.position.y, rect.end.y]:
			if not zs.has(z): zs.append(z)
	xs.sort()
	zs.sort()
	for i in range(xs.size()-1):
		for j in range(zs.size()-1):
			var center := Vector2((xs[i]+xs[i+1])*0.5, (zs[j]+zs[j+1])*0.5)
			if not _inside(center): continue
			var height := 13.65 if HALL.has_point(center) else 7.5
			var width := xs[i+1]-xs[i]
			var depth := zs[j+1]-zs[j]
			if not _inside(Vector2(xs[i]-0.01,center.y)):
				_wall(Vector3(xs[i]-0.12,height*0.5,center.y),Vector3(0.24,height,depth+0.04))
			if not _inside(Vector2(xs[i+1]+0.01,center.y)):
				_wall(Vector3(xs[i+1]+0.12,height*0.5,center.y),Vector3(0.24,height,depth+0.04))
			if not _inside(Vector2(center.x,zs[j]-0.01)):
				_wall(Vector3(center.x,height*0.5,zs[j]-0.12),Vector3(width+0.04,height,0.24))
			if not _inside(Vector2(center.x,zs[j+1]+0.01)):
				_wall(Vector3(center.x,height*0.5,zs[j+1]+0.12),Vector3(width+0.04,height,0.24))
	# Backstop floors below the modular floors close omissions, without
	# filling the elevator shaft or the inter-floor stair openings.
	var threshold := SpaceVisuals.box(self,"LiftThreshold",Vector3(2.0,0.18,0.32),Vector3(-32,-0.09,20.16),Color(0.27,0.29,0.29),true)
	threshold.material_override = preload("res://materials/facility_floor.tres")
	for rect in FOOTPRINTS.slice(0,5):
		var floor_mesh := SpaceVisuals.box(self,"Foundation",Vector3(rect.size.x,0.2,rect.size.y),Vector3(rect.get_center().x,-0.34,rect.get_center().y),Color(0.22,0.25,0.26),true)
		floor_mesh.material_override = preload("res://materials/facility_floor.tres")
	for data in [[Rect2(-37,-20,15,40),7.5], [HALL,13.65], [Rect2(0,-16,14,32),7.5], [Rect2(14,1.5,14,5),7.5], [Rect2(28,-2.5,14,9),7.5], [Rect2(42,-22,34,44),7.5], [Rect2(-33.9,19,3.8,5.1),7.5], [Rect2(-22,-20,22,4),7.5]]:
		var rect: Rect2 = data[0]
		_wall(Vector3(rect.get_center().x,data[1]+0.12,rect.get_center().y), Vector3(rect.size.x,0.24,rect.size.y))

func _inside(point: Vector2) -> bool:
	for rect in FOOTPRINTS:
		if rect.has_point(point): return true
	return false

func contains_position(at: Vector3) -> bool:
	return at.y > -3.5 and at.y < 15.0 and _inside(Vector2(at.x,at.z))

func _wall(at: Vector3, dimensions: Vector3) -> void:
	var mesh := SpaceVisuals.box(self,"ExteriorShell",dimensions,at,Color(0.40,0.44,0.44),true)
	mesh.material_override = preload("res://materials/facility_wall.tres")

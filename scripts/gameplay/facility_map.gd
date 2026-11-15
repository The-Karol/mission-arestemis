extends Control

var level := 1
var player: CharacterBody3D
var world: Node3D

func _ready() -> void:
	resized.connect(queue_redraw)

func _process(_delta: float) -> void:
	queue_redraw()

func _point(at: Vector3) -> Vector2:
	var offset := (size.x - 116.0 * _scale()) * 0.5
	return Vector2(offset, 36) + Vector2(at.x + 38, at.z + 23) * _scale()

func _scale() -> float:
	return minf((size.x - 56) / 116.0, (size.y - 55) / 46.0)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.10, 0.095))
	if not is_instance_valid(world):
		return
	var scale_factor := _scale()
	var floor_node := world.get_node("Floor01" if level == 1 else "Floor02")
	var font := SpaceUI.FONT
	draw_string(font, Vector2(16, 22), "LEVEL 0%d" % level, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, SpaceUI.GREEN)
	for room in floor_node.get_children():
		if room.get("room_title") == null:
			continue
		var at: Vector3 = room.position
		var dimensions: Vector2 = room.room_size
		var rect := Rect2(_point(at) - dimensions * scale_factor * 0.5, dimensions * scale_factor)
		var color: Color = room.zone_color
		draw_rect(rect, Color(color, 0.13))
		draw_rect(rect.grow(-1), Color(color, 0.55), false)
		var title := str(room.room_title)
		var short: String = {"PROJECT OFFICE":"P", "SPACECRAFT DEVELOPMENT LAB":"S", "TEST LABORATORY":"V", "MAIN LAUNCH CONTROL":"C", "MAIN ROCKET ASSEMBLY HALL":"R / ASSEMBLY", "TECHNICAL CORRIDOR":"E"}.get(title, "")
		if short != "":
			draw_string(font, rect.position + Vector2(5, rect.size.y * 0.5 + 4), short, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 7, 12, SpaceUI.INK)
	var connector := Rect2(_point(Vector3(14, 0, 1.5)), Vector2(14, 5) * scale_factor)
	draw_rect(connector, Color(0.2, 0.5, 0.5, 0.20))
	draw_rect(connector, Color(0.4, 0.7, 0.6, 0.6), false)
	var foyer := Rect2(28,-2.5,14,9) if level == 1 else Rect2(28,1.5,14,5)
	draw_rect(Rect2(_point(Vector3(foyer.position.x,0,foyer.position.y)),foyer.size*scale_factor),Color(0.3,0.55,0.54,0.30))
	if level == 2:
		for walkway in [Rect2(40.5,-2.5,1.5,4), Rect2(44,1.7,2.8,4.6), Rect2(-27, 16, 27, 4), Rect2(-2, -16, 2, 32), Rect2(42.12, 8.12, 23.88, 1.88), Rect2(42.12, -10, 23.88, 1.88), Rect2(64.12, -8.12, 1.88, 16.24), Rect2(42.12, -8.12, 1.76, 16.24)]:
			draw_rect(Rect2(_point(Vector3(walkway.position.x, 0, walkway.position.y)), walkway.size * scale_factor), Color(0.45, 0.61, 0.54, 0.18))
		var hall := Rect2(_point(Vector3(-22, 0, -16)), Vector2(22, 32) * scale_factor)
		draw_rect(hall, Color(0.6, 0.6, 0.4, 0.35), false)
		draw_string(font, hall.position + Vector2(8, hall.size.y * 0.5), "OPEN BELOW", HORIZONTAL_ALIGNMENT_LEFT, hall.size.x, 11, SpaceUI.MUTED)
	for stair_name in ["MIK_Stairs", "KKA_Stairs", "CUZ_Stairs"]:
		var stair: Node3D = world.get_node("Floor01/" + stair_name)
		var landing: Node3D = stair.get_node("LowerLandingAnchor" if level == 1 else "UpperLandingAnchor")
		draw_rect(Rect2(_point(landing.global_position) - Vector2(4, 4), Vector2(8, 8)), SpaceUI.ACCENT, false)
	var target := GameState.objective_target
	if target != Vector3.ZERO and (target.y > 2) == (level == 2):
		var at := _point(target)
		draw_circle(at, 5, SpaceUI.ACCENT)
		draw_arc(at, 9, 0, TAU, 24, Color(SpaceUI.ACCENT, 0.6), 1.0, true)
	if is_instance_valid(player) and (player.global_position.y > 2) == (level == 2):
		var at := _point(player.global_position)
		draw_circle(at, 4, SpaceUI.GREEN)
		var forward: Vector3 = -player.head.global_basis.z
		draw_line(at, at + Vector2(forward.x, forward.z) * 14, SpaceUI.GREEN, 2, true)

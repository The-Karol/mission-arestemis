extends Node2D

func _draw() -> void:
	var shell := Color(0.84, 0.85, 0.79, 1.0)
	var shell_shadow := Color(0.47, 0.57, 0.59, 1.0)
	var dark_metal := Color(0.12, 0.20, 0.24, 1.0)
	var accent := Color(0.88, 0.34, 0.24, 1.0)
	var gold := Color(0.99, 0.69, 0.36, 0.95)
	var flame := Color(1.0, 0.79, 0.48, 0.9)

	# Layered plume and engine glow keep the temporary shuttle legible on dark space.
	for radius in [34.0, 25.0, 17.0]:
		draw_circle(Vector2(0, 62), radius, Color(0.95, 0.39, 0.19, 0.08))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, 43), Vector2(-11, 67), Vector2(-4, 112),
		Vector2(0, 91), Vector2(4, 112), Vector2(11, 67), Vector2(13, 43)
	]), gold)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7, 46), Vector2(-5, 70), Vector2(0, 99),
		Vector2(5, 70), Vector2(7, 46)
	]), flame)

	# Swept shuttle wings and tail fins.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, 7), Vector2(-45, 40), Vector2(-34, 43),
		Vector2(-12, 31), Vector2(0, 37), Vector2(12, 31),
		Vector2(34, 43), Vector2(45, 40), Vector2(11, 7)
	]), shell_shadow)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-39, 39), Vector2(-45, 40), Vector2(-34, 43),
		Vector2(-13, 31), Vector2(-11, 26)
	]), accent)
	draw_colored_polygon(PackedVector2Array([
		Vector2(39, 39), Vector2(45, 40), Vector2(34, 43),
		Vector2(13, 31), Vector2(11, 26)
	]), accent)

	# Main fuselage, split into lit and shaded faces for a simple 3D impression.
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -84), Vector2(14, -57), Vector2(15, 25),
		Vector2(10, 40), Vector2(0, 48), Vector2(-10, 40),
		Vector2(-15, 25), Vector2(-14, -57)
	]), shell)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -84), Vector2(14, -57), Vector2(15, 25),
		Vector2(10, 40), Vector2(0, 48)
	]), shell_shadow)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, -24), Vector2(14, -24), Vector2(14, -17),
		Vector2(-14, -17)
	]), accent)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, 31), Vector2(12, 31), Vector2(9, 42),
		Vector2(0, 49), Vector2(-9, 42)
	]), dark_metal)

	# Cockpit, hull seams, inspection ports, and engine bells.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7, -52), Vector2(0, -69), Vector2(7, -52),
		Vector2(6, -43), Vector2(-6, -43)
	]), dark_metal)
	draw_line(Vector2(0, -65), Vector2(0, 29), Color(1.0, 0.96, 0.84, 0.55), 1.6)
	draw_line(Vector2(-11, -5), Vector2(-11, 21), Color(0.28, 0.39, 0.42, 0.75), 1.0)
	draw_line(Vector2(11, -5), Vector2(11, 21), Color(0.28, 0.39, 0.42, 0.75), 1.0)
	for port_y in [-8.0, 3.0, 14.0]:
		draw_circle(Vector2(-8, port_y), 1.4, gold)
		draw_circle(Vector2(8, port_y), 1.4, gold)
	for engine_x in [-8.0, 0.0, 8.0]:
		draw_circle(Vector2(engine_x, 45), 3.2, dark_metal)
		draw_circle(Vector2(engine_x, 45), 1.5, gold)

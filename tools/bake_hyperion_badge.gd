extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(1536,384)
	viewport.disable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var panel:=PanelContainer.new()
	panel.size=Vector2(1536,384)
	panel.add_theme_stylebox_override("panel",SpaceUI.style(Color("192527"),36,Color("bd9a65")))
	viewport.add_child(panel)
	var col:=SpaceUI.column(panel,0)
	var title:=SpaceUI.label(col,"HYPERION",154,Color("e8cc97"))
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var sub:=SpaceUI.label(col,"SPACE COMPLEX  /  ASSEMBLY DIVISION",38,Color("92ada6"))
	sub.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	await create_timer(.15).timeout
	await RenderingServer.frame_post_draw
	print("BADGE ",viewport.get_texture().get_image().save_png("res://assets/ui/hyperion_badge.png"))
	quit()

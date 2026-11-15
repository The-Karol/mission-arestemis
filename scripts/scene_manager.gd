extends Node

const FADE_SCENE := preload("res://scenes/ui/transition_fade.tscn")
var menu_intro_seen := false
var _transitioning := false
var loading_fade: CanvasLayer

func loading_status(text:String,value:float) -> void:
	if is_instance_valid(loading_fade):loading_fade.update_loading(text,value)

func change_scene(scene_path: String) -> void:
	if _transitioning:
		return
	SaveStore.save_now()
	_transitioning = true
	var fade = FADE_SCENE.instantiate()
	get_tree().root.add_child(fade)
	await fade.fade_out()
	loading_fade=fade
	var world_load:=scene_path.ends_with("world.tscn")
	if world_load:
		fade.show_loading()
		await RenderingServer.frame_post_draw
		await get_tree().process_frame
	var loaded:PackedScene
	var request:=ResourceLoader.load_threaded_request(scene_path)
	if request==OK:
		var ratio:Array=[]
		while ResourceLoader.load_threaded_get_status(scene_path,ratio)==ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			loading_status("Loading the facility...",float(ratio[0])*22 if not ratio.is_empty() else 2)
			await get_tree().process_frame
		loaded=ResourceLoader.load_threaded_get(scene_path)
	else:loaded=load(scene_path)
	loading_status("Building rooms and workstations...",25)
	await get_tree().process_frame
	var result := get_tree().change_scene_to_packed(loaded) if loaded else ERR_CANT_OPEN
	if result != OK:
		push_error("Could not load scene %s: %s" % [scene_path, error_string(result)])
		fade.queue_free()
		_transitioning = false
		return
	await get_tree().process_frame
	var scene := get_tree().current_scene
	if scene and scene.has_signal("presentation_ready") and not scene.ready_to_play:
		fade.show_loading()
		await scene.presentation_ready
	await fade.fade_in()
	fade.queue_free()
	loading_fade=null
	_transitioning = false


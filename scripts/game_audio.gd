extends Node

const CLIPS = {
	"flyby":preload("res://assets/audio/sfx/world/flyby.ogg"),
	"button":preload("res://assets/audio/sfx/ui/button.ogg"),
	"lift":preload("res://assets/audio/sfx/world/lift.ogg"),
	"door":preload("res://assets/audio/sfx/world/door.ogg"),
	"boot":preload("res://assets/audio/sfx/world/boot.ogg"),
	"cartridge_in":preload("res://assets/audio/sfx/world/cartridge_in.ogg"),
	"cartridge_out":preload("res://assets/audio/sfx/world/cartridge_out.ogg"),
	"paper":preload("res://assets/audio/sfx/ui/paper.ogg"),
	"assignment":preload("res://assets/audio/sfx/ui/assignment.ogg"),
	"saved":preload("res://assets/audio/sfx/ui/saved.ogg"),
	"verified":preload("res://assets/audio/sfx/ui/verified.ogg"),
	"error":preload("res://assets/audio/sfx/ui/error.ogg"),
	"failure":preload("res://assets/audio/sfx/ui/failure.ogg"),
	"processing":preload("res://assets/audio/sfx/ui/processing.ogg"),
	"metal":preload("res://assets/audio/sfx/player/metal.wav"),
	"step":preload("res://assets/audio/sfx/player/step.wav"),
	"facility":preload("res://assets/audio/ambience/facility.ogg"),
	"terminal":preload("res://assets/audio/ambience/terminal.ogg"),
	"machinery":preload("res://assets/audio/ambience/machinery.ogg"),
	"countdown":preload("res://assets/audio/voices/countdown.ogg"),
	"separation":preload("res://assets/audio/sfx/world/separation.ogg"),
}
const MENU_MUSIC := preload("res://assets/audio/music/main_menu.ogg")
var music_player: AudioStreamPlayer
var music_fade: Tween
var bed: AudioStreamPlayer
var footsteps: Dictionary = {}
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key in ["step","metal"]:
		var player:=AudioStreamPlayer.new()
		player.stream=CLIPS[key]
		player.bus=&"SFX"
		add_child(player)
		footsteps[key]=player
	music_player=AudioStreamPlayer.new()
	music_player.bus=&"Music"
	var track:AudioStreamOggVorbis=MENU_MUSIC.duplicate()
	track.loop=true
	music_player.stream=track
	add_child(music_player)
	bed = AudioStreamPlayer.new()
	bed.bus = "SFX"
	add_child(bed)
	bed.finished.connect(bed.play)
	get_tree().node_added.connect(_wire_button)

func _wire_button(node: Node) -> void:
	if node is BaseButton:
		var click := play_effect.bind("button",-19.0)
		if not node.pressed.is_connected(click): node.pressed.connect(click)

func play_effect(key: String, db := -9.0) -> void:
	if footsteps.has(key):
		var foot:AudioStreamPlayer=footsteps[key]
		foot.pitch_scale=randf_range(0.91,1.08)
		foot.volume_db=db
		foot.play()
		return
	var sound := AudioStreamPlayer.new()
	sound.stream = CLIPS[key]
	sound.bus = "SFX"
	sound.volume_db = db
	add_child(sound)
	sound.finished.connect(sound.queue_free)
	sound.play()

func ambience(key: String) -> void:
	if key.is_empty():
		bed.stop()
		bed.stream = null
	elif bed.stream != CLIPS[key]:
		bed.stream = CLIPS[key]
		bed.volume_db = -21
		bed.play()

func menu_music(enabled: bool) -> void:
	if is_instance_valid(music_fade):music_fade.kill()
	if enabled:
		if not music_player.playing:
			music_player.volume_db=-60
			music_player.play()
		music_fade=create_tween()
		music_fade.tween_property(music_player,"volume_db",-12.0,1.5)
	else:
		music_fade=create_tween()
		music_fade.tween_property(music_player,"volume_db",-60.0,0.6)
		music_fade.tween_callback(music_player.stop)

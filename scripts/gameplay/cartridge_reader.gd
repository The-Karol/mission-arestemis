class_name CartridgeReader
extends SpaceInteractable

signal contents_changed

var cartridge: DataCartridge
var busy := false
var socket: Marker3D

func _ready() -> void:
	super._ready()
	SpaceVisuals.model(self, "interactive/cartridge_reader", Vector3.ZERO, 0.0, 0.3, false)
	SpaceVisuals.interaction_shape(self, Vector3(0.38, 0.25, 0.35), Vector3(0, 0.11, 0.02))
	socket = Marker3D.new()
	socket.name = "CartridgeSocket"
	socket.position = Vector3(0, 0.065, 0.08)
	add_child(socket)

func has_cartridge() -> bool:
	return is_instance_valid(cartridge)

func get_interaction_text(player: Node) -> String:
	if busy:
		return "Reader busy..."
	if has_cartridge():
		return "Remove Cartridge" if not is_instance_valid(player.carried_item) else "Hands are full"
	return "Insert Cartridge" if is_instance_valid(player.carried_item) else "Empty Cartridge Reader"

func interact(player: Node) -> void:
	if has_cartridge():
		remove_cartridge(player)
	elif is_instance_valid(player.carried_item):
		insert_cartridge(player)
	else:
		player.notify("Required design cartridge not inserted.")

func insert_cartridge(player: Node) -> bool:
	if busy:
		player.notify("Reader busy. Please wait.")
		return false
	if has_cartridge():
		player.notify("Cartridge slot occupied.")
		return false
	if not is_instance_valid(player.carried_item):
		player.notify("Required design cartridge not inserted.")
		return false
	GameAudio.play_effect("cartridge_in")
	cartridge = player.carried_item
	player.carried_item = null
	_dock(false)
	contents_changed.emit()
	return true

func remove_cartridge(player: Node) -> bool:
	if busy:
		player.notify("Reader busy. Please wait.")
		return false
	if is_instance_valid(player.carried_item):
		player.notify("Hands are full.")
		return false
	if not has_cartridge():
		player.notify("Cartridge reader is empty.")
		return false
	GameAudio.play_effect("cartridge_out")
	busy = true
	var tween := create_tween()
	tween.tween_property(cartridge, "position:z", 0.21, 0.22)
	tween.tween_callback(func() -> void:
		var removed := cartridge
		cartridge = null
		busy = false
		player.take_item(removed)
		contents_changed.emit())
	return true

func produce_cartridge() -> DataCartridge:
	if has_cartridge() or busy:
		return null
	cartridge = preload("res://scenes/items/data_cartridge.tscn").instantiate() as DataCartridge
	add_child(cartridge)
	_dock(true)
	contents_changed.emit()
	return cartridge

func _dock(output: bool) -> void:
	busy = true
	if output: GameAudio.play_effect("processing",-15)
	cartridge.state = "reader"
	cartridge.holder = self
	cartridge.collision_layer = 0
	cartridge.reparent(socket, false)
	cartridge.transform = Transform3D.IDENTITY
	cartridge.position.z = -0.05 if output else 0.22
	var tween := create_tween()
	tween.tween_property(cartridge, "position:z", 0.12 if output else 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void: busy = false)

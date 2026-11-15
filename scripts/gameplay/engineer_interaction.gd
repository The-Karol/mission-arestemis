extends SpaceInteractable

func _ready() -> void:
	super._ready()
	highlight_root = get_parent().get_node_or_null("VisualRoot")

func get_interaction_text(_player: Node) -> String:
	return "Talk to Engineer"

func can_interact(player: Node) -> bool:
	return super.can_interact(player) and get_parent().active

func interact(_player: Node) -> void:
	get_parent().talk()

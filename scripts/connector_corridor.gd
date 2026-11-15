extends Node3D

const FLOOR_SCENE := preload("res://scenes/blockout/floor_module.tscn")
const WALL_SCENE := preload("res://scenes/blockout/wall.tscn")
const SERVICE_MATERIAL: Material = preload("res://materials/zone_service.tres")

@export var corridor_width := 5.0
@export var corridor_length := 22.0
@export var corridor_height := 3.2

func _ready() -> void:
	_add_piece(FLOOR_SCENE, "Floor", Vector3(corridor_width, 0.22, corridor_length), Vector3(0, -0.11, 0))
	_add_piece(FLOOR_SCENE, "Ceiling", Vector3(corridor_width, 0.18, corridor_length), Vector3(0, corridor_height, 0))
	var side_wall_length := maxf(0.1, corridor_length - 0.24)
	_add_piece(WALL_SCENE, "WestWall", Vector3(0.22, corridor_height, side_wall_length), Vector3(-corridor_width * 0.5, corridor_height * 0.5, 0))
	_add_piece(WALL_SCENE, "EastWall", Vector3(0.22, corridor_height, side_wall_length), Vector3(corridor_width * 0.5, corridor_height * 0.5, 0))
	var sign_anchor := Marker3D.new()
	sign_anchor.name = "SignAnchor"
	sign_anchor.position = Vector3(0, 2.4, 0)
	add_child(sign_anchor)
	var sign := Label3D.new()
	sign.font = SpaceUI.FONT
	sign.name = "SecurePassageSign"
	sign.text = "SECURE PASSAGE\nKKA  /  CUZ"
	sign.font_size = 24
	sign.pixel_size = 0.006
	sign.outline_size = 5
	sign.outline_modulate = Color(0.035, 0.07, 0.09, 1.0)
	sign.modulate = Color(0.93, 0.63, 0.40, 1.0)
	sign_anchor.add_child(sign)

func _add_piece(scene: PackedScene, node_name: String, dimensions: Vector3, location: Vector3) -> void:
	var piece = scene.instantiate()
	piece.name = node_name
	add_child(piece)
	piece.configure(dimensions, SERVICE_MATERIAL)
	piece.position = location

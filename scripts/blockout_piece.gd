extends StaticBody3D

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func configure(dimensions: Vector3, material: Material = null) -> void:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	mesh_instance.mesh = mesh
	if material != null:
		mesh_instance.material_override = material
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision_shape.shape = shape


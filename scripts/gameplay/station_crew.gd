extends SpaceInteractable

const MODELS := {
	"scientist":preload("res://assets/characters/scientist/scientist.glb"),
	"builder":preload("res://assets/characters/builder/builder.glb"),
	"technician":preload("res://assets/characters/technician/technician.glb")
}
const LINES := {
	"scientist":["This bench is where we check the payload against the mission brief. The spacecraft terminal is just beside us.","Save your instruments and spacecraft to the data cartridge before you take it to Assembly."],
	"builder":["The interstage carries the load between the stages. Each section rides on its own jack carriage. We level the rollers and bring the flanges together along the floor rails."],
	"technician":["Flight control here. Bring the verified cartridge to the launch console. Until then, we keep the vehicle on the ground."]
}
var role: String
var title: String
var home_yaw: float
var watch := false
var scan := 0.0
var visitor: Node3D
var collision_body: StaticBody3D

func _ready() -> void:
	super._ready()
	home_yaw = rotation.y
	title = {"scientist":"Payload scientist","builder":"Assembly specialist","technician":"Flight controller"}[role]
	interaction_text = "Talk to "+title.to_lower()
	var actor := (MODELS[role] as PackedScene).instantiate() as Node3D
	add_child(actor)
	var bounds := SpaceVisuals.bounds_of(actor)
	var factor := 1.78 / bounds.size.y
	actor.scale *= factor
	actor.position -= Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)*factor
	var rig := actor.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	var pose := preload("res://scripts/gameplay/crew_pose.gd").new()
	pose.role = role
	rig.add_child(pose)
	highlight_root = actor
	SpaceVisuals.interaction_shape(self,Vector3(0.74,1.8,0.65),Vector3.UP*0.9)
	var body := StaticBody3D.new()
	collision_body = body
	add_child(body)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.74
	capsule.radius = 0.24
	shape.shape = capsule
	shape.position.y = 0.87
	body.add_child(shape)
func _physics_process(delta: float) -> void:
	scan -= delta
	if scan <= 0:
		scan = 0.25
		visitor = get_tree().get_first_node_in_group("player") as Node3D
		watch = false
		if visitor and absf(visitor.global_position.y-global_position.y)<1.3 and global_position.distance_to(visitor.global_position)<3.7:
			var origin := global_position+Vector3.UP*1.5
			var ray := PhysicsRayQueryParameters3D.create(origin,visitor.global_position+Vector3.UP*1.5,1)
			ray.exclude = [collision_body.get_rid()]
			watch = get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
	var target := home_yaw
	if watch and visitor:
		var offset := visitor.global_position-global_position
		target = atan2(offset.x,offset.z)
	rotation.y = rotate_toward(rotation.y,target,delta*2.4)

func interact(player: Node) -> void:
	var lines:Array=LINES[role].duplicate()
	if role=="scientist":
		lines.append("Tip: power generation should exceed instrument demand. Batteries carry the spacecraft through eclipse or lunar night.")
		lines.append("A spectrometer separates light into wavelengths. Different materials leave different spectral signatures.")
		if GameState.sandbox:lines=["Welcome to Sandbox. You can experiment with any spacecraft and rocket design, without a mission deadline.","Start at the Spacecraft Design computer beside me. Choose a spacecraft from the picture cards, then add its instruments and onboard systems.","A cartridge is already in the computer reader. Save your concept, exit, then take the cartridge to Rocket Assembly. Your spacecraft type sets the flight profile shown on the computers. Meet its requirements, verify your cartridge in the Test Laboratory, then launch from Mission Control."]
	elif role=="builder":
		lines.append("Tip: select a part on the drawing to remove it. Stage 1 lifts the vehicle; an optional upper stage supplies velocity higher up.")
		lines.append("Discarding an empty stage reduces the mass that the remaining engine must accelerate.")
	else:
		lines.append("Tip: verification lists what to fix and sets a destination for you. After a successful launch, save the rocket to Workshop and export it to share.")
		lines.append("Reaching orbit requires sideways speed as well as altitude. A satellite is continually falling around Earth.")
	player.ui.show_dialogue(title,lines,Callable(),self)

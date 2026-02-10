class_name MaterialDrop
extends RigidBody3D
## Pickable material dropped by monsters

signal picked_up(material: MaterialDrop)

@export var material_name: String = "unknown"
@export var element_type: String = "neutral"
@export var pickup_radius: float = 1.5
@export var despawn_time: float = 60.0

var mesh_preview: Mesh = null
var _pickup_area: Area3D = null
var _despawn_timer: Timer = null


func _ready() -> void:
	# Physics setup
	mass = 0.5
	linear_damp = 2.0
	angular_damp = 2.0

	add_to_group("pickable")

	_setup_pickup_area()
	_setup_despawn_timer()

	if OS.is_debug_build():
		print("MaterialDrop spawned: %s (%s)" % [material_name, element_type])


func _setup_pickup_area() -> void:
	_pickup_area = Area3D.new()
	_pickup_area.name = "PickupArea"
	_pickup_area.collision_layer = 0
	_pickup_area.collision_mask = 2  # Player layer

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = pickup_radius
	shape.shape = sphere

	_pickup_area.add_child(shape)
	add_child(_pickup_area)

	_pickup_area.body_entered.connect(_on_body_entered)


func _setup_despawn_timer() -> void:
	_despawn_timer = Timer.new()
	_despawn_timer.wait_time = despawn_time
	_despawn_timer.one_shot = true
	_despawn_timer.timeout.connect(_on_despawn_timeout)
	add_child(_despawn_timer)
	_despawn_timer.start()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		pickup(body)


func pickup(collector: Node3D) -> void:
	picked_up.emit(self)

	if collector.has_method("pickup_material"):
		collector.pickup_material(self)

	if OS.is_debug_build():
		print("Material picked up: %s" % material_name)

	queue_free()


func _on_despawn_timeout() -> void:
	if OS.is_debug_build():
		print("Material despawned: %s" % material_name)
	queue_free()


## Get material data as dictionary
func to_dict() -> Dictionary:
	return {
		"name": material_name,
		"element": element_type
	}


## Set element-based color
func apply_element_color() -> void:
	var color: Color
	match element_type:
		"fire":
			color = Color.ORANGE_RED
		"ice":
			color = Color.CYAN
		"poison":
			color = Color.GREEN_YELLOW
		"lightning":
			color = Color.YELLOW
		_:
			color = Color.GRAY

	# Apply to mesh if exists
	for child in get_children():
		if child is MeshInstance3D:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = color
			mat.emission_enabled = true
			mat.emission = color * 0.3
			child.material_override = mat
			break

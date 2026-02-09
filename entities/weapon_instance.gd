class_name WeaponInstance
extends RigidBody3D
## Physics-enabled weapon container for AI-generated models

var model_mesh: MeshInstance3D = null
var bug_score: float = 0.0

func _ready() -> void:
	mass = 1.0
	collision_layer = 1
	collision_mask = 2  # Collides with table layer
	contact_monitor = true
	max_contacts_reported = 4  # Track up to 4 contacts

	if OS.is_debug_build():
		print("WeaponInstance spawned at: %s" % global_position)

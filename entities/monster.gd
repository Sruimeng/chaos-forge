class_name Monster
extends RigidBody3D
## AI-generated monster with HP and material drops

signal died(monster: Monster)
signal damage_taken(amount: float, remaining_hp: float)

@export var max_hp: float = 100.0
@export var drop_count: int = 3

var current_hp: float
var source_prompt: String = ""
var is_dead: bool = false

# Material types this monster drops
var drop_materials: Array[Dictionary] = []


func _ready() -> void:
	current_hp = max_hp

	# Physics setup
	mass = 20.0
	contact_monitor = true
	max_contacts_reported = 4

	add_to_group("monster")

	# Default drop materials (overridden by spawner)
	if drop_materials.is_empty():
		drop_materials = [
			{"name": "monster_bone", "element": "neutral"},
			{"name": "monster_scale", "element": "neutral"},
			{"name": "monster_eye", "element": "poison"}
		]

	if OS.is_debug_build():
		print("Monster spawned | HP: %.0f | Drops: %d" % [max_hp, drop_count])


func take_damage(amount: float) -> void:
	if is_dead:
		return

	current_hp -= amount
	damage_taken.emit(amount, current_hp)

	if OS.is_debug_build():
		print("Monster took %.1f damage | HP: %.1f/%.1f" % [amount, current_hp, max_hp])

	if current_hp <= 0:
		die()


func die() -> void:
	if is_dead:
		return

	is_dead = true
	died.emit(self)

	if OS.is_debug_build():
		print("Monster died at position: %s" % global_position)

	# Spawn materials before removing
	explode_materials()

	# Remove from scene
	queue_free()


func explode_materials() -> void:
	var MaterialDropScript := preload("res://entities/material_drop.gd")

	for i in range(drop_count):
		var mat_data: Dictionary = drop_materials[i % drop_materials.size()]

		var drop: RigidBody3D = RigidBody3D.new()
		drop.set_script(MaterialDropScript)
		drop.material_name = mat_data.get("name", "unknown")
		drop.element_type = mat_data.get("element", "neutral")

		# Add visual mesh
		var mesh_instance := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.15
		sphere.height = 0.3
		mesh_instance.mesh = sphere
		drop.add_child(mesh_instance)

		# Add collision
		var collision := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 0.15
		collision.shape = shape
		drop.add_child(collision)

		# Scatter position
		var offset := Vector3(
			randf_range(-1.0, 1.0),
			0.5,
			randf_range(-1.0, 1.0)
		)
		drop.global_position = global_position + offset

		# Add to scene
		get_tree().current_scene.add_child(drop)

		# Apply random impulse
		var impulse := Vector3(
			randf_range(-2.0, 2.0),
			randf_range(3.0, 5.0),
			randf_range(-2.0, 2.0)
		)
		drop.apply_impulse(impulse)

	if OS.is_debug_build():
		print("Spawned %d material drops" % drop_count)


func get_hp_percent() -> float:
	return current_hp / max_hp * 100.0

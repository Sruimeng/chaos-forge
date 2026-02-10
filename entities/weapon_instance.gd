class_name WeaponInstance
extends RigidBody3D
## Physics-enabled weapon with collision damage

signal hit_monster(monster: Node, damage: float)

const DAMAGE_MULTIPLIER: float = 10.0
const MIN_VELOCITY_FOR_DAMAGE: float = 2.0

var model_mesh: MeshInstance3D = null
var bug_score: float = 0.0
var _last_hit_bodies: Array[Node] = []


func _ready() -> void:
	mass = 1.0
	collision_layer = 4  # Weapon layer
	collision_mask = 1 | 8  # World + Monster

	contact_monitor = true
	max_contacts_reported = 4

	body_entered.connect(_on_body_entered)

	if OS.is_debug_build():
		print("WeaponInstance spawned | mass: %.1f" % mass)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("monster"):
		return

	# Prevent multi-hit on same swing
	if body in _last_hit_bodies:
		return

	var velocity_magnitude: float = linear_velocity.length()
	if velocity_magnitude < MIN_VELOCITY_FOR_DAMAGE:
		return

	var damage: float = _calculate_damage(velocity_magnitude)
	_apply_damage(body, damage)

	_last_hit_bodies.append(body)

	# Clear hit list after short delay
	get_tree().create_timer(0.3).timeout.connect(_clear_hit_list)


func _calculate_damage(velocity: float) -> float:
	# damage = mass × velocity × multiplier
	return mass * velocity * DAMAGE_MULTIPLIER


func _apply_damage(body: Node, damage: float) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
		hit_monster.emit(body, damage)

		if OS.is_debug_build():
			print("Weapon hit! Damage: %.1f (vel: %.1f)" % [damage, linear_velocity.length()])


func _clear_hit_list() -> void:
	_last_hit_bodies.clear()


## Set weapon mass (affects damage)
func set_weapon_mass(new_mass: float) -> void:
	mass = clampf(new_mass, 0.5, 10.0)


## Get current damage potential at given velocity
func get_damage_at_velocity(velocity: float) -> float:
	return _calculate_damage(velocity)

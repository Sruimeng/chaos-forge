class_name RagdollNPC
extends RigidBody3D
## Simplified physics-driven character that can topple

signal stability_changed(state: String)
signal toppled
signal grabbed_weapon(weapon: RigidBody3D)

enum StabilityState { STABLE, WOBBLING, TOPPLED }

const TOPPLE_ANGLE: float = 45.0  # Degrees from vertical to consider toppled
const WOBBLE_ANGLE: float = 15.0  # Degrees to start wobbling

var current_state: StabilityState = StabilityState.STABLE
var held_weapon: RigidBody3D = null
var weapon_joint: Generic6DOFJoint3D = null

var _initial_up: Vector3 = Vector3.UP
var _wobble_timer: float = 0.0

func _ready() -> void:
	# Set up physics
	mass = 10.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.3, 0)  # Low center of mass for stability

	angular_damp = 2.0
	linear_damp = 0.5

	contact_monitor = true
	max_contacts_reported = 4

	add_to_group("ragdoll")

	if OS.is_debug_build():
		print("RagdollNPC ready | State: STABLE")

func _physics_process(delta: float) -> void:
	_check_stability(delta)

func _check_stability(delta: float) -> void:
	# Get current up vector
	var current_up := global_transform.basis.y
	var angle_from_vertical := rad_to_deg(acos(clamp(current_up.dot(Vector3.UP), -1.0, 1.0)))

	if angle_from_vertical > TOPPLE_ANGLE:
		_set_state(StabilityState.TOPPLED)
	elif angle_from_vertical > WOBBLE_ANGLE:
		_set_state(StabilityState.WOBBLING)
		_wobble_timer = 0.0
	elif current_state == StabilityState.WOBBLING:
		_wobble_timer += delta
		if _wobble_timer > 1.0:  # Recovered after 1 second of stability
			_set_state(StabilityState.STABLE)

func _set_state(new_state: StabilityState) -> void:
	if current_state == new_state:
		return

	current_state = new_state
	var state_name: String = StabilityState.keys()[new_state]
	stability_changed.emit(state_name)

	if OS.is_debug_build():
		print("RagdollNPC state: %s" % state_name)

	if new_state == StabilityState.TOPPLED:
		toppled.emit()

## Attach weapon to hand position
func grab_weapon(weapon: RigidBody3D) -> void:
	if not weapon:
		push_error("Cannot grab weapon: weapon is null")
		return

	if held_weapon:
		release_weapon()

	held_weapon = weapon

	# Create joint to attach weapon
	weapon_joint = Generic6DOFJoint3D.new()
	weapon_joint.node_a = get_path()
	weapon_joint.node_b = weapon.get_path()

	# Lock position relative to body
	weapon_joint.set_flag_x(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
	weapon_joint.set_flag_y(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
	weapon_joint.set_flag_z(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)

	add_child(weapon_joint)

	# Position weapon at hand (right side of body)
	var hand_pos := global_position + global_transform.basis.x * 0.4
	weapon.global_position = hand_pos

	grabbed_weapon.emit(weapon)

	if OS.is_debug_build():
		print("RagdollNPC grabbed weapon: mass=%.2f" % weapon.mass)

	# Apply torque based on weapon mass
	_apply_weapon_torque(weapon)

func release_weapon() -> void:
	if weapon_joint:
		weapon_joint.queue_free()
		weapon_joint = null
	held_weapon = null

func _apply_weapon_torque(weapon: RigidBody3D) -> void:
	# Calculate torque from weapon weight
	var lever_arm: float = 0.4  # Distance from center to hand
	var torque_magnitude := weapon.mass * 9.8 * lever_arm

	# Apply as angular impulse (rotate around forward axis)
	var torque_axis := global_transform.basis.z
	apply_torque_impulse(torque_axis * torque_magnitude * 0.1)

	if OS.is_debug_build():
		print("Applied weapon torque: %.2f N·m" % torque_magnitude)

## Get current stability as string
func get_stability_state() -> String:
	return StabilityState.keys()[current_state]

## Check if NPC is still standing
func is_stable() -> bool:
	return current_state == StabilityState.STABLE

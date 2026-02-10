class_name RagdollNPC
extends Node3D
## Physics-driven humanoid for weapon testing

signal stability_changed(state: String)
signal toppled
signal grabbed_weapon(weapon: RigidBody3D)

enum StabilityState { STABLE, WOBBLING, TOPPLED }

const TOPPLE_THRESHOLD: float = 15.0  # N·m torque threshold
const WOBBLE_THRESHOLD: float = 5.0   # N·m torque threshold
const RECOVERY_TIME: float = 2.0      # Seconds to recover from wobble

var current_state: StabilityState = StabilityState.STABLE
var held_weapon: RigidBody3D = null

# Body parts (assigned in _ready from scene tree)
var pelvis: RigidBody3D = null
var spine: RigidBody3D = null
var head: RigidBody3D = null
var left_arm: RigidBody3D = null
var right_arm: RigidBody3D = null
var left_leg: RigidBody3D = null
var right_leg: RigidBody3D = null

# Hand attachment point
var right_hand_marker: Marker3D = null
var weapon_joint: Generic6DOFJoint3D = null

var _wobble_timer: float = 0.0
var _initial_pelvis_y: float = 0.0

func _ready() -> void:
	_find_body_parts()
	_initial_pelvis_y = pelvis.global_position.y if pelvis else 0.0

	if OS.is_debug_build():
		print("RagdollNPC ready | State: STABLE")

func _find_body_parts() -> void:
	pelvis = get_node_or_null("Pelvis")
	spine = get_node_or_null("Pelvis/Spine")
	head = get_node_or_null("Pelvis/Spine/Head")
	left_arm = get_node_or_null("Pelvis/Spine/LeftArm")
	right_arm = get_node_or_null("Pelvis/Spine/RightArm")
	left_leg = get_node_or_null("Pelvis/LeftLeg")
	right_leg = get_node_or_null("Pelvis/RightLeg")
	right_hand_marker = get_node_or_null("Pelvis/Spine/RightArm/HandMarker")

func _physics_process(delta: float) -> void:
	if current_state == StabilityState.TOPPLED:
		return

	_check_stability(delta)

func _check_stability(delta: float) -> void:
	if not pelvis:
		return

	# Check if pelvis dropped significantly (toppled)
	var pelvis_drop := _initial_pelvis_y - pelvis.global_position.y
	if pelvis_drop > 0.5:
		_set_state(StabilityState.TOPPLED)
		return

	# Check angular velocity of spine (wobbling indicator)
	if spine:
		var angular_speed := spine.angular_velocity.length()
		if angular_speed > 3.0:
			_set_state(StabilityState.WOBBLING)
			_wobble_timer = 0.0
		elif current_state == StabilityState.WOBBLING:
			_wobble_timer += delta
			if _wobble_timer > RECOVERY_TIME:
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

## Attach weapon to right hand
func grab_weapon(weapon: RigidBody3D) -> void:
	if not right_arm or not weapon:
		push_error("Cannot grab weapon: missing arm or weapon")
		return

	if held_weapon:
		release_weapon()

	held_weapon = weapon

	# Create joint to attach weapon
	weapon_joint = Generic6DOFJoint3D.new()
	weapon_joint.node_a = right_arm.get_path()
	weapon_joint.node_b = weapon.get_path()

	# Lock linear movement, allow some angular freedom
	weapon_joint.set_flag_x(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
	weapon_joint.set_flag_y(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
	weapon_joint.set_flag_z(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)

	# Set linear limits to 0 (locked)
	weapon_joint.set_param_x(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, 0)
	weapon_joint.set_param_x(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0)
	weapon_joint.set_param_y(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, 0)
	weapon_joint.set_param_y(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0)
	weapon_joint.set_param_z(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, 0)
	weapon_joint.set_param_z(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0)

	add_child(weapon_joint)

	# Position weapon at hand
	if right_hand_marker:
		weapon.global_position = right_hand_marker.global_position

	grabbed_weapon.emit(weapon)

	if OS.is_debug_build():
		print("RagdollNPC grabbed weapon: mass=%.2f" % weapon.mass)

	# Calculate expected torque and predict outcome
	_evaluate_weapon_torque(weapon)

func release_weapon() -> void:
	if weapon_joint:
		weapon_joint.queue_free()
		weapon_joint = null
	held_weapon = null

func _evaluate_weapon_torque(weapon: RigidBody3D) -> void:
	if not right_arm:
		return

	# Calculate lever arm (distance from shoulder to hand)
	var lever_arm: float = 0.5  # Approximate arm length

	# Calculate torque: mass * gravity * lever_arm
	var torque := weapon.mass * 9.8 * lever_arm

	if OS.is_debug_build():
		print("Weapon torque: %.2f N·m" % torque)

	# Predict reaction based on torque
	if torque > TOPPLE_THRESHOLD:
		if OS.is_debug_build():
			print("Prediction: TOPPLE (torque > %.1f)" % TOPPLE_THRESHOLD)
	elif torque > WOBBLE_THRESHOLD:
		if OS.is_debug_build():
			print("Prediction: WOBBLE (torque > %.1f)" % WOBBLE_THRESHOLD)
	else:
		if OS.is_debug_build():
			print("Prediction: STABLE")

## Get current stability as string
func get_stability_state() -> String:
	return StabilityState.keys()[current_state]

## Check if NPC is still standing
func is_stable() -> bool:
	return current_state == StabilityState.STABLE

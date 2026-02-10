class_name WeaponAttacher
extends Node
## Manages weapon attachment to Ragdoll and monitors physics reactions

signal weapon_attached(weapon: RigidBody3D, ragdoll: Node3D)
signal ragdoll_toppled(ragdoll: Node3D, weapon: RigidBody3D)
signal ragdoll_wobbling(ragdoll: Node3D, weapon: RigidBody3D)
signal ragdoll_stable(ragdoll: Node3D, weapon: RigidBody3D)

const ATTACH_DELAY: float = 0.5  # Wait for weapon to settle

var _pending_attachment: Dictionary = {}  # weapon -> ragdoll


func attach_weapon_to_ragdoll(weapon: RigidBody3D, ragdoll: Node3D) -> void:
	if not weapon or not ragdoll:
		push_error("WeaponAttacher: Invalid weapon or ragdoll")
		return

	if not ragdoll.has_method("grab_weapon"):
		push_error("WeaponAttacher: Ragdoll missing grab_weapon method")
		return

	# Connect to ragdoll signals
	if ragdoll.has_signal("stability_changed"):
		if not ragdoll.stability_changed.is_connected(_on_stability_changed):
			ragdoll.stability_changed.connect(_on_stability_changed.bind(ragdoll, weapon))

	if ragdoll.has_signal("toppled"):
		if not ragdoll.toppled.is_connected(_on_toppled):
			ragdoll.toppled.connect(_on_toppled.bind(ragdoll, weapon))

	# Perform attachment
	ragdoll.grab_weapon(weapon)
	weapon_attached.emit(weapon, ragdoll)

	if OS.is_debug_build():
		print("WeaponAttacher: Weapon attached to ragdoll")


func detach_weapon_from_ragdoll(ragdoll: Node3D) -> void:
	if not ragdoll:
		return

	if ragdoll.has_method("release_weapon"):
		ragdoll.release_weapon()

	# Disconnect signals
	if ragdoll.has_signal("stability_changed"):
		var connections: Array = ragdoll.stability_changed.get_connections()
		for conn in connections:
			if conn.callable.get_method() == "_on_stability_changed":
				ragdoll.stability_changed.disconnect(conn.callable)


func _on_stability_changed(state: String, ragdoll: Node3D, weapon: RigidBody3D) -> void:
	match state:
		"STABLE":
			ragdoll_stable.emit(ragdoll, weapon)
		"WOBBLING":
			ragdoll_wobbling.emit(ragdoll, weapon)
		"TOPPLED":
			ragdoll_toppled.emit(ragdoll, weapon)

	if OS.is_debug_build():
		print("WeaponAttacher: Ragdoll state -> %s" % state)


func _on_toppled(ragdoll: Node3D, weapon: RigidBody3D) -> void:
	ragdoll_toppled.emit(ragdoll, weapon)

	if OS.is_debug_build():
		print("WeaponAttacher: Ragdoll toppled!")


## Calculate expected torque for a weapon
static func calculate_torque(weapon: RigidBody3D, lever_arm: float = 0.5) -> float:
	if not weapon:
		return 0.0
	return weapon.mass * 9.8 * lever_arm


## Predict reaction based on weapon mass
static func predict_reaction(weapon: RigidBody3D) -> String:
	var torque := calculate_torque(weapon)

	if torque > 15.0:
		return "TOPPLE"
	elif torque > 5.0:
		return "WOBBLE"
	else:
		return "STABLE"

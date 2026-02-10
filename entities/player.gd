class_name Player
extends CharacterBody3D
## Player controller with weapon and inventory

signal weapon_equipped(weapon: RigidBody3D)
signal material_picked_up(material_data: Dictionary)
signal inventory_changed(count: int)

@export var move_speed: float = 5.0
@export var mouse_sensitivity: float = 0.003

var equipped_weapon: RigidBody3D = null
var inventory: Array[Dictionary] = []

var _weapon_mount: RemoteTransform3D = null
var _camera: Camera3D = null


func _ready() -> void:
	# Physics setup
	add_to_group("player")

	# Create collision
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)

	# Create mesh
	var mesh := MeshInstance3D.new()
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.4
	capsule_mesh.height = 1.8
	mesh.mesh = capsule_mesh
	mesh.position.y = 0.9
	add_child(mesh)

	# Create weapon mount point
	_weapon_mount = RemoteTransform3D.new()
	_weapon_mount.name = "WeaponMount"
	_weapon_mount.position = Vector3(0.6, 1.2, -0.3)
	_weapon_mount.update_rotation = false
	add_child(_weapon_mount)

	# Set collision layer (2 = player)
	collision_layer = 2
	collision_mask = 1  # Collide with world

	# Give starter materials
	_give_starter_materials()

	if OS.is_debug_build():
		print("Player spawned | Inventory: %d" % inventory.size())


func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_handle_attack()
	move_and_slide()


func _handle_movement(_delta: float) -> void:
	var input_dir := Vector3.ZERO

	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		input_dir.z -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		input_dir.z += 1
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		input_dir.x += 1

	input_dir = input_dir.normalized()

	# Apply movement
	velocity.x = input_dir.x * move_speed
	velocity.z = input_dir.z * move_speed

	# Simple gravity
	if not is_on_floor():
		velocity.y -= 20.0 * get_physics_process_delta_time()
	else:
		velocity.y = 0

	# Face movement direction
	if input_dir.length() > 0.1:
		var target_angle := atan2(input_dir.x, input_dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 0.15)


func _handle_attack() -> void:
	if not equipped_weapon:
		return

	if Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_swing_weapon()


func _swing_weapon() -> void:
	if not equipped_weapon:
		return

	# Apply forward impulse to weapon
	var swing_dir := -global_transform.basis.z
	var swing_force := swing_dir * 15.0 + Vector3.UP * 5.0
	equipped_weapon.apply_impulse(swing_force)

	if OS.is_debug_build():
		print("Weapon swung!")


func equip_weapon(weapon: RigidBody3D) -> void:
	if equipped_weapon:
		unequip_weapon()

	equipped_weapon = weapon

	# Parent weapon to mount
	if weapon.get_parent():
		weapon.reparent(self)
	else:
		add_child(weapon)

	# Position at mount point
	weapon.position = _weapon_mount.position
	weapon.rotation = Vector3.ZERO

	# Enable contact monitoring for damage
	weapon.contact_monitor = true
	weapon.max_contacts_reported = 4

	weapon_equipped.emit(weapon)

	if OS.is_debug_build():
		print("Weapon equipped")


func unequip_weapon() -> void:
	if not equipped_weapon:
		return

	equipped_weapon.reparent(get_tree().current_scene)
	equipped_weapon = null


func pickup_material(material: Node) -> void:
	var mat_data: Dictionary

	if material is MaterialDrop:
		mat_data = material.to_dict()
	elif material.has_method("to_dict"):
		mat_data = material.to_dict()
	else:
		mat_data = {"name": "unknown", "element": "neutral"}

	inventory.append(mat_data)
	material_picked_up.emit(mat_data)
	inventory_changed.emit(inventory.size())

	if OS.is_debug_build():
		print("Picked up: %s | Inventory: %d" % [mat_data.name, inventory.size()])


func get_inventory_count() -> int:
	return inventory.size()


func has_enough_materials(count: int = 2) -> bool:
	return inventory.size() >= count


func consume_materials(count: int) -> Array[Dictionary]:
	var consumed: Array[Dictionary] = []

	for i in range(mini(count, inventory.size())):
		consumed.append(inventory.pop_front())

	inventory_changed.emit(inventory.size())
	return consumed


func _give_starter_materials() -> void:
	var StarterMaterialsScript := preload("res://data/starter_materials.gd")
	var starters: Array[Dictionary] = StarterMaterialsScript.get_starter_set()

	for mat in starters:
		inventory.append(mat)

	inventory_changed.emit(inventory.size())

	if OS.is_debug_build():
		print("Received %d starter materials" % starters.size())

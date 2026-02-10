class_name ModelLoader
extends Node
## Loads GLB files and wraps them in physics-enabled instances

const WeaponInstanceScript := preload("res://entities/weapon_instance.gd")
const MonsterScript := preload("res://entities/monster.gd")
const MAX_VERTICES: int = 500000  # AI models can be detailed
const SPAWN_HEIGHT_OFFSET: float = 1.5

signal weapon_spawned(weapon: RigidBody3D)
signal monster_loaded(monster: RigidBody3D)
signal load_failed(error_msg: String)

var _table_position: Vector3 = Vector3.ZERO

func _ready() -> void:
	_find_table_position()

func _find_table_position() -> void:
	var table: Node = get_tree().root.find_child("Table", true, false)
	if not table:
		push_error("Table node not found in scene")
		return

	if table is Node3D:
		_table_position = table.global_position

func load_weapon(glb_path: String) -> void:
	if not FileAccess.file_exists(glb_path):
		load_failed.emit("GLB file not found: %s" % glb_path)
		return

	var scene: Node3D = _load_glb(glb_path)
	if not scene:
		load_failed.emit("Failed to parse GLB: %s" % glb_path)
		return

	var mesh: MeshInstance3D = _extract_mesh(scene)
	if not mesh:
		load_failed.emit("No mesh found in GLB")
		scene.queue_free()
		return

	if not _validate_mesh(mesh):
		scene.queue_free()
		return

	var weapon: RigidBody3D = _create_weapon_body(scene, mesh)
	if not weapon:
		scene.queue_free()
		return

	_position_weapon(weapon)
	weapon_spawned.emit(weapon)

func _load_glb(path: String) -> Node3D:
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()

	var err := gltf.append_from_file(path, state)
	if err != OK:
		push_error("GLTFDocument.append_from_file failed: %d" % err)
		return null

	var scene: Node = gltf.generate_scene(state)
	if not scene is Node3D:
		push_error("Generated scene is not Node3D")
		if scene:
			scene.queue_free()
		return null

	return scene as Node3D

func _extract_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D

	for child in node.get_children():
		var found := _extract_mesh(child)
		if found:
			return found

	return null

func _validate_mesh(mesh: MeshInstance3D) -> bool:
	if not mesh.mesh:
		load_failed.emit("MeshInstance3D has no mesh data")
		return false

	var vertex_count: int = 0
	for surface_idx in range(mesh.mesh.get_surface_count()):
		var arrays: Array = mesh.mesh.surface_get_arrays(surface_idx)
		if arrays.size() > 0 and arrays[Mesh.ARRAY_VERTEX]:
			vertex_count += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()

	if vertex_count > MAX_VERTICES:
		load_failed.emit("Mesh exceeds vertex limit: %d > %d" % [vertex_count, MAX_VERTICES])
		return false

	return true

func _create_weapon_body(scene: Node3D, mesh: MeshInstance3D) -> RigidBody3D:
	var weapon: RigidBody3D = WeaponInstanceScript.new()
	weapon.add_child(scene)
	weapon.set("model_mesh", mesh)

	var collision := _create_collision_shape(mesh)
	if collision:
		weapon.add_child(collision)
	else:
		load_failed.emit("Failed to create collision shape")
		weapon.queue_free()
		return null

	get_tree().root.add_child(weapon)
	return weapon

func _create_collision_shape(mesh: MeshInstance3D) -> CollisionShape3D:
	var collision := CollisionShape3D.new()

	# Try convex hull first
	var convex_shape := _generate_convex_shape(mesh)
	if convex_shape:
		collision.shape = convex_shape
		return collision

	# Fallback to box shape
	var box_shape := BoxShape3D.new()
	var aabb := mesh.get_aabb()
	box_shape.size = aabb.size
	collision.shape = box_shape
	collision.position = aabb.get_center()

	if OS.is_debug_build():
		print("Using fallback BoxShape3D")

	return collision

func _generate_convex_shape(mesh: MeshInstance3D) -> ConvexPolygonShape3D:
	if not mesh.mesh:
		return null

	var shape := mesh.mesh.create_convex_shape(true, true)
	if shape is ConvexPolygonShape3D:
		return shape as ConvexPolygonShape3D

	return null

func _position_weapon(weapon: RigidBody3D) -> void:
	var spawn_pos := _table_position + Vector3(0, SPAWN_HEIGHT_OFFSET, 0)
	weapon.global_position = spawn_pos


## Load monster from GLB file
func load_monster(glb_path: String) -> Monster:
	if not FileAccess.file_exists(glb_path):
		load_failed.emit("Monster GLB not found: %s" % glb_path)
		return null

	var scene: Node3D = _load_glb(glb_path)
	if not scene:
		load_failed.emit("Failed to parse monster GLB: %s" % glb_path)
		return null

	var mesh: MeshInstance3D = _extract_mesh(scene)
	if not mesh:
		load_failed.emit("No mesh found in monster GLB")
		scene.queue_free()
		return null

	if not _validate_mesh(mesh):
		scene.queue_free()
		return null

	var monster: Monster = _create_monster_body(scene, mesh)
	if monster:
		monster_loaded.emit(monster)

	return monster


func _create_monster_body(scene: Node3D, mesh: MeshInstance3D) -> Monster:
	var monster: Monster = MonsterScript.new()
	monster.add_child(scene)

	# Set collision layer for monsters
	monster.collision_layer = 8  # Monster layer
	monster.collision_mask = 1 | 4  # World + Weapon

	var collision := _create_collision_shape(mesh)
	if collision:
		monster.add_child(collision)
	else:
		# Fallback sphere collision
		var fallback := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.5
		fallback.shape = sphere
		fallback.position.y = 0.5
		monster.add_child(fallback)

	if OS.is_debug_build():
		print("Monster body created from GLB")

	return monster

class_name MonsterSpawner
extends Node
## Async monster pre-generation with queue system

signal monster_ready
signal monster_spawned(monster: Monster)
signal generation_started
signal generation_failed(error: String)

var monster_queue: Array[Dictionary] = []  # {glb_path, prompt}
var is_generating: bool = false
var spawn_points: Array[Marker3D] = []

var _model_loader: Node = null

const MONSTER_PROMPTS: Array[String] = [
	"a small goblin creature, low-poly game asset",
	"a spider monster with glowing eyes, low-poly game asset",
	"a slime blob creature, low-poly game asset",
	"a skeleton warrior, low-poly game asset",
	"a bat demon, low-poly game asset",
	"a mushroom monster, low-poly game asset"
]

const MONSTER_MATERIALS: Array[Array] = [
	[{"name": "goblin_ear", "element": "neutral"}, {"name": "goblin_tooth", "element": "poison"}],
	[{"name": "spider_leg", "element": "poison"}, {"name": "spider_silk", "element": "neutral"}],
	[{"name": "slime_core", "element": "ice"}, {"name": "slime_gel", "element": "neutral"}],
	[{"name": "bone_fragment", "element": "neutral"}, {"name": "soul_essence", "element": "fire"}],
	[{"name": "bat_wing", "element": "neutral"}, {"name": "demon_fang", "element": "fire"}],
	[{"name": "mushroom_cap", "element": "poison"}, {"name": "spore_dust", "element": "neutral"}]
]


func _ready() -> void:
	_setup_model_loader()
	_find_spawn_points()

	if OS.is_debug_build():
		print("MonsterSpawner ready | Spawn points: %d" % spawn_points.size())


func _setup_model_loader() -> void:
	var ModelLoaderScript := preload("res://systems/model_loader.gd")
	_model_loader = ModelLoaderScript.new()
	add_child(_model_loader)

	_model_loader.load_failed.connect(_on_load_failed)


func _find_spawn_points() -> void:
	spawn_points.clear()
	var points := get_tree().get_nodes_in_group("spawn_point")
	for point in points:
		if point is Marker3D:
			spawn_points.append(point)


## Queue next monster generation (call during crafting)
func queue_next_monster() -> void:
	if is_generating or monster_queue.size() > 0:
		return  # Already have one ready or generating

	is_generating = true
	generation_started.emit()

	var prompt_index := randi() % MONSTER_PROMPTS.size()
	var prompt: String = MONSTER_PROMPTS[prompt_index]

	if OS.is_debug_build():
		print("Generating monster: %s" % prompt)

	# Store material info for this monster type
	var monster_data := {
		"prompt": prompt,
		"prompt_index": prompt_index,
		"glb_path": ""
	}

	# Request from API
	if APIClient:
		APIClient.model_ready.connect(_on_model_ready.bind(monster_data), CONNECT_ONE_SHOT)
		APIClient.request_model(prompt)
	else:
		push_error("APIClient not available")
		is_generating = false


func _on_model_ready(glb_path: String, monster_data: Dictionary) -> void:
	monster_data.glb_path = glb_path
	monster_queue.append(monster_data)
	is_generating = false
	monster_ready.emit()

	if OS.is_debug_build():
		print("Monster queued: %s" % glb_path)


func _on_load_failed(error: String) -> void:
	is_generating = false
	generation_failed.emit(error)
	push_error("Monster generation failed: %s" % error)


## Get queued monster or fallback
func get_queued_monster() -> Monster:
	var monster: Monster

	if monster_queue.is_empty():
		monster = create_fallback_sphere_monster()
	else:
		var data: Dictionary = monster_queue.pop_front()
		monster = _load_monster_from_glb(data)

	# Start next generation immediately
	queue_next_monster()

	return monster


func _load_monster_from_glb(data: Dictionary) -> Monster:
	var glb_path: String = data.glb_path
	var prompt_index: int = data.get("prompt_index", 0)

	# Load GLB file
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()

	var err := gltf.append_from_file(glb_path, state)
	if err != OK:
		push_error("Failed to load monster GLB: %s" % glb_path)
		return create_fallback_sphere_monster()

	var scene: Node3D = gltf.generate_scene(state)
	if not scene:
		return create_fallback_sphere_monster()

	# Create Monster instance
	var monster := Monster.new()
	monster.source_prompt = data.prompt

	# Transfer mesh to monster
	for child in scene.get_children():
		child.reparent(monster)

	scene.queue_free()

	# Add collision shape
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.5
	collision.shape = shape
	collision.position.y = 0.5
	monster.add_child(collision)

	# Set drop materials based on monster type
	if prompt_index < MONSTER_MATERIALS.size():
		monster.drop_materials.clear()
		for mat in MONSTER_MATERIALS[prompt_index]:
			monster.drop_materials.append(mat)

	return monster


## Create fallback sphere monster when queue empty
func create_fallback_sphere_monster() -> Monster:
	var monster := Monster.new()
	monster.max_hp = 50.0
	monster.source_prompt = "fallback_sphere"

	# Visual mesh
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	mesh.mesh = sphere
	mesh.position.y = 0.5

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.DARK_RED
	mesh.material_override = mat

	monster.add_child(mesh)

	# Collision
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.5
	collision.shape = shape
	collision.position.y = 0.5
	monster.add_child(collision)

	# Default materials
	monster.drop_materials = [
		{"name": "dark_essence", "element": "neutral"},
		{"name": "void_shard", "element": "neutral"}
	]

	if OS.is_debug_build():
		print("Created fallback sphere monster")

	return monster


## Spawn monster at random point
func spawn_at_random_point(monster: Monster) -> void:
	if spawn_points.is_empty():
		monster.global_position = Vector3(0, 1, -5)
	else:
		var point: Marker3D = spawn_points.pick_random()
		monster.global_position = point.global_position

	get_tree().current_scene.add_child(monster)
	monster_spawned.emit(monster)

	if OS.is_debug_build():
		print("Monster spawned at: %s" % monster.global_position)


## Check if monster is ready
func has_queued_monster() -> bool:
	return monster_queue.size() > 0


## Check generation status
func is_busy() -> bool:
	return is_generating

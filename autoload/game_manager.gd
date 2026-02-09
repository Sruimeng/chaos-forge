extends Node
## Game state manager singleton

const ModelLoaderScript := preload("res://systems/model_loader.gd")
const PhysicsInspectorScript := preload("res://systems/physics_inspector.gd")

signal weapon_generated(weapon_scene: Node3D)
signal inspection_complete(weapon: RigidBody3D, bug_score: float, bug_details: Dictionary)
signal sale_completed(success: bool, profit: int)

enum GameState { IDLE, GENERATING, INSPECTING, PITCHING }

var current_state: GameState = GameState.IDLE
var current_weapon: RigidBody3D = null

var _model_loader: Node = null
var _physics_inspector: Node = null

func _ready() -> void:
	_setup_model_loader()
	_setup_physics_inspector()
	_connect_signals()

	if OS.is_debug_build():
		print("GameManager initialized")

func _setup_model_loader() -> void:
	_model_loader = ModelLoaderScript.new()
	add_child(_model_loader)

func _setup_physics_inspector() -> void:
	_physics_inspector = PhysicsInspectorScript.new()
	add_child(_physics_inspector)

func _connect_signals() -> void:
	if not APIClient:
		push_error("APIClient autoload not found")
		return

	APIClient.model_ready.connect(_on_model_ready)

	if _model_loader:
		_model_loader.weapon_spawned.connect(_on_weapon_spawned)
		_model_loader.load_failed.connect(_on_load_failed)

	if _physics_inspector:
		_physics_inspector.inspection_complete.connect(_on_inspection_complete)

func _on_model_ready(glb_path: String) -> void:
	if OS.is_debug_build():
		print("Model ready, loading: %s" % glb_path)

	if not _model_loader:
		push_error("ModelLoader not initialized")
		return

	_model_loader.load_weapon(glb_path)

func _on_weapon_spawned(weapon: RigidBody3D) -> void:
	clear_weapon()
	current_weapon = weapon
	set_state(GameState.INSPECTING)
	weapon_generated.emit(weapon)

	if OS.is_debug_build():
		print("Weapon spawned successfully")

	if _physics_inspector and weapon:
		_physics_inspector.start_inspection(weapon)

func _on_inspection_complete(weapon: RigidBody3D, bug_score: float, bug_details: Dictionary) -> void:
	if not weapon or not is_instance_valid(weapon):
		if OS.is_debug_build():
			print("Inspection complete but weapon is invalid")
		return

	if weapon is WeaponInstance:
		weapon.bug_score = bug_score

	set_state(GameState.PITCHING)
	inspection_complete.emit(weapon, bug_score, bug_details)

	if OS.is_debug_build():
		print("Bug score assigned: %.2f" % bug_score)

func _on_load_failed(error_msg: String) -> void:
	push_error("Model loading failed: %s" % error_msg)
	set_state(GameState.IDLE)

func set_state(new_state: GameState) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	if OS.is_debug_build():
		print("State changed: ", GameState.keys()[new_state])

func clear_weapon() -> void:
	if not current_weapon:
		return
	current_weapon.queue_free()
	current_weapon = null

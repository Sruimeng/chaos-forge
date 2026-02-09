extends Node
## Game state manager singleton

const ModelLoaderScript := preload("res://systems/model_loader.gd")

signal weapon_generated(weapon_scene: Node3D)
signal sale_completed(success: bool, profit: int)

enum GameState { IDLE, GENERATING, INSPECTING, PITCHING }

var current_state: GameState = GameState.IDLE
var current_weapon: RigidBody3D = null

var _model_loader: Node = null

func _ready() -> void:
	_setup_model_loader()
	_connect_signals()

	if OS.is_debug_build():
		print("GameManager initialized")

func _setup_model_loader() -> void:
	_model_loader = ModelLoaderScript.new()
	add_child(_model_loader)

func _connect_signals() -> void:
	if not APIClient:
		push_error("APIClient autoload not found")
		return

	APIClient.model_ready.connect(_on_model_ready)

	if _model_loader:
		_model_loader.weapon_spawned.connect(_on_weapon_spawned)
		_model_loader.load_failed.connect(_on_load_failed)

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

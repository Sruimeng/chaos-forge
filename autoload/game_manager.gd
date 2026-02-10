extends Node
## Game state manager singleton - Dimension Smuggler MVP

const ModelLoaderScript := preload("res://systems/model_loader.gd")

signal weapon_generated(weapon: RigidBody3D)
signal weapon_ready_for_test(weapon: RigidBody3D)
signal ragdoll_reaction(reaction_type: String, details: Dictionary)
signal test_complete(success: bool)

enum GameState { IDLE, ORDERING, GENERATING, TESTING, REACTING }

var current_state: GameState = GameState.IDLE
var current_weapon: RigidBody3D = null

var _model_loader: Node = null

func _ready() -> void:
	_setup_model_loader()
	_connect_signals()

	if OS.is_debug_build():
		print("GameManager initialized (Dimension Smuggler MVP)")

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

## Public API: Start weapon generation
func request_weapon(prompt: String) -> void:
	if current_state != GameState.IDLE and current_state != GameState.ORDERING:
		push_error("Cannot request weapon in state: %s" % GameState.keys()[current_state])
		return

	set_state(GameState.GENERATING)
	APIClient.request_model(prompt)

## Public API: Start test phase (weapon ready for Ragdoll)
func start_weapon_test() -> void:
	if not current_weapon:
		push_error("No weapon to test")
		return

	set_state(GameState.TESTING)
	weapon_ready_for_test.emit(current_weapon)

## Public API: Report Ragdoll reaction
func report_ragdoll_reaction(reaction_type: String, details: Dictionary = {}) -> void:
	if current_state != GameState.TESTING:
		return

	set_state(GameState.REACTING)
	ragdoll_reaction.emit(reaction_type, details)

	if OS.is_debug_build():
		print("Ragdoll reaction: %s" % reaction_type)

## Public API: Complete test and reset
func complete_test(success: bool) -> void:
	test_complete.emit(success)
	set_state(GameState.IDLE)

	if OS.is_debug_build():
		print("Test complete: %s" % ("SUCCESS" if success else "FAILED"))

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
	weapon_generated.emit(weapon)

	if OS.is_debug_build():
		print("Weapon spawned successfully")

	# Auto-transition to testing (MVP: skip ordering UI)
	start_weapon_test()

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

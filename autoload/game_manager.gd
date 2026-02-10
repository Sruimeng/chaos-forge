extends Node
## Game state manager singleton

const ModelLoaderScript := preload("res://systems/model_loader.gd")
const PhysicsInspectorScript := preload("res://systems/physics_inspector.gd")
const SalesManagerScript := preload("res://systems/sales_manager.gd")

signal weapon_generated(weapon_scene: Node3D)
signal inspection_complete(weapon: RigidBody3D, bug_score: float, bug_details: Dictionary)
signal pitches_ready(options: Array)
signal sale_completed(success: bool, profit: int)

enum GameState { IDLE, GENERATING, INSPECTING, PITCHING }

var current_state: GameState = GameState.IDLE
var current_weapon: RigidBody3D = null

var _model_loader: Node = null
var _physics_inspector: Node = null
var _sales_manager: Node = null
var _current_npc: RefCounted = null

func _ready() -> void:
	_setup_model_loader()
	_setup_physics_inspector()
	_setup_sales_manager()
	_connect_signals()

	if OS.is_debug_build():
		print("GameManager initialized")

func _setup_model_loader() -> void:
	_model_loader = ModelLoaderScript.new()
	add_child(_model_loader)

func _setup_physics_inspector() -> void:
	_physics_inspector = PhysicsInspectorScript.new()
	add_child(_physics_inspector)

func _setup_sales_manager() -> void:
	_sales_manager = SalesManagerScript.new()
	add_child(_sales_manager)

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

	if _sales_manager:
		_sales_manager.pitches_generated.connect(_on_pitches_generated)
		_sales_manager.sale_attempted.connect(_on_sale_attempted)

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

	_generate_sales_pitch(bug_score)

func _generate_sales_pitch(bug_score: float) -> void:
	if not _sales_manager:
		push_error("SalesManager not initialized")
		return

	_current_npc = _sales_manager.create_random_npc()

	if OS.is_debug_build():
		print("NPC: %s (%s) | Gullibility: %.2f" % [_current_npc.npc_name, _current_npc.personality, _current_npc.gullibility])

	_sales_manager.generate_pitch_options(bug_score, "weapon", _current_npc)

func _on_pitches_generated(options: Array) -> void:
	pitches_ready.emit(options)

	if OS.is_debug_build() and not options.is_empty():
		var first_pitch = options[0]
		print("Pitch generated: %s (%.0f%% success rate)" % [first_pitch.pitch_type, first_pitch.success_rate * 100])

func _on_sale_attempted(pitch_type: String, success: bool, final_price: int) -> void:
	var profit := final_price if success else 0
	sale_completed.emit(success, profit)

	if OS.is_debug_build():
		print("Sale result: %s | Profit: %d" % ["SUCCESS" if success else "FAILED", profit])

	set_state(GameState.IDLE)
	clear_weapon()

func attempt_sale(pitch_option) -> void:
	if not _sales_manager:
		push_error("SalesManager not initialized")
		return

	if current_state != GameState.PITCHING:
		push_error("Cannot attempt sale in state: %s" % GameState.keys()[current_state])
		return

	_sales_manager.attempt_sale(pitch_option)

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

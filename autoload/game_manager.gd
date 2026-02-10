extends Node
## Game state manager singleton - Combat Loop MVP

const ModelLoaderScript := preload("res://systems/model_loader.gd")

signal crafting_started(materials: Array)
signal weapon_ready(weapon: RigidBody3D)
signal combat_started
signal monster_killed(monster: Node)
signal loot_collected(material: Node)
signal state_changed(new_state: String)

enum GameState { IDLE, CRAFTING, GENERATING_WEAPON, COMBAT, LOOTING }

var current_state: GameState = GameState.IDLE
var current_weapon: RigidBody3D = null
var _model_loader: Node = null

func _ready() -> void:
	_setup_model_loader()
	_connect_signals()

	if OS.is_debug_build():
		print("GameManager initialized (Combat Loop MVP)")

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

## Start crafting with selected materials
func start_crafting(materials: Array) -> void:
	if current_state != GameState.IDLE:
		push_error("Cannot craft in state: %s" % GameState.keys()[current_state])
		return

	if materials.size() < 2:
		push_error("Need at least 2 materials to craft")
		return

	set_state(GameState.CRAFTING)
	crafting_started.emit(materials)

## Request weapon generation from CraftingSystem prompt
func request_weapon(prompt: String) -> void:
	if current_state != GameState.CRAFTING:
		push_error("Cannot request weapon in state: %s" % GameState.keys()[current_state])
		return

	set_state(GameState.GENERATING_WEAPON)
	APIClient.request_model(prompt)

## Transition to combat when weapon equipped
func start_combat() -> void:
	if not current_weapon:
		push_error("No weapon equipped for combat")
		return

	set_state(GameState.COMBAT)
	combat_started.emit()

## Report monster killed, transition to looting
func report_monster_killed(monster: Node) -> void:
	if current_state != GameState.COMBAT:
		return

	set_state(GameState.LOOTING)
	monster_killed.emit(monster)

	if OS.is_debug_build():
		print("Monster killed, entering LOOTING state")

## Report material collected
func collect_material(material: Node) -> void:
	loot_collected.emit(material)

	if OS.is_debug_build():
		print("Material collected")

## Complete looting phase, return to IDLE
func complete_looting() -> void:
	if current_state != GameState.LOOTING:
		return

	set_state(GameState.IDLE)

	if OS.is_debug_build():
		print("Looting complete, returning to IDLE")

func _on_model_ready(glb_path: String) -> void:
	if current_state != GameState.GENERATING_WEAPON:
		return

	if OS.is_debug_build():
		print("Model ready, loading: %s" % glb_path)

	if not _model_loader:
		push_error("ModelLoader not initialized")
		return

	_model_loader.load_weapon(glb_path)

func _on_weapon_spawned(weapon: RigidBody3D) -> void:
	clear_weapon()
	current_weapon = weapon
	weapon_ready.emit(weapon)

	if OS.is_debug_build():
		print("Weapon spawned, ready for combat")

func _on_load_failed(error_msg: String) -> void:
	push_error("Model loading failed: %s" % error_msg)
	set_state(GameState.IDLE)

func set_state(new_state: GameState) -> void:
	if current_state == new_state:
		return

	current_state = new_state
	var state_name: String = GameState.keys()[new_state]
	state_changed.emit(state_name)

	if OS.is_debug_build():
		print("State: %s" % state_name)

func clear_weapon() -> void:
	if not current_weapon:
		return
	current_weapon.queue_free()
	current_weapon = null

func get_state_name() -> String:
	return GameState.keys()[current_state]

func is_idle() -> bool:
	return current_state == GameState.IDLE

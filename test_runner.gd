extends Node3D
## Test Runner for Block A, B & C

var _tests_passed: int = 0
var _tests_failed: int = 0

# Autoload references
@onready var game_manager: Node = get_node("/root/GameManager")
@onready var api_client: Node = get_node("/root/APIClient")

# Test state
var _validation_error: String = ""
var _api_success: bool = false
var _api_error: String = ""
var _api_completed: bool = false
var _model_path: String = ""

# Block C state
var _weapon_spawned: bool = false
var _spawned_weapon: RigidBody3D = null


func _ready() -> void:
	await get_tree().process_frame

	print("\n" + "=".repeat(50))
	print("🧪 CHAOS FORGE TEST SUITE")
	print("=".repeat(50) + "\n")

	await _run_block_a_tests()
	await _run_block_b_and_c_tests()

	_print_summary()


## Block A: Core Infrastructure Tests
func _run_block_a_tests() -> void:
	print("📦 BLOCK A: Core Infrastructure\n")

	_test("GameManager singleton exists", func(): return game_manager != null)
	_test("GameManager initial state is IDLE", func():
		return game_manager.current_state == game_manager.GameState.IDLE
	)
	_test("GameManager state transition works", func():
		var old_state = game_manager.current_state
		game_manager.set_state(game_manager.GameState.GENERATING)
		var success = game_manager.current_state == game_manager.GameState.GENERATING
		game_manager.set_state(old_state)
		return success
	)
	_test("APIClient singleton exists", func(): return api_client != null)
	_test("APIClient has model_ready signal", func(): return api_client.has_signal("model_ready"))
	_test("APIClient has request_failed signal", func(): return api_client.has_signal("request_failed"))
	_test("Camera3D exists in scene", func(): return get_node_or_null("Camera3D") != null)
	_test("DirectionalLight3D exists in scene", func(): return get_node_or_null("DirectionalLight3D") != null)
	_test("Table (CSGBox3D) exists in scene", func(): return get_node_or_null("Table") != null)

	# Block C prerequisites
	_test("GameManager has ModelLoader", func():
		return game_manager.get("_model_loader") != null
	)

	print("")


## Block B + C: API + Model Loading (combined for efficiency)
func _run_block_b_and_c_tests() -> void:
	print("🔌 BLOCK B: Tripo API Integration\n")

	# Test 1: Short prompt rejection
	print("  Testing prompt validation...")
	_validation_error = ""
	api_client.request_failed.connect(_on_validation_failed)
	api_client.request_model("abc")
	api_client.request_failed.disconnect(_on_validation_failed)

	if _validation_error != "":
		print("    Received: %s" % _validation_error)
	_test("Rejects prompt < 10 chars", func(): return _validation_error.find("short") >= 0)

	# Test 2: Real API call + Model Loading
	print("\n  🌐 Testing API + Model Loading pipeline...")
	print("  (This may take 60-120 seconds)\n")

	_api_success = false
	_api_error = ""
	_api_completed = false
	_model_path = ""
	_weapon_spawned = false
	_spawned_weapon = null

	api_client.model_ready.connect(_on_model_ready)
	api_client.request_failed.connect(_on_api_failed)
	game_manager.weapon_generated.connect(_on_weapon_generated)

	api_client.request_model("a simple glowing crystal gemstone")

	# Wait for full pipeline (API + load + spawn)
	var elapsed := 0.0
	while not _weapon_spawned and elapsed < 150.0:
		await get_tree().create_timer(1.0).timeout
		elapsed += 1.0
		if int(elapsed) % 10 == 0:
			print("  ⏳ Waiting... %.0fs" % elapsed)
		# Check if download completed but spawn failed
		if _api_completed and not _weapon_spawned and elapsed > 10:
			await get_tree().create_timer(5.0).timeout
			break

	api_client.model_ready.disconnect(_on_model_ready)
	api_client.request_failed.disconnect(_on_api_failed)
	game_manager.weapon_generated.disconnect(_on_weapon_generated)

	# Block B results
	if not _api_completed:
		_record_result(false, "API request timeout")
	elif _api_success:
		_record_result(true, "API call + Download successful")
	else:
		_record_result(false, "API failed: %s" % _api_error)

	# Block C results
	print("\n🔧 BLOCK C: Model Loading\n")

	_test("Weapon spawned in scene", func(): return _weapon_spawned)
	_test("Weapon is RigidBody3D", func(): return _spawned_weapon is RigidBody3D)
	_test("Weapon has collision shape", func():
		if not _spawned_weapon:
			return false
		for child in _spawned_weapon.get_children():
			if child is CollisionShape3D:
				return true
		return false
	)
	_test("Weapon has mesh", func():
		if not _spawned_weapon:
			return false
		return _find_mesh(_spawned_weapon) != null
	)
	_test("GameManager state is INSPECTING", func():
		return game_manager.current_state == game_manager.GameState.INSPECTING
	)
	_test("GameManager.current_weapon set", func():
		return game_manager.current_weapon == _spawned_weapon
	)

	print("")


func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _find_mesh(child)
		if found:
			return found
	return null


# Signal handlers
func _on_validation_failed(msg: String) -> void:
	_validation_error = msg


func _on_model_ready(path: String) -> void:
	_api_success = true
	_api_completed = true
	_model_path = path
	print("  ✅ Model downloaded: %s" % path)


func _on_api_failed(msg: String) -> void:
	_api_error = msg
	_api_completed = true
	print("  ❌ API error: %s" % msg)


func _on_weapon_generated(weapon: Node3D) -> void:
	_weapon_spawned = true
	if weapon is RigidBody3D:
		_spawned_weapon = weapon
	print("  ✅ Weapon spawned in scene")


## Test helpers
func _test(name: String, check: Callable) -> void:
	var passed = check.call()
	_record_result(passed, name)


func _record_result(passed: bool, name: String) -> void:
	if passed:
		_tests_passed += 1
		print("  ✅ %s" % name)
	else:
		_tests_failed += 1
		print("  ❌ %s" % name)


func _print_summary() -> void:
	print("\n" + "=".repeat(50))
	print("📊 TEST SUMMARY")
	print("=".repeat(50))
	print("  Passed: %d" % _tests_passed)
	print("  Failed: %d" % _tests_failed)
	print("  Total:  %d" % (_tests_passed + _tests_failed))
	print("=".repeat(50))

	if _tests_failed == 0:
		print("🎉 ALL TESTS PASSED!")
	else:
		print("⚠️  Some tests failed.")

	print("\nExiting in 3 seconds...")
	await get_tree().create_timer(3.0).timeout
	get_tree().quit()

extends Node3D
## Test Runner for Dimension Smuggler MVP

var _tests_passed: int = 0
var _tests_failed: int = 0

# Autoload references
@onready var game_manager: Node = get_node("/root/GameManager")
@onready var api_client: Node = get_node("/root/APIClient")

# Scene references
@onready var ragdoll_npc: Node3D = get_node_or_null("RagdollNPC")

# Test state
var _weapon_spawned: bool = false
var _spawned_weapon: RigidBody3D = null
var _test_started: bool = false


func _ready() -> void:
	await get_tree().process_frame

	print("\n" + "=".repeat(50))
	print("🧪 DIMENSION SMUGGLER MVP TEST SUITE")
	print("=".repeat(50) + "\n")

	await _run_infrastructure_tests()
	await _run_ragdoll_tests()
	await _run_api_tests()

	_print_summary()


## Infrastructure Tests
func _run_infrastructure_tests() -> void:
	print("📦 INFRASTRUCTURE\n")

	_test("GameManager singleton exists", func(): return game_manager != null)
	_test("GameManager initial state is IDLE", func():
		return game_manager.current_state == game_manager.GameState.IDLE
	)
	_test("GameManager has new state enum", func():
		return game_manager.GameState.has("TESTING") and game_manager.GameState.has("REACTING")
	)
	_test("APIClient singleton exists", func(): return api_client != null)
	_test("APIClient has model_ready signal", func(): return api_client.has_signal("model_ready"))
	_test("Camera3D exists in scene", func(): return get_node_or_null("Camera3D") != null)
	_test("DirectionalLight3D exists in scene", func(): return get_node_or_null("DirectionalLight3D") != null)
	_test("Table (CSGBox3D) exists in scene", func(): return get_node_or_null("Table") != null)
	_test("GameManager has ModelLoader", func():
		return game_manager.get("_model_loader") != null
	)
	_test("GameManager has weapon_ready_for_test signal", func():
		return game_manager.has_signal("weapon_ready_for_test")
	)
	_test("GameManager has ragdoll_reaction signal", func():
		return game_manager.has_signal("ragdoll_reaction")
	)

	print("")


## Ragdoll NPC Tests
func _run_ragdoll_tests() -> void:
	print("🎭 RAGDOLL NPC\n")

	_test("RagdollNPC exists in scene", func(): return ragdoll_npc != null)
	_test("RagdollNPC has RagdollNPC class", func():
		return ragdoll_npc and ragdoll_npc.get_script() != null
	)
	_test("RagdollNPC has pelvis", func():
		return ragdoll_npc and ragdoll_npc.get_node_or_null("Pelvis") != null
	)
	_test("RagdollNPC has spine", func():
		return ragdoll_npc and ragdoll_npc.get_node_or_null("Pelvis/Spine") != null
	)
	_test("RagdollNPC has right arm", func():
		return ragdoll_npc and ragdoll_npc.get_node_or_null("Pelvis/Spine/RightArm") != null
	)
	_test("RagdollNPC has grab_weapon method", func():
		return ragdoll_npc and ragdoll_npc.has_method("grab_weapon")
	)
	_test("RagdollNPC has stability signals", func():
		return ragdoll_npc and ragdoll_npc.has_signal("stability_changed") and ragdoll_npc.has_signal("toppled")
	)
	_test("RagdollNPC initial state is STABLE", func():
		if not ragdoll_npc or not ragdoll_npc.has_method("is_stable"):
			return false
		return ragdoll_npc.is_stable()
	)

	print("")


## API + Weapon Generation Tests
func _run_api_tests() -> void:
	print("🔌 API + WEAPON GENERATION\n")

	# Test prompt validation
	print("  Testing prompt validation...")
	var _validation_error: String = ""
	api_client.request_failed.connect(func(msg): _validation_error = msg)
	api_client.request_model("abc")

	await get_tree().process_frame
	if _validation_error != "":
		print("    Received: %s" % _validation_error)
	_test("Rejects prompt < 10 chars", func(): return _validation_error.find("short") >= 0)

	# Test weapon generation pipeline
	print("\n  🌐 Testing weapon generation pipeline...")
	print("  (This may take 60-120 seconds)\n")

	_weapon_spawned = false
	_spawned_weapon = null
	_test_started = false

	game_manager.weapon_generated.connect(_on_weapon_generated)
	game_manager.weapon_ready_for_test.connect(_on_test_started)

	game_manager.request_weapon("a simple glowing crystal gemstone")

	# Wait for weapon generation
	var elapsed := 0.0
	while not _weapon_spawned and elapsed < 120.0:
		await get_tree().create_timer(1.0).timeout
		elapsed += 1.0
		if int(elapsed) % 10 == 0:
			print("  ⏳ Waiting... %.0fs" % elapsed)

	game_manager.weapon_generated.disconnect(_on_weapon_generated)
	game_manager.weapon_ready_for_test.disconnect(_on_test_started)

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
	_test("GameManager.current_weapon set", func():
		return game_manager.current_weapon == _spawned_weapon
	)
	_test("State transitioned to TESTING", func():
		return _test_started
	)
	_test("GameManager state is TESTING", func():
		return game_manager.current_state == game_manager.GameState.TESTING
	)

	print("")


func _on_weapon_generated(weapon: Node3D) -> void:
	_weapon_spawned = true
	if weapon is RigidBody3D:
		_spawned_weapon = weapon
	print("  ✅ Weapon spawned in scene")


func _on_test_started(_weapon: RigidBody3D) -> void:
	_test_started = true
	print("  ✅ Test phase started")


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

extends Node
## Test suite for PhysicsInspector

const PhysicsInspectorScript := preload("res://systems/physics_inspector.gd")

var inspector: Node = null
var test_weapon: RigidBody3D = null
var test_scene: Node3D = null

func _ready() -> void:
	_setup_test_environment()
	_run_all_tests()
	get_tree().quit()

func _setup_test_environment() -> void:
	test_scene = Node3D.new()
	add_child(test_scene)

	inspector = PhysicsInspectorScript.new()
	test_scene.add_child(inspector)

	inspector.inspection_complete.connect(_on_inspection_complete)

	print("=== PhysicsInspector Test Suite ===")

func _create_test_weapon() -> RigidBody3D:
	var weapon := RigidBody3D.new()
	weapon.mass = 1.0
	weapon.position = Vector3(0, 2, 0)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.5, 0.5, 0.5)
	collision.shape = shape
	weapon.add_child(collision)

	test_scene.add_child(weapon)
	return weapon

func _run_all_tests() -> void:
	_test_inspector_initialization()
	_test_start_inspection()
	_test_invalid_weapon_handling()
	_test_inspection_duration()

func _test_inspector_initialization() -> void:
	var test_name := "Inspector Initialization"
	if not inspector:
		_fail_test(test_name, "Inspector not created")
		return

	if inspector.tracked_body != null:
		_fail_test(test_name, "tracked_body should be null initially")
		return

	if inspector.jitter_count != 0:
		_fail_test(test_name, "jitter_count should be 0 initially")
		return

	_pass_test(test_name)

func _test_start_inspection() -> void:
	var test_name := "Start Inspection"
	test_weapon = _create_test_weapon()

	if not test_weapon:
		_fail_test(test_name, "Failed to create test weapon")
		return

	inspector.start_inspection(test_weapon)

	if inspector.tracked_body != test_weapon:
		_fail_test(test_name, "Weapon not tracked after start_inspection")
		return

	if inspector.initial_position != test_weapon.global_position:
		_fail_test(test_name, "Initial position not recorded")
		return

	_pass_test(test_name)
	_cleanup_weapon()

func _test_invalid_weapon_handling() -> void:
	var test_name := "Invalid Weapon Handling"

	inspector.start_inspection(null)

	if inspector.tracked_body != null:
		_fail_test(test_name, "Should not track null weapon")
		return

	_pass_test(test_name)

func _test_inspection_duration() -> void:
	var test_name := "Inspection Duration"
	test_weapon = _create_test_weapon()

	inspector.start_inspection(test_weapon)

	var timeout := 5.0
	var start_time := Time.get_ticks_msec() / 1000.0

	while Time.get_ticks_msec() / 1000.0 - start_time < timeout:
		await get_tree().process_frame

	_pass_test(test_name)
	_cleanup_weapon()

func _on_inspection_complete(weapon: RigidBody3D, bug_score: float, bug_details: Dictionary) -> void:
	print("  Inspection Complete Callback:")
	print("    Bug Score: %.3f" % bug_score)
	print("    Jitter: %.1f" % bug_details.jitter_score)
	print("    Drift: %.1f" % bug_details.drift_score)
	print("    Clip: %.1f" % bug_details.clip_score)
	print("    Max Velocity: %.2f" % bug_details.max_velocity)

func _pass_test(test_name: String) -> void:
	print("[PASS] %s" % test_name)

func _fail_test(test_name: String, reason: String) -> void:
	print("[FAIL] %s: %s" % [test_name, reason])

func _cleanup_weapon() -> void:
	if test_weapon and is_instance_valid(test_weapon):
		test_weapon.queue_free()
		test_weapon = null

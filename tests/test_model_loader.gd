extends Node
## Integration test for Block C (Model Loading System)

const ModelLoaderScript := preload("res://systems/model_loader.gd")

var _loader: Node = null
var _test_passed := false
var _test_result := ""

func _ready() -> void:
	print("=== Block C Integration Test ===")
	_run_test()

func _run_test() -> void:
	_loader = ModelLoaderScript.new()
	add_child(_loader)

	_loader.connect("weapon_spawned", _on_weapon_spawned)
	_loader.connect("load_failed", _on_load_failed)

	print("✓ ModelLoader instantiated")
	print("✓ Signals connected")

	# Verify class exports
	var expected_signals := ["weapon_spawned", "load_failed"]
	for sig_name in expected_signals:
		var found := false
		for signal_data in _loader.get_signal_list():
			if signal_data["name"] == sig_name:
				found = true
				break
		if not found:
			_fail("Missing signal: %s" % sig_name)
			return

	print("✓ All signals present")

	# Check table finding logic
	if _loader.has_method("_find_table_position"):
		print("✓ Table position finder exists")
	else:
		_fail("Missing _find_table_position method")
		return

	_test_passed = true
	_test_result = "Block C structure validated successfully"
	_print_results()

func _on_weapon_spawned(weapon: RigidBody3D) -> void:
	print("✓ Weapon spawned: %s" % weapon)

func _on_load_failed(error_msg: String) -> void:
	print("⚠ Load failed: %s" % error_msg)

func _fail(reason: String) -> void:
	_test_passed = false
	_test_result = "FAILED: %s" % reason
	_print_results()

func _print_results() -> void:
	print("\n=== Test Results ===")
	if _test_passed:
		print("✓ PASSED: %s" % _test_result)
	else:
		print("✗ FAILED: %s" % _test_result)
	print("====================\n")

	get_tree().quit()

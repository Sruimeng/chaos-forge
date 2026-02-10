extends Node
## Test suite for SalesManager pitch generation and sale resolution

const SalesManagerScript := preload("res://systems/sales_manager.gd")

var _sales_manager: SalesManager = null
var _test_results: Array[String] = []

func _ready() -> void:
	_sales_manager = SalesManagerScript.new()
	add_child(_sales_manager)

	await get_tree().create_timer(0.5).timeout

	_run_tests()

func _run_tests() -> void:
	print("\n=== SalesManager Test Suite ===\n")

	_test_npc_creation()
	_test_pitch_generation_premium()
	_test_pitch_generation_exotic()
	_test_pitch_generation_discount()
	_test_success_rate_calculation()
	_test_price_multipliers()

	print("\n=== Test Results ===")
	for result in _test_results:
		print(result)

	print("\nTests completed. Press Ctrl+C to exit.")

func _test_npc_creation() -> void:
	var npc := _sales_manager.create_random_npc()

	var passed := npc != null and npc.gullibility >= 0.3 and npc.gullibility <= 0.9

	_log_result("NPC Creation", passed)

	if passed and OS.is_debug_build():
		print("  Created NPC: %s (%s) | Gullibility: %.2f" % [npc.npc_name, npc.personality, npc.gullibility])

func _test_pitch_generation_premium() -> void:
	var npc := SalesManager.NPCProfile.new("Test Buyer", "neutral", 0.8, 100)
	var bug_level := 0.1

	var pitches := _sales_manager.generate_pitch_options(bug_level, "test_weapon", npc)

	var passed := not pitches.is_empty() and pitches[0].pitch_type == "premium"

	_log_result("Pitch Generation (Premium)", passed)

	if passed and OS.is_debug_build():
		print("  Generated: %s | Success Rate: %.0f%%" % [pitches[0].pitch_type, pitches[0].success_rate * 100])

func _test_pitch_generation_exotic() -> void:
	var npc := SalesManager.NPCProfile.new("Test Buyer", "neutral", 0.6, 100)
	var bug_level := 0.35

	var pitches := _sales_manager.generate_pitch_options(bug_level, "test_weapon", npc)

	var passed := not pitches.is_empty() and pitches[0].pitch_type == "exotic"

	_log_result("Pitch Generation (Exotic)", passed)

	if passed and OS.is_debug_build():
		print("  Generated: %s | Success Rate: %.0f%%" % [pitches[0].pitch_type, pitches[0].success_rate * 100])

func _test_pitch_generation_discount() -> void:
	var npc := SalesManager.NPCProfile.new("Test Buyer", "neutral", 0.5, 100)
	var bug_level := 0.75

	var pitches := _sales_manager.generate_pitch_options(bug_level, "test_weapon", npc)

	var passed := not pitches.is_empty() and pitches[0].pitch_type == "discount"

	_log_result("Pitch Generation (Discount)", passed)

	if passed and OS.is_debug_build():
		print("  Generated: %s | Success Rate: %.0f%%" % [pitches[0].pitch_type, pitches[0].success_rate * 100])

func _test_success_rate_calculation() -> void:
	var npc := SalesManager.NPCProfile.new("Test Buyer", "gullible", 0.85, 100)
	var bug_level := 0.3

	var pitches := _sales_manager.generate_pitch_options(bug_level, "test_weapon", npc)

	var passed := not pitches.is_empty() and pitches[0].success_rate >= 0.1 and pitches[0].success_rate <= 0.9

	_log_result("Success Rate Bounds", passed)

	if passed and OS.is_debug_build():
		print("  Success Rate: %.2f (within [0.1, 0.9])" % pitches[0].success_rate)

func _test_price_multipliers() -> void:
	var npc := SalesManager.NPCProfile.new("Test Buyer", "neutral", 0.6, 100)

	var premium_pitches := _sales_manager.generate_pitch_options(0.1, "weapon", npc)
	var discount_pitches := _sales_manager.generate_pitch_options(0.8, "weapon", npc)

	var passed := false

	if not premium_pitches.is_empty() and not discount_pitches.is_empty():
		passed = premium_pitches[0].price_multiplier > discount_pitches[0].price_multiplier

	_log_result("Price Multiplier Logic", passed)

	if passed and OS.is_debug_build():
		print("  Premium: %.2fx | Discount: %.2fx" % [premium_pitches[0].price_multiplier, discount_pitches[0].price_multiplier])

func _log_result(test_name: String, passed: bool) -> void:
	var status := "[PASS]" if passed else "[FAIL]"
	_test_results.append("%s %s" % [status, test_name])

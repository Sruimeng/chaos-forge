class_name SalesManager
extends Node
## Generates contextual sales pitches and handles sale resolution

const PitchDatabaseScript := preload("res://data/pitch_database.gd")

signal pitches_generated(options: Array)
signal sale_attempted(pitch_type: String, success: bool, final_price: int)

const BASE_PRICE: int = 100

class PitchOption:
	var text: String
	var pitch_type: String  # premium/exotic/discount
	var risk_level: float
	var price_multiplier: float
	var success_rate: float

	func _init(p_text: String, p_type: String, p_risk: float, p_mult: float, p_success: float) -> void:
		text = p_text
		pitch_type = p_type
		risk_level = p_risk
		price_multiplier = p_mult
		success_rate = p_success

class NPCProfile:
	var npc_name: String
	var personality: String  # skeptical/gullible/neutral
	var gullibility: float   # 0.3-0.9
	var budget: int

	func _init(p_name: String, p_personality: String, p_gullibility: float, p_budget: int) -> void:
		npc_name = p_name
		personality = p_personality
		gullibility = p_gullibility
		budget = p_budget

var _pitch_db: Node = null
var _current_npc: NPCProfile = null

func _ready() -> void:
	_pitch_db = PitchDatabaseScript.new()
	add_child(_pitch_db)

func generate_pitch_options(bug_level: float, weapon_type: String, npc: NPCProfile) -> Array:
	if not _pitch_db:
		push_error("PitchDatabase not initialized")
		return []

	_current_npc = npc
	var options: Array = []

	var angle := _select_pitch_angle(bug_level)
	var templates: Array = _pitch_db.get_pitch_templates(npc.personality, angle)

	if templates.is_empty():
		if OS.is_debug_build():
			print("No templates for personality: %s, angle: %s" % [npc.personality, angle])
		return []

	var selected_template: String = templates.pick_random()
	var pitch_text := _format_pitch(selected_template, weapon_type, bug_level)

	var multiplier := _calculate_price_multiplier(angle, bug_level)
	var success_rate := _calculate_success_rate(bug_level, npc.gullibility, angle)

	var option := PitchOption.new(
		pitch_text,
		angle,
		bug_level,
		multiplier,
		success_rate
	)

	options.append(option)

	pitches_generated.emit(options)
	return options

func attempt_sale(pitch: PitchOption) -> bool:
	if not _current_npc:
		push_error("No NPC profile set")
		return false

	var sale_success := randf() < pitch.success_rate
	var final_price := _calculate_final_price(pitch.price_multiplier)

	sale_attempted.emit(pitch.pitch_type, sale_success, final_price)

	if OS.is_debug_build():
		print("Sale attempt: %s | Success: %s | Price: %d" % [pitch.pitch_type, sale_success, final_price])

	return sale_success

func _select_pitch_angle(bug_level: float) -> String:
	if bug_level < 0.2:
		return "premium"

	if bug_level < 0.5:
		return "exotic"

	return "discount"

func _format_pitch(template: String, weapon_type: String, bug_level: float) -> String:
	var euphemism: String = _pitch_db.get_euphemism(bug_level) if _pitch_db else "special feature"

	var formatted := template.format({
		"weapon_name": weapon_type,
		"bug_euphemism": euphemism
	})

	return formatted

func _calculate_price_multiplier(angle: String, bug_level: float) -> float:
	match angle:
		"premium":
			return 1.5 - (bug_level * 0.2)
		"exotic":
			return 1.2 - (bug_level * 0.3)
		"discount":
			return 0.7 - (bug_level * 0.4)
		_:
			return 1.0

func _calculate_success_rate(bug_level: float, gullibility: float, angle: String) -> float:
	var base_rate := gullibility
	var bug_penalty := bug_level * 0.6

	var pitch_bonus := 0.2 if angle == "exotic" else 0.0

	return clampf(base_rate - bug_penalty + pitch_bonus, 0.1, 0.9)

func _calculate_final_price(multiplier: float) -> int:
	return int(BASE_PRICE * multiplier)

func create_random_npc() -> NPCProfile:
	var personalities: Array[String] = ["skeptical", "gullible", "neutral"]
	var names: Array[String] = ["Grizzled Veteran", "Wide-Eyed Novice", "Seasoned Merchant", "Curious Collector"]

	var personality: String = personalities.pick_random()
	var gullibility: float

	match personality:
		"skeptical":
			gullibility = randf_range(0.3, 0.5)
		"gullible":
			gullibility = randf_range(0.7, 0.9)
		_:
			gullibility = randf_range(0.5, 0.7)

	return NPCProfile.new(
		names.pick_random(),
		personality,
		gullibility,
		randi_range(50, 200)
	)

class_name CraftingPanel
extends Control
## UI for material selection and weapon crafting

signal craft_requested(materials: Array, weapon_type: String)

@onready var material_container: HBoxContainer = $Panel/VBox/MaterialSlots
@onready var weapon_type_dropdown: OptionButton = $Panel/VBox/WeaponType
@onready var craft_button: Button = $Panel/VBox/CraftButton
@onready var progress_bar: ProgressBar = $Panel/VBox/ProgressBar
@onready var status_label: Label = $Panel/VBox/StatusLabel

var _selected_materials: Array[Dictionary] = []
var _material_slots: Array[Button] = []
var _player: Node = null

const MAX_MATERIALS: int = 3
const WEAPON_TYPES: Array[String] = ["sword", "axe", "hammer", "spear", "dagger", "staff"]


func _ready() -> void:
	_setup_weapon_types()
	_setup_material_slots()
	_connect_signals()

	hide_panel()

	if OS.is_debug_build():
		print("CraftingPanel ready")


func _setup_weapon_types() -> void:
	if not weapon_type_dropdown:
		return

	weapon_type_dropdown.clear()
	for wtype in WEAPON_TYPES:
		weapon_type_dropdown.add_item(wtype.capitalize())


func _setup_material_slots() -> void:
	if not material_container:
		return

	# Clear existing
	for child in material_container.get_children():
		child.queue_free()

	_material_slots.clear()

	# Create 3 material slot buttons
	for i in range(MAX_MATERIALS):
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(80, 80)
		slot.text = "Empty"
		slot.pressed.connect(_on_slot_pressed.bind(i))
		material_container.add_child(slot)
		_material_slots.append(slot)


func _connect_signals() -> void:
	if craft_button:
		craft_button.pressed.connect(_on_craft_pressed)

	# Connect to GameManager
	if GameManager:
		GameManager.state_changed.connect(_on_state_changed)
		GameManager.weapon_ready.connect(_on_weapon_ready)


func show_panel() -> void:
	_find_player()
	_refresh_slots()
	_update_craft_button()

	progress_bar.value = 0
	status_label.text = "Select materials to craft"

	visible = true


func hide_panel() -> void:
	visible = false


func _find_player() -> void:
	_player = get_tree().get_first_node_in_group("player")


func _refresh_slots() -> void:
	if not _player:
		return

	_selected_materials.clear()

	var inventory: Array = []
	if _player.has_method("get_inventory_count"):
		inventory = _player.inventory

	# Update slot display
	for i in range(_material_slots.size()):
		var slot: Button = _material_slots[i]
		if i < inventory.size():
			var mat: Dictionary = inventory[i]
			slot.text = mat.get("name", "?").substr(0, 10)
			slot.disabled = false
			slot.modulate = Color.WHITE
		else:
			slot.text = "Empty"
			slot.disabled = true
			slot.modulate = Color.DIM_GRAY


func _on_slot_pressed(index: int) -> void:
	if not _player:
		return

	var inventory: Array = _player.inventory
	if index >= inventory.size():
		return

	var mat: Dictionary = inventory[index]
	var slot: Button = _material_slots[index]

	# Toggle selection
	if mat in _selected_materials:
		_selected_materials.erase(mat)
		slot.modulate = Color.WHITE
	else:
		if _selected_materials.size() < MAX_MATERIALS:
			_selected_materials.append(mat)
			slot.modulate = Color.GREEN

	_update_craft_button()


func _update_craft_button() -> void:
	var can_craft: bool = _selected_materials.size() >= 2

	if craft_button:
		craft_button.disabled = not can_craft
		craft_button.text = "Craft (%d)" % _selected_materials.size() if can_craft else "Select 2+ Materials"


func _on_craft_pressed() -> void:
	if _selected_materials.size() < 2:
		return

	var weapon_type: String = WEAPON_TYPES[weapon_type_dropdown.selected]

	# Get CraftingSystem
	var crafting_system: Node = _get_or_create_crafting_system()
	if not crafting_system:
		status_label.text = "Error: CraftingSystem not found"
		return

	# Build prompt and request
	var prompt: String = crafting_system.build_prompt(_selected_materials, weapon_type)
	if prompt.is_empty():
		status_label.text = "Error: Invalid materials"
		return

	# Consume materials from player
	if _player and _player.has_method("consume_materials"):
		_player.consume_materials(_selected_materials.size())

	# Start crafting
	GameManager.start_crafting(_selected_materials)
	GameManager.request_weapon(prompt)

	craft_requested.emit(_selected_materials, weapon_type)

	# Update UI
	craft_button.disabled = true
	progress_bar.value = 0
	status_label.text = "Generating weapon..."

	# Start progress animation
	_animate_progress()


func _get_or_create_crafting_system() -> Node:
	var system: Node = get_tree().root.find_child("CraftingSystem", true, false)
	if system:
		return system

	var CraftingSystemScript := preload("res://systems/crafting_system.gd")
	system = CraftingSystemScript.new()
	system.name = "CraftingSystem"
	get_tree().root.add_child(system)
	return system


func _animate_progress() -> void:
	var tween := create_tween()
	tween.tween_property(progress_bar, "value", 90, 10.0)


func _on_state_changed(state: String) -> void:
	match state:
		"IDLE":
			status_label.text = "Ready to craft"
			_refresh_slots()
			_update_craft_button()
		"CRAFTING":
			status_label.text = "Preparing..."
		"GENERATING_WEAPON":
			status_label.text = "Forging weapon..."
		"COMBAT":
			hide_panel()


func _on_weapon_ready(_weapon: RigidBody3D) -> void:
	progress_bar.value = 100
	status_label.text = "Weapon ready!"

	# Auto-equip to player
	if _player and _player.has_method("equip_weapon"):
		_player.equip_weapon(_weapon)

	# Hide after delay
	get_tree().create_timer(1.0).timeout.connect(hide_panel)

	# Start combat
	GameManager.start_combat()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if visible:
			hide_panel()

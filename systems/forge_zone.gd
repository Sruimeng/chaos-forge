class_name ForgeZone
extends Area3D
## Triggers crafting UI when player enters

signal player_entered
signal player_exited

var _player_inside: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if OS.is_debug_build():
		print("ForgeZone ready")


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	_player_inside = true
	player_entered.emit()

	# Notify GameManager
	if GameManager and GameManager.is_idle():
		_show_crafting_hint()

	if OS.is_debug_build():
		print("Player entered forge zone")


func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	_player_inside = false
	player_exited.emit()

	if OS.is_debug_build():
		print("Player exited forge zone")


func _show_crafting_hint() -> void:
	# Find or create crafting panel
	var panel: Control = get_tree().root.find_child("CraftingPanel", true, false)
	if panel and panel.has_method("show_panel"):
		panel.show_panel()


func is_player_inside() -> bool:
	return _player_inside

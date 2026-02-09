class_name GameManager
extends Node

signal weapon_generated(weapon_scene: Node3D)
signal sale_completed(success: bool, profit: int)

enum GameState { IDLE, GENERATING, INSPECTING, PITCHING }

var current_state: GameState = GameState.IDLE
var current_weapon: RigidBody3D = null

func _ready() -> void:
	if OS.is_debug_build():
		print("GameManager initialized")

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

class_name PhysicsInspector
extends Node
## Real-time physics anomaly detector for weapon quality assessment

signal inspection_complete(weapon: RigidBody3D, bug_score: float, bug_details: Dictionary)

const THRESHOLD_JITTER: float = 10.0
const THRESHOLD_DRIFT: float = 0.5
const THRESHOLD_CLIP: float = 0.1
const INSPECTION_DURATION: float = 3.0

var tracked_body: RigidBody3D = null
var prev_velocity: Vector3 = Vector3.ZERO
var initial_position: Vector3 = Vector3.ZERO
var spawn_time: float = 0.0

var jitter_count: int = 0
var drift_count: int = 0
var clip_count: int = 0
var max_velocity: float = 0.0
var contact_count: int = 0

var _elapsed_time: float = 0.0
var _is_active: bool = false

func start_inspection(weapon: RigidBody3D) -> void:
	if not weapon or not is_instance_valid(weapon):
		push_error("Invalid weapon passed to PhysicsInspector")
		return

	tracked_body = weapon
	initial_position = weapon.global_position
	prev_velocity = weapon.linear_velocity
	spawn_time = Time.get_ticks_msec() / 1000.0

	jitter_count = 0
	drift_count = 0
	clip_count = 0
	max_velocity = 0.0
	contact_count = 0
	_elapsed_time = 0.0
	_is_active = true

	set_physics_process(true)

	if OS.is_debug_build():
		print("PhysicsInspector: Started tracking weapon")

func stop_inspection() -> void:
	_is_active = false
	set_physics_process(false)
	tracked_body = null

func _ready() -> void:
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	if not _is_active:
		return

	if not tracked_body or not is_instance_valid(tracked_body):
		_finalize_inspection(true)
		return

	_elapsed_time += delta

	if _elapsed_time >= INSPECTION_DURATION:
		_finalize_inspection(false)
		return

	_detect_jitter(delta)
	_detect_drift()
	_detect_clipping()
	_track_velocity()

func _detect_jitter(delta: float) -> void:
	if delta <= 0.0:
		return

	var current_velocity := tracked_body.linear_velocity
	var velocity_delta := (current_velocity - prev_velocity).length()
	var jitter := velocity_delta / delta

	if jitter > THRESHOLD_JITTER:
		jitter_count += 1

	prev_velocity = current_velocity

func _detect_drift() -> void:
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	var time_since_spawn := _elapsed_time
	var expected_pos := initial_position + Vector3(0, -0.5 * gravity * time_since_spawn * time_since_spawn, 0)
	var actual_pos := tracked_body.global_position
	var drift := (actual_pos - expected_pos).length()

	if drift > THRESHOLD_DRIFT:
		drift_count += 1

func _detect_clipping() -> void:
	var colliding_bodies := tracked_body.get_colliding_bodies()

	if colliding_bodies.size() > 0:
		contact_count += colliding_bodies.size()

		for _body in colliding_bodies:
			var contact_count_local := tracked_body.get_contact_count()
			if contact_count_local > 0:
				clip_count += 1
				break

func _track_velocity() -> void:
	var speed := tracked_body.linear_velocity.length()
	if speed > max_velocity:
		max_velocity = speed

func _finalize_inspection(weapon_destroyed: bool) -> void:
	_is_active = false
	set_physics_process(false)

	if weapon_destroyed:
		if OS.is_debug_build():
			print("PhysicsInspector: Weapon destroyed during inspection")
		return

	var bug_score := _calculate_bug_score()
	var bug_details := _build_bug_details()

	if OS.is_debug_build():
		print("PhysicsInspector: Inspection complete - Bug Score: %.2f" % bug_score)
		print("  Jitter: %d, Drift: %d, Clip: %d" % [jitter_count, drift_count, clip_count])

	inspection_complete.emit(tracked_body, bug_score, bug_details)
	tracked_body = null

func _calculate_bug_score() -> float:
	var frame_count := _elapsed_time / get_physics_process_delta_time()
	if frame_count <= 0:
		return 0.0

	var jitter_norm: float = clamp(float(jitter_count) / frame_count, 0.0, 1.0)
	var drift_norm: float = clamp(float(drift_count) / frame_count, 0.0, 1.0)
	var clip_norm: float = clamp(float(clip_count) / frame_count, 0.0, 1.0)

	var bug_level: float = jitter_norm * 0.4 + drift_norm * 0.3 + clip_norm * 0.3
	return clamp(bug_level, 0.0, 1.0)

func _build_bug_details() -> Dictionary:
	return {
		"jitter_score": float(jitter_count),
		"drift_score": float(drift_count),
		"clip_score": float(clip_count),
		"max_velocity": max_velocity,
		"contact_count": contact_count
	}

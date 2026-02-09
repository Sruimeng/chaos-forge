---
id: constitution
type: reference
related_ids: [coordinate-system, physics-rules, rendering-baseline]
---

# Technical Constitution

> **Core technical constraints and mandatory patterns for Godot 4.x mobile development.**

## Coordinate System

```gdscript
# World Space: Y-up Right-Handed
# Forward: -Z
# Right: +X
# Up: +Y

const FORWARD := Vector3(0, 0, -1)
const RIGHT := Vector3(1, 0, 0)
const UP := Vector3(0, 1, 0)
```

**Rules:**
- Never mix coordinate conventions
- Physics queries use world-space by default
- Local transforms always relative to parent

## Physics Engine

```gdscript
# Jolt Physics Constraints
class_name PhysicsConfig

const GRAVITY: float = 9.8
const MAX_VELOCITY: float = 50.0
const COLLISION_MARGIN: float = 0.001

static func validate_body(body: RigidBody3D) -> bool:
    return body.mass > 0.0 and body.get_collision_layer() != 0
```

**Rules:**
- Static bodies: mass = 0
- Dynamic bodies: mass > 0
- Kinematic bodies: `motion_mode = MOTION_MODE_KINEMATIC`
- No direct `transform` manipulation on physics bodies during `_physics_process()`

## Rendering Pipeline

```gdscript
# Mobile Optimization Baseline
const MAX_LIGHTS_PER_SCENE: int = 4
const MAX_SHADOW_CASTERS: int = 2
const TARGET_DRAW_CALLS: int = 100
const MAX_VERTICES_PER_MESH: int = 5000

# Shader Feature Flags
const MOBILE_FEATURES := {
    "use_vertex_lighting": true,
    "disable_ambient_occlusion": true,
    "simplify_reflections": true,
}
```

**Rules:**
- Mobile renderer: Forward+ with clustering disabled
- Texture compression: ASTC (Android), ETC2 (fallback)
- Shadow atlas: 2048x2048 max
- No real-time GI on mobile

## Forbidden Patterns

### ❌ Deep Inheritance
```gdscript
# WRONG
class_name AbstractBaseEntity extends Node3D
class_name BaseCharacter extends AbstractBaseEntity
class_name Player extends BaseCharacter  # 3 levels deep

# CORRECT
class_name Player extends Node3D
```

### ❌ Bureaucratic Naming
```gdscript
# WRONG
class_name EntityManager
class_name PlayerHelper
class_name GameStateObject

# CORRECT
class_name EntityPool
class_name Player
class_name GameState
```

### ❌ Deep Nesting
```gdscript
# WRONG
func process_input(event: InputEvent) -> void:
    if event is InputEventKey:
        if event.pressed:
            if event.keycode == KEY_SPACE:
                if can_jump():
                    jump()

# CORRECT
func process_input(event: InputEvent) -> void:
    if not event is InputEventKey: return
    if not event.pressed: return
    if event.keycode != KEY_SPACE: return
    if not can_jump(): return
    jump()
```

### ❌ "What" Comments
```gdscript
# WRONG
# Loop through all enemies
for enemy in enemies:
    enemy.take_damage(10)  # Deal 10 damage

# CORRECT
# Poison damage ticks once per second
for enemy in poisoned_enemies:
    enemy.take_damage(POISON_DAMAGE_PER_TICK)
```

## Mandatory Patterns

### ✅ Composition Over Inheritance
```gdscript
class_name Character extends Node3D

@onready var health: HealthComponent = $HealthComponent
@onready var movement: MovementComponent = $MovementComponent
@onready var inventory: InventoryComponent = $InventoryComponent
```

### ✅ Signal-Driven Architecture
```gdscript
signal health_changed(old_value: int, new_value: int)
signal died()

func take_damage(amount: int) -> void:
    var old_hp := health
    health -= amount
    health_changed.emit(old_hp, health)
    if health <= 0:
        died.emit()
```

### ✅ Type-First Design
```gdscript
# All functions must have explicit types
func calculate_velocity(delta: float) -> Vector3:
    return velocity * delta

# All class variables must have type hints
var player_name: String = ""
var max_health: int = 100
var position_cache: Dictionary[int, Vector3] = {}
```

### ✅ Guard Clauses
```gdscript
func interact(target: Node3D) -> void:
    if not is_instance_valid(target): return
    if not target.has_method("on_interact"): return
    if distance_to(target) > interaction_range: return

    target.on_interact(self)
```

## Performance Constraints

```gdscript
# Frame Budget (60 FPS target)
const FRAME_TIME_MS: float = 16.67
const PHYSICS_TIME_BUDGET_MS: float = 8.0
const RENDER_TIME_BUDGET_MS: float = 8.0

# Object Pooling Thresholds
const POOL_BULLET_COUNT: int = 100
const POOL_VFX_COUNT: int = 50
const POOL_AUDIO_COUNT: int = 20
```

**Rules:**
- No allocations in hot paths (`_process`, `_physics_process`)
- Cache frequently accessed nodes with `@onready`
- Use object pools for frequently spawned/destroyed objects
- Profile with Godot's built-in profiler before optimizing

## Resource Naming

```
# Scene Files
player.tscn
enemy_goblin.tscn
weapon_sword.tscn

# Script Files
player.gd
health_component.gd
item_pickup.gd

# Asset Files
player_diffuse.png
ui_button_normal.png
sfx_footstep_01.wav
```

**Rules:**
- Use snake_case for all file names
- Prefix component scripts with functionality (e.g., `health_component.gd`)
- Suffix variations with descriptors (e.g., `enemy_goblin_ranged.tscn`)

## Error Handling

```gdscript
func load_save_file(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        push_warning("Save file not found: %s" % path)
        return {}

    var file := FileAccess.open(path, FileAccess.READ)
    if not file:
        push_error("Failed to open save file: %s" % path)
        return {}

    var data := JSON.parse_string(file.get_as_text())
    if not data is Dictionary:
        push_error("Invalid save data format")
        return {}

    return data
```

**Rules:**
- Use `push_warning()` for recoverable issues
- Use `push_error()` for critical failures
- Always return safe defaults
- Never crash on bad input

## Testing Protocol

```gdscript
# GdUnit4 Test Structure
class_name PlayerTest extends GdUnitTestSuite

func test_player_takes_damage() -> void:
    var player := Player.new()
    player.health = 100

    player.take_damage(20)

    assert_int(player.health).is_equal(80)

func test_player_dies_at_zero_health() -> void:
    var player := Player.new()
    var signal_monitor := monitor_signals(player)

    player.health = 10
    player.take_damage(10)

    assert_signal(signal_monitor).is_emitted("died")
```

**Rules:**
- Test public interfaces only
- One assertion per test (when possible)
- Use descriptive test names: `test_<action>_<expected_result>()`
- Mock external dependencies

## Version Control

**Commit Message Format:**
```
<type>: <subject>

<body>

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `perf`: Performance improvement
- `refactor`: Code restructure (no behavior change)
- `test`: Add/update tests
- `docs`: Documentation only

**Rules:**
- Subject line: imperative mood, lowercase, <50 chars
- Body: explain WHY, not WHAT
- Reference issue numbers when applicable

---

**Enforcement Level:** CRITICAL
**Last Updated:** 2026-02-09
**Maintainer:** Surveyor Agent

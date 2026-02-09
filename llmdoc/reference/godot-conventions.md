---
id: godot-conventions
type: reference
related_ids: [gdscript-patterns, scene-architecture]
---

# Godot Conventions

> **Summary:** GDScript 2.0 naming, signal protocol, and scene composition rules derived from implicit codebase patterns.

## Naming Conventions

```gdscript
# Variables & Functions: snake_case
var player_health: int = 100
func calculate_damage(amount: int) -> int:
    return amount * 2

# Constants: UPPER_SNAKE_CASE
const MAX_HEALTH: int = 100
const GRAVITY: float = 9.8

# Signals: past_tense
signal player_died
signal health_changed(new_value: int)
signal item_collected(item_name: String)

# Classes: PascalCase
class_name PlayerController
class_name InventorySystem

# Files: snake_case
# player_controller.gd
# inventory_system.gd
```

## Signal Protocol

**Declaration Order:**
```gdscript
class_name PlayerController
extends CharacterBody2D

# 1. Signals (top of file)
signal health_depleted
signal damage_taken(amount: int, source: Node)

# 2. Exports (@export variables)
@export var max_health: int = 100
@export var speed: float = 200.0

# 3. Public variables
var current_health: int

# 4. Private variables
var _is_invulnerable: bool = false
```

**Signal Naming Rules:**
- Past tense verb: `player_died`, not `player_die`
- Descriptive parameters: `(new_value: int)`, not `(val)`
- Emit from source of truth only

## Type Annotations

**Mandatory Static Typing:**
```gdscript
# Functions: always specify return type
func get_health() -> int:
    return current_health

func process_input() -> void:
    pass

# Variables: explicit type hints
var position: Vector2
var inventory: Array[Item]
var config: Dictionary = {}

# Inferred types allowed for literals
var count := 0  # int inferred
var name := "Player"  # String inferred
```

## Scene Architecture

**Composition Over Inheritance:**
```
Player (CharacterBody2D)
├── HealthComponent
├── MovementComponent
└── InputComponent
```

**Rules:**
- One scene = one responsibility
- Favor node composition over deep inheritance
- Communicate via signals between components
- Avoid cross-scene direct references

## Export Variables

**Position & Typing:**
```gdscript
class_name Enemy
extends CharacterBody2D

# Exports always at top (after signals)
@export_category("Combat")
@export var max_health: int = 50
@export var damage: int = 10

@export_category("Movement")
@export var patrol_speed: float = 100.0
@export var chase_speed: float = 200.0

# Never export without type
# ❌ @export var value  # FORBIDDEN
# ✅ @export var value: int  # CORRECT
```

## Critical Rules

- **Static Typing Enforced:** GDScript 2.0 requires type annotations for exports and function returns
- **Signal Scope:** Only emit signals you own; never emit parent's signals
- **Node Access:** Use `@onready var` for node references, never `get_node()` in `_ready()`
- **File Naming:** Must match class name: `PlayerController` → `player_controller.gd`
- **Scene Boundaries:** Components communicate via signals, not direct method calls
- **Constant Visibility:** Shared constants go in autoload singleton, not duplicated per-scene

## Anti-Patterns

```gdscript
# ❌ AVOID: Present tense signals
signal player_die  # Wrong
signal health_change  # Wrong

# ✅ USE: Past tense signals
signal player_died  # Correct
signal health_changed  # Correct

# ❌ AVOID: Untyped exports
@export var speed  # Breaks in Godot 4.x

# ✅ USE: Typed exports
@export var speed: float = 100.0

# ❌ AVOID: Deep inheritance
class Player extends Actor extends Entity extends Node2D

# ✅ USE: Composition
class Player extends CharacterBody2D:
    var health_component: HealthComponent
    var movement_component: MovementComponent
```

## File Organization

```
res://
├── entities/
│   ├── player/
│   │   ├── player.tscn
│   │   └── player.gd
│   └── enemy/
│       ├── enemy.tscn
│       └── enemy.gd
├── components/
│   ├── health_component.gd
│   └── movement_component.gd
└── autoload/
    └── game_events.gd  # Global signal bus
```

**Rationale:**
- Scenes grouped by entity type
- Reusable components in dedicated folder
- Autoloads for cross-scene communication
- One file per class (no nested classes in production)

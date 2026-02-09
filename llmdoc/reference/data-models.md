---
id: data-models
type: reference
related_ids: [tripo-integration, weapon-system, npc-order-system]
---

# Data Models

> **Core data structures for Tripo API integration and smuggling game mechanics.**

## Tripo API Models

```gdscript
# API Request
class_name TripoRequest
extends RefCounted

var prompt: String
var image_path: String = ""  # Optional reference image
var model_type: String = "default"  # default | detailed | lowpoly

func _init(p_prompt: String, p_image_path: String = "", p_model_type: String = "default"):
    prompt = p_prompt
    image_path = p_image_path
    model_type = p_model_type
```

```gdscript
# API Response
class_name TripoResponse
extends RefCounted

enum Status { PENDING, PROCESSING, COMPLETED, FAILED }

var task_id: String
var status: Status
var model_url: String = ""
var progress: float = 0.0  # 0.0 to 1.0

func is_complete() -> bool:
    return status == Status.COMPLETED
```

## Game Domain Models

```gdscript
# Weapon Contraband Metadata
class_name WeaponMetadata
extends Resource

@export var model_id: String
@export var prompt: String
@export var physics_state: Dictionary = {
    "jitter": 0.0,      # Dimensional instability
    "offset": Vector3.ZERO,
    "decay_rate": 0.0
}
@export var price: int = 100

func is_stable() -> bool:
    return physics_state.jitter < 0.5
```

```gdscript
# NPC Order Contract
class_name NPCOrder
extends Resource

@export var npc_id: String
@export var requirements: Array[String] = []  # Weapon trait keywords
@export var budget: int
@export var urgency: float = 1.0  # Multiplier for payment

func matches(weapon: WeaponMetadata) -> bool:
    for req in requirements:
        if req.to_lower() in weapon.prompt.to_lower():
            return true
    return false
```

## Critical Rules

**Tripo Integration:**
- `task_id` is persistent across sessions (store in save file).
- `Status.FAILED` requires retry logic with exponential backoff.

**Physics State:**
- `jitter >= 1.0` triggers dimensional collapse (weapon destroyed).
- `decay_rate` applied per frame: `jitter += decay_rate * delta`.

**Order Matching:**
- Case-insensitive keyword search in `prompt`.
- Payment = `budget * urgency`.
- Failed delivery = reputation penalty.

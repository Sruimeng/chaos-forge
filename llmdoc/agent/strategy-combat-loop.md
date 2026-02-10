---
id: strategy-combat-loop
type: strategy
description: Roguelike combat loop MVP - Monster-Material-Crafting cycle
status: active
updated: 2026-02-10
---

# Strategy: Roguelike Combat Loop MVP

## 1. Situational Awareness

**Context:** Convert "Dimension Smuggler" (Order → Generate → Test) into Roguelike loop (Kill → Loot → Craft → Repeat).

**Active Constitution:**
* **Technical:**
  - Reuse: `APIClient`, `ModelLoader` (proven async pipeline)
  - Physics: All entities = `RigidBody3D` (consistent collision)
  - Scene Root: `main.tscn` → Arena layout (no UI dependencies)
* **Style:** **Strict Adherence to `/llmdoc/guides/doc-standard.md`** (Type-First, No Meta-Narrative)
* **Security:** Input validation on crafting prompts (inherit `APIClient.FORBIDDEN_WORDS`)

## 2. Assessment

<Assessment>
**Complexity:** Level 3 (Core Architecture Refactor)
**Critical Risks:**
1. **Async Queue Race Condition** - Player crafts weapon while monster still generating
2. **Prompt Injection** - User-modified material names pollute Tripo prompts
3. **Physics Explosion** - 100+ material drops = FPS death
4. **State Desync** - Combat starts before weapon equipped
</Assessment>

## 3. Abstract Specification (The Logic)

> **MANDATORY Level 3 Spec.** This defines HOW the loop works, not WHERE the code goes.

<LogicSpec>

### 3.1 Game Loop State Machine

```
STATE IDLE:
  IF inventory.count >= 2:
    ENABLE forge_interaction
  ELSE:
    DISABLE forge_interaction

  ON player_enter_forge_zone:
    GOTO CRAFTING

STATE CRAFTING:
  materials = UI.select_materials(inventory, min=2, max=3)
  weapon_type = UI.select_weapon_type(["sword", "axe", "hammer", "spear"])

  prompt = crafting_system.build_prompt(materials, weapon_type)
  APIClient.request_model(prompt)

  # Critical: Start next monster generation in parallel
  spawner.queue_next_monster()

  GOTO GENERATING_WEAPON

STATE GENERATING_WEAPON:
  ON APIClient.model_ready:
    weapon = ModelLoader.load_weapon(glb_path)
    player.equip(weapon)
    GOTO COMBAT

STATE COMBAT:
  ON monster_spawner.ready:
    monster = spawner.get_queued_monster()
    arena.spawn_monster(monster)

  ON monster.died:
    materials = monster.explode_into_materials(count=3)
    FOR mat IN materials:
      arena.spawn_drop(mat, monster.position)
    GOTO LOOTING

STATE LOOTING:
  ON player.pickup_material(mat):
    inventory.add(mat)

  IF all_materials_picked:
    GOTO IDLE
```

### 3.2 Material → Prompt Translation

```
FUNCTION build_crafting_prompt(materials, weapon_type):
  # Sanitize material names (prevent injection)
  safe_names = []
  FOR mat IN materials:
    safe_name = sanitize(mat.material_name)  # Strip special chars
    safe_names.append(safe_name)

  # Combine element types for flavor
  elements = unique([mat.element_type FOR mat IN materials])
  element_modifier = JOIN(elements, " and ")  # "fire and ice"

  # Template structure
  prompt = "A {weapon_type}, forged from {material1}"
  IF materials.count > 1:
    prompt += " and {material2}"
  IF elements.count > 0:
    prompt += ", infused with {element_modifier} energy"

  # Quality based on material rarity (future extension)
  prompt += ", low-poly game asset style"

  RETURN prompt

FUNCTION sanitize(text):
  REMOVE chars NOT IN [a-zA-Z0-9 _-]
  LIMIT length to 50
  RETURN text
```

### 3.3 Async Monster Pre-Generation

```
CLASS MonsterSpawner:
  var queue: Array[MonsterData] = []
  var is_generating: bool = false

  FUNCTION queue_next_monster():
    IF is_generating OR queue.size() > 0:
      RETURN  # Already have one ready

    is_generating = true
    prompt = generate_random_monster_prompt()
    APIClient.request_model(prompt)

    ON APIClient.model_ready(glb_path):
      monster_data = MonsterData.new(glb_path)
      queue.append(monster_data)
      is_generating = false

  FUNCTION get_queued_monster() -> Monster:
    IF queue.empty():
      RETURN create_fallback_sphere_monster()  # Emergency backup

    data = queue.pop_front()
    monster = ModelLoader.load_monster(data.glb_path)

    # Start next generation immediately
    queue_next_monster()

    RETURN monster
```

### 3.4 Combat Collision Logic

```
# In weapon_instance.gd (existing)
EXTEND contact_monitor = true, max_contacts_reported = 4

ON body_entered(body):
  IF body.is_in_group("monster"):
    damage = calculate_damage(linear_velocity.length())
    body.take_damage(damage)

# In monster.gd (new)
FUNCTION take_damage(amount):
  hp -= amount
  IF hp <= 0:
    die()

FUNCTION die():
  emit_signal("died", self)
  queue_free()
```

</LogicSpec>

## 4. Execution Plan

<ExecutionPlan>

### Block A: State Machine Refactor

**A1. Modify `/Users/sruim/godot/autoload/game_manager.gd`**
- Change enum: `GameState { IDLE, CRAFTING, GENERATING_WEAPON, COMBAT, LOOTING }`
- Remove: `ORDERING`, `TESTING`, `REACTING` (old NPC flow)
- Add signals: `combat_started`, `monster_died`, `materials_collected`
- **Constraint:** Preserve `APIClient` connection pattern (line 34)

**A2. Create `/Users/sruim/godot/systems/crafting_system.gd`**
- Rename from `order_generator.gd` (git mv)
- Replace `OrderRequest` class with:
  ```gdscript
  class CraftingRecipe:
    var materials: Array[MaterialDrop]
    var weapon_type: String
    var combined_prompt: String
  ```
- Implement `build_prompt()` from LogicSpec 3.2
- **Constraint:** Reuse `FORBIDDEN_WORDS` from `APIClient` (line 7)

### Block B: Entity Creation

**B1. Create `/Users/sruim/godot/entities/monster.gd`**
- Extends: `RigidBody3D`
- Properties:
  ```gdscript
  @export var max_hp: float = 100.0
  @export var drop_count: int = 3
  var current_hp: float
  var source_prompt: String
  signal died(monster: Monster)
  ```
- Methods: `take_damage(amount)`, `die()`, `explode_materials()`
- **Constraint:** Material drops use same mesh split technique as weapon (see `model_loader.gd` line 72-80)

**B2. Create `/Users/sruim/godot/entities/material_drop.gd`**
- Extends: `RigidBody3D`
- Properties:
  ```gdscript
  var material_name: String       # "spider leg", "iron ore"
  var element_type: String        # "fire", "ice", "poison", "neutral"
  var mesh_preview: Mesh          # For UI display
  var pickup_radius: float = 1.5
  ```
- Add to group: `"pickable"`
- **Constraint:** Auto-pickup on player proximity (use `Area3D` child node)

**B3. Create `/Users/sruim/godot/entities/player.gd`**
- Extends: `CharacterBody3D` (not RigidBody, for stable control)
- Movement: WASD, speed = 5.0
- Properties:
  ```gdscript
  var equipped_weapon: WeaponInstance = null
  var inventory: Array[MaterialDrop] = []
  ```
- Methods: `equip_weapon(weapon)`, `pickup_material(mat)`
- **Constraint:** Weapon attachment via `RemoteTransform3D` (keep physics independent)

### Block C: Spawning System

**C1. Create `/Users/sruim/godot/systems/monster_spawner.gd`**
- Implements LogicSpec 3.3 queue pattern
- Properties:
  ```gdscript
  var monster_queue: Array[Dictionary] = []  # {glb_path, prompt}
  var is_generating: bool = false
  var spawn_points: Array[Marker3D] = []     # Populated from scene
  ```
- Methods: `queue_next_monster()`, `get_queued_monster()`, `_generate_random_prompt()`
- **Constraint:** Connect to `APIClient.model_ready` with custom callback (separate from weapon generation)

**C2. Create `/Users/sruim/godot/systems/inventory.gd`**
- Simple `Array[MaterialDrop]` wrapper
- Methods: `add(mat)`, `remove(mat)`, `get_by_type(element)`
- **Constraint:** No UI logic here (pure data structure)

### Block D: Combat Integration

**D1. Modify `/Users/sruim/godot/entities/weapon_instance.gd`**
- Enable collision detection:
  ```gdscript
  contact_monitor = true
  max_contacts_reported = 4
  ```
- Add `body_entered` signal handler
- Calculate damage: `damage = linear_velocity.length() * 10.0`
- **Constraint:** Only damage bodies in group "monster"

**D2. Update `/Users/sruim/godot/systems/model_loader.gd`**
- Add method: `load_monster(glb_path) -> Monster`
  - Similar to `load_weapon()` but returns `Monster` instance
  - Add loaded node to group "monster"
- **Constraint:** Reuse `_load_glb()`, `_extract_mesh()`, `_validate_mesh()` (DRY principle)

### Block E: Scene Layout

**E1. Modify `/Users/sruim/godot/main.tscn`**
- Remove: Ragdoll test nodes, old UI panels
- Add:
  ```
  Arena (Node3D)
  ├─ Floor (CSGBox3D: 20x0.5x20)
  ├─ ForgeTable (CSGBox3D: 2x1x2, center)
  ├─ ForgeZone (Area3D, collision_layer=8)
  ├─ SpawnPoints (Node3D)
  │  ├─ North (Marker3D)
  │  ├─ South (Marker3D)
  │  ├─ East (Marker3D)
  │  └─ West (Marker3D)
  └─ Player (CharacterBody3D from player.gd)
  ```
- **Constraint:** Forge zone triggers `GameManager.start_crafting()` on `body_entered`

**E2. Create `/Users/sruim/godot/ui/crafting_panel.tscn`**
- Minimal UI:
  - Material slots (2-3 TextureRect)
  - Weapon type dropdown (OptionButton)
  - Craft button (Button)
  - Progress bar (for API wait)
- **Constraint:** Use existing `GameUI` parent container (line unclear, check `ui/` folder structure)

### Block F: Bootstrap Data

**F1. Create `/Users/sruim/godot/data/starter_materials.gd`**
- Static data:
  ```gdscript
  const STARTERS: Array[Dictionary] = [
    {name="iron_bar", element="neutral", mesh_path="res://models/primitives/bar.glb"},
    {name="bone_shard", element="poison", mesh_path="res://models/primitives/bone.glb"},
    {name="wood_plank", element="neutral", mesh_path="res://models/primitives/plank.glb"}
  ]
  ```
- **Constraint:** Use simple primitive meshes (CSG or pre-made GLBs, not AI-generated)

</ExecutionPlan>

## 5. Risk Mitigation

| Risk | Mitigation | Implementation |
|------|-----------|----------------|
| **Async Race Condition** | Separate API callbacks for weapons vs monsters | Add `request_context` parameter to `APIClient.request_model()` |
| **Prompt Injection** | Whitelist material names + sanitize user input | Implement `CraftingSystem.sanitize()` per LogicSpec 3.2 |
| **Physics Performance** | Limit material drops to 3, auto-despawn after 60s | Add `Timer` to `MaterialDrop._ready()` |
| **Empty Monster Queue** | Fallback sphere monster if queue empty | `MonsterSpawner.create_fallback_sphere_monster()` |

## 6. MVP Prioritization

**Week 1 Deliverable (Minimal Playable):**
1. ✅ Player movement (WASD)
2. ✅ Starter materials (3 primitive meshes, pre-placed in scene)
3. ✅ Crafting UI (basic, no polish)
4. ✅ Weapon generation (reuse existing pipeline)
5. ✅ Fallback sphere monster (CSGSphere, 100 HP)
6. ✅ Collision damage (weapon → monster)
7. ✅ Material drop on death (scatter 3 copies of random starter material)

**Deferred to Week 2+:**
- ❌ Monster AI (just static targets for MVP)
- ❌ Element-based damage types
- ❌ Material mesh extraction from dead monsters (use random starters)
- ❌ QTE forging minigame
- ❌ Weapon durability/breaking
- ❌ Complex UI animations

## 7. Testing Checkpoints

```
TEST 1: Crafting Flow
  GIVEN player with 2+ materials
  WHEN enter forge zone
  THEN UI appears with material selection

TEST 2: Weapon Generation
  GIVEN selected materials + weapon type
  WHEN click Craft
  THEN APIClient called with sanitized prompt
  AND weapon spawns after API success

TEST 3: Monster Spawn
  GIVEN weapon equipped
  WHEN combat state entered
  THEN monster appears at random spawn point

TEST 4: Combat
  GIVEN equipped weapon + spawned monster
  WHEN weapon collides with monster at velocity > 2.0
  THEN monster HP decreases
  AND monster dies at HP <= 0

TEST 5: Material Drops
  GIVEN monster died
  WHEN death animation complete
  THEN 3 materials spawn near death position
  AND player can walk over to auto-pickup

TEST 6: Loop Completion
  GIVEN materials picked up
  WHEN return to forge with 2+ materials
  THEN can craft again (state = IDLE)
```

## 8. File Change Summary

**Deletions:**
- ❌ `/systems/weapon_attacher.gd` (Ragdoll attachment, obsolete)
- ❌ `/tests/*` (old test scenes tied to NPC flow)

**Major Refactors:**
- 🔄 `/autoload/game_manager.gd` (state enum change)
- 🔄 `/systems/order_generator.gd` → `/systems/crafting_system.gd` (rename + logic change)
- 🔄 `/entities/weapon_instance.gd` (add collision signals)
- 🔄 `/systems/model_loader.gd` (add `load_monster()` method)

**New Files:**
- ✨ `/entities/player.gd`
- ✨ `/entities/monster.gd`
- ✨ `/entities/material_drop.gd`
- ✨ `/systems/monster_spawner.gd`
- ✨ `/systems/inventory.gd`
- ✨ `/ui/crafting_panel.tscn`
- ✨ `/data/starter_materials.gd`

**Scene Changes:**
- 🔄 `/main.tscn` (arena layout)

---

**Handoff Note for Worker:**
Implement blocks sequentially (A → B → C → D → E → F). Each block is self-contained. Test after each block using checkpoints from Section 7. Do not add features from "Deferred" list.

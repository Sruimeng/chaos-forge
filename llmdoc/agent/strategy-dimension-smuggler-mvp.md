---
id: strategy-dimension-smuggler-mvp
type: strategy
description: MVP implementation plan for Ragdoll-based weapon testing system
---

# Strategy: Dimension Smuggler MVP

## 1. Situational Awareness

**Context:** Existing codebase has API integration, model loading, and physics inspection. Need to pivot from "sales pitch" paradigm to "physical comedy" paradigm.

**Active Constitution:**
* **Technical:** Godot 4.x Physics (Column-Major Transform)
* **Style:** Strict Adherence to Hemingway Principle (Iceberg, High Signal, Low Noise)
* **Security:** Input validation for API responses, mesh complexity limits

## 2. Assessment

<Assessment>
**Complexity:** Level 3 (Deep Physics + Multi-System Refactor)

**Critical Risks:**
- Ragdoll instability (exploding joints, infinite loops)
- Joint attachment point miscalculation (weapon flies off)
- Performance degradation (PhysicalBone3D is CPU-intensive)

**Reusable Assets:**
- ✅ APIClient (autoload) - No changes needed
- ✅ ModelLoader - Reuse GLB loading, collision generation
- ✅ WeaponInstance - Reuse RigidBody3D wrapper
- ⚠️ PhysicsInspector - Refactor to detect "ragdoll disturbance" instead of "weapon bugs"
- ❌ SalesManager - Delete, replace with OrderGenerator

**New Requirements:**
- RagdollNPC (PhysicalBone3D skeleton + balance state machine)
- WeaponAttachment (Generic6DOFJoint3D manager)
- OrderGenerator (simple text randomizer)
</Assessment>

## 3. Abstract Specification (The Logic)

### 3.1 Ragdoll Physics Model

<LogicSpec>
**Ragdoll Stability Conditions:**
```
DEFINE Ragdoll:
  bones = [pelvis, spine, head, arm_L, arm_R, leg_L, leg_R]
  joints = [PinJoint3D with damping=0.9, bias=0.3]

STABILITY_CHECK(ragdoll):
  center_of_mass = SUM(bone.mass * bone.global_position) / total_mass
  support_polygon = ConvexHull(foot_L.position, foot_R.position)

  IF center_of_mass NOT IN support_polygon:
    RETURN "falling"

  IF ABS(spine.angular_velocity.length()) > 2.0:
    RETURN "unstable"

  RETURN "stable"
```

**Key Parameters:**
- Bone Mass Distribution: `pelvis=3.0, spine=2.0, head=1.5, limbs=1.0`
- Joint Damping: `0.9` (high resistance to prevent jitter)
- Joint Bias: `0.3` (soft correction, allows wobble)
</LogicSpec>

### 3.2 Weapon Attachment & Torque Calculation

<LogicSpec>
**Attachment Point Calculation:**
```
FUNCTION attach_weapon(weapon: RigidBody3D, hand_bone: PhysicalBone3D):
  weapon_aabb = weapon.get_child(CollisionShape3D).shape.get_aabb()
  weapon_center_of_mass = weapon_aabb.get_center()

  attachment_point = hand_bone.global_position + hand_bone.global_basis.y * 0.1

  joint = Generic6DOFJoint3D.new()
  joint.node_a = hand_bone.get_path()
  joint.node_b = weapon.get_path()
  joint.set_flag_x(FLAG_ENABLE_ANGULAR_LIMIT, false)  # Allow rotation
  joint.set_flag_y(FLAG_ENABLE_LINEAR_LIMIT, true)    # Lock Y position

  hand_bone.add_child(joint)

  RETURN joint
```

**Torque Calculation:**
```
FUNCTION calculate_disturbance(weapon: RigidBody3D, hand: PhysicalBone3D):
  weapon_mass = weapon.mass
  lever_arm = (weapon.global_position - hand.global_position).length()
  gravity = 9.8

  torque_magnitude = weapon_mass * gravity * lever_arm

  IF torque_magnitude > 15.0:  # Threshold for "too heavy"
    RETURN "topple"
  ELSE IF torque_magnitude > 5.0:
    RETURN "wobble"
  ELSE:
    RETURN "stable"
```
</LogicSpec>

### 3.3 State Flow Redesign

<LogicSpec>
**New GameManager States:**
```
ENUM GameState {
  IDLE,         # Waiting for user input
  ORDERING,     # Display random NPC order
  GENERATING,   # API call in progress
  SPAWNING,     # Weapon dropped on table
  TESTING,      # Ragdoll grabs weapon
  REACTING,     # Ragdoll falls/wobbles
  RESULT        # Show outcome (success/fail)
}

TRANSITION_RULES:
  IDLE -> ORDERING: User clicks "Start"
  ORDERING -> GENERATING: After 1.5s delay (simulate reading)
  GENERATING -> SPAWNING: APIClient.model_ready signal
  SPAWNING -> TESTING: Weapon.linear_velocity.length() < 0.1 (settled)
  TESTING -> REACTING: Attachment complete
  REACTING -> RESULT: After 3s OR ragdoll.state == "fallen"
  RESULT -> IDLE: User clicks "Next"
```
</LogicSpec>

## 4. Execution Plan

<ExecutionPlan>

**Block A: Core Refactor**

1. **MODIFY** `autoload/game_manager.gd`
   * Replace `GameState` enum with new states (ORDERING, TESTING, REACTING, RESULT)
   * Remove `_sales_manager` references
   * Add `_order_generator`, `_ragdoll_npc` references
   * Update signal flow: `weapon_spawned -> ragdoll_test_start -> ragdoll_reaction -> test_complete`
   * Constraint: Keep existing `_model_loader`, `_physics_inspector` setup

2. **DELETE** `systems/sales_manager.gd`
   * Reason: No longer needed for MVP

3. **DELETE** `data/pitch_database.gd`
   * Reason: Dependent on SalesManager

**Block B: Order System (Minimal)**

4. **CREATE** `systems/order_generator.gd`
   * Class: `OrderGenerator extends Node`
   * Method: `generate_order() -> Dictionary`
   * Returns: `{ "npc_name": String, "weapon_type": String, "flavor_text": String }`
   * Implementation: Simple `pick_random()` from hardcoded arrays
   * No persistence, no complexity
   * Constraint: Max 50 lines total

**Block C: Ragdoll NPC**

5. **CREATE** `entities/ragdoll_npc.tscn`
   * Root: `Node3D` (not PhysicalBone3D, that's for children)
   * Skeleton Structure:
     ```
     RagdollNPC (Node3D)
     ├─ Pelvis (PhysicalBone3D) [mass=3.0]
     │  ├─ Spine (PhysicalBone3D) [mass=2.0]
     │  │  ├─ Head (PhysicalBone3D) [mass=1.5]
     │  │  ├─ ArmL (PhysicalBone3D) [mass=1.0]
     │  │  └─ ArmR (PhysicalBone3D) [mass=1.0]
     │  ├─ LegL (PhysicalBone3D) [mass=1.2]
     │  └─ LegR (PhysicalBone3D) [mass=1.2]
     ├─ PinJoint_Spine (PinJoint3D) [damping=0.9, bias=0.3]
     ├─ PinJoint_Head (PinJoint3D)
     ... (repeat for all joints)
     ```
   * Constraint: Use primitive shapes (CapsuleShape3D) for visualization
   * Collision Layers: `layer=4, mask=1` (collides with weapons)

6. **CREATE** `entities/ragdoll_npc.gd`
   * Extends: `Node3D`
   * Properties:
     - `state: String` (stable/wobbling/fallen)
     - `hand_bone: PhysicalBone3D` (reference to right hand)
   * Methods:
     - `grab_weapon(weapon: RigidBody3D)`
     - `_check_stability() -> String`
     - `_on_physics_frame(delta: float)`
   * Signals:
     - `reaction_started(reaction_type: String)`
     - `fallen_down()`
   * Constraint: Implement LogicSpec 3.1 stability check exactly

**Block D: Weapon Attachment System**

7. **CREATE** `systems/weapon_attacher.gd`
   * Class: `WeaponAttacher extends Node`
   * Method: `attach_to_hand(weapon: RigidBody3D, hand: PhysicalBone3D) -> Generic6DOFJoint3D`
   * Method: `calculate_expected_reaction(weapon: RigidBody3D) -> String`
   * Implementation: LogicSpec 3.2 (attachment point + torque calculation)
   * Constraint: Single responsibility - only handles joint creation

**Block E: Physics Inspector Adaptation**

8. **MODIFY** `systems/physics_inspector.gd`
   * Rename: `start_inspection()` -> `start_weapon_settle_check()`
   * New Purpose: Detect when weapon has stopped moving (ready for pickup)
   * Remove: Jitter/drift/clip detection logic
   * Add: Simple velocity threshold check
   * Signal: Change `inspection_complete` -> `weapon_settled`
   * Constraint: Keep existing structure, just strip out scoring logic

**Block F: Integration**

9. **MODIFY** `autoload/game_manager.gd` (continued)
   * Add child nodes: `OrderGenerator`, `WeaponAttacher`
   * Add scene instance: `RagdollNPC` (loaded from .tscn)
   * Wire signals:
     ```gdscript
     _order_generator.order_ready.connect(_on_order_ready)
     _physics_inspector.weapon_settled.connect(_on_weapon_settled)
     _ragdoll.reaction_started.connect(_on_reaction_started)
     _ragdoll.fallen_down.connect(_on_test_complete)
     ```
   * State handlers:
     - `ORDERING`: Display order, auto-advance after 2s
     - `TESTING`: Call `_weapon_attacher.attach_to_hand()`
     - `REACTING`: Wait for ragdoll signal or timeout
     - `RESULT`: Log reaction type, clean up weapon

**Block G: UI Stub (Minimal)**

10. **CREATE** `ui/test_display.gd`
    * Class: `TestDisplay extends Control`
    * Elements: Single `Label` for state display
    * Updates: Show current `GameState` and NPC name
    * Constraint: No visual polish, just functional text output
    * Position: Top-left corner, absolute positioning

</ExecutionPlan>

## 5. Technical Challenges & Mitigations

### Challenge 1: Ragdoll Exploding Joints

**Symptom:** Limbs fly off at initialization.

**Mitigation:**
```gdscript
# In ragdoll_npc.gd _ready()
for joint in get_children():
  if joint is PinJoint3D:
    joint.set_param(PinJoint3D.PARAM_BIAS, 0.3)
    joint.set_param(PinJoint3D.PARAM_DAMPING, 0.9)
    joint.set_param(PinJoint3D.PARAM_IMPULSE_CLAMP, 0.0)
```

### Challenge 2: Weapon Attachment Point Offset

**Symptom:** Weapon spawns inside hand or floats away.

**Solution:** Use `hand_bone.to_global()` transform, not direct position:
```gdscript
joint.set_node_a(hand_bone.get_path())
joint.set_node_b(weapon.get_path())
joint.transform = Transform3D(Basis(), hand_bone.global_transform.origin)
```

### Challenge 3: Performance - PhysicalBone3D Updates

**Symptom:** FPS drops with many PhysicalBones.

**Mitigation:**
- Limit ragdoll to 7 bones (no fingers, no spine segments)
- Use `contact_monitor = false` on non-critical bones
- Set `Physics Process Priority = -1` for ragdoll (lower priority)

## 6. File Operation Summary

**Preserve:**
- `autoload/api_client.gd`
- `systems/model_loader.gd`
- `entities/weapon_instance.gd`

**Refactor:**
- `autoload/game_manager.gd` - State machine redesign
- `systems/physics_inspector.gd` - Simplify to settle detection

**Delete:**
- `systems/sales_manager.gd`
- `data/pitch_database.gd`

**Create:**
- `systems/order_generator.gd`
- `systems/weapon_attacher.gd`
- `entities/ragdoll_npc.tscn`
- `entities/ragdoll_npc.gd`
- `ui/test_display.gd`

## 7. Implementation Sequence

**Phase 1: Deconstruction** (Worker)
1. Delete SalesManager, PitchDatabase
2. Refactor GameManager enum
3. Stub out new systems (empty classes)

**Phase 2: Ragdoll Construction** (Worker)
1. Build ragdoll_npc.tscn manually
2. Implement stability check in ragdoll_npc.gd
3. Test standalone (drop heavy box on ragdoll)

**Phase 3: Integration** (Worker)
1. Implement OrderGenerator (trivial)
2. Implement WeaponAttacher (critical)
3. Wire signals in GameManager
4. Add TestDisplay UI

**Phase 4: Calibration** (Manual Testing)
1. Tune joint parameters (damping, bias)
2. Tune torque thresholds (5.0, 15.0 values are estimates)
3. Test with various weapon shapes/masses

## 8. Success Criteria

**MVP Acceptance:**
- [ ] Order displayed on screen (text only)
- [ ] Weapon generated and dropped on table
- [ ] Ragdoll grabs weapon when settled
- [ ] Ragdoll reacts (wobble/topple/stable) based on weapon properties
- [ ] No crashes, no exploding joints
- [ ] Cycle completes in <10 seconds

**Deferred to Post-MVP:**
- Forging rhythm game
- Shader scratch-off effect
- Persistent order queue
- Score/currency system

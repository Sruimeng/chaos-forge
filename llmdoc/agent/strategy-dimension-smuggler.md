---
id: strategy-dimension-smuggler
type: strategy
related_ids: [constitution, tech-stack, godot-conventions]
phase: architecture
complexity: 3
---

# Strategy: Dimension Smuggler (维度走私商)

## 1. Situational Awareness

**Context:** Greenfield Godot 4.6 Mobile project. No existing code. Core loop: AI-generated weapons → Physics sandbox inspection → Sales pitch → Roguelike feedback loop.

**Active Constitution:**
* **Technical:**
    * Godot 4.6.stable + Jolt Physics (Mobile-First)
    * Coordinate System: Y-up Right-Handed, Forward = -Z
    * Physics: Dynamic bodies mass > 0, no `transform` manipulation in `_physics_process()`
    * Mobile Constraints: Max 4 lights, 2 shadow casters, 5000 verts/mesh
    * Composition over inheritance (Components, not deep class trees)
    * Signal-driven architecture (past-tense signals)
    * Static typing enforced (GDScript 2.0)
* **Style:** **Strict Adherence to Hemingway Principle** (Iceberg, Guard Clauses, Type-First, No "What" Comments)
* **Security:** API key isolation, input validation on AI responses, fail-safe defaults

## 2. Assessment

<Assessment>
**Complexity:** Level 3
**Reasoning:**
- External AI integration (Tripo API) with async failure modes
- Physics-based bug detection (non-deterministic)
- Procedural generation with feedback loop (Prompt mutation)
- Multi-module state synchronization (API → Model → Physics → UI → Sales)

**Critical Risks:**
1. **API Latency:** Tripo generation may take 5-30 seconds
2. **Model Loading Failure:** GLB may be malformed or exceed vertex limits
3. **Physics Instability:** Jolt Physics may behave unpredictably with exotic geometries
4. **Prompt Drift:** Iterative NPC mutations may produce unusable prompts
5. **Mobile Performance:** Dynamic mesh loading may spike frame time
</Assessment>

## 3. Abstract Specification (The Logic)

> **MANDATORY: Define algorithms before implementation.**

### 3.1 Tripo AI Integration Flow

<LogicSpec>
**Request Phase:**
```
Input: PromptText, NPCProfile
Output: TaskID | Error

1. Validate(PromptText):
   - Length ∈ [10, 500]
   - No forbidden tokens (profanity filter)
2. HTTP.POST(TRIPO_API_URL, {
     type: "text_to_model",
     prompt: PromptText,
     quality: "medium"
   })
3. Parse(Response):
   - Success → Store(TaskID) + Poll()
   - Failure → Retry(exponential_backoff) or Abort()
```

**Polling Phase:**
```
Input: TaskID
Output: ModelURL | Status

1. Timer.Start(interval=2s, max_retries=30)
2. For each tick:
   HTTP.GET(TRIPO_API_URL/task/{TaskID})
   If status == "success":
     Return ModelURL
   If status == "failed":
     Log(error) + Return Null
   If timeout:
     Return Null
```

**Download Phase:**
```
Input: ModelURL
Output: GLB_Bytes | Error

1. HTTP.GET(ModelURL) → Stream
2. Validate(FileSize < 10MB)
3. Save(temp://weapon_{UUID}.glb)
4. Return Path
```
</LogicSpec>

### 3.2 Physics Bug Detection

<LogicSpec>
**Initialization:**
```
Input: GLB_Path
Output: RigidBody3D + Bug_Score

1. Scene = GLBLoader.Import(GLB_Path)
2. Extract MeshInstance3D
3. Validate:
   - Vertices < 5000
   - CollisionShape != null
4. Wrap in RigidBody3D:
   - mass = 1.0
   - collision_layer = 1
   - collision_mask = 2 (table layer)
5. Add to PhysicsWorld
```

**Real-Time Detection (每帧执行):**
```
Inputs: RigidBody3D, DeltaTime
Outputs: JitterScore, DriftScore, ClipScore

1. JitterScore:
   velocity_delta = abs(velocity - prev_velocity)
   jitter = velocity_delta.length() / DeltaTime
   If jitter > THRESHOLD_JITTER (e.g., 50):
     JitterScore += 1

2. DriftScore:
   expected_pos = initial_pos + gravity * time²
   actual_pos = global_position
   drift = (actual_pos - expected_pos).length()
   If drift > THRESHOLD_DRIFT (e.g., 0.5):
     DriftScore += 1

3. ClipScore:
   For each contact in get_colliding_bodies():
     penetration_depth = contact.get_contact_impulse().length()
     If penetration_depth > THRESHOLD_CLIP (e.g., 0.1):
       ClipScore += 1

4. Aggregate:
   BugLevel = JitterScore * 0.4 + DriftScore * 0.3 + ClipScore * 0.3
```
</LogicSpec>

### 3.3 Sales Pitch Algorithm

<LogicSpec>
**Input:** BugLevel, WeaponType, NPCPersonality
**Output:** PitchText, SuccessRate

1. Generate Pitch Angle:
   ```
   If BugLevel < 0.2:
     angle = "premium_quality"
   Else If BugLevel < 0.5:
     angle = "exotic_feature"
   Else:
     angle = "discount_clearance"
   ```

2. Template Selection:
   ```
   templates = PITCH_DATABASE[NPCPersonality][angle]
   selected = templates.pick_random()
   ```

3. Variable Substitution:
   ```
   pitch = selected.format({
     "weapon_name": WeaponType,
     "bug_euphemism": BUG_EUPHEMISMS[BugLevel],
     "price_modifier": 1.0 - (BugLevel * 0.5)
   })
   ```

4. Success Calculation:
   ```
   base_rate = NPC.Gullibility
   bug_penalty = BugLevel * 0.6
   pitch_bonus = 0.2 if angle == "exotic_feature" else 0
   SuccessRate = clamp(base_rate - bug_penalty + pitch_bonus, 0.1, 0.9)
   ```

5. Dice Roll:
   ```
   If randf() < SuccessRate:
     Return (pitch, true)
   Else:
     Return (pitch, false)
   ```
</LogicSpec>

### 3.4 Prompt Mutation (Roguelike Loop)

<LogicSpec>
**Input:** PrevPrompt, SaleResult (success/fail), NPCFeedback
**Output:** NewPrompt

1. Extract Keywords:
   ```
   keywords = NLP.Extract(PrevPrompt, top_n=5)
   ```

2. Mutation Strategy:
   ```
   If SaleResult == success:
     strategy = "reinforce"  # Keep successful traits
     mutation_rate = 0.2
   Else:
     strategy = "explore"    # Randomize heavily
     mutation_rate = 0.6
   ```

3. Apply Mutations:
   ```
   new_keywords = []
   For each kw in keywords:
     If randf() < mutation_rate:
       new_keywords.append(SYNONYM_DB.get(kw).pick_random())
     Else:
       new_keywords.append(kw)
   ```

4. Recombination:
   ```
   If strategy == "explore":
     inject_random_trait(new_keywords, NPCFeedback)

   NewPrompt = TEMPLATE.format(new_keywords)
   Validate(Length < 500)
   ```

5. Feedback Loop:
   ```
   Store(Mutation_History, {
     prompt: NewPrompt,
     parent: PrevPrompt,
     fitness: SaleResult ? 1.0 : 0.0
   })
   ```
</LogicSpec>

## 4. Execution Plan

<ExecutionPlan>

### Block A: Core Infrastructure (Day 1-2)
**Goal:** Minimal runnable scene + Autoload singletons

1. **CREATE** `res://main.tscn`
   - Root: `Node3D` (name="Main")
   - Children:
     - `Camera3D` (position=(0, 2, 5), rotation=(-20°, 0, 0))
     - `DirectionalLight3D` (shadow enabled)
     - `CSGBox3D` (name="Table", size=(2, 0.1, 1), collision_layer=2)
   - *Constraint:* Camera must face table center

2. **CREATE** `res://autoload/game_manager.gd`
   ```gdscript
   class_name GameManager
   extends Node

   signal weapon_generated(weapon_scene: Node3D)
   signal sale_completed(success: bool, profit: int)

   enum GameState { IDLE, GENERATING, INSPECTING, PITCHING }
   var current_state: GameState = GameState.IDLE
   var current_weapon: RigidBody3D = null
   ```
   - *Constraint:* Register as Autoload in Project Settings

3. **CREATE** `res://autoload/api_client.gd`
   ```gdscript
   class_name APIClient
   extends Node

   const TRIPO_API_KEY: String = "YOUR_KEY_HERE"  # Move to environment variable
   const TRIPO_BASE_URL: String = "https://api.tripo3d.ai/v2/openapi"

   var http: HTTPRequest = null
   var active_task_id: String = ""
   ```
   - *Constraint:* No API key in source control (use `res://secrets.cfg`)

### Block B: Tripo API Integration (Day 3-4)
**Goal:** Request → Poll → Download pipeline

1. **EXTEND** `api_client.gd` → Add `request_model(prompt: String) -> void`
   - *Implementation:*
     - Use `HTTPRequest` node
     - Set headers: `{"Authorization": "Bearer %s" % API_KEY}`
     - POST to `/task`
   - *Constraint:* Must validate prompt length before sending

2. **ADD** `_on_task_created(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void`
   - *Implementation:*
     - Parse JSON: `JSON.parse_string(body.get_string_from_utf8())`
     - Extract `task_id`
     - Start polling timer
   - *Constraint:* Handle HTTP errors (4xx/5xx) with retry logic

3. **ADD** `poll_task_status(task_id: String) -> void`
   - *Implementation:*
     - GET `/task/{task_id}`
     - Check `status` field
     - Emit `model_ready` signal on success
   - *Constraint:* Max 30 retries, 2-second interval

4. **ADD** `download_model(url: String) -> String`
   - *Implementation:*
     - Download GLB bytes
     - Save to `user://models/weapon_{timestamp}.glb`
     - Return file path
   - *Constraint:* Validate file size < 10MB

### Block C: Model Loading & Physics Setup (Day 5-6)
**Goal:** GLB → RigidBody3D with collision

1. **CREATE** `res://systems/model_loader.gd`
   ```gdscript
   class_name ModelLoader
   extends Node

   func load_glb(path: String) -> Node3D:
       var loader := GLTFDocument.new()
       var state := GLTFState.new()
       var err := loader.append_from_file(path, state)
       if err != OK: return null
       return loader.generate_scene(state)
   ```
   - *Constraint:* Validate vertex count < 5000

2. **CREATE** `res://entities/weapon_instance.gd`
   ```gdscript
   class_name WeaponInstance
   extends RigidBody3D

   var model_mesh: MeshInstance3D = null
   var bug_score: float = 0.0
   ```
   - *Constraint:* Must set `mass = 1.0`, `collision_layer = 1`

3. **ADD** `setup_collision(mesh: MeshInstance3D) -> void`
   - *Implementation:*
     - Create `CollisionShape3D` child
     - Generate `ConvexPolygonShape3D` from mesh
     - Attach to `WeaponInstance`
   - *Constraint:* Fallback to `BoxShape3D` if convex generation fails

### Block D: Physics Bug Detection (Day 7-8)
**Goal:** Real-time jitter/drift/clipping detection

1. **CREATE** `res://systems/physics_inspector.gd`
   ```gdscript
   class_name PhysicsInspector
   extends Node

   var tracked_body: RigidBody3D = null
   var prev_velocity: Vector3 = Vector3.ZERO
   var initial_position: Vector3 = Vector3.ZERO
   var spawn_time: float = 0.0

   var jitter_count: int = 0
   var drift_count: int = 0
   var clip_count: int = 0
   ```

2. **IMPLEMENT** `_physics_process(delta: float) -> void`
   - *Logic:* Use LogicSpec 3.2
   - *Constraint:* No allocations in this function (cache all vectors)

3. **ADD** `calculate_bug_score() -> float`
   - *Formula:* `jitter * 0.4 + drift * 0.3 + clip * 0.3`
   - *Constraint:* Normalize to [0.0, 1.0]

### Block E: Sales Pitch System (Day 9-10)
**Goal:** Generate contextual sales pitches

1. **CREATE** `res://data/pitch_database.gd`
   ```gdscript
   const PITCHES := {
       "skeptical": {
           "premium": ["This blade defies physics itself..."],
           "exotic": ["Notice how it vibrates? That's quantum sharpness."],
           "discount": ["Slight instability, but 50% off!"]
       },
       "gullible": { ... }
   }
   ```
   - *Constraint:* Externalize to JSON in production

2. **CREATE** `res://systems/sales_manager.gd`
   ```gdscript
   class_name SalesManager

   func generate_pitch(bug_level: float, npc_type: String) -> String:
       # Implement LogicSpec 3.3
       pass

   func roll_sale(success_rate: float) -> bool:
       return randf() < success_rate
   ```

3. **CREATE** `res://ui/pitch_panel.tscn`
   - *Structure:*
     - `PanelContainer` → `VBoxContainer`
       - `RichTextLabel` (pitch display)
       - `HBoxContainer` (Approve/Reject buttons)
   - *Constraint:* Mobile-friendly touch targets (min 48x48 dp)

### Block F: Roguelike Prompt Mutation (Day 11-12)
**Goal:** Feedback-driven prompt evolution

1. **CREATE** `res://systems/prompt_mutator.gd`
   ```gdscript
   class_name PromptMutator

   var mutation_history: Array[Dictionary] = []

   func mutate(prev_prompt: String, success: bool, npc_feedback: String) -> String:
       # Implement LogicSpec 3.4
       pass
   ```

2. **CREATE** `res://data/synonym_db.json`
   ```json
   {
       "sword": ["blade", "saber", "katana", "rapier"],
       "sharp": ["keen", "razor", "honed", "lethal"]
   }
   ```
   - *Constraint:* Lazy-load on first mutation

3. **INTEGRATE** with `game_manager.gd`
   - *Signal:* `sale_completed.connect(_on_sale_completed)`
   - *Action:* Trigger mutation, request new model

### Block G: UI/UX Polish (Day 13-14)
**Goal:** Minimal viable interface

1. **CREATE** `res://ui/hud.tscn`
   - *Components:*
     - Generation progress bar
     - Bug score meter
     - Profit counter
     - NPC portrait + dialogue box

2. **CREATE** `res://ui/input_handler.gd`
   - *Inputs:*
     - Touch drag to rotate camera
     - Pinch to zoom
     - Tap to interact with weapon

3. **STYLE** → Apply Nexus Design System colors (if available)
   - *Constraint:* Fallback to Godot default theme

</ExecutionPlan>

## 5. Risk Mitigation

<RiskMatrix>

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Tripo API timeout** | High | Implement exponential backoff + user cancellation option |
| **GLB malformed** | Medium | Validate with `GLTFDocument.append_from_buffer()` before loading |
| **Physics explosion** | High | Clamp velocities, add "reset" button, limit angular velocity |
| **Prompt drift to gibberish** | Medium | Store top-5 successful prompts, allow manual override |
| **Mobile performance drop** | Critical | Async GLB loading, limit 1 weapon in scene, unload after sale |

</RiskMatrix>

## 6. Testing Protocol

**Unit Tests (GdUnit4):**
- `test_api_client_retry_logic()`
- `test_physics_inspector_jitter_detection()`
- `test_prompt_mutator_preserves_length()`

**Integration Tests:**
- Mock Tripo API responses (success/failure/timeout)
- Simulate extreme physics scenarios (high velocity, clipping)

**Manual QA:**
- Generate 10 weapons, verify no crashes
- Test on mid-range Android device (target: 30 FPS minimum)

## 7. Mandatory Constraints

1. **No Direct Scene References:** Use signals exclusively between systems
2. **Type Everything:** No untyped variables or function returns
3. **Mobile-First:** Test on Android emulator every 2 days
4. **API Key Security:** Never commit `secrets.cfg` to version control
5. **Physics Isolation:** Never modify `WeaponInstance.transform` directly after spawn
6. **Hemingway Style:** Code must pass "iceberg test" (interface simple, implementation hidden)

## 8. Success Criteria

**MVP Complete When:**
- [ ] User inputs prompt → Weapon appears in 30s
- [ ] Physics bugs visibly detected (jitter/drift)
- [ ] Sales pitch changes based on bug level
- [ ] Successful sale triggers new mutated weapon request
- [ ] App runs at 30+ FPS on Android mid-tier device

**Code Quality Gate:**
- [ ] No `push_error()` in normal operation
- [ ] All exports typed
- [ ] Signal names past-tense
- [ ] No deep nesting (max 2 levels)
- [ ] Test coverage > 60% for core systems

---

**Estimated Timeline:** 14 days (2 weeks)
**Blocking Dependencies:** Tripo API key, Android device/emulator
**Next Step:** Worker implements Block A (Core Infrastructure)

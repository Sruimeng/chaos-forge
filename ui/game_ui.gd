extends Control
## Main game UI - handles input and displays status

@onready var prompt_input: LineEdit = $VBoxContainer/PromptInput
@onready var submit_button: Button = $VBoxContainer/SubmitButton
@onready var state_label: Label = $VBoxContainer/StateLabel
@onready var result_label: Label = $VBoxContainer/ResultLabel
@onready var order_label: Label = $VBoxContainer/OrderLabel

var _order_generator: Node = null

func _ready() -> void:
	# Setup OrderGenerator
	var OrderGeneratorScript := preload("res://systems/order_generator.gd")
	_order_generator = OrderGeneratorScript.new()
	add_child(_order_generator)

	# Connect UI signals
	submit_button.pressed.connect(_on_submit_pressed)
	prompt_input.text_submitted.connect(_on_prompt_submitted)

	# Connect GameManager signals
	if GameManager:
		GameManager.weapon_generated.connect(_on_weapon_generated)
		GameManager.weapon_ready_for_test.connect(_on_test_started)
		GameManager.ragdoll_reaction.connect(_on_ragdoll_reaction)
		GameManager.test_complete.connect(_on_test_complete)

	# Generate initial order
	_generate_new_order()
	_update_state_display()


func _generate_new_order() -> void:
	if not _order_generator:
		return

	var order = _order_generator.get_random_order()
	order_label.text = "📜 " + order.order_text

	# Pre-fill prompt with suggested keywords
	prompt_input.placeholder_text = _order_generator.keywords_to_prompt(order)


func _on_submit_pressed() -> void:
	_submit_prompt()


func _on_prompt_submitted(_text: String) -> void:
	_submit_prompt()


func _submit_prompt() -> void:
	var prompt := prompt_input.text.strip_edges()

	# Use placeholder if empty
	if prompt.is_empty():
		prompt = prompt_input.placeholder_text

	if prompt.length() < 10:
		result_label.text = "⚠️ Prompt 太短（至少 10 字符）"
		return

	# Disable input during generation
	prompt_input.editable = false
	submit_button.disabled = true
	result_label.text = "🔄 正在生成..."

	# Request weapon
	GameManager.request_weapon(prompt)


func _on_weapon_generated(_weapon: RigidBody3D) -> void:
	result_label.text = "✅ 武器已生成！"
	_update_state_display()


func _on_test_started(_weapon: RigidBody3D) -> void:
	result_label.text = "🧪 测试中..."
	_update_state_display()

	# Find and grab weapon with ragdoll
	_attach_weapon_to_ragdoll(_weapon)


func _attach_weapon_to_ragdoll(weapon: RigidBody3D) -> void:
	var ragdoll := get_tree().get_first_node_in_group("ragdoll")
	if not ragdoll:
		# Try to find by name
		ragdoll = get_node_or_null("/root/Main/RagdollNPC")

	if ragdoll and ragdoll.has_method("grab_weapon"):
		# Wait a frame for physics to settle
		await get_tree().physics_frame
		ragdoll.grab_weapon(weapon)


func _on_ragdoll_reaction(reaction_type: String, _details: Dictionary) -> void:
	match reaction_type:
		"STABLE":
			result_label.text = "😊 勇者稳稳接住了武器！"
		"WOBBLING":
			result_label.text = "😰 勇者在摇晃..."
		"TOPPLED":
			result_label.text = "💀 勇者被压倒了！"
		_:
			result_label.text = "❓ " + reaction_type

	_update_state_display()


func _on_test_complete(success: bool) -> void:
	if success:
		result_label.text = "🎉 测试成功！"
	else:
		result_label.text = "💔 测试失败..."

	# Re-enable input
	prompt_input.editable = true
	submit_button.disabled = false
	prompt_input.text = ""

	# Generate new order
	_generate_new_order()
	_update_state_display()


func _update_state_display() -> void:
	if not GameManager:
		state_label.text = "状态: 未知"
		return

	var state_name: String = GameManager.GameState.keys()[GameManager.current_state]
	var state_emoji: String

	match GameManager.current_state:
		GameManager.GameState.IDLE:
			state_emoji = "💤"
		GameManager.GameState.ORDERING:
			state_emoji = "📝"
		GameManager.GameState.GENERATING:
			state_emoji = "⚙️"
		GameManager.GameState.TESTING:
			state_emoji = "🧪"
		GameManager.GameState.REACTING:
			state_emoji = "🎭"
		_:
			state_emoji = "❓"

	state_label.text = "%s 状态: %s" % [state_emoji, state_name]


func _process(_delta: float) -> void:
	# Update state display periodically
	if Engine.get_process_frames() % 30 == 0:
		_update_state_display()

class_name CraftingSystem
extends Node
## Material → Weapon prompt translation system

signal recipe_created(recipe: CraftingRecipe)
signal prompt_ready(prompt: String)

class CraftingRecipe:
	var materials: Array  # Array of MaterialDrop or Dictionary
	var weapon_type: String
	var combined_prompt: String

	func _init(p_materials: Array, p_type: String, p_prompt: String) -> void:
		materials = p_materials
		weapon_type = p_type
		combined_prompt = p_prompt


const WEAPON_TYPES: Array[String] = ["sword", "axe", "hammer", "spear", "dagger", "staff"]

const ELEMENT_MODIFIERS: Dictionary = {
	"fire": "blazing",
	"ice": "frozen",
	"poison": "venomous",
	"lightning": "crackling",
	"neutral": ""
}

# Sanitization constraints
const MAX_NAME_LENGTH: int = 50
const ALLOWED_CHARS: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 _-"


## Build crafting prompt from materials and weapon type
func build_prompt(materials: Array, weapon_type: String) -> String:
	if materials.size() < 2:
		push_error("Need at least 2 materials")
		return ""

	if weapon_type not in WEAPON_TYPES:
		push_error("Invalid weapon type: %s" % weapon_type)
		return ""

	# Sanitize material names
	var safe_names: Array[String] = []
	for mat in materials:
		var name: String = _get_material_name(mat)
		safe_names.append(sanitize(name))

	# Collect unique element types
	var elements: Array[String] = []
	for mat in materials:
		var element: String = _get_element_type(mat)
		if element != "neutral" and element not in elements:
			elements.append(element)

	# Build prompt
	var prompt: String = "A %s, forged from %s" % [weapon_type, safe_names[0]]

	if safe_names.size() > 1:
		prompt += " and %s" % safe_names[1]

	if safe_names.size() > 2:
		prompt += " with %s" % safe_names[2]

	# Add element modifiers
	if elements.size() > 0:
		var element_words: Array[String] = []
		for el in elements:
			if ELEMENT_MODIFIERS.has(el) and ELEMENT_MODIFIERS[el] != "":
				element_words.append(ELEMENT_MODIFIERS[el])

		if element_words.size() > 0:
			prompt += ", infused with %s energy" % " and ".join(element_words)

	prompt += ", low-poly game asset style"

	if OS.is_debug_build():
		print("Crafting prompt: %s" % prompt)

	return prompt


## Create full recipe and trigger generation
func create_recipe(materials: Array, weapon_type: String) -> CraftingRecipe:
	var prompt := build_prompt(materials, weapon_type)
	if prompt.is_empty():
		return null

	var recipe := CraftingRecipe.new(materials, weapon_type, prompt)
	recipe_created.emit(recipe)
	prompt_ready.emit(prompt)

	return recipe


## Sanitize text: remove special chars, limit length
func sanitize(text: String) -> String:
	var result: String = ""

	for i in range(text.length()):
		var c: String = text[i]
		if c in ALLOWED_CHARS:
			result += c

	if result.length() > MAX_NAME_LENGTH:
		result = result.substr(0, MAX_NAME_LENGTH)

	return result.strip_edges()


## Extract material name from MaterialDrop or Dictionary
func _get_material_name(mat) -> String:
	if mat is Dictionary:
		return mat.get("name", mat.get("material_name", "unknown"))
	elif mat.has_method("get") or "material_name" in mat:
		return mat.material_name
	return "unknown"


## Extract element type from MaterialDrop or Dictionary
func _get_element_type(mat) -> String:
	if mat is Dictionary:
		return mat.get("element", mat.get("element_type", "neutral"))
	elif mat.has_method("get") or "element_type" in mat:
		return mat.element_type
	return "neutral"


## Get random weapon type
func get_random_weapon_type() -> String:
	return WEAPON_TYPES.pick_random()

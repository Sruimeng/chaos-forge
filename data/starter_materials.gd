class_name StarterMaterials
extends RefCounted
## Static data for starter materials given to player at game start

const STARTERS: Array[Dictionary] = [
	{
		"name": "iron_bar",
		"element": "neutral",
		"description": "A sturdy iron ingot"
	},
	{
		"name": "bone_shard",
		"element": "poison",
		"description": "A sharp fragment of bone"
	},
	{
		"name": "wood_plank",
		"element": "neutral",
		"description": "Solid oak wood"
	},
	{
		"name": "fire_crystal",
		"element": "fire",
		"description": "Glows with inner flame"
	},
	{
		"name": "ice_shard",
		"element": "ice",
		"description": "Perpetually frozen"
	}
]

const ELEMENT_COLORS: Dictionary = {
	"neutral": Color.GRAY,
	"fire": Color.ORANGE_RED,
	"ice": Color.CYAN,
	"poison": Color.GREEN_YELLOW,
	"lightning": Color.YELLOW
}


## Get starter materials for new game
static func get_starter_set() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	# Give player first 3 materials
	for i in range(mini(3, STARTERS.size())):
		result.append(STARTERS[i].duplicate())
	return result


## Get random material from starters
static func get_random() -> Dictionary:
	return STARTERS.pick_random().duplicate()


## Get material by name
static func get_by_name(mat_name: String) -> Dictionary:
	for mat in STARTERS:
		if mat.name == mat_name:
			return mat.duplicate()
	return {}


## Get color for element type
static func get_element_color(element: String) -> Color:
	return ELEMENT_COLORS.get(element, Color.WHITE)


## Create MaterialDrop node from data
static func create_drop(mat_data: Dictionary, position: Vector3) -> RigidBody3D:
	var MaterialDropScript := preload("res://entities/material_drop.gd")

	var drop: RigidBody3D = RigidBody3D.new()
	drop.set_script(MaterialDropScript)
	drop.material_name = mat_data.get("name", "unknown")
	drop.element_type = mat_data.get("element", "neutral")

	# Add visual mesh
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	mesh_instance.mesh = sphere

	# Apply element color
	var mat := StandardMaterial3D.new()
	mat.albedo_color = get_element_color(mat_data.get("element", "neutral"))
	mat.emission_enabled = true
	mat.emission = mat.albedo_color * 0.3
	mesh_instance.material_override = mat

	drop.add_child(mesh_instance)

	# Add collision
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.15
	collision.shape = shape
	drop.add_child(collision)

	drop.global_position = position

	return drop

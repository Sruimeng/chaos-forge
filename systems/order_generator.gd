class_name OrderGenerator
extends Node
## Generates random weapon orders from NPCs

signal order_generated(order: OrderRequest)

class OrderRequest:
	var order_text: String
	var suggested_keywords: Array[String]
	var difficulty: float  # 0.0 - 1.0

	func _init(p_text: String, p_keywords: Array[String], p_difficulty: float) -> void:
		order_text = p_text
		suggested_keywords = p_keywords
		difficulty = p_difficulty


const ORDER_TEMPLATES: Array[Dictionary] = [
	{
		"text": "我需要一把能砸碎巨龙脚趾的锤子！",
		"keywords": ["massive", "hammer", "heavy", "crushing"],
		"difficulty": 0.7
	},
	{
		"text": "给我一把轻巧的匕首，要能切开影子。",
		"keywords": ["dagger", "light", "sharp", "shadow"],
		"difficulty": 0.5
	},
	{
		"text": "我要一把燃烧的巨剑！像太阳一样！",
		"keywords": ["greatsword", "burning", "fire", "glowing", "massive"],
		"difficulty": 0.8
	},
	{
		"text": "来把普通的剑就行，别太花哨。",
		"keywords": ["sword", "simple", "metal"],
		"difficulty": 0.3
	},
	{
		"text": "我听说你能锻造传说武器？给我惊喜！",
		"keywords": ["legendary", "magical", "ancient", "glowing"],
		"difficulty": 0.9
	},
	{
		"text": "一把能发出雷鸣的战斧！",
		"keywords": ["axe", "thunder", "lightning", "electric"],
		"difficulty": 0.6
	},
	{
		"text": "给我一根法杖，要有水晶的那种。",
		"keywords": ["staff", "crystal", "magic", "glowing"],
		"difficulty": 0.5
	},
	{
		"text": "我需要一把长矛，能刺穿城墙！",
		"keywords": ["spear", "long", "piercing", "massive"],
		"difficulty": 0.7
	}
]


func get_random_order() -> OrderRequest:
	var template: Dictionary = ORDER_TEMPLATES.pick_random()

	var keywords: Array[String] = []
	for kw in template.keywords:
		keywords.append(kw)

	var order := OrderRequest.new(
		template.text,
		keywords,
		template.difficulty
	)

	order_generated.emit(order)

	if OS.is_debug_build():
		print("Order generated: %s" % template.text)

	return order


## Convert order keywords to Tripo prompt
func keywords_to_prompt(order: OrderRequest) -> String:
	var parts: Array[String] = []
	for kw in order.suggested_keywords:
		parts.append(kw)
	return " ".join(parts)


## Generate prompt directly from random order
func generate_prompt() -> String:
	var order := get_random_order()
	return keywords_to_prompt(order)

class_name Inventory
extends RefCounted
## Pure data structure for material storage

signal item_added(material: Dictionary)
signal item_removed(material: Dictionary)
signal changed(count: int)

var _materials: Array[Dictionary] = []


func add(material: Dictionary) -> void:
	_materials.append(material)
	item_added.emit(material)
	changed.emit(_materials.size())


func add_from_drop(drop: MaterialDrop) -> void:
	add(drop.to_dict())


func remove(material: Dictionary) -> bool:
	var idx := _find_index(material)
	if idx >= 0:
		var removed := _materials[idx]
		_materials.remove_at(idx)
		item_removed.emit(removed)
		changed.emit(_materials.size())
		return true
	return false


func remove_at(index: int) -> Dictionary:
	if index < 0 or index >= _materials.size():
		return {}

	var removed := _materials[index]
	_materials.remove_at(index)
	item_removed.emit(removed)
	changed.emit(_materials.size())
	return removed


func get_all() -> Array[Dictionary]:
	return _materials.duplicate()


func get_at(index: int) -> Dictionary:
	if index < 0 or index >= _materials.size():
		return {}
	return _materials[index]


func get_by_element(element: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for mat in _materials:
		if mat.get("element", "neutral") == element:
			result.append(mat)
	return result


func get_by_name(name: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for mat in _materials:
		if mat.get("name", "") == name:
			result.append(mat)
	return result


func consume(count: int) -> Array[Dictionary]:
	var consumed: Array[Dictionary] = []
	for i in range(mini(count, _materials.size())):
		consumed.append(_materials.pop_front())

	if consumed.size() > 0:
		changed.emit(_materials.size())

	return consumed


func count() -> int:
	return _materials.size()


func has_enough(required: int) -> bool:
	return _materials.size() >= required


func is_empty() -> bool:
	return _materials.is_empty()


func clear() -> void:
	_materials.clear()
	changed.emit(0)


func _find_index(material: Dictionary) -> int:
	for i in range(_materials.size()):
		if _materials[i].get("name") == material.get("name"):
			return i
	return -1


## Get unique element types in inventory
func get_unique_elements() -> Array[String]:
	var elements: Array[String] = []
	for mat in _materials:
		var el: String = mat.get("element", "neutral")
		if el not in elements:
			elements.append(el)
	return elements


## Get material names as string array
func get_material_names() -> Array[String]:
	var names: Array[String] = []
	for mat in _materials:
		names.append(mat.get("name", "unknown"))
	return names

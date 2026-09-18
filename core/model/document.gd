extends RefCounted

const Shape := preload("res://core/model/shape.gd")

const FORMAT_VERSION := 1

var shapes: Array[Shape] = []


func add(shape: Shape) -> void:
	shapes.append(shape)


func remove(shape_id: String) -> bool:
	var i := _index_of(shape_id)
	if i == -1:
		return false
	shapes.remove_at(i)
	return true


func get_shape(shape_id: String) -> Shape:
	for s in shapes:
		if s.id == shape_id:
			return s
	return null


func move_to_top(shape_id: String) -> bool:
	var i := _index_of(shape_id)
	if i == -1:
		return false
	var s := shapes[i]
	shapes.remove_at(i)
	shapes.append(s)
	return true


func move_to_bottom(shape_id: String) -> bool:
	var i := _index_of(shape_id)
	if i == -1:
		return false
	var s := shapes[i]
	shapes.remove_at(i)
	shapes.push_front(s)
	return true


func hit_test(p: Vector2, threshold := 2.0) -> Shape:
	for i in range(shapes.size() - 1, -1, -1):
		if shapes[i].contains_point(p, threshold):
			return shapes[i]
	return null


func hit_test_all(rect: Rect2, threshold := 8.0) -> Array[Shape]:
	var hit: Array[Shape] = []
	for s in shapes:
		if s.get_selrect().grow(threshold).intersects(rect):
			hit.append(s)
	return hit


func to_dict() -> Dictionary:
	var arr: Array[Dictionary] = []
	for s in shapes:
		arr.append(s.to_dict())
	return {"format_version": FORMAT_VERSION, "shapes": arr}


func load_from_dict(d: Dictionary) -> void:
	shapes.clear()
	var arr: Array = d.get("shapes", [])
	for entry in arr:
		var s := Shape.new()
		s.load_from_dict(entry)
		shapes.append(s)


func _index_of(shape_id: String) -> int:
	for i in range(shapes.size()):
		if shapes[i].id == shape_id:
			return i
	return -1
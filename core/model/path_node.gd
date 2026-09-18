extends RefCounted

var position := Vector2.ZERO
var c1 := Vector2.ZERO
var c2 := Vector2.ZERO


func _init(p_position := Vector2.ZERO, p_c1 := Vector2.ZERO, p_c2 := Vector2.ZERO) -> void:
	position = p_position
	c1 = p_c1
	c2 = p_c2


func make_straight() -> void:
	c1 = position
	c2 = position


func is_straight_in() -> bool:
	return position.distance_to(c1) < 0.001


func is_straight_out() -> bool:
	return position.distance_to(c2) < 0.001


func to_dict() -> Dictionary:
	return {
		"x": position.x,
		"y": position.y,
		"c1x": c1.x,
		"c1y": c1.y,
		"c2x": c2.x,
		"c2y": c2.y,
	}
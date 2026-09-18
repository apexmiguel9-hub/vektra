extends "res://core/history/command.gd"

var shape
var from_pos := Vector2.ZERO
var to_pos := Vector2.ZERO


func _init(p_shape, p_from: Vector2, p_to: Vector2, p_label := "Mover") -> void:
	shape = p_shape
	from_pos = p_from
	to_pos = p_to
	label = p_label


func apply() -> void:
	shape.position = to_pos


func apply_undo() -> void:
	shape.position = from_pos
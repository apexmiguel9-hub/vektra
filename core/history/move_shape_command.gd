extends "res://core/history/command.gd"

var shape
var from_anchor := Vector2.ZERO
var to_anchor := Vector2.ZERO


func _init(p_shape, p_from: Vector2, p_to: Vector2, p_label := "Mover") -> void:
	shape = p_shape
	from_anchor = p_from
	to_anchor = p_to
	label = p_label


func apply() -> void:
	shape.set_anchor(to_anchor)


func apply_undo() -> void:
	shape.set_anchor(from_anchor)
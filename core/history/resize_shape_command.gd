extends "res://core/history/command.gd"

var shape
var before: Dictionary = {}
var after: Dictionary = {}


func _init(p_shape, p_before: Dictionary, p_after: Dictionary, p_label := "Redimensionar") -> void:
	shape = p_shape
	before = p_before
	after = p_after
	label = p_label


func apply() -> void:
	shape.load_from_dict(after)


func apply_undo() -> void:
	shape.load_from_dict(before)
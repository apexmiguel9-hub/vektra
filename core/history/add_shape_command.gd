extends "res://core/history/command.gd"

var document
var shape
var index := -1


func _init(p_document, p_shape, p_label := "Añadir figura") -> void:
	document = p_document
	shape = p_shape
	label = p_label


func apply() -> void:
	index = document.get_index(shape.id)
	document.add_at(shape, index + 1)


func apply_undo() -> void:
	document.remove(shape.id)
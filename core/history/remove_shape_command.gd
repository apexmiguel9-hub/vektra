extends "res://core/history/command.gd"

var document
var shape
var index := 0


func _init(p_document, p_shape, p_label := "Eliminar figura") -> void:
	document = p_document
	shape = p_shape
	index = document.get_index(shape.id)
	label = p_label


func apply() -> void:
	index = document.get_index(shape.id)
	document.remove(shape.id)


func apply_undo() -> void:
	document.add_at(shape, index)
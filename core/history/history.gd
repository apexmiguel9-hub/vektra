extends RefCounted

const Command := preload("res://core/history/command.gd")

var max_undo := 100

signal changed

var _undo: Array[Command] = []
var _redo: Array[Command] = []


func push(cmd: Command) -> void:
	cmd.apply()
	_undo.append(cmd)
	if _undo.size() > max_undo:
		_undo.pop_front()
	_redo.clear()
	changed.emit()


func undo() -> bool:
	if _undo.is_empty():
		return false
	var cmd: Command = _undo.pop_back()
	cmd.apply_undo()
	_redo.append(cmd)
	changed.emit()
	return true


func redo() -> bool:
	if _redo.is_empty():
		return false
	var cmd: Command = _redo.pop_back()
	cmd.apply()
	_undo.append(cmd)
	changed.emit()
	return true


func clear() -> void:
	_undo.clear()
	_redo.clear()
	changed.emit()


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


func undo_count() -> int:
	return _undo.size()


func redo_count() -> int:
	return _redo.size()
extends Node2D

const Document := preload("res://core/model/document.gd")
const ShapeFactory := preload("res://core/model/shape_factory.gd")
const PathNode := preload("res://core/model/path_node.gd")
const CanvasView := preload("res://shell/canvas_view.gd")

const BASE_COUNT := 200
const BATCH := 200

var _document: Document
var _view: CanvasView
var _fps_label: Label
var _count := 0


func _ready() -> void:
	_document = Document.new()
	_fill(BASE_COUNT)

	_view = CanvasView.new()
	_view.setup(_document)
	add_child(_view)

	var layer := CanvasLayer.new()
	add_child(layer)
	_fps_label = Label.new()
	_fps_label.position = Vector2(16, 16)
	_fps_label.add_theme_font_size_override("font_size", 24)
	layer.add_child(_fps_label)


func _process(_delta: float) -> void:
	_fps_label.text = "FPS: %d  shapes: %d" % [Engine.get_frames_per_second(), _count]


func _unhandled_input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventScreenTouch and event.pressed:
		pressed = true
	elif event is InputEventMouseButton and event.pressed:
		pressed = true
	if pressed:
		_fill(BATCH)
		_view.queue_redraw()


func _fill(n: int) -> void:
	for i in range(n):
		var x := randf_range(40.0, 1040.0)
		var y := randf_range(80.0, 1840.0)
		var r := randf_range(12.0, 90.0)
		match randi() % 4:
			0:
				_document.add(ShapeFactory.rect(Vector2(x, y), r, r * randf_range(0.6, 1.4)))
			1:
				_document.add(ShapeFactory.ellipse(Vector2(x, y), r, r * randf_range(0.6, 1.4)))
			2:
				var ln := ShapeFactory.line(Vector2(x - r, y - r), Vector2(x + r, y + r))
				ln.stroke_width = 4.0
				_document.add(ln)
			3:
				_document.add(ShapeFactory.path([
					PathNode.new(Vector2(x - r, y)),
					PathNode.new(Vector2(x, y - r)),
					PathNode.new(Vector2(x + r, y)),
					PathNode.new(Vector2(x, y + r)),
				], true))
	_count += n
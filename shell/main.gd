extends Node2D

const Document := preload("res://core/model/document.gd")
const ShapeFactory := preload("res://core/model/shape_factory.gd")
const CanvasView := preload("res://shell/canvas_view.gd")

var _document: Document


func _ready() -> void:
	_document = Document.new()
	var card := ShapeFactory.rect(Vector2(300, 320), 260, 160, "Card")
	card.fill = Color("#5a8dee")
	card.stroke = Color("#25407a")
	card.rotation_deg = 8.0
	_document.add(card)

	var avatar := ShapeFactory.ellipse(Vector2(300, 180), 110, 110, "Avatar")
	avatar.fill = Color("#f2b64d")
	avatar.stroke = Color("#8a6210")
	_document.add(avatar)

	var divider := ShapeFactory.line(Vector2(120, 480), Vector2(480, 480), "Divider")
	divider.stroke = Color("#3a4a6b")
	divider.stroke_width = 3.0
	_document.add(divider)

	var btn := ShapeFactory.rect(Vector2(300, 580), 180, 64, "Button")
	btn.fill = Color("#2f9e63")
	btn.stroke = Color("#155434")
	_document.add(btn)

	var view := CanvasView.new()
	view.setup(_document)
	add_child(view)
	view.queue_redraw()
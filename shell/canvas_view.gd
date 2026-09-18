extends Node2D

const Document := preload("res://core/model/document.gd")
const Shape := preload("res://core/model/shape.gd")

const DOC_WORLD_SIZE := Vector2(1240, 1754)
const GRID_SPACING := 24.0
const GRID_DOT_RADIUS := 1.4
const BG_COLOR := Color("#3a3a3c")
const SHEET_COLOR := Color("#ffffff")
const GRID_COLOR := Color("#d9d9d9")
const MIN_ZOOM := 0.2
const MAX_ZOOM := 8.0

var document: Document

var _zoom := 1.0
var _offset := Vector2.ZERO
var _touches := {}
var _gesture_dist := 0.0
var _gesture_center := Vector2.ZERO


func setup(doc: Document) -> void:
	document = doc


func _ready() -> void:
	var vp := get_viewport_rect()
	_offset = (vp.size - DOC_WORLD_SIZE) * 0.5


func _draw() -> void:
	_draw_background()
	draw_set_transform(_offset, 0.0, Vector2(_zoom, _zoom))
	_draw_sheet()
	if document == null:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	for s in document.shapes:
		_draw_shape(s)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_background() -> void:
	var vp := get_viewport_rect()
	draw_rect(vp, BG_COLOR)


func _draw_sheet() -> void:
	draw_rect(Rect2(Vector2.ZERO, DOC_WORLD_SIZE), SHEET_COLOR)
	var spacing := GRID_SPACING
	var y := spacing * 0.5
	while y < DOC_WORLD_SIZE.y:
		var x := spacing * 0.5
		while x < DOC_WORLD_SIZE.x:
			draw_circle(Vector2(x, y), GRID_DOT_RADIUS, GRID_COLOR)
			x += spacing
		y += spacing


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			if _touches.size() == 2:
				_sync_baseline()
		else:
			_touches.erase(event.index)
			if _touches.size() == 2:
				_sync_baseline()
			else:
				_gesture_dist = 0.0
	elif event is InputEventScreenDrag:
		if event.index in _touches:
			_touches[event.index] = event.position
			if _touches.size() == 2 and _gesture_dist > 0.0:
				var pts: Array = _touches.values()
				var a: Vector2 = pts[0]
				var b: Vector2 = pts[1]
				var center := (a + b) * 0.5
				var dist := a.distance_to(b)
				if dist > 0.0:
					_apply_camera(center - _gesture_center, dist / _gesture_dist, center)
					_gesture_center = center
					_gesture_dist = dist


func _sync_baseline() -> void:
	var pts: Array = _touches.values()
	var a: Vector2 = pts[0]
	var b: Vector2 = pts[1]
	_gesture_center = (a + b) * 0.5
	_gesture_dist = a.distance_to(b)


func _apply_camera(delta: Vector2, factor: float, center: Vector2) -> void:
	var new_zoom := clampf(_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	var world_anchor := (center - _offset) / _zoom
	_offset = center - world_anchor * new_zoom + delta
	_zoom = new_zoom
	queue_redraw()


func _draw_shape(s: Shape) -> void:
	if not s.visible:
		return
	match s.type:
		Shape.Type.RECT:
			draw_set_transform(s.position, deg_to_rad(s.rotation_deg), s.scale)
			draw_rect(Rect2(-s.size * 0.5, s.size), s.fill)
			draw_rect(Rect2(-s.size * 0.5, s.size), s.stroke, false, s.stroke_width)
		Shape.Type.ELLIPSE:
			_draw_ellipse(s)
		Shape.Type.LINE:
			draw_line(s.line_a, s.line_b, s.stroke, s.stroke_width)
		Shape.Type.PATH:
			var poly: PackedVector2Array = s.get_flattened_polyline()
			if poly.size() >= 2:
				if s.closed and poly.size() >= 3:
					draw_colored_polygon(poly, s.fill)
					draw_polyline(poly, s.stroke, s.stroke_width, true)
				else:
					draw_polyline(poly, s.stroke, s.stroke_width, false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_ellipse(s: Shape) -> void:
	var steps := 64
	var r := s.size * 0.5
	var pts := PackedVector2Array()
	for i in range(steps):
		var ang := TAU * float(i) / float(steps)
		pts.append(Vector2(cos(ang) * r.x, sin(ang) * r.y))
	draw_set_transform(s.position, deg_to_rad(s.rotation_deg), s.scale)
	draw_colored_polygon(pts, s.fill)
	draw_polyline(pts, s.stroke, s.stroke_width, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
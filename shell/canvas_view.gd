extends Node2D

const Document := preload("res://core/model/document.gd")
const Shape := preload("res://core/model/shape.gd")

const GRID_SPACING := 24.0
const GRID_DOT_RADIUS := 1.6
const TILE_CELLS := 16
const MIN_PINCH_DIST := 24.0
const CANVAS_COLOR := Color("#ffffff")
const GRID_COLOR := Color("#d9d9d9")
const MIN_ZOOM := 0.2
const MAX_ZOOM := 8.0

var document: Document

var _zoom := 1.0
var _content_offset := Vector2.ZERO
var _touches := {}
var _gesture_dist := 0.0
var _gesture_center := Vector2.ZERO
var _pinch_armed := false
var _grid_tex: ImageTexture


func setup(doc: Document) -> void:
	document = doc


func _ready() -> void:
	_grid_tex = _make_grid_texture()
	_fit_to_document()


func _fit_to_document() -> void:
	var vp := get_viewport_rect()
	if document == null or document.shapes.is_empty():
		_content_offset = vp.size * 0.5
		return
	var bounds := document.shapes[0].get_selrect()
	for s in document.shapes:
		bounds = bounds.merge(s.get_selrect())
	_content_offset = vp.size * 0.5 - bounds.get_center() * _zoom


func _draw() -> void:
	_draw_background()
	if document == null:
		return
	var content := Transform2D(0.0, Vector2(_zoom, _zoom), 0.0, _content_offset)
	for s in document.shapes:
		_draw_shape(s, content)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_background() -> void:
	var vp := get_viewport_rect()
	draw_rect(vp, CANVAS_COLOR)
	var tile := GRID_SPACING * TILE_CELLS
	var y := 0.0
	while y < vp.size.y:
		var x := 0.0
		while x < vp.size.x:
			draw_texture(_grid_tex, Vector2(x, y))
			x += tile
		y += tile


func _make_grid_texture() -> ImageTexture:
	var tile := int(GRID_SPACING) * TILE_CELLS
	var img := Image.create(tile, tile, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var ri := int(ceil(GRID_DOT_RADIUS))
	for cy in range(TILE_CELLS):
		for cx in range(TILE_CELLS):
			var center := Vector2(GRID_SPACING * (float(cx) + 0.5), GRID_SPACING * (float(cy) + 0.5))
			for dy in range(-ri, ri + 1):
				for dx in range(-ri, ri + 1):
					if dx * dx + dy * dy <= GRID_DOT_RADIUS * GRID_DOT_RADIUS:
						img.set_pixel(int(center.x) + dx, int(center.y) + dy, GRID_COLOR)
	return ImageTexture.create_from_image(img)


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
					var factor := 1.0
					if _pinch_armed and dist >= MIN_PINCH_DIST:
						factor = dist / _gesture_dist
					_apply_camera(center - _gesture_center, factor, center)
					_gesture_center = center
					_gesture_dist = dist
					_pinch_armed = _pinch_armed or dist >= MIN_PINCH_DIST


func _sync_baseline() -> void:
	var pts: Array = _touches.values()
	var a: Vector2 = pts[0]
	var b: Vector2 = pts[1]
	_gesture_center = (a + b) * 0.5
	_gesture_dist = a.distance_to(b)
	_pinch_armed = _gesture_dist >= MIN_PINCH_DIST


func _apply_camera(delta: Vector2, factor: float, center: Vector2) -> void:
	var new_zoom := clampf(_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	var world_anchor := (center - _content_offset) / _zoom
	_content_offset = center - world_anchor * new_zoom + delta
	_zoom = new_zoom
	queue_redraw()


func _draw_shape(s: Shape, content: Transform2D) -> void:
	if not s.visible:
		return
	match s.type:
		Shape.Type.RECT:
			draw_set_transform_matrix(content * Transform2D(deg_to_rad(s.rotation_deg), s.scale, 0.0, s.position))
			draw_rect(Rect2(-s.size * 0.5, s.size), s.fill)
			draw_rect(Rect2(-s.size * 0.5, s.size), s.stroke, false, s.stroke_width)
		Shape.Type.ELLIPSE:
			_draw_ellipse(s, content)
		Shape.Type.LINE:
			draw_set_transform_matrix(content)
			draw_line(s.line_a, s.line_b, s.stroke, s.stroke_width)
		Shape.Type.PATH:
			draw_set_transform_matrix(content)
			var poly: PackedVector2Array = s.get_flattened_polyline()
			if poly.size() >= 2:
				if s.closed and poly.size() >= 3:
					draw_colored_polygon(poly, s.fill)
					draw_polyline(poly, s.stroke, s.stroke_width, true)
				else:
					draw_polyline(poly, s.stroke, s.stroke_width, false)


func _draw_ellipse(s: Shape, content: Transform2D) -> void:
	var steps := 64
	var r := s.size * 0.5
	var pts := PackedVector2Array()
	for i in range(steps):
		var ang := TAU * float(i) / float(steps)
		pts.append(Vector2(cos(ang) * r.x, sin(ang) * r.y))
	draw_set_transform_matrix(content * Transform2D(deg_to_rad(s.rotation_deg), s.scale, 0.0, s.position))
	draw_colored_polygon(pts, s.fill)
	draw_polyline(pts, s.stroke, s.stroke_width, true)
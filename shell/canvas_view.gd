extends Node2D

const Document := preload("res://core/model/document.gd")
const Shape := preload("res://core/model/shape.gd")
const History := preload("res://core/history/history.gd")
const MoveShapeCommand := preload("res://core/history/move_shape_command.gd")

const GRID_SPACING := 24.0
const GRID_DOT_RADIUS := 1.6
const TILE_CELLS := 16
const MIN_PINCH_DIST := 24.0
const TAP_SLOP := 12.0
const FAT_FINGER_PX := 14.0
const CANVAS_COLOR := Color("#ffffff")
const GRID_COLOR := Color("#d9d9d9")
const SELECTION_COLOR := Color("#335dff")
const MARQUEE_FILL := Color(0.2, 0.36, 1.0, 0.14)
const MIN_ZOOM := 0.2
const MAX_ZOOM := 8.0

var document: Document
var history: History

var _zoom := 1.0
var _content_offset := Vector2.ZERO
var _touches := {}
var _gesture_dist := 0.0
var _gesture_center := Vector2.ZERO
var _pinch_armed := false
var _grid_tex: ImageTexture

var _selected: Array[Shape] = []
var _press_screen := Vector2.ZERO
var _press_world := Vector2.ZERO
var _drag_mode := 0
var _drag_moved := false
var _drag_origins := {}
var _marquee_start_world := Vector2.ZERO
var _marquee_end_world := Vector2.ZERO
var _marquee_screen_end := Vector2.ZERO


func setup(doc: Document, p_history: History = null) -> void:
	document = doc
	history = p_history


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
	for s in _selected:
		_draw_selection_rect(s, content)
	if _drag_mode == 2 and _drag_moved:
		_draw_marquee()
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_hud()


func _draw_selection_rect(s: Shape, content: Transform2D) -> void:
	var stroke := maxf(2.0 / _zoom, 1.0)
	var sr := s.get_selrect().grow(stroke * 0.5)
	draw_set_transform_matrix(content)
	draw_rect(sr, MARQUEE_FILL, true)
	draw_rect(sr, SELECTION_COLOR, false, stroke)


func _draw_marquee() -> void:
	var rect := _rect_from_points(_press_screen, _marquee_screen_end)
	draw_rect(rect, MARQUEE_FILL, true)
	draw_rect(rect, SELECTION_COLOR, false, 2.0)


func _draw_hud() -> void:
	var zoom_text := "zoom %s offset %s" % [str(_zoom).pad_decimals(2), str(_content_offset)]
	draw_string(ThemeDB.fallback_font, Vector2(10, 26), zoom_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(0.28, 0.28, 0.30))


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
				_cancel_pointer_action()
			else:
				_start_press(event.position)
		else:
			_touches.erase(event.index)
			if _touches.size() == 2:
				_sync_baseline()
			else:
				_gesture_dist = 0.0
			if _touches.is_empty():
				_end_press()
	elif event is InputEventScreenDrag:
		if event.index in _touches:
			_touches[event.index] = event.position
			if _touches.size() == 2 and _gesture_dist > 0.0:
				_handle_camera()
			elif _touches.size() == 1 and _drag_mode != 0:
				_handle_drag(event.position)


func _handle_camera() -> void:
	var pts: Array = _touches.values()
	var a: Vector2 = pts[0]
	var b: Vector2 = pts[1]
	var center := (a + b) * 0.5
	var dist := a.distance_to(b)
	if dist <= 0.0:
		return
	var factor := 1.0
	if _pinch_armed and dist >= MIN_PINCH_DIST:
		factor = dist / _gesture_dist
	_apply_camera(center - _gesture_center, factor, center)
	_gesture_center = center
	_gesture_dist = dist
	_pinch_armed = _pinch_armed or dist >= MIN_PINCH_DIST


func _to_world(screen: Vector2) -> Vector2:
	return (screen - _content_offset) / _zoom


func _start_press(screen: Vector2) -> void:
	_press_screen = screen
	_press_world = _to_world(screen)
	_drag_mode = 0
	_drag_moved = false
	if document == null:
		return
	var hit := _hit_test(_press_world)
	if hit != null:
		_select_only(hit)
		_drag_mode = 1
		_capture_origins()
	else:
		_drag_mode = 2
		_marquee_start_world = _press_world
		_marquee_end_world = _press_world
		_marquee_screen_end = screen
		queue_redraw()


func _handle_drag(screen: Vector2) -> void:
	if not _drag_moved and screen.distance_to(_press_screen) >= TAP_SLOP:
		_drag_moved = true
	if not _drag_moved:
		return
	if _drag_mode == 1:
		var cur_world := _to_world(screen)
		var delta := cur_world - _press_world
		for s in _selected:
			s.position = _drag_origins[s] + delta
	elif _drag_mode == 2:
		_marquee_screen_end = screen
		_marquee_end_world = _to_world(screen)
	queue_redraw()


func _end_press() -> void:
	if _drag_mode == 1:
		if _drag_moved:
			_commit_move()
	elif _drag_mode == 2:
		if _drag_moved:
			_select_in_marquee()
		else:
			_deselect_all()
	_drag_mode = 0
	_drag_moved = false
	_drag_origins.clear()


func _cancel_pointer_action() -> void:
	if _drag_mode == 1 and _drag_moved:
		_commit_move()
	_drag_mode = 0
	_drag_moved = false
	_drag_origins.clear()


func _select_only(s: Shape) -> void:
	_selected.clear()
	_selected.append(s)
	queue_redraw()


func _deselect_all() -> void:
	_selected.clear()
	queue_redraw()


func _select_in_marquee() -> void:
	if document == null:
		return
	var rect := _rect_from_points(_marquee_start_world, _marquee_end_world)
	_selected = document.hit_test_all(rect)
	queue_redraw()


func _rect_from_points(a: Vector2, b: Vector2) -> Rect2:
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), Vector2(absf(a.x - b.x), absf(a.y - b.y)))


func _capture_origins() -> void:
	_drag_origins.clear()
	for s in _selected:
		_drag_origins[s] = s.position


func _commit_move() -> void:
	for s in _selected:
		var origin: Vector2 = _drag_origins[s]
		if origin != s.position and history != null:
			history.push(MoveShapeCommand.new(s, origin, s.position))
	_drag_origins.clear()
	queue_redraw()


func _hit_test(world: Vector2) -> Shape:
	return document.hit_test(world, maxf(2.0, FAT_FINGER_PX / _zoom))


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
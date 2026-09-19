extends Node2D

const Document := preload("res://core/model/document.gd")
const Shape := preload("res://core/model/shape.gd")
const History := preload("res://core/history/history.gd")
const MoveShapeCommand := preload("res://core/history/move_shape_command.gd")
const ResizeShapeCommand := preload("res://core/history/resize_shape_command.gd")

const GRID_SPACING := 24.0
const GRID_DOT_RADIUS := 1.6
const TILE_CELLS := 16
const MIN_PINCH_DIST := 24.0
const TAP_SLOP := 12.0
const FAT_FINGER_PX := 14.0
const HANDLE_RADIUS := 24.0
const HANDLE_STROKE := 5.0
const HANDLE_HIT_PX := 40.0
const MIN_SELRECT_PX := 10.0
const SELECTION_STROKE := 2.0

const RESIZE_MIN_RATIO := 0.02
const RESIZE_MAX_RATIO := 200.0

const _EDGE_FRACTIONS := [
	[0.0, 0.0], [0.5, 0.0], [1.0, 0.0], [1.0, 0.5],
	[1.0, 1.0], [0.5, 1.0], [0.0, 1.0], [0.0, 0.5],
]
const CANVAS_COLOR := Color("#ffffff")
const GRID_COLOR := Color("#d9d9d9")
const SELECTION_COLOR := Color("#335dff")
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

var _editing = null
var _edit_points: Array = []
var _edit_before: Dictionary = {}
var _drag_edit_point := -1
var _last_tap_ms := -1000
var _last_tap_id := ""
var _press_hit = null
var _press_screen := Vector2.ZERO
var _press_world := Vector2.ZERO
var _drag_mode := 0
var _drag_moved := false
var _drag_origins := {}
var _marquee_start_world := Vector2.ZERO
var _marquee_end_world := Vector2.ZERO
var _marquee_screen_end := Vector2.ZERO

var _resize_edge := -1
var _resize_anchor := Vector2.ZERO
var _resize_corner0 := Vector2.ZERO
var _resize_start_rect := Rect2()
var _resize_befores := {}


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
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if _editing != null:
		_draw_edit_handles()
	elif _selected.size() == 1:
		_draw_handles(_selected[0])
	if _drag_mode == 2 and _drag_moved:
		_draw_marquee()
	_draw_hud()


func _draw_selection_rect(s: Shape, content: Transform2D) -> void:
	draw_set_transform_matrix(content)
	if s.type == Shape.Type.QUAD and s.quad.size() >= 2:
		draw_polyline(s.quad, SELECTION_COLOR, SELECTION_STROKE, true)
	else:
		var sr := _min_visible_rect(s).grow(SELECTION_STROKE / _zoom)
		draw_rect(sr, SELECTION_COLOR, false, SELECTION_STROKE)


func _draw_marquee() -> void:
	var rect := _rect_from_points(_press_screen, _marquee_screen_end)
	draw_rect(rect, SELECTION_COLOR, false, SELECTION_STROKE)


func _draw_hud() -> void:
	var zoom_text := "zoom %s offset %s" % [str(_zoom).pad_decimals(2), str(_content_offset)]
	draw_string(ThemeDB.fallback_font, Vector2(10, 26), zoom_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(0.28, 0.28, 0.30))
	if _editing != null:
		draw_string(ThemeDB.fallback_font, Vector2(10, 46), "EDIT MODE (doble tap sale)", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(0.2, 0.35, 0.85))


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
	_press_hit = _hit_test(_press_world) if document != null else null
	if document == null:
		return
	if _editing != null:
		var h := _hit_edit_handle(screen)
		if h >= 0:
			_drag_mode = 4
			_drag_edit_point = h
			queue_redraw()
			return
		if _press_hit == _editing:
			_select_only(_editing)
			_drag_mode = 1
			_capture_origins()
			return
		_end_edit(true)
		if _press_hit == null:
			_deselect_all()
			return
	if _selected.size() == 1:
		var handle := _hit_handle(screen)
		if handle >= 0:
			_drag_mode = 3
			_begin_resize(handle)
			queue_redraw()
			return
	var hit: Shape = _press_hit
	if hit != null:
		_select_only(hit)
		_drag_mode = 1
		_capture_origins()
	else:
		if _selected.size() == 1:
			var vr := _min_visible_rect(_selected[0])
			if vr.has_point(_press_world):
				_drag_mode = 1
				_capture_origins()
				queue_redraw()
				return
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
			s.set_anchor(_drag_origins[s] + delta)
	elif _drag_mode == 2:
		_marquee_screen_end = screen
		_marquee_end_world = _to_world(screen)
	elif _drag_mode == 3:
		_apply_resize(_to_world(screen))
	elif _drag_mode == 4:
		_set_edit_point(_drag_edit_point, _to_world(screen))
	queue_redraw()


func _end_press() -> void:
	if _drag_mode == 1:
		if _drag_moved:
			_commit_move()
		else:
			_detect_double_tap()
	elif _drag_mode == 2:
		if _drag_moved:
			_select_in_marquee()
		else:
			_detect_double_tap()
			if _editing == null and _press_hit == null:
				_deselect_all()
	elif _drag_mode == 3:
		_commit_resize()
	_drag_mode = 0
	_drag_moved = false
	_drag_origins.clear()


func _detect_double_tap() -> void:
	var now := Time.get_ticks_msec()
	if _press_hit != null and _press_hit.id == _last_tap_id and now - _last_tap_ms < 450:
		if _editing == _press_hit:
			_end_edit(true)
		else:
			_begin_edit(_press_hit)
		_last_tap_ms = -1000
		_last_tap_id = ""
	else:
		if _press_hit != null:
			_last_tap_ms = now
			_last_tap_id = _press_hit.id
		else:
			_last_tap_ms = -1000
			_last_tap_id = ""


func _begin_edit(s: Shape) -> void:
	if s.type == Shape.Type.RECT:
		_edit_before = s.to_dict()
		s.convert_to_quad()
	else:
		_edit_before = s.to_dict()
	_editing = s
	_rebuild_edit_points()
	_select_only(s)
	queue_redraw()


func _end_edit(p_commit: bool) -> void:
	if _editing == null:
		return
	var s: Shape = _editing
	var after: Dictionary = s.to_dict()
	if p_commit and after != _edit_before and history != null:
		history.push(ResizeShapeCommand.new(s, _edit_before, after))
	_editing = null
	_edit_points.clear()
	_drag_edit_point = -1
	queue_redraw()


func _rebuild_edit_points() -> void:
	_edit_points.clear()
	var s = _editing
	if s == null:
		return
	if s.type == Shape.Type.QUAD:
		for p in s.quad:
			_edit_points.append(p)
	elif s.type == Shape.Type.LINE:
		_edit_points.append(s.line_a)
		_edit_points.append(s.line_b)
	elif s.type == Shape.Type.PATH:
		for nd in s.nodes:
			_edit_points.append(nd.position)


func _set_edit_point(i: int, world: Vector2) -> void:
	var s = _editing
	if s == null:
		return
	if s.type == Shape.Type.QUAD and s.quad.size() > i:
		s.quad[i] = world
	elif s.type == Shape.Type.LINE:
		if i == 0:
			s.line_a = world
		elif i == 1:
			s.line_b = world
	elif s.type == Shape.Type.PATH and i < s.nodes.size():
		s.nodes[i].position = world
	_edit_points[i] = world


func _cancel_pointer_action() -> void:
	if _drag_mode == 1 and _drag_moved:
		_commit_move()
	elif _drag_mode == 3:
		_commit_resize()
	_drag_mode = 0
	_drag_moved = false
	_drag_origins.clear()


func _select_only(s: Shape) -> void:
	_selected.clear()
	_selected.append(s)
	queue_redraw()


func _deselect_all() -> void:
	if _editing != null:
		_end_edit(true)
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
		_drag_origins[s] = s.get_anchor()


func _commit_move() -> void:
	for s in _selected:
		var origin: Vector2 = _drag_origins[s]
		if origin != s.get_anchor() and history != null:
			history.push(MoveShapeCommand.new(s, origin, s.get_anchor()))
	_drag_origins.clear()
	queue_redraw()


func _hit_test(world: Vector2) -> Shape:
	return document.hit_test(world, maxf(2.0, FAT_FINGER_PX / _zoom))


func _hit_handle(screen: Vector2) -> int:
	var sr := _min_visible_rect(_selected[0])
	var pts := _handle_positions(sr)
	var reach := minf(HANDLE_HIT_PX, minf(sr.size.x, sr.size.y) * _zoom * 0.45)
	for i in range(pts.size()):
		if _handle_visible(i) and pts[i].distance_to(screen) <= reach:
			return i
	return -1


func _hit_edit_handle(screen: Vector2) -> int:
	if _editing == null:
		return -1
	var pts := _edit_handles_screen()
	for i in range(pts.size()):
		if pts[i].distance_to(screen) <= HANDLE_HIT_PX:
			return i
	return -1


func _edit_handles_screen() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for w in _edit_points:
		out.append(w * _zoom + _content_offset)
	return out


func _min_visible_rect(s: Shape) -> Rect2:
	var sr := s.get_selrect()
	var grow_x := maxf((MIN_SELRECT_PX / _zoom - sr.size.x) * 0.5, 0.0)
	var grow_y := maxf((MIN_SELRECT_PX / _zoom - sr.size.y) * 0.5, 0.0)
	return sr.grow_individual(grow_x, grow_y, grow_x, grow_y)


func _handle_visible(edge: int) -> bool:
	match edge:
		1, 3, 5, 7:
			return false
		_:
			return true


func _handle_positions(sr: Rect2) -> Array[Vector2]:
	var world := [
		sr.position,
		Vector2(sr.position.x + sr.size.x * 0.5, sr.position.y),
		Vector2(sr.end.x, sr.position.y),
		Vector2(sr.end.x, sr.position.y + sr.size.y * 0.5),
		sr.end,
		Vector2(sr.position.x + sr.size.x * 0.5, sr.end.y),
		Vector2(sr.position.x, sr.end.y),
		Vector2(sr.position.x, sr.position.y + sr.size.y * 0.5),
	]
	var out: Array[Vector2] = []
	for w in world:
		out.append(w * _zoom + _content_offset)
	return out


func _begin_resize(edge: int) -> void:
	var sr := _min_visible_rect(_selected[0])
	_resize_start_rect = sr
	_resize_edge = edge
	_resize_anchor = _anchor_for_edge(sr, edge)
	_resize_corner0 = sr.position + Vector2(sr.size.x * _EDGE_FRACTIONS[edge][0], sr.size.y * _EDGE_FRACTIONS[edge][1])
	_resize_befores.clear()
	for s in _selected:
		_resize_befores[s] = s.to_dict()


func _anchor_for_edge(sr: Rect2, edge: int) -> Vector2:
	match edge:
		0:
			return sr.end
		1:
			return Vector2(sr.position.x + sr.size.x * 0.5, sr.end.y)
		2:
			return Vector2(sr.position.x, sr.end.y)
		3:
			return Vector2(sr.position.x, sr.position.y + sr.size.y * 0.5)
		4:
			return sr.position
		5:
			return Vector2(sr.position.x + sr.size.x * 0.5, sr.position.y)
		6:
			return Vector2(sr.end.x, sr.position.y)
		_:
			return Vector2(sr.end.x, sr.position.y + sr.size.y * 0.5)


func _edge_moves_x(edge: int) -> bool:
	return edge in [0, 2, 3, 4, 6, 7]


func _edge_moves_y(edge: int) -> bool:
	return edge in [0, 1, 2, 4, 5, 6]


func _pick_ratio(axis: float, a: float, c0: float, span: float) -> float:
	var r := (axis - a) / (c0 - a)
	var sgn := signf(r)
	if is_zero_approx(sgn):
		sgn = 1.0
	return sgn * clampf(absf(r), RESIZE_MIN_RATIO, RESIZE_MAX_RATIO)


func _resize_ratio(world: Vector2) -> Vector2:
	var a := _resize_anchor
	var c0 := _resize_corner0
	var span := _resize_start_rect.size
	var ratio := Vector2(1.0, 1.0)
	if _edge_moves_x(_resize_edge):
		ratio.x = _pick_ratio(world.x, a.x, c0.x, span.x)
	if _edge_moves_y(_resize_edge):
		ratio.y = _pick_ratio(world.y, a.y, c0.y, span.y)
	return ratio


func _apply_resize(world: Vector2) -> void:
	if _selected.is_empty() or _resize_start_rect.size.x <= 0.0 or _resize_start_rect.size.y <= 0.0:
		return
	var ratio := _resize_ratio(world)
	if absf(ratio.x - 1.0) < 0.001 and absf(ratio.y - 1.0) < 0.001:
		return
	for s in _selected:
		var before: Dictionary = _resize_befores[s]
		s.load_from_dict(before)
		s.rescale(_resize_anchor, ratio)
	queue_redraw()


func _commit_resize() -> void:
	for s in _resize_befores:
		var before: Dictionary = _resize_befores[s]
		var after: Dictionary = s.to_dict()
		if after != before and history != null:
			history.push(ResizeShapeCommand.new(s, before, after))
	_resize_befores.clear()
	queue_redraw()


func _draw_handles(s: Shape) -> void:
	var sr := _min_visible_rect(s)
	var pts := _handle_positions(sr)
	for i in range(pts.size()):
		if not _handle_visible(i):
			continue
		draw_circle(pts[i], HANDLE_RADIUS, Color.WHITE)
		draw_arc(pts[i], HANDLE_RADIUS, 0.0, TAU, 24, SELECTION_COLOR, HANDLE_STROKE)


func _draw_edit_handles() -> void:
	var pts := _edit_handles_screen()
	for p in pts:
		draw_circle(p, HANDLE_RADIUS, Color.WHITE)
		draw_arc(p, HANDLE_RADIUS, 0.0, TAU, 24, SELECTION_COLOR, HANDLE_STROKE)


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
		Shape.Type.QUAD:
			draw_set_transform_matrix(content)
			if s.quad.size() >= 3:
				draw_colored_polygon(s.quad, s.fill)
				draw_polyline(s.quad, s.stroke, s.stroke_width, true)


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
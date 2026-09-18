extends Node2D

const Document := preload("res://core/model/document.gd")
const Shape := preload("res://core/model/shape.gd")

const GRID_SPACING := 24.0
const GRID_DOT_RADIUS := 1.4
const BG_COLOR := Color("#ffffff")
const GRID_COLOR := Color("#d9d9d9")

var document: Document


func setup(doc: Document) -> void:
	document = doc


func _draw() -> void:
	_draw_background()
	if document == null:
		return
	for s in document.shapes:
		_draw_shape(s)


func _draw_background() -> void:
	var vp := get_viewport_rect()
	draw_rect(vp, BG_COLOR)
	var spacing := GRID_SPACING
	var y := vp.position.y + spacing * 0.5
	while y < vp.end.y:
		var x := vp.position.x + spacing * 0.5
		while x < vp.end.x:
			draw_circle(Vector2(x, y), GRID_DOT_RADIUS, GRID_COLOR)
			x += spacing
		y += spacing


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
		var a := TAU * float(i) / float(steps)
		pts.append(Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_set_transform(s.position, deg_to_rad(s.rotation_deg), s.scale)
	draw_colored_polygon(pts, s.fill)
	draw_polyline(pts, s.stroke, s.stroke_width, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
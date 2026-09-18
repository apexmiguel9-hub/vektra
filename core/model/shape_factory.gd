extends RefCounted

const Shape := preload("res://core/model/shape.gd")


static func rect(center: Vector2, w: float, h: float, p_name := "Rect") -> Shape:
	var s := Shape.new(p_name)
	s.type = Shape.Type.RECT
	s.position = center
	s.size = Vector2(w, h)
	return s


static func ellipse(center: Vector2, w: float, h: float, p_name := "Ellipse") -> Shape:
	var s := Shape.new(p_name)
	s.type = Shape.Type.ELLIPSE
	s.position = center
	s.size = Vector2(w, h)
	return s


static func line(a: Vector2, b: Vector2, p_name := "Line") -> Shape:
	var s := Shape.new(p_name)
	s.type = Shape.Type.LINE
	s.line_a = a
	s.line_b = b
	return s


static func path(p_nodes: Array, p_closed := false, p_name := "Path") -> Shape:
	var s := Shape.new(p_name)
	s.type = Shape.Type.PATH
	s.closed = p_closed
	s.nodes.assign(p_nodes)
	for nd in s.nodes:
		if nd.c1 == Vector2.ZERO and nd.c2 == Vector2.ZERO:
			nd.make_straight()
	return s


static func clone(src: Shape) -> Shape:
	var s := Shape.new(src.name)
	s.id = src.id
	s.type = src.type
	s.position = src.position
	s.rotation_deg = src.rotation_deg
	s.scale = src.scale
	s.size = src.size
	s.line_a = src.line_a
	s.line_b = src.line_b
	s.fill = src.fill
	s.stroke = src.stroke
	s.stroke_width = src.stroke_width
	s.visible = src.visible
	return s
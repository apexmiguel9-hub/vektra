extends SceneTree

const Shape := preload("res://core/model/shape.gd")
const ShapeFactory := preload("res://core/model/shape_factory.gd")
const Document := preload("res://core/model/document.gd")
const PathNode := preload("res://core/model/path_node.gd")
const SvgPath := preload("res://core/geo/svg_path.gd")
const Bezier := preload("res://core/geo/bezier.gd")
const History := preload("res://core/history/history.gd")
const AddShapeCommand := preload("res://core/history/add_shape_command.gd")
const RemoveShapeCommand := preload("res://core/history/remove_shape_command.gd")
const MoveShapeCommand := preload("res://core/history/move_shape_command.gd")
const CanvasView := preload("res://shell/canvas_view.gd")

var _passed := 0
var _failed := 0


func _init() -> void:
	_test_rect_geometry()
	_test_rotation_bbox()
	_test_move_and_scale()
	_test_ellipse_hit()
	_test_line_hit()
	_test_document_zorder()
	_test_serialization_roundtrip()
	_test_clone()
	_test_marquee()
	_test_history_add()
	_test_history_move()
	_test_history_remove_index()
	_test_history_redo_cleared()
	_test_history_cap()
	_test_bezier_cubic_mid()
	_test_pip()
	_test_svg_roundtrip_lines()
	_test_svg_parse_curve()
	_test_svg_parse_quad()
	_test_svg_parse_smooth()
	_test_path_hit_closed()
	_test_path_hit_open()
	_test_path_selrect()
	_test_path_shape_roundtrip()
	_test_camera_pan_zoom()
	_test_selection_tap_and_drag()
	_test_selection_empty_tap_deselects()
	_test_marquee_selects()
	_test_line_selectable()
	_test_line_move_via_anchor()
	_test_history_move_line()
	print("=== RESULTADO: %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(label: String, cond: bool) -> void:
	if cond:
		_passed += 1
		print("[PASS] " + label)
	else:
		_failed += 1
		print("[FAIL] " + label)


func _approx(a: float, b: float, eps := 0.001) -> bool:
	return absf(a - b) <= eps


func _vec2_approx(a: Vector2, b: Vector2, eps := 0.001) -> bool:
	return _approx(a.x, b.x, eps) and _approx(a.y, b.y, eps)


func _rect2_approx(a: Rect2, b: Rect2, eps := 0.001) -> bool:
	return _vec2_approx(a.position, b.position, eps) and _vec2_approx(a.size, b.size, eps)


func _test_rect_geometry() -> void:
	var r := ShapeFactory.rect(Vector2.ZERO, 100.0, 50.0)
	var corners := r.get_corners()
	_check("rect corners count == 4", corners.size() == 4)
	_check("rect corner TL", _vec2_approx(corners[0], Vector2(-50, -25)))
	_check("rect corner TR", _vec2_approx(corners[1], Vector2(50, -25)))
	_check("rect corner BR", _vec2_approx(corners[2], Vector2(50, 25)))
	_check("rect corner BL", _vec2_approx(corners[3], Vector2(-50, 25)))
	_check("rect selrect", _rect2_approx(r.get_selrect(), Rect2(-50, -25, 100, 50)))


func _test_rotation_bbox() -> void:
	var r := ShapeFactory.rect(Vector2.ZERO, 200.0, 100.0)
	r.set_rotation_deg(90.0)
	var sr := r.get_selrect()
	_check("rect@90 bbox w=100", _approx(sr.size.x, 100.0))
	_check("rect@90 bbox h=200", _approx(sr.size.y, 200.0))
	_check("rect@90 center preserved", _vec2_approx(sr.get_center(), Vector2.ZERO, 0.5))
	r.set_rotation_deg(45.0)
	var sr45 := r.get_selrect()
	_check("rect@45 bbox diag", _approx(sr45.size.x, 212.132, 0.5))


func _test_move_and_scale() -> void:
	var r := ShapeFactory.rect(Vector2(10, 10), 40.0, 40.0)
	r.move_by(Vector2(5, -5))
	_check("rect moved", _vec2_approx(r.position, Vector2(15, 5)))
	_check("rect contains after move", r.contains_point(Vector2(15, 5)))
	r.scale = Vector2(2, 2)
	_check("rect scaled size", _approx(r.size.x * r.scale.x, 80.0))
	_check("rect scaled contains corner", r.contains_point(Vector2(15 + 39, 5)))
	_check("rect scaled rejects outside", not r.contains_point(Vector2(15 + 45, 5)))


func _test_ellipse_hit() -> void:
	var e := ShapeFactory.ellipse(Vector2.ZERO, 100.0, 100.0)
	_check("ellipse center", e.contains_point(Vector2.ZERO))
	_check("ellipse on axis inside", e.contains_point(Vector2(49, 0)))
	_check("ellipse corner outside", not e.contains_point(Vector2(49, 49)))
	_check("ellipse border hit", e.contains_point(Vector2(50, 0), 4.0))


func _test_line_hit() -> void:
	var l := ShapeFactory.line(Vector2(0, 0), Vector2(100, 0))
	l.stroke_width = 4.0
	_check("line on segment", l.contains_point(Vector2(50, 0)))
	_check("line within stroke", l.contains_point(Vector2(50, 1.5)))
	_check("line beyond stroke", not l.contains_point(Vector2(50, 3.0)))
	_check("line outside span", not l.contains_point(Vector2(120, 0)))
	_check("line bounds", _rect2_approx(l.get_selrect(), Rect2(-2, -2, 104, 4)))


func _test_document_zorder() -> void:
	var doc := Document.new()
	var a := ShapeFactory.rect(Vector2.ZERO, 100.0, 100.0, "A")
	var b := ShapeFactory.rect(Vector2.ZERO, 100.0, 100.0, "B")
	doc.add(a)
	doc.add(b)
	_check("hit topmost is B", doc.hit_test(Vector2.ZERO) == b)
	doc.move_to_top(a.id)
	_check("after move_top hit is A", doc.hit_test(Vector2.ZERO) == a)
	_check("remove works", doc.remove(b.id))
	_check("removed shape not hit", doc.hit_test(Vector2.ZERO) == a)
	_check("null on empty point", doc.hit_test(Vector2(1000, 1000)) == null)


func _test_serialization_roundtrip() -> void:
	var doc := Document.new()
	var r := ShapeFactory.rect(Vector2(120, 80), 200.0, 90.0, "Header")
	r.fill = Color("#3366ff")
	r.rotation_deg = 12.0
	r.stroke_width = 3.0
	var e := ShapeFactory.ellipse(Vector2(400, 240), 80.0, 80.0, "Avatar")
	var l := ShapeFactory.line(Vector2(50, 400), Vector2(700, 400), "Divider")
	doc.add(r)
	doc.add(e)
	doc.add(l)
	var d := doc.to_dict()
	var doc2 := Document.new()
	doc2.load_from_dict(d)
	_check("roundtrip shape count", doc2.shapes.size() == 3)
	_check("roundtrip type rect", doc2.shapes[0].type == Shape.Type.RECT)
	_check("roundtrip position", _vec2_approx(doc2.shapes[0].position, Vector2(120, 80)))
	_check("roundtrip rotation", _approx(doc2.shapes[0].rotation_deg, 12.0))
	_check("roundtrip fill", doc2.shapes[0].fill == Color("#3366ff"))
	_check("roundtrip line", _vec2_approx(doc2.shapes[2].line_a, Vector2(50, 400)))


func _test_clone() -> void:
	var r := ShapeFactory.rect(Vector2(5, 5), 60.0, 60.0, "Src")
	r.fill = Color("#ff8800")
	var c := ShapeFactory.clone(r)
	r.position = Vector2(999, 999)
	_check("clone keeps own position", _vec2_approx(c.position, Vector2(5, 5)))
	_check("clone keeps fill", c.fill == Color("#ff8800"))
	_check("clone same id", c.id == r.id)


func _test_marquee() -> void:
	var doc := Document.new()
	var a := ShapeFactory.rect(Vector2(10, 10), 50.0, 50.0)
	var b := ShapeFactory.rect(Vector2(200, 200), 50.0, 50.0)
	doc.add(a)
	doc.add(b)
	var hit := doc.hit_test_all(Rect2(0, 0, 100, 100))
	_check("marquee selects one", hit.size() == 1)
	_check("marquee picks A", hit[0] == a)


func _test_history_add() -> void:
	var doc := Document.new()
	var hist := History.new()
	var r := ShapeFactory.rect(Vector2.ZERO, 50.0, 50.0)
	hist.push(AddShapeCommand.new(doc, r))
	_check("add command applied", doc.shapes.size() == 1)
	hist.undo()
	_check("add command undone", doc.shapes.is_empty())
	hist.redo()
	_check("add command redone", doc.shapes.size() == 1)
	_check("redo stack clean", not hist.can_redo())


func _test_history_move() -> void:
	var doc := Document.new()
	var hist := History.new()
	var m := ShapeFactory.rect(Vector2(10, 10), 50.0, 50.0)
	doc.add(m)
	hist.push(MoveShapeCommand.new(m, m.position, Vector2(100, 50)))
	_check("move applied", _vec2_approx(m.position, Vector2(100, 50)))
	hist.undo()
	_check("move undone", _vec2_approx(m.position, Vector2(10, 10)))
	hist.redo()
	_check("move redone", _vec2_approx(m.position, Vector2(100, 50)))


func _test_history_remove_index() -> void:
	var doc := Document.new()
	var hist := History.new()
	var a := ShapeFactory.rect(Vector2(0, 0), 10.0, 10.0)
	var b := ShapeFactory.rect(Vector2(20, 20), 10.0, 10.0)
	doc.add(a)
	doc.add(b)
	hist.push(RemoveShapeCommand.new(doc, a))
	_check("remove applied", doc.get_shape(a.id) == null)
	hist.undo()
	_check("remove undone count", doc.shapes.size() == 2)
	_check("remove undone preserves index", doc.shapes[0] == a)
	hist.redo()
	_check("remove redone", doc.get_shape(a.id) == null)


func _test_history_redo_cleared() -> void:
	var doc := Document.new()
	var hist := History.new()
	var r := ShapeFactory.rect(Vector2.ZERO, 10.0, 10.0)
	hist.push(AddShapeCommand.new(doc, r))
	hist.undo()
	_check("can redo before new push", hist.can_redo())
	hist.push(AddShapeCommand.new(doc, ShapeFactory.rect(Vector2(50, 50), 10.0, 10.0)))
	_check("redo cleared by new push", not hist.can_redo())


func _test_history_cap() -> void:
	var doc := Document.new()
	var hist := History.new()
	hist.max_undo = 2
	for i in range(3):
		hist.push(AddShapeCommand.new(doc, ShapeFactory.rect(Vector2(i * 10, 0), 5.0, 5.0)))
	_check("doc has 3 shapes", doc.shapes.size() == 3)
	hist.undo()
	hist.undo()
	_check("cap discards oldest", not hist.can_undo())
	_check("cap leaves 1 shape", doc.shapes.size() == 1)


func _test_bezier_cubic_mid() -> void:
	var p := Bezier.cubic_point(Vector2(0, 0), Vector2(33, 0), Vector2(66, 100), Vector2(100, 100), 0.5)
	_check("cubic mid x", _approx(p.x, 49.625))
	_check("cubic mid y", _approx(p.y, 50.0))


func _test_pip() -> void:
	var tri := PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100)])
	_check("pip inside", Bezier.point_in_polygon(Vector2(50, 30), tri))
	_check("pip outside right", not Bezier.point_in_polygon(Vector2(150, 30), tri))
	_check("pip outside left", not Bezier.point_in_polygon(Vector2(0, 90), tri))


func _test_svg_roundtrip_lines() -> void:
	var parsed: Dictionary = SvgPath.nodes_from_svg_path_data("M 0 0 L 100 0 L 100 100 Z")
	var nodes: Array = parsed["nodes"]
	_check("svg nodes count", nodes.size() == 3)
	_check("svg closed", parsed["closed"] == true)
	_check("svg n0", _vec2_approx(nodes[0].position, Vector2.ZERO))
	_check("svg n1", _vec2_approx(nodes[1].position, Vector2(100, 0)))
	_check("svg n2", _vec2_approx(nodes[2].position, Vector2(100, 100)))
	_check("svg serialized", SvgPath.path_to_svg_data(nodes, parsed["closed"]) == "M 0 0 L 100 0 L 100 100 Z")


func _test_svg_parse_curve() -> void:
	var parsed: Dictionary = SvgPath.nodes_from_svg_path_data("M 0 0 C 33 0 66 100 100 100")
	var nodes: Array = parsed["nodes"]
	_check("curve nodes", nodes.size() == 2)
	_check("curve prev c2", _vec2_approx(nodes[0].c2, Vector2(33, 0)))
	_check("curve cur c1", _vec2_approx(nodes[1].c1, Vector2(66, 100)))
	_check("curve cur pos", _vec2_approx(nodes[1].position, Vector2(100, 100)))
	_check("curve serialized", SvgPath.path_to_svg_data(nodes, false) == "M 0 0 C 33 0 66 100 100 100")


func _test_svg_parse_quad() -> void:
	var parsed: Dictionary = SvgPath.nodes_from_svg_path_data("M 0 0 Q 50 0 100 0")
	var nodes: Array = parsed["nodes"]
	_check("quad prev c2", _vec2_approx(nodes[0].c2, Vector2(33.333, 0), 0.01))
	_check("quad cur c1", _vec2_approx(nodes[1].c1, Vector2(66.667, 0), 0.01))


func _test_svg_parse_smooth() -> void:
	var parsed: Dictionary = SvgPath.nodes_from_svg_path_data("M 0 0 C 33 0 66 100 100 100 S 133 100 200 0")
	var nodes: Array = parsed["nodes"]
	_check("smooth nodes", nodes.size() == 3)
	_check("smooth reflection c2", _vec2_approx(nodes[1].c2, Vector2(134, 100), 0.01))
	_check("smooth cur c1", _vec2_approx(nodes[2].c1, Vector2(133, 100), 0.01))
	_check("smooth cur pos", _vec2_approx(nodes[2].position, Vector2(200, 0), 0.01))


func _test_path_hit_closed() -> void:
	var p := ShapeFactory.path([
		PathNode.new(Vector2(0, 0)),
		PathNode.new(Vector2(100, 0)),
		PathNode.new(Vector2(100, 100)),
	], true)
	_check("path inside", p.contains_point(Vector2(50, 30)))
	_check("path outside", not p.contains_point(Vector2(150, 30)))
	_check("path border within threshold", p.contains_point(Vector2(101.5, 50), 2.0))
	_check("path border beyond threshold", not p.contains_point(Vector2(103, 50), 2.0))


func _test_path_hit_open() -> void:
	var p := ShapeFactory.path([PathNode.new(Vector2(0, 0)), PathNode.new(Vector2(100, 0))])
	p.stroke_width = 2.0
	_check("open on", p.contains_point(Vector2(50, 0)))
	_check("open within stroke", p.contains_point(Vector2(50, 1)))
	_check("open beyond stroke", not p.contains_point(Vector2(50, 3)))


func _test_path_selrect() -> void:
	var p := ShapeFactory.path([
		PathNode.new(Vector2(0, 0)),
		PathNode.new(Vector2(100, 0), Vector2.ZERO, Vector2(0, -40)),
		PathNode.new(Vector2(100, 100)),
	], true)
	var sr := p.get_selrect()
	_check("path bbox top", _approx(sr.position.y, -40.0))
	_check("path bbox height", _approx(sr.size.y, 140.0))
	_check("path bbox width", _approx(sr.size.x, 100.0))


func _test_path_shape_roundtrip() -> void:
	var p := ShapeFactory.path([
		PathNode.new(Vector2(0, 0)),
		PathNode.new(Vector2(100, 0)),
		PathNode.new(Vector2(100, 100)),
	], true)
	p.fill = Color("#ff3366")
	var d := p.to_dict()
	var p2 := Shape.new()
	p2.load_from_dict(d)
	_check("path roundtrip type", p2.type == Shape.Type.PATH)
	_check("path roundtrip closed", p2.closed)
	_check("path roundtrip nodes", p2.nodes.size() == 3)
	_check("path roundtrip fill", p2.fill == Color("#ff3366"))
	_check("path roundtrip hit", p2.contains_point(Vector2(50, 30)))


func _test_camera_pan_zoom() -> void:
	var cv := CanvasView.new()
	cv._zoom = 1.0
	cv._content_offset = Vector2(100, 200)
	var center := Vector2(300, 400)
	cv._apply_camera(Vector2.ZERO, 2.0, center)
	var world := (center - cv._content_offset) / cv._zoom
	_check("cam zoom applied", _approx(cv._zoom, 2.0))
	_check("cam anchor stays on center", _vec2_approx(world, Vector2(200, 200)))
	var before := cv._content_offset
	cv._apply_camera(Vector2(10, -5), 1.0, center)
	var moved := cv._content_offset - before
	_check("cam pan translates by delta", _vec2_approx(moved, Vector2(10, -5)))
	var zoomed := cv._zoom
	cv._apply_camera(Vector2.ZERO, 100.0, center)
	_check("cam clamps max zoom", _approx(cv._zoom, 8.0))
	cv._apply_camera(Vector2.ZERO, 0.0001, center)
	_check("cam clamps min zoom", _approx(cv._zoom, 0.2))
	_check("cam zoom unchanged when maxed", _approx(zoomed, 2.0))
	cv.free()


func _test_selection_tap_and_drag() -> void:
	var doc := Document.new()
	var r := ShapeFactory.rect(Vector2(100, 100), 50, 50, "r")
	doc.add(r)
	var cv := CanvasView.new()
	cv._zoom = 1.0
	cv._content_offset = Vector2.ZERO
	cv.setup(doc)
	cv._start_press(Vector2(100, 100))
	_check("tap selects shape", cv._selected.size() == 1 and cv._selected[0] == r)
	cv._end_press()
	_check("tap keeps selection", cv._selected.size() == 1)
	cv._start_press(Vector2(100, 100))
	cv._handle_drag(Vector2(160, 100))
	_check("drag moves shape", _vec2_approx(r.position, Vector2(160, 100)))
	cv._end_press()
	_check("drag not active after release", cv._drag_mode == 0)
	cv.free()


func _test_selection_empty_tap_deselects() -> void:
	var doc := Document.new()
	var r := ShapeFactory.rect(Vector2(400, 400), 60, 60, "r")
	doc.add(r)
	var cv := CanvasView.new()
	cv._zoom = 1.0
	cv._content_offset = Vector2.ZERO
	cv.setup(doc)
	cv._start_press(Vector2(400, 400))
	_check("press selects rect", cv._selected.size() == 1)
	cv._start_press(Vector2(12, 12))
	cv._end_press()
	_check("tap empty deselects", cv._selected.is_empty())
	cv.free()


func _test_marquee_selects() -> void:
	var doc := Document.new()
	var a := ShapeFactory.rect(Vector2(100, 100), 60, 60, "a")
	var b := ShapeFactory.rect(Vector2(300, 300), 60, 60, "b")
	doc.add(a)
	doc.add(b)
	var cv := CanvasView.new()
	cv._zoom = 1.0
	cv._content_offset = Vector2.ZERO
	cv.setup(doc)
	cv._start_press(Vector2(20, 20))
	cv._handle_drag(Vector2(180, 180))
	cv._end_press()
	_check("marquee selects only A", cv._selected.size() == 1 and cv._selected[0] == a)
	cv._start_press(Vector2(20, 20))
	cv._handle_drag(Vector2(400, 400))
	cv._end_press()
	_check("marquee selects both", cv._selected.size() == 2)
	cv.free()


func _test_line_selectable() -> void:
	var doc := Document.new()
	var l := ShapeFactory.line(Vector2(0, 0), Vector2(400, 0), "l")
	l.stroke_width = 3.0
	doc.add(l)
	var cv := CanvasView.new()
	cv._zoom = 1.0
	cv._content_offset = Vector2.ZERO
	cv.setup(doc)
	cv._start_press(Vector2(200, 8))
	_check("line grabs within fat finger", cv._selected.size() == 1 and cv._selected[0] == l)
	cv._start_press(Vector2(200, 40))
	cv._end_press()
	_check("line missed far away", cv._selected.is_empty())
	cv.free()


func _test_line_move_via_anchor() -> void:
	var doc := Document.new()
	var l := ShapeFactory.line(Vector2(0, 0), Vector2(400, 0), "l")
	doc.add(l)
	var cv := CanvasView.new()
	cv._zoom = 1.0
	cv._content_offset = Vector2.ZERO
	cv.setup(doc)
	cv._start_press(Vector2(200, 0))
	cv._handle_drag(Vector2(230, 60))
	cv._end_press()
	_check("line moved both endpoints", _vec2_approx(l.line_a, Vector2(30, 60)) and _vec2_approx(l.line_b, Vector2(430, 60)))
	cv.free()


func _test_history_move_line() -> void:
	var l := ShapeFactory.line(Vector2(0, 0), Vector2(100, 0))
	var hist := History.new()
	hist.push(MoveShapeCommand.new(l, Vector2(0, 0), Vector2(50, 50)))
	_check("line command applied", _vec2_approx(l.line_a, Vector2(50, 50)) and _vec2_approx(l.line_b, Vector2(150, 50)))
	hist.undo()
	_check("line command undone", _vec2_approx(l.line_a, Vector2(0, 0)) and _vec2_approx(l.line_b, Vector2(100, 0)))
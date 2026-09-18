extends SceneTree

const Shape := preload("res://core/model/shape.gd")
const ShapeFactory := preload("res://core/model/shape_factory.gd")
const Document := preload("res://core/model/document.gd")

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
	_check("line bounds", _rect2_approx(l.get_selrect(), Rect2(0, 0, 100, 0)))


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
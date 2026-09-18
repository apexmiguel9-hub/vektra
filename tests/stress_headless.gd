extends SceneTree

const Document := preload("res://core/model/document.gd")
const ShapeFactory := preload("res://core/model/shape_factory.gd")
const PathNode := preload("res://core/model/path_node.gd")


func _init() -> void:
	var doc := Document.new()
	for i in range(2000):
		var x := float(i % 100) * 11.0
		var y := float(i / 100) * 14.0
		match i % 4:
			0:
				doc.add(ShapeFactory.rect(Vector2(x, y), 32, 22))
			1:
				doc.add(ShapeFactory.ellipse(Vector2(x + 300.0, y), 26, 20))
			2:
				doc.add(ShapeFactory.line(Vector2(x, y), Vector2(x + 44.0, y + 30.0)))
			3:
				doc.add(ShapeFactory.path([
					PathNode.new(Vector2(x, y)),
					PathNode.new(Vector2(x + 30.0, y)),
					PathNode.new(Vector2(x + 30.0, y + 30.0)),
					PathNode.new(Vector2(x, y + 30.0)),
				], true))
	print("[stress] shapes: ", doc.shapes.size())

	var t0 := Time.get_ticks_usec()
	var dicts: Array = []
	for s in doc.shapes:
		dicts.append(s.to_dict())
	var t1 := Time.get_ticks_usec()
	print("[stress] serialized %d dicts in %.2f ms" % [dicts.size(), (t1 - t0) / 1000.0])

	t0 = Time.get_ticks_usec()
	var hits := 0
	for i in range(2000):
		if doc.shapes[i % doc.shapes.size()].contains_point(Vector2(i, i)):
			hits += 1
	t1 = Time.get_ticks_usec()
	print("[stress] 2000 hit-tests (incl path flatten) in %.2f ms, hits=%d" % [(t1 - t0) / 1000.0, hits])

	t0 = Time.get_ticks_usec()
	var loaded := Document.new()
	loaded.load_from_dict({"format_version": 1, "shapes": dicts})
	t1 = Time.get_ticks_usec()
	print("[stress] loaded %d shapes from dicts in %.2f ms" % [loaded.shapes.size(), (t1 - t0) / 1000.0])

	print("[stress] stress ok")
	quit(0)
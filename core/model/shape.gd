extends RefCounted

const PathNode := preload("res://core/model/path_node.gd")
const SvgPath := preload("res://core/geo/svg_path.gd")
const Bezier := preload("res://core/geo/bezier.gd")

enum Type { RECT, ELLIPSE, LINE, PATH, QUAD }

var id := ""
var name := ""
var type := Type.RECT

var position := Vector2.ZERO
var rotation_deg := 0.0
var scale := Vector2.ONE

var size := Vector2.ZERO

var line_a := Vector2.ZERO
var line_b := Vector2.ZERO

var nodes: Array[PathNode] = []
var closed := false
var quad := PackedVector2Array()

var fill := Color(1, 1, 1, 1)
var stroke := Color(0, 0, 0, 1)
var stroke_width := 2.0
var visible := true


static func make_id() -> String:
	return "%d%04d" % [Time.get_ticks_usec(), randi_range(0, 9999)]


func _init(p_name := "") -> void:
	if p_name != "":
		name = p_name
	id = make_id()


func get_transform() -> Transform2D:
	var t := Transform2D(deg_to_rad(rotation_deg), Vector2.ZERO)
	t = t.scaled(scale)
	t.origin += position
	return t


func get_corners() -> PackedVector2Array:
	if type == Type.LINE:
		return PackedVector2Array([line_a, line_b])
	if type == Type.QUAD:
		return quad
	var hw := size.x * 0.5
	var hh := size.y * 0.5
	var local := PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh),
	])
	var t := get_transform()
	var out := PackedVector2Array()
	for c in local:
		out.append(t * c)
	return out


func get_selrect() -> Rect2:
	if type == Type.LINE:
		return Rect2(line_a, line_b - line_a).abs().grow(stroke_width * 0.5)
	if type == Type.PATH:
		if nodes.is_empty():
			return Rect2(position, Vector2.ZERO)
		var pts := PackedVector2Array()
		for nd in nodes:
			pts.append(nd.position)
			pts.append(nd.c1)
			pts.append(nd.c2)
		var minp := pts[0]
		var maxp := pts[0]
		for i in range(1, pts.size()):
			minp = minp.min(pts[i])
			maxp = maxp.max(pts[i])
		return Rect2(minp, maxp - minp)
	if type == Type.QUAD and quad.is_empty():
		return Rect2(position, Vector2.ZERO)
	var pts := get_corners()
	var minp := pts[0]
	var maxp := pts[0]
	for i in range(1, pts.size()):
		minp = minp.min(pts[i])
		maxp = maxp.max(pts[i])
	return Rect2(minp, maxp - minp)


func get_center() -> Vector2:
	return get_selrect().get_center()


func move_by(delta: Vector2) -> void:
	if type == Type.LINE:
		line_a += delta
		line_b += delta
	elif type == Type.QUAD:
		for i in range(quad.size()):
			quad[i] = quad[i] + delta
	else:
		position += delta


func get_anchor() -> Vector2:
	if type == Type.LINE:
		return line_a
	if type == Type.QUAD:
		if not quad.is_empty():
			return quad[0]
		return position
	return position


func set_anchor(v: Vector2) -> void:
	if type == Type.LINE:
		var d := v - line_a
		line_a += d
		line_b += d
	elif type == Type.QUAD:
		var d := v - get_anchor()
		for i in range(quad.size()):
			quad[i] = quad[i] + d
	else:
		position = v


func rescale(anchor: Vector2, ratio: Vector2) -> void:
	if type == Type.LINE:
		line_a = anchor + (line_a - anchor) * ratio
		line_b = anchor + (line_b - anchor) * ratio
	elif type == Type.QUAD:
		for i in range(quad.size()):
			quad[i] = anchor + (quad[i] - anchor) * ratio
	elif type == Type.PATH:
		for nd in nodes:
			nd.position = anchor + (nd.position - anchor) * ratio
			nd.c1 = anchor + (nd.c1 - anchor) * ratio
			nd.c2 = anchor + (nd.c2 - anchor) * ratio
		position = anchor + (position - anchor) * ratio
	else:
		position = anchor + (position - anchor) * ratio
		size.x = maxf(size.x * absf(ratio.x), 1.0)
		size.y = maxf(size.y * absf(ratio.y), 1.0)


func set_rotation_deg(deg: float) -> void:
	rotation_deg = fposmod(deg, 360.0)


func contains_point(p: Vector2, threshold := 2.0) -> bool:
	if not visible:
		return false
	if type == Type.LINE:
		var closest := Geometry2D.get_closest_point_to_segment(p, line_a, line_b)
		return p.distance_to(closest) <= maxf(threshold, stroke_width * 0.5)
	if type == Type.QUAD:
		if quad.size() < 3:
			return false
		var t := maxf(threshold, stroke_width * 0.5)
		return Bezier.point_in_polygon(p, quad) or Bezier.distance_to_polyline(p, quad) <= t
	if type == Type.PATH:
		var t := maxf(threshold, stroke_width * 0.5)
		if nodes.size() < 2:
			return false
		var poly := get_flattened_polyline()
		if closed:
			return Bezier.point_in_polygon(p, poly) or Bezier.distance_to_polyline(p, poly) <= t
		return Bezier.distance_to_polyline(p, poly) <= t
	var local := get_transform().affine_inverse() * p
	if _is_inside_local(local):
		return true
	return _border_distance(local) <= maxf(threshold, stroke_width * 0.5)


func get_flattened_polyline(steps := 10) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if nodes.is_empty():
		return pts
	var n := nodes.size()
	var count := n if closed else n - 1
	if count <= 0:
		return pts
	for i in range(count):
		var a: PathNode = nodes[i]
		var b: PathNode = nodes[(i + 1) % n]
		_append_flattened(pts, a.position)
		if SvgPath.segments_are_curved(a, b):
			for k in range(1, steps):
				var tt := float(k) / float(steps)
				_append_flattened(pts, Bezier.cubic_point(a.position, a.c2, b.c1, b.position, tt))
		_append_flattened(pts, b.position)
	return pts


func _append_flattened(pts: PackedVector2Array, pt: Vector2) -> void:
	if not pts.is_empty() and pts[pts.size() - 1] == pt:
		return
	pts.append(pt)


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"type": Type.keys()[type].to_lower(),
		"x": position.x,
		"y": position.y,
		"rotation_deg": rotation_deg,
		"sx": scale.x,
		"sy": scale.y,
		"width": size.x,
		"height": size.y,
		"line_a": [line_a.x, line_a.y],
		"line_b": [line_b.x, line_b.y],
		"fill": "#" + fill.to_html(),
		"stroke": "#" + stroke.to_html(),
		"stroke_width": stroke_width,
		"closed": closed,
		"d": SvgPath.path_to_svg_data(nodes, closed),
		"quad": _quad_to_array(),
	}


func _quad_to_array() -> Array:
	var out: Array = []
	for p in quad:
		out.append([p.x, p.y])
	return out


func load_from_dict(d: Dictionary) -> void:
	id = d.get("id", make_id())
	name = d.get("name", "")
	type = _type_from_string(d.get("type", "rect"))
	position = Vector2(d.get("x", 0.0), d.get("y", 0.0))
	rotation_deg = d.get("rotation_deg", 0.0)
	scale = Vector2(d.get("sx", 1.0), d.get("sy", 1.0))
	size = Vector2(d.get("width", 0.0), d.get("height", 0.0))
	var la: Array = d.get("line_a", [0.0, 0.0])
	var lb: Array = d.get("line_b", [0.0, 0.0])
	line_a = Vector2(la[0], la[1])
	line_b = Vector2(lb[0], lb[1])
	fill = Color(d.get("fill", "#ffffff"))
	stroke = Color(d.get("stroke", "#000000"))
	stroke_width = d.get("stroke_width", 2.0)
	closed = d.get("closed", false)
	nodes.clear()
	quad.clear()
	if type == Type.PATH:
		var parsed: Dictionary = SvgPath.nodes_from_svg_path_data(d.get("d", ""))
		nodes.assign(parsed["nodes"])
		closed = parsed["closed"]
	elif type == Type.QUAD:
		var qa: Array = d.get("quad", [])
		for qp in qa:
			var pa: Array = qp
			quad.append(Vector2(pa[0], pa[1]))


func _is_inside_local(local: Vector2) -> bool:
	match type:
		Type.RECT:
			return Rect2(-size * 0.5, size).has_point(local)
		Type.ELLIPSE:
			var nx := local.x / maxf(size.x * 0.5, 0.0001)
			var ny := local.y / maxf(size.y * 0.5, 0.0001)
			return nx * nx + ny * ny <= 1.0
	return false


func _border_distance(local: Vector2) -> float:
	match type:
		Type.ELLIPSE:
			var nx := local.x / maxf(size.x * 0.5, 0.0001)
			var ny := local.y / maxf(size.y * 0.5, 0.0001)
			var radial := sqrt(nx * nx + ny * ny)
			return absf(radial - 1.0) * minf(size.x, size.y) * 0.25
		_:
			var hw := size.x * 0.5
			var hh := size.y * 0.5
			var dx := absf(local.x) - hw
			var dy := absf(local.y) - hh
			if dx < 0.0 and dy < 0.0:
				return 0.0
			return sqrt(maxf(dx, 0.0) * maxf(dx, 0.0) + maxf(dy, 0.0) * maxf(dy, 0.0))


static func _type_from_string(t: String) -> int:
	match t.to_lower():
		"ellipse":
			return Type.ELLIPSE
		"line":
			return Type.LINE
		"path":
			return Type.PATH
		"quad":
			return Type.QUAD
		_:
			return Type.RECT


func convert_to_quad() -> void:
	if type == Type.QUAD:
		return
	var c := get_corners()
	if type == Type.LINE or c.size() != 4:
		return
	quad = c
	type = Type.QUAD
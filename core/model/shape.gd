extends RefCounted

enum Type { RECT, ELLIPSE, LINE }

var id := ""
var name := ""
var type := Type.RECT

var position := Vector2.ZERO
var rotation_deg := 0.0
var scale := Vector2.ONE

var size := Vector2.ZERO

var line_a := Vector2.ZERO
var line_b := Vector2.ZERO

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
		return Rect2(line_a, line_b - line_a).abs()
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
	position += delta


func set_rotation_deg(deg: float) -> void:
	rotation_deg = fposmod(deg, 360.0)


func contains_point(p: Vector2, threshold := 2.0) -> bool:
	if not visible:
		return false
	if type == Type.LINE:
		var closest := Geometry2D.get_closest_point_to_segment(p, line_a, line_b)
		return p.distance_to(closest) <= maxf(threshold, stroke_width * 0.5)
	var local := get_transform().affine_inverse() * p
	if _is_inside_local(local):
		return true
	return _border_distance(local) <= maxf(threshold, stroke_width * 0.5)


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
	}


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
		_:
			return Type.RECT
extends RefCounted

const PathNode := preload("res://core/model/path_node.gd")

const EPS := 0.001
const COMMANDS := "MLCSQZAHV"


static func format_number(v: float) -> String:
	var s := "%.3f" % v
	if not s.contains("."):
		return s
	s = s.rstrip("0")
	s = s.rstrip(".")
	return s


static func segments_are_curved(a: PathNode, b: PathNode) -> bool:
	return a.position.distance_to(a.c2) > EPS or b.position.distance_to(b.c1) > EPS


static func path_to_svg_data(nodes: Array[PathNode], closed: bool) -> String:
	if nodes.is_empty():
		return ""
	var parts: PackedStringArray = []
	var first: PathNode = nodes[0]
	parts.append("M " + format_number(first.position.x) + " " + format_number(first.position.y))
	for i in range(1, nodes.size()):
		var prev: PathNode = nodes[i - 1]
		var cur: PathNode = nodes[i]
		if segments_are_curved(prev, cur):
			parts.append(
				"C " + format_number(prev.c2.x) + " " + format_number(prev.c2.y)
				+ " " + format_number(cur.c1.x) + " " + format_number(cur.c1.y)
				+ " " + format_number(cur.position.x) + " " + format_number(cur.position.y)
			)
		else:
			parts.append("L " + format_number(cur.position.x) + " " + format_number(cur.position.y))
	if closed and nodes.size() > 2:
		parts.append("Z")
	return " ".join(parts)


static func nodes_from_svg_path_data(data: String) -> Dictionary:
	var tokens := _tokenize(data)
	var nodes: Array[PathNode] = []
	var closed := false
	var i := 0
	var cur := Vector2.ZERO
	var start := Vector2.ZERO
	var last_control := Vector2.ZERO
	var last_command := ""

	while i < tokens.size():
		var cmd_raw: String = tokens[i]
		if not _is_command(cmd_raw):
			break
		i += 1
		var cmd := cmd_raw.to_upper()
		var rel := cmd_raw != cmd

		match cmd:
			"M":
				var res = _read_points(tokens, i, 1, rel, cur)
				if res == null:
					break
				var pt: Vector2 = res[0]
				i = res[1]
				cur = pt
				start = pt
				nodes.append(PathNode.new(pt, pt, pt))
				last_control = pt
				last_command = "M"
				while true:
					var extra = _read_points(tokens, i, 1, rel, cur)
					if extra == null:
						break
					var pt2: Vector2 = extra[0]
					i = extra[1]
					cur = pt2
					_append_line_node(nodes, pt2)
					last_control = pt2
			"L":
				while true:
					var res = _read_points(tokens, i, 1, rel, cur)
					if res == null:
						break
					var pt: Vector2 = res[0]
					i = res[1]
					cur = pt
					_append_line_node(nodes, pt)
					last_control = pt
				last_command = "L"
			"C":
				var res = _read_points(tokens, i, 3, rel, cur)
				if res == null:
					break
				var ctrl1: Vector2 = res[0]
				var ctrl2: Vector2 = res[1]
				var pt: Vector2 = res[2]
				i = res[3]
				_append_curve_node(nodes, ctrl1, ctrl2, pt)
				cur = pt
				last_control = ctrl2
				last_command = "C"
			"S":
				var res = _read_points(tokens, i, 2, rel, cur)
				if res == null:
					break
				var ctrl2: Vector2 = res[0]
				var pt: Vector2 = res[1]
				i = res[2]
				var ctrl1 := _smooth_incoming(last_command, last_control, cur)
				_append_curve_node(nodes, ctrl1, ctrl2, pt)
				cur = pt
				last_control = ctrl2
				last_command = "S"
			"Q":
				var res = _read_points(tokens, i, 2, rel, cur)
				if res == null:
					break
				var quad_ctrl: Vector2 = res[0]
				var pt: Vector2 = res[1]
				i = res[2]
				var ctrl1 := cur + (2.0 / 3.0) * (quad_ctrl - cur)
				var ctrl2 := pt + (2.0 / 3.0) * (quad_ctrl - pt)
				_append_curve_node(nodes, ctrl1, ctrl2, pt)
				cur = pt
				last_control = ctrl2
				last_command = "Q"
			"Z":
				if nodes.size() > 2:
					closed = true
				cur = start
				last_command = "Z"
			_:
				break

	if closed and nodes.size() > 1 and nodes[0].position.distance_to(nodes[nodes.size() - 1].position) < EPS:
		nodes.pop_back()

	return {"nodes": nodes, "closed": closed}


static func _append_line_node(nodes: Array[PathNode], pt: Vector2) -> void:
	var prev: PathNode = nodes[nodes.size() - 1]
	prev.c2 = prev.position
	nodes.append(PathNode.new(pt, pt, pt))


static func _append_curve_node(nodes: Array[PathNode], ctrl1: Vector2, ctrl2: Vector2, pt: Vector2) -> void:
	var prev: PathNode = nodes[nodes.size() - 1]
	prev.c2 = ctrl1
	nodes.append(PathNode.new(pt, ctrl2, pt))


static func _smooth_incoming(last_command: String, last_control: Vector2, cur: Vector2) -> Vector2:
	if last_command == "S" or last_command == "C" or last_command == "Q":
		return 2.0 * cur - last_control
	return cur


static func _read_points(tokens: Array[String], i: int, count: int, rel: bool, origin: Vector2):
	if i + count * 2 > tokens.size():
		return null
	var pts: Array = []
	for k in range(count):
		if not _is_number(tokens[i]) or not _is_number(tokens[i + 1]):
			return null
		var x: float = tokens[i].to_float()
		var y: float = tokens[i + 1].to_float()
		i += 2
		var pt := Vector2(x, y)
		if rel:
			pt += origin
		pts.append(pt)
	pts.append(i)
	return pts


static func _is_number(s: String) -> bool:
	if s.is_empty():
		return false
	var c0 := s[0]
	return c0.is_valid_int() or c0 == "-" or c0 == "+" or c0 == "."


static func _is_command(s: String) -> bool:
	if s.length() != 1:
		return false
	return COMMANDS.find(s.to_upper()) != -1


static func _is_number_char(ch: String) -> bool:
	return ch.is_valid_int() or ch == "-" or ch == "+" or ch == "." or ch == "e" or ch == "E"


static func _tokenize(data: String) -> Array[String]:
	var out: Array[String] = []
	var num := ""
	for k in range(data.length()):
		var ch := data[k]
		if _is_number_char(ch):
			num += ch
		else:
			if num != "":
				out.append(num)
				num = ""
			if _is_command(ch):
				out.append(ch)
	if num != "":
		out.append(num)
	return out
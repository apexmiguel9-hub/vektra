extends RefCounted

static func cubic_point(p0: Vector2, c1: Vector2, c2: Vector2, p1: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	var w0 := u * u * u
	var w1 := 3.0 * u * u * t
	var w2 := 3.0 * u * t * t
	var w3 := t * t * t
	return p0 * w0 + c1 * w1 + c2 * w2 + p1 * w3


static func quad_point(p0: Vector2, c: Vector2, p1: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return p0 * (u * u) + c * (2.0 * u * t) + p1 * (t * t)


static func point_in_polygon(p: Vector2, poly: PackedVector2Array) -> bool:
	if poly.size() < 3:
		return false
	var inside := false
	var j := poly.size() - 1
	for i in range(poly.size()):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[j]
		if (a.y > p.y) != (b.y > p.y):
			var x_int := a.x + (p.y - a.y) / (b.y - a.y) * (b.x - a.x)
			if x_int > p.x:
				inside = not inside
		j = i
	return inside


static func distance_to_polyline(p: Vector2, pts: PackedVector2Array) -> float:
	if pts.size() < 2:
		if pts.size() == 1:
			return p.distance_to(pts[0])
		return INF
	var min_d := INF
	for i in range(pts.size() - 1):
		var closest := Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])
		min_d = minf(min_d, p.distance_to(closest))
	return min_d
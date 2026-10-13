extends SceneTree

const DIRECTIONS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

func project_point(vertex: Array) -> Vector2:
	return Vector2(512 + (vertex[0] - vertex[1]) * 80, 700 + (vertex[0] + vertex[1]) * 60 - vertex[2] * 80)

func polygon(vertices: Array, fill: String) -> String:
	var points := PackedStringArray()
	for vertex in vertices:
		var point := project_point(vertex)
		points.append("%.2f,%.2f" % [point.x, point.y])
	return '<polygon points="%s" fill="%s" stroke="#66503b" stroke-width="2" stroke-linejoin="round"/>' % [" ".join(points), fill]

func box(x0: float, y0: float, x1: float, y1: float, z0: float, z1: float) -> String:
	var result := polygon([[x0, y0, z1], [x1, y0, z1], [x1, y1, z1], [x0, y1, z1]], "#dcb165")
	result += polygon([[x0, y1, z0], [x1, y1, z0], [x1, y1, z1], [x0, y1, z1]], "#b47b3f")
	result += polygon([[x1, y0, z0], [x1, y1, z0], [x1, y1, z1], [x1, y0, z1]], "#956334")
	return result

func stake(x: float, y: float) -> String:
	var half_width := 0.42
	var result := box(x - half_width, y - half_width, x + half_width, y + half_width, 0.0, 3.8)
	result += polygon([[x - half_width, y - half_width, 3.8], [x + half_width, y - half_width, 3.8], [x, y, 4.5]], "#e6bb77")
	result += polygon([[x + half_width, y - half_width, 3.8], [x + half_width, y + half_width, 3.8], [x, y, 4.5]], "#c99655")
	result += polygon([[x + half_width, y + half_width, 3.8], [x - half_width, y + half_width, 3.8], [x, y, 4.5]], "#dca862")
	result += polygon([[x - half_width, y + half_width, 3.8], [x - half_width, y - half_width, 3.8], [x, y, 4.5]], "#efc98e")
	return result

func make_guide(mask: int) -> void:
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024"><rect width="1024" height="1024" fill="#eef0f2"/>'
	svg += polygon([[-2.5, -2.5, 0], [2.5, -2.5, 0], [2.5, 2.5, 0], [-2.5, 2.5, 0]], "#bc9163")
	var positions: Array[Vector2i] = [Vector2i.ZERO]
	for i in range(4):
		if mask & (1 << i):
			positions.append(DIRECTIONS[i])
			positions.append(DIRECTIONS[i] * 2)
	positions.sort_custom(func(a: Vector2i, b: Vector2i): return a.x + a.y < b.x + b.y)
	for position in positions:
		svg += stake(position.x, position.y)
	for i in range(4):
		if not mask & (1 << i):
			continue
		var direction: Vector2i = DIRECTIONS[i]
		for z in [0.9, 2.5]:
			if direction.x != 0:
				svg += box(minf(0, direction.x * 2.5), 0.42, maxf(0, direction.x * 2.5), 0.68, z, z + 0.25)
			else:
				svg += box(0.42, minf(0, direction.y * 2.5), 0.68, maxf(0, direction.y * 2.5), z, z + 0.25)
	svg += '</svg>'
	var image := Image.new()
	if image.load_svg_from_string(svg) != OK:
		quit(1)
		return
	image.save_png("res://.godot/palisade-mask-%02d-guide.png" % mask)

func _initialize() -> void:
	for mask in range(16):
		make_guide(mask)
	quit()

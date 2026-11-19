extends RefCounted

# Painted scene: atmospheric water and shores, cartoon fish on top.
# Phase numbers match the enum in main.gd.

const W := 390.0
const H := 844.0
const HORIZON := 368.0

const INK := Color("07141a")
const CREAM := Color("f4ebda")
const GOLD := Color("e4a04a")
const MUTED := Color("8aa09a")
const RUST := Color("c46a45")
const GREEN := Color("7ea37a")

const P_HOME := 0
const P_READY := 1
const P_CHARGING := 2
const P_FLYING := 3
const P_WAITING := 4
const P_BITE := 5
const P_FIGHT := 6
const P_RESULT := 7
const P_SHOP := 8
const P_DEX := 9
const P_MAP := 10

const Catalog = preload("res://scripts/catalog.gd")


func paint(n: Node2D) -> void:
	var id := str(n.save.get("location", "cove"))
	var pal := _pal(id)
	_sky(n, pal, id)
	_hills(n, pal, id)
	_trees(n, pal, id)
	_water(n, pal, id)
	_underwater(n, pal, id)
	_foreground(n, pal, id)
	_angler(n, pal)
	_tackle(n, pal, id)
	_vignette(n)
	_ui(n, pal, id)


func _pal(id: String) -> Dictionary:
	match id:
		"river":
			return {
				"sky0": Color("24362e"),
				"sky1": Color("e7b36a"),
				"sky2": Color("f3e0c0"),
				"hill": Color("1b3328"),
				"hill_far": Color("3d5a48"),
				"water0": Color("8fbf9a"),
				"water1": Color("1d4a38"),
				"deep": Color("071c16"),
				"mist": Color("d5e6da"),
			}
		"pier":
			return {
				"sky0": Color("070910"),
				"sky1": Color("1a2744"),
				"sky2": Color("3a4e78"),
				"hill": Color("101624"),
				"hill_far": Color("1c2740"),
				"water0": Color("24344a"),
				"water1": Color("0c1824"),
				"deep": Color("04080e"),
				"mist": Color("9eb0c8"),
			}
		"sea":
			return {
				"sky0": Color("1d6eab"),
				"sky1": Color("7ec8ea"),
				"sky2": Color("f6e3b0"),
				"hill": Color("1d5c48"),
				"hill_far": Color("6ea0b8"),
				"water0": Color("3ec8c4"),
				"water1": Color("0d6e86"),
				"deep": Color("06303c"),
				"mist": Color("e8f6f4"),
			}
		_:
			return {
				"sky0": Color("1a3356"),
				"sky1": Color("e07a55"),
				"sky2": Color("ffd7a8"),
				"hill": Color("1a3830"),
				"hill_far": Color("5c4038"),
				"water0": Color("e7b07a"),
				"water1": Color("1a5960"),
				"deep": Color("06242c"),
				"mist": Color("f0d8c0"),
			}


func _sky(n: Node2D, pal: Dictionary, id: String) -> void:
	var top: Color = pal["sky0"]
	var mid: Color = pal["sky1"]
	var low: Color = pal["sky2"]
	for i in 28:
		var u := float(i) / 27.0
		var col: Color = top.lerp(mid, smoothstep(0.0, 0.72, u)).lerp(low, smoothstep(0.45, 1.0, u))
		n.draw_rect(Rect2(0, u * (HORIZON + 24.0), W, 20), col, true)
	if id == "pier":
		_moon(n, Vector2(292, 108))
		for i in 42:
			var sx := _hash(i * 3 + 1) * W
			var sy := _hash(i * 5 + 2) * 250.0
			var tw := 0.35 + 0.65 * absf(sin(n.t * 1.4 + float(i)))
			n.draw_circle(Vector2(sx, sy), 1.1, Color(1, 1, 1, 0.35 + 0.55 * tw))
		var u := fposmod(n.t, 13.0)
		if u < 0.45:
			var p := Vector2(30.0 + (u / 0.45) * 220.0, 36.0 + u * 50.0)
			var a := 1.0 - u / 0.45
			n.draw_line(p, p + Vector2(-22, 8), Color(1, 1, 1, 0.75 * a), 1.6, true)
	else:
		var sun := Vector2(300, 150 if id != "sea" else 168)
		var glow: Color = Color(1, 0.86, 0.55, 0.18)
		n.draw_circle(sun, 78, glow)
		n.draw_circle(sun, 46, Color(1, 0.9, 0.7, 0.22))
		n.draw_circle(sun, 22, Color("fff1cf"))
		if id == "cove":
			for i in 7:
				var ang := -0.4 + float(i) * 0.18
				var dir := Vector2(cos(ang), sin(ang))
				n.draw_colored_polygon(PackedVector2Array([
					sun,
					sun + dir.rotated(-0.04) * 280.0,
					sun + dir.rotated(0.04) * 280.0,
				]), Color(1, 0.82, 0.55, 0.045))
	_clouds(n, id)


func _moon(n: Node2D, c: Vector2) -> void:
	n.draw_circle(c, 36, Color(0.75, 0.82, 1.0, 0.12))
	n.draw_circle(c, 16, Color("f3ecda"))
	n.draw_circle(c + Vector2(6, -3), 13, Color("1a2744"))
	n.draw_circle(c + Vector2(-4, 2), 2.2, Color(0.8, 0.78, 0.7, 0.45))
	n.draw_circle(c + Vector2(2, 6), 1.4, Color(0.8, 0.78, 0.7, 0.35))


func _clouds(n: Node2D, id: String) -> void:
	if id == "pier":
		return
	var tint := Color(1, 0.96, 0.92, 0.55 if id != "sea" else 0.82)
	if id == "cove":
		tint = Color(1, 0.82, 0.7, 0.42)
	for i in 5:
		var speed := 7.0 + float(i) * 2.4
		var x := fposmod(40.0 + float(i) * 90.0 + n.t * speed, W + 180.0) - 70.0
		var y := 46.0 + float(i % 3) * 28.0 + sin(n.t * 0.3 + float(i)) * 4.0
		var s := 0.7 + float(i % 3) * 0.25
		_cloud(n, Vector2(x, y), s, tint)


func _cloud(n: Node2D, c: Vector2, s: float, tint: Color) -> void:
	n.draw_circle(c, 16.0 * s, tint)
	n.draw_circle(c + Vector2(14.0 * s, 4.0), 12.0 * s, tint)
	n.draw_circle(c + Vector2(-12.0 * s, 5.0), 11.0 * s, tint)
	n.draw_circle(c + Vector2(4.0 * s, -6.0 * s), 10.0 * s, tint)


func _hills(n: Node2D, pal: Dictionary, id: String) -> void:
	var y := HORIZON + 10.0
	var far: Color = pal["hill_far"]
	n.draw_colored_polygon(PackedVector2Array([
		Vector2(-10, y), Vector2(-10, y - 46), Vector2(80, y - 88), Vector2(180, y - 40),
		Vector2(260, y - 96), Vector2(340, y - 36), Vector2(W + 10, y - 70), Vector2(W + 10, y),
	]), far)
	var hill: Color = pal["hill"]
	n.draw_colored_polygon(PackedVector2Array([
		Vector2(-10, y + 6), Vector2(-10, y - 24), Vector2(50, y - 58), Vector2(120, y - 18),
		Vector2(190, y - 64), Vector2(270, y - 16), Vector2(330, y - 48), Vector2(W + 10, y - 12),
		Vector2(W + 10, y + 6),
	]), hill)
	if id == "river":
		n.draw_rect(Rect2(0, HORIZON - 28, W, 36), Color(pal["mist"], 0.28), true)


func _trees(n: Node2D, pal: Dictionary, id: String) -> void:
	var base := HORIZON + 6.0
	var leaf: Color = Color(pal["hill"]).lightened(0.12)
	if id == "sea":
		_island(n, Vector2(78, base), leaf)
		_palm(n, Vector2(308, base + 2), 78, leaf)
		_palm(n, Vector2(336, base + 6), 58, leaf.darkened(0.08))
		return
	if id == "pier":
		_boathouse(n, base)
		return
	if id == "river":
		for i in 6:
			var x := 168.0 + float(i) * 36.0
			var h := 48.0 + float(i % 3) * 18.0
			_pine(n, x, base, h, leaf.darkened(0.05 * float(i % 2)))
		return
	_willow(n, 210, base, 78, leaf)
	_willow(n, 286, base, 96, leaf.darkened(0.06))
	_willow(n, 346, base, 70, leaf)
	for i in 7:
		var x := 168.0 + float(i) * 12.0
		_reed(n, x, base + 2, 18.0 + sin(float(i)) * 5.0, leaf.lightened(0.15))


func _willow(n: Node2D, x: float, base: float, h: float, col: Color) -> void:
	n.draw_line(Vector2(x, base), Vector2(x + 6, base - h * 0.42), Color("1a140e"), 3.2, true)
	_ellipse(n, Vector2(x + 8, base - h * 0.58), h * 0.34, h * 0.22, col)
	_ellipse(n, Vector2(x - 10, base - h * 0.48), h * 0.22, h * 0.16, col.darkened(0.08))
	for i in 6:
		var vx := x - h * 0.22 + float(i) * h * 0.1
		var sway := sin(n.t * 1.3 + float(i)) * 3.0
		n.draw_line(Vector2(vx, base - h * 0.5), Vector2(vx + sway, base - h * 0.12), Color(col.darkened(0.12), 0.85), 1.4, true)


func _pine(n: Node2D, x: float, base: float, h: float, col: Color) -> void:
	n.draw_rect(Rect2(x - 2, base - h * 0.28, 4, h * 0.28), Color("241810"), true)
	n.draw_colored_polygon(PackedVector2Array([
		Vector2(x, base - h), Vector2(x - h * 0.26, base - h * 0.18), Vector2(x + h * 0.26, base - h * 0.18),
	]), col)
	n.draw_colored_polygon(PackedVector2Array([
		Vector2(x, base - h * 0.72), Vector2(x - h * 0.2, base), Vector2(x + h * 0.2, base),
	]), col.darkened(0.1))


func _palm(n: Node2D, x: Vector2, h: float, col: Color) -> void:
	var top := x + Vector2(8, -h)
	n.draw_line(x, x + Vector2(4, -h * 0.45), Color("5a3a24"), 3.0, true)
	n.draw_line(x + Vector2(4, -h * 0.45), top, Color("5a3a24"), 3.0, true)
	for i in 6:
		var ang := -2.4 + float(i) * 0.7
		var tip := top + Vector2(cos(ang), sin(ang)) * (h * 0.42)
		n.draw_line(top, tip, col, 2.2, true)


func _island(n: Node2D, base: Vector2, col: Color) -> void:
	_ellipse(n, base + Vector2(0, -8), 54, 16, col.darkened(0.05))
	_ellipse(n, base + Vector2(10, -22), 28, 12, col)


func _boathouse(n: Node2D, base: float) -> void:
	n.draw_rect(Rect2(196, base - 46, 78, 46), Color("16141c"), true)
	n.draw_colored_polygon(PackedVector2Array([
		Vector2(190, base - 46), Vector2(235, base - 70), Vector2(280, base - 46),
	]), Color("2a241c"))
	n.draw_rect(Rect2(228, base - 22, 14, 22), Color("0c0c10"), true)
	var glow := 0.45 + 0.25 * sin(n.t * 2.0)
	n.draw_rect(Rect2(206, base - 36, 10, 12), Color(1, 0.78, 0.4, glow), true)
	n.draw_rect(Rect2(248, base - 34, 10, 10), Color(1, 0.78, 0.4, glow * 0.8), true)


func _reed(n: Node2D, x: float, base: float, h: float, col: Color) -> void:
	var sway := sin(n.t * 1.6 + x * 0.08) * 3.0
	n.draw_line(Vector2(x, base), Vector2(x + sway, base - h), col, 1.5, true)
	_ellipse(n, Vector2(x + sway, base - h), 3.2, 1.6, col.lightened(0.1))


func _water(n: Node2D, pal: Dictionary, id: String) -> void:
	var shallow: Color = pal["water0"]
	var mid: Color = pal["water1"]
	var deep: Color = pal["deep"]
	var bands := 32
	var span := H - HORIZON
	for i in bands:
		var u := float(i) / float(bands - 1)
		var y := HORIZON + u * span
		var h := span / float(bands) + 3.0
		var wave := sin(n.t * 1.35 + float(i) * 0.62) * (2.2 + u * 1.4)
		var col: Color = shallow.lerp(mid, smoothstep(0.0, 0.45, u)).lerp(deep, smoothstep(0.25, 1.0, u))
		if i < 5:
			col = col.lerp(pal["sky2"], 0.22 * (1.0 - float(i) / 5.0))
		n.draw_rect(Rect2(-8, y + wave, W + 16, h), col, true)
	n.draw_rect(Rect2(0, HORIZON - 1, W, 2), Color(pal["mist"], 0.55), true)
	var glitter_x := 292.0 if id != "river" else 210.0
	if id == "pier":
		glitter_x = 292.0
	for i in 16:
		var y := HORIZON + 10.0 + float(i) * 26.0
		var a := 0.08 + 0.16 * absf(sin(n.t * 2.6 + float(i) * 0.9))
		var half := 22.0 * (1.0 - float(i) / 20.0)
		var col := Color(1, 0.95, 0.82, a)
		if id == "pier":
			col = Color(0.85, 0.9, 1.0, a)
		n.draw_line(Vector2(glitter_x - half, y), Vector2(glitter_x + half, y + 1.5), col, 1.6, true)
	for i in 18:
		var x := float(i) * 24.0
		var y := HORIZON + sin(n.t * 1.5 + float(i) * 0.8) * 2.5
		n.draw_circle(Vector2(x, y + 3), 7.0, Color(1, 1, 1, 0.07 if id == "pier" else 0.13))
	if id == "sea":
		for i in 9:
			var x := fposmod(float(i) * 50.0 + n.t * 22.0, W + 30.0) - 10.0
			var y := HORIZON + 30.0 + float(i % 4) * 36.0
			n.draw_line(Vector2(x, y), Vector2(x + 16, y - 2), Color(1, 1, 1, 0.45), 1.5, true)
			n.draw_line(Vector2(x + 10, y + 3), Vector2(x + 24, y + 1), Color(1, 1, 1, 0.28), 1.2, true)
	if id == "river":
		for i in 7:
			var x := fposmod(n.t * 36.0 + float(i) * 70.0, W + 40.0) - 20.0
			var y := HORIZON + 50.0 + float(i) * 48.0
			n.draw_line(Vector2(x, y), Vector2(x + 28, y + 4), Color(1, 1, 1, 0.08), 2.0, true)
	if id == "cove":
		for spot in [Vector2(168, HORIZON + 28), Vector2(214, HORIZON + 48), Vector2(190, HORIZON + 70)]:
			var bob := sin(n.t * 1.2 + spot.x) * 1.5
			_ellipse(n, spot + Vector2(0, bob), 16, 6, Color("1f6a48"))
			_ellipse(n, spot + Vector2(-4, bob), 7, 3, Color("2f8a58"))
			n.draw_line(spot + Vector2(10, bob), spot + Vector2(18, bob - 3), Color("1a4030"), 1.2, true)


func _underwater(n: Node2D, pal: Dictionary, id: String) -> void:
	var ids := ["roach", "crucian", "perch", "bream", "mackerel", "trout"]
	for i in n.ambient.size():
		var spec: Dictionary = n.ambient[i]
		var fish_id: String = ids[i % ids.size()]
		var dir := 1.0 if float(spec["v"]) > 0.0 else -1.0
		var wobble := sin(n.t * 2.2 + float(spec["x"]) * 0.02) * 3.0
		var center := Vector2(float(spec["x"]), float(spec["y"]) + wobble)
		_fish(n, center, float(spec["len"]), dir, fish_id, spec["color"], n.t, 0.9)
	for i in 7:
		var y := fposmod(H - n.t * (16.0 + float(i) * 4.0) + float(i) * 40.0, H - HORIZON) + HORIZON
		var x := fposmod(30.0 + float(i) * 57.0, W - 20.0)
		n.draw_arc(Vector2(x, y), 2.4 + float(i % 3), 0.0, TAU, 12, Color(1, 1, 1, 0.22), 1.0, true)
	if id == "cove":
		for i in 8:
			var x := fposmod(_hash(i + 9) * W + n.t * (5.0 + float(i)), W)
			var y := 180.0 + fposmod(float(i) * 36.0 + n.t * 10.0, 160.0)
			n.draw_circle(Vector2(x, y), 1.3, Color(1, 0.95, 0.8, 0.4))


func _foreground(n: Node2D, pal: Dictionary, id: String) -> void:
	var deck := Color("6b4b32")
	var post := Color("3e2a1c")
	if id == "sea":
		n.draw_colored_polygon(PackedVector2Array([
			Vector2(0, HORIZON + 18), Vector2(108, HORIZON + 12), Vector2(122, HORIZON + 36),
			Vector2(100, HORIZON + 58), Vector2(0, HORIZON + 64),
		]), Color("f4f1ea"))
		n.draw_colored_polygon(PackedVector2Array([
			Vector2(6, HORIZON + 28), Vector2(96, HORIZON + 24), Vector2(104, HORIZON + 48), Vector2(0, HORIZON + 54),
		]), deck)
		n.draw_circle(Vector2(78, HORIZON + 36), 7, RUST)
		n.draw_circle(Vector2(78, HORIZON + 36), 3.5, CREAM)
		return
	if id == "river":
		n.draw_colored_polygon(PackedVector2Array([
			Vector2(0, HORIZON - 4), Vector2(108, HORIZON + 6), Vector2(86, HORIZON + 64), Vector2(0, HORIZON + 86),
		]), Color("3e6a40"))
		n.draw_colored_polygon(PackedVector2Array([
			Vector2(0, HORIZON + 8), Vector2(92, HORIZON + 16), Vector2(72, HORIZON + 72), Vector2(0, HORIZON + 90),
		]), Color("2a4a30"))
		_ellipse(n, Vector2(62, HORIZON + 14), 22, 8, Color("5c564c"))
		for i in 6:
			_reed(n, 20.0 + float(i) * 16.0, HORIZON + 10, 30.0 + float(i % 3) * 8.0, Color("8fb56a"))
		return
	var top := HORIZON + 10.0
	_rrect(n, Rect2(-4, top, 112, 16), deck, 2)
	n.draw_rect(Rect2(0, top, 108, 3), Color("8a6244"), true)
	for i in 5:
		n.draw_line(Vector2(10 + i * 18, top + 1), Vector2(10 + i * 18, top + 15), Color(0, 0, 0, 0.22), 1.0, true)
	for i in 3:
		var x := 16.0 + float(i) * 32.0
		n.draw_rect(Rect2(x, top + 12, 8, 78), post, true)
		n.draw_rect(Rect2(x + 1, top + 92, 6, 18), Color(0, 0, 0, 0.22), true)
	n.draw_polyline(PackedVector2Array([
		Vector2(16, top + 6), Vector2(40, top + 16), Vector2(70, top + 7), Vector2(100, top + 14),
	]), Color("c8b49a"), 1.4, true)
	_rrect(n, Rect2(86, top - 14, 18, 14), Color("2d4a52"), 3)
	if id == "pier":
		for i in 2:
			var x := 24.0 + float(i) * 40.0
			var gy := top - 8.0
			n.draw_line(Vector2(x, gy), Vector2(x, gy - 26), Color("2a241c"), 2.0, true)
			n.draw_circle(Vector2(x, gy - 30), 5, Color("ffb15a"))
			n.draw_circle(Vector2(x, gy - 30), 12, Color(1, 0.7, 0.3, 0.18 + 0.06 * sin(n.t * 3.0 + float(i))))
	for i in 5:
		_reed(n, 200.0 + float(i) * 18.0, HORIZON + 4, 26.0 + float(i % 2) * 10.0, Color("6e9a62"))


func _angler(n: Node2D, _pal: Dictionary) -> void:
	var feet := Vector2(74, HORIZON + 22)
	_ellipse(n, feet + Vector2(6, 4), 20, 5, Color(0, 0, 0, 0.28))
	n.draw_line(feet + Vector2(-6, -26), feet + Vector2(-4, -2), Color("241910"), 5.0, true)
	n.draw_line(feet + Vector2(10, -26), feet + Vector2(8, -2), Color("241910"), 5.0, true)
	_rrect(n, Rect2(feet.x - 12, feet.y - 8, 12, 8), Color("1a120e"), 2)
	_rrect(n, Rect2(feet.x + 4, feet.y - 8, 12, 8), Color("1a120e"), 2)
	_rrect(n, Rect2(feet.x - 16, feet.y - 52, 36, 28), Color("1d4e52"), 6)
	n.draw_rect(Rect2(feet.x - 16, feet.y - 40, 36, 6), Color("e4a04a"), true)
	var hand := Vector2(104, HORIZON - 18)
	n.draw_line(feet + Vector2(12, -40), hand, Color("f0d2b4"), 5.0, true)
	n.draw_circle(hand, 4.5, Color("f0d2b4"))
	var head := feet + Vector2(2, -66)
	n.draw_circle(head, 12, Color("f0d2b4"))
	n.draw_circle(head + Vector2(-3.5, -1), 1.5, INK)
	n.draw_circle(head + Vector2(3.2, -1), 1.5, INK)
	n.draw_arc(head + Vector2(0, 3), 3.5, 0.2, PI - 0.2, 8, Color("a85a48"), 1.2, true)
	_ellipse(n, head + Vector2(0, -10), 16, 5, Color("142026"))
	n.draw_rect(Rect2(head.x - 8, head.y - 18, 16, 10), Color("142026"), true)
	n.draw_circle(Vector2(96, HORIZON + 2), 7, Color("1a2428"))
	n.draw_rect(Rect2(90, HORIZON + 6, 12, 10), Color("243038"), true)


func _tackle(n: Node2D, _pal: Dictionary, _id: String) -> void:
	var phase := int(n.phase)
	var hand := Vector2(104, HORIZON - 18)
	var tip: Vector2 = n._rod_tip()
	var bend := 10.0
	if phase == P_CHARGING:
		bend = 6.0 + float(n.power) * 16.0
	elif phase == P_FIGHT:
		bend = 22.0 + absf(float(n.fight_fish_y) - float(n.fight_zone_y)) * 36.0
	elif phase == P_BITE:
		bend = 20.0 + sin(n.t * 28.0) * 4.0
	var delta: Vector2 = tip - hand
	var perp := Vector2(-delta.y, delta.x).normalized()
	if perp.y > 0.0:
		perp = -perp
	var sag: Vector2 = hand.lerp(tip, 0.55) + perp * bend
	var rod := PackedVector2Array()
	for i in 12:
		rod.append(_quad(hand, sag, tip, float(i) / 11.0))
	n.draw_polyline(rod, Color("4a3424"), 4.2, true)
	n.draw_polyline(rod, Color("8a6244"), 2.0, true)
	for i in [2, 5, 8, 10]:
		var p: Vector2 = rod[i]
		n.draw_circle(p, 2.4, Color("1a120e"))
		n.draw_arc(p, 3.4, 0, TAU, 10, GOLD, 1.0, true)
	n.draw_circle(hand + Vector2(-2, 6), 7, Color("1c2428"))
	n.draw_circle(hand + Vector2(-2, 6), 3.2, Color("8a9094"))
	n.draw_line(hand + Vector2(-2, 6), hand + Vector2(6, 12), Color("c8c2b8"), 1.6, true)
	var show_line := phase == P_FLYING or phase == P_WAITING or phase == P_BITE or phase == P_FIGHT or phase == P_CHARGING
	if phase == P_CHARGING:
		show_line = false
	if show_line:
		var bp: Vector2 = n.bobber + Vector2(0, n.bobber_dip)
		var drop := tip.lerp(bp, 0.5) + Vector2(0, 30.0 + sin(n.t * 2.2) * 4.0)
		var line := PackedVector2Array()
		for i in 16:
			line.append(_quad(tip, drop, bp, float(i) / 15.0))
		n.draw_polyline(line, Color(0.05, 0.08, 0.1, 0.45), 2.2, true)
		n.draw_polyline(line, Color(0.95, 0.96, 0.9, 0.9), 1.1, true)
		_bobber(n, bp)
		_hooked(n, bp, phase)
		for rip in n.ripples:
			var alpha := clampf(float(rip["life"]), 0.0, 1.0)
			var rad := float(rip["r"])
			n.draw_arc(rip["p"], rad, 0.2, TAU - 0.2, 24, Color(1, 1, 1, alpha * 0.55), 1.4, true)
			n.draw_arc(rip["p"], rad * 0.65, 0.5, TAU - 0.5, 18, Color(1, 1, 1, alpha * 0.28), 1.0, true)


func _bobber(n: Node2D, bp: Vector2) -> void:
	var reflex := bp + Vector2(sin(n.t * 2.0) * 1.5, 16)
	n.draw_circle(reflex, 5, Color(1, 1, 1, 0.12))
	n.draw_rect(Rect2(bp.x - 1.2, bp.y - 16, 2.4, 10), CREAM, true)
	n.draw_circle(bp + Vector2(0, -16), 2.2, RUST)
	n.draw_circle(bp + Vector2(0, -2), 7.2, RUST)
	n.draw_circle(bp + Vector2(0, 5), 6.4, CREAM)
	n.draw_circle(bp + Vector2(-2.2, -4), 1.6, Color(1, 1, 1, 0.75))
	n.draw_rect(Rect2(bp.x - 0.8, bp.y + 8, 1.6, 6), Color("2a241c"), true)


func _hooked(n: Node2D, bp: Vector2, phase: int) -> void:
	if phase == P_WAITING or phase == P_BITE:
		var dart := 8.0 if phase == P_BITE else 3.0
		var fish_pos := bp + Vector2(sin(n.t * (3.0 + dart)) * (8.0 + dart), 34.0)
		var col := Color(0.05, 0.12, 0.14, 0.55)
		_fish(n, fish_pos, 20.0 + dart, -1.0, "roach", col, n.t, 0.7)
		if phase == P_BITE:
			for i in 6:
				var a: float = float(n.t) * 9.0 + float(i)
				var p := bp + Vector2(sin(a) * (10.0 + float(i) * 3.0), -absf(sin(a * 1.4)) * (16.0 + float(i)))
				n.draw_circle(p, 1.8, Color(1, 1, 1, 0.65))
			_text(n, "КЛЮЁТ", Vector2(W * 0.5, 628), 28, Color("ffb15a"), HORIZONTAL_ALIGNMENT_CENTER, 280)
	elif phase == P_FIGHT and not n.fish.is_empty():
		var col := Color.html(str(n.fish["color"]))
		var length := 28.0 + float(n.fish["rarity"]) * 8.0
		var fish_pos := bp + Vector2(sin(n.t * 3.4) * 12.0, 40.0 + sin(n.t * 2.1) * 6.0)
		_fish(n, fish_pos, length, -1.0, str(n.fish["id"]), col, n.t, 1.0)


func _fish(n: Node2D, center: Vector2, length: float, dir: float, id: String, col: Color, time: float, alpha: float) -> void:
	var body := Color(col.r, col.g, col.b, alpha)
	var dark := Color(col.darkened(0.22).r, col.darkened(0.22).g, col.darkened(0.22).b, alpha)
	var belly := Color(col.lightened(0.38).r, col.lightened(0.38).g, col.lightened(0.38).b, alpha)
	var wag := sin(time * 8.0 + center.x * 0.01) * 0.08
	if id == "eel":
		_eel(n, center, length, dir, body, dark, time, alpha)
		return
	if id == "flounder":
		_flounder(n, center, length, body, dark, alpha)
		return
	var kind := _kind(id)
	var shape := _shape(kind)
	var mapped := PackedVector2Array()
	for p in shape:
		mapped.append(_pt(center, length, dir, p, wag))
	n.draw_colored_polygon(mapped, body)
	var belly_pts := PackedVector2Array()
	for p in _belly(kind):
		belly_pts.append(_pt(center, length, dir, p, wag))
	if belly_pts.size() >= 3:
		n.draw_colored_polygon(belly_pts, belly)
	var tail := PackedVector2Array([
		_pt(center, length, dir, Vector2(-0.30, -0.02), wag),
		_pt(center, length, dir, Vector2(-0.56, -0.22), wag),
		_pt(center, length, dir, Vector2(-0.44, 0.0), wag * 0.2),
		_pt(center, length, dir, Vector2(-0.56, 0.20), wag),
	])
	if id == "tuna":
		tail = PackedVector2Array([
			_pt(center, length, dir, Vector2(-0.28, 0.0), wag),
			_pt(center, length, dir, Vector2(-0.62, -0.28), wag),
			_pt(center, length, dir, Vector2(-0.4, 0.0), wag),
			_pt(center, length, dir, Vector2(-0.62, 0.28), wag),
		])
	n.draw_colored_polygon(tail, dark)
	var dorsal := PackedVector2Array([
		_pt(center, length, dir, Vector2(0.05, -0.16), 0.0),
		_pt(center, length, dir, Vector2(-0.02, -0.36), 0.0),
		_pt(center, length, dir, Vector2(-0.16, -0.12), wag),
	])
	n.draw_colored_polygon(dorsal, dark)
	var pec := PackedVector2Array([
		_pt(center, length, dir, Vector2(0.08, 0.06), 0.0),
		_pt(center, length, dir, Vector2(-0.02, 0.2), 0.0),
		_pt(center, length, dir, Vector2(0.12, 0.16), 0.0),
	])
	n.draw_colored_polygon(pec, dark)
	if length >= 32.0:
		var outline := mapped.duplicate()
		outline.append(mapped[0])
		n.draw_polyline(outline, Color(0, 0, 0, 0.28 * alpha), 1.3, true)
	_decor(n, center, length, dir, id, col, wag, alpha)
	var eye := _pt(center, length, dir, Vector2(0.28, -0.04), 0.0)
	var er := maxf(1.7, length * 0.065)
	n.draw_circle(eye, er, Color(0.96, 0.95, 0.9, alpha))
	n.draw_circle(eye + Vector2(dir * er * 0.25, 0), er * 0.55, Color(0.08, 0.1, 0.12, alpha))
	n.draw_circle(eye + Vector2(-dir * er * 0.3, -er * 0.3), er * 0.28, Color(1, 1, 1, alpha))


func _eel(n: Node2D, center: Vector2, length: float, dir: float, body: Color, dark: Color, time: float, alpha: float) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var u := float(i) / 15.0
		var x := lerpf(0.48, -0.55, u)
		var y := sin(u * TAU + time * 3.2) * 0.14
		pts.append(center + Vector2(x * length * dir, y * length))
	n.draw_polyline(pts, body, maxf(4.0, length * 0.2), true)
	n.draw_circle(pts[0], maxf(3.0, length * 0.12), body)
	n.draw_circle(pts[0] + Vector2(dir * 2.0, -length * 0.04), maxf(1.4, length * 0.04), Color(0.95, 0.95, 0.9, alpha))
	n.draw_colored_polygon(PackedVector2Array([
		pts[pts.size() - 1],
		pts[pts.size() - 1] + Vector2(-dir * length * 0.12, -length * 0.08),
		pts[pts.size() - 1] + Vector2(-dir * length * 0.12, length * 0.08),
	]), dark)


func _flounder(n: Node2D, center: Vector2, length: float, body: Color, dark: Color, alpha: float) -> void:
	_ellipse(n, center, length * 0.55, length * 0.32, body)
	_ellipse(n, center + Vector2(0, length * 0.06), length * 0.36, length * 0.16, body.lightened(0.2))
	for i in 4:
		var s := Vector2(cos(float(i) * 1.7), sin(float(i))) * length * 0.18
		n.draw_circle(center + s, maxf(1.5, length * 0.035), dark)
	var eye_y := -length * 0.06
	n.draw_circle(center + Vector2(length * 0.12, eye_y), maxf(2.0, length * 0.05), Color(0.95, 0.95, 0.9, alpha))
	n.draw_circle(center + Vector2(length * 0.22, eye_y - 1), maxf(2.0, length * 0.05), Color(0.95, 0.95, 0.9, alpha))
	n.draw_circle(center + Vector2(length * 0.13, eye_y), 1.2, INK)
	n.draw_circle(center + Vector2(length * 0.23, eye_y - 1), 1.2, INK)
	n.draw_colored_polygon(PackedVector2Array([
		center + Vector2(-length * 0.48, 0),
		center + Vector2(-length * 0.68, -length * 0.1),
		center + Vector2(-length * 0.68, length * 0.1),
	]), dark)


func _decor(n: Node2D, center: Vector2, length: float, dir: float, id: String, col: Color, wag: float, alpha: float) -> void:
	if length < 30.0 and id != "koi":
		return
	if id == "perch":
		for i in 5:
			var x := 0.18 - float(i) * 0.1
			n.draw_line(_pt(center, length, dir, Vector2(x, -0.16), wag), _pt(center, length, dir, Vector2(x - 0.02, 0.14), wag), Color(0.1, 0.16, 0.1, 0.55 * alpha), 2.0, true)
	elif id == "mackerel":
		for i in 4:
			var x := 0.16 - float(i) * 0.12
			n.draw_line(_pt(center, length, dir, Vector2(x, -0.1), 0.0), _pt(center, length, dir, Vector2(x - 0.08, 0.1), 0.0), Color(0.08, 0.16, 0.2, 0.7 * alpha), 2.2, true)
	elif id == "trout" or id == "pike":
		for i in 6:
			var p := _pt(center, length, dir, Vector2(0.16 - float(i) * 0.08, -0.06 + float(i % 2) * 0.1), 0.0)
			n.draw_circle(p, maxf(1.2, length * 0.02), Color(0.15, 0.1, 0.08, 0.7 * alpha))
		if id == "trout":
			n.draw_line(_pt(center, length, dir, Vector2(0.2, 0.02), 0.0), _pt(center, length, dir, Vector2(-0.2, 0.04), wag), Color(0.85, 0.4, 0.38, 0.8 * alpha), 1.6, true)
	elif id == "koi":
		n.draw_circle(_pt(center, length, dir, Vector2(0.05, -0.06), 0.0), length * 0.1, Color("e2582a", alpha * 0.95))
		n.draw_circle(_pt(center, length, dir, Vector2(-0.12, 0.08), 0.0), length * 0.07, Color("c43420", alpha * 0.9))
		n.draw_colored_polygon(PackedVector2Array([
			_pt(center, length, dir, Vector2(-0.16, -0.12), wag),
			_pt(center, length, dir, Vector2(-0.28, -0.32), wag),
			_pt(center, length, dir, Vector2(-0.05, -0.16), 0.0),
		]), Color(col.lightened(0.2), alpha))
	elif id == "catfish":
		var mouth := _pt(center, length, dir, Vector2(0.4, 0.06), 0.0)
		n.draw_line(mouth, mouth + Vector2(dir * length * 0.18, length * 0.1), Color(0.1, 0.08, 0.06, alpha), 1.3, true)
		n.draw_line(mouth, mouth + Vector2(dir * length * 0.16, -length * 0.02), Color(0.1, 0.08, 0.06, alpha), 1.3, true)
	elif id == "tuna":
		for i in 4:
			var p := _pt(center, length, dir, Vector2(-0.05 - float(i) * 0.05, 0.1), 0.0)
			n.draw_line(p, p + Vector2(-dir * 3.0, 4.0), Color("e4a04a", alpha), 1.4, true)


func _kind(id: String) -> String:
	match id:
		"pike", "zander":
			return "pike"
		"crucian", "bream", "koi":
			return "deep"
		"tuna", "mackerel":
			return "torpedo"
		"catfish":
			return "cat"
		_:
			return "classic"


func _shape(kind: String) -> PackedVector2Array:
	match kind:
		"pike":
			return PackedVector2Array([
				Vector2(0.62, 0.02), Vector2(0.36, -0.1), Vector2(0.05, -0.16), Vector2(-0.22, -0.12),
				Vector2(-0.4, -0.02), Vector2(-0.22, 0.12), Vector2(0.08, 0.14), Vector2(0.34, 0.1),
			])
		"deep":
			return PackedVector2Array([
				Vector2(0.46, 0.0), Vector2(0.22, -0.32), Vector2(-0.04, -0.38), Vector2(-0.28, -0.16),
				Vector2(-0.36, 0.0), Vector2(-0.22, 0.22), Vector2(0.06, 0.36), Vector2(0.28, 0.26),
			])
		"torpedo":
			return PackedVector2Array([
				Vector2(0.58, 0.0), Vector2(0.3, -0.12), Vector2(0.0, -0.13), Vector2(-0.24, -0.08),
				Vector2(-0.34, 0.0), Vector2(-0.24, 0.08), Vector2(0.02, 0.12), Vector2(0.32, 0.1),
			])
		"cat":
			return PackedVector2Array([
				Vector2(0.5, 0.06), Vector2(0.32, -0.14), Vector2(0.02, -0.18), Vector2(-0.22, -0.12),
				Vector2(-0.4, 0.0), Vector2(-0.18, 0.16), Vector2(0.12, 0.2), Vector2(0.36, 0.16),
			])
		_:
			return PackedVector2Array([
				Vector2(0.52, 0.0), Vector2(0.24, -0.18), Vector2(-0.02, -0.2), Vector2(-0.26, -0.1),
				Vector2(-0.38, 0.0), Vector2(-0.24, 0.12), Vector2(0.04, 0.18), Vector2(0.28, 0.14),
			])


func _belly(kind: String) -> PackedVector2Array:
	if kind == "deep":
		return PackedVector2Array([
			Vector2(0.3, 0.05), Vector2(0.2, 0.24), Vector2(-0.05, 0.32), Vector2(-0.2, 0.12), Vector2(0.05, 0.04),
		])
	return PackedVector2Array([
		Vector2(0.32, 0.02), Vector2(0.18, 0.12), Vector2(-0.08, 0.14), Vector2(-0.22, 0.04), Vector2(0.08, 0.0),
	])


func _pt(c: Vector2, length: float, dir: float, local: Vector2, wag: float) -> Vector2:
	var y := local.y
	if local.x < -0.12:
		y += wag
	return c + Vector2(local.x * length * dir, y * length)


func _ui(n: Node2D, pal: Dictionary, id: String) -> void:
	var phase := int(n.phase)
	if phase == P_HOME:
		_home(n)
	elif phase == P_SHOP:
		_sheet(n)
		_shop(n)
	elif phase == P_DEX:
		_sheet(n)
		_dex(n)
	elif phase == P_MAP:
		_sheet(n)
		_map(n)
	elif phase == P_RESULT:
		_result(n)
	elif phase == P_FIGHT:
		_fight(n)
		_chrome(n, id)
	elif phase == P_READY or phase == P_CHARGING or phase == P_WAITING or phase == P_BITE or phase == P_FLYING:
		_chrome(n, id)
	_dock(n, phase)
	for b in n.buttons:
		_button(n, b)
	if n.toast_t > 0.0:
		_chip(n, str(n.toast_text), Vector2(W * 0.5, 96))


func _vignette(n: Node2D) -> void:
	for i in 5:
		var a := 0.16 * (1.0 - float(i) / 5.0)
		n.draw_rect(Rect2(0, float(i) * 7.0, W, 7), Color(0, 0, 0, a), true)


func _sheet(n: Node2D) -> void:
	n.draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.05, 0.07, 0.62), true)


func _dock(n: Node2D, phase: int) -> void:
	if phase == P_HOME:
		_rrect(n, Rect2(16, 672, 358, 156), Color(0.03, 0.07, 0.09, 0.48), 22)
	elif phase == P_READY or phase == P_CHARGING or phase == P_WAITING or phase == P_BITE or phase == P_FIGHT or phase == P_FLYING:
		_rrect(n, Rect2(16, 720, 358, 108), Color(0.03, 0.07, 0.09, 0.5), 22)
	elif phase == P_RESULT:
		_rrect(n, Rect2(16, 684, 358, 146), Color(0.03, 0.07, 0.09, 0.4), 22)


func _home(n: Node2D) -> void:
	var plate := Rect2(24, 58, 342, 214)
	_rrect(n, Rect2(plate.position + Vector2(0, 6), plate.size), Color(0, 0, 0, 0.28), 24)
	_panel(n, plate, Color(0.04, 0.09, 0.11, 0.58), Color(1, 0.82, 0.55, 0.45), 22)
	_text(n, "ЗОЛОТОЙ КЛЁВ", Vector2(W * 0.5, 104), 28, CREAM, HORIZONTAL_ALIGNMENT_CENTER, 300)
	_text(n, "Рыбалка", Vector2(W * 0.5, 132), 15, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 300)
	n.draw_line(Vector2(120, 148), Vector2(270, 148), Color(GOLD, 0.7), 1.2, true)
	n.draw_circle(Vector2(W * 0.5, 148), 4, RUST)
	var loc := Catalog.by_id(str(n.save["location"]))
	_text(n, str(loc["name"]), Vector2(W * 0.5, 178), 20, CREAM, HORIZONTAL_ALIGNMENT_CENTER, 300)
	_text(n, "%d монет" % int(n.save["coins"]), Vector2(W * 0.5, 206), 16, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 300)
	_text(n, "Атлас %d/16    рекорд %.2f кг" % [n._dex_count(), float(n.save["stats"]["best"])], Vector2(W * 0.5, 232), 13, MUTED, HORIZONTAL_ALIGNMENT_CENTER, 300)
	_text(n, n._daily_line(), Vector2(W * 0.5, 254), 14, CREAM, HORIZONTAL_ALIGNMENT_CENTER, 300)


func _chrome(n: Node2D, _id: String) -> void:
	var phase := int(n.phase)
	var loc := Catalog.by_id(str(n.save["location"]))
	_text(n, str(loc["name"]), Vector2(W * 0.5, 78), 16, CREAM, HORIZONTAL_ALIGNMENT_CENTER, 220)
	n.draw_circle(Vector2(W - 40, 38), 9, GOLD)
	n.draw_circle(Vector2(W - 40, 38), 5.5, Color("a86b22"))
	_text(n, "%d" % int(n.save["coins"]), Vector2(W - 56, 44), 16, GOLD, HORIZONTAL_ALIGNMENT_RIGHT, 110)
	var hint := ""
	if phase == P_READY:
		hint = "Зажми и отпусти на вершине"
	elif phase == P_CHARGING:
		hint = "Отпусти в золотой зоне"
	elif phase == P_FLYING:
		hint = "Леска в полёте"
	elif phase == P_WAITING:
		hint = "Мелкая дрожь — ещё не клёв"
	elif phase == P_BITE:
		hint = "Жми, пока кольцо не погасло"
	elif phase == P_FIGHT:
		hint = str(n.fish.get("name", "Рыба"))
	if hint != "":
		_text(n, hint, Vector2(W * 0.5, 708), 14, CREAM, HORIZONTAL_ALIGNMENT_CENTER, W - 36)
	if phase == P_CHARGING or phase == P_READY:
		var meter := Rect2(40, 652, 310, 16)
		_rrect(n, meter, Color(0, 0, 0, 0.4), 8)
		var shown := float(n.power) if phase == P_CHARGING else 0.0
		if shown > 0.02:
			_rrect(n, Rect2(meter.position.x + 2, meter.position.y + 2, (meter.size.x - 4.0) * shown, meter.size.y - 4.0), GOLD, 6)
		var sweet := meter.position.x + meter.size.x * 0.78
		n.draw_rect(Rect2(sweet, meter.position.y - 3, meter.size.x * 0.2, meter.size.y + 6), Color(GREEN, 0.35), true)
		_text(n, "сила", Vector2(meter.position.x, meter.position.y - 6), 11, MUTED, HORIZONTAL_ALIGNMENT_LEFT, 80)
	if phase == P_BITE:
		var left_ratio := clampf(float(n.bite_left) / 1.15, 0.0, 1.0)
		var bp: Vector2 = n.bobber + Vector2(0, n.bobber_dip)
		n.draw_arc(bp + Vector2(0, -28), 18, -PI * 0.5, -PI * 0.5 + TAU * left_ratio, 28, Color("ffb15a"), 3.2, true)
		var meter := Rect2(40, 656, 310, 12)
		_rrect(n, meter, Color(0, 0, 0, 0.4), 6)
		_rrect(n, Rect2(meter.position, Vector2((meter.size.x) * left_ratio, meter.size.y)), RUST, 6)


func _fight(n: Node2D) -> void:
	var bar := Rect2(338, 168, 40, 430)
	_rrect(n, Rect2(bar.position + Vector2(0, 4), bar.size), Color(0, 0, 0, 0.35), 16)
	_panel(n, bar, Color("0c1a20"), Color(GOLD, 0.55), 16)
	var inner := Rect2(bar.position.x + 8, bar.position.y + 16, bar.size.x - 16, bar.size.y - 32)
	_rrect(n, inner, Color("071014"), 8)
	var zh := float(n._zone_h())
	var zone_top := inner.position.y + (1.0 - (float(n.fight_zone_y) + zh * 0.5)) * inner.size.y
	var zone_h := zh * inner.size.y
	_rrect(n, Rect2(inner.position.x + 2, zone_top, inner.size.x - 4, zone_h), Color(GREEN, 0.35), 6)
	_rrect(n, Rect2(inner.position.x + 5, zone_top + 3, inner.size.x - 10, maxf(4.0, zone_h - 6.0)), GREEN, 5)
	var fish_y := inner.position.y + (1.0 - float(n.fight_fish_y)) * inner.size.y
	var marker := Vector2(inner.position.x + inner.size.x * 0.5, fish_y)
	var hot: bool = absf(float(n.fight_fish_y) - float(n.fight_zone_y)) <= zh * 0.5
	n.draw_circle(marker, 8, GOLD if hot else RUST)
	n.draw_circle(marker, 3.5, INK)
	for i in 8:
		var y := inner.position.y + float(i) * inner.size.y / 7.0
		n.draw_line(Vector2(inner.position.x - 4, y), Vector2(inner.position.x, y), Color(CREAM, 0.35), 1.0, true)
	_text(n, "НАТЯГ", Vector2(bar.position.x + bar.size.x * 0.5, bar.position.y + 12), 9, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 40)
	var prog := Rect2(28, 112, 290, 14)
	_rrect(n, prog, Color(0, 0, 0, 0.4), 7)
	_rrect(n, Rect2(prog.position.x + 2, prog.position.y + 2, (prog.size.x - 4.0) * float(n.fight_progress), prog.size.y - 4.0), GOLD, 5)
	_text(n, "Держи рыбу в зелёной зоне", Vector2(28, 146), 13, CREAM, HORIZONTAL_ALIGNMENT_LEFT, 280)


func _result(n: Node2D) -> void:
	n.draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.04, 0.06, 0.5), true)
	var card := Rect2(24, 168, 342, 490)
	var hub := Vector2(W * 0.5, 360)
	for i in 14:
		var a: float = float(n.t) * 0.35 + float(i) / 14.0 * TAU
		var dir := Vector2(cos(a), sin(a))
		n.draw_colored_polygon(PackedVector2Array([
			hub,
			hub + dir.rotated(-0.06) * 210.0,
			hub + dir.rotated(0.06) * 210.0,
		]), Color(1, 0.82, 0.45, 0.07))
	_rrect(n, Rect2(card.position + Vector2(0, 8), card.size), Color(0, 0, 0, 0.35), 28)
	_panel(n, card, Color("102228"), GOLD, 26)
	_text(n, str(n.result.get("title", "")), Vector2(W * 0.5, 230), 28, CREAM, HORIZONTAL_ALIGNMENT_CENTER, 300)
	if bool(n.result.get("ok", false)) and not n.fish.is_empty():
		var col := Color.html(str(n.fish["color"]))
		_fish(n, Vector2(W * 0.5, 340), 118, 1.0, str(n.fish["id"]), col, n.t, 1.0)
		_text(n, "+%d монет" % int(n.result.get("coins", 0)), Vector2(W * 0.5, 450), 24, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 300)
	_text(n, str(n.result.get("line", "")), Vector2(W * 0.5, 500), 15, MUTED, HORIZONTAL_ALIGNMENT_CENTER, 300)


func _shop(n: Node2D) -> void:
	_text(n, "Снасти", Vector2(130, 52), 24, CREAM, HORIZONTAL_ALIGNMENT_LEFT, 180)
	_text(n, "%d монет" % int(n.save["coins"]), Vector2(W - 24, 52), 16, GOLD, HORIZONTAL_ALIGNMENT_RIGHT, 150)
	var order: Array = Catalog.GEAR_ORDER
	for i in order.size():
		var gid := str(order[i])
		var spec: Dictionary = Catalog.GEAR[gid]
		var card: Rect2 = n._gear_card_rect(i)
		_card(n, card)
		_gear_icon(n, gid, card.position + Vector2(36, 56))
		_text(n, str(spec["name"]), Vector2(card.position.x + 68, card.position.y + 40), 20, CREAM, HORIZONTAL_ALIGNMENT_LEFT, 180)
		_text(n, str(spec["blurb"]), Vector2(card.position.x + 68, card.position.y + 66), 13, MUTED, HORIZONTAL_ALIGNMENT_LEFT, 180)
		var level := int(n.save["gear"][gid])
		var pips := ""
		for k in 4:
			pips += "● " if k < level else "○ "
		_text(n, pips, Vector2(card.position.x + 68, card.position.y + 108), 16, GOLD, HORIZONTAL_ALIGNMENT_LEFT, 160)


func _gear_icon(n: Node2D, gid: String, c: Vector2) -> void:
	n.draw_circle(c, 20, Color("0c2428"))
	match gid:
		"rod":
			n.draw_line(c + Vector2(-10, 10), c + Vector2(10, -12), Color("c4a074"), 2.4, true)
			n.draw_circle(c + Vector2(-2, 2), 4, Color("d0d4d6"))
		"line":
			n.draw_circle(c, 8, Color("d7d2c8"))
			n.draw_arc(c, 5, 0.4, 5.4, 16, Color("1a2428"), 1.4, true)
		"reel":
			n.draw_circle(c, 8, GOLD)
			n.draw_circle(c, 3, INK)
			n.draw_line(c, c + Vector2(12, 6), CREAM, 2.0, true)
		_:
			n.draw_polyline(PackedVector2Array([
				c + Vector2(-8, 2), c + Vector2(-2, -6), c + Vector2(2, 4), c + Vector2(8, -2),
			]), Color("d07a6a"), 2.2, true)


func _map(n: Node2D) -> void:
	_text(n, "Водоёмы", Vector2(130, 52), 24, CREAM, HORIZONTAL_ALIGNMENT_LEFT, 200)
	for i in Catalog.LOCATIONS.size():
		var loc: Dictionary = Catalog.LOCATIONS[i]
		var card: Rect2 = n._loc_card_rect(i)
		_card(n, card)
		var sw := Rect2(card.position.x + 14, card.position.y + 28, 44, 64)
		var pal := _pal(str(loc["id"]))
		_rrect(n, sw, pal["sky1"], 8)
		n.draw_rect(Rect2(sw.position.x, sw.position.y + 34, sw.size.x, 30), pal["water1"], true)
		n.draw_circle(sw.position + Vector2(30, 16), 6, Color("fff1cf"))
		var owned: bool = str(loc["id"]) in n.save["unlocked"]
		_text(n, str(loc["name"]), Vector2(card.position.x + 70, card.position.y + 42), 18, CREAM, HORIZONTAL_ALIGNMENT_LEFT, 180)
		var detail := "Открыто" if owned else "Открытие %d" % int(loc["cost"])
		if str(n.save["location"]) == str(loc["id"]):
			detail = "Сейчас ты здесь"
		_text(n, detail, Vector2(card.position.x + 70, card.position.y + 68), 13, MUTED, HORIZONTAL_ALIGNMENT_LEFT, 180)
		var names := ""
		for fish in Catalog.fish_in(str(loc["id"])):
			names += str(fish["name"]) + "  "
		_text(n, names, Vector2(card.position.x + 70, card.position.y + 96), 12, GOLD, HORIZONTAL_ALIGNMENT_LEFT, 170)


func _dex(n: Node2D) -> void:
	_text(n, "Атлас  %d/16" % n._dex_count(), Vector2(130, 52), 22, CREAM, HORIZONTAL_ALIGNMENT_LEFT, 220)
	for i in Catalog.FISH.size():
		var spec: Dictionary = Catalog.FISH[i]
		var col := i % 2
		var row := int(i / 2.0)
		var cell := Rect2(16 + col * 182, 84 + row * 90, 172, 82)
		var known: bool = n.save["dex"].has(str(spec["id"]))
		_card(n, cell)
		var tint := Color.html(str(spec["color"])) if known else Color(0.22, 0.28, 0.3)
		_fish(n, cell.position + Vector2(40, 42), 36, 1.0, str(spec["id"]), tint, n.t, 1.0 if known else 0.85)
		var label := str(spec["name"]) if known else "???"
		_text(n, label, Vector2(cell.position.x + 68, cell.position.y + 32), 13, CREAM if known else MUTED, HORIZONTAL_ALIGNMENT_LEFT, 96)
		if known:
			var entry: Dictionary = n.save["dex"][str(spec["id"])]
			_text(n, "%.2f кг" % float(entry.get("best", 0.0)), Vector2(cell.position.x + 68, cell.position.y + 54), 12, GOLD, HORIZONTAL_ALIGNMENT_LEFT, 96)
		else:
			_text(n, Catalog.rarity_name(int(spec["rarity"])), Vector2(cell.position.x + 68, cell.position.y + 54), 11, MUTED, HORIZONTAL_ALIGNMENT_LEFT, 96)


func _card(n: Node2D, r: Rect2) -> void:
	_rrect(n, Rect2(r.position + Vector2(0, 4), r.size), Color(0, 0, 0, 0.28), 16)
	_panel(n, r, Color("102228"), Color(GOLD, 0.28), 16)


func _button(n: Node2D, b: Dictionary) -> void:
	var r: Rect2 = b["rect"]
	var primary := bool(b.get("primary", false))
	var hot: bool = bool(n.pointer_down) and r.has_point(n.pointer_pos)
	var id := str(b["id"])
	if primary and (id == "hook" or id == "hold"):
		var pulse := 0.35 + 0.25 * sin(n.t * (8.0 if id == "hook" else 4.0))
		_rrect(n, r.grow(4.0 + pulse * 4.0), Color(GOLD, 0.18 + pulse * 0.2), 18)
	var fill := GOLD if primary else Color("14343c")
	if hot:
		fill = fill.lightened(0.12)
		r = Rect2(r.position + Vector2(0, 2), r.size)
	else:
		_rrect(n, Rect2(r.position + Vector2(0, 4), r.size), Color(0, 0, 0, 0.28), 16)
	_rrect(n, r, fill, 16)
	n.draw_rect(Rect2(r.position.x + 14, r.position.y + 4, r.size.x - 28, 5), Color(1, 1, 1, 0.18), true)
	var ink := INK if primary else CREAM
	_text(n, str(b["label"]), Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.66), 18, ink, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, false)


func _text(n: Node2D, s: String, pos: Vector2, size: int, color: Color, align: HorizontalAlignment, width: float, shadow: bool = true) -> void:
	if n.font == null:
		return
	var origin := pos
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		origin.x -= width * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		origin.x -= width
	if shadow:
		n.draw_string(n.font, origin + Vector2(0, 1.6), s, align, width, size, Color(0, 0, 0, 0.5))
	n.draw_string(n.font, origin, s, align, width, size, color)


func _chip(n: Node2D, s: String, center: Vector2) -> void:
	var width := 240.0
	var r := Rect2(center.x - width * 0.5, center.y - 18.0, width, 36.0)
	_panel(n, r, Color("102228"), GOLD, 14)
	_text(n, s, Vector2(center.x, r.position.y + 24), 14, CREAM, HORIZONTAL_ALIGNMENT_CENTER, width, false)


func _rrect(n: Node2D, r: Rect2, col: Color, rad: float) -> void:
	if r.size.x < 2.0 or r.size.y < 2.0:
		return
	rad = minf(rad, minf(r.size.x, r.size.y) * 0.5)
	if rad < 1.5:
		n.draw_rect(r, col, true)
		return
	n.draw_rect(Rect2(r.position.x + rad, r.position.y, r.size.x - rad * 2.0, r.size.y), col, true)
	n.draw_rect(Rect2(r.position.x, r.position.y + rad, r.size.x, r.size.y - rad * 2.0), col, true)
	n.draw_circle(r.position + Vector2(rad, rad), rad, col)
	n.draw_circle(r.position + Vector2(r.size.x - rad, rad), rad, col)
	n.draw_circle(r.position + Vector2(rad, r.size.y - rad), rad, col)
	n.draw_circle(r.position + Vector2(r.size.x - rad, r.size.y - rad), rad, col)


func _panel(n: Node2D, r: Rect2, fill: Color, border: Color, rad: float) -> void:
	_rrect(n, r, border, rad)
	var inset := Rect2(r.position + Vector2(2, 2), r.size - Vector2(4, 4))
	_rrect(n, inset, fill, maxf(0.0, rad - 2.0))


func _ellipse(n: Node2D, c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 14:
		var a := TAU * float(i) / 14.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	n.draw_colored_polygon(pts, col)


func _quad(a: Vector2, c: Vector2, b: Vector2, u: float) -> Vector2:
	return a.lerp(c, u).lerp(c.lerp(b, u), u)


func _hash(i: int) -> float:
	var x := sin(float(i) * 127.1) * 43758.5453
	return x - floor(x)

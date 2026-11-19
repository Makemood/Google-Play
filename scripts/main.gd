extends Node2D

const Catalog = preload("res://scripts/catalog.gd")

const W := 390.0
const H := 844.0
const SAVE_PATH := "user://golden_bite_save.json"

const INK := Color("07141a")
const CREAM := Color("f4ebda")
const GOLD := Color("e4a04a")
const MUTED := Color("8aa09a")
const RUST := Color("c46a45")
const GREEN := Color("7ea37a")

enum Phase { HOME, READY, CHARGING, FLYING, WAITING, BITE, FIGHT, RESULT, SHOP, DEX, MAP }

var phase: int = Phase.HOME
var save: Dictionary = {}
var t := 0.0
var power := 0.0
var cast_dist := 0.5
var bobber := Vector2(220, 410)
var bobber_dip := 0.0
var fly_from := Vector2.ZERO
var fly_to := Vector2.ZERO
var fly_t := 0.0
var wait_left := 0.0
var wait_total := 1.0
var nibble_i := 0
var bite_left := 0.0
var fish: Dictionary = {}
var fight_fish_y := 0.5
var fight_target := 0.5
var fight_zone_y := 0.5
var zone_v := 0.0
var fight_progress := 0.4
var was_in_zone := false
var pointer_down := false
var pointer_pos := Vector2.ZERO
var buttons: Array = []
var ripples: Array = []
var ambient: Array = []
var shake := 0.0
var toast_text := ""
var toast_t := 0.0
var result: Dictionary = {}
var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font
	seed(int(Time.get_unix_time_from_system()))
	_load()
	for i in 6:
		ambient.append({
			"x": randf() * W,
			"y": 470.0 + randf() * 280.0,
			"len": randf_range(16.0, 36.0),
			"v": randf_range(16.0, 42.0) * (1.0 if randf() > 0.5 else -1.0),
			"color": Color.html(["7ea37a", "d7a15a", "8fb8c9", "c46a45", "4f7c8a"][i % 5]),
		})


func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	t += delta
	shake = move_toward(shake, 0.0, delta * 36.0)
	toast_t = maxf(0.0, toast_t - delta)
	bobber_dip = move_toward(bobber_dip, 0.0, delta * 36.0)
	_sim(delta)
	_ambience(delta)
	_layout_buttons()
	queue_redraw()


func _sim(delta: float) -> void:
	if phase == Phase.CHARGING:
		var rod := int(save["gear"]["rod"])
		var speed := 3.1 - float(rod) * 0.28
		power = 0.5 + 0.5 * sin(t * speed)
	elif phase == Phase.FLYING:
		fly_t += delta / 0.7
		var u := clampf(fly_t, 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - u, 2.0)
		var arc := sin(u * PI) * 78.0
		bobber = fly_from.lerp(fly_to, eased) + Vector2(0, -arc)
		if fly_t >= 1.0:
			_land()
	elif phase == Phase.WAITING:
		wait_left -= delta
		var marks := [0.4, 0.68]
		var done_ratio := 1.0 - wait_left / maxf(wait_total, 0.01)
		if nibble_i < marks.size() and done_ratio >= float(marks[nibble_i]):
			nibble_i += 1
			bobber_dip = 10.0
			_blip(280.0, 0.05, 0.5)
		if wait_left <= 0.0:
			_start_bite()
	elif phase == Phase.BITE:
		bite_left -= delta
		bobber_dip = 18.0 + sin(t * 28.0) * 4.0
		if bite_left <= 0.0:
			_fail("Не подсёк", "Рыба ушла, пока поплавок нырял.")
	elif phase == Phase.FIGHT:
		var rarity := int(fish.get("rarity", 2))
		var wander := 0.55 + float(rarity) * 0.22
		if randf() < delta * (0.35 + float(rarity) * 0.2):
			fight_target = randf_range(0.08, 0.92)
		fight_fish_y = lerpf(fight_fish_y, fight_target, delta * wander)
		fight_fish_y += randf_range(-1.0, 1.0) * delta * (0.15 + float(rarity) * 0.05)
		fight_fish_y = clampf(fight_fish_y, 0.05, 0.95)
		var want := 0.9 if pointer_down else -0.9
		zone_v = lerpf(zone_v, want, delta * 5.0)
		var zh := _zone_h()
		fight_zone_y = clampf(fight_zone_y + zone_v * delta * 0.72, zh * 0.5, 1.0 - zh * 0.5)
		var inside := absf(fight_fish_y - fight_zone_y) <= zh * 0.5
		var reel := int(save["gear"]["reel"])
		if inside:
			fight_progress += delta * 0.22 * (1.0 + float(reel) * 0.12)
			if not was_in_zone:
				_blip(740.0, 0.04, 0.45)
		else:
			fight_progress -= delta * (0.12 + float(rarity) * 0.018)
		was_in_zone = inside
		fight_progress = clampf(fight_progress, 0.0, 1.0)
		if fight_progress >= 1.0:
			_catch()
		elif fight_progress <= 0.0:
			_fail("Сошла", "Вываживание сорвалось. Рамка ушла от рыбы.")


func _ambience(delta: float) -> void:
	for spec in ambient:
		spec["x"] = float(spec["x"]) + float(spec["v"]) * delta
		if float(spec["x"]) < -40.0:
			spec["x"] = W + 20.0
		elif float(spec["x"]) > W + 40.0:
			spec["x"] = -20.0
	var next: Array = []
	for rip in ripples:
		rip["r"] = float(rip["r"]) + delta * 36.0
		rip["life"] = float(rip["life"]) - delta
		if float(rip["life"]) > 0.0:
			next.append(rip)
	ripples = next


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		pointer_pos = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pointer_pos = event.position
		pointer_down = event.pressed
		if event.pressed:
			_on_press(event.position)
		else:
			_on_release()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		pointer_down = true
		_on_press(_primary_point())
	elif event.is_action_released("ui_accept"):
		pointer_down = false
		_on_release()


func _primary_point() -> Vector2:
	_layout_buttons()
	for b in buttons:
		if bool(b.get("primary", false)):
			var r: Rect2 = b["rect"]
			return r.position + r.size * 0.5
	return Vector2(W * 0.5, H - 90.0)


func _on_press(p: Vector2) -> void:
	_layout_buttons()
	var id := _hit(p)
	if id == "back":
		_go_back()
		return
	if phase == Phase.BITE:
		_hook()
		return
	if phase == Phase.READY and (id == "cast" or id == ""):
		phase = Phase.CHARGING
		_blip(480.0, 0.04, 0.4)
		return
	match id:
		"play":
			phase = Phase.READY
		"shop":
			phase = Phase.SHOP
		"dex":
			phase = Phase.DEX
		"map":
			phase = Phase.MAP
		"again":
			phase = Phase.READY
		"shore":
			phase = Phase.HOME
		"buy_rod", "buy_line", "buy_reel", "buy_bait":
			_buy(id.trim_prefix("buy_"))
		"loc_cove", "loc_river", "loc_pier", "loc_sea":
			_travel(id.trim_prefix("loc_"))


func _on_release() -> void:
	if phase == Phase.CHARGING:
		_cast()


func _go_back() -> void:
	if phase == Phase.SHOP or phase == Phase.DEX or phase == Phase.MAP or phase == Phase.RESULT:
		phase = Phase.HOME
	elif phase == Phase.READY or phase == Phase.CHARGING or phase == Phase.WAITING or phase == Phase.BITE:
		phase = Phase.HOME
	elif phase == Phase.FIGHT:
		_fail("Смотал", "Снасть смотана. Рыба ушла.")
	else:
		phase = Phase.HOME


func _cast() -> void:
	cast_dist = 0.26 + power * 0.66
	fish = {}
	fly_from = _rod_tip()
	fly_to = Vector2(48.0 + cast_dist * (W - 90.0), 408.0)
	fly_t = 0.0
	bobber = fly_from
	phase = Phase.FLYING
	_blip(190.0, 0.08, 0.55)


func _land() -> void:
	bobber = fly_to
	var bait := int(save["gear"]["bait"])
	wait_total = randf_range(1.45, 3.3) * (1.0 - float(bait) * 0.05)
	wait_left = wait_total
	nibble_i = 0
	phase = Phase.WAITING
	ripples.append({"p": bobber, "r": 6.0, "life": 0.85})
	_blip(120.0, 0.1, 0.6)


func _start_bite() -> void:
	phase = Phase.BITE
	var rod := int(save["gear"]["rod"])
	bite_left = 0.78 + float(rod) * 0.08
	shake = 6.0
	bobber_dip = 22.0
	_blip(760.0, 0.09, 0.7)
	_blip(980.0, 0.12, 0.45)


func _hook() -> void:
	fish = Catalog.roll_fish(str(save["location"]), int(save["gear"]["bait"]), cast_dist)
	phase = Phase.FIGHT
	fight_fish_y = randf_range(0.35, 0.7)
	fight_target = fight_fish_y
	fight_zone_y = 0.5
	zone_v = 0.0
	fight_progress = 0.36
	was_in_zone = false
	shake = 3.0
	_blip(420.0, 0.07, 0.6)


func _zone_h() -> float:
	var line := int(save["gear"]["line"])
	var rarity := int(fish.get("rarity", 2))
	return clampf(0.3 + float(line) * 0.03 - float(rarity - 1) * 0.034, 0.12, 0.48)


func _catch() -> void:
	var gained := Catalog.coins_for(fish)
	var bonus := 0
	_touch_daily()
	save["daily"]["count"] = int(save["daily"]["count"]) + 1
	if int(save["daily"]["count"]) >= 3 and not _as_bool(save["daily"]["claimed"]):
		save["daily"]["claimed"] = true
		bonus = 120
	save["coins"] = int(save["coins"]) + gained + bonus
	var id := str(fish["id"])
	var dex: Dictionary = save["dex"]
	var prev: Dictionary = dex.get(id, {})
	var is_new := prev.is_empty()
	var old_best := float(prev.get("best", 0.0))
	var is_record := (not is_new) and float(fish["weight"]) + 0.001 >= old_best
	var count := int(prev.get("count", 0)) + 1
	var best := maxf(old_best, float(fish["weight"]))
	dex[id] = {"count": count, "best": best}
	save["dex"] = dex
	var stats: Dictionary = save["stats"]
	stats["catches"] = int(stats.get("catches", 0)) + 1
	stats["total"] = float(stats.get("total", 0.0)) + float(fish["weight"])
	stats["best"] = maxf(float(stats.get("best", 0.0)), float(fish["weight"]))
	stats["streak"] = int(stats.get("streak", 0)) + 1
	stats["best_streak"] = maxi(int(stats.get("best_streak", 0)), int(stats["streak"]))
	save["stats"] = stats
	var line := "%.2f кг  ·  %s" % [float(fish["weight"]), Catalog.rarity_name(int(fish["rarity"]))]
	if is_new:
		line += "  ·  новая"
	elif is_record:
		line += "  ·  рекорд"
	if bonus > 0:
		line += "  ·  день +%d" % bonus
	result = {
		"ok": true,
		"title": str(fish["name"]),
		"line": line,
		"coins": gained + bonus,
		"fish": fish,
	}
	phase = Phase.RESULT
	shake = 8.0
	_save()
	_chime()


func _fail(title: String, line: String) -> void:
	var stats: Dictionary = save["stats"]
	stats["streak"] = 0
	save["stats"] = stats
	result = {"ok": false, "title": title, "line": line, "coins": 0, "fish": {}}
	phase = Phase.RESULT
	_save()
	_blip(96.0, 0.22, 0.55)


func _buy(gear_id: String) -> void:
	var spec: Dictionary = Catalog.GEAR[gear_id]
	var costs: Array = spec["costs"]
	var level := int(save["gear"][gear_id])
	if level >= costs.size():
		_toast("Уже максимум")
		return
	var price := int(costs[level])
	if int(save["coins"]) < price:
		_toast("Мало монет")
		return
	save["coins"] = int(save["coins"]) - price
	save["gear"][gear_id] = level + 1
	_save()
	_blip(560.0, 0.07, 0.5)
	_toast("%s улучшено" % str(spec["name"]))


func _travel(loc_id: String) -> void:
	var loc := Catalog.by_id(loc_id)
	if loc.is_empty():
		return
	var unlocked: Array = save["unlocked"]
	if loc_id in unlocked:
		save["location"] = loc_id
		_save()
		phase = Phase.READY
		return
	var cost := int(loc["cost"])
	if int(save["coins"]) < cost:
		_toast("Нужно %d монет" % cost)
		return
	save["coins"] = int(save["coins"]) - cost
	unlocked.append(loc_id)
	save["unlocked"] = unlocked
	save["location"] = loc_id
	_save()
	phase = Phase.READY
	_toast(str(loc["name"]))
	_blip(520.0, 0.08, 0.5)


func _layout_buttons() -> void:
	buttons.clear()
	if phase != Phase.HOME:
		buttons.append({"id": "back", "rect": Rect2(16, 16, 96, 44), "label": "Назад", "primary": false})
	match phase:
		Phase.HOME:
			buttons.append({"id": "play", "rect": Rect2(32, 688, 326, 64), "label": "На воду", "primary": true})
			buttons.append({"id": "shop", "rect": Rect2(32, 764, 102, 52), "label": "Снасти", "primary": false})
			buttons.append({"id": "dex", "rect": Rect2(144, 764, 102, 52), "label": "Атлас", "primary": false})
			buttons.append({"id": "map", "rect": Rect2(256, 764, 102, 52), "label": "Водоёмы", "primary": false})
		Phase.READY, Phase.CHARGING:
			buttons.append({"id": "cast", "rect": Rect2(32, 736, 326, 76), "label": "Заброс", "primary": true})
		Phase.WAITING:
			buttons.append({"id": "wait", "rect": Rect2(32, 736, 326, 76), "label": "Жди клёв", "primary": false})
		Phase.BITE:
			buttons.append({"id": "hook", "rect": Rect2(32, 736, 326, 76), "label": "Подсекай", "primary": true})
		Phase.FIGHT:
			buttons.append({"id": "hold", "rect": Rect2(32, 736, 326, 76), "label": "Держи", "primary": true})
		Phase.RESULT:
			buttons.append({"id": "again", "rect": Rect2(32, 700, 326, 60), "label": "Ещё заброс", "primary": true})
			buttons.append({"id": "shore", "rect": Rect2(32, 770, 326, 48), "label": "На берег", "primary": false})
		Phase.SHOP:
			var order: Array = Catalog.GEAR_ORDER
			for i in order.size():
				var gid := str(order[i])
				var card := _gear_card_rect(i)
				buttons.append({
					"id": "buy_%s" % gid,
					"rect": Rect2(card.position.x + card.size.x - 138.0, card.position.y + 82.0, 118.0, 46.0),
					"label": _gear_price_label(gid),
					"primary": true,
				})
		Phase.MAP:
			for i in Catalog.LOCATIONS.size():
				var loc: Dictionary = Catalog.LOCATIONS[i]
				var card := _loc_card_rect(i)
				buttons.append({
					"id": "loc_%s" % str(loc["id"]),
					"rect": Rect2(card.position.x + card.size.x - 138.0, card.position.y + 82.0, 118.0, 46.0),
					"label": _loc_button_label(str(loc["id"])),
					"primary": true,
				})


func _gear_card_rect(i: int) -> Rect2:
	return Rect2(20, 118 + i * 156, 350, 144)


func _loc_card_rect(i: int) -> Rect2:
	return Rect2(20, 118 + i * 156, 350, 144)


func _gear_price_label(gid: String) -> String:
	var costs: Array = Catalog.GEAR[gid]["costs"]
	var level := int(save["gear"][gid])
	if level >= costs.size():
		return "Макс"
	return "%d" % int(costs[level])


func _loc_button_label(loc_id: String) -> String:
	if loc_id in save["unlocked"]:
		if str(save["location"]) == loc_id:
			return "Здесь"
		return "Ехать"
	return "%d" % int(Catalog.by_id(loc_id)["cost"])


func _hit(p: Vector2) -> String:
	for i in range(buttons.size() - 1, -1, -1):
		var b: Dictionary = buttons[i]
		var r: Rect2 = b["rect"]
		if r.has_point(p):
			return str(b["id"])
	return ""


func _draw() -> void:
	var ox := randf_range(-shake, shake)
	draw_set_transform(Vector2(ox, 0), 0.0, Vector2.ONE)
	_draw_world()
	_draw_overlay()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_world() -> void:
	var loc := Catalog.by_id(str(save["location"]))
	if loc.is_empty():
		loc = Catalog.LOCATIONS[0]
	var sky0 := Color.html(str(loc["sky0"]))
	var sky1 := Color.html(str(loc["sky1"]))
	var water := Color.html(str(loc["water"]))
	var hill := Color.html(str(loc["hill"]))
	for i in 16:
		var u := float(i) / 15.0
		draw_rect(Rect2(0, u * 400.0, W, 30), sky0.lerp(sky1, u), true)
	if str(loc["id"]) == "pier":
		draw_circle(Vector2(292, 108), 16, Color(0.93, 0.94, 0.88))
		draw_circle(Vector2(292, 108), 34, Color(0.75, 0.8, 0.9, 0.12))
	else:
		draw_circle(Vector2(300, 148), 46, Color(1, 0.78, 0.42, 0.16))
		draw_circle(Vector2(300, 148), 26, Color(1, 0.88, 0.62))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 408), Vector2(0, 312), Vector2(70, 338), Vector2(150, 286),
		Vector2(240, 346), Vector2(320, 300), Vector2(W, 334), Vector2(W, 408),
	]), hill)
	for i in 8:
		var x := 168.0 + float(i) * 24.0
		var h := 22.0 + sin(float(i) * 1.7) * 10.0
		draw_line(Vector2(x, 400), Vector2(x + 6.0, 400.0 - h), Color(0.1, 0.28, 0.18), 3.0)
	for i in 24:
		var y := 398.0 + float(i) * 20.0
		var wave := sin(t * 1.25 + float(i) * 0.62) * 4.0
		var c := water.lerp(Color(0.62, 0.84, 0.78), 0.05 + 0.04 * sin(t * 0.7 + float(i)))
		c = c.lerp(Color("041016"), float(i) / 32.0)
		draw_rect(Rect2(0, y + wave, W, 26), c, true)
	for spec in ambient:
		var dir := 1.0 if float(spec["v"]) > 0.0 else -1.0
		var wobble := sin(t * 3.0 + float(spec["x"]) * 0.02) * 3.0
		_draw_fish(Vector2(float(spec["x"]), float(spec["y"]) + wobble), float(spec["len"]), spec["color"], dir)
	_draw_pier()
	_draw_angler()
	if phase == Phase.FLYING or phase == Phase.WAITING or phase == Phase.BITE or phase == Phase.FIGHT:
		var tip := _rod_tip()
		var bp := bobber + Vector2(0, bobber_dip)
		var sag := tip.lerp(bp, 0.5) + Vector2(0, 26.0 + sin(t * 2.2) * 5.0)
		var pts := PackedVector2Array()
		for i in 14:
			pts.append(_quad(tip, sag, bp, float(i) / 13.0))
		draw_polyline(pts, Color(0.93, 0.94, 0.9, 0.9), 1.6, true)
		_draw_bobber(bp)
		if phase == Phase.FIGHT or phase == Phase.BITE or phase == Phase.WAITING:
			var col := GOLD
			var length := 28.0
			if not fish.is_empty():
				col = Color.html(str(fish["color"]))
				length = 22.0 + float(fish["rarity"]) * 6.0
			var fish_pos := bp + Vector2(sin(t * 2.0) * 10.0, 36.0 + sin(t * 1.4) * 8.0)
			_draw_fish(fish_pos, length, col, -1.0)
	for rip in ripples:
		var alpha := clampf(float(rip["life"]), 0.0, 1.0)
		draw_arc(rip["p"], float(rip["r"]), 0.0, TAU, 28, Color(1, 1, 1, alpha * 0.55), 1.5, true)


func _draw_pier() -> void:
	draw_rect(Rect2(0, 390, 168, 16), Color("6b4b32"), true)
	draw_rect(Rect2(0, 390, 168, 3), Color("8a6244"), true)
	for i in 6:
		draw_rect(Rect2(10 + i * 26, 406, 14, 78), Color("4e3424"), true)


func _draw_angler() -> void:
	draw_rect(Rect2(58, 374, 14, 18), Color("241910"), true)
	draw_rect(Rect2(78, 374, 14, 18), Color("241910"), true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(52, 376), Vector2(98, 376), Vector2(104, 328), Vector2(46, 328),
	]), Color("1d4a4e"))
	draw_circle(Vector2(74, 316), 11, Color("f0d2b4"))
	draw_rect(Rect2(60, 300, 30, 8), Color("142026"), true)
	draw_rect(Rect2(66, 286, 16, 16), Color("142026"), true)
	var tip := _rod_tip()
	draw_line(Vector2(98, 342), tip, Color("5a3a24"), 3.2, true)


func _rod_tip() -> Vector2:
	if phase == Phase.CHARGING:
		return Vector2(168, 318 - power * 46.0)
	return Vector2(176, 292)


func _draw_bobber(bp: Vector2) -> void:
	draw_circle(bp, 7.5, GOLD)
	draw_rect(Rect2(bp.x - 1.5, bp.y + 2.0, 3, 11), CREAM, true)
	draw_circle(bp + Vector2(0, 14), 3.2, RUST)


func _draw_fish(center: Vector2, length: float, col: Color, dir: float) -> void:
	var nose := center + Vector2(dir * length * 0.55, 0)
	var tail := center + Vector2(-dir * length * 0.35, 0)
	draw_colored_polygon(PackedVector2Array([
		nose,
		center + Vector2(-dir * length * 0.05, -length * 0.24),
		tail,
		center + Vector2(-dir * length * 0.05, length * 0.24),
	]), col)
	draw_colored_polygon(PackedVector2Array([
		tail,
		tail + Vector2(-dir * length * 0.32, -length * 0.2),
		tail + Vector2(-dir * length * 0.32, length * 0.2),
	]), col.darkened(0.12))
	draw_circle(center + Vector2(dir * length * 0.28, -length * 0.05), maxf(1.6, length * 0.06), INK)


func _draw_overlay() -> void:
	if phase == Phase.HOME:
		_draw_home()
	elif phase == Phase.SHOP:
		_draw_shop()
	elif phase == Phase.DEX:
		_draw_dex()
	elif phase == Phase.MAP:
		_draw_map()
	elif phase == Phase.RESULT:
		_draw_result()
	elif phase == Phase.FIGHT:
		_draw_fight()
		_draw_fishing_chrome()
	elif phase == Phase.READY or phase == Phase.CHARGING or phase == Phase.WAITING or phase == Phase.BITE or phase == Phase.FLYING:
		_draw_fishing_chrome()
	for b in buttons:
		_draw_button(b)
	if toast_t > 0.0:
		_chip(toast_text, Vector2(W * 0.5, 92))


func _draw_home() -> void:
	draw_rect(Rect2(24, 88, 342, 250), Color(0.03, 0.07, 0.09, 0.62), true)
	_text("ЗОЛОТОЙ КЛЁВ", Vector2(W * 0.5, 148), 32, CREAM, HORIZONTAL_ALIGNMENT_CENTER, W - 40)
	_text("Рыбалка", Vector2(W * 0.5, 184), 18, GOLD, HORIZONTAL_ALIGNMENT_CENTER, W - 40)
	var loc := Catalog.by_id(str(save["location"]))
	_text(str(loc["name"]), Vector2(W * 0.5, 230), 20, CREAM, HORIZONTAL_ALIGNMENT_CENTER, W - 48)
	_text("%d монет" % int(save["coins"]), Vector2(W * 0.5, 262), 16, GOLD, HORIZONTAL_ALIGNMENT_CENTER, W - 48)
	_text("Атлас %d/16   ·   рекорд %.2f кг" % [_dex_count(), float(save["stats"]["best"])], Vector2(W * 0.5, 292), 14, MUTED, HORIZONTAL_ALIGNMENT_CENTER, W - 48)
	_text(_daily_line(), Vector2(W * 0.5, 316), 14, CREAM, HORIZONTAL_ALIGNMENT_CENTER, W - 48)


func _draw_fishing_chrome() -> void:
	var loc := Catalog.by_id(str(save["location"]))
	_text(str(loc["name"]), Vector2(124, 46), 18, CREAM, HORIZONTAL_ALIGNMENT_LEFT, 160)
	_text("%d" % int(save["coins"]), Vector2(W - 24, 46), 18, GOLD, HORIZONTAL_ALIGNMENT_RIGHT, 120)
	var hint := ""
	if phase == Phase.READY:
		hint = "Зажми и отпусти — сила заброса"
	elif phase == Phase.CHARGING:
		hint = "Отпусти в верхней точке"
	elif phase == Phase.FLYING:
		hint = "Леска в полёте"
	elif phase == Phase.WAITING:
		hint = "Мелкая дрожь — ещё не клёв"
	elif phase == Phase.BITE:
		hint = "Клюёт! Жми сразу"
	elif phase == Phase.FIGHT:
		hint = str(fish.get("name", "Рыба"))
	if hint != "":
		_text(hint, Vector2(W * 0.5, 700), 15, CREAM, HORIZONTAL_ALIGNMENT_CENTER, W - 32)
	if phase == Phase.CHARGING or phase == Phase.READY:
		var meter := Rect2(48, 656, 294, 14)
		draw_rect(meter, Color(0, 0, 0, 0.35), true)
		var shown := power if phase == Phase.CHARGING else 0.0
		draw_rect(Rect2(meter.position, Vector2(meter.size.x * shown, meter.size.y)), GOLD, true)
	if phase == Phase.BITE:
		var left_ratio := clampf(bite_left / 1.15, 0.0, 1.0)
		draw_rect(Rect2(48, 656, 294, 14), Color(0, 0, 0, 0.35), true)
		draw_rect(Rect2(48, 656, 294.0 * left_ratio, 14), RUST, true)


func _draw_fight() -> void:
	var bar := Rect2(334, 150, 28, 470)
	draw_rect(bar, Color(0, 0, 0, 0.4), true)
	var zh := _zone_h()
	var zone_top := bar.position.y + (1.0 - (fight_zone_y + zh * 0.5)) * bar.size.y
	var zone_h_px := zh * bar.size.y
	draw_rect(Rect2(bar.position.x + 3.0, zone_top, bar.size.x - 6.0, zone_h_px), GREEN, true)
	var fish_y := bar.position.y + (1.0 - fight_fish_y) * bar.size.y
	draw_circle(Vector2(bar.position.x + bar.size.x * 0.5, fish_y), 7, GOLD)
	var prog := Rect2(32, 118, 280, 12)
	draw_rect(prog, Color(0, 0, 0, 0.35), true)
	draw_rect(Rect2(prog.position, Vector2(prog.size.x * fight_progress, prog.size.y)), GOLD, true)
	_text("Держи, чтобы рамка поднималась", Vector2(32, 148), 13, MUTED, HORIZONTAL_ALIGNMENT_LEFT, 280)


func _draw_result() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.05, 0.06, 0.45), true)
	var card := Rect2(28, 180, 334, 480)
	draw_rect(card, Color("102228"), true)
	draw_rect(card, GOLD, false, 2.0)
	var title := str(result.get("title", ""))
	_text(title, Vector2(W * 0.5, 240), 28, CREAM, HORIZONTAL_ALIGNMENT_CENTER, 300)
	if bool(result.get("ok", false)) and not fish.is_empty():
		_draw_fish(Vector2(W * 0.5, 340), 54, Color.html(str(fish["color"])), 1.0)
		_text("+%d монет" % int(result.get("coins", 0)), Vector2(W * 0.5, 430), 22, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 300)
	_text(str(result.get("line", "")), Vector2(W * 0.5, 480), 15, MUTED, HORIZONTAL_ALIGNMENT_CENTER, 300)


func _draw_shop() -> void:
	_dim_panel()
	_text("Снасти", Vector2(130, 48), 22, CREAM, HORIZONTAL_ALIGNMENT_LEFT, 200)
	_text("%d монет" % int(save["coins"]), Vector2(W - 20, 48), 16, GOLD, HORIZONTAL_ALIGNMENT_RIGHT, 140)
	var order: Array = Catalog.GEAR_ORDER
	for i in order.size():
		var gid := str(order[i])
		var spec: Dictionary = Catalog.GEAR[gid]
		var card := _gear_card_rect(i)
		draw_rect(card, Color("102228"), true)
		_text(str(spec["name"]), Vector2(card.position.x + 16, card.position.y + 36), 20, CREAM, HORIZONTAL_ALIGNMENT_LEFT, 200)
		_text(str(spec["blurb"]), Vector2(card.position.x + 16, card.position.y + 64), 14, MUTED, HORIZONTAL_ALIGNMENT_LEFT, 210)
		var level := int(save["gear"][gid])
		var pips := ""
		for n in 4:
			pips += "● " if n < level else "○ "
		_text(pips, Vector2(card.position.x + 16, card.position.y + 112), 16, GOLD, HORIZONTAL_ALIGNMENT_LEFT, 180)


func _draw_map() -> void:
	_dim_panel()
	_text("Водоёмы", Vector2(130, 48), 22, CREAM, HORIZONTAL_ALIGNMENT_LEFT, 220)
	for i in Catalog.LOCATIONS.size():
		var loc: Dictionary = Catalog.LOCATIONS[i]
		var card := _loc_card_rect(i)
		draw_rect(card, Color("102228"), true)
		var owned: bool = str(loc["id"]) in save["unlocked"]
		_text(str(loc["name"]), Vector2(card.position.x + 16, card.position.y + 40), 20, CREAM, HORIZONTAL_ALIGNMENT_LEFT, 200)
		var detail := "Открыто" if owned else "Открытие %d" % int(loc["cost"])
		if str(save["location"]) == str(loc["id"]):
			detail = "Сейчас ты здесь"
		_text(detail, Vector2(card.position.x + 16, card.position.y + 72), 14, MUTED, HORIZONTAL_ALIGNMENT_LEFT, 200)
		var names := ""
		for fish in Catalog.fish_in(str(loc["id"])):
			names += str(fish["name"]) + "  "
		_text(names, Vector2(card.position.x + 16, card.position.y + 104), 13, GOLD, HORIZONTAL_ALIGNMENT_LEFT, 200)


func _draw_dex() -> void:
	_dim_panel()
	_text("Атлас %d/16" % _dex_count(), Vector2(130, 48), 22, CREAM, HORIZONTAL_ALIGNMENT_LEFT, 220)
	for i in Catalog.FISH.size():
		var spec: Dictionary = Catalog.FISH[i]
		var col := i % 2
		var row := int(i / 2)
		var cell := Rect2(20 + col * 178, 88 + row * 88, 168, 80)
		var known: bool = save["dex"].has(str(spec["id"]))
		draw_rect(cell, Color("102228"), true)
		var tint := Color.html(str(spec["color"])) if known else Color(0.25, 0.3, 0.32)
		_draw_fish(cell.position + Vector2(36, 40), 22, tint, 1.0)
		var label := str(spec["name"]) if known else "???"
		_text(label, Vector2(cell.position.x + 68, cell.position.y + 32), 14, CREAM if known else MUTED, HORIZONTAL_ALIGNMENT_LEFT, 92)
		if known:
			var entry: Dictionary = save["dex"][str(spec["id"])]
			_text("%.2f кг" % float(entry.get("best", 0.0)), Vector2(cell.position.x + 68, cell.position.y + 54), 13, GOLD, HORIZONTAL_ALIGNMENT_LEFT, 92)
		else:
			_text(Catalog.rarity_name(int(spec["rarity"])), Vector2(cell.position.x + 68, cell.position.y + 54), 12, MUTED, HORIZONTAL_ALIGNMENT_LEFT, 92)


func _dim_panel() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.03, 0.06, 0.07, 0.78), true)


func _draw_button(b: Dictionary) -> void:
	var r: Rect2 = b["rect"]
	var primary := bool(b.get("primary", false))
	var hot := pointer_down and r.has_point(pointer_pos)
	var fill := GOLD if primary else Color("14343c")
	if hot:
		fill = fill.lightened(0.12)
	draw_rect(r, fill, true)
	draw_rect(r, Color("f4ebda").lerp(GOLD, 0.35), false, 1.5)
	var ink := INK if primary else CREAM
	_text(str(b["label"]), Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.66), 18, ink, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func _text(s: String, pos: Vector2, size: int, color: Color, align: HorizontalAlignment, width: float) -> void:
	var origin := pos
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		origin.x -= width * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		origin.x -= width
	draw_string(font, origin, s, align, width, size, color)


func _chip(s: String, center: Vector2) -> void:
	var width := 220.0
	var r := Rect2(center.x - width * 0.5, center.y - 18.0, width, 36.0)
	draw_rect(r, Color("102228"), true)
	_text(s, Vector2(center.x, r.position.y + 24), 14, CREAM, HORIZONTAL_ALIGNMENT_CENTER, width)


func _quad(a: Vector2, c: Vector2, b: Vector2, u: float) -> Vector2:
	return a.lerp(c, u).lerp(c.lerp(b, u), u)


func _daily_line() -> String:
	_touch_daily()
	var count := int(save["daily"]["count"])
	if _as_bool(save["daily"]["claimed"]):
		return "Дневная цель закрыта"
	return "Сегодня %d/3  ·  награда 120" % count


func _dex_count() -> int:
	var n := 0
	for spec in Catalog.FISH:
		if save["dex"].has(str(spec["id"])):
			n += 1
	return n


func _touch_daily() -> void:
	var today := _today()
	if str(save["daily"].get("date", "")) != today:
		save["daily"] = {"date": today, "count": 0, "claimed": false}


func _today() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(d["year"]), int(d["month"]), int(d["day"])]


func _toast(s: String) -> void:
	toast_text = s
	toast_t = 1.7


func _fresh() -> Dictionary:
	return {
		"version": 1,
		"coins": 0,
		"location": "cove",
		"unlocked": ["cove"],
		"gear": {"rod": 0, "line": 0, "reel": 0, "bait": 0},
		"dex": {},
		"stats": {"catches": 0, "best": 0.0, "total": 0.0, "streak": 0, "best_streak": 0},
		"daily": {"date": "", "count": 0, "claimed": false},
	}


func _load() -> void:
	save = _fresh()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	save["coins"] = int(parsed.get("coins", 0))
	var loc_id := str(parsed.get("location", "cove"))
	save["location"] = loc_id if not Catalog.by_id(loc_id).is_empty() else "cove"
	var unlocked = parsed.get("unlocked", ["cove"])
	if typeof(unlocked) == TYPE_ARRAY and not unlocked.is_empty():
		save["unlocked"] = unlocked
	if not ("cove" in save["unlocked"]):
		save["unlocked"].append("cove")
	var gear = parsed.get("gear", {})
	if typeof(gear) == TYPE_DICTIONARY:
		for k in ["rod", "line", "reel", "bait"]:
			save["gear"][k] = clampi(int(gear.get(k, 0)), 0, 4)
	var dex = parsed.get("dex", {})
	if typeof(dex) == TYPE_DICTIONARY:
		save["dex"] = dex
	var stats = parsed.get("stats", {})
	if typeof(stats) == TYPE_DICTIONARY:
		save["stats"]["catches"] = int(stats.get("catches", 0))
		save["stats"]["best"] = float(stats.get("best", 0.0))
		save["stats"]["total"] = float(stats.get("total", 0.0))
		save["stats"]["streak"] = int(stats.get("streak", 0))
		save["stats"]["best_streak"] = int(stats.get("best_streak", 0))
	var daily = parsed.get("daily", {})
	if typeof(daily) == TYPE_DICTIONARY:
		save["daily"] = {
			"date": str(daily.get("date", "")),
			"count": int(daily.get("count", 0)),
			"claimed": _as_bool(daily.get("claimed", false)),
		}
	_touch_daily()


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(save))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		if not save.is_empty():
			_save()


func _as_bool(v) -> bool:
	if typeof(v) == TYPE_BOOL:
		return v
	if typeof(v) == TYPE_STRING:
		return v == "true"
	return int(v) != 0


func _blip(freq: float, dur: float, vol: float = 0.5) -> void:
	var rate := 22050
	var n := maxi(1, int(float(rate) * dur))
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var env := 1.0 - float(i) / float(n)
		var s := sin(TAU * freq * float(i) / float(rate)) * env * vol
		_write_sample(data, i, s)
	_spawn_player(data, rate)


func _chime() -> void:
	var rate := 22050
	var dur := 0.46
	var n := int(float(rate) * dur)
	var freqs := [523.0, 659.0, 784.0]
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var u := float(i) / float(n)
		var fi := mini(int(u * 3.0), 2)
		var s := sin(TAU * freqs[fi] * float(i) / float(rate)) * sin(u * PI) * 0.7
		_write_sample(data, i, s)
	_spawn_player(data, rate)


func _write_sample(data: PackedByteArray, i: int, sample: float) -> void:
	var v := int(clampf(sample, -1.0, 1.0) * 28000.0)
	if v < 0:
		v += 65536
	data[i * 2] = v & 255
	data[i * 2 + 1] = (v >> 8) & 255


func _spawn_player(data: PackedByteArray, rate: int) -> void:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	var player := AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

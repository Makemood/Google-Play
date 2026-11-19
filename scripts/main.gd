extends Node2D

const Catalog = preload("res://scripts/catalog.gd")
const Art = preload("res://scripts/art.gd")

const W := 390.0
const H := 844.0
const SAVE_PATH := "user://golden_bite_save.json"

const INK := Color("07141a")
const CREAM := Color("f4ebda")
const GOLD := Color("e4a04a")
const MUTED := Color("8aa09a")
const RUST := Color("c46a45")
const GREEN := Color("7ea37a")

enum Phase { HOME, READY, CHARGING, FLYING, WAITING, BITE, FIGHT, RESULT, SHOP, DEX, MAP, SAIL }

var phase: int = Phase.HOME
var save: Dictionary = {}
var t := 0.0
var power := 0.0
var cast_dist := 0.5
var bobber := Vector2(220, 410)
var bobber_dip := 0.0
var boat := Vector2(190, 560)
var boat_heading := Vector2(0, -1)
var boat_speed := 0.0
var hotspot := Vector2(210, 250)
var linger := 0.0
var linger_anchor := Vector2(190, 560)
var spooked := false
var dragging := false
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
var painter


func _ready() -> void:
	font = ThemeDB.fallback_font
	painter = Art.new()
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
	_sail(delta)
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
		var hop := clampf(fly_from.distance_to(fly_to) * 0.28, 10.0, 42.0)
		var arc := sin(u * PI) * hop
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
		if dragging and phase == Phase.SAIL:
			boat = _clamp_water(boat + event.relative)
			if event.relative.length() > 1.5:
				boat_heading = event.relative.normalized()
			boat_speed = 90.0
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pointer_pos = event.position
		pointer_down = event.pressed
		if event.pressed:
			_on_press(event.position)
		else:
			dragging = false
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
	if phase == Phase.SAIL and id == "":
		dragging = true
		return
	if phase == Phase.READY and (id == "cast" or id == ""):
		phase = Phase.CHARGING
		_blip(480.0, 0.04, 0.4)
		return
	match id:
		"play":
			_enter_lake()
		"shop":
			phase = Phase.SHOP
		"dex":
			phase = Phase.DEX
		"map":
			phase = Phase.MAP
		"again":
			_enter_lake()
		"shore":
			phase = Phase.HOME
		"cast":
			if phase == Phase.SAIL:
				_boat_cast()
		"buy_rod", "buy_line", "buy_reel", "buy_bait":
			_buy(id.trim_prefix("buy_"))
		"loc_cove", "loc_river", "loc_pier", "loc_sea":
			_travel(id.trim_prefix("loc_"))


func _on_release() -> void:
	if phase == Phase.CHARGING:
		_cast()


func _go_back() -> void:
	if phase == Phase.SHOP or phase == Phase.DEX or phase == Phase.MAP:
		phase = Phase.HOME
	elif phase == Phase.SAIL:
		phase = Phase.HOME
	elif phase == Phase.READY or phase == Phase.CHARGING or phase == Phase.WAITING or phase == Phase.BITE or phase == Phase.FLYING:
		_enter_lake()
	elif phase == Phase.FIGHT:
		_fail("Смотал", "Снасть смотана. Рыба ушла.")
	else:
		phase = Phase.HOME


func _enter_lake() -> void:
	phase = Phase.SAIL
	dragging = false
	fish = {}


func _moor() -> void:
	boat = Vector2(190, 560)
	boat_heading = Vector2(0, -1)
	boat_speed = 0.0
	linger = 0.0
	spooked = false
	linger_anchor = boat
	dragging = false
	_shift_hotspot()


func _sail(delta: float) -> void:
	_drift_hotspot(delta)
	if phase != Phase.SAIL and phase != Phase.WAITING:
		return
	if phase == Phase.SAIL:
		var wish := _steer()
		if dragging:
			boat_speed = 80.0
		elif wish.length() > 0.05:
			var dir := wish.normalized()
			boat = _clamp_water(boat + dir * 150.0 * delta)
			boat_heading = dir
			boat_speed = 150.0
		else:
			boat_speed = move_toward(boat_speed, 0.0, delta * 280.0)
	if boat.distance_to(linger_anchor) > 34.0:
		linger_anchor = boat
		linger = 0.0
		spooked = false
	elif phase == Phase.SAIL or phase == Phase.WAITING:
		linger += delta
		if linger >= 16.0 and not spooked:
			spooked = true
			_shift_hotspot()
			if phase == Phase.WAITING:
				_fail("Ушла", "Долго стоишь на одном месте. Рыба ушла.")
			else:
				_toast("Рыба ушла с точки")


func _steer() -> Vector2:
	var v := Vector2.ZERO
	if pointer_down:
		var id := _hit(pointer_pos)
		if id == "left":
			v.x -= 1.0
		elif id == "right":
			v.x += 1.0
		elif id == "up":
			v.y -= 1.0
		elif id == "down":
			v.y += 1.0
	if Input.is_action_pressed("ui_left"):
		v.x -= 1.0
	if Input.is_action_pressed("ui_right"):
		v.x += 1.0
	if Input.is_action_pressed("ui_up"):
		v.y -= 1.0
	if Input.is_action_pressed("ui_down"):
		v.y += 1.0
	return v


func _boat_cast() -> void:
	dragging = false
	var heading := boat_heading
	if heading.length() < 0.01:
		heading = Vector2(0, -1)
	else:
		heading = heading.normalized()
	fish = {}
	fly_from = boat
	fly_to = _clamp_water(boat + heading * 48.0)
	fly_t = 0.0
	bobber = boat
	cast_dist = clampf((560.0 - fly_to.y) / 420.0, 0.15, 1.0)
	phase = Phase.FLYING
	_blip(190.0, 0.08, 0.55)


func _clamp_water(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, 72.0, 300.0), clampf(p.y, 168.0, 600.0))


func _zone_at(p: Vector2) -> String:
	if not spooked and p.distance_to(hotspot) <= 58.0:
		return "school"
	if p.y > 500.0:
		return "shallow"
	if p.y < 310.0:
		return "deep"
	return "open"


func zone_label(at: Vector2) -> String:
	if spooked and at.distance_to(linger_anchor) < 50.0:
		return "Пусто"
	match _zone_at(at):
		"shallow":
			return "Мелководье"
		"deep":
			return "Глубина"
		"school":
			return "Косяк"
		_:
			return "Плёс"


func _shift_hotspot() -> void:
	var p := Vector2(randf_range(96.0, 280.0), randf_range(186.0, 450.0))
	if p.distance_to(boat) < 130.0:
		p.y = clampf(boat.y - 180.0, 186.0, 440.0)
	hotspot = p


func _drift_hotspot(delta: float) -> void:
	var away := Vector2.ZERO
	if boat.distance_to(hotspot) < 84.0 and linger > 7.0:
		var delta_pos: Vector2 = hotspot - boat
		if delta_pos.length() > 1.0:
			away = delta_pos.normalized() * 34.0
	var drift := Vector2(sin(t * 0.45), cos(t * 0.31))
	if drift.length() > 0.01:
		drift = drift.normalized() * 16.0
	hotspot = Vector2(
		clampf(hotspot.x + (drift.x + away.x) * delta, 88.0, 292.0),
		clampf(hotspot.y + (drift.y + away.y) * delta, 180.0, 460.0)
	)


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
	var pace := randf_range(1.5, 3.05) * (1.0 - float(bait) * 0.05)
	var zone := _zone_at(bobber)
	if zone == "shallow" or zone == "school":
		pace *= 0.62
	elif zone == "deep":
		pace *= 1.55
	if spooked:
		pace *= 1.7
	wait_total = pace
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
	fish = Catalog.roll_fish(str(save["location"]), int(save["gear"]["bait"]), cast_dist, _zone_at(bobber), spooked)
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
		_moor()
		phase = Phase.SAIL
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
	_moor()
	phase = Phase.SAIL
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
		Phase.SAIL:
			buttons.append({"id": "up", "rect": Rect2(149, 640, 92, 46), "label": "Дальше", "primary": false})
			buttons.append({"id": "left", "rect": Rect2(16, 694, 88, 62), "label": "Лево", "primary": false})
			buttons.append({"id": "cast", "rect": Rect2(112, 694, 166, 62), "label": "Закинуть", "primary": true})
			buttons.append({"id": "right", "rect": Rect2(286, 694, 88, 62), "label": "Право", "primary": false})
			buttons.append({"id": "down", "rect": Rect2(149, 764, 92, 52), "label": "Ближе", "primary": false})
		Phase.READY, Phase.CHARGING:
			buttons.append({"id": "cast", "rect": Rect2(32, 736, 326, 76), "label": "Заброс", "primary": true})
		Phase.WAITING:
			buttons.append({"id": "wait", "rect": Rect2(32, 736, 326, 76), "label": "Жди клёв", "primary": false})
		Phase.BITE:
			buttons.append({"id": "hook", "rect": Rect2(32, 736, 326, 76), "label": "Подсекай", "primary": true})
		Phase.FIGHT:
			buttons.append({"id": "hold", "rect": Rect2(32, 736, 326, 76), "label": "Держи", "primary": true})
		Phase.RESULT:
			buttons.append({"id": "again", "rect": Rect2(32, 700, 326, 60), "label": "К лодке", "primary": true})
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


func _rod_tip() -> Vector2:
	if phase == Phase.CHARGING:
		return Vector2(168, 318 - power * 46.0)
	if phase == Phase.FIGHT:
		return Vector2(188, 250)
	if phase == Phase.BITE:
		return Vector2(184, 268)
	return Vector2(176, 292)


func _draw() -> void:
	var ox := randf_range(-shake, shake)
	draw_set_transform(Vector2(ox, 0.0), 0.0, Vector2.ONE)
	painter.paint(self)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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

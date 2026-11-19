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

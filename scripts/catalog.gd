extends RefCounted

const LOCATIONS := [
	{
		"id": "cove",
		"name": "Тихая заводь",
		"cost": 0,
		"sky0": "163246",
		"sky1": "f0b56a",
		"water": "0e3a44",
		"hill": "1c4034",
	},
	{
		"id": "river",
		"name": "Янтарная река",
		"cost": 600,
		"sky0": "243628",
		"sky1": "e39a4e",
		"water": "1a4634",
		"hill": "2a3d2c",
	},
	{
		"id": "pier",
		"name": "Ночной пирс",
		"cost": 1800,
		"sky0": "070b16",
		"sky1": "24345c",
		"water": "071824",
		"hill": "12182c",
	},
	{
		"id": "sea",
		"name": "Открытое море",
		"cost": 4200,
		"sky0": "0d3048",
		"sky1": "f2c27a",
		"water": "0a4a58",
		"hill": "164458",
	},
]

const FISH := [
	{"id": "roach", "name": "Плотва", "loc": "cove", "rarity": 1, "min_kg": 0.12, "max_kg": 0.45, "color": "c4b08a"},
	{"id": "crucian", "name": "Карась", "loc": "cove", "rarity": 1, "min_kg": 0.30, "max_kg": 1.30, "color": "d7a15a"},
	{"id": "perch", "name": "Окунь", "loc": "cove", "rarity": 2, "min_kg": 0.20, "max_kg": 1.20, "color": "6f8f62"},
	{"id": "pike", "name": "Щука", "loc": "cove", "rarity": 3, "min_kg": 1.20, "max_kg": 7.00, "color": "7e9a78"},
	{"id": "chub", "name": "Голавль", "loc": "river", "rarity": 2, "min_kg": 0.40, "max_kg": 2.00, "color": "8aa0a8"},
	{"id": "ide", "name": "Язь", "loc": "river", "rarity": 2, "min_kg": 0.50, "max_kg": 2.50, "color": "c9845a"},
	{"id": "trout", "name": "Форель", "loc": "river", "rarity": 3, "min_kg": 0.40, "max_kg": 2.20, "color": "d07a6a"},
	{"id": "catfish", "name": "Сом", "loc": "river", "rarity": 4, "min_kg": 3.00, "max_kg": 18.00, "color": "5c5348"},
	{"id": "bream", "name": "Лещ", "loc": "pier", "rarity": 2, "min_kg": 0.60, "max_kg": 3.50, "color": "b7a48a"},
	{"id": "zander", "name": "Судак", "loc": "pier", "rarity": 3, "min_kg": 0.80, "max_kg": 5.00, "color": "8e9a7a"},
	{"id": "eel", "name": "Угорь", "loc": "pier", "rarity": 3, "min_kg": 0.40, "max_kg": 2.00, "color": "3e4a44"},
	{"id": "flounder", "name": "Камбала", "loc": "pier", "rarity": 4, "min_kg": 0.50, "max_kg": 3.00, "color": "c4a06a"},
	{"id": "mackerel", "name": "Скумбрия", "loc": "sea", "rarity": 2, "min_kg": 0.30, "max_kg": 1.20, "color": "4f7c8a"},
	{"id": "bass", "name": "Сибас", "loc": "sea", "rarity": 3, "min_kg": 0.60, "max_kg": 3.50, "color": "9aa8b0"},
	{"id": "tuna", "name": "Тунец", "loc": "sea", "rarity": 4, "min_kg": 4.00, "max_kg": 25.00, "color": "3d5f86"},
	{"id": "koi", "name": "Золотой карп", "loc": "sea", "rarity": 5, "min_kg": 1.50, "max_kg": 8.00, "color": "e4a04a"},
]

const GEAR := {
	"rod": {"name": "Удилище", "blurb": "Дольше окно подсечки", "costs": [120, 340, 760, 1500]},
	"line": {"name": "Леска", "blurb": "Шире зелёная зона", "costs": [100, 280, 640, 1300]},
	"reel": {"name": "Катушка", "blurb": "Быстрее копится улов", "costs": [140, 380, 820, 1600]},
	"bait": {"name": "Наживка", "blurb": "Чаще клюёт крупная", "costs": [80, 220, 520, 1100]},
}

const GEAR_ORDER := ["rod", "line", "reel", "bait"]

const RARITY_NAME := ["", "Обычная", "Неплохая", "Редкая", "Трофей", "Легенда"]


static func by_id(id: String) -> Dictionary:
	for loc in LOCATIONS:
		if str(loc["id"]) == id:
			return loc
	return {}


static func fish_by_id(id: String) -> Dictionary:
	for fish in FISH:
		if str(fish["id"]) == id:
			return fish
	return {}


static func fish_in(loc_id: String) -> Array:
	var out: Array = []
	for fish in FISH:
		if str(fish["loc"]) == loc_id:
			out.append(fish)
	return out


static func roll_fish(loc_id: String, bait: int, distance: float, zone: String = "open", spooked: bool = false) -> Dictionary:
	var pool: Array = []
	var weights: Array = []
	var sum := 0.0
	for fish in FISH:
		if str(fish["loc"]) != loc_id:
			continue
		var rarity := int(fish["rarity"])
		var w := 1.0 / pow(float(rarity), 1.35)
		if rarity >= 3:
			w *= 1.0 + float(bait) * 0.18 + distance * 0.35
		if rarity >= 5:
			w *= 0.4
		if zone == "shallow":
			w *= 1.8 if rarity <= 2 else 0.35
		elif zone == "deep":
			if rarity == 1:
				w *= 0.4
			elif rarity >= 3:
				w *= 1.7
		elif zone == "school":
			if rarity >= 3:
				w *= 2.3
			if rarity >= 4:
				w *= 1.35
		if spooked and rarity >= 2:
			w *= 0.4
		pool.append(fish)
		weights.append(w)
		sum += w
	var chosen: Dictionary = pool[0]
	var r := randf() * sum
	var acc := 0.0
	for i in pool.size():
		acc += float(weights[i])
		if r <= acc:
			chosen = pool[i]
			break
	var bias := 1.55
	if zone == "shallow":
		bias = 2.35
	elif zone == "deep":
		bias = 0.8
	elif zone == "school":
		bias = 1.05
	if spooked:
		bias += 0.65
	var t := pow(randf(), bias)
	var kg := lerpf(float(chosen["min_kg"]), float(chosen["max_kg"]), t)
	var out := chosen.duplicate()
	out["weight"] = snapped(kg, 0.01)
	out["zone"] = zone
	return out


static func coins_for(fish: Dictionary) -> int:
	var mul := [0, 16, 28, 52, 95, 190]
	var rarity := clampi(int(fish["rarity"]), 1, 5)
	return maxi(1, int(round(float(fish["weight"]) * float(mul[rarity]))))


static func rarity_name(rarity: int) -> String:
	return RARITY_NAME[clampi(rarity, 1, 5)]

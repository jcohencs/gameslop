extends Node
## Global state. "Meta" (cash, stash, upgrades, weapons) survives between raids and is
## saved to disk; "raid" state (binder, health, heat) is at risk until you extract.

signal changed
signal message(text: String, color: Color)
signal card_acquired(card: Dictionary)
signal settings_changed

const SAVE_PATH := "user://save.cfg"
const SETTINGS_PATH := "user://settings.cfg"
const WIN_COST := 3000

const RARITIES := [
	{"name": "Common", "color": Color(0.85, 0.85, 0.85), "min": 2, "max": 5, "weight": 40.0},
	{"name": "Uncommon", "color": Color(0.4, 0.95, 0.4), "min": 8, "max": 20, "weight": 30.0},
	{"name": "Rare", "color": Color(0.35, 0.65, 1.0), "min": 30, "max": 70, "weight": 18.0},
	{"name": "Holo", "color": Color(0.85, 0.45, 1.0), "min": 100, "max": 200, "weight": 9.0},
	{"name": "Legendary", "color": Color(1.0, 0.78, 0.15), "min": 400, "max": 800, "weight": 3.0},
]

const CARD_NAMES := [
	"Charzard", "Pikachew", "Blue-Eyed Wyrm", "Mewthree", "Dark Magic Gal",
	"Exodiya's Left Toe", "Squirtel", "Bulbasore", "Gyarados-ish", "Snorlax Jr.",
	"Mega Bidoof", "Shadow Lugi", "Time Wizard Steve", "Jiggly Puffy", "Dragonknight Kevin",
	"Rainbow Eevie", "Golden Goomba", "Cyber Dino Rex", "Holo Hamster", "Black Lotus (prob. fake)",
]

## Places you can raid. rarity_bonus boosts the odds of Rare+ cards.
## guard is the patrolling adult that watches for scams (see parent.gd TYPES).
const LOCATIONS := {
	"playground": {"name": "Sunnyvale Playground", "fee": 0, "time": 240.0, "kids": 8, "rarity_bonus": 0.0,
		"heat_floor": 0, "guard": "monitor", "difficulty": 1,
		"desc": "Recess. Lots of kids, mostly junk cards. A lone recess monitor patrols."},
	"locals": {"name": "Friday Night Locals @ Dragon's Den", "fee": 15, "time": 300.0, "kids": 10, "rarity_bonus": 1.2,
		"heat_floor": 1, "guard": "owner", "difficulty": 2,
		"desc": "The weekly tournament. Fat binders full of holos. Gary the store owner is watching."},
	"pizza": {"name": "Pizza Party Palace", "fee": 25, "time": 300.0, "kids": 12, "rarity_bonus": 1.6,
		"heat_floor": 1, "guard": "cheesy", "difficulty": 2,
		"desc": "A birthday bash with arcade cabinets and a giant ball pit: dive in to vanish from grown-ups. Cheesy the Rat keeps order."},
	"mall": {"name": "Galleria Mall Food Court", "fee": 40, "time": 300.0, "kids": 11, "rarity_bonus": 2.5,
		"heat_floor": 2, "guard": "cop", "difficulty": 3,
		"desc": "Rich kids with Legendaries. Mall cops on patrol, gym coaches on speed dial."},
}

## One modifier is rolled per raid. Effects are read through mod(key, default).
const RAID_MODIFIERS := {
	"bake_sale": {"name": "Bake Sale", "desc": "Adults are distracted by brownies (-30% sight range)", "sight": 0.7},
	"report_card": {"name": "Report Card Day", "desc": "Everyone's on edge (heat cools down 50% slower)", "heat_decay": 0.5},
	"free_refills": {"name": "Free Refills", "desc": "Sugar rush! Kids show up twice as fast", "kid_respawn": 0.5},
	"holo_hype": {"name": "Holo Hype", "desc": "A new set just dropped: Rare+ cards everywhere", "rarity_bonus": 1.0},
}

## Scam tactics, in trade-screen order. base = odds before upgrades and penalties.
## gentle = no heat and no crying even on failure (the kid just gets wary).
const TACTICS := [
	{"id": "junk", "label": "Offer a \"super rare\" junk card", "base": 0.6, "heat": 8.0, "cry": 0.25,
		"junk_cost": 1, "sticker_cost": 0, "gentle": false, "cost_text": "Costs 1 junk card  ·  low heat"},
	{"id": "sticker", "label": "Holo-sticker forgery", "base": 0.9, "heat": 4.0, "cry": 0.1,
		"junk_cost": 1, "sticker_cost": 1, "gentle": false, "cost_text": "Costs 1 junk + 1 sticker  ·  barely any heat"},
	{"id": "bundle", "label": "Bundle Deal (\"three for one, bro!\")", "base": 0.8, "heat": 5.0, "cry": 0.15,
		"junk_cost": 3, "sticker_cost": 0, "gentle": false, "cost_text": "Costs 3 junk cards  ·  low heat"},
	{"id": "sob", "label": "Sob Story (\"my dog ate my deck...\")", "base": 0.35, "heat": 0.0, "cry": 0.0,
		"junk_cost": 0, "sticker_cost": 0, "gentle": true, "cost_text": "Free  ·  no heat  ·  never cries"},
	{"id": "ufo", "label": "\"Whoa, is that a UFO?!\" (swipe it)", "base": 0.75, "heat": 22.0, "cry": 1.0,
		"junk_cost": 0, "sticker_cost": 0, "gentle": false, "cost_text": "Free  ·  the kid WILL cry  ·  high heat"},
]

## Collector orders: reward multiplier over expected sell value, and the guaranteed floor.
const ORDER_COUNT := 3
const ORDER_REWARD_MULT := 1.6
const ORDER_MIN_MULT := 1.5
const ORDER_NAME_FLOOR := 40

const UPGRADES := {
	"tongue": {"name": "Silver Tongue", "desc": "+8% scam success", "base": 40, "max": 5},
	"shoes": {"name": "Light-Up Sneakers", "desc": "+10% move speed", "base": 30, "max": 4},
	"binder": {"name": "Fat Binder", "desc": "+5 card slots per raid", "base": 35, "max": 4},
	"armor": {"name": "Puffy Vest", "desc": "+30 max health", "base": 50, "max": 5},
	"protein": {"name": "Protein Shake", "desc": "+15% melee damage", "base": 45, "max": 5},
	"cardio": {"name": "Gym Membership", "desc": "+25 stamina (more heavies)", "base": 40, "max": 4},
	"hoodie": {"name": "Shady Hoodie", "desc": "-20% heat, harder to spot", "base": 60, "max": 3},
	"grading": {"name": "Fake Grading Slabs", "desc": "+25% sell price", "base": 80, "max": 4},
}

## Melee weapons. kind is "fist" or "sword". arc = half-angle (deg) of the hit cone.
## combo = damage multipliers for the light-attack chain; heavy = charged attack multiplier.
const WEAPONS := {
	"knuckles": {"name": "Bare Knuckles", "kind": "fist", "cost": 0, "damage": 16.0, "rate": 0.3, "range": 2.2,
		"arc": 40.0, "knock": 4.0, "stun": 0.25, "combo": [1.0, 1.0, 1.5], "heavy": 2.4,
		"color": Color(0.85, 0.62, 0.48), "size": 0.05},
	"brass": {"name": "Brass Knuckles", "kind": "fist", "cost": 120, "damage": 26.0, "rate": 0.32, "range": 2.2,
		"arc": 40.0, "knock": 5.0, "stun": 0.3, "combo": [1.0, 1.0, 1.5], "heavy": 2.4,
		"color": Color(0.95, 0.75, 0.2), "size": 0.052},
	"foam": {"name": "Foam LARP Sword", "kind": "sword", "cost": 90, "damage": 20.0, "rate": 0.42, "range": 3.0,
		"arc": 70.0, "knock": 7.0, "stun": 0.35, "combo": [1.0, 1.1, 1.6], "heavy": 2.2,
		"color": Color(0.3, 0.6, 1.0), "blade": 0.9},
	"gloves": {"name": "Boxing Gloves", "kind": "fist", "cost": 220, "damage": 22.0, "rate": 0.42, "range": 2.4,
		"arc": 50.0, "knock": 15.0, "stun": 0.7, "combo": [1.0, 1.0, 1.4], "heavy": 2.0,
		"color": Color(0.9, 0.12, 0.12), "size": 0.075},
	"katana": {"name": "Mall Kiosk Katana", "kind": "sword", "cost": 400, "damage": 42.0, "rate": 0.48, "range": 3.2,
		"arc": 75.0, "knock": 8.0, "stun": 0.4, "combo": [1.0, 1.15, 1.7], "heavy": 2.3,
		"color": Color(0.85, 0.88, 0.95), "blade": 1.05},
	"gauntlet": {"name": "Power Gauntlet (1989)", "kind": "fist", "cost": 650, "damage": 50.0, "rate": 0.5, "range": 2.8,
		"arc": 85.0, "knock": 11.0, "stun": 0.5, "combo": [1.0, 1.0, 1.5], "heavy": 2.2,
		"color": Color(0.35, 0.4, 0.5), "size": 0.07},
	# Thrown, not swung: blinds every parent in a cone. Uses sand packets.
	"sand": {"name": "Pocket Sand", "kind": "sand", "cost": 60, "damage": 0.0, "rate": 0.8, "range": 7.0,
		"arc": 45.0, "knock": 2.0, "stun": 0.0, "blind": 3.5, "combo": [1.0], "heavy": 1.0,
		"color": Color(0.9, 0.78, 0.5), "size": 0.05},
}
const WEAPON_ORDER := ["knuckles", "brass", "foam", "gloves", "katana", "gauntlet", "sand"]

## Player movement profile (Quake/STRAFTAT style). Speeds in m/s. See specs/001-movement-retune.
const MOVEMENT := {
	"run_speed": 5.0, "sprint_speed": 6.8, "crouch_speed": 2.6,
	"ground_accel": 10.0, "air_accel": 10.0, "air_cap": 0.6,
	"friction": 6.0, "stop_speed": 2.0,
	"slide_start_speed": 4.5, "slide_boost": 2.0, "slide_boost_cd": 1.0,
	"slide_friction": 1.4, "slide_min_speed": 2.5,
	"max_speed": 12.0, "jump_velocity": 6.2,
	"noise_crouch": 0.35, "noise_run": 0.8, "noise_sprint": 1.0,
	"ball_pit_speed": 2.5,  # speed cap inside ball pits (Pizza Party Palace)
}

const JUNK_PACK_COST := 5
const JUNK_PACK_SIZE := 10
const STICKER_COST := 12
const SAND_COST := 8
const SAND_PACK := 3

# Settings
var mouse_sensitivity := 0.3   # 0.05 .. 1.0
var invert_y := false
var fov := 85.0
var volume := 0.8

# Meta (persists between raids)
var cash: int
var stash: Array          # extracted, unsold cards
var junk: int             # carried into raids; lost if you don't extract
var stickers: int
var sand: int             # pocket sand packets, carried like supplies
var upgrades: Dictionary
var weapons_owned: Dictionary
var weapon_id: String
var orders: Array        # collector orders (see roll_orders)
var raids: int
var extracts: int
var scams: int
var knockouts: int
var won: bool

# Raid (at risk)
var location_id := ""
var raid_modifier := ""
var binder: Array
var health: float
var stamina: float
var heat: float
var raid_time_left: float


func _ready() -> void:
	_setup_input()
	load_settings()
	reset()


func reset() -> void:
	cash = 20
	stash = []
	junk = 10
	stickers = 0
	sand = 0
	upgrades = {}
	for k in UPGRADES:
		upgrades[k] = 0
	weapons_owned = {}
	for k in WEAPONS:
		weapons_owned[k] = k == "knuckles"
	weapon_id = "knuckles"
	raids = 0
	extracts = 0
	scams = 0
	knockouts = 0
	won = false
	location_id = ""
	raid_modifier = ""
	binder = []
	roll_orders()
	heat = 0.0
	health = max_health()
	stamina = max_stamina()
	changed.emit()


# --- Derived stats -----------------------------------------------------------

func max_health() -> float:
	return 100.0 + upgrades.get("armor", 0) * 30.0

func max_stamina() -> float:
	return 100.0 + upgrades.get("cardio", 0) * 25.0

func speed_mult() -> float:
	return 1.0 + upgrades["shoes"] * 0.1

func capacity() -> int:
	return 6 + upgrades["binder"] * 5

func scam_bonus() -> float:
	return upgrades["tongue"] * 0.08

func heat_mult() -> float:
	return 1.0 - upgrades["hoodie"] * 0.2

func stealth_mult() -> float:
	## Multiplies how far parents can see you.
	return 1.0 - upgrades["hoodie"] * 0.12

func sell_mult() -> float:
	return 1.0 + upgrades["grading"] * 0.25

func damage_mult() -> float:
	return 1.0 + upgrades["protein"] * 0.15

func upgrade_cost(id: String) -> int:
	return int(UPGRADES[id]["base"]) * (int(upgrades[id]) + 1)

func stars() -> int:
	var floor_stars: int = LOCATIONS[location_id]["heat_floor"] if location_id != "" else 0
	return clampi(ceili(heat / 20.0) + floor_stars, 0, 5)

func weapon() -> Dictionary:
	return WEAPONS[weapon_id]

func weapon_slot(id: String) -> int:
	return WEAPON_ORDER.find(id) + 1


# --- Cards -------------------------------------------------------------------

func roll_card(rarity_bonus := 0.0) -> Dictionary:
	var weights := []
	var total := 0.0
	for i in RARITIES.size():
		var w: float = RARITIES[i]["weight"] * (1.0 + rarity_bonus if i >= 2 else 1.0)
		weights.append(w)
		total += w
	var pick := randf() * total
	var idx := 0
	for i in weights.size():
		pick -= weights[i]
		if pick <= 0.0:
			idx = i
			break
	var r: Dictionary = RARITIES[idx]
	return {
		"name": CARD_NAMES[randi() % CARD_NAMES.size()],
		"rarity": idx,
		"value": randi_range(r["min"], r["max"]),
		"art": randi(),
	}

func card_sell_value(card: Dictionary) -> int:
	return int(round(card["value"] * sell_mult()))

func cards_value(cards: Array) -> int:
	var total := 0
	for c in cards:
		total += card_sell_value(c)
	return total

func rarity_name(card: Dictionary) -> String:
	return RARITIES[card["rarity"]]["name"]

func rarity_color(card: Dictionary) -> Color:
	return RARITIES[card["rarity"]]["color"]

func add_to_binder(card: Dictionary) -> bool:
	if binder.size() >= capacity():
		return false
	binder.append(card)
	card_acquired.emit(card)
	changed.emit()
	return true

func sell_stash() -> int:
	var total := cards_value(stash)
	cash += total
	stash.clear()
	save_game()
	changed.emit()
	return total

func sell_card(index: int) -> int:
	if index < 0 or index >= stash.size():
		return 0
	var v := card_sell_value(stash[index])
	cash += v
	stash.remove_at(index)
	save_game()
	changed.emit()
	return v


# --- Raid lifecycle ----------------------------------------------------------

func start_raid(id: String) -> bool:
	var fee: int = LOCATIONS[id]["fee"]
	if fee > 0 and not try_spend(fee):
		return false
	location_id = id
	binder = []
	heat = 0.0
	health = max_health()
	stamina = max_stamina()
	raid_time_left = LOCATIONS[id]["time"]
	raids += 1
	changed.emit()
	return true

## Successful extraction: binder goes into the stash.
func extract() -> Dictionary:
	var result := {"cards": binder.size(), "value": cards_value(binder)}
	stash.append_array(binder)
	binder = []
	extracts += 1
	location_id = ""
	save_game()
	changed.emit()
	return result

## Knocked out, timed out or abandoned: binder and carried supplies are gone.
func lose_raid() -> Dictionary:
	var result := {"cards": binder.size(), "value": cards_value(binder), "junk": junk, "stickers": stickers, "sand": sand}
	binder = []
	junk = 0
	stickers = 0
	sand = 0
	location_id = ""
	save_game()
	changed.emit()
	return result


# --- Economy -----------------------------------------------------------------

func try_spend(amount: int) -> bool:
	if cash < amount:
		say("Not enough cash! Need $%d." % amount, Color(1, 0.4, 0.4))
		return false
	cash -= amount
	changed.emit()
	return true

func buy_upgrade(id: String) -> bool:
	if upgrades[id] >= UPGRADES[id]["max"]:
		return false
	if not try_spend(upgrade_cost(id)):
		return false
	upgrades[id] += 1
	health = max_health()
	stamina = max_stamina()
	say("Bought %s (lvl %d)" % [UPGRADES[id]["name"], upgrades[id]], Color(0.5, 1, 0.5))
	save_game()
	changed.emit()
	return true

func buy_weapon(id: String) -> bool:
	if weapons_owned[id]:
		return false
	if not try_spend(int(WEAPONS[id]["cost"])):
		return false
	weapons_owned[id] = true
	weapon_id = id
	say("Bought %s!" % WEAPONS[id]["name"], Color(0.5, 1, 0.5))
	save_game()
	changed.emit()
	return true

func equip_weapon(id: String) -> void:
	if weapons_owned.get(id, false) and weapon_id != id:
		weapon_id = id
		changed.emit()

## Cycle through owned weapons (mouse wheel).
func cycle_weapon(step: int) -> void:
	var owned := []
	for id in WEAPON_ORDER:
		if weapons_owned[id]:
			owned.append(id)
	if owned.size() < 2:
		return
	var i := owned.find(weapon_id)
	equip_weapon(owned[posmod(i + step, owned.size())])

func buy_junk() -> bool:
	if not try_spend(JUNK_PACK_COST):
		return false
	junk += JUNK_PACK_SIZE
	save_game()
	changed.emit()
	return true

func buy_sand() -> bool:
	if not try_spend(SAND_COST):
		return false
	sand += SAND_PACK
	save_game()
	changed.emit()
	return true

func buy_sticker() -> bool:
	if not try_spend(STICKER_COST):
		return false
	stickers += 1
	save_game()
	changed.emit()
	return true


# --- Heat / health -----------------------------------------------------------

func add_heat(amount: float) -> void:
	heat = clampf(heat + amount * heat_mult(), 0.0, 100.0)
	changed.emit()

func damage(amount: float) -> void:
	health = maxf(health - amount, 0.0)
	changed.emit()


func say(text: String, color := Color.WHITE) -> void:
	message.emit(text, color)


# --- Raid modifiers ----------------------------------------------------------

func roll_raid_modifier() -> String:
	var ids := RAID_MODIFIERS.keys()
	raid_modifier = ids[randi() % ids.size()]
	return raid_modifier

## Value of the active modifier's effect key, or default when no modifier sets it.
func mod(key: String, default: float) -> float:
	if raid_modifier == "" or not RAID_MODIFIERS.has(raid_modifier):
		return default
	return RAID_MODIFIERS[raid_modifier].get(key, default)


# --- Collector orders --------------------------------------------------------

func _ceil5(x: float) -> int:
	return int(ceil(x / 5.0)) * 5

func _rarity_avg(r: int) -> float:
	return (RARITIES[r]["min"] + RARITIES[r]["max"]) * 0.5

func roll_orders() -> void:
	orders = []
	for i in ORDER_COUNT:
		orders.append(_roll_order())

func _roll_order() -> Dictionary:
	if randf() < 0.3:
		var n: String = CARD_NAMES[randi() % CARD_NAMES.size()]
		var reward := maxi(_ceil5(_rarity_avg(1) * sell_mult() * ORDER_REWARD_MULT), ORDER_NAME_FLOOR)
		return {"kind": "name", "card_name": n, "rarity": 0, "count": 1, "reward": reward,
			"title": "Deliver any \"%s\"" % n, "filled": false}
	var r: int = [2, 2, 3, 3, 4][randi() % 5]
	var count: int = {2: randi_range(1, 3), 3: randi_range(1, 2), 4: 1}[r]
	var reward := _ceil5(_rarity_avg(r) * count * sell_mult() * ORDER_REWARD_MULT)
	return {"kind": "rarity", "rarity": r, "count": count, "card_name": "", "reward": reward,
		"title": "Deliver %d %s+ card%s" % [count, RARITIES[r]["name"], "s" if count > 1 else ""], "filled": false}

func _order_qualifies(order: Dictionary, card: Dictionary) -> bool:
	if order["kind"] == "name":
		return card["name"] == order["card_name"]
	return card["rarity"] >= order["rarity"]

## Stash indices of the cheapest cards that fill this order, or [] if it can't be filled.
func order_matches(order: Dictionary) -> Array:
	if order.get("filled", false):
		return []
	var idx := []
	for i in stash.size():
		if _order_qualifies(order, stash[i]):
			idx.append(i)
	idx.sort_custom(func(a, b): return card_sell_value(stash[a]) < card_sell_value(stash[b]))
	if idx.size() < order["count"]:
		return []
	return idx.slice(0, order["count"])

func order_have(order: Dictionary) -> int:
	var n := 0
	for c in stash:
		if _order_qualifies(order, c):
			n += 1
	return mini(n, order["count"])

func order_payout(order: Dictionary) -> int:
	var removed := 0
	for i in order_matches(order):
		removed += card_sell_value(stash[i])
	return maxi(order["reward"], _ceil5(removed * ORDER_MIN_MULT))

## Fulfills order i from the stash. Returns the cash paid (0 if it couldn't be filled).
func fulfill_order(i: int) -> int:
	if i < 0 or i >= orders.size():
		return 0
	var order: Dictionary = orders[i]
	var idx := order_matches(order)
	if idx.is_empty():
		return 0
	var pay := order_payout(order)
	idx.sort()
	idx.reverse()
	for j in idx:
		stash.remove_at(j)
	cash += pay
	order["filled"] = true
	save_game()
	changed.emit()
	return pay

func orders_ready() -> int:
	var n := 0
	for o in orders:
		if not order_matches(o).is_empty():
			n += 1
	return n


# --- Persistence -------------------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> void:
	var cfg := ConfigFile.new()
	for key in ["cash", "stash", "junk", "stickers", "sand", "orders", "upgrades", "weapons_owned", "weapon_id",
			"raids", "extracts", "scams", "knockouts", "won"]:
		cfg.set_value("meta", key, get(key))
	cfg.save(SAVE_PATH)

func load_game() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return false
	reset()
	for key in ["cash", "stash", "junk", "stickers", "sand", "raids", "extracts", "scams", "knockouts", "won", "weapon_id"]:
		if cfg.has_section_key("meta", key):
			set(key, cfg.get_value("meta", key))
	# Merge dictionaries so newly added upgrades/weapons get defaults.
	var saved_up: Dictionary = cfg.get_value("meta", "upgrades", {})
	for k in saved_up:
		if upgrades.has(k):
			upgrades[k] = saved_up[k]
	var saved_w: Dictionary = cfg.get_value("meta", "weapons_owned", {})
	for k in saved_w:
		if weapons_owned.has(k):
			weapons_owned[k] = saved_w[k]
	if not weapons_owned.get(weapon_id, false):
		weapon_id = "knuckles"
	var saved_orders: Array = cfg.get_value("meta", "orders", [])
	if saved_orders.size() == ORDER_COUNT:
		orders = saved_orders
	else:
		roll_orders()
	health = max_health()
	stamina = max_stamina()
	changed.emit()
	return true

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("input", "invert_y", invert_y)
	cfg.set_value("video", "fov", fov)
	cfg.set_value("audio", "volume", volume)
	cfg.save(SETTINGS_PATH)
	_apply_volume()
	settings_changed.emit()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		mouse_sensitivity = cfg.get_value("input", "mouse_sensitivity", mouse_sensitivity)
		invert_y = cfg.get_value("input", "invert_y", invert_y)
		fov = cfg.get_value("video", "fov", fov)
		volume = cfg.get_value("audio", "volume", volume)
	_apply_volume()

func _apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))


# --- Input map (defined in code so project.godot stays tiny) -----------------

func _setup_input() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE],
		"sprint": [KEY_SHIFT],
		"crouch": [KEY_CTRL, KEY_C],
		"throw_sand": [KEY_Q],
		"interact": [KEY_E],
		"pause": [KEY_ESCAPE],
	}
	for i in WEAPON_ORDER.size():
		keys["weapon_%d" % (i + 1)] = [KEY_1 + i]
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	var mouse := {"attack": MOUSE_BUTTON_LEFT, "block": MOUSE_BUTTON_RIGHT,
		"weapon_next": MOUSE_BUTTON_WHEEL_DOWN, "weapon_prev": MOUSE_BUTTON_WHEEL_UP}
	for action in mouse:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var mb := InputEventMouseButton.new()
			mb.button_index = mouse[action]
			InputMap.action_add_event(action, mb)

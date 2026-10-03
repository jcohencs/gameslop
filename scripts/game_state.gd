extends Node
## Global run state: money, cards, upgrades, weapons, heat.

signal changed
signal message(text: String, color: Color)

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
	"Rainbow Eevie", "Golden Goomba", "Cyber Dino Rex", "Holo Hamster", "Sir Fluffington",
]

const UPGRADES := {
	"tongue": {"name": "Silver Tongue", "desc": "+8% scam success", "base": 40, "max": 5},
	"shoes": {"name": "Light-Up Sneakers", "desc": "+15% move speed", "base": 30, "max": 4},
	"binder": {"name": "Fat Binder", "desc": "+6 card slots", "base": 35, "max": 4},
	"armor": {"name": "Puffy Vest", "desc": "+40 max health", "base": 50, "max": 5},
	"hoodie": {"name": "Shady Hoodie", "desc": "-20% heat gained", "base": 60, "max": 3},
	"grading": {"name": "Fake Grading Slabs", "desc": "+25% sell price", "base": 80, "max": 4},
}

const WEAPONS := {
	"pistol": {"name": "Pea Pistol", "cost": 0, "damage": 25.0, "rate": 0.28, "mag": 12, "reload": 1.1,
		"pellets": 1, "spread": 0.01, "auto": false, "rocket": false, "color": Color(0.2, 0.2, 0.22), "key": 1},
	"shotgun": {"name": "Boomstick", "cost": 150, "damage": 14.0, "rate": 0.8, "mag": 6, "reload": 1.8,
		"pellets": 8, "spread": 0.08, "auto": false, "rocket": false, "color": Color(0.45, 0.28, 0.12), "key": 2},
	"smg": {"name": "Recess SMG", "cost": 300, "damage": 11.0, "rate": 0.08, "mag": 35, "reload": 1.5,
		"pellets": 1, "spread": 0.035, "auto": true, "rocket": false, "color": Color(0.15, 0.3, 0.15), "key": 3},
	"rocket": {"name": "Bake-Sale Bazooka", "cost": 700, "damage": 160.0, "rate": 1.2, "mag": 1, "reload": 1.6,
		"pellets": 1, "spread": 0.0, "auto": false, "rocket": true, "color": Color(0.5, 0.5, 0.1), "key": 4},
}

const JUNK_PACK_COST := 5
const JUNK_PACK_SIZE := 10
const STICKER_COST := 12

var cash: int
var junk: int
var stickers: int
var cards: Array
var health: float
var heat: float
var scams: int
var knockouts: int
var deaths: int
var won: bool
var upgrades: Dictionary
var weapons_owned: Dictionary


func _ready() -> void:
	_setup_input()
	reset()


func reset() -> void:
	cash = 20
	junk = 10
	stickers = 0
	cards = []
	heat = 0.0
	scams = 0
	knockouts = 0
	deaths = 0
	won = false
	upgrades = {}
	for k in UPGRADES:
		upgrades[k] = 0
	weapons_owned = {"pistol": true, "shotgun": false, "smg": false, "rocket": false}
	health = max_health()
	changed.emit()


# --- Derived stats -----------------------------------------------------------

func max_health() -> float:
	return 100.0 + upgrades.get("armor", 0) * 40.0

func speed_mult() -> float:
	return 1.0 + upgrades["shoes"] * 0.15

func capacity() -> int:
	return 8 + upgrades["binder"] * 6

func scam_bonus() -> float:
	return upgrades["tongue"] * 0.08

func heat_mult() -> float:
	return 1.0 - upgrades["hoodie"] * 0.2

func sell_mult() -> float:
	return 1.0 + upgrades["grading"] * 0.25

func upgrade_cost(id: String) -> int:
	return int(UPGRADES[id]["base"]) * (int(upgrades[id]) + 1)

func stars() -> int:
	return clampi(ceili(heat / 20.0), 0, 5)


# --- Cards -------------------------------------------------------------------

func roll_card() -> Dictionary:
	var total := 0.0
	for r in RARITIES:
		total += r["weight"]
	var pick := randf() * total
	var idx := 0
	for i in RARITIES.size():
		pick -= RARITIES[i]["weight"]
		if pick <= 0.0:
			idx = i
			break
	var r: Dictionary = RARITIES[idx]
	return {
		"name": CARD_NAMES[randi() % CARD_NAMES.size()],
		"rarity": idx,
		"value": randi_range(r["min"], r["max"]),
	}

func card_sell_value(card: Dictionary) -> int:
	return int(round(card["value"] * sell_mult()))

func collection_value() -> int:
	var total := 0
	for c in cards:
		total += card_sell_value(c)
	return total

func rarity_name(card: Dictionary) -> String:
	return RARITIES[card["rarity"]]["name"]

func rarity_color(card: Dictionary) -> Color:
	return RARITIES[card["rarity"]]["color"]

func add_card(card: Dictionary) -> bool:
	if cards.size() >= capacity():
		return false
	cards.append(card)
	changed.emit()
	return true

func sell_all() -> int:
	var total := collection_value()
	cash += total
	cards.clear()
	changed.emit()
	return total


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
	var old_max := max_health()
	upgrades[id] += 1
	if id == "armor":
		health += max_health() - old_max
	say("Bought %s (lvl %d)" % [UPGRADES[id]["name"], upgrades[id]], Color(0.5, 1, 0.5))
	changed.emit()
	return true

func buy_weapon(id: String) -> bool:
	if weapons_owned[id]:
		return false
	if not try_spend(int(WEAPONS[id]["cost"])):
		return false
	weapons_owned[id] = true
	say("Bought the %s! Press %d to equip." % [WEAPONS[id]["name"], WEAPONS[id]["key"]], Color(0.5, 1, 0.5))
	changed.emit()
	return true


# --- Heat / health -----------------------------------------------------------

func add_heat(amount: float) -> void:
	heat = clampf(heat + amount * heat_mult(), 0.0, 100.0)
	changed.emit()

func damage(amount: float) -> void:
	health = maxf(health - amount, 0.0)
	changed.emit()

func on_death() -> Dictionary:
	var lost_cash := cash / 2
	var lost_cards := cards.size()
	cash -= lost_cash
	cards.clear()
	heat = 0.0
	deaths += 1
	health = max_health()
	changed.emit()
	return {"cash": lost_cash, "cards": lost_cards}


func say(text: String, color := Color.WHITE) -> void:
	message.emit(text, color)


# --- Input map (defined in code so project.godot stays tiny) -----------------

func _setup_input() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE],
		"sprint": [KEY_SHIFT],
		"interact": [KEY_E],
		"reload": [KEY_R],
		"weapon_1": [KEY_1],
		"weapon_2": [KEY_2],
		"weapon_3": [KEY_3],
		"weapon_4": [KEY_4],
		"pause": [KEY_ESCAPE],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	if not InputMap.has_action("shoot"):
		InputMap.add_action("shoot")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("shoot", mb)

extends Node
## Global state. "Meta" (cash, stash, upgrades, fists) survives between raids;
## "raid" state (binder, health, heat) is at risk until you extract.

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
	"Rainbow Eevie", "Golden Goomba", "Cyber Dino Rex", "Holo Hamster", "Black Lotus (prob. fake)",
]

## Places you can raid. rarity_bonus boosts the odds of Rare+ cards.
const LOCATIONS := {
	"playground": {"name": "Sunnyvale Playground", "fee": 0, "time": 240.0, "kids": 8, "rarity_bonus": 0.0, "heat_floor": 0,
		"desc": "Recess. Lots of kids, mostly junk cards. Moms and dads only. A good warm-up."},
	"locals": {"name": "Friday Night Locals @ Dragon's Den Games", "fee": 15, "time": 300.0, "kids": 10, "rarity_bonus": 1.2, "heat_floor": 1,
		"desc": "The weekly tournament. Kids with fat binders full of holos. The PTA plays here too."},
	"mall": {"name": "Galleria Mall Food Court", "fee": 40, "time": 300.0, "kids": 11, "rarity_bonus": 2.5, "heat_floor": 2,
		"desc": "Rich kids with Legendaries and their rich, angry parents. Gym coaches on patrol."},
}

const UPGRADES := {
	"tongue": {"name": "Silver Tongue", "desc": "+8% scam success", "base": 40, "max": 5},
	"shoes": {"name": "Light-Up Sneakers", "desc": "+12% move speed", "base": 30, "max": 4},
	"binder": {"name": "Fat Binder", "desc": "+5 card slots per raid", "base": 35, "max": 4},
	"armor": {"name": "Puffy Vest", "desc": "+30 max health", "base": 50, "max": 5},
	"protein": {"name": "Protein Shake", "desc": "+15% punch damage", "base": 45, "max": 5},
	"hoodie": {"name": "Shady Hoodie", "desc": "-20% heat gained", "base": 60, "max": 3},
	"grading": {"name": "Fake Grading Slabs", "desc": "+25% sell price", "base": 80, "max": 4},
}

## Melee weapons. arc is the half-angle (degrees) of the punch cone.
const FISTS := {
	"knuckles": {"name": "Bare Knuckles", "cost": 0, "damage": 18.0, "rate": 0.36, "range": 2.3, "arc": 40.0,
		"knock": 4.0, "stun": 0.25, "color": Color(0.85, 0.62, 0.48), "size": 0.11, "key": 1},
	"brass": {"name": "Brass Knuckles", "cost": 120, "damage": 30.0, "rate": 0.38, "range": 2.3, "arc": 40.0,
		"knock": 5.0, "stun": 0.3, "color": Color(0.95, 0.75, 0.2), "size": 0.12, "key": 2},
	"gloves": {"name": "Boxing Gloves", "cost": 220, "damage": 24.0, "rate": 0.5, "range": 2.6, "arc": 50.0,
		"knock": 15.0, "stun": 0.7, "color": Color(0.9, 0.12, 0.12), "size": 0.18, "key": 3},
	"gauntlet": {"name": "Power Gauntlet (1989)", "cost": 600, "damage": 55.0, "rate": 0.6, "range": 3.0, "arc": 85.0,
		"knock": 11.0, "stun": 0.5, "color": Color(0.35, 0.4, 0.5), "size": 0.16, "key": 4},
}

const JUNK_PACK_COST := 5
const JUNK_PACK_SIZE := 10
const STICKER_COST := 12

# Meta (persists between raids)
var cash: int
var stash: Array          # extracted, unsold cards
var junk: int             # carried into raids; lost if you don't extract
var stickers: int
var upgrades: Dictionary
var fists_owned: Dictionary
var fist_id: String
var raids: int
var extracts: int
var scams: int
var knockouts: int
var won: bool

# Raid (at risk)
var location_id := ""
var binder: Array
var health: float
var heat: float
var raid_time_left: float


func _ready() -> void:
	_setup_input()
	reset()


func reset() -> void:
	cash = 20
	stash = []
	junk = 10
	stickers = 0
	upgrades = {}
	for k in UPGRADES:
		upgrades[k] = 0
	fists_owned = {}
	for k in FISTS:
		fists_owned[k] = k == "knuckles"
	fist_id = "knuckles"
	raids = 0
	extracts = 0
	scams = 0
	knockouts = 0
	won = false
	binder = []
	heat = 0.0
	health = max_health()
	changed.emit()


# --- Derived stats -----------------------------------------------------------

func max_health() -> float:
	return 100.0 + upgrades.get("armor", 0) * 30.0

func speed_mult() -> float:
	return 1.0 + upgrades["shoes"] * 0.12

func capacity() -> int:
	return 6 + upgrades["binder"] * 5

func scam_bonus() -> float:
	return upgrades["tongue"] * 0.08

func heat_mult() -> float:
	return 1.0 - upgrades["hoodie"] * 0.2

func sell_mult() -> float:
	return 1.0 + upgrades["grading"] * 0.25

func damage_mult() -> float:
	return 1.0 + upgrades["protein"] * 0.15

func upgrade_cost(id: String) -> int:
	return int(UPGRADES[id]["base"]) * (int(upgrades[id]) + 1)

func stars() -> int:
	var floor_stars: int = LOCATIONS[location_id]["heat_floor"] if location_id != "" else 0
	return clampi(ceili(heat / 20.0) + floor_stars, 0, 5)

func fist() -> Dictionary:
	return FISTS[fist_id]


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
	changed.emit()
	return true

func sell_stash() -> int:
	var total := cards_value(stash)
	cash += total
	stash.clear()
	changed.emit()
	return total


# --- Raid lifecycle ----------------------------------------------------------

func start_raid(id: String) -> bool:
	var fee: int = LOCATIONS[id]["fee"]
	if fee > 0 and not try_spend(fee):
		return false
	location_id = id
	binder = []
	heat = 0.0
	health = max_health()
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
	changed.emit()
	return result

## Died or ran out of time: binder and carried supplies are gone.
func lose_raid() -> Dictionary:
	var result := {"cards": binder.size(), "value": cards_value(binder), "junk": junk, "stickers": stickers}
	binder = []
	junk = 0
	stickers = 0
	location_id = ""
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
	say("Bought %s (lvl %d)" % [UPGRADES[id]["name"], upgrades[id]], Color(0.5, 1, 0.5))
	changed.emit()
	return true

func buy_fist(id: String) -> bool:
	if fists_owned[id]:
		return false
	if not try_spend(int(FISTS[id]["cost"])):
		return false
	fists_owned[id] = true
	fist_id = id
	say("Bought %s!" % FISTS[id]["name"], Color(0.5, 1, 0.5))
	changed.emit()
	return true

func equip_fist(id: String) -> void:
	if fists_owned.get(id, false):
		fist_id = id
		changed.emit()


# --- Heat / health -----------------------------------------------------------

func add_heat(amount: float) -> void:
	heat = clampf(heat + amount * heat_mult(), 0.0, 100.0)
	changed.emit()

func damage(amount: float) -> void:
	health = maxf(health - amount, 0.0)
	changed.emit()


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
	var mouse := {"punch": MOUSE_BUTTON_LEFT, "block": MOUSE_BUTTON_RIGHT}
	for action in mouse:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var mb := InputEventMouseButton.new()
			mb.button_index = mouse[action]
			InputMap.action_add_event(action, mb)

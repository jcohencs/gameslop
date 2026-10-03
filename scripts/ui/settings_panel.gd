extends PanelContainer
## Settings: mouse sensitivity, invert Y, FOV, volume. Emits closed when done.

signal closed


func _ready() -> void:
	add_theme_stylebox_override("panel", UI.box(UI.PANEL, 14, 2, UI.ACCENT, 20))
	custom_minimum_size = Vector2(520, 0)
	var v := UI.vbox(14)
	add_child(v)
	v.add_child(UI.label("SETTINGS", 28, UI.ACCENT, true))
	_slider(v, "Mouse sensitivity", 0.05, 1.0, 0.01, GameState.mouse_sensitivity,
		func(x): GameState.mouse_sensitivity = x, func(x): return "%.2f" % x)
	_slider(v, "Field of view", 65.0, 110.0, 1.0, GameState.fov,
		func(x): GameState.fov = x, func(x): return "%d" % x)
	_slider(v, "Volume", 0.0, 1.0, 0.01, GameState.volume, _set_volume, func(x): return "%d%%" % roundi(x * 100.0))
	var gfx_row := UI.hbox(10)
	v.add_child(gfx_row)
	var gfx_l := UI.label("Graphics quality", 17, UI.TEXT_DIM)
	gfx_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gfx_row.add_child(gfx_l)
	var gfx := OptionButton.new()
	gfx.add_item("High", 0)
	gfx.add_item("Low (faster)", 1)
	gfx.selected = 0 if GameState.graphics_quality == "high" else 1
	gfx.focus_mode = Control.FOCUS_NONE
	gfx.item_selected.connect(_set_quality)
	gfx_row.add_child(gfx)
	v.add_child(UI.label("Graphics quality applies from the next raid.", 13, UI.TEXT_DIM))
	var inv := CheckBox.new()
	inv.text = "Invert mouse Y"
	inv.button_pressed = GameState.invert_y
	inv.focus_mode = Control.FOCUS_NONE
	inv.toggled.connect(func(on): GameState.invert_y = on)
	v.add_child(inv)
	v.add_child(UI.button("Done", _close, 20, 46))


func _slider(parent: Control, title: String, lo: float, hi: float, step: float, value: float,
		setter: Callable, fmt: Callable) -> void:
	var row := UI.vbox(4)
	parent.add_child(row)
	var top := UI.hbox()
	row.add_child(top)
	var name_l := UI.label(title, 17, UI.TEXT_DIM)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_l)
	var val_l := UI.label(fmt.call(value), 17, UI.TEXT, true)
	top.add_child(val_l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(0, 24)
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(_on_slider.bind(setter, fmt, val_l))
	row.add_child(s)


func _on_slider(x: float, setter: Callable, fmt: Callable, val_l: Label) -> void:
	setter.call(x)
	val_l.text = fmt.call(x)


func _set_quality(index: int) -> void:
	GameState.graphics_quality = "high" if index == 0 else "low"


func _set_volume(x: float) -> void:
	GameState.volume = x
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(x, 0.0001)))


func _close() -> void:
	GameState.save_settings()
	closed.emit()

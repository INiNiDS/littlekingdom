extends CanvasLayer

var player: CharacterBody2D
var hp_bar: ProgressBar
var hp_text: Label
var delayed_bar: ProgressBar
var target_hp: float = 100.0


func _ready() -> void:
	player = get_node_or_null("../player") as CharacterBody2D
	if player == null:
		push_error("HUD: cannot find player")
		return
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(18.0, 16.0)
	panel.custom_minimum_size = Vector2(304.0, 88.0)
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.065, 0.063, 0.10, 0.94)
	panel_style.border_color = Color(0.52, 0.44, 0.29, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(12.0)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)
	var header: HBoxContainer = HBoxContainer.new()
	box.add_child(header)
	var heart: Label = Label.new()
	heart.text = "♥"
	heart.add_theme_color_override("font_color", Color(0.96, 0.34, 0.42))
	heart.add_theme_font_size_override("font_size", 25)
	header.add_child(heart)
	var title: Label = Label.new()
	title.text = "  ЖИЗНЬ"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color(0.88, 0.80, 0.65))
	title.add_theme_font_size_override("font_size", 17)
	header.add_child(title)
	hp_text = Label.new()
	hp_text.add_theme_font_size_override("font_size", 17)
	hp_text.add_theme_color_override("font_color", Color(1, 0.95, 0.84))
	header.add_child(hp_text)

	var bars: Control = Control.new()
	bars.custom_minimum_size = Vector2(276.0, 20.0)
	box.add_child(bars)
	delayed_bar = _create_bar(Color(0.48, 0.23, 0.19), true)
	bars.add_child(delayed_bar)
	hp_bar = _create_bar(Color(0.82, 0.18, 0.27), false)
	bars.add_child(hp_bar)

	player.connect("health_changed", _on_health_changed)
	_on_health_changed(int(player.get("hp")), int(player.get("max_hp")))


func _create_bar(fill_color: Color, show_frame: bool) -> ProgressBar:
	var progress: ProgressBar = ProgressBar.new()
	progress.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	progress.show_percentage = false
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.16, 0.12, 0.17, 1.0) if show_frame else Color(0, 0, 0, 0)
	if show_frame:
		bg.set_border_width_all(1)
		bg.border_color = Color(0.63, 0.51, 0.36)
		bg.set_corner_radius_all(3)
	progress.add_theme_stylebox_override("background", bg)
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(2)
	progress.add_theme_stylebox_override("fill", fill)
	return progress


func _on_health_changed(current: int, maximum: int) -> void:
	target_hp = float(current)
	hp_text.text = "%d / %d" % [current, maximum]
	hp_bar.max_value = maximum
	delayed_bar.max_value = maximum
	hp_bar.value = current
	if delayed_bar.value < current or delayed_bar.value == 0.0:
		delayed_bar.value = current


func _process(delta: float) -> void:
	if delayed_bar != null:
		delayed_bar.value = move_toward(delayed_bar.value, target_hp, 48.0 * delta)

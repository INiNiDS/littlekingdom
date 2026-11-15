extends CanvasLayer

var retry_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_screen()
	var player: Node = get_node_or_null("../player")
	if player != null:
		player.connect("died", _show_death_menu)


func _build_screen() -> void:
	var cover: ColorRect = ColorRect.new()
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.color = Color(0.035, 0.025, 0.055, 0.89)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(cover)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 348)
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)

	var stack: VBoxContainer = VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 12)
	panel.add_child(stack)
	var icon_label: Label = Label.new()
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_color_override("font_color", Color(0.80, 0.26, 0.31))
	icon_label.add_theme_font_size_override("font_size", 38)
	stack.add_child(icon_label)
	var title: Label = Label.new()
	title.text = "ВЫ ПОГИБЛИ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.98, 0.83, 0.75))
	title.add_theme_font_size_override("font_size", 34)
	stack.add_child(title)
	var subtitle: Label = Label.new()
	subtitle.text = "Ваш путь ещё не окончен"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.74, 0.70, 0.73))
	subtitle.add_theme_font_size_override("font_size", 15)
	stack.add_child(subtitle)

	retry_button = _make_button("ПОПРОБОВАТЬ СНОВА", stack)
	retry_button.pressed.connect(_restart)
	var menu_button: Button = _make_button("ГЛАВНОЕ МЕНЮ", stack)
	menu_button.pressed.connect(_main_menu)
	var exit_button: Button = _make_button("ВЫЙТИ ИЗ ИГРЫ", stack)
	exit_button.pressed.connect(_quit)


func _panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.083, 0.14, 0.99)
	style.border_color = Color(0.69, 0.49, 0.32)
	style.set_border_width_all(3)
	style.set_corner_radius_all(9)
	style.set_content_margin_all(22.0)
	return style


func _make_button(caption: String, parent: VBoxContainer) -> Button:
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(370.0, 46.0)
	btn.text = caption
	btn.add_theme_font_size_override("font_size", 17)
	btn.add_theme_color_override("font_color", Color(0.94, 0.86, 0.73))
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color(0.22, 0.15, 0.23)
	normal.border_color = Color(0.5, 0.38, 0.32)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.43, 0.22, 0.30)
	btn.add_theme_stylebox_override("hover", hover)
	parent.add_child(btn)
	return btn


func _show_death_menu() -> void:
	visible = true
	get_tree().paused = true
	retry_button.grab_focus()


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _quit() -> void:
	get_tree().paused = false
	get_tree().quit()

extends Control


func _ready() -> void:
	get_tree().paused = false
	_build_menu()


func _build_menu() -> void:
	var dark: ColorRect = ColorRect.new()
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dark.color = Color(0.05, 0.04, 0.09, 0.72)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dark)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.custom_minimum_size = Vector2(430, 400)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 20)
	center.add_child(stack)

	var title: Label = Label.new()
	title.text = "LITTLE KINGDOM"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(0.96, 0.82, 0.55))
	stack.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.text = "Тёмные земли"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.76, 0.69, 0.8))
	stack.add_child(subtitle)

	var play: Button = _button("НАЧАТЬ ИГРУ", stack)
	play.pressed.connect(_start_game)
	var quit: Button = _button("ВЫЙТИ", stack)
	quit.pressed.connect(_quit_game)
	play.grab_focus()


func _button(caption: String, box: VBoxContainer) -> Button:
	var btn: Button = Button.new()
	btn.text = caption
	btn.custom_minimum_size = Vector2(400, 50)
	btn.add_theme_font_size_override("font_size", 19)
	btn.add_theme_color_override("font_color", Color(0.97, 0.89, 0.75))
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.12, 0.18, 0.94)
	style.border_color = Color(0.59, 0.44, 0.32)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", style)
	var highlight: StyleBoxFlat = style.duplicate() as StyleBoxFlat
	highlight.bg_color = Color(0.41, 0.22, 0.28)
	btn.add_theme_stylebox_override("hover", highlight)
	box.add_child(btn)
	return btn


func _start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _quit_game() -> void:
	get_tree().quit()

extends Node2D

var slash_left: float = 0.0
var slash_direction: int = 1
var dust: Array[Dictionary] = []
var dust_cooldown: float = 0.0


func start_slash(direction: int) -> void:
	slash_direction = direction
	slash_left = 0.22
	queue_redraw()


func make_dust(x_offset: float) -> void:
	if dust_cooldown > 0.0:
		return
	dust_cooldown = 0.12
	for i in range(3):
		dust.append({"pos": Vector2(x_offset + randf_range(-5.0, 5.0), -2.0), "vel": Vector2(randf_range(-22.0, 22.0), randf_range(-23.0, -8.0)), "life": randf_range(0.26, 0.42)})


func make_mining_sparks(world_position: Vector2) -> void:
	var at: Vector2 = to_local(world_position)
	for i in range(9):
		dust.append({
			"pos": at + Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0)),
			"vel": Vector2(randf_range(-55.0, 55.0), randf_range(-65.0, -16.0)),
			"life": randf_range(0.22, 0.50)
		})
	queue_redraw()


func _process(delta: float) -> void:
	var was_visible: bool = slash_left > 0.0 or not dust.is_empty()
	slash_left = maxf(0.0, slash_left - delta)
	dust_cooldown = maxf(0.0, dust_cooldown - delta)
	for i in range(dust.size() - 1, -1, -1):
		var p: Dictionary = dust[i]
		p["life"] = float(p["life"]) - delta
		p["pos"] = p["pos"] + p["vel"] * delta
		var v: Vector2 = p["vel"]
		p["vel"] = v.lerp(Vector2(0.0, 15.0), delta * 4.0)
		if float(p["life"]) <= 0.0:
			dust.remove_at(i)
		else:
			dust[i] = p
	if was_visible or slash_left > 0.0 or not dust.is_empty():
		queue_redraw()


func _draw() -> void:
	for p in dust:
		var alpha: float = clampf(float(p["life"]) * 1.7, 0.0, 0.55)
		draw_rect(Rect2(Vector2(p["pos"]), Vector2(3, 3)), Color(0.57, 0.48, 0.62, alpha))
	if slash_left <= 0.0:
		return
	var fade: float = clampf(slash_left / 0.22, 0.0, 1.0)
	var center: Vector2 = Vector2(float(slash_direction) * 13.0, -27.0)
	var a: float = -1.0
	var b: float = 1.2
	if slash_direction < 0:
		a = PI - 1.2
		b = PI + 1.0
	draw_arc(center, 32.0, a, b, 18, Color(0.56, 0.91, 1.0, fade * 0.46), 7.0, true)
	draw_arc(center, 32.0, a, b, 18, Color(0.95, 0.95, 0.78, fade * 0.90), 2.5, true)

extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal died
signal guard_recruited(guard: KnightGuard)

@export var move_speed: float = 300.0
@export var jump_speed: float = -400.0
@export var gravity: float = 980.0
@export var max_hp: int = 100
@export var sword_damage: int = 24
@export var sword_reach: float = 76.0
@export var sprite_size: float = 1.32

const ATTACK_COOLDOWN: float = 0.40
const ATTACK_DURATION: float = 0.32
const MINE_DURATION: float = 0.40
const MINE_IMPACT_REMAINING: float = 0.19
const MINE_COOLDOWN: float = 0.10

var pshenicha: int = 0
var player_crops: int = 0
var hp: int = 100
var facing: int = 1
var hit_time_left: float = 0.0
var invulnerability_left: float = 0.0
var attack_time_left: float = 0.0
var attack_cooldown_left: float = 0.0
var attack_landed: bool = false
var mine_time_left: float = 0.0
var mine_cooldown_left: float = 0.0
var mine_landed: bool = false
var mine_target: Vector2 = Vector2.ZERO
var is_dead: bool = false
var run_phase: float = 0.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var effects: Node2D = $CombatFX


func _ready() -> void:
	add_to_group("player")
	hp = max_hp
	anim.scale = Vector2.ONE * sprite_size
	health_changed.emit(hp, max_hp)
	_play_animation(&"default")


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	attack_cooldown_left = maxf(0.0, attack_cooldown_left - delta)
	invulnerability_left = maxf(0.0, invulnerability_left - delta)
	hit_time_left = maxf(0.0, hit_time_left - delta)
	attack_time_left = maxf(0.0, attack_time_left - delta)
	mine_time_left = maxf(0.0, mine_time_left - delta)
	mine_cooldown_left = maxf(0.0, mine_cooldown_left - delta)
	if mine_time_left > 0.0 and not mine_landed and mine_time_left <= MINE_IMPACT_REMAINING:
		_mine_impact()

	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, 740.0)
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_speed

	var axis: float = Input.get_axis("ui_left", "ui_right")
	if absf(axis) > 0.01:
		facing = -1 if axis < 0.0 else 1
		anim.flip_h = facing < 0
		velocity.x = move_toward(velocity.x, axis * move_speed, 2100.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 2500.0 * delta)

	if Input.is_action_just_pressed("attack") and attack_cooldown_left <= 0.0 and mine_time_left <= 0.0:
		_begin_attack()
	if Input.is_action_just_pressed("interact"):
		_recruit_nearest_guard()
	# Terraria-style continuous mining when the mouse is held down.
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		request_mine(get_global_mouse_position())

	move_and_slide()
	if attack_time_left > 0.0 and not attack_landed and attack_time_left < 0.19:
		_attack_impact()
	_animate(delta)


func request_mine(mouse_global: Vector2) -> void:
	if is_dead or hit_time_left > 0.0 or attack_time_left > 0.0 or mine_time_left > 0.0 or mine_cooldown_left > 0.0:
		return
	var world: DarkFantasyWorld = get_node_or_null("../World") as DarkFantasyWorld
	if world == null or not world.can_mine_at(mouse_global, global_position):
		return
	mine_target = mouse_global
	mine_time_left = MINE_DURATION
	mine_cooldown_left = MINE_DURATION + MINE_COOLDOWN
	mine_landed = false
	if absf(mouse_global.x - global_position.x) > 5.0:
		facing = -1 if mouse_global.x < global_position.x else 1
		anim.flip_h = facing < 0
	_play_animation(&"mine")


func _mine_impact() -> void:
	mine_landed = true
	var world: DarkFantasyWorld = get_node_or_null("../World") as DarkFantasyWorld
	if world == null or not world.can_mine_at(mine_target, global_position):
		return
	world.mine_at(mine_target, global_position)
	if effects.has_method("make_mining_sparks"):
		effects.call("make_mining_sparks", mine_target)


func _begin_attack() -> void:
	attack_time_left = ATTACK_DURATION
	attack_cooldown_left = ATTACK_COOLDOWN
	attack_landed = false
	_play_animation(&"attack")
	if effects.has_method("start_slash"):
		effects.call("start_slash", facing)


func _attack_impact() -> void:
	attack_landed = true
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy: CharacterBody2D = node as CharacterBody2D
		if enemy == null or not is_instance_valid(enemy) or bool(enemy.get("dead")):
			continue
		var d: Vector2 = enemy.global_position - global_position
		if absf(d.x) <= sword_reach and absf(d.y) < 83.0 and d.x * float(facing) > -12.0:
			var q: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position + Vector2(0.0, -21.0), enemy.global_position + Vector2(0.0, -21.0), 1)
			if get_world_2d().direct_space_state.intersect_ray(q).is_empty():
				enemy.call("take_damage", sword_damage, self)


func _recruit_nearest_guard() -> void:
	var nearest: KnightGuard = null
	var distance: float = INF
	for node in get_tree().get_nodes_in_group("guards"):
		var guard: KnightGuard = node as KnightGuard
		if guard == null or not guard.can_recruit():
			continue
		var d: float = global_position.distance_to(guard.global_position)
		if d < distance:
			distance = d
			nearest = guard
	if nearest != null:
		nearest.recruit()
		guard_recruited.emit(nearest)


func _animate(delta: float) -> void:
	if hit_time_left > 0.0:
		_play_animation(&"hit")
	elif mine_time_left > 0.0:
		_play_animation(&"mine")
	elif attack_time_left > 0.0:
		_play_animation(&"attack")
	elif not is_on_floor():
		_play_animation(&"jump" if velocity.y < 0.0 else &"fall")
	elif absf(velocity.x) > 16.0:
		_play_animation(&"run")
	else:
		_play_animation(&"default")

	var run_intensity: float = clampf(absf(velocity.x) / move_speed, 0.0, 1.0)
	var bob: float = 0.0
	if is_on_floor() and run_intensity > 0.2 and attack_time_left <= 0.0 and mine_time_left <= 0.0:
		run_phase += delta * 16.0 * run_intensity
		bob = sin(run_phase) * 0.85 * run_intensity
		if effects.has_method("make_dust") and sin(run_phase) > 0.98:
			effects.call("make_dust", -float(facing) * 10.0)
	anim.position.y = lerpf(anim.position.y, -31.0 + bob, minf(1.0, delta * 14.0))
	var target_scale: float = sprite_size
	if attack_time_left > 0.0:
		target_scale *= 1.045
	anim.scale = anim.scale.lerp(Vector2.ONE * target_scale, minf(1.0, delta * 14.0))


func take_damage(amount: int, _attacker: Node2D = null) -> void:
	if is_dead or invulnerability_left > 0.0:
		return
	hp = maxi(0, hp - maxi(amount, 0))
	mine_time_left = 0.0
	mine_landed = true
	invulnerability_left = 0.45
	hit_time_left = 0.25
	_play_animation(&"hit")
	health_changed.emit(hp, max_hp)
	if hp == 0:
		is_dead = true
		velocity = Vector2.ZERO
		died.emit()


func _play_animation(animation_name: StringName) -> void:
	if anim.sprite_frames == null or not anim.sprite_frames.has_animation(animation_name):
		return
	if anim.animation != animation_name or not anim.is_playing():
		anim.play(animation_name)


func take() -> void:
	player_crops += 1


func add_pshenicha() -> void:
	pshenicha += 1


func get_pshenicha() -> int:
	return pshenicha

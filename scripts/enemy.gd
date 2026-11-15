extends CharacterBody2D
class_name DarkFantasyEnemy

const SKELETON_FRAMES: SpriteFrames = preload("res://assets/game/skeleton.tres")
const EYE_FRAMES: SpriteFrames = preload("res://assets/game/eye.tres")
const GRAVITY: float = 980.0
const SIGHT_RANGE: float = 650.0

@export_range(0, 1, 1) var kind: int = 0
@export var attack_damage: int = 10
@export var attack_interval: float = 1.15

var target: CharacterBody2D = null
var hp: int = 45
var max_hp: int = 45
var move_speed: float = 104.0
var attack_range: float = 36.0
var attack_cooldown: float = 0.65
var windup_left: float = 0.0
var attacking: bool = false
var hit_left: float = 0.0
var invulnerable_left: float = 0.0
var dead: bool = false
var death_left: float = 0.0
var target_scan_left: float = 0.0
var hesitate_left: float = 0.0
var wander_direction: float = 1.0
var fly_phase: float = 0.0
var attack_fired: bool = false
var player: CharacterBody2D = null

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var health_bar: ProgressBar = $HealthBar


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if kind == 1:
		max_hp = 28
		move_speed = 112.0
		attack_range = 38.0
		anim.sprite_frames = EYE_FRAMES
		anim.position = Vector2(0.0, -22.0)
		body_shape.position = Vector2(0.0, -22.0)
		var circle: CircleShape2D = CircleShape2D.new()
		circle.radius = 12.0
		body_shape.shape = circle
	else:
		max_hp = 48
		move_speed = 109.0
		attack_range = 42.0
		anim.sprite_frames = SKELETON_FRAMES
		anim.position = Vector2(0.0, -23.0)
		body_shape.position = Vector2(0.0, -20.0)
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = Vector2(19.0, 39.0)
		body_shape.shape = rect
	hp = max_hp
	attack_cooldown = randf_range(0.5, 1.1)
	health_bar.max_value = max_hp
	health_bar.value = hp
	health_bar.visible = false
	_play(&"default")


func _physics_process(delta: float) -> void:
	if dead:
		death_left -= delta
		if death_left <= 0.0:
			queue_free()
		return

	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	invulnerable_left = maxf(0.0, invulnerable_left - delta)
	hit_left = maxf(0.0, hit_left - delta)
	target_scan_left -= delta
	fly_phase += delta * 3.1

	if target_scan_left <= 0.0:
		target_scan_left = randf_range(0.22, 0.40)
		_select_target()

	if not _target_alive():
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 4.0 * delta)
		if kind == 0:
			velocity.y = minf(velocity.y + GRAVITY * delta, 700.0)
		move_and_slide()
		_play(&"default")
		return

	var to_target: Vector2 = target.global_position - global_position
	if to_target.x != 0.0:
		anim.flip_h = to_target.x < 0.0

	if attacking:
		windup_left -= delta
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 9.0 * delta)
		if not attack_fired and windup_left <= 0.10:
			attack_fired = true
			_deal_attack_damage()
		if windup_left <= 0.0:
			attacking = false
	elif attack_cooldown <= 0.0 and absf(to_target.x) <= attack_range and absf(to_target.y) <= 65.0 and _clear_sight():
		_begin_attack()
	else:
		if kind == 1:
			_move_flying(delta, to_target)
		else:
			_move_ground(delta, to_target)

	if kind == 0 and not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, 700.0)
	move_and_slide()
	_update_animation()

	if is_instance_valid(player) and global_position.distance_to(player.global_position) > 1300.0:
		queue_free()


func _target_alive() -> bool:
	if not is_instance_valid(target):
		return false
	if target is KnightGuard and (target as KnightGuard).dead:
		return false
	return int(target.get("hp")) > 0


func _select_target() -> void:
	var best: CharacterBody2D = null
	var best_distance: float = SIGHT_RANGE
	if is_instance_valid(player) and int(player.get("hp")) > 0:
		best = player
		best_distance = global_position.distance_to(player.global_position)
		if best_distance > SIGHT_RANGE:
			best = null
			best_distance = SIGHT_RANGE
	for node in get_tree().get_nodes_in_group("guards"):
		var guard: KnightGuard = node as KnightGuard
		if guard == null or guard.dead or not guard.hired:
			continue
		var d: float = global_position.distance_to(guard.global_position)
		if d < best_distance - 25.0:
			best = guard
			best_distance = d
	if _target_alive() and global_position.distance_to(target.global_position) < 110.0:
		return
	target = best


func _move_ground(delta: float, direction: Vector2) -> void:
	var dx: float = direction.x
	var desired: float = signf(dx) * move_speed if absf(dx) > attack_range - 6.0 else 0.0
	velocity.x = move_toward(velocity.x, desired, move_speed * 6.0 * delta)
	if is_on_floor() and absf(dx) > 22.0 and (is_on_wall() or _obstacle_ahead(signf(dx))):
		velocity.y = -350.0


func _obstacle_ahead(direction: float) -> bool:
	var from: Vector2 = global_position + Vector2(direction * 12.0, -19.0)
	var q: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, from + Vector2(direction * 22.0, 0.0), 1)
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _move_flying(delta: float, direction: Vector2) -> void:
	var desired_offset: Vector2 = Vector2(-24.0 if direction.x > 0.0 else 24.0, -27.0 + sin(fly_phase) * 16.0)
	var desired_position: Vector2 = target.global_position + desired_offset
	var chase: Vector2 = desired_position - global_position
	if chase.length() > attack_range:
		velocity = velocity.move_toward(chase.normalized() * move_speed, move_speed * 3.5 * delta)
	else:
		velocity = velocity.move_toward(Vector2(0.0, cos(fly_phase) * 20.0), move_speed * 3.0 * delta)


func _clear_sight() -> bool:
	if not _target_alive():
		return false
	var q: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position + Vector2(0.0, -18.0), target.global_position + Vector2(0.0, -18.0), 1)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _begin_attack() -> void:
	attacking = true
	attack_fired = false
	windup_left = 0.37
	attack_cooldown = attack_interval + randf_range(-0.12, 0.25)
	_play(&"attack")


func _deal_attack_damage() -> void:
	if not _target_alive() or not _clear_sight():
		return
	var d: Vector2 = target.global_position - global_position
	if absf(d.x) <= attack_range + 13.0 and absf(d.y) <= 70.0:
		target.call("take_damage", attack_damage, self)


func take_damage(amount: int, attacker: Node2D = null) -> void:
	if dead or invulnerable_left > 0.0:
		return
	hp = maxi(0, hp - maxi(0, amount))
	invulnerable_left = 0.12
	health_bar.value = hp
	health_bar.visible = true
	if is_instance_valid(attacker) and attacker is CharacterBody2D:
		target = attacker as CharacterBody2D
		target_scan_left = 0.9
	if hp <= 0:
		_die()
	else:
		hit_left = 0.19
		attacking = false
		_play(&"hit")


func _die() -> void:
	dead = true
	attacking = false
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	body_shape.set_deferred("disabled", true)
	health_bar.visible = false
	_play(&"death")
	death_left = 1.2


func _update_animation() -> void:
	if dead:
		return
	if hit_left > 0.0:
		_play(&"hit")
	elif attacking:
		_play(&"attack")
	elif kind == 0 and not is_on_floor():
		_play(&"run")
	elif velocity.length() > 8.0:
		_play(&"run")
	else:
		_play(&"default")


func _play(animation_name: StringName) -> void:
	if anim.sprite_frames != null and anim.sprite_frames.has_animation(animation_name):
		if anim.animation != animation_name or not anim.is_playing():
			anim.play(animation_name)

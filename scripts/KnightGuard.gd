extends CharacterBody2D
class_name KnightGuard

signal health_changed(current: int, maximum: int)
signal recruited(guard: Node)

const GRAVITY: float = 980.0
const JUMP_SPEED: float = -355.0
const SWORD_REACH: float = 70.0
const INTERACT_RANGE: float = 64.0

@export var guard_name: String = "Страж"
@export var guard_index: int = 0
@export var spawn_cell_x: int = -16
@export_range(1, 150, 1) var defense_radius_tiles: int = 100
@export var max_hp: int = 85
@export var attack_damage: int = 18
@export var follow_speed: float = 235.0
@export var pursuit_leash: float = 370.0

var hp: int = 85
var hired: bool = false
var dead: bool = false
var player: CharacterBody2D
var target: CharacterBody2D
var attack_cooldown: float = 0.0
var attack_timer: float = 0.0
var attack_hit: bool = false
var hurt_timer: float = 0.0
var hit_immunity: float = 0.0
var search_timer: float = 0.0
var facing: int = 1
var attack_number: int = 0
var dead_timer: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var hp_bar: ProgressBar = $HealthBar
@onready var name_label: Label = $NameLabel
@onready var hint: Label = $Hint


func _ready() -> void:
	add_to_group("guards")
	player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	hp = max_hp
	name_label.text = guard_name
	var world: DarkFantasyWorld = get_node_or_null("../World") as DarkFantasyWorld
	if world != null:
		var ground: int = world.get_surface_height_at(spawn_cell_x)
		global_position = world.blocks.to_global(world.blocks.map_to_local(Vector2i(spawn_cell_x, ground - 1)))
	_update_hp()
	_play(&"idle")


func can_recruit() -> bool:
	return not dead and not hired and is_instance_valid(player) and player.global_position.distance_to(global_position) <= INTERACT_RANGE


func recruit() -> void:
	if not can_recruit():
		return
	hired = true
	hint.visible = false
	name_label.modulate = Color(0.63, 0.94, 0.98)
	recruited.emit(self)


func _physics_process(delta: float) -> void:
	if dead:
		dead_timer -= delta
		if dead_timer <= 0.0:
			queue_free()
		return

	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	attack_timer = maxf(0.0, attack_timer - delta)
	hurt_timer = maxf(0.0, hurt_timer - delta)
	hit_immunity = maxf(0.0, hit_immunity - delta)
	search_timer -= delta
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, 720.0)

	if is_instance_valid(player):
		hint.visible = can_recruit()
	else:
		hint.visible = false

	if not hired or not _player_alive():
		target = null
		velocity.x = move_toward(velocity.x, 0.0, follow_speed * 7.0 * delta)
	else:
		if search_timer <= 0.0:
			search_timer = 0.18 + float(guard_index) * 0.05
			target = _best_enemy()
		_move_and_fight(delta)

	move_and_slide()
	if hired and attack_timer > 0.0 and not attack_hit and attack_timer <= 0.20:
		_strike()
	_choose_animation()


func _player_alive() -> bool:
	return is_instance_valid(player) and int(player.get("hp")) > 0


func _best_enemy() -> CharacterBody2D:
	if not _player_alive():
		return null
	var best: CharacterBody2D = null
	var best_score: float = INF
	var radius: float = float(defense_radius_tiles * DarkFantasyWorld.TILE_SIZE)
	for candidate in get_tree().get_nodes_in_group("enemies"):
		var enemy: CharacterBody2D = candidate as CharacterBody2D
		if enemy == null or not is_instance_valid(enemy) or bool(enemy.get("dead")):
			continue
		var from_player: float = player.global_position.distance_to(enemy.global_position)
		var from_guard: float = global_position.distance_to(enemy.global_position)
		if from_player > radius or from_guard > pursuit_leash:
			continue
		var score: float = from_guard * 0.65 + from_player * 0.35
		if score < best_score:
			best_score = score
			best = enemy
	return best


func _move_and_fight(delta: float) -> void:
	var destination: Vector2 = player.global_position
	var stopping_distance: float = 26.0
	if is_instance_valid(target) and not bool(target.get("dead")):
		destination = target.global_position
		stopping_distance = 42.0
	else:
		target = null
		var offset: float = float(44 + guard_index * 38)
		destination.x = player.global_position.x - offset * float(int(player.get("facing")))

	var dx: float = destination.x - global_position.x
	var dy: float = destination.y - global_position.y
	if absf(dx) > stopping_distance:
		facing = 1 if dx > 0.0 else -1
		sprite.flip_h = facing < 0
		var speed: float = follow_speed
		if target == null and absf(dx) > 160.0:
			speed = follow_speed * 1.52
		velocity.x = move_toward(velocity.x, float(facing) * speed, speed * 7.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, follow_speed * 10.0 * delta)

	if is_on_floor() and absf(dx) > 28.0 and (is_on_wall() or _front_wall()):
		velocity.y = JUMP_SPEED
	if is_on_floor() and target != null and dy < -50.0 and absf(dx) < 90.0:
		velocity.y = JUMP_SPEED
	if target != null and attack_timer <= 0.0 and attack_cooldown <= 0.0:
		var d: Vector2 = target.global_position - global_position
		if absf(d.x) < SWORD_REACH and absf(d.y) < 85.0 and _has_line_of_sight(target.global_position):
			_start_attack()


func _front_wall() -> bool:
	var from: Vector2 = global_position + Vector2(float(facing) * 10.0, -18.0)
	var to: Vector2 = from + Vector2(float(facing) * 18.0, 0.0)
	var q: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to, 1)
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _has_line_of_sight(point: Vector2) -> bool:
	var q: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position + Vector2(0.0, -21.0), point + Vector2(0.0, -19.0), 1)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _start_attack() -> void:
	attack_number += 1
	attack_timer = 0.38 if attack_number % 2 == 0 else 0.30
	attack_cooldown = 0.63
	attack_hit = false
	_play(&"attack2" if attack_number % 2 == 0 else &"attack")


func _strike() -> void:
	attack_hit = true
	if not is_instance_valid(target) or bool(target.get("dead")):
		return
	var difference: Vector2 = target.global_position - global_position
	if absf(difference.x) <= SWORD_REACH + 10.0 and absf(difference.y) <= 85.0 and difference.x * float(facing) > -18.0 and _has_line_of_sight(target.global_position):
		target.call("take_damage", attack_damage, self)


func take_damage(amount: int, _attacker: Node2D = null) -> void:
	if dead or hit_immunity > 0.0:
		return
	hit_immunity = 0.24
	hp = maxi(0, hp - maxi(amount, 0))
	_update_hp()
	hurt_timer = 0.23
	if hp <= 0:
		_die()
	else:
		_play(&"hit")


func _die() -> void:
	dead = true
	hint.visible = false
	hp_bar.visible = false
	name_label.text = guard_name + " †"
	collision_layer = 0
	collision_mask = 0
	body_shape.set_deferred("disabled", true)
	velocity = Vector2.ZERO
	_play(&"death")
	dead_timer = 3.2


func _update_hp() -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	hp_bar.visible = hp > 0
	health_changed.emit(hp, max_hp)


func _choose_animation() -> void:
	if dead:
		return
	if hurt_timer > 0.0:
		_play(&"hit")
	elif attack_timer > 0.0:
		_play(&"attack2" if attack_number % 2 == 0 else &"attack")
	elif not is_on_floor():
		_play(&"jump" if velocity.y < 0.0 else &"fall")
	elif absf(velocity.x) > 12.0:
		_play(&"run")
	else:
		_play(&"idle")


func _play(animation_name: StringName) -> void:
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_name):
		if sprite.animation != animation_name or not sprite.is_playing():
			sprite.play(animation_name)

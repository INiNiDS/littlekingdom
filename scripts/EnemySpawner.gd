extends Node2D
class_name DarkFantasyEnemySpawner
## Random enemies spawn away from the camera, not in the castle.

const ENEMY_SCENE: PackedScene = preload("res://scenes/Enemy.tscn")

@export_range(1, 20, 1) var max_alive: int = 6
@export_range(1.0, 30.0, 0.5) var spawn_delay_min: float = 4.0
@export_range(1.0, 30.0, 0.5) var spawn_delay_max: float = 7.0
@export_range(20, 70, 1) var spawn_cells_min: int = 26
@export_range(20, 90, 1) var spawn_cells_max: int = 38

@onready var world: DarkFantasyWorld = get_node_or_null("../World") as DarkFantasyWorld
@onready var player: CharacterBody2D = get_node_or_null("../player") as CharacterBody2D

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var time_until_spawn: float = 0.0


func _ready() -> void:
	rng.randomize()
	if world == null or player == null:
		push_error("EnemySpawner: missing sibling World or player")
		set_process(false)
		return
	_next_delay()


func _process(delta: float) -> void:
	if not is_instance_valid(player) or int(player.get("hp")) <= 0:
		return
	time_until_spawn -= delta
	if time_until_spawn <= 0.0:
		_spawn_enemy()
		_next_delay()


func _next_delay() -> void:
	time_until_spawn = rng.randf_range(spawn_delay_min, maxf(spawn_delay_min, spawn_delay_max))


func _spawn_enemy() -> void:
	if get_tree().get_nodes_in_group("enemies").size() >= max_alive:
		return
	var player_cell: Vector2i = world.blocks.local_to_map(world.blocks.to_local(player.global_position))
	for attempt in range(16):
		var direction: int = -1 if rng.randf() < 0.5 else 1
		var distance_cells: int = rng.randi_range(spawn_cells_min, maxi(spawn_cells_min, spawn_cells_max))
		var x: int = player_cell.x + direction * distance_cells
		if absi(x) <= DarkFantasyWorld.CASTLE_BLEND_RADIUS + 5:
			continue
		var floor_y: int = world.get_surface_height_at(x)
		if world.get_tile_id_at(Vector2i(x, floor_y)) == DarkFantasyWorld.AIR:
			continue
		var flying: bool = rng.randf() < 0.40
		var cell: Vector2i = Vector2i(x, floor_y - (5 if flying else 2))
		if world.get_tile_id_at(cell) != DarkFantasyWorld.AIR:
			continue
		if world.get_tile_id_at(cell + Vector2i(0, -1)) != DarkFantasyWorld.AIR:
			continue
		var enemy: DarkFantasyEnemy = ENEMY_SCENE.instantiate() as DarkFantasyEnemy
		if enemy == null:
			push_error("Enemy.tscn must have DarkFantasyEnemy script attached")
			return
		enemy.target = player
		enemy.kind = 1 if flying else 0
		add_child(enemy)
		enemy.global_position = world.blocks.to_global(world.blocks.map_to_local(cell))
		return

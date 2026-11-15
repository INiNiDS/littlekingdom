extends Node2D
class_name DarkFantasyWorld


signal resources_changed
signal selected_block_changed(block_name: String)

const TILE_SIZE: int = 16
const CHUNK_SIZE: int = 16
const TILE_COUNT: int = 32
const NO_CASTLE_TILE: int = -2
const CASTLE_HALF_WIDTH: int = 13
const CASTLE_FLAT_RADIUS: int = 18
const CASTLE_BLEND_RADIUS: int = 28
# Deterministic villages: one house every 30 cells on each side of the castle.
const HOUSE_FIRST_CENTER: int = 40
const HOUSE_SPACING: int = 30
const HOUSE_BLEND: int = 4
const SAVE_PATH: String = "user://terraria_world_save.json"
const ATLAS_PATH: String = "res://assets/dark_fantasy_atlas.png"

const AIR: int = -1
const GRASS: int = 0
const DIRT: int = 1
const STONE: int = 2
const COPPER: int = 3
const IRON: int = 4
const GOLD: int = 5
const WOOD: int = 6
const LEAVES: int = 7
const AUTUMN_GRASS: int = 8
const RED_DIRT: int = 9
const PURPLE_GRASS: int = 10
const LIGHT_DIRT: int = 11
const BRICK: int = 12
const PLANKS: int = 13
const GLASS: int = 14
const SAND: int = 15

# Extra dark-fantasy tiles; original IDs above are unchanged.
const CRACKED_STONE: int = 16
const BONE_STONE: int = 17
const MOSS_STONE: int = 18
const GLOOMSTONE: int = 19
const ROOT_DIRT: int = 20
const RUNE_BRICK: int = 21
const ASH_STONE: int = 22
const OBSIDIAN: int = 23
const CRIMSON_STONE: int = 24
const ARCANE_CRYSTAL: int = 25
const DEAD_WOOD: int = 26
const DEAD_LEAVES: int = 27
const MUSHROOM: int = 28
const VINE: int = 29
const LANTERN: int = 30
const SKULL: int = 31

const BIOME_GLOOMWOOD: int = 0
const BIOME_ASHLANDS: int = 1
const BIOME_BLIGHT: int = 2

@export var world_seed: int = 1733
@export_range(1, 5, 1) var load_radius: int = 3
@export_range(16.0, 240.0, 1.0) var mining_distance: float = 120.0
@export var spawn_player_in_castle: bool = true
@export_node_path("CharacterBody2D") var player_path: NodePath = NodePath("../player")

@onready var player: CharacterBody2D = get_node_or_null(player_path) as CharacterBody2D
@onready var background: TileMapLayer = get_node_or_null("Background") as TileMapLayer
@onready var blocks: TileMapLayer = get_node_or_null("Blocks") as TileMapLayer

var height_noise: FastNoiseLite = FastNoiseLite.new()
var detail_noise: FastNoiseLite = FastNoiseLite.new()
var biome_noise: FastNoiseLite = FastNoiseLite.new()
var cave_noise: FastNoiseLite = FastNoiseLite.new()
var copper_noise: FastNoiseLite = FastNoiseLite.new()
var iron_noise: FastNoiseLite = FastNoiseLite.new()
var gold_noise: FastNoiseLite = FastNoiseLite.new()

var loaded_chunks: Dictionary = {}
var height_cache: Dictionary = {}
var tree_cache: Dictionary = {}
var house_cache: Dictionary = {}
var player_chunk: Vector2i = Vector2i(999999, 999999)
var edits: Dictionary = {} # "x:y" -> tile ID; -1 means air.
var resources: Dictionary = {"copper": 0, "iron": 0, "gold": 0}
var selected_tile: int = DIRT


func _ready() -> void:
	if player == null or background == null or blocks == null:
		push_error("World needs a sibling 'player' and child TileMapLayers: 'Background', 'Blocks'. Check node names / player_path.")
		set_process(false)
		set_process_unhandled_input(false)
		return

	_configure_noise(height_noise, world_seed, 0.016)
	_configure_noise(detail_noise, world_seed + 13, 0.090)
	_configure_noise(biome_noise, world_seed + 23, 0.0035)
	_configure_noise(cave_noise, world_seed + 31, 0.050)
	_configure_noise(copper_noise, world_seed + 71, 0.110)
	_configure_noise(iron_noise, world_seed + 117, 0.090)
	_configure_noise(gold_noise, world_seed + 193, 0.080)

	if not _build_tileset():
		set_process(false)
		set_process_unhandled_input(false)
		return

	_load_save()
	if spawn_player_in_castle:
		# Spawn inside the main castle hall, just above its stone floor.
		player.global_position = blocks.to_global(
			blocks.map_to_local(Vector2i(0, _surface_height(0) - 2))
		)
	_update_chunks()
	selected_block_changed.emit(get_selected_block_text())
	resources_changed.emit()


func _exit_tree() -> void:
	# Do not overwrite an existing save if setup failed.
	if blocks != null and blocks.tile_set != null:
		_save_game()


func _configure_noise(noise: FastNoiseLite, noise_seed: int, frequency: float) -> void:
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = frequency


func _build_tileset() -> bool:
	var atlas_texture: Texture2D = load(ATLAS_PATH) as Texture2D
	if atlas_texture == null:
		push_error("Missing texture: " + ATLAS_PATH)
		return false
	if atlas_texture.get_width() < TILE_COUNT * TILE_SIZE or atlas_texture.get_height() < TILE_SIZE:
		push_error("Incorrect atlas dimensions. Expected at least 512x16 px: " + ATLAS_PATH)
		return false

	var tiles: TileSet = TileSet.new()
	tiles.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tiles.add_physics_layer()
	tiles.set_physics_layer_collision_layer(0, 1)
	tiles.set_physics_layer_collision_mask(0, 1)

	var atlas: TileSetAtlasSource = TileSetAtlasSource.new()
	atlas.texture = atlas_texture
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tiles.add_source(atlas, 0)

	for tile_id in range(TILE_COUNT):
		var coords: Vector2i = Vector2i(tile_id, 0)
		atlas.create_tile(coords)
		if _is_solid(tile_id):
			var data: TileData = atlas.get_tile_data(coords, 0)
			data.set_collision_polygons_count(0, 1)
			data.set_collision_polygon_points(0, 0, PackedVector2Array([
				Vector2(-8, -8), Vector2(8, -8),
				Vector2(8, 8), Vector2(-8, 8)
			]))

	blocks.tile_set = tiles
	background.tile_set = tiles
	background.collision_enabled = false
	background.z_index = -1
	background.modulate = Color(0.37, 0.38, 0.51, 1.0)
	blocks.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return true


func _is_solid(tile_id: int) -> bool:
	return (tile_id != LEAVES and tile_id != DEAD_LEAVES
		and tile_id != MUSHROOM and tile_id != VINE and tile_id != LANTERN
		and tile_id != SKULL)


func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	var cell: Vector2i = blocks.local_to_map(blocks.to_local(player.global_position))
	if _chunk_of(cell) != player_chunk:
		_update_chunks()


func _chunk_of(cell: Vector2i) -> Vector2i:
	# floori preserves negative chunk coordinates correctly.
	return Vector2i(floori(float(cell.x) / CHUNK_SIZE), floori(float(cell.y) / CHUNK_SIZE))


func _base_surface_height(x: int) -> int:
	return 11 + roundi(height_noise.get_noise_1d(float(x)) * 8.0
		+ detail_noise.get_noise_1d(float(x)) * 2.0)


func _surface_height(x: int) -> int:
	if height_cache.has(x):
		return int(height_cache[x])
	var h: int = _base_surface_height(x)
	var dist: int = absi(x)
	if dist <= CASTLE_FLAT_RADIUS:
		h = _base_surface_height(0)
	elif dist < CASTLE_BLEND_RADIUS:
		var mix: float = float(dist - CASTLE_FLAT_RADIUS) / float(CASTLE_BLEND_RADIUS - CASTLE_FLAT_RADIUS)
		h = roundi(lerpf(float(_base_surface_height(0)), float(h), mix))
	# Level the ground beneath each house and blend it into natural terrain.
	var house: Dictionary = _house_near_x(x, HOUSE_BLEND)
	if not house.is_empty():
		var distance: int = absi(x - int(house["center"]))
		var footprint: int = int(house["half_width"])
		if distance <= footprint:
			h = int(house["ground"])
		else:
			var t: float = float(distance - footprint) / float(HOUSE_BLEND)
			h = roundi(lerpf(float(house["ground"]), float(h), t))
	height_cache[x] = h
	return h


func _house_data(side: int, index: int) -> Dictionary:
	if index < 0:
		return {}
	var key: String = "%d:%d" % [side, index]
	if house_cache.has(key):
		return house_cache[key]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = world_seed + index * 13757 + (94763 if side > 0 else 31847)
	var center: int = side * (HOUSE_FIRST_CENTER + index * HOUSE_SPACING + rng.randi_range(-2, 2))
	var data: Dictionary = {
		"center": center,
		"half_width": rng.randi_range(5, 7),
		"height": rng.randi_range(6, 8),
		"ground": _base_surface_height(center),
		"style": rng.randi_range(0, 2)
	}
	house_cache[key] = data
	return data


func _house_near_x(x: int, margin: int = 0) -> Dictionary:
	if absi(x) < HOUSE_FIRST_CENTER - 12 - margin:
		return {}
	var side: int = -1 if x < 0 else 1
	var guess: int = maxi(0, floori(float(absi(x) - HOUSE_FIRST_CENTER) / float(HOUSE_SPACING)))
	for index in range(maxi(0, guess - 1), guess + 2):
		var house: Dictionary = _house_data(side, index)
		if absi(x - int(house["center"])) <= int(house["half_width"]) + margin:
			return house
	return {}


func _house_tile(cell: Vector2i) -> int:
	var house: Dictionary = _house_near_x(cell.x)
	if house.is_empty():
		return NO_CASTLE_TILE
	var dx: int = absi(cell.x - int(house["center"]))
	var half: int = int(house["half_width"])
	var ground: int = int(house["ground"])
	var height: int = int(house["height"])
	var style: int = int(house["style"])
	var roof_peak: int = ground - height - 3
	var roof_y: int = roof_peak + floori(float(dx) * 0.52)
	if cell.y < roof_peak or cell.y > ground + 1:
		return NO_CASTLE_TILE
	# Sloped roof and weathered ridge, different material per house.
	if cell.y == roof_y:
		if style == 0:
			return OBSIDIAN if posmod(cell.x, 4) == 0 else RUNE_BRICK
		if style == 1:
			return DEAD_WOOD if posmod(cell.x, 3) else PLANKS
		return CRIMSON_STONE if posmod(cell.x, 3) == 0 else ASH_STONE
	if cell.y < roof_y:
		return AIR
	# Roofline is supported on the sides, with a 3-tile-high open doorway.
	if cell.y >= ground:
		return PLANKS if cell.y == ground else BRICK
	if dx == half and cell.y <= ground - 4:
		return BRICK if style != 1 else DEAD_WOOD
	if dx == half - 1 and cell.y == ground - 5:
		return GLASS
	if dx == half - 2 and cell.y == ground - 4:
		return LANTERN
	if dx == 0 and cell.y == ground - 5:
		return GLASS
	if dx == 2 and cell.y == ground - 2:
		return PLANKS
	return AIR


func _house_back_wall(cell: Vector2i) -> int:
	var house: Dictionary = _house_near_x(cell.x)
	if house.is_empty():
		return AIR
	var ground: int = int(house["ground"])
	if cell.y < ground - int(house["height"]) or cell.y >= ground:
		return AIR
	return PLANKS if int(house["style"]) == 1 else BRICK


func get_surface_height_at(x: int) -> int:
	# Public API for the enemy spawner.
	return _surface_height(x)


func get_tile_id_at(cell: Vector2i) -> int:
	return _tile_for(cell)


func _castle_tile(cell: Vector2i) -> int:
	# Fixed castle at the world's origin, generated identically across chunks.
	# The returned air clears trees and creates walkable halls.
	var x: int = cell.x
	var y: int = cell.y
	var base: int = _surface_height(0)
	if absi(x) > CASTLE_HALF_WIDTH or y < base - 13 or y > base + 2:
		return NO_CASTLE_TILE

	if y >= base:
		return BRICK if y <= base + 2 else NO_CASTLE_TILE

	var tower: bool = (x >= -13 and x <= -10) or (x >= 10 and x <= 13)
	# Passage through BOTH towers and hall, at character height.
	if y >= base - 3:
		return AIR

	if tower:
		if y == base - 13:
			return RUNE_BRICK if (posmod(x, 2) == 0 or absi(x) == 13) else AIR
		if y == base - 12:
			return OBSIDIAN
		if x == -13 or x == -10 or x == 10 or x == 13:
			return BRICK
		if y == base - 8 and (x == -11 or x == 11):
			return GLASS
		if y == base - 5 and (x == -11 or x == 11):
			return LANTERN
		return AIR

	if absi(x) <= 9:
		if y == base - 10:
			return RUNE_BRICK if posmod(x, 3) == 0 else AIR
		if y == base - 9:
			return RUNE_BRICK if posmod(x, 2) == 0 else BRICK
		if y > base - 9:
			if absi(x) == 9:
				return BRICK
			if y == base - 6 and absi(x) <= 1:
				return GLASS
			if y == base - 5 and absi(x) == 6:
				return LANTERN
			if y == base - 4 and absi(x) >= 3 and absi(x) <= 5:
				return PLANKS
		return AIR
	return AIR


func _biome(x: int) -> int:
	var value: float = biome_noise.get_noise_1d(float(x))
	if value > 0.23:
		return BIOME_ASHLANDS
	if value < -0.23:
		return BIOME_BLIGHT
	return BIOME_GLOOMWOOD


func _cell_hash(cell: Vector2i) -> int:
	return posmod((cell.x * 92821) ^ (cell.y * 68917) ^ (world_seed * 131), 100)


func _tree_root(x: int) -> bool:
	if tree_cache.has(x):
		return bool(tree_cache[x])
	# Three-to-four block tall trees, ~40% chance per 26 tiles.
	# Keep the castle courtyard entirely clear.
	if absi(x) <= CASTLE_BLEND_RADIUS or not _house_near_x(x, 4).is_empty():
		tree_cache[x] = false
		return false
	var segment: int = floori(float(x) / 26.0)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = world_seed + segment * 3797 + 8941
	var candidate: int = segment * 26 + rng.randi_range(7, 19)
	var valid: bool = candidate == x and rng.randf() < 0.40
	if valid:
		var ground: int = _surface_height(x)
		valid = (abs(_surface_height(x - 1) - ground) <= 1
			and abs(_surface_height(x + 1) - ground) <= 1)
	tree_cache[x] = valid
	return valid


func _tree_height(x: int) -> int:
	return 3 + posmod(x * 11 + world_seed, 2)


func _tree_tile(cell: Vector2i) -> int:
	# Look on both sides: canopies remain seamless across chunk borders.
	for root_x in range(cell.x - 2, cell.x + 3):
		if not _tree_root(root_x):
			continue
		var top: int = _surface_height(root_x) - _tree_height(root_x)
		var withered: bool = _biome(root_x) != BIOME_GLOOMWOOD
		if cell.x == root_x and cell.y >= top and cell.y < _surface_height(root_x):
			return DEAD_WOOD if withered else WOOD
		var dx: int = abs(cell.x - root_x)
		var dy: int = abs(cell.y - (top - 1))
		if (dy <= 1 and dx <= 1) or (dy == 0 and dx <= 2):
			return DEAD_LEAVES if withered else LEAVES
	return AIR


func _natural_tile(cell: Vector2i) -> int:
	var house_id: int = _house_tile(cell)
	if house_id != NO_CASTLE_TILE:
		return house_id
	var castle_id: int = _castle_tile(cell)
	if castle_id != NO_CASTLE_TILE:
		return castle_id
	var ground: int = _surface_height(cell.x)
	var biome: int = _biome(cell.x)
	if cell.y < ground:
		if cell.y < ground - 20:
			return AIR
		var tree: int = _tree_tile(cell)
		if tree != AIR:
			return tree
		if cell.y == ground - 1 and _cell_hash(cell) < 4:
			return MUSHROOM
		return AIR

	if cell.y == ground:
		match biome:
			BIOME_ASHLANDS: return AUTUMN_GRASS
			BIOME_BLIGHT: return PURPLE_GRASS
		return GRASS

	var depth: int = cell.y - ground
	if depth <= 5:
		if biome == BIOME_ASHLANDS:
			return RED_DIRT
		if biome == BIOME_BLIGHT:
			return LIGHT_DIRT
		return ROOT_DIRT if _cell_hash(cell) < 16 else DIRT

	var x: float = float(cell.x)
	var y: float = float(cell.y)
	if depth >= 7:
		var cave_value: float = cave_noise.get_noise_2d(x, y)
		if absf(cave_value) < 0.090 or cave_value > 0.49:
			return AIR

	if depth >= 32 and gold_noise.get_noise_2d(x, y) > 0.53:
		return GOLD
	if depth >= 17 and iron_noise.get_noise_2d(x, y) > 0.50:
		return IRON
	if depth >= 7 and copper_noise.get_noise_2d(x, y) > 0.46:
		return COPPER

	if depth <= 9:
		if biome == BIOME_ASHLANDS:
			return RED_DIRT
		if biome == BIOME_BLIGHT:
			return LIGHT_DIRT
		return DIRT

	var choice: int = _cell_hash(cell)
	if biome == BIOME_ASHLANDS:
		return ASH_STONE if choice < 46 else (CRIMSON_STONE if choice < 51 else STONE)
	if biome == BIOME_BLIGHT:
		return GLOOMSTONE if choice < 48 else (ARCANE_CRYSTAL if choice < 50 else STONE)
	if depth >= 35 and choice < 20:
		return OBSIDIAN
	if choice < 9:
		return CRACKED_STONE
	if choice < 14:
		return MOSS_STONE
	if choice < 17:
		return BONE_STONE
	return STONE


func _edit_key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]


func _tile_for(cell: Vector2i) -> int:
	var key: String = _edit_key(cell)
	if edits.has(key):
		return int(edits[key])
	return _natural_tile(cell)


func _update_chunks() -> void:
	var cell: Vector2i = blocks.local_to_map(blocks.to_local(player.global_position))
	var center: Vector2i = _chunk_of(cell)
	player_chunk = center
	height_cache.clear()
	tree_cache.clear()
	# House cache holds only deterministic metadata, never player edits.
	house_cache.clear()

	for chunk in loaded_chunks.keys():
		if abs(chunk.x - center.x) > load_radius or abs(chunk.y - center.y) > load_radius:
			_unload_chunk(chunk)

	for cy in range(center.y - load_radius, center.y + load_radius + 1):
		for cx in range(center.x - load_radius, center.x + load_radius + 1):
			var chunk: Vector2i = Vector2i(cx, cy)
			if not loaded_chunks.has(chunk):
				_generate_chunk(chunk)


func _generate_chunk(chunk: Vector2i) -> void:
	var x0: int = chunk.x * CHUNK_SIZE
	var y0: int = chunk.y * CHUNK_SIZE
	for y in range(y0, y0 + CHUNK_SIZE):
		for x in range(x0, x0 + CHUNK_SIZE):
			var cell: Vector2i = Vector2i(x, y)
			var depth: int = y - _surface_height(x)
			if depth > 0:
				var wall: int = STONE
				if depth <= 10:
					match _biome(x):
						BIOME_ASHLANDS: wall = RED_DIRT
						BIOME_BLIGHT: wall = LIGHT_DIRT
						_: wall = DIRT
				background.set_cell(cell, 0, Vector2i(wall, 0))
			var house_wall: int = _house_back_wall(cell)
			if house_wall != AIR:
				background.set_cell(cell, 0, Vector2i(house_wall, 0))
			var castle_floor: int = _surface_height(0)
			if absi(x) <= CASTLE_HALF_WIDTH and y >= castle_floor - 12 and y < castle_floor:
				background.set_cell(cell, 0, Vector2i(BRICK, 0))
			var tile_id: int = _tile_for(cell)
			if tile_id >= 0 and tile_id < TILE_COUNT:
				blocks.set_cell(cell, 0, Vector2i(tile_id, 0))
	loaded_chunks[chunk] = true


func _unload_chunk(chunk: Vector2i) -> void:
	var x0: int = chunk.x * CHUNK_SIZE
	var y0: int = chunk.y * CHUNK_SIZE
	for y in range(y0, y0 + CHUNK_SIZE):
		for x in range(x0, x0 + CHUNK_SIZE):
			var cell: Vector2i = Vector2i(x, y)
			blocks.erase_cell(cell)
			background.erase_cell(cell)
	loaded_chunks.erase(chunk)


func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(player):
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.pressed:
			if mouse_event.button_index == MOUSE_BUTTON_LEFT:
				if player.has_method("request_mine"):
					player.call("request_mine", get_global_mouse_position())
				else:
					mine_at(get_global_mouse_position(), player.global_position)
			elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
				place_at(get_global_mouse_position(), player.global_position)
	elif event is InputEventKey:
		var key_event: InputEventKey = event
		if key_event.pressed and not key_event.echo:
			match key_event.keycode:
				KEY_1: _set_selected_tile(DIRT)
				KEY_2: _set_selected_tile(STONE)
				KEY_3: _set_selected_tile(WOOD)
				KEY_4: _set_selected_tile(BRICK)
				KEY_5: _set_selected_tile(PLANKS)
				KEY_6: _set_selected_tile(GLASS)
				KEY_7: _set_selected_tile(SAND)
				KEY_8: _set_selected_tile(RUNE_BRICK)
				KEY_9: _set_selected_tile(OBSIDIAN)


func _set_selected_tile(tile_id: int) -> void:
	selected_tile = tile_id
	selected_block_changed.emit(get_selected_block_text())


func can_mine_at(mouse_global: Vector2, player_global: Vector2) -> bool:
	if mouse_global.distance_to(player_global) > mining_distance:
		return false
	var cell: Vector2i = blocks.local_to_map(blocks.to_local(mouse_global))
	return blocks.get_cell_source_id(cell) != -1


func mine_at(mouse_global: Vector2, player_global: Vector2) -> void:
	if not can_mine_at(mouse_global, player_global):
		return
	var cell: Vector2i = blocks.local_to_map(blocks.to_local(mouse_global))
	var tile_id: int = blocks.get_cell_atlas_coords(cell).x
	match tile_id:
		COPPER: resources["copper"] += 1
		IRON: resources["iron"] += 1
		GOLD: resources["gold"] += 1
	edits[_edit_key(cell)] = AIR
	blocks.erase_cell(cell)
	_save_game()
	resources_changed.emit()


func place_at(mouse_global: Vector2, player_global: Vector2) -> void:
	if mouse_global.distance_to(player_global) > mining_distance:
		return
	var cell: Vector2i = blocks.local_to_map(blocks.to_local(mouse_global))
	if blocks.get_cell_source_id(cell) != -1:
		return
	# Check tile center (not cursor) to prevent blocks forming in the player.
	var tile_center: Vector2 = blocks.to_global(blocks.map_to_local(cell))
	if absf(tile_center.x - player_global.x) < 17.0 and absf(tile_center.y - player_global.y) < 29.0:
		return
	edits[_edit_key(cell)] = selected_tile
	blocks.set_cell(cell, 0, Vector2i(selected_tile, 0))
	_save_game()


func get_resource_text() -> String:
	return "Медь: %d   Железо: %d   Золото: %d" % [
		int(resources["copper"]), int(resources["iron"]), int(resources["gold"])
	]


func get_selected_block_text() -> String:
	match selected_tile:
		DIRT: return "Тёмная земля"
		STONE: return "Сланец"
		WOOD: return "Древесина"
		BRICK: return "Кирпич склепа"
		PLANKS: return "Старые доски"
		GLASS: return "Витраж"
		SAND: return "Пепельный песок"
		RUNE_BRICK: return "Рунический камень"
		OBSIDIAN: return "Обсидиан"
	return "Блок"


func _save_game() -> void:
	# All saves belong in the writable user:// directory, NEVER in assets/.
	var data: Dictionary = {
		"seed": world_seed,
		"edits": edits,
		"resources": resources
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("World save failed: " + SAVE_PATH)
		return
	file.store_string(JSON.stringify(data))
	file.close()


func _load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not parsed is Dictionary:
		push_warning("Invalid save JSON, creating a new world.")
		return
	var saved: Dictionary = parsed
	if int(saved.get("seed", -1)) != world_seed:
		return
	if saved.get("edits") is Dictionary:
		edits = saved["edits"]
	if saved.get("resources") is Dictionary:
		var stored: Dictionary = saved["resources"]
		for key in resources.keys():
			resources[key] = int(stored.get(key, 0))

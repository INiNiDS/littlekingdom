extends Node2D

@onready var player = $player
@onready var citizen = $Citizen
@onready var layer = $TileMapLayer
@onready var crop_take = $CropTake
@onready var hud = $HUD

const CROP = preload("res://scenes/crop.tscn")
var citizen_go_for_player = false 
const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const GRAVITY = 980.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("player_position: " + str(player.global_position))
	print("citizen position: " + str(citizen.global_position))


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	
	if citizen_go_for_player:
		var direction = (player.position - citizen.position).normalized()
		print("direction: " + str(direction))
		citizen.citizen_go_for_player(direction)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_interact"):
		if citizen.player_in_zone:
			if citizen_go_for_player:
				citizen_go_for_player = false
				citizen.dont_go_for_player()
			else:
				citizen_go_for_player = true
	elif event.is_action_pressed("ui_spawn") and player.player_crops > 0:
		player.player_crops -= 1
		print("here: " + hud.name)
		hud.remove_crop()
		
		var instance = CROP.instantiate()
		get_tree().current_scene.add_child(instance)
		print("pshenicha!")
		instance.global_position = player.global_position - Vector2(0, 90)

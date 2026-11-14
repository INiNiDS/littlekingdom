extends Node2D

@onready var player = $player
@onready var citizen = $Enemy
@onready var layer = $TileMapLayer

var citizen_go_for_player = false 
const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const GRAVITY = 980.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:

	if citizen_go_for_player:
		var direction = (player.position - citizen.position).normalized()

		citizen.citizen_go_for_player(direction, delta)

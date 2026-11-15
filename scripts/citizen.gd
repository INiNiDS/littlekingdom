extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0
@onready var animation = $AnimatedSprite2D
@export var player_in_zone = false
@onready var player = $"../Player"
var goint_to_seed = false
var gl_seed_position = Vector2.ZERO
var citizen_go_for_player_var = false
var player_direction = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	if citizen_go_for_player_var:
		if abs(player_direction.x) >= 0.52:
			animation.play("run")
		else:
			animation.play("idle")

		if player_direction.x:
			velocity.x = player_direction.x * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
		
		if player_direction.x != 0:
			animation.flip_h = player_direction.x < 0
		else:
			animation.flip_h = player_direction.x < 0
		if player_direction.y <= 0.4 and is_on_floor():
			velocity.y = JUMP_VELOCITY
	elif goint_to_seed:
		var direction = (gl_seed_position - position).normalized()
		
		if abs(direction.x) >= 0.52:
			animation.play("run")
		else:
			animation.play("idle")
			goint_to_seed = false

		if direction.x:
			velocity.x = direction.x * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
		
		if direction.x != 0:
			animation.flip_h = direction.x < 0
		else:
			animation.flip_h = direction.x < 0
		

	move_and_slide()

func _ready() -> void:
	animation.play("idle")

func citizen_go_for_player(direction_fr: Vector2) -> void:
	player_direction = direction_fr
	citizen_go_for_player_var = true

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_in_zone = true


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_in_zone = false
		
func go_to_seed(seed_position: Vector2) -> void:
	goint_to_seed = true
	gl_seed_position = seed_position
	
func dont_go_for_player() -> void:
	citizen_go_for_player_var = false

func going_to_seed() -> bool:
	return goint_to_seed

func add_pschenicha() -> void:
	player.add_pschenicha()

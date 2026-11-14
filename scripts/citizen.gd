extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0
@onready var animation = $AnimatedSprite2D
@export var player_in_zone = false

func _ready() -> void:
	animation.play("idle")

func citizen_go_for_player(direction: Vector2, delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	print(direction.y)
	if abs(direction.x) >= 0.52:
		animation.play("run")
	else:
		animation.play("idle")

	if direction.x:
		velocity.x = direction.x * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	
	if direction.x != 0:
		animation.flip_h = direction.x < 0
	else:
		animation.flip_h = direction.x < 0
	
	if direction.y <= 0.4:
		velocity.y = JUMP_VELOCITY

	move_and_slide()


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_in_zone = true


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_in_zone = false

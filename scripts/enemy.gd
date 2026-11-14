extends CharacterBody2D

@export var speed: float = 120.0
@export var gravity: float = 980.0
@export var stop_distance: float = 30.0

var player: CharacterBody2D = null

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection: Area2D = $Area2D

func _ready():
	detection.body_entered.connect(_on_body_entered)
	detection.body_exited.connect(_on_body_exited)

	anim.play("default")


func _physics_process(delta):

	# Гравитация
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0

	# Если игрок обнаружен
	if is_instance_valid(player):

		var distance = global_position.distance_to(
		player.global_position
		)

		var direction = sign(
		player.global_position.x - global_position.x
		)

		if distance > stop_distance:
			velocity.x = direction * speed

		if direction != 0:
			anim.flip_h = direction < 0

			anim.play("run")
		else:
			velocity.x = 0
			anim.play("default")

	else:
		player = null
		velocity.x = 0
		anim.play("default")

	move_and_slide()


func _on_body_entered(body):
	if body.is_in_group("player"):
		player = body
		print("Игрок найден!")


func _on_body_exited(body):
	if body == player:
		player = null
		print("Игрок потерян!")

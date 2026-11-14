extends CharacterBody2D

@export var speed: float = 120.0
@export var gravity: float = 980.0
@export var stop_distance: float = 30.0
@export var attack_distance: float = 40.0
@export var damage: int = 10
@export var attack_cooldown: float = 1.0

var player: CharacterBody2D = null

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection: Area2D = $Area2D
var attacking: bool = false
var can_attack: bool = true

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

		if attacking:
			velocity.x = 0

		elif distance <= attack_distance:
			velocity.x = 0

		if can_attack:
			attack()


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
	check_player_collision()







func attack():
	attacking = true
	can_attack = false
	velocity.x = 0

	anim.play("attack")

	# Наносим урон
	if is_instance_valid(player):
		if player.has_method("take_damage"):
			player.take_damage(damage)

		await get_tree().create_timer(attack_cooldown).timeout
		can_attack = true



func _on_body_entered(body):
	if body.is_in_group("player"):
		player = body
		print("Игрок найден!")


func _on_body_exited(body):
	if body == player:
		player = null
		print("Игрок потерян!")
		
func check_player_collision():
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var body = collision.get_collider()

		if body.is_in_group("player"):
			if can_attack and not attacking:
				attack()

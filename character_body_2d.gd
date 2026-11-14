extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const GRAVITY = 980.0

@onready var anim = $AnimatedSprite2D


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("ui_left", "ui_right")
	
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		
	if not is_on_floor():
		if velocity.y < 0:
			anim.play("jump")
			anim.flip_h = direction < 0
		else:
			anim.play("fall")
			anim.flip_h = direction < 0
	elif direction != 0:
		anim.play("run")
		anim.flip_h = direction < 0
	else:
		anim.play("default")
		anim.flip_h = direction < 0
	

	move_and_slide()

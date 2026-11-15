extends Node2D

var time = 0 # in seconds
const TIME_POLOVINA = 480
const TIME_FULL = 960
var can_take_crop = false
var state = 0
@onready var crop_start = $CropStart
@onready var crop_polovina = $CropPolovina
@onready var crop_full = $Crop
@onready var timer = $Timer
var nn_body = Node2D.new()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	crop_full.hide()
	crop_polovina.hide()
	crop_start.show()
	timer.start()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if can_take_crop and is_full():
		print("pshenicha")
		nn_body.add_pshenicha()
		take()
		
	if time >= TIME_FULL:
			crop_start.hide()
			crop_polovina.hide()
			crop_full.show()
			state = 2
	elif time >= TIME_POLOVINA:
		crop_start.hide()
		crop_full.hide()
		crop_polovina.show()
		state = 1



func is_full() -> bool:
	if state == 2:
		return true
	else:
		return false

func take() -> void:
	queue_free()

func _on_timer_timeout() -> void:
	time += 1 


func _on_area_2d_body_entered(body: Node2D) -> void:
	print("name: " + body.name + " is_full " + str(is_full()))
	if body.has_method("go_to_seed") and body.has_method("going_to_seed"):
		if not body.going_to_seed():
			body.go_to_seed(position)
	
	if body.has_method("add_pshenicha"):
		can_take_crop = true
		nn_body = body

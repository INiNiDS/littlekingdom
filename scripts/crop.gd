extends Node2D

var time = 0 # in seconds
const TIME_POLOVINA = 480
const TIME_FULL = 960

@onready var crop_start = $CropStart
@onready var crop_polovina = $CropPolovina
@onready var crop_full = $Crop
@onready var timer = $Timer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	crop_full.hide()
	crop_polovina.hide()
	crop_start.show()
	timer.start()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	print(time)
	if time >= TIME_FULL:
			crop_start.hide()
			crop_polovina.hide()
			crop_full.show()
	elif time >= TIME_POLOVINA:
		crop_start.hide()
		crop_full.hide()
		crop_polovina.show()


func _on_timer_timeout() -> void:
	time += 1 

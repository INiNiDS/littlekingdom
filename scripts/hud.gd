extends CanvasLayer

var pschenicha = 0
var crop = 0
@onready var label = $MarginContainer/PanelContainer/HBoxContainer/Label

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	update_label()

func update_label() -> void:
	label.text = "Pshenicha " + str(pschenicha) + "\nCrop " + str(crop)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func add_pshenicha() -> void:
	pschenicha += 1
	update_label()

func add_crop() -> void:
	crop += 1
	update_label()
	
func remove_crop() -> void:
	crop -= 1
	update_label()
	
func remove_pshenicha() -> void:
	pschenicha -= 1
	update_label()
	

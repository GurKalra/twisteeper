extends CanvasLayer

signal restart

func _ready():
	# Connect the restart button if it exists
	if has_node("RestartButton"):
		$RestartButton.pressed.connect(onrestart_button_pressed)
	# Alternative path if your button is nested differently
	elif has_node("Panel/RestartButton"):
		$Panel/RestartButton.pressed.connect(onrestart_button_pressed)
	# Add more paths as needed based on your scene structure

func onrestart_button_pressed():
	print("Restart button signal emitted!")  # Debug print
	restart.emit()

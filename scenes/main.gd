extends Node

# Game variables
const TOTAL_MINES : int = 20
var time_elapsed : float
var remaining_mines : int
var first_click : bool

# Twist mechanic variables
var click_count : int = 0
const CLICKS_PER_TWIST : int = 8

# Called when the node enters the scene tree for the first time.
func _ready():
	# Connect the signals from TileMap
	$TileMap.end_game.connect(ontile_map_end_game)
	$TileMap.game_won.connect(ontile_map_game_won)
	$TileMap.flag_placed.connect(ontile_map_flag_placed)
	$TileMap.flag_removed.connect(ontile_map_flag_removed)
	
	# Connect the GameOver restart signal
	$GameOver.restart.connect(ongame_over_restart)
	
	# IMPORTANT: Connect the restart button signal
	# Make sure your GameOver scene has a Button node called "RestartButton"
	if $GameOver.has_node("RestartButton"):
		$GameOver.get_node("RestartButton").pressed.connect(ongame_over_restart)
	
	new_game()

func new_game():
	first_click = true
	time_elapsed = 0
	remaining_mines = TOTAL_MINES
	click_count = 0  # Reset click counter
	$TileMap.new_game()
	$GameOver.hide()
	get_tree().paused = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# Only update time if game is not paused
	if not get_tree().paused:
		time_elapsed += delta
	
	$HUD.get_node("Stopwatch").text = str(int(time_elapsed))
	
	# Display remaining flags instead of remaining mines
	var remaining_flags = $TileMap.get_remaining_flags()
	$HUD.get_node("RemainingMines").text = "Flags: " + str(remaining_flags)
	
	# Display click counter
	$HUD.get_node("ClickCounter").text = "Clicks: " + str(click_count) + "/" + str(CLICKS_PER_TWIST)

func increment_click_count():
	click_count += 1
	print("Click count: ", click_count)  # Debug print
	if click_count >= CLICKS_PER_TWIST:
		print("Triggering board twist!")  # Debug print
		click_count = 0
		$TileMap.twist_board()

func end_game(result):
	get_tree().paused = true
	$GameOver.show()
	if result == 1:
		$GameOver.get_node("Label").text = "YOU WIN!"
	else:
		$GameOver.get_node("Label").text = "BOOM!"

# These functions are now mainly for tracking, since flag limiting is handled in TileMap
func ontile_map_flag_placed():
	pass

func ontile_map_flag_removed():
	pass

func ontile_map_end_game():
	end_game(-1)

func ontile_map_game_won():
	end_game(1)

func ongame_over_restart():
	print("Restart button pressed!")  # Debug print
	new_game()

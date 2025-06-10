extends Node

# Game variables
const TOTAL_MINES : int = 20
var time_elapsed : float
var remaining_mines : int
var first_click : bool

# Twist mechanic variables
var click_count : int = 0
const CLICKS_PER_TWIST : int = 8

# Screen shake variables
var shake_intensity : float = 0.0
var shake_duration : float = 0.0
var original_camera_position : Vector2

# Audio nodes references
@onready var click_sound = $ClickSound
@onready var boom_sound = $BoomSound
@onready var win_sound = $WinSound
@onready var flag_place_sound = $FlagPlaceSound
@onready var flag_remove_sound = $FlagRemoveSound
@onready var twist_sound = $TwistSound

var camera: Camera2D
@export var explosion_particles_scene: PackedScene 

# Called when the node enters the scene tree for the first time.
func _ready():
	# Connect the signals from TileMap
	$TileMap.end_game.connect(ontile_map_end_game)
	$TileMap.game_won.connect(ontile_map_game_won)
	$TileMap.flag_placed.connect(ontile_map_flag_placed)
	$TileMap.flag_removed.connect(ontile_map_flag_removed)
	$TileMap.cell_revealed.connect(ontile_map_cell_revealed)
	$TileMap.board_twisted.connect(ontile_map_board_twisted)
	
	# Move TileMap up to avoid HUD overlap - SIMPLE FIX
	$TileMap.position = Vector2(0, -50)
	
	# Create and position camera properly
	camera = Camera2D.new()
	camera.enabled = true
	add_child(camera)
	
	# Position camera to center the game area
	var game_width = 15 * 50  # COLS * CELL_SIZE
	var game_height = 14 * 50  # ROWS * CELL_SIZE
	camera.position = Vector2(game_width / 2, (game_height / 2) - 25)
	original_camera_position = camera.position
	
	# Make camera current
	camera.make_current()
	
	# Connect the GameOver restart signal
	$GameOver.restart.connect(ongame_over_restart)
	
	# IMPORTANT: Connect the restart button signal
	if $GameOver.has_node("RestartButton"):
		$GameOver.get_node("RestartButton").pressed.connect(ongame_over_restart)
	
	new_game()

func new_game():
	first_click = true
	time_elapsed = 0
	remaining_mines = TOTAL_MINES
	click_count = 0
	$TileMap.new_game()
	$GameOver.hide()
	get_tree().paused = false
	
	# Reset camera shake
	shake_intensity = 0.0
	shake_duration = 0.0
	camera.position = original_camera_position

# Screen shake function
func add_screen_shake(intensity: float, duration: float):
	shake_intensity = intensity
	shake_duration = duration

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# Only update time if game is not paused
	if not get_tree().paused:
		time_elapsed += delta
	
	# Handle screen shake
	if shake_duration > 0:
		shake_duration -= delta
		if shake_duration <= 0:
			# Reset camera to original position
			camera.position = original_camera_position
			shake_intensity = 0.0
		else:
			# Apply shake
			var shake_offset = Vector2(
				randf_range(-shake_intensity, shake_intensity),
				randf_range(-shake_intensity, shake_intensity)
			)
			camera.position = original_camera_position + shake_offset
	
	$HUD.get_node("Stopwatch").text = str(int(time_elapsed))
	
	# Display remaining flags instead of remaining mines
	var remaining_flags = $TileMap.get_remaining_flags()
	$HUD.get_node("RemainingMines").text = "Flags: " + str(remaining_flags)
	
	# Display click counter
	$HUD.get_node("ClickCounter").text = str(click_count) + "/" + str(CLICKS_PER_TWIST)

func increment_click_count():
	click_count += 1
	print("Click count: ", click_count)
	if click_count >= CLICKS_PER_TWIST:
		print("Triggering board twist!")
		click_count = 0
		$TileMap.twist_board()
	
func end_game(result):
	get_tree().paused = true
	$GameOver.show()
	if result == 1:
		$GameOver.get_node("Label").text = "YOU WIN!"
		win_sound.play()
	else:
		$GameOver.get_node("Label").text = "BOOM!"
	
func create_explosion_at_mine(mine_position: Vector2i):
	if explosion_particles_scene:
		var explosion = explosion_particles_scene.instantiate()
		add_child(explosion)
		# Convert grid position to world position, accounting for TileMap position
		var tilemap_pos = $TileMap.position
		explosion.position = Vector2(
			tilemap_pos.x + mine_position.x * 50 + 25, 
			tilemap_pos.y + mine_position.y * 50 + 25
		)
		explosion.explode()

# Sound effect callbacks
func ontile_map_cell_revealed():
	click_sound.play()

func ontile_map_flag_placed():
	flag_place_sound.play()

func ontile_map_flag_removed():
	flag_remove_sound.play()

func ontile_map_board_twisted():
	twist_sound.play()
	# Add screen shake for board twist
	add_screen_shake(8.0, 0.5)

func ontile_map_end_game():
	print("Mine hit! Playing boom sound...")
	boom_sound.play()
	
	# Add strong screen shake for explosion
	add_screen_shake(15.0, 1.0)
	
	# Create explosion particles at all mine locations
	for mine_pos in $TileMap.mine_coords:
		create_explosion_at_mine(mine_pos)
	
	await boom_sound.finished
	end_game(-1)

func ontile_map_game_won():
	# Add celebratory screen shake
	add_screen_shake(5.0, 0.3)
	end_game(1)

func ongame_over_restart():
	print("Restart button pressed!")
	new_game()

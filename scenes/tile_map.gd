extends TileMap

# Helper function to count surrounding mines
func count_surrounding_mines(cell):
	var count = 0
	for neighbor in get_all_surrounding_cells(cell):
		if is_mine(neighbor):
			count += 1
	return count

signal end_game
signal game_won
signal flag_placed
signal flag_removed
signal cell_revealed
signal board_twisted

# Grid variables
const ROWS : int = 14
const COLS : int = 15
const CELL_SIZE : int = 50
const TOTAL_MINES : int = 20

# Tilemap variables
var tile_id : int = 0

# Layer variables - FIXED ORDER: bottom to top
var mine_layer : int = 0      # Bottom layer (hidden mines)
var number_layer : int = 1    # Numbers (revealed)
var grass_layer : int = 2     # Grass cover (middle)
var flag_layer : int = 3      # Flags (above grass)
var hover_layer : int = 4     # Hover effect (top)

# Atlas coordinates
var mine_atlas := Vector2i(4, 0)
var flag_atlas := Vector2i(5, 0)
var hover_atlas := Vector2i(6, 0)
var number_atlas : Array = generate_number_atlas()

# Array to store mine coordinates
var mine_coords := []

# Toggle variable to scan nearby mines
var scanning := false

# Flag limiting variables
const MAX_FLAGS : int = 15
var current_flags : int = 0

func generate_number_atlas():
	var a := []
	for i in range(8):
		a.append(Vector2i(i, 1))
	return a

# Called when the node enters the scene tree for the first time.
func _ready():
	new_game()
	
# Reset game
func new_game():
	clear_all_layers()
	mine_coords.clear()
	current_flags = 0
	generate_mines()
	generate_numbers()
	generate_grass()

# Clear all layers properly
func clear_all_layers():
	for layer in range(5):  # Clear all 5 layers
		clear_layer(layer)

# Simple instant twist function - NO ANIMATION
func twist_board():
	print("Starting instant board twist! Flagged positions will stay frozen.")
	
	var flagged_positions = get_used_cells(flag_layer)
	print("Frozen positions: ", flagged_positions)
	
	# Play twist sound
	board_twisted.emit()
	
	# Do the actual board transformation instantly
	perform_board_twist_logic(flagged_positions)
	
	print("Instant board twist complete!")

func perform_board_twist_logic(flagged_positions):
	# Store current state of ALL layers except flags
	var mine_data = get_layer_data_excluding_flags(mine_layer, flagged_positions)
	var grass_data = get_layer_data_excluding_flags(grass_layer, flagged_positions)
	
	# Clear layers except flags
	clear_layer_excluding_flags(mine_layer, flagged_positions)
	clear_layer_excluding_flags(number_layer, flagged_positions)
	clear_layer_excluding_flags(grass_layer, flagged_positions)
	
	# Rotate and place back data
	rotate_layer_data_avoiding_flags(mine_data, mine_layer, flagged_positions)
	rotate_layer_data_avoiding_flags(grass_data, grass_layer, flagged_positions)
	
	# Update mine coordinates
	update_mine_coords_after_rotation()
	
	# Regenerate numbers based on new mine positions
	generate_numbers_avoiding_flags(flagged_positions)

func get_layer_data_excluding_flags(layer_index, flagged_positions):
	var data = {}
	for cell in get_used_cells(layer_index):
		# Only include cells that are NOT flagged
		if not flagged_positions.has(cell):
			var atlas_coords = get_cell_atlas_coords(layer_index, cell)
			data[cell] = atlas_coords
	return data

func clear_layer_excluding_flags(layer_index, flagged_positions):
	for cell in get_used_cells(layer_index):
		# Only clear cells that are NOT flagged
		if not flagged_positions.has(cell):
			erase_cell(layer_index, cell)

func rotate_layer_data_avoiding_flags(data, layer_index, flagged_positions):
	for old_pos in data.keys():
		var new_pos = rotate_coordinates_90_clockwise(old_pos)
		var atlas_coords = data[old_pos]
		
		# If the new position is flagged, find an alternative position
		if flagged_positions.has(new_pos):
			var alternative = find_alternative_position(new_pos, flagged_positions)
			new_pos = alternative
		
		set_cell(layer_index, new_pos, tile_id, atlas_coords)

func find_alternative_position(blocked_pos, flagged_positions):
	# PHASE 1: Try to find a nearby unflagged position in expanding circles
	for radius in range(1, max(ROWS, COLS)):
		for y_offset in range(-radius, radius + 1):
			for x_offset in range(-radius, radius + 1):
				# Only check positions on the edge of current radius
				if abs(x_offset) == radius or abs(y_offset) == radius:
					var candidate = blocked_pos + Vector2i(x_offset, y_offset)
					# Check if position is within bounds and not flagged
					if (candidate.x >= 0 and candidate.x < COLS and 
						candidate.y >= 0 and candidate.y < ROWS and 
						not flagged_positions.has(candidate)):
						return candidate
	
	# PHASE 2: Fallback - find any available position
	for y in range(ROWS):
		for x in range(COLS):
			var candidate = Vector2i(x, y)
			if not flagged_positions.has(candidate):
				return candidate
	
	# PHASE 3: Ultimate fallback (shouldn't happen unless entire board is flagged)
	return blocked_pos

func rotate_coordinates_90_clockwise(pos):
	# For 90 degree clockwise rotation: (x, y) -> (ROWS - 1 - y, x)
	# Fixed coordinate system for proper rotation within bounds
	var new_x = ROWS - 1 - pos.y
	var new_y = pos.x
	
	# Clamp coordinates to ensure they stay within bounds
	new_x = clamp(new_x, 0, COLS - 1)
	new_y = clamp(new_y, 0, ROWS - 1)
		
	return Vector2i(new_x, new_y)

func update_mine_coords_after_rotation():
	# Clear the old mine_coords array and rebuild it from scratch
	mine_coords.clear()
	
	# Get all cells that have mines on the mine_layer and rebuild the array
	for cell in get_used_cells(mine_layer):
		if get_cell_source_id(mine_layer, cell) != -1:
			mine_coords.append(cell)

func generate_numbers_avoiding_flags(flagged_positions):
	# Clear previous numbers but don't touch flagged positions
	for cell in get_used_cells(number_layer):
		if not flagged_positions.has(cell):
			erase_cell(number_layer, cell)
	
	# Generate numbers for all cells that aren't flagged, aren't mines, and aren't grass (covered)
	for y in range(ROWS):
		for x in range(COLS):
			var cell = Vector2i(x, y)
			# Skip if it's a mine, flagged, or still has grass (covered)
			if not is_mine(cell) and not flagged_positions.has(cell) and not is_grass(cell):
				var mine_count = count_surrounding_mines(cell)
				if mine_count > 0:
					set_cell(number_layer, cell, tile_id, number_atlas[mine_count - 1])
	
func generate_mines():
	for i in range(TOTAL_MINES):
		var mine_pos = Vector2i(randi_range(0, COLS - 1), randi_range(0, ROWS - 1))
		while mine_coords.has(mine_pos):
			mine_pos = Vector2i(randi_range(0, COLS - 1), randi_range(0, ROWS - 1))
		mine_coords.append(mine_pos)
		# Add mine to tilemap
		set_cell(mine_layer, mine_pos, tile_id, mine_atlas)

func generate_numbers():
	# Clear previous numbers in case the mine was moved
	clear_layer(number_layer)
	for i in get_empty_cells():
		var mine_count : int = 0
		for j in get_all_surrounding_cells(i):
			# Check if there is a mine in the cell
			if is_mine(j):
				mine_count += 1
		# Once counted, add the number cell to the tilemap
		if mine_count > 0:
			set_cell(number_layer, i, tile_id, number_atlas[mine_count - 1])

func generate_grass():
	# Clear grass layer first
	clear_layer(grass_layer)
	for y in range(ROWS):
		for x in range(COLS):
			var toggle = ((x + y) % 2)
			set_cell(grass_layer, Vector2i(x, y), tile_id, Vector2i(3 - toggle, 0))

func get_empty_cells():
	var empty_cells := []
	# Iterate over grid
	for y in range(ROWS):
		for x in range(COLS):
			# Check if the cell is empty and add it to the array
			if not is_mine(Vector2i(x, y)):
				empty_cells.append(Vector2i(x, y))
	return empty_cells

func get_all_surrounding_cells(middle_cell):
	var surrounding_cells := []
	var target_cell
	for y in range(3):
		for x in range(3):
			target_cell = middle_cell + Vector2i(x - 1, y - 1)
			# Skip cell if it is the one in the middle
			if target_cell != middle_cell:
				# Check that the cell is on the grid
				if (target_cell.x >= 0 and target_cell.x <= COLS - 1
					and target_cell.y >= 0 and target_cell.y <= ROWS - 1):
						surrounding_cells.append(target_cell)
	return surrounding_cells

func _input(event):
	if event is InputEventMouseButton:
		# Check if mouse is on the game board
		if event.position.y < ROWS * CELL_SIZE:
			var map_pos := local_to_map(event.position)
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				# Check that there is no flag there
				if not is_flag(map_pos):
					# Check if it is a mine
					if is_mine(map_pos):
						# Check if it is the first click
						if get_parent().first_click:
							move_mine(map_pos)
							generate_numbers()
							process_left_click(map_pos)
							# Count this as a valid click since first click is always safe
							get_parent().increment_click_count()
						# Otherwise end the game
						else:
							end_game.emit()
							show_mines()
							# Don't count mine clicks as valid clicks
					else:
						# Only count clicks that reveal valid cells (not mines)
						if is_grass(map_pos):  # Only count if clicking on unrevealed grass
							get_parent().increment_click_count()
						process_left_click(map_pos)
			# Right click places and removes flags
			elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				# Only count right clicks that actually place/remove flags on grass cells
				if is_grass(map_pos):
					var had_flag = is_flag(map_pos)
					process_right_click(map_pos)
					# Only count if flag state actually changed
					if had_flag != is_flag(map_pos):
						get_parent().increment_click_count()

# Flood fill algorithm to reveal connected empty cells
func flood_fill(start_pos):
	var cells_to_check = [start_pos]
	var processed_cells = {}
	var cells_revealed = false
	
	while cells_to_check.size() > 0:
		var current_cell = cells_to_check.pop_back()
		
		# Skip if already processed
		if processed_cells.has(current_cell):
			continue
			
		# Mark as processed
		processed_cells[current_cell] = true
		
		# Skip if not grass (already revealed), is a mine, or is flagged
		if not is_grass(current_cell) or is_mine(current_cell) or is_flag(current_cell):
			continue
		
		# Reveal the current cell
		erase_cell(grass_layer, current_cell)
		cells_revealed = true
		
		# Count surrounding mines
		var mine_count = count_surrounding_mines(current_cell)
		
		# If there are surrounding mines, place the number and stop expanding from this cell
		if mine_count > 0:
			set_cell(number_layer, current_cell, tile_id, number_atlas[mine_count - 1])
		else:
			# If no surrounding mines, add all neighbors to be checked
			for neighbor in get_all_surrounding_cells(current_cell):
				if not processed_cells.has(neighbor):
					cells_to_check.append(neighbor)
	
	# Emit signal if any cells were revealed (for sound effect)
	if cells_revealed:
		cell_revealed.emit()

# Updated left click processing with flood fill
func process_left_click(pos):
	get_parent().first_click = false
	
	# Only process if it's a grass cell (unrevealed)
	if not is_grass(pos):
		return
	
	# Use flood fill to reveal connected areas
	flood_fill(pos)
	
	# Check win condition after revealing cells
	check_win_condition()

func check_win_condition():
	var unrevealed_safe_cells = 0
	
	for y in range(ROWS):
		for x in range(COLS):
			var cell = Vector2i(x, y)
			# If it's grass (unrevealed) and not a mine, it's an unrevealed safe cell
			if is_grass(cell) and not is_mine(cell):
				unrevealed_safe_cells += 1
	
	# Win if all safe cells are revealed
	if unrevealed_safe_cells == 0:
		game_won.emit()

func process_right_click(pos):
	# Check if it is a grass cell
	if is_grass(pos):
		if is_flag(pos):
			erase_cell(flag_layer, pos)
			current_flags -= 1
			flag_removed.emit()
		else:
			# Check if we can place more flags
			if current_flags < MAX_FLAGS:
				set_cell(flag_layer, pos, tile_id, flag_atlas)
				current_flags += 1
				flag_placed.emit()
			# If at flag limit, you could add a visual/audio feedback here

func show_mines():
	for mine in mine_coords:
		if is_mine(mine):
			erase_cell(grass_layer, mine)

func move_mine(old_pos):
	for y in range(ROWS):
		for x in range(COLS):
			if not is_mine(Vector2i(x, y)) and get_parent().first_click == true:
				# Update array
				mine_coords[mine_coords.find(old_pos)] = Vector2i(x, y)
				# Clear the old mine
				erase_cell(mine_layer, old_pos)
				# Move to new free space
				set_cell(mine_layer, Vector2i(x, y), tile_id, mine_atlas)
				# No longer first click
				get_parent().first_click = false
				return

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	highlight_cell()
	
	# Scan mines
	if (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and 
		Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
			var scan_pos := local_to_map(get_local_mouse_position())
			if not is_grass(scan_pos):
				if scanning == false:
					scan_mines(scan_pos)
					scanning = true
	else:
		scanning = false
	
func highlight_cell():
	var mouse_pos := local_to_map(get_local_mouse_position())
	# Clear hover tiles and add a fresh one under the mouse
	clear_layer(hover_layer)
	
	# Hover over grass cells
	if is_grass(mouse_pos):
		set_cell(hover_layer, mouse_pos, tile_id, hover_atlas)
	else:
		# If the cell is cleared then only hover over number cells
		if is_number(mouse_pos):
			set_cell(hover_layer, mouse_pos, tile_id, hover_atlas)

func scan_mines(pos):
	var unflagged_mines : int = 0
	for i in get_all_surrounding_cells(pos):
		# Check if there are any un-mined flags
		if is_flag(i) and not is_mine(i):
			end_game.emit()
			show_mines()
			return
		# Check if there are un-flagged mines
		if is_mine(i) and not is_flag(i):
			unflagged_mines += 1
	
	# No auto-reveal for scan mines - just visual feedback
	if unflagged_mines == 0:
		# You could add visual feedback here instead of auto-revealing
		print("All mines around this cell are flagged!")

# Function to get remaining flags for UI
func get_remaining_flags():
	return MAX_FLAGS - current_flags

# Helper functions
func is_mine(pos):
	return get_cell_source_id(mine_layer, pos) != -1

func is_grass(pos):
	return get_cell_source_id(grass_layer, pos) != -1

func is_number(pos):
	return get_cell_source_id(number_layer, pos) != -1

func is_flag(pos):
	return get_cell_source_id(flag_layer, pos) != -1

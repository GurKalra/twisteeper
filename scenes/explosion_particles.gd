extends CPUParticles2D

func _ready():
	# Configure explosion particles
	emitting = false
	amount = 80  # Slightly fewer particles for shorter effect
	lifetime = 1.2  # Much shorter lifetime (was 3.0)
	texture = create_particle_texture()
	
	# Emission settings
	emission_shape = EMISSION_SHAPE_SPHERE
	emission_sphere_radius = 15.0  # Slightly smaller emission area
	
	# Direction and spread
	direction = Vector2(0, -1)
	spread = 180.0  # Full spread for explosion effect
	initial_velocity_min = 80.0  # Higher initial velocity for quick burst
	initial_velocity_max = 250.0  # Adjusted max velocity
	
	# Physics
	gravity = Vector2(0, 300)  # More gravity to pull particles down faster
	linear_accel_min = -50.0  # More deceleration
	linear_accel_max = 50.0
	
	# Appearance
	scale_amount_min = 0.8
	scale_amount_max = 2.0  # Slightly smaller max scale
	color = Color.RED  # More visible red color

func create_particle_texture():
	# Create a smaller, more efficient particle texture
	var image = Image.create(12, 12, false, Image.FORMAT_RGBA8)
	# Create a gradient circle for better particle appearance
	for y in range(12):
		for x in range(12):
			var distance = Vector2(x - 6, y - 6).length()
			var alpha = 1.0 - (distance / 6.0)
			alpha = max(0.0, alpha)
			image.set_pixel(x, y, Color(1.0, 0.4, 0.0, alpha))  # Orange with alpha
	
	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture

func explode():
	emitting = true
	# Auto-destroy much sooner after particles finish
	await get_tree().create_timer(lifetime + 0.3).timeout  # Was lifetime + 1.0, now + 0.3
	queue_free()

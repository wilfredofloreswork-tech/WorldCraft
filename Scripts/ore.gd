extends Area2D
# ore.gd - Collectible ore nodes with health system

signal damaged(damage_amount, current_health)
signal destroyed(ore_type)

# Ore properties
enum OreType {COPPER, TIN, IRON, COAL, GOLD, MITHRIL}
var ore_type: OreType = OreType.COPPER

# Health system
var max_health := 100.0
var current_health := 100.0

# Ore data for different types
var ore_data = {
	OreType.COPPER: {
		"name": "copper_ore",
		"color": Color(0.72, 0.45, 0.20),
		"health": 80.0,
		"size": 1.0,
		"impact_resistance": 1.0  # How much damage it takes from hits
	},
	OreType.TIN: {
		"name": "tin_ore", 
		"color": Color(0.7, 0.7, 0.75),
		"health": 80.0,
		"size": 1.0,
		"impact_resistance": 1.0
	},
	OreType.IRON: {
		"name": "iron_ore",
		"color": Color(0.5, 0.5, 0.55),
		"health": 150.0,
		"size": 1.2,
		"impact_resistance": 0.8  # Takes less damage (harder ore)
	},
	OreType.COAL: {
		"name": "coal",
		"color": Color(0.15, 0.15, 0.15),
		"health": 120.0,
		"size": 1.1,
		"impact_resistance": 1.2  # Takes more damage (softer)
	},
	OreType.GOLD: {
		"name": "gold_ore",
		"color": Color(1.0, 0.84, 0.0),
		"health": 200.0,
		"size": 0.9,
		"impact_resistance": 0.7  # Very hard to break
	},
	OreType.MITHRIL: {
		"name": "mithril_ore",
		"color": Color(0.5, 0.8, 1.0),  # Bright blue
		"health": 300.0,
		"size": 0.8,
		"impact_resistance": 0.5  # Extremely hard
	}
}

# Visual feedback
var health_bar: ProgressBar

func _ready():
	# Set up collision detection
	body_entered.connect(_on_body_entered)
	set_ore_type(2)
	# Apply ore properties
	apply_ore_properties()
	
	# Create health bar
	create_health_bar()

func set_ore_type(type: OreType):
	ore_type = type
	apply_ore_properties()

func apply_ore_properties():
	var data = ore_data[ore_type]
	
	# Set health
	max_health = data["health"]
	current_health = max_health
	
	# Color the sprite if it exists
	var sprite = null
	if has_node("CollisionShape2D/Sprite2D"):
		sprite = get_node("CollisionShape2D/Sprite2D")

	
	if sprite:
		sprite.modulate = data["color"]
		print("Applied color to sprite: " + data["name"] + " - Color: " + str(data["color"]))
	else:
		print("WARNING: No sprite found to color!")
	
	# Update health bar if it exists
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

func create_health_bar():
	# Create a simple health bar above the ore
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(50, 2)
	health_bar.position = Vector2(-25, -40)  # Above the ore
	health_bar.max_value = max_health
	health_bar.value = current_health
	health_bar.show_percentage = false
	
	# Style the health bar
	var style_fg = StyleBoxFlat.new()
	style_fg.bg_color = Color(0.2, 0.8, 0.2)  # Green
	health_bar.add_theme_stylebox_override("fill", style_fg)
	
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color(0.3, 0.3, 0.3)  # Dark gray
	health_bar.add_theme_stylebox_override("background", style_bg)
	
	add_child(health_bar)

func _on_body_entered(body):
	# Only take damage from the pickaxe
	print("Body entered ore: " + body.name)
	if body.name == "RigidBody2D":
		# Calculate damage based on pickaxe velocity
		var impact_force = body.linear_velocity.length()
		print("Impact force: " + str(impact_force))
		take_damage(impact_force)

func take_damage(impact_force: float):
	var data = ore_data[ore_type]
	
	# Calculate damage (scale with impact force and resistance)
	var damage = impact_force * 0.15 * data["impact_resistance"]
	
	print("Calculating damage - Impact: %.2f, Damage: %.2f, Current HP: %.2f/%.2f" % [impact_force, damage, current_health, max_health])
	
	# Minimum damage threshold (weak hits don't count)
	if damage < 5.0:
		print("Damage too weak! Need at least 5.0 damage")
		return  # Too weak
	
	# Apply damage
	current_health -= damage
	
	print("Ore took %.2f damage! Health now: %.2f/%.2f" % [damage, current_health, max_health])
	
	# Visual feedback
	flash_damage()
	update_health_bar()
	
	# Screen shake based on impact
	shake_ore(impact_force * 0.05)
	
	# Emit signal
	damaged.emit(damage, current_health)
	
	# Check if destroyed
	if current_health <= 0:
		print("ORE HEALTH DEPLETED - DESTROYING")
		destroy_ore()

func flash_damage():
	# Flash red when damaged
	var original_modulate = modulate
	modulate = Color(1.5, 0.8, 0.8)  # Bright red-ish
	
	var tween = create_tween()
	tween.tween_property(self, "modulate", original_modulate, 0.15)

func update_health_bar():
	if health_bar:
		health_bar.value = current_health
		
		# Change color based on health percentage
		var health_percent = current_health / max_health
		var style = StyleBoxFlat.new()
		
		if health_percent > 0.6:
			style.bg_color = Color(0.2, 0.8, 0.2)  # Green
		elif health_percent > 0.3:
			style.bg_color = Color(0.9, 0.7, 0.1)  # Yellow
		else:
			style.bg_color = Color(0.9, 0.2, 0.2)  # Red
		
		health_bar.add_theme_stylebox_override("fill", style)

func shake_ore(intensity: float):
	# Shake effect on hit
	var original_pos = position
	var shake_offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
	
	position = original_pos + shake_offset
	
	var tween = create_tween()
	tween.tween_property(self, "position", original_pos, 0.1)

func destroy_ore():
	# Emit destroyed signal FIRST before doing anything else
	var data = ore_data[ore_type]
	print("ORE DESTROYED: " + data["name"])
	destroyed.emit(data["name"])
	
	# Create destruction effect
	create_destruction_effect()
	
	# Wait a tiny bit before removing (let signal propagate)
	await get_tree().create_timer(0.05).timeout
	
	# Remove ore
	queue_free()

func create_destruction_effect():
	var data = ore_data[ore_type]
	
	# Particle burst effect
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 30
	particles.lifetime = 0.8
	particles.explosiveness = 1.0
	particles.direction = Vector2(0, -1)
	particles.spread = 180
	particles.initial_velocity_min = 100
	particles.initial_velocity_max = 200
	particles.gravity = Vector2(0, 300)
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 5.0
	particles.color = data["color"]
	
	get_parent().add_child(particles)
	particles.global_position = global_position
	
	# Auto-delete particles after animation
	await get_tree().create_timer(1.0).timeout
	particles.queue_free()
	
	# Scale-out animation for the ore itself
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.2)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)

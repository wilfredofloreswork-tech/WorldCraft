extends RigidBody2D
# log.gd - Individual log that can be hit and sorted (physics-based)

signal log_hit(log, hit_direction)

var is_good_log := true
var already_hit := false  # Prevent multiple hits

# Visual settings
const GOOD_COLOR = Color(0.6, 0.4, 0.2)  # Brown
const BAD_COLOR = Color(0.4, 0.2, 0.15)  # Deep red-brown

func _ready():

	# Physics settings - constrained but can fall
	gravity_scale = 1.0
	lock_rotation = true  # Keep logs upright
	freeze = false
	
	# Connect collision detection
	body_entered.connect(_on_body_entered)

func setup_log(good: bool):
	"""Initialize the log as good or bad quality"""
	is_good_log = good
	
	# Color the sprite
	var sprite = get_node_or_null("Sprite2D")
	if not sprite:
		sprite = get_node_or_null("ColorRect")
	
	if sprite:
		sprite.modulate = GOOD_COLOR if is_good_log else BAD_COLOR
	
	# Add visual indicator for testing
	add_quality_label()

func add_quality_label():
	"""Add text label showing quality (for testing - remove later)"""
	var label = Label.new()
	label.text = "Good" if is_good_log else "Bad"
	label.add_theme_font_size_override("font_size", 14)
	label.position = Vector2(-20, -10)
	label.modulate = Color.WHITE if is_good_log else Color.RED
	add_child(label)

func _on_body_entered(body):
	"""Detect when axe hits this log"""
	if already_hit:
		return
		
	print("Body entered log: " + body.name)
	
	if body.name == "AxeHead" or "Axe" in body.name:
		hit_by_axe(body)

func hit_by_axe(axe_node):
	"""Process axe hit"""
	if already_hit:
		return
	
	already_hit = true  # Mark as hit to prevent multiple triggers
	
	# Determine which side was hit based on axe position
	var hit_from_left = axe_node.global_position.x < global_position.x
	var direction = "left" if hit_from_left else "right"
	
	print("Log hit from " + direction + " side")
	
	# Disable physics constraints for flying to basket
	freeze = true
	collision_layer = 0  # Stop colliding with other logs
	collision_mask = 0
	
	# Emit signal with direction
	log_hit.emit(self, direction)
	
	# Visual feedback
	flash_hit()

func flash_hit():
	"""Quick flash when hit"""
	var original_modulate = modulate
	modulate = Color.WHITE
	
	var tween = create_tween()
	tween.tween_property(self, "modulate", original_modulate, 0.1)

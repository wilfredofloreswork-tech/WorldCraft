extends Area2D
# log.gd - Individual log that can be hit and sorted

signal log_hit(log, hit_direction)

var is_good_log := true

# Visual settings
const GOOD_COLOR = Color(0.6, 0.4, 0.2)  # Brown
const BAD_COLOR = Color(0.4, 0.2, 0.15)  # Deep red-brown

func _ready():
	# Connect collision detection
	body_entered.connect(_on_body_entered)

func setup_log(good: bool):
	"""Initialize the log as good or bad quality"""
	is_good_log = good
	
	# Color the sprite
	var sprite = get_node_or_null("Sprite2D")
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
	if body.name == "AxeHead":
		# Determine which side was hit based on axe position
		var hit_from_left = body.global_position.x < global_position.x
		var direction = "left" if hit_from_left else "right"
		
		print("Log hit from " + direction + " side")
		
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

extends Node2D
# axe.gd - Rotating axe controlled by dragging

@onready var axe_head = $AxeHead
@onready var axe_handle = $AxeHandle

var dragging := false
var pivot_point := Vector2.ZERO

func _ready():
	pivot_point = global_position
	print("Axe ready - drag the head to swing!")

func _process(_delta):
	if dragging:
		# Calculate angle to mouse
		var mouse_pos = get_global_mouse_position()
		var direction = mouse_pos - pivot_point
		var target_angle = direction.angle()
		
		# Clamp rotation to reasonable range (bottom half of circle)
		target_angle = clamp(target_angle, -PI * 0.8, PI * 0.2)
		
		# Apply rotation
		rotation = target_angle
	else:
		# Return to center when not dragging
		var tween = create_tween()
		tween.tween_property(self, "rotation", 0.0, 0.3).set_ease(Tween.EASE_OUT)

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Check if clicking on axe head
				var mouse_pos = get_global_mouse_position()
				var head_pos = axe_head.global_position
				var distance = mouse_pos.distance_to(head_pos)
				
				if distance < 50:  # Within 50 pixels
					dragging = true
			else:
				dragging = false

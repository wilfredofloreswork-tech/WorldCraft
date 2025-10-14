# Pickaxe.gd - Attach to your RigidBody2D pickaxe
extends RigidBody2D

signal score(ore)

@onready var pin_joint = $PinJoint2D
@onready var anchor = $"../mouseAnchor"  # Reference to the anchor node

var last_mouse_pos = Vector2.ZERO
var max_swing_speed = 12.0

func _ready():
	last_mouse_pos = get_global_mouse_position()
	
	# Set up the pin joint
	pin_joint.node_a = anchor.get_path()  # The anchor point
	pin_joint.node_b = self.get_path()    # The pickaxe
	
	# Softness makes it more realistic (0 = rigid, 1 = very soft)
	pin_joint.softness = 0.01
	
	# Disable bias to prevent jittering
	pin_joint.bias = 0.0

func _physics_process(delta):
	var current_mouse_pos = get_global_mouse_position()
	
	# Move the anchor to follow mouse
	anchor.global_position = current_mouse_pos
	
	# Limit swing speed to prevent freakouts
	angular_velocity = clamp(angular_velocity, -max_swing_speed, max_swing_speed)
	
	# Apply swing torque based on mouse movement
	var mouse_movement = current_mouse_pos.x - last_mouse_pos.x
	apply_torque(mouse_movement * -8000)  # Increased for more responsive swinging
	
	# Gravity torque to pull back to center
	var target_angle = 0.0
	var angle_diff = wrapf(target_angle - rotation, -PI, PI)
	apply_torque(angle_diff * 200)  # Gravity-like restoration force
	
	last_mouse_pos = current_mouse_pos

func _on_body_entered(body):
	if body.is_in_group("ore"):
		# Dampen on impact
		angular_velocity *= 0.3
		linear_velocity *= 0.5
		
		score.emit(body)
		body.queue_free()



func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.is_action_pressed("leftclick"):
			pass

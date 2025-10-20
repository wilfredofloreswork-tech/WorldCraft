extends Node2D
# axe.gd - Rotating axe controlled by dragging with PinJoint2D physics

@onready var axe_head = $AxeHead if has_node("AxeHead") else null
@onready var handle_point = $Handlepoint if has_node("Handlepoint") else null
@onready var pin_joint = $axepivotpoint if has_node("axepivotpoint") else null

var dragging := false
var drag_offset := Vector2.ZERO

func _ready():
	if not axe_head:
		print("ERROR: AxeHead node not found!")
		return
	if not handle_point:
		print("ERROR: Handlepoint node not found!")
		return
	if not pin_joint:
		print("ERROR: PinJoint not found!")
		return
		
	print("Axe ready - drag the head to swing!")
	
	# FIX: Set pin joint position to the handle point location
	pin_joint.position = handle_point.position
	print("PinJoint position set to: " + str(pin_joint.position))
	
	# Unfreeze the axe head so it can move
	axe_head.freeze = false
	
	# Set up physics properties for smooth swinging
	axe_head.angular_damp = 4.0  # Some air resistance
	axe_head.linear_damp = 4.0
	axe_head.mass = 6.0
	
	# Make sure handle point is frozen (it's the anchor)
	handle_point.freeze = true
	
	print("AxeHead position: " + str(axe_head.position))
	print("Handlepoint position: " + str(handle_point.position))

func _physics_process(delta):
	if not axe_head:
		return
		
	if dragging:
		# Apply force towards mouse position
		var mouse_pos = get_global_mouse_position()
		var direction = mouse_pos - axe_head.global_position
		
		# Apply strong force to move head toward mouse
		var force_strength = 25000.0
		axe_head.apply_central_force(direction * force_strength * delta)

func _input(event):
	if not axe_head:
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Check if clicking on axe head area
				var mouse_pos = get_global_mouse_position()
				var head_pos = axe_head.global_position
				var distance = mouse_pos.distance_to(head_pos)
				
				if distance < 100:  # Within 100 pixels of head
					dragging = true
					print("Grabbed axe! Head at: " + str(axe_head.global_position))
			else:
				if dragging:
					# Release with momentum
					dragging = false
					print("Released axe!")

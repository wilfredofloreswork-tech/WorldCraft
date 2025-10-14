extends CanvasLayer
# ResultsScreen.gd - Shows mining session results

signal continue_pressed

# UI nodes - adjust paths based on your scene structure
@onready var xp_label = $Panel/VBoxContainer/XPLabel if has_node("Panel/VBoxContainer/XPLabel") else null
@onready var items_container = $Panel/VBoxContainer/ItemsContainer if has_node("Panel/VBoxContainer/ItemsContainer") else null
@onready var continue_button = $Panel/VBoxContainer/ContinueButton if has_node("Panel/VBoxContainer/ContinueButton") else null
@onready var title_label = $Panel/VBoxContainer/TitleLabel if has_node("Panel/VBoxContainer/TitleLabel") else null

var session_xp := 0
var session_items := {}

func _ready():
	# Initially hidden
	visible = false
	
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
	
	print("ResultsScreen ready")

func show_results(xp: int, items: Dictionary):
	print("\n=== SHOWING RESULTS ===")
	print("XP to display: " + str(xp))
	print("Items to display: " + str(items))
	
	session_xp = xp
	session_items = items.duplicate()  # Make a copy
	
	# Wait one frame to ensure UI is ready
	await get_tree().process_frame
	
	display_results()
	visible = true
	
	print("Results screen now visible")

func display_results():
	print("Displaying results...")
	
	# Show XP gained
	if xp_label:
		xp_label.text = "XP Gained: +" + str(session_xp)
		print("Set XP label to: " + xp_label.text)
	else:
		print("WARNING: xp_label is null!")
	
	# Show title
	if title_label:
		title_label.text = "Mining Complete!"
	
	# Show items collected
	if items_container:
		print("Setting up items container...")
		
		# Clear existing items
		for child in items_container.get_children():
			child.queue_free()
		
		# Check if we have items
		if session_items.size() == 0:
			print("WARNING: No items to display!")
			var label = Label.new()
			label.text = "No items collected"
			label.add_theme_font_size_override("font_size", 20)
			items_container.add_child(label)
		else:
			# Add item labels
			for item_name in session_items:
				var count = session_items[item_name]
				print("Adding item: " + item_name + " x" + str(count))
				
				var label = Label.new()
				label.text = item_name.replace("_", " ").capitalize() + ": x" + str(count)
				label.add_theme_font_size_override("font_size", 20)
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				items_container.add_child(label)
	else:
		print("WARNING: items_container is null!")
	
	# Show continue button
	if continue_button:
		continue_button.text = "Continue"
		continue_button.disabled = false
	else:
		print("WARNING: continue_button is null!")
	
	print("Display complete")

func _on_continue_pressed():
	print("Continue button pressed")
	continue_pressed.emit()
	queue_free()

# Debug function to manually test the results screen
func debug_test():
	show_results(500, {"copper_ore": 25, "iron_ore": 10})

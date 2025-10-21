extends Node2D
# MiningMini.gd - Time-based mining with combo system (FIXED COORDINATES)

# Game state
var ores_destroyed := 0
var session_items := 0
var game_active := true

# Combo system
var combo_count := 0
var combo_timer := 0.0
const COMBO_TIMEOUT = 2.0
var combo_multiplier := 1.0

# Ore type for this session
var current_ore_type = 5
var current_ore_name = "mithril_ore"

# Time settings
@export var game_duration := 5.0
var time_remaining := 0.0

# References
@onready var ore = preload("res://scenes/ore.tscn")
@onready var spawn_timer = $OrespawnTimer
@onready var spawn_locations = $OrespawnLocations

# UI References
@onready var timer_label = $TimerLabel if has_node("TimerLabel") else null
@onready var combo_label = $ComboLabel if has_node("ComboLabel") else null
@onready var ore_count_label = $OreCountLabel if has_node("OreCountLabel") else null

func _ready():
	print("\n=== MINIGAME STARTING ===")
	print("Current ore type: " + str(current_ore_type))
	print("Current ore name: " + current_ore_name)
	
	# Debug spawn locations
	if spawn_locations:
		print("Spawn locations found!")
		print("  Position: " + str(spawn_locations.position))
		print("  Global position: " + str(spawn_locations.global_position))
		print("  Point count: " + str(spawn_locations.get_point_count()))
		if spawn_locations.get_point_count() > 0:
			print("  First point (local): " + str(spawn_locations.get_point_position(0)))
			print("  First point (global): " + str(spawn_locations.to_global(spawn_locations.get_point_position(0))))
	else:
		print("WARNING: spawn_locations not found!")
	

	
	# Initialize time
	time_remaining = game_duration
	
	# Scale difficulty with level
	var player_level = PlayerData.get_skill_level("mining")
	game_duration = 5.0 + (player_level * 0.1)
	time_remaining = game_duration
	
	# Connect timer
	spawn_timer.timeout.connect(_on_timer_timeout)
	
	# Spawn initial ores (all same type)
	var initial_ores = 3
	for i in range(initial_ores):
		var spawn_pos = get_random_spawn_position()
		print("Spawning ore at: " + str(spawn_pos))
		spawn_ore(spawn_pos)
	
	# Start spawning
	spawn_timer.start()
	
	# Equipment bonus
	apply_equipment_bonus()
	
	update_ui()
	print("Mining " + current_ore_name + "! Combo multiplier active!")

func get_random_spawn_position() -> Vector2:
	"""Get a random spawn position from the Line2D, converted to global coordinates"""
	if not spawn_locations or spawn_locations.get_point_count() == 0:
		print("ERROR: No spawn locations available, using fallback")
		return Vector2(240, 200)  # Fallback position
	
	# Get random point from Line2D
	var random_index = randi_range(0, spawn_locations.get_point_count() - 1)
	var local_pos = spawn_locations.get_point_position(random_index)
	
	# Convert to global coordinates (this is the key fix!)
	var global_pos = spawn_locations.to_global(local_pos)
	
	return global_pos

func set_ore_type(ore_type: int, ore_name: String):
	"""Call this before starting the minigame to set what ore type to mine"""
	current_ore_type = ore_type
	current_ore_name = ore_name

func apply_equipment_bonus():
	var equipped_pickaxe = PlayerData.get_equipped_item("pickaxe")
	if equipped_pickaxe:
		var bonus_time = ItemDatabase.get_bonus_time(equipped_pickaxe)
		game_duration += bonus_time
		time_remaining += bonus_time
		print("Equipped: %s (+%.1fs)" % [equipped_pickaxe, bonus_time])

func _process(delta):
	if not game_active:
		return
	
	# Countdown timer
	time_remaining -= delta
	
	if time_remaining <= 0:
		time_remaining = 0
		end_minigame()
	
	# Combo timer countdown
	if combo_count > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			reset_combo()
	
	update_ui()

func calculate_combo_multiplier() -> float:
	# Combo multiplier: 1x, 1.5x, 2x, 2.5x, 3x, etc.
	if combo_count <= 1:
		return 1.0
	elif combo_count <= 3:
		return 1.5
	elif combo_count <= 5:
		return 2.0
	elif combo_count <= 8:
		return 2.5
	else:
		return 3.0

func reset_combo():
	combo_count = 0
	combo_multiplier = 1.0
	print("Combo broken!")

func update_ui():
	# Timer display with warning colors
	if timer_label:
		timer_label.text = "Time: %.1f" % time_remaining
		
		if time_remaining <= 2.0:
			timer_label.modulate = Color.RED if int(time_remaining * 10) % 2 == 0 else Color.WHITE
		elif time_remaining <= 3.0:
			timer_label.modulate = Color.ORANGE
		else:
			timer_label.modulate = Color.WHITE
	
	# Combo display
	if combo_label:
		if combo_count > 1:
			combo_multiplier = calculate_combo_multiplier()
			combo_label.text = "COMBO x%d (%.1fx)" % [combo_count, combo_multiplier]
			combo_label.visible = true
			
			# Color based on combo level
			if combo_count >= 8:
				combo_label.modulate = Color(1.0, 0.3, 1.0)  # Purple - max combo
			elif combo_count >= 5:
				combo_label.modulate = Color(1.0, 0.5, 0.0)  # Orange - high combo
			elif combo_count >= 3:
				combo_label.modulate = Color(1.0, 1.0, 0.0)  # Yellow - good combo
			else:
				combo_label.modulate = Color.WHITE
		else:
			combo_label.visible = false
	
	# Ore count display
	if ore_count_label:
		ore_count_label.text = current_ore_name.replace("_", " ").capitalize() + ": " + str(session_items)

func _on_timer_timeout() -> void:
	if game_active:
		# Keep spawning ores of the same type
		spawn_ore(get_random_spawn_position())
		
		# Spawn faster as time runs out
		if time_remaining < 2.0 and spawn_timer.wait_time > 0.25:
			spawn_timer.wait_time = 0.25
		elif time_remaining < 3.5 and spawn_timer.wait_time > 0.6:
			spawn_timer.wait_time = 0.6

func spawn_ore(spawn_pos: Vector2):
	var new_ore = ore.instantiate()
	add_child(new_ore)
	new_ore.global_position = spawn_pos  # Use global_position instead of position
	
	# Set the ore type (all ores are the same type in this session)
	new_ore.set_ore_type(current_ore_type)
	
	# Connect signals
	if new_ore.has_signal("destroyed"):
		new_ore.destroyed.connect(_on_ore_destroyed)
	if new_ore.has_signal("damaged"):
		new_ore.damaged.connect(_on_ore_damaged)

func _on_ore_damaged(damage: float, current_health: float):
	# Optional: Could add small visual feedback for hits
	pass

func _on_ore_destroyed(ore_type: String):
	ores_destroyed += 1
	
	# Increment combo
	combo_count += 1
	combo_timer = COMBO_TIMEOUT  # Reset combo timer
	
	# Calculate ores gained with combo multiplier
	combo_multiplier = calculate_combo_multiplier()
	var ores_gained = int(ceil(1.0 * combo_multiplier))
	
	session_items += ores_gained
	
	# Show combo feedback
	show_combo_popup(ores_gained)
	
	print("Destroyed ore! Combo: x" + str(combo_count) + " (%.1fx multiplier) - Gained %d ores" % [combo_multiplier, ores_gained])
	
	update_ui()

func show_combo_popup(ores_gained: int):
	# Create floating text showing ores gained
	var popup = Label.new()
	popup.text = "+%d" % ores_gained
	popup.add_theme_font_size_override("font_size", 24)
	popup.modulate = Color(1.0, 1.0, 0.5)
	popup.z_index = 100
	
	# Position at mouse/pickaxe location
	popup.global_position = get_global_mouse_position() + Vector2(-20, -30)
	add_child(popup)
	
	# Animate upward and fade
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "global_position:y", popup.global_position.y - 50, 1.0)
	tween.tween_property(popup, "modulate:a", 0.0, 1.0)
	
	await tween.finished
	popup.queue_free()

func end_minigame():
	if not game_active:
		return
	
	game_active = false
	spawn_timer.stop()
	
	# Clear remaining ores
	for node in get_children():
		if node.is_in_group("ore"):
			node.queue_free()
	
	# Calculate XP (more ores = more XP, combo increases XP)
	var base_xp_per_ore = ItemDatabase.get_base_xp(current_ore_name)
	var total_xp = session_items * base_xp_per_ore
	
	# Award items and XP to PlayerData
	PlayerData.add_item(current_ore_name, session_items)
	PlayerData.add_xp("mining", total_xp)
	PlayerData.increment_stat("nodes_harvested", ores_destroyed)
	
	print("\n=== TIME'S UP! ===")
	print("Ores Destroyed: " + str(ores_destroyed))
	print("Total Ores Gained (with combos): " + str(session_items))
	print("Total XP: " + str(total_xp))
	print("==================\n")
	
	# Show results
	show_results_screen(total_xp)

func show_results_screen(total_xp: int):
	print("\n=== PREPARING RESULTS SCREEN ===")
	print("Total XP: " + str(total_xp))
	print("Session items: " + str(session_items))
	print("Current ore name: " + current_ore_name)
	
	# Load and show results screen
	var results_scene = preload("res://UI/results_screen.tscn")
	var results = results_scene.instantiate()
	add_child(results)
	
	# Pass session data with custom title
	var items_dict = {current_ore_name: session_items}
	print("Items dictionary being passed: " + str(items_dict))
	
	results.show_results(total_xp, items_dict, "⛏️ Mining Complete!")
	
	# Wait for player to click continue
	results.continue_pressed.connect(return_to_map)

func return_to_map():
	print("Returning to hub...")
	# Return to the main hub
	get_tree().change_scene_to_file("res://scenes/main_hub.tscn")

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		pause_or_quit()

func pause_or_quit():
	game_active = false
	spawn_timer.stop()
	
	# Still award items/XP if quitting early
	if session_items > 0:
		var base_xp_per_ore = ItemDatabase.get_base_xp(current_ore_name)
		var total_xp = session_items * base_xp_per_ore
		PlayerData.add_item(current_ore_name, session_items)
		PlayerData.add_xp("mining", total_xp)
	
	print("Minigame quit early")
	show_results_screen(session_items * ItemDatabase.get_base_xp(current_ore_name))

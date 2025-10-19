extends Node2D
# fishing_mini.gd - Stardew Valley style fishing minigame

# Game state
var fish_caught := 0
var session_items := 0
var game_active := false
var fishing_active := false

# Current fish type (set from world map)
var current_fish_type = "raw_fish"
var current_fish_name = "Raw Fish"

# Time settings
@export var game_duration := 30.0
var time_remaining := 0.0

# Fish behavior
var fish_position := 0.5  # 0.0 to 1.0 (bottom to top of bar)
var fish_velocity := 0.0
var fish_target := 0.5
var fish_change_timer := 0.0
var fish_difficulty := 1.0  # Multiplier for fish speed/aggression

# Catch bar
var bar_position := 0.0  # 0.0 to 1.0
var bar_size := 0.25  # How tall the bar is (0.0 to 1.0)
var bar_velocity := 0.0

# Progress
var catch_progress := 0.0  # 0.0 to 1.0
const PROGRESS_GAIN_RATE = 0.6  # Per second when fish is in bar
const PROGRESS_LOSS_RATE = 0.3  # Per second when fish is out of bar

# Physics constants
const GRAVITY = 2.0
const BAR_BOOST = 4.0
const BAR_DRAG = 3.0
const FISH_ACCELERATION = 3.0

# UI dimensions
const BAR_AREA_HEIGHT = 500.0
const BAR_AREA_Y = 100.0
const BAR_WIDTH = 100.0
const BAR_X = 190.0

# References
@onready var timer_label = $UI/TimerLabel if has_node("UI/TimerLabel") else null
@onready var fish_count_label = $UI/FishCountLabel if has_node("UI/FishCountLabel") else null
@onready var instruction_label = $UI/InstructionLabel if has_node("UI/InstructionLabel") else null

# Visual elements
@onready var fishing_bar_bg = $FishingBarBG if has_node("FishingBarBG") else null
@onready var catch_bar = $CatchBar if has_node("CatchBar") else null
@onready var fish_sprite = $FishSprite if has_node("FishSprite") else null
@onready var progress_bar_node = $ProgressBar if has_node("ProgressBar") else null

func _ready():
	print("\n=== FISHING MINIGAME STARTING ===")
	
	# Initialize time
	time_remaining = game_duration
	
	# Set up difficulty based on fish type
	setup_fish_difficulty()
	
	# Equipment bonus
	apply_equipment_bonus()
	
	# Start in "cast" mode
	game_active = true
	fishing_active = false
	
	if instruction_label:
		instruction_label.text = "Click to cast!"
	
	update_ui()
	print("Fishing ready! Click to cast your line!")

func setup_fish_difficulty():
	"""Set difficulty based on fish type"""
	match current_fish_type:
		"raw_fish":
			fish_difficulty = 1.0
			bar_size = 0.25
		"salmon":
			fish_difficulty = 1.3
			bar_size = 0.22
		"tuna":
			fish_difficulty = 1.6
			bar_size = 0.18
		"lobster":
			fish_difficulty = 2.0
			bar_size = 0.15
		_:
			fish_difficulty = 1.0
			bar_size = 0.25

func set_fish_type(fish_type: String, fish_name: String):
	"""Call this before starting minigame"""
	current_fish_type = fish_type
	current_fish_name = fish_name

func apply_equipment_bonus():
	var equipped_rod = PlayerData.get_equipped_item("fishing_rod")
	
	match equipped_rod:
		"basic_rod":
			game_duration += 5.0
			time_remaining += 5.0
			bar_size += 0.02
		"good_rod":
			game_duration += 10.0
			time_remaining += 10.0
			bar_size += 0.04
		"great_rod":
			game_duration += 15.0
			time_remaining += 15.0
			bar_size += 0.06
		"master_rod":
			game_duration += 20.0
			time_remaining += 20.0
			bar_size += 0.08
	
	# Clamp bar size
	bar_size = clamp(bar_size, 0.1, 0.4)

func _process(delta):
	if not game_active:
		return
	
	# Countdown timer
	time_remaining -= delta
	
	if time_remaining <= 0:
		time_remaining = 0
		end_minigame()
		return
	
	# Update fishing physics if active
	if fishing_active:
		update_fish_ai(delta)
		update_catch_bar(delta)
		update_catch_progress(delta)
		check_catch_complete()
	
	update_ui()

func update_fish_ai(delta):
	"""Fish AI - moves erratically"""
	fish_change_timer -= delta
	
	# Change target position periodically
	if fish_change_timer <= 0:
		fish_target = randf()
		fish_change_timer = randf_range(0.5, 2.0) / fish_difficulty
	
	# Move toward target
	var direction = sign(fish_target - fish_position)
	fish_velocity += direction * FISH_ACCELERATION * fish_difficulty * delta
	
	# Apply some drag
	fish_velocity *= (1.0 - delta * 2.0)
	
	# Update position
	fish_position += fish_velocity * delta
	fish_position = clamp(fish_position, 0.0, 1.0)
	
	# Bounce off edges
	if fish_position <= 0.0 or fish_position >= 1.0:
		fish_velocity *= -0.5

func update_catch_bar(delta):
	"""Player-controlled catch bar physics"""
	# Apply gravity (bar falls)
	bar_velocity -= GRAVITY * delta
	
	# Boost when holding button/touch
	if Input.is_action_pressed("leftclick") or Input.is_action_pressed("ui_accept"):
		bar_velocity += BAR_BOOST * delta
	
	# Apply drag
	bar_velocity *= (1.0 - BAR_DRAG * delta)
	
	# Update position
	bar_position += bar_velocity * delta
	bar_position = clamp(bar_position, 0.0, 1.0 - bar_size)

func update_catch_progress(delta):
	"""Update catch progress based on if fish is in bar"""
	var bar_top = bar_position + bar_size
	var fish_in_bar = fish_position >= bar_position and fish_position <= bar_top
	
	if fish_in_bar:
		catch_progress += PROGRESS_GAIN_RATE * delta
		
		# Visual feedback - make bar green
		if catch_bar:
			catch_bar.modulate = Color(0.2, 1.0, 0.2)
	else:
		catch_progress -= PROGRESS_LOSS_RATE * delta
		
		# Visual feedback - make bar red
		if catch_bar:
			catch_bar.modulate = Color(1.0, 0.3, 0.3)
	
	catch_progress = clamp(catch_progress, 0.0, 1.0)

func check_catch_complete():
	"""Check if fish is caught"""
	if catch_progress >= 1.0:
		# Caught the fish!
		fish_caught += 1
		session_items += 1
		
		print("FISH CAUGHT!")
		show_catch_feedback()
		
		# Reset for next fish
		reset_fishing_attempt()

func reset_fishing_attempt():
	"""Reset positions for next cast"""
	fishing_active = false
	catch_progress = 0.0
	fish_position = 0.5
	fish_velocity = 0.0
	bar_position = 0.0
	bar_velocity = 0.0
	
	if instruction_label:
		instruction_label.text = "Click to cast again!"
	
	# Hide fishing UI elements
	if fishing_bar_bg:
		fishing_bar_bg.visible = false
	if catch_bar:
		catch_bar.visible = false
	if fish_sprite:
		fish_sprite.visible = false
	if progress_bar_node:
		progress_bar_node.visible = false

func show_catch_feedback():
	"""Show visual feedback for catching a fish"""
	var feedback = Label.new()
	feedback.text = "CAUGHT!"
	feedback.add_theme_font_size_override("font_size", 32)
	feedback.modulate = Color(1.0, 1.0, 0.0)
	feedback.position = Vector2(200, 300)
	add_child(feedback)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(feedback, "position:y", 250, 0.8)
	tween.tween_property(feedback, "modulate:a", 0.0, 0.8)
	
	await tween.finished
	feedback.queue_free()

func update_ui():
	# Update timer
	if timer_label:
		timer_label.text = "Time: %.1f" % time_remaining
		
		if time_remaining <= 5.0:
			timer_label.modulate = Color.RED if int(time_remaining * 10) % 2 == 0 else Color.WHITE
		elif time_remaining <= 10.0:
			timer_label.modulate = Color.ORANGE
		else:
			timer_label.modulate = Color.WHITE
	
	# Update fish count
	if fish_count_label:
		fish_count_label.text = current_fish_name + ": " + str(session_items)
	
	# Update visual positions
	if fishing_active:
		if catch_bar:
			catch_bar.visible = true
			var bar_y = BAR_AREA_Y + (1.0 - bar_position - bar_size) * BAR_AREA_HEIGHT
			catch_bar.position.y = bar_y
			catch_bar.size.y = bar_size * BAR_AREA_HEIGHT
		
		if fish_sprite:
			fish_sprite.visible = true
			var fish_y = BAR_AREA_Y + (1.0 - fish_position) * BAR_AREA_HEIGHT
			fish_sprite.position.y = fish_y
		
		if progress_bar_node:
			progress_bar_node.visible = true
			progress_bar_node.value = catch_progress

func _input(event):
	if not game_active:
		return
	
	# Cast fishing line
	if event.is_action_pressed("leftclick") or event.is_action_pressed("ui_accept"):
		if not fishing_active:
			cast_line()

func cast_line():
	"""Start a fishing attempt"""
	fishing_active = true
	
	# Randomize fish starting position
	fish_position = randf_range(0.3, 0.7)
	fish_target = randf()
	bar_position = 0.0
	catch_progress = 0.0
	
	if instruction_label:
		instruction_label.text = "Hold to raise bar!"
	
	# Show fishing UI
	if fishing_bar_bg:
		fishing_bar_bg.visible = true
	if catch_bar:
		catch_bar.visible = true
	if fish_sprite:
		fish_sprite.visible = true
	if progress_bar_node:
		progress_bar_node.visible = true
	
	print("Line cast! Keep fish in the green bar!")

func end_minigame():
	if not game_active:
		return
	
	game_active = false
	fishing_active = false
	
	# Calculate XP
	var base_xp_per_fish = get_base_xp_for_fish(current_fish_type)
	var total_xp = session_items * base_xp_per_fish
	
	# Award items and XP
	PlayerData.add_item(current_fish_type, session_items)
	PlayerData.add_xp("fishing", total_xp)
	PlayerData.increment_stat("nodes_harvested", fish_caught)
	
	print("\n=== FISHING COMPLETE ===")
	print("Fish Caught: " + str(fish_caught))
	print("Total XP: " + str(total_xp))
	
	show_results_screen(total_xp)

func get_base_xp_for_fish(fish_type: String) -> int:
	match fish_type:
		"raw_fish": return 15
		"salmon": return 30
		"tuna": return 50
		"lobster": return 80
		_: return 15

func show_results_screen(total_xp: int):
	var results_scene = preload("res://UI/results_screen.tscn")
	var results = results_scene.instantiate()
	add_child(results)
	
	var items_dict = {current_fish_type: session_items}
	results.show_results(total_xp, items_dict)
	
	results.continue_pressed.connect(return_to_map)

func return_to_map():
	print("Returning to hub...")
	get_tree().change_scene_to_file("res://scenes/main_hub.tscn")

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		pause_or_quit()

func pause_or_quit():
	game_active = false
	fishing_active = false
	
	if session_items > 0:
		var base_xp_per_fish = get_base_xp_for_fish(current_fish_type)
		var total_xp = session_items * base_xp_per_fish
		PlayerData.add_item(current_fish_type, session_items)
		PlayerData.add_xp("fishing", total_xp)
	
	print("Fishing quit early")
	show_results_screen(session_items * get_base_xp_for_fish(current_fish_type))

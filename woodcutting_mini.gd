extends Node2D
# WoodcuttingMini.gd - logg sorting minigame

# Game state
var score := 0
var correct_sorts := 0
var wrong_sorts := 0
var game_active := true

# logg type for this session (set from world map)
var current_log_type = "oak_log"

# Time settings
@export var game_duration := 30.0
var time_remaining := 0.0

# References
@onready var log_scene = preload("res://scenes/log.tscn")
@onready var spawn_timer = $LogSpawnTimer
@onready var log_container = $LogContainer
@onready var axe = $Axe if has_node("Axe") else null

# UI References
@onready var timer_label = $UI/TimerLabel if has_node("UI/TimerLabel") else null
@onready var score_label = $UI/ScoreLabel if has_node("UI/ScoreLabel") else null
@onready var feedback_label = $UI/FeedbackLabel if has_node("UI/FeedbackLabel") else null

# Basket positions
const LEFT_BASKET_X = 100.0  # Bad logs
const RIGHT_BASKET_X = 380.0  # Good logs

# logg spawn and stack settings
const LOG_SPAWN_X = 240.0  # Center of screen
const LOG_START_Y = 100.0
const LOG_SPACING = 65.0  # Closer together like poker chips
const MAX_LOGS = 9  # Keep 7 logs on screen at all times
var log_stack = []

func _ready():
	print("\n=== WOODCUTTING MINIGAME STARTING ===")
	
	# Initialize time
	time_remaining = game_duration
	
	# Equipment bonus
	apply_equipment_bonus()
	
	# Spawn initial logs to fill the stack
	for i in range(MAX_LOGS):
		spawn_log()
		await get_tree().create_timer(0.2).timeout  # Small delay between spawns
	
	# Start monitoring to maintain logg count
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.wait_time = 0.5  # Check twice per second
	spawn_timer.start()
	
	update_ui()
	print("Woodcutting started! Sort logs into correct baskets!")

func set_log_type(log_type: String):
	"""Call this before starting the minigame to set what logg type to cut"""
	current_log_type = log_type

func apply_equipment_bonus():
	var equipped_axe = PlayerData.get_equipped_item("axe")
	
	match equipped_axe:
		"bronze_axe":
			game_duration += 5.0
			time_remaining += 5.0
		"iron_axe":
			game_duration += 10.0
			time_remaining += 10.0
		"steel_axe":
			game_duration += 15.0
			time_remaining += 15.0
		"mithril_axe":
			game_duration += 25.0
			time_remaining += 25.0

func _process(delta):
	if not game_active:
		return
	
	# Countdown timer
	time_remaining -= delta
	
	if time_remaining <= 0:
		time_remaining = 0
		end_minigame()
	
	update_ui()

func update_ui():
	if timer_label:
		timer_label.text = "Time: %.1f" % time_remaining
		
		# Warning colors
		if time_remaining <= 5.0:
			timer_label.modulate = Color.RED if int(time_remaining * 10) % 2 == 0 else Color.WHITE
		elif time_remaining <= 10.0:
			timer_label.modulate = Color.ORANGE
		else:
			timer_label.modulate = Color.WHITE
	
	if score_label:
		score_label.text = "Score: %d\nCorrect: %d | Wrong: %d" % [score, correct_sorts, wrong_sorts]

func _on_spawn_timer_timeout():
	# Maintain constant logg count - spawn new logg if below MAX_LOGS
	if game_active and log_stack.size() < MAX_LOGS:
		spawn_log()

func spawn_log():
	var new_log = log_scene.instantiate()
	log_container.add_child(new_log)
	
	# Determine if good or bad logg (50/50 chance for now)
	var is_good = randf() > 0.5
	new_log.setup_log(is_good)
	
	# Spawn at top, physics will make it fall and stack
	new_log.position = Vector2(LOG_SPAWN_X, LOG_START_Y - 100)
	
	# Add to stack
	log_stack.append(new_log)
	
	# Connect signal
	new_log.log_hit.connect(_on_log_hit)
	
	print("Spawned " + ("GOOD" if is_good else "BAD") + " logg")

func _on_log_hit(logg: Node, hit_direction: String):
	"""Called when axe hits a logg with direction info"""
	print("logg hit! Direction: " + hit_direction + ", Is Good: " + str(logg.is_good_log))
	
	# Check if sorting is correct
	var correct = false
	
	if hit_direction == "right" and not logg.is_good_log:
		# Hit right side, sent to left basket (bad logs) - CORRECT
		correct = true
	elif hit_direction == "left" and logg.is_good_log:
		# Hit left side, sent to right basket (good logs) - CORRECT
		correct = true
	
	# Score it
	if correct:
		correct_sorts += 1
		score += 10
		show_feedback("Good! +10", Color.GREEN)
	else:
		wrong_sorts += 1
		score = max(0, score - 5)  # Don't go negative
		show_feedback("Wrong! -5", Color.RED)
	
	# Remove logg from stack
	log_stack.erase(logg)
	
	# Fly logg to basket (physics already disabled in logg.gd)
	fly_log_to_basket(logg, hit_direction)
	
	# Logs will fall naturally due to physics!
	# New logg will spawn automatically via timer to maintain MAX_LOGS count
	
	update_ui()

func fly_log_to_basket(logg: Node, direction: String):
	"""Animate logg flying to the appropriate basket"""
	var target_x = RIGHT_BASKET_X if direction == "left" else LEFT_BASKET_X
	var target_y = 650.0  # Bottom of screen
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(logg, "position:x", target_x, 0.5)
	tween.tween_property(logg, "position:y", target_y, 0.5)
	tween.tween_property(logg, "rotation", randf_range(-PI/4, PI/4), 0.5)
	tween.tween_property(logg, "modulate:a", 0.0, 0.5)
	
	await tween.finished
	logg.queue_free()

func show_feedback(text: String, color: Color):
	if not feedback_label:
		return
	
	feedback_label.text = text
	feedback_label.modulate = color
	feedback_label.visible = true
	
	# Fade out
	var tween = create_tween()
	tween.tween_property(feedback_label, "modulate:a", 0.0, 1.0)
	await tween.finished
	feedback_label.visible = false
	feedback_label.modulate.a = 1.0

func end_minigame():
	if not game_active:
		return
	
	game_active = false
	spawn_timer.stop()
	
	# Calculate XP based on score
	var xp_per_correct = 20
	var total_xp = correct_sorts * xp_per_correct
	
	# Award XP and logs
	PlayerData.add_xp("woodcutting", total_xp)
	PlayerData.add_item(current_log_type, correct_sorts)
	PlayerData.increment_stat("nodes_harvested", correct_sorts)
	
	print("\n=== WOODCUTTING COMPLETE ===")
	print("Score: " + str(score))
	print("Correct: " + str(correct_sorts))
	print("Wrong: " + str(wrong_sorts))
	print("XP Gained: " + str(total_xp))
	print("Logs Collected: " + str(correct_sorts))
	
	# Show results screen
	show_results_screen(total_xp)

func show_results_screen(total_xp: int):
	var results_scene = preload("res://UI/results_screen.tscn")
	var results = results_scene.instantiate()
	add_child(results)
	
	# Pass session data
	var items_dict = {current_log_type: correct_sorts}
	results.show_results(total_xp, items_dict)
	
	# Wait for continue
	results.continue_pressed.connect(return_to_hub)

func return_to_hub():
	print("Returning to hub...")
	get_tree().change_scene_to_file("res://scenes/main_hub.tscn")

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		pause_or_quit()

func pause_or_quit():
	game_active = false
	spawn_timer.stop()
	
	# Award partial score
	if correct_sorts > 0:
		var xp_per_correct = 20
		var total_xp = correct_sorts * xp_per_correct
		PlayerData.add_xp("woodcutting", total_xp)
		PlayerData.add_item(current_log_type, correct_sorts)
	
	print("Woodcutting quit early")
	show_results_screen(correct_sorts * 20)

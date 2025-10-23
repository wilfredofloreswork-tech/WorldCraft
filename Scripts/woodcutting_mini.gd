extends Node2D
# WoodcuttingMini.gd - Log sorting minigame with Android debugging

# Game state
var score := 0
var correct_sorts := 0
var wrong_sorts := 0
var game_active := true

# Log type for this session
var current_log_type = "oak_log"

# Time settings
@export var game_duration := 30.0
var time_remaining := 0.0

# References
var log_scene = null
@onready var spawn_timer = $LogSpawnTimer if has_node("LogSpawnTimer") else null
@onready var log_container = $LogContainer if has_node("LogContainer") else null
@onready var axe = $Axe if has_node("Axe") else null

# UI References
@onready var timer_label = $UI/TimerLabel if has_node("UI/TimerLabel") else null
@onready var score_label = $UI/ScoreLabel if has_node("UI/ScoreLabel") else null
@onready var feedback_label = $UI/FeedbackLabel if has_node("UI/FeedbackLabel") else null

# Basket positions
const LEFT_BASKET_X = 100.0
const RIGHT_BASKET_X = 380.0

# Log spawn settings
const LOG_SPAWN_X = 240.0
const LOG_START_Y = 0
const MAX_LOGS = 10
var log_stack = []

func _ready():
	print("\n=== WOODCUTTING MINIGAME STARTING ===")
	print("OS: " + OS.get_name())
	print("Screen size: " + str(get_viewport().get_visible_rect().size))
	
	# DEBUG: Check all required nodes exist
	if not spawn_timer:
		print("ERROR: LogSpawnTimer not found!")
		show_error_message("Missing: LogSpawnTimer")
		return
	
	if not log_container:
		print("ERROR: LogContainer not found!")
		show_error_message("Missing: LogContainer")
		return
	
	if not axe:
		print("ERROR: Axe not found!")
		show_error_message("Missing: Axe")
	
	# Load log scene with error checking
	if ResourceLoader.exists("res://scenes/log.tscn"):
		log_scene = load("res://scenes/log.tscn")
		print("Log scene loaded successfully")
	else:
		print("ERROR: log.tscn not found!")
		show_error_message("Cannot load log.tscn")
		return
	
	# Initialize time
	time_remaining = game_duration
	
	# Equipment bonus
	apply_equipment_bonus()
	
	print("Starting log spawn sequence...")
	# Spawn initial logs
	for i in range(MAX_LOGS):
		spawn_log()
		await get_tree().create_timer(0.15).timeout
	
	print("Initial logs spawned")
	
	# Connect timer
	if spawn_timer:
		spawn_timer.timeout.connect(_on_spawn_timer_timeout)
		spawn_timer.wait_time = 0.5
		spawn_timer.start()
		print("Spawn timer started")
	
	update_ui()


func show_error_message(text: String, color: Color = Color.RED):
	"""Show debug message on screen for mobile testing"""
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 24)
	label.modulate = color
	label.position = Vector2(50, 300)
	label.z_index = 100
	add_child(label)
	
	# Auto-remove after 3 seconds
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(label):
		label.queue_free()

func set_log_type(log_type: String):
	current_log_type = log_type

func apply_equipment_bonus():
	var equipped_axe = PlayerData.get_equipped_item("axe")
	if equipped_axe:
		var bonus_time = ItemDatabase.get_bonus_time(equipped_axe)
		game_duration += bonus_time
		time_remaining += bonus_time
		print("Equipped: %s (+%.1fs)" % [equipped_axe, bonus_time])

func _process(delta):
	if not game_active:
		return
	
	time_remaining -= delta
	
	if time_remaining <= 0:
		time_remaining = 0
		end_minigame()
	
	update_ui()

func update_ui():
	if timer_label:
		timer_label.text = "Time: %.1f" % time_remaining
		
		if time_remaining <= 5.0:
			timer_label.modulate = Color.RED if int(time_remaining * 10) % 2 == 0 else Color.WHITE
		elif time_remaining <= 10.0:
			timer_label.modulate = Color.ORANGE
		else:
			timer_label.modulate = Color.WHITE
	
	if score_label:
		score_label.text = "Score: %d\nCorrect: %d | Wrong: %d" % [score, correct_sorts, wrong_sorts]

func _on_spawn_timer_timeout():
	if game_active and log_stack.size() < MAX_LOGS:
		spawn_log()

func spawn_log():
	if not log_scene:
		print("ERROR: Cannot spawn log - log_scene is null")
		return
	
	print("Spawning log...")
	var new_log = log_scene.instantiate()
	
	if not new_log:
		print("ERROR: Failed to instantiate log")
		return
	
	log_container.add_child(new_log)
	
	var is_good = randf() > 0.5
	new_log.setup_log(is_good)
	
	new_log.position = Vector2(LOG_SPAWN_X, LOG_START_Y - 100)
	log_stack.append(new_log)
	
	# Connect signal with error checking
	if new_log.has_signal("log_hit"):
		new_log.log_hit.connect(_on_log_hit)
	else:
		print("WARNING: Log doesn't have log_hit signal!")
	
	print("Log spawned: " + ("GOOD" if is_good else "BAD"))

func _on_log_hit(log_node: Node, hit_direction: String):
	print("Log hit! Direction: " + hit_direction + ", Is Good: " + str(log_node.is_good_log))
	
	var correct = false
	
	if hit_direction == "right" and not log_node.is_good_log:
		correct = true
	elif hit_direction == "left" and log_node.is_good_log:
		correct = true
	
	if correct:
		correct_sorts += 1
		score += 10
		show_feedback("Good! +10", Color.GREEN)
	else:
		wrong_sorts += 1
		score = max(0, score - 5)
		show_feedback("Wrong! -5", Color.RED)
	
	log_stack.erase(log_node)
	fly_log_to_basket(log_node, hit_direction)
	update_ui()

func fly_log_to_basket(log_node: Node, direction: String):
	var target_x = RIGHT_BASKET_X if direction == "left" else LEFT_BASKET_X
	var target_y = 1000.0
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(log_node, "position:x", target_x, 0.5)
	tween.tween_property(log_node, "position:y", target_y, 0.5)
	tween.tween_property(log_node, "rotation", randf_range(-PI/4, PI/4), 0.5)
	tween.tween_property(log_node, "modulate:a", 0.0, 0.5)
	
	await tween.finished
	if is_instance_valid(log_node):
		log_node.queue_free()

func show_feedback(text: String, color: Color):
	if not feedback_label:
		return
	
	feedback_label.text = text
	feedback_label.modulate = color
	feedback_label.visible = true
	
	var tween = create_tween()
	tween.tween_property(feedback_label, "modulate:a", 0.0, 1.0)
	await tween.finished
	
	if is_instance_valid(feedback_label):
		feedback_label.visible = false
		feedback_label.modulate.a = 1.0

func end_minigame():
	if not game_active:
		return
	
	game_active = false
	
	if spawn_timer:
		spawn_timer.stop()
	
	var xp_per_correct = 20
	var total_xp = correct_sorts * xp_per_correct
	
	PlayerData.add_xp("woodcutting", total_xp)
	PlayerData.add_item(current_log_type, correct_sorts)
	PlayerData.increment_stat("nodes_harvested", correct_sorts)
	
	print("\n=== WOODCUTTING COMPLETE ===")
	print("Score: " + str(score))
	print("Correct: " + str(correct_sorts))
	print("Wrong: " + str(wrong_sorts))
	
	show_results_screen(total_xp)

func show_results_screen(total_xp: int):
	print("Loading results screen...")
	
	if not ResourceLoader.exists("res://UI/results_screen.tscn"):
		print("ERROR: results_screen.tscn not found!")
		show_error_message("Cannot load results screen")
		await get_tree().create_timer(2.0).timeout
		return_to_hub()
		return
	
	var results_scene = load("res://UI/results_screen.tscn")
	var results = results_scene.instantiate()
	add_child(results)
	
	var items_dict = {current_log_type: correct_sorts}
	results.show_results(total_xp, items_dict, "🪓 Woodcutting Complete!")
	results.continue_pressed.connect(return_to_hub)

func return_to_hub():
	print("Returning to hub...")
	get_tree().change_scene_to_file("res://scenes/main_hub.tscn")

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		pause_or_quit()

func pause_or_quit():
	game_active = false
	
	if spawn_timer:
		spawn_timer.stop()
	
	if correct_sorts > 0:
		var xp_per_correct = 20
		var total_xp = correct_sorts * xp_per_correct
		PlayerData.add_xp("woodcutting", total_xp)
		PlayerData.add_item(current_log_type, correct_sorts)
	
	print("Woodcutting quit early")
	show_results_screen(correct_sorts * 20)

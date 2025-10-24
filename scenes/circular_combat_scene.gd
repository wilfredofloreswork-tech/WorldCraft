extends Node2D

# Combat configuration
@export var hexagon_radius: float = 200.0
@export var node_size: float = 30.0
@export var boss_attack_speed: float = 0.8
@export var player_damage: int = 10
@export var boss_health: int = 100
@export var xp_per_hit: int = 15
@export var boss_loot_item: String = "Boss Goo"
@export var min_loot_amount: int = 1
@export var max_loot_amount: int = 3

# Node positions (6 positions around hexagon)
var grid_positions: Array = []
var current_player_position: int = 0
var boss_position: Vector2

# Combat state
var boss_current_health: int
var attack_timer: float = 0.0
var is_swiping: bool = false
var swipe_start_pos: Vector2
var swipe_threshold: float = 50.0
var game_active: bool = true

# Session stats
var total_hits: int = 0
var total_damage_dealt: int = 0
var times_hit: int = 0
var dodges: int = 0
var total_xp: int = 0
var loot_earned: int = 0

# Visual nodes
var player_node: Node2D
var boss_node: Node2D
var grid_nodes: Array = []

func _ready():
	# Ensure combat skill exists in PlayerData
	if PlayerData and not PlayerData.player_data["skills"].has("combat"):
		PlayerData.player_data["skills"]["combat"] = {
			"level": 1,
			"xp": 0,
			"total_xp": 0
		}
		print("Combat skill initialized in PlayerData")
	
	boss_current_health = boss_health
	setup_combat_arena()
	create_player()
	create_boss()
	update_ui()

func setup_combat_arena():
	boss_position = get_viewport_rect().size / 2
	
	# Calculate 6 positions around hexagon
	for i in range(6):
		var angle = deg_to_rad(i * 60 - 90)  # Start from top
		var pos = boss_position + Vector2(
			cos(angle) * hexagon_radius,
			sin(angle) * hexagon_radius
		)
		grid_positions.append(pos)
		
		# Create visual grid node
		var grid_visual = create_grid_visual(pos)
		grid_nodes.append(grid_visual)
		add_child(grid_visual)
	
	# Draw hexagon connections
	queue_redraw()

func create_grid_visual(pos: Vector2) -> Node2D:
	var node = Node2D.new()
	node.position = pos
	
	var sprite = ColorRect.new()
	sprite.size = Vector2(node_size, node_size)
	sprite.position = -sprite.size / 2
	sprite.color = Color(0.2, 0.8, 0.3, 0.6)
	node.add_child(sprite)
	
	return node

func create_player():
	player_node = Node2D.new()
	player_node.position = grid_positions[current_player_position]
	
	var sprite = ColorRect.new()
	sprite.size = Vector2(node_size, node_size)
	sprite.position = -sprite.size / 2
	sprite.color = Color(0.1, 0.1, 0.1)
	player_node.add_child(sprite)
	
	add_child(player_node)

func create_boss():
	boss_node = Node2D.new()
	boss_node.position = boss_position
	
	var sprite = ColorRect.new()
	sprite.size = Vector2(node_size * 1.5, node_size * 1.5)
	sprite.position = -sprite.size / 2
	sprite.color = Color(0.9, 0.2, 0.2)
	boss_node.add_child(sprite)
	
	add_child(boss_node)

func _draw():
	# Draw hexagon outline
	for i in range(6):
		var start = grid_positions[i]
		var end = grid_positions[(i + 1) % 6]
		draw_line(start - position, end - position, Color.BLACK, 3.0)

func _process(delta):
	if not game_active:
		return
		
	attack_timer += delta
	
	# Boss attacks at specified rate
	if attack_timer >= 1.0 / boss_attack_speed:
		attack_timer = 0.0
		boss_attack()

func _input(event):
	if not game_active:
		return
		
	if event.is_action_pressed("ui_cancel"):
		end_combat_early()
		return
		
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			is_swiping = true
			swipe_start_pos = event.position
		elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if is_swiping:
				handle_swipe(event.position)
			is_swiping = false
	
	elif event is InputEventScreenTouch:
		if event.pressed:
			is_swiping = true
			swipe_start_pos = event.position
		else:
			if is_swiping:
				handle_swipe(event.position)
			is_swiping = false

func handle_swipe(end_pos: Vector2):
	if not game_active:
		return
		
	var swipe_vector = end_pos - swipe_start_pos
	
	if swipe_vector.length() < swipe_threshold:
		return
	
	var player_to_boss = boss_position - player_node.position
	var angle_to_boss = swipe_vector.angle_to(player_to_boss)
	
	# Swipe towards boss = attack
	if abs(angle_to_boss) < PI / 4:  # Within 45 degrees
		attack_boss()
		return
	
	# Determine movement direction
	var current_pos = grid_positions[current_player_position]
	
	var clockwise_pos = (current_player_position + 1) % 6
	var counter_clockwise_pos = (current_player_position - 1 + 6) % 6
	
	var angle_to_clockwise = swipe_vector.angle_to(
		grid_positions[clockwise_pos] - current_pos
	)
	var angle_to_counter = swipe_vector.angle_to(
		grid_positions[counter_clockwise_pos] - current_pos
	)
	
	# Move to closest direction
	if abs(angle_to_clockwise) < abs(angle_to_counter):
		move_player(clockwise_pos)
	else:
		move_player(counter_clockwise_pos)

func move_player(new_position: int):
	current_player_position = new_position
	var tween = create_tween()
	tween.tween_property(player_node, "position", 
		grid_positions[current_player_position], 0.2)

func attack_boss():
	if not game_active:
		return
		
	boss_current_health -= player_damage
	total_hits += 1
	total_damage_dealt += player_damage
	var hit_xp = xp_per_hit
	total_xp += hit_xp
	
	print("Player attacks! Boss health: ", boss_current_health)
	
	# Visual feedback
	flash_node(boss_node, Color.WHITE)
	show_damage_number(boss_position, player_damage, Color.YELLOW)
	
	update_ui()
	
	if boss_current_health <= 0:
		victory()

func boss_attack():
	if not game_active:
		return
		
	# Boss attacks 2-3 random positions
	var attack_count = randi_range(2, 3)
	var attacked_positions = []
	
	for i in range(attack_count):
		var pos = randi() % 6
		if not attacked_positions.has(pos):
			attacked_positions.append(pos)
	
	# Show attack indicators
	for pos in attacked_positions:
		show_attack_indicator(pos)
	
	# Store the current position before delay
	var player_pos_at_attack = current_player_position
	
	# Delay damage check
	await get_tree().create_timer(0.5).timeout
	
	if not game_active:
		return
	
	# Check if player was hit (and didn't move)
	if attacked_positions.has(player_pos_at_attack):
		# If player moved away in time, count as dodge
		if current_player_position != player_pos_at_attack:
			dodges += 1
		else:
			player_hit()

func show_attack_indicator(grid_pos: int):
	var indicator = ColorRect.new()
	indicator.size = Vector2(node_size * 1.2, node_size * 1.2)
	indicator.position = grid_positions[grid_pos] - indicator.size / 2
	indicator.color = Color(1, 0, 0, 0.5)
	add_child(indicator)
	
	# Animate
	var tween = create_tween()
	tween.tween_property(indicator, "modulate:a", 0.0, 0.6)
	tween.tween_callback(indicator.queue_free)

func player_hit():
	times_hit += 1
	print("Player was hit! (Total hits taken: ", times_hit, ")")
	flash_node(player_node, Color.RED)
	
	# Add screen shake effect
	var tween = create_tween()
	var original_pos = player_node.position
	tween.tween_property(player_node, "position", 
		original_pos + Vector2(10, 0), 0.05)
	tween.tween_property(player_node, "position", 
		original_pos - Vector2(10, 0), 0.05)
	tween.tween_property(player_node, "position", original_pos, 0.05)

func flash_node(node: Node2D, flash_color: Color):
	var sprite = node.get_child(0)
	var original_color = sprite.color
	sprite.color = flash_color
	
	await get_tree().create_timer(0.1).timeout
	if node:
		sprite.color = original_color

func show_damage_number(pos: Vector2, damage: int, color: Color):
	var label = Label.new()
	label.text = str(damage)
	label.position = pos
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 24)
	add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "position:y", pos.y - 50, 1.0)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)

func update_ui():
	# Update boss health bar
	var health_bar = get_node_or_null("CanvasLayer/UI/BossHealthBar")
	if health_bar:
		health_bar.value = boss_current_health
		
		var health_label = health_bar.get_node_or_null("BossHealthLabel")
		if health_label:
			health_label.text = "BOSS: %d/%d" % [boss_current_health, boss_health]

func victory():
	if not game_active:
		return
		
	game_active = false
	
	# Calculate loot
	loot_earned = randi_range(min_loot_amount, max_loot_amount)
	
	print("\n=== VICTORY! ===")
	print("Total Hits: " + str(total_hits))
	print("Total Damage: " + str(total_damage_dealt))
	print("Times Hit: " + str(times_hit))
	print("Dodges: " + str(dodges))
	print("Total XP: " + str(total_xp))
	print("Loot Earned: " + str(loot_earned) + "x " + boss_loot_item)
	print("================\n")
	
	# Hide instructions
	var instructions = get_node_or_null("CanvasLayer/UI/Instructions")
	if instructions:
		instructions.text = "VICTORY!\nBoss Defeated!"
		instructions.add_theme_color_override("font_color", Color.GOLD)
	
	# Add victory effects
	flash_node(boss_node, Color.BLACK)
	await get_tree().create_timer(0.5).timeout
	if boss_node:
		boss_node.visible = false
	
	# Award XP and loot
	if PlayerData:
		print("Awarding " + str(total_xp) + " XP to combat skill...")
		PlayerData.add_xp("combat", total_xp)
		PlayerData.add_item(boss_loot_item, loot_earned)
		PlayerData.increment_stat("bosses_defeated", 1)
		PlayerData.increment_stat("total_hits_landed", total_hits)
		print("PlayerData updated successfully")
	else:
		print("WARNING: PlayerData not found!")
	
	# Show results screen
	await get_tree().create_timer(1.5).timeout
	show_results_screen()

func end_combat_early():
	if not game_active:
		return
		
	game_active = false
	
	print("\n=== COMBAT ENDED EARLY ===")
	print("Total Hits: " + str(total_hits))
	print("Total Damage: " + str(total_damage_dealt))
	print("Total XP: " + str(total_xp))
	print("=========================\n")
	
	# Still award XP for early quit
	if PlayerData and total_xp > 0:
		print("Awarding " + str(total_xp) + " XP to combat skill...")
		PlayerData.add_xp("combat", total_xp)
		PlayerData.increment_stat("total_hits_landed", total_hits)
		print("PlayerData updated successfully")
	else:
		print("WARNING: PlayerData not found or no XP earned!")
	
	show_results_screen()

func show_results_screen():
	print("\n=== PREPARING RESULTS SCREEN ===")
	print("Total XP: " + str(total_xp))
	print("Total Hits: " + str(total_hits))
	print("Damage Dealt: " + str(total_damage_dealt))
	print("Loot: " + str(loot_earned) + "x " + boss_loot_item)
	
	# Load and show results screen
	var results_scene = preload("res://UI/results_screen.tscn")
	var results = results_scene.instantiate()
	add_child(results)
	
	# Prepare loot dictionary for results screen
	var items_dict = {}
	if loot_earned > 0:
		items_dict[boss_loot_item] = loot_earned
	
	# Show results with custom title
	var title = "⚔️ Combat Complete!"
	if boss_current_health <= 0:
		title = "⚔️ Victory!"
	
	results.show_results(total_xp, items_dict, title)
	
	# Wait for player to click continue
	results.continue_pressed.connect(return_to_hub)

func return_to_hub():
	print("Returning to hub...")
	get_tree().change_scene_to_file("res://scenes/main_hub.tscn")

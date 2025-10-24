extends CanvasLayer
# SkillsUI.gd - Display player skills and statistics

signal skills_closed

# UI References
@onready var skills_container = $Panel/VBoxContainer/ScrollContainer/SkillsContainer if has_node("Panel/VBoxContainer/ScrollContainer/SkillsContainer") else null
@onready var stats_panel = $Panel/VBoxContainer/StatsPanel if has_node("Panel/VBoxContainer/StatsPanel") else null
@onready var close_button = $Panel/VBoxContainer/TopBar/CloseButton if has_node("Panel/VBoxContainer/TopBar/CloseButton") else null
@onready var total_level_label = $Panel/VBoxContainer/TopBar/TotalLevelLabel if has_node("Panel/VBoxContainer/TopBar/TotalLevelLabel") else null

# Skill display info with colors and icons
var skill_info = {
	
	"combat": {
	"display_name": "Combat",
	"icon": "⚔️",
	"color": Color(0.8, 0.2, 0.2),
	"description": "Fight enemies and bosses"
	},
	"mining": {
		"display_name": "Mining",
		"icon": "⛏️",
		"color": Color(0.6, 0.5, 0.4),
		"description": "Extract ores from rocks"
	},
	"smithing": {
		"display_name": "Smithing", 
		"icon": "🔨",
		"color": Color(0.7, 0.3, 0.2),
		"description": "Forge metal into tools and equipment"
	},
	"woodcutting": {
		"display_name": "Woodcutting",
		"icon": "🪓",
		"color": Color(0.4, 0.6, 0.3),
		"description": "Chop down trees for logs"
	},
	"fishing": {
		"display_name": "Fishing",
		"icon": "🎣",
		"color": Color(0.3, 0.5, 0.7),
		"description": "Catch fish from water sources"
	},
	"herbalism": {
		"display_name": "Herbalism",
		"icon": "🌿",
		"color": Color(0.3, 0.7, 0.4),
		"description": "Gather herbs and plants"
	},
	"cooking": {
		"display_name": "Cooking",
		"icon": "🍳",
		"color": Color(0.9, 0.6, 0.2),
		"description": "Prepare food from raw ingredients"
	}
}

func _ready():
	visible = false
	
	# Connect buttons
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	
	# Connect to PlayerData signals
	PlayerData.level_up.connect(_on_level_up)
	PlayerData.xp_gained.connect(_on_xp_gained)

func show_skills():
	visible = true
	refresh_skills()
	refresh_stats()

func hide_skills():
	visible = false
	skills_closed.emit()

func refresh_skills():
	if not skills_container:
		print("ERROR: SkillsContainer node not found!")
		return
	
	# Clear existing skill displays
	for child in skills_container.get_children():
		child.queue_free()
	
	# Calculate total level for header
	var total_level = 0
	for skill_name in PlayerData.player_data["skills"]:
		total_level += PlayerData.get_skill_level(skill_name)
	
	if total_level_label:
		total_level_label.text = "Total Level: " + str(total_level)
	
	# Create skill display for each skill
	var skill_order = ["mining", "smithing", "woodcutting", "fishing", "combat", "herbalism", "cooking"]
	
	for skill_name in skill_order:
		var skill_card = create_skill_card(skill_name)
		skills_container.add_child(skill_card)

func create_skill_card(skill_name: String) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 80)
	
	# Style the card
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.8)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = skill_info[skill_name]["color"]
	card.add_theme_stylebox_override("panel", style)
	
	# Main container
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	margin.add_child(hbox)
	
	# Left side - Icon and name
	var left_vbox = VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(100, 0)
	hbox.add_child(left_vbox)
	
	# Icon
	var icon_label = Label.new()
	icon_label.text = skill_info[skill_name]["icon"]
	icon_label.add_theme_font_size_override("font_size", 32)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(icon_label)
	
	# Skill name
	var name_label = Label.new()
	name_label.text = skill_info[skill_name]["display_name"]
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.modulate = skill_info[skill_name]["color"]
	left_vbox.add_child(name_label)
	
	# Right side - Level and progress
	var right_vbox = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(right_vbox)
	
	# Get skill data
	var level = PlayerData.get_skill_level(skill_name)
	var current_xp = PlayerData.get_skill_xp(skill_name)
	var total_xp = PlayerData.get_skill_total_xp(skill_name)
	var xp_for_next = PlayerData.get_xp_for_next_level(skill_name)
	var progress = PlayerData.get_skill_progress(skill_name)
	
	# Level display
	var level_hbox = HBoxContainer.new()
	right_vbox.add_child(level_hbox)
	
	var level_label = Label.new()
	level_label.text = "Level " + str(level)
	level_label.add_theme_font_size_override("font_size", 18)
	level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_hbox.add_child(level_label)
	
	# Total XP
	var total_xp_label = Label.new()
	total_xp_label.text = str(total_xp) + " XP"
	total_xp_label.add_theme_font_size_override("font_size", 12)
	total_xp_label.modulate = Color(0.8, 0.8, 0.8)
	level_hbox.add_child(total_xp_label)
	
	# Progress bar
	var progress_bar = ProgressBar.new()
	progress_bar.min_value = 0
	progress_bar.max_value = 1.0
	progress_bar.value = progress
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size = Vector2(0, 20)
	
	# Style progress bar
	var progress_fg = StyleBoxFlat.new()
	progress_fg.bg_color = skill_info[skill_name]["color"]
	progress_bar.add_theme_stylebox_override("fill", progress_fg)
	
	var progress_bg = StyleBoxFlat.new()
	progress_bg.bg_color = Color(0.2, 0.2, 0.2)
	progress_bar.add_theme_stylebox_override("background", progress_bg)
	
	right_vbox.add_child(progress_bar)
	
	# XP needed text
	if level < 99:
		var xp_text = Label.new()
		xp_text.text = str(current_xp) + " / " + str(current_xp + xp_for_next) + " XP"
		xp_text.add_theme_font_size_override("font_size", 11)
		xp_text.modulate = Color(0.7, 0.7, 0.7)
		right_vbox.add_child(xp_text)
	else:
		var max_label = Label.new()
		max_label.text = "MAX LEVEL"
		max_label.add_theme_font_size_override("font_size", 12)
		max_label.modulate = Color(1.0, 0.84, 0.0)  # Gold color
		right_vbox.add_child(max_label)
	
	return card

func refresh_stats():
	if not stats_panel:
		return
	
	# Clear existing stats
	for child in stats_panel.get_children():
		child.queue_free()
	
	# Title
	var title = Label.new()
	title.text = "Statistics"
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_panel.add_child(title)
	
	# Stats grid
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 5)
	stats_panel.add_child(grid)
	
	# Get statistics
	var stats = PlayerData.player_data["statistics"]
	
	# Display stats
	add_stat_row(grid, "Nodes Harvested:", str(stats.get("nodes_harvested", 0)))
	add_stat_row(grid, "Items Crafted:", str(stats.get("items_crafted", 0)))
	add_stat_row(grid, "Playtime:", format_time(stats.get("total_playtime", 0)))
	add_stat_row(grid, "Distance Traveled:", "%.1f m" % stats.get("distance_traveled", 0))
	add_stat_row(grid, "Bosses Defeated:", str(stats.get("bosses_defeated", 0)))
	add_stat_row(grid, "Total Hits Landed:", str(stats.get("total_hits_landed", 0)))

func add_stat_row(grid: GridContainer, label_text: String, value_text: String):
	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 12)
	label.modulate = Color(0.8, 0.8, 0.8)
	grid.add_child(label)
	
	var value = Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 12)
	value.modulate = Color(1.0, 1.0, 0.7)
	grid.add_child(value)

func format_time(seconds: float) -> String:
	var hours = int(seconds / 3600)
	var minutes = int((seconds - hours * 3600) / 60)
	if hours > 0:
		return str(hours) + "h " + str(minutes) + "m"
	else:
		return str(minutes) + "m"

func _on_level_up(skill_name: String, new_level: int):
	# Refresh if visible
	if visible:
		refresh_skills()
		show_level_up_animation(skill_name, new_level)

func _on_xp_gained(_skill_name: String, _amount: int, _new_total: int):
	# Refresh if visible
	if visible:
		refresh_skills()

func show_level_up_animation(skill_name: String, new_level: int):
	# Create a temporary celebration label
	var celebration = Label.new()
	celebration.text = "🎉 " + skill_info[skill_name]["display_name"] + " Level " + str(new_level) + "! 🎉"
	celebration.add_theme_font_size_override("font_size", 24)
	celebration.modulate = skill_info[skill_name]["color"]
	celebration.position = Vector2(get_viewport().size.x / 2 - 150, 100)
	add_child(celebration)
	
	# Animate
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(celebration, "position:y", 50, 1.5)
	tween.tween_property(celebration, "modulate:a", 0.0, 1.5)
	
	await tween.finished
	celebration.queue_free()

func _on_close_pressed():
	hide_skills()

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel") and visible:
		hide_skills()
		get_viewport().set_input_as_handled()

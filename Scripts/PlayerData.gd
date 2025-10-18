extends Node
# PlayerData.gd - Autoload/Singleton for managing all player progression data
# This script will be accessible from anywhere in your game via PlayerData.function_name()

# IMPORTANT: Add this as an autoload in Project Settings:
# Project -> Project Settings -> Autoload -> Add this script as "PlayerData"

# ===== SIGNALS =====
# Other parts of your game can connect to these to respond to changes
signal xp_gained(skill_name, amount, new_total)
signal level_up(skill_name, new_level)
signal item_added(item_name, amount)
signal item_removed(item_name, amount)
signal equipment_changed(slot, item_name)

# ===== CORE DATA STRUCTURE =====
# This Dictionary holds ALL player data. Think of it like a big nested container.
var player_data = {
	"skills": {
		# Each skill has: current level, current XP, total XP earned
		"mining": {"level": 1, "xp": 0, "total_xp": 0},
		"smithing": {"level": 1, "xp": 0, "total_xp": 0},
		"woodcutting": {"level": 1, "xp": 0, "total_xp": 0},
		"fishing": {"level": 1, "xp": 0, "total_xp": 0},
		"herbalism": {"level": 1, "xp": 0, "total_xp": 0},
		"cooking": {"level": 1, "xp": 0, "total_xp": 0}
	},
	"inventory": {
		# Items stored as: "item_name": quantity
		# Example: "copper_ore": 15
	},
	"equipment": {
		# Currently equipped items
		"pickaxe": null,  # null means nothing equipped
		"axe": null,
		"fishing_rod": null,
		"armor": null,
		"accessory": null
	},
	"statistics": {
		# Track various stats for achievements/analytics
		"total_playtime": 0.0,
		"nodes_harvested": 0,
		"items_crafted": 0,
		"distance_traveled": 0.0
	},
	"settings": {
		# Player preferences
		"sound_volume": 1.0,
		"music_volume": 0.7,
		"notifications_enabled": true
	}
}

# ===== XP REQUIREMENTS =====
# XP needed to reach each level (RuneScape-inspired formula)
# Level 2 needs 83 XP, Level 3 needs 174 XP total, etc.
var xp_table = []

# ===== INITIALIZATION =====
func _ready():
	print("PlayerData system initialized")
	_generate_xp_table()
	load_game()  # Load existing save or create new one

# Generates XP requirements for levels 1-99
func _generate_xp_table():
	xp_table.append(0)  # Level 1 starts at 0 XP
	
	var total_xp = 0
	for level in range(1, 100):  # Levels 2-99
		# RuneScape formula: XP = floor(level + 300 * 2^(level/7)) / 4
		var xp_needed = floor((level - 1) + 300.0 * pow(2.0, (level - 1) / 7.0))
		total_xp += int(xp_needed / 4.0)
		xp_table.append(total_xp)
	
	# Example: Level 10 requires xp_table[9] = ~1154 XP

# ===== SKILL FUNCTIONS =====

# Add XP to a skill and handle level-ups
func add_xp(skill_name: String, amount: int):
	if not player_data["skills"].has(skill_name):
		push_error("Skill '" + skill_name + "' does not exist!")
		return
	
	var skill = player_data["skills"][skill_name]
	var old_level = skill["level"]
	
	# Add XP
	skill["xp"] += amount
	skill["total_xp"] += amount
	xp_gained.emit(skill_name, amount, skill["total_xp"])
	
	# Check for level-up(s) - player might gain multiple levels at once
	while skill["level"] < 99 and skill["total_xp"] >= xp_table[skill["level"]]:
		skill["level"] += 1
		print(skill_name.capitalize() + " leveled up to " + str(skill["level"]) + "!")
		level_up.emit(skill_name, skill["level"])
	
	# Update current XP (XP within current level)
	if skill["level"] < 99:
		skill["xp"] = skill["total_xp"] - xp_table[skill["level"] - 1]
	else:
		skill["xp"] = 0  # Max level
	
	# Auto-save after gaining XP
	save_game()

# Get current level of a skill
func get_skill_level(skill_name: String) -> int:
	if player_data["skills"].has(skill_name):
		return player_data["skills"][skill_name]["level"]
	return 0

# Get current XP within the current level (for progress bars)
func get_skill_xp(skill_name: String) -> int:
	if player_data["skills"].has(skill_name):
		return player_data["skills"][skill_name]["xp"]
	return 0

# Get total XP earned in a skill
func get_skill_total_xp(skill_name: String) -> int:
	if player_data["skills"].has(skill_name):
		return player_data["skills"][skill_name]["total_xp"]
	return 0

# Get XP needed for next level
func get_xp_for_next_level(skill_name: String) -> int:
	if not player_data["skills"].has(skill_name):
		return 0
	
	var current_level = player_data["skills"][skill_name]["level"]
	if current_level >= 99:
		return 0  # Max level
	
	var current_total = player_data["skills"][skill_name]["total_xp"]
	var next_level_req = xp_table[current_level]
	return next_level_req - current_total

# Get percentage progress to next level (0.0 to 1.0)
func get_skill_progress(skill_name: String) -> float:
	if not player_data["skills"].has(skill_name):
		return 0.0
	
	var skill = player_data["skills"][skill_name]
	if skill["level"] >= 99:
		return 1.0  # Max level
	
	var current_level_xp = xp_table[skill["level"] - 1]
	var next_level_xp = xp_table[skill["level"]]
	var xp_in_level = skill["total_xp"] - current_level_xp
	var xp_needed = next_level_xp - current_level_xp
	
	return float(xp_in_level) / float(xp_needed)
# ===== CRAFTING SYSTEM =====

# Recipe database - defines all craftable items
var recipes = {
	# Pickaxes
	"bronze_pickaxe": {
		"requires": {"copper_ore": 1, "tin_ore": 1},
		"skill_required": {"smithing": 1},
		"produces": "bronze_pickaxe",
		"xp_granted": {"smithing": 12.5},
		"category": "pickaxe",
		"description": "A basic pickaxe. +1s mining time"
	},
	"iron_pickaxe": {
		"requires": {"iron_ore": 3},
		"skill_required": {"smithing": 15},
		"produces": "iron_pickaxe",
		"xp_granted": {"smithing": 25},
		"category": "pickaxe",
		"description": "Sturdy iron pickaxe. +2s mining time"
	},
	"steel_pickaxe": {
		"requires": {"iron_ore": 2, "coal": 2},
		"skill_required": {"smithing": 30},
		"produces": "steel_pickaxe",
		"xp_granted": {"smithing": 50},
		"category": "pickaxe",
		"description": "Strong steel pickaxe. +3s mining time"
	},
	"mithril_pickaxe": {
		"requires": {"mithril_ore": 4, "coal": 4},
		"skill_required": {"smithing": 50},
		"produces": "mithril_pickaxe",
		"xp_granted": {"smithing": 120},
		"category": "pickaxe",
		"description": "Legendary pickaxe. +5s mining time"
	},
		# Axes
	"bronze_axe": {
		"requires": {"copper_ore": 1, "tin_ore": 1},
		"skill_required": {"smithing": 1},
		"produces": "bronze_axe",
		"xp_granted": {"smithing": 12.5},
		"category": "tool",
		"description": "A basic axe. +5s woodcutting time"
	},
	"iron_axe": {
		"requires": {"iron_ore": 3},
		"skill_required": {"smithing": 15},
		"produces": "iron_axe",
		"xp_granted": {"smithing": 25},
		"category": "tool",
		"description": "Sturdy iron axe. +10s woodcutting time"
	},
	"steel_axe": {
		"requires": {"iron_ore": 2, "coal": 2},
		"skill_required": {"smithing": 30},
		"produces": "steel_axe",
		"xp_granted": {"smithing": 50},
		"category": "tool",
		"description": "Strong steel axe. +15s woodcutting time"
	},
	"mithril_axe": {
		"requires": {"mithril_ore": 4, "coal": 4},
		"skill_required": {"smithing": 50},
		"produces": "mithril_axe",
		"xp_granted": {"smithing": 120},
		"category": "tool",
		"description": "Legendary axe. +25s woodcutting time"
	},
	# Future: fishing rods, armor, etc.

	# "fishing_rod": { ... },
}

# ===== CRAFTING FUNCTIONS =====

# Check if player can craft a recipe
func can_craft(recipe_name: String) -> bool:
	if not recipes.has(recipe_name):
		return false
	
	var recipe = recipes[recipe_name]
	
	# Check materials
	for material in recipe["requires"]:
		if not has_item(material, recipe["requires"][material]):
			return false
	
	# Check skill levels
	for skill in recipe["skill_required"]:
		if get_skill_level(skill) < recipe["skill_required"][skill]:
			return false
	
	return true

# Get list of missing materials for a recipe
func get_missing_materials(recipe_name: String) -> Dictionary:
	if not recipes.has(recipe_name):
		return {}
	
	var recipe = recipes[recipe_name]
	var missing = {}
	
	for material in recipe["requires"]:
		var needed = recipe["requires"][material]
		var have = get_item_count(material)
		if have < needed:
			missing[material] = needed - have
	
	return missing

# Check if player meets skill requirements
func meets_skill_requirements(recipe_name: String) -> bool:
	if not recipes.has(recipe_name):
		return false
	
	var recipe = recipes[recipe_name]
	for skill in recipe["skill_required"]:
		if get_skill_level(skill) < recipe["skill_required"][skill]:
			return false
	
	return true

# Craft an item
func craft_item(recipe_name: String) -> bool:
	if not can_craft(recipe_name):
		print("Cannot craft " + recipe_name + " - requirements not met")
		return false
	
	var recipe = recipes[recipe_name]
	
	# Consume materials
	for material in recipe["requires"]:
		remove_item(material, recipe["requires"][material])
	
	# Create item
	add_item(recipe["produces"], 1)
	
	# Grant XP
	for skill in recipe["xp_granted"]:
		add_xp(skill, int(recipe["xp_granted"][skill]))
	
	# Update statistics
	increment_stat("items_crafted", 1)
	
	print("Crafted: " + recipe["produces"])
	return true

# Get all recipes player can currently craft
func get_craftable_recipes() -> Array:
	var craftable = []
	for recipe_name in recipes:
		if can_craft(recipe_name):
			craftable.append(recipe_name)
	return craftable

# Get recipes by category
func get_recipes_by_category(category: String) -> Array:
	var filtered = []
	for recipe_name in recipes:
		if recipes[recipe_name]["category"] == category:
			filtered.append(recipe_name)
	return filtered

# Get all recipe names
func get_all_recipes() -> Array:
	return recipes.keys()
	

# ===== INVENTORY FUNCTIONS =====

# Add items to inventory
func add_item(item_name: String, amount: int = 1):
	if player_data["inventory"].has(item_name):
		player_data["inventory"][item_name] += amount
	else:
		player_data["inventory"][item_name] = amount
	
	item_added.emit(item_name, amount)
	save_game()

# Remove items from inventory
func remove_item(item_name: String, amount: int = 1) -> bool:
	if not player_data["inventory"].has(item_name):
		return false  # Don't have this item
	
	if player_data["inventory"][item_name] < amount:
		return false  # Don't have enough
	
	player_data["inventory"][item_name] -= amount
	
	# Remove entry if quantity is 0
	if player_data["inventory"][item_name] <= 0:
		player_data["inventory"].erase(item_name)
	
	item_removed.emit(item_name, amount)
	save_game()
	return true

# Check if player has enough of an item
func has_item(item_name: String, amount: int = 1) -> bool:
	if not player_data["inventory"].has(item_name):
		return false
	return player_data["inventory"][item_name] >= amount

# Get quantity of an item
func get_item_count(item_name: String) -> int:
	if player_data["inventory"].has(item_name):
		return player_data["inventory"][item_name]
	return 0

# Get all items in inventory (returns Dictionary)
func get_all_items() -> Dictionary:
	return player_data["inventory"].duplicate()

# ===== EQUIPMENT FUNCTIONS =====

# Equip an item to a slot
func equip_item(slot: String, item_name: String) -> bool:
	if not player_data["equipment"].has(slot):
		push_error("Equipment slot '" + slot + "' does not exist!")
		return false
	
	# Check if player owns the item
	if not has_item(item_name):
		return false
	
	# Unequip current item in slot (if any)
	if player_data["equipment"][slot] != null:
		unequip_item(slot)
	
	# Equip new item
	player_data["equipment"][slot] = item_name
	remove_item(item_name, 1)  # Remove from inventory
	
	equipment_changed.emit(slot, item_name)
	save_game()
	return true

# Unequip an item from a slot
func unequip_item(slot: String) -> bool:
	if not player_data["equipment"].has(slot):
		return false
	
	var item_name = player_data["equipment"][slot]
	if item_name == null:
		return false  # Nothing equipped
	
	# Return item to inventory
	add_item(item_name, 1)
	player_data["equipment"][slot] = null
	
	equipment_changed.emit(slot, null)
	save_game()
	return true

# Get currently equipped item in a slot
func get_equipped_item(slot: String):
	if player_data["equipment"].has(slot):
		return player_data["equipment"][slot]
	return null

# Check if any item is equipped in a slot
func is_slot_equipped(slot: String) -> bool:
	return player_data["equipment"].get(slot) != null

# ===== STATISTICS FUNCTIONS =====

func increment_stat(stat_name: String, amount: float = 1.0):
	if player_data["statistics"].has(stat_name):
		player_data["statistics"][stat_name] += amount

func get_stat(stat_name: String) -> float:
	if player_data["statistics"].has(stat_name):
		return player_data["statistics"][stat_name]
	return 0.0

# ===== SAVE/LOAD SYSTEM =====

const SAVE_PATH = "user://player_save.json"

# Save all player data to a JSON file
func save_game():
	var save_file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if save_file == null:
		push_error("Failed to open save file for writing!")
		return
	
	# Convert Dictionary to JSON string
	var json_string = JSON.stringify(player_data, "\t")  # \t adds tabs for readability
	save_file.store_string(json_string)
	save_file.close()
	
	print("Game saved successfully!")

# Load player data from JSON file
func load_game():
	# Check if save file exists
	if not FileAccess.file_exists(SAVE_PATH):
		print("No save file found, starting new game")
		save_game()  # Create initial save
		return
	
	var save_file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if save_file == null:
		push_error("Failed to open save file for reading!")
		return
	
	# Read and parse JSON
	var json_string = save_file.get_as_text()
	save_file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("Failed to parse save file JSON!")
		return
	
	# Load data (with validation)
	var loaded_data = json.get_data()
	if typeof(loaded_data) == TYPE_DICTIONARY:
		player_data = loaded_data
		print("Game loaded successfully!")
	else:
		push_error("Save file contains invalid data!")

# Delete save file (for testing/reset)
func delete_save():
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
		print("Save file deleted")
	
	# Reset to default data
	_ready()

# ===== DEBUG FUNCTIONS =====

# Print all player data to console (useful for debugging)
func debug_print_data():
	print("===== PLAYER DATA =====")
	print("Skills:")
	for skill_name in player_data["skills"]:
		var skill = player_data["skills"][skill_name]
		print("  " + skill_name + ": Level " + str(skill["level"]) + " (" + str(skill["total_xp"]) + " XP)")
	
	print("\nInventory:")
	for item_name in player_data["inventory"]:
		print("  " + item_name + ": x" + str(player_data["inventory"][item_name]))
	
	print("\nEquipment:")
	for slot in player_data["equipment"]:
		var item = player_data["equipment"][slot]
		print("  " + slot + ": " + (str(item) if item != null else "empty"))
	
	print("=======================")

# Give player test items (for debugging)
func debug_add_test_items():
	add_item("copper_ore", 50)
	add_item("tin_ore", 30)
	add_item("iron_ore", 20)
	add_item("coal", 10)
	add_xp("mining", 500)
	add_xp("smithing", 200)
	print("Test items and XP added!")

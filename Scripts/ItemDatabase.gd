extends Node
# ItemDatabase.gd - Centralized item and recipe database
# Add this as an autoload: Project -> Project Settings -> Autoload -> ItemDatabase

const DATABASE_PATH = "res://item_database.json"

var items = {}
var recipes = {}

func _ready():
	load_database()
	print("ItemDatabase loaded: %d items, %d recipes" % [items.size(), recipes.size()])

func load_database():
	var file = FileAccess.open(DATABASE_PATH, FileAccess.READ)
	if file == null:
		push_error("Failed to load item database from: " + DATABASE_PATH)
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("Failed to parse item database JSON!")
		return
	
	var data = json.get_data()
	if typeof(data) == TYPE_DICTIONARY:
		items = data.get("items", {})
		recipes = data.get("recipes", {})
	else:
		push_error("Item database has invalid format!")

# ===== ITEM FUNCTIONS =====

func get_item(item_id: String) -> Dictionary:
	"""Get all data for an item"""
	if items.has(item_id):
		return items[item_id]
	return {}

func get_item_display_name(item_id: String) -> String:
	"""Get the display item_name for an item"""
	var item = get_item(item_id)
	if item.has("display_name"):
		return item["display_name"]
	return item_id.replace("_", " ").capitalize()

func get_item_description(item_id: String) -> String:
	"""Get the description for an item"""
	var item = get_item(item_id)
	if item.has("description"):
		return item["description"]
	return "No description available."

func get_item_color(item_id: String) -> Color:
	"""Get the color for an item (for UI display)"""
	var item = get_item(item_id)
	if item.has("color"):
		var color_array = item["color"]
		return Color(color_array[0], color_array[1], color_array[2])
	return Color(0.7, 0.7, 0.7)

func get_item_category(item_id: String) -> String:
	"""Get the category for an item"""
	var item = get_item(item_id)
	if item.has("category"):
		return item["category"]
	return "misc"

func get_base_xp(item_id: String) -> int:
	"""Get the base XP for gathering/catching this item"""
	var item = get_item(item_id)
	if item.has("base_xp"):
		return item["base_xp"]
	return 10

func get_equipment_slot(item_id: String) -> String:
	"""Get the equipment slot for a tool"""
	var item = get_item(item_id)
	if item.has("equipment_slot"):
		return item["equipment_slot"]
	
	# Fallback detection
	if "pickaxe" in item_id:
		return "pickaxe"
	elif "axe" in item_id and "pickaxe" not in item_id:
		return "axe"
	elif "rod" in item_id:
		return "fishing_rod"
	elif "armor" in item_id:
		return "armor"
	else:
		return "accessory"

func get_bonus_time(item_id: String) -> float:
	"""Get time bonus for equipped tools"""
	var item = get_item(item_id)
	if item.has("bonus_time"):
		return item["bonus_time"]
	return 0.0

func get_bar_size_bonus(item_id: String) -> float:
	"""Get fishing bar size bonus for rods"""
	var item = get_item(item_id)
	if item.has("bar_size_bonus"):
		return item["bar_size_bonus"]
	return 0.0

func item_exists(item_id: String) -> bool:
	"""Check if an item exists in the database"""
	return items.has(item_id)

func get_all_items_by_category(category: String) -> Array:
	"""Get all items of a specific category"""
	var result = []
	for item_id in items.keys():
		if get_item_category(item_id) == category:
			result.append(item_id)
	return result

# ===== RECIPE FUNCTIONS =====

func get_recipe(recipe_id: String) -> Dictionary:
	"""Get all data for a recipe"""
	if recipes.has(recipe_id):
		var recipe = recipes[recipe_id].duplicate(true)
		
		# Add item info for the produced item
		if recipe.has("produces"):
			var item = get_item(recipe["produces"])
			if item.has("description"):
				recipe["description"] = item["description"]
		
		return recipe
	return {}

func recipe_exists(recipe_id: String) -> bool:
	"""Check if a recipe exists"""
	return recipes.has(recipe_id)

func get_all_recipes() -> Array:
	"""Get all recipe IDs"""
	return recipes.keys()

func get_recipes_by_category(category: String) -> Array:
	"""Get all recipes in a category"""
	var result = []
	for recipe_id in recipes.keys():
		var recipe = recipes[recipe_id]
		if recipe.has("category") and recipe["category"] == category:
			result.append(recipe_id)
	return result

func get_recipes_using_item(item_id: String) -> Array:
	"""Get all recipes that use a specific item"""
	var result = []
	for recipe_id in recipes.keys():
		var recipe = recipes[recipe_id]
		if recipe.has("requires") and recipe["requires"].has(item_id):
			result.append(recipe_id)
	return result

# ===== HELPER FUNCTIONS =====

func format_requirements(recipe_id: String) -> String:
	"""Format recipe requirements as a readable string"""
	var recipe = get_recipe(recipe_id)
	if not recipe.has("requires"):
		return "No requirements"
	
	var parts = []
	for item_id in recipe["requires"].keys():
		var amount = recipe["requires"][item_id]
		var item_name = get_item_display_name(item_id)
		parts.append("%s x%d" % [item_name, amount])
	
	return ", ".join(parts)

func format_skill_requirements(recipe_id: String) -> String:
	"""Format skill requirements as a readable string"""
	var recipe = get_recipe(recipe_id)
	if not recipe.has("skill_required"):
		return "No skill requirements"
	
	var parts = []
	for skill in recipe["skill_required"].keys():
		var level = recipe["skill_required"][skill]
		parts.append("%s Lv.%d" % [skill.capitalize(), level])
	
	return ", ".join(parts)

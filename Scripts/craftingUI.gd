extends CanvasLayer
# CraftingUI.gd - Interface for crafting items

signal crafting_closed

# UI References
@onready var recipe_list = $Panel/VBoxContainer/ScrollContainer/RecipeList
@onready var recipe_details = $Panel/VBoxContainer/DetailsPanel
@onready var craft_button = $Panel/VBoxContainer/CraftButton
@onready var close_button = $Panel/VBoxContainer/CloseButton
@onready var category_tabs = $Panel/VBoxContainer/CategoryTabs

# State
var selected_recipe = null
var current_category = "all"

func _ready():
	visible = false
	
	# Connect buttons
	if craft_button:
		craft_button.pressed.connect(_on_craft_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	
	# Setup category tabs if they exist
	setup_categories()

func setup_categories():
	# You can add category filtering buttons here
	# For now, showing all recipes
	pass

func show_crafting():
	visible = true
	refresh_recipes()

func hide_crafting():
	visible = false
	crafting_closed.emit()

func refresh_recipes():
	# Clear existing recipe buttons
	if not recipe_list:
		print("ERROR: RecipeList node not found!")
		return
	
	for child in recipe_list.get_children():
		child.queue_free()
	
	# Get all recipes
	var all_recipes = ItemDatabase.get_all_recipes()
	
	# Create button for each recipe
	for recipe_name in all_recipes:
		var recipe = ItemDatabase.get_recipe(recipe_name)
		
		# Create recipe button
		var button = Button.new()
		button.custom_minimum_size = Vector2(0, 40)
		
		# Check if craftable
		var can_craft = PlayerData.can_craft(recipe_name)
		var meets_skills = PlayerData.meets_skill_requirements(recipe_name)
		
		# Button text with status
		var item_display_name = ItemDatabase.get_item_display_name(recipe["produces"])
		if can_craft:
			button.text = "✓ " + item_display_name
			button.modulate = Color(0.8, 1.0, 0.8)  # Green tint
		elif not meets_skills:
			button.text = "🔒 " + item_display_name
			button.modulate = Color(0.6, 0.6, 0.6)  # Grayed out
			button.disabled = true
		else:
			button.text = "   " + item_display_name
			button.modulate = Color(1.0, 0.9, 0.7)  # Yellow tint (have skills, need materials)
		
		# Connect button
		button.pressed.connect(_on_recipe_selected.bind(recipe_name))
		
		recipe_list.add_child(button)
	
	print("Loaded " + str(all_recipes.size()) + " recipes")

func _on_recipe_selected(recipe_name: String):
	selected_recipe = recipe_name
	display_recipe_details(recipe_name)

func display_recipe_details(recipe_name: String):
	if not recipe_details:
		return
	
	# Clear existing details
	for child in recipe_details.get_children():
		child.queue_free()
	
	var recipe = ItemDatabase.get_recipe(recipe_name)
	
	# Title
	var title = Label.new()
	title.text = ItemDatabase.get_item_display_name(recipe["produces"])
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	recipe_details.add_child(title)
	
	# Description
	var desc = Label.new()
	desc.text = ItemDatabase.get_item_description(recipe["produces"])
	desc.add_theme_font_size_override("font_size", 14)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	recipe_details.add_child(desc)
	
	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 10)
	recipe_details.add_child(spacer1)
	
	# Required materials
	var materials_label = Label.new()
	materials_label.text = "Materials Required:"
	materials_label.add_theme_font_size_override("font_size", 16)
	recipe_details.add_child(materials_label)
	
	if recipe.has("requires"):
		for material in recipe["requires"]:
			var needed = recipe["requires"][material]
			var have = PlayerData.get_item_count(material)
			
			var mat_label = Label.new()
			var material_name = ItemDatabase.get_item_display_name(material)
			mat_label.text = "  • " + material_name + ": " + str(have) + "/" + str(needed)
			
			# Color based on if we have enough
			if have >= needed:
				mat_label.modulate = Color(0.5, 1.0, 0.5)  # Green
			else:
				mat_label.modulate = Color(1.0, 0.5, 0.5)  # Red
			
			recipe_details.add_child(mat_label)
	
	# Skill requirements
	if recipe.has("skill_required") and recipe["skill_required"].size() > 0:
		var spacer2 = Control.new()
		spacer2.custom_minimum_size = Vector2(0, 10)
		recipe_details.add_child(spacer2)
		
		var skills_label = Label.new()
		skills_label.text = "Skills Required:"
		skills_label.add_theme_font_size_override("font_size", 16)
		recipe_details.add_child(skills_label)
		
		for skill in recipe["skill_required"]:
			var required_level = recipe["skill_required"][skill]
			var current_level = PlayerData.get_skill_level(skill)
			
			var skill_label = Label.new()
			var skill_name = skill.capitalize()
			skill_label.text = "  • " + skill_name + " Lv." + str(required_level)
			
			if current_level >= required_level:
				skill_label.modulate = Color(0.5, 1.0, 0.5)  # Green
			else:
				skill_label.modulate = Color(1.0, 0.5, 0.5)  # Red
			
			recipe_details.add_child(skill_label)
	
	# Update craft button state
	if craft_button:
		craft_button.disabled = not PlayerData.can_craft(recipe_name)
		if craft_button.disabled:
			craft_button.text = "Cannot Craft"
		else:
			craft_button.text = "Craft"

func _on_craft_pressed():
	if selected_recipe == null:
		print("No recipe selected")
		return
	
	# Attempt to craft
	var success = PlayerData.craft_item(selected_recipe)
	
	if success:
		print("Successfully crafted " + selected_recipe)
		
		# Show feedback
		show_craft_feedback(selected_recipe)
		
		# Refresh UI
		refresh_recipes()
		if selected_recipe:
			display_recipe_details(selected_recipe)
	else:
		print("Failed to craft " + selected_recipe)

func show_craft_feedback(item_name: String):
	# Create temporary label showing what was crafted
	var feedback = Label.new()
	feedback.text = "Crafted: " + item_name.replace("_", " ").capitalize() + "!"
	feedback.add_theme_font_size_override("font_size", 20)
	feedback.modulate = Color(1.0, 1.0, 0.5)
	feedback.position = Vector2(400, 100)
	add_child(feedback)
	
	# Fade out and remove
	var tween = create_tween()
	tween.tween_property(feedback, "modulate:a", 0.0, 1.5)
	await tween.finished
	feedback.queue_free()

func _on_close_pressed():
	hide_crafting()

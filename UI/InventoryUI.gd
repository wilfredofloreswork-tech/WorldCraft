extends CanvasLayer
# InventoryUI.gd - Display and manage player inventory

signal inventory_closed
signal item_selected(item_name: String)

# UI References - using has_node checks for safety
@onready var item_grid = $Panel/VBoxContainer/ScrollContainer/ItemGrid if has_node("Panel/VBoxContainer/ScrollContainer/ItemGrid") else null
@onready var item_details = $Panel/VBoxContainer/DetailsPanel if has_node("Panel/VBoxContainer/DetailsPanel") else null
@onready var close_button = $Panel/VBoxContainer/TopBar/CloseButton if has_node("Panel/VBoxContainer/TopBar/CloseButton") else null
@onready var category_buttons = $Panel/VBoxContainer/TopBar/CategoryButtons if has_node("Panel/VBoxContainer/TopBar/CategoryButtons") else null
@onready var total_items_label = $Panel/VBoxContainer/TopBar/TotalItemsLabel if has_node("Panel/VBoxContainer/TopBar/TotalItemsLabel") else null

# State
var selected_item = null
var current_category = "all"

# Item categories and display info
var item_info = {
	# Ores
	"copper_ore": {"category": "ore", "display_name": "Copper Ore", "description": "Basic copper ore. Used in bronze crafting.", "color": Color(0.72, 0.45, 0.20)},
	"tin_ore": {"category": "ore", "display_name": "Tin Ore", "description": "Tin ore. Combined with copper to make bronze.", "color": Color(0.7, 0.7, 0.75)},
	"iron_ore": {"category": "ore", "display_name": "Iron Ore", "description": "Strong iron ore. Used in steel crafting.", "color": Color(0.5, 0.5, 0.55)},
	"coal": {"category": "ore", "display_name": "Coal", "description": "Fuel for smelting. Required for steel.", "color": Color(0.15, 0.15, 0.15)},
	"gold_ore": {"category": "ore", "display_name": "Gold Ore", "description": "Precious gold ore. Rare and valuable.", "color": Color(1.0, 0.84, 0.0)},
	"mithril_ore": {"category": "ore", "display_name": "Mithril Ore", "description": "Legendary mithril ore. Extremely rare.", "color": Color(0.5, 0.8, 1.0)},
	
	# Tools - Pickaxes
	"bronze_pickaxe": {"category": "tool", "display_name": "Bronze Pickaxe", "description": "Basic pickaxe. +1s mining time.", "color": Color(0.8, 0.5, 0.2)},
	"iron_pickaxe": {"category": "tool", "display_name": "Iron Pickaxe", "description": "Sturdy iron pickaxe. +2s mining time.", "color": Color(0.6, 0.6, 0.65)},
	"steel_pickaxe": {"category": "tool", "display_name": "Steel Pickaxe", "description": "Strong steel pickaxe. +3s mining time.", "color": Color(0.7, 0.7, 0.75)},
	"mithril_pickaxe": {"category": "tool", "display_name": "Mithril Pickaxe", "description": "Legendary pickaxe. +5s mining time.", "color": Color(0.6, 0.9, 1.0)},
	
	# Tools - Axes
	"bronze_axe": {"category": "tool", "display_name": "Bronze Axe", "description": "Basic axe. +5s woodcutting time.", "color": Color(0.8, 0.5, 0.2)},
	"iron_axe": {"category": "tool", "display_name": "Iron Axe", "description": "Sturdy iron axe. +10s woodcutting time.", "color": Color(0.6, 0.6, 0.65)},
	"steel_axe": {"category": "tool", "display_name": "Steel Axe", "description": "Strong steel axe. +15s woodcutting time.", "color": Color(0.7, 0.7, 0.75)},
	"mithril_axe": {"category": "tool", "display_name": "Mithril Axe", "description": "Legendary axe. +25s woodcutting time.", "color": Color(0.6, 0.9, 1.0)},
	
	# Logs
	"oak_log": {"category": "resource", "display_name": "Oak Log", "description": "Basic oak logs for woodworking.", "color": Color(0.6, 0.4, 0.2)},
	
	"raw_fish": {"category": "resource", "display_name": "Raw Fish", "description": "Common fish. Can be cooked.", "color": Color(0.7, 0.7, 0.8)},
	"salmon": {"category": "resource", "display_name": "Salmon", "description": "Quality fish. Harder to catch.", "color": Color(1.0, 0.6, 0.5)},
	"tuna": {"category": "resource", "display_name": "Tuna", "description": "Large fish. Very challenging.", "color": Color(0.4, 0.5, 0.8)},
	"lobster": {"category": "resource", "display_name": "Lobster", "description": "Rare crustacean. Extremely difficult.", "color": Color(0.9, 0.3, 0.2)},
}

func _ready():
	visible = false
	
	# Connect buttons
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	
	# Setup category filtering
	setup_categories()
	
	# Connect to PlayerData signals
	PlayerData.item_added.connect(_on_item_changed)
	PlayerData.item_removed.connect(_on_item_changed)

func setup_categories():
	if not category_buttons:
		return
	
	# Clear existing buttons
	for child in category_buttons.get_children():
		child.queue_free()
	
	# Create category filter buttons
	var categories = ["all", "ore", "tool", "equipment"]
	
	for cat in categories:
		var button = Button.new()
		button.text = cat.capitalize()
		button.custom_minimum_size = Vector2(80, 30)
		button.pressed.connect(_on_category_selected.bind(cat))
		category_buttons.add_child(button)
		
		# Highlight "all" by default
		if cat == "all":
			button.modulate = Color(1.0, 1.0, 0.7)

func show_inventory():
	visible = true
	refresh_inventory()

func hide_inventory():
	visible = false
	inventory_closed.emit()

func _on_category_selected(category: String):
	current_category = category
	
	# Update button highlights
	if category_buttons:
		for button in category_buttons.get_children():
			if button.text.to_lower() == category:
				button.modulate = Color(1.0, 1.0, 0.7)
			else:
				button.modulate = Color.WHITE
	
	refresh_inventory()

func refresh_inventory():
	if not item_grid:
		print("ERROR: ItemGrid node not found!")
		return
	
	# Clear existing items
	for child in item_grid.get_children():
		child.queue_free()
	
	# Get all items from PlayerData
	var inventory = PlayerData.get_all_items()
	
	# Count total items
	var total_count = 0
	var filtered_count = 0
	
	# Create item cards
	for item_name in inventory.keys():
		var quantity = inventory[item_name]
		total_count += quantity
		
		# Check if item matches current category filter
		var item_category = get_item_category(item_name)
		if current_category != "all" and item_category != current_category:
			continue
		
		filtered_count += quantity
		
		# Create item button
		var item_button = create_item_button(item_name, quantity)
		item_grid.add_child(item_button)
	
	# Update total items label
	if total_items_label:
		if current_category == "all":
			total_items_label.text = "Total Items: " + str(total_count)
		else:
			total_items_label.text = current_category.capitalize() + ": " + str(filtered_count) + " / Total: " + str(total_count)
	
	# Show message if inventory is empty
	if inventory.size() == 0:
		var empty_label = Label.new()
		empty_label.text = "Your inventory is empty.\nGo collect some resources!"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 18)
		empty_label.modulate = Color(0.7, 0.7, 0.7)
		item_grid.add_child(empty_label)

func create_item_button(item_name: String, quantity: int) -> Button:
	var button = Button.new()
	button.custom_minimum_size = Vector2(80, 90)
	
	# Create vertical layout for button content
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Item icon (colored circle for now - you can replace with actual sprites)
	var icon = Panel.new()
	icon.custom_minimum_size = Vector2(40, 40)
	var icon_style = StyleBoxFlat.new()
	icon_style.bg_color = get_item_color(item_name)
	icon_style.corner_radius_top_left = 20
	icon_style.corner_radius_top_right = 20
	icon_style.corner_radius_bottom_left = 20
	icon_style.corner_radius_bottom_right = 20
	icon.add_theme_stylebox_override("panel", icon_style)
	
	# Item name
	var name_label = Label.new()
	name_label.text = get_item_display_name(item_name)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	
	# Quantity
	var qty_label = Label.new()
	qty_label.text = "x" + str(quantity)
	qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty_label.add_theme_font_size_override("font_size", 12)
	qty_label.modulate = Color(1.0, 1.0, 0.5)
	
	vbox.add_child(icon)
	vbox.add_child(name_label)
	vbox.add_child(qty_label)
	button.add_child(vbox)
	
	# Disable button interactions with content
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	qty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Connect button
	button.pressed.connect(_on_item_selected.bind(item_name))
	
	return button

func _on_item_selected(item_name: String):
	selected_item = item_name
	display_item_details(item_name)
	item_selected.emit(item_name)

func display_item_details(item_name: String):
	if not item_details:
		return
	
	# Clear existing details
	for child in item_details.get_children():
		child.queue_free()
	
	var quantity = PlayerData.get_item_count(item_name)
	
	# Title with quantity
	var title = Label.new()
	title.text = get_item_display_name(item_name)
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_details.add_child(title)
	
	var qty_label = Label.new()
	qty_label.text = "Quantity: " + str(quantity)
	qty_label.add_theme_font_size_override("font_size", 14)
	qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty_label.modulate = Color(1.0, 1.0, 0.7)
	item_details.add_child(qty_label)
	
	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 5)
	item_details.add_child(spacer1)
	
	# Description
	var desc = Label.new()
	desc.text = get_item_description(item_name)
	desc.add_theme_font_size_override("font_size", 12)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_details.add_child(desc)
	
	# Check if item is a tool that can be equipped
	var item_category = get_item_category(item_name)
	if item_category == "tool":
		var spacer2 = Control.new()
		spacer2.custom_minimum_size = Vector2(0, 15)
		item_details.add_child(spacer2)
		
		# Check if already equipped
		var equipped_slot = get_equipment_slot_for_item(item_name)
		var is_equipped = PlayerData.get_equipped_item(equipped_slot) == item_name
		
		# Equip/Unequip button
		var equip_button = Button.new()
		equip_button.custom_minimum_size = Vector2(120, 35)
		
		if is_equipped:
			equip_button.text = "Unequip"
			equip_button.modulate = Color(1.0, 0.7, 0.7)
			equip_button.pressed.connect(_on_unequip_item.bind(equipped_slot))
		else:
			equip_button.text = "Equip"
			equip_button.modulate = Color(0.7, 1.0, 0.7)
			equip_button.pressed.connect(_on_equip_item.bind(equipped_slot, item_name))
		
		item_details.add_child(equip_button)
	
	# Show recipes that use this item
	show_crafting_uses(item_name)

func show_crafting_uses(item_name: String):
	# Find recipes that use this item
	var uses = []
	for recipe_name in PlayerData.recipes.keys():
		var recipe = PlayerData.recipes[recipe_name]
		if recipe["requires"].has(item_name):
			uses.append(recipe_name)
	
	if uses.size() > 0:
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 10)
		item_details.add_child(spacer)
		
		var uses_label = Label.new()
		uses_label.text = "Used in crafting:"
		uses_label.add_theme_font_size_override("font_size", 14)
		uses_label.modulate = Color(0.8, 0.8, 1.0)
		item_details.add_child(uses_label)
		
		for recipe_name in uses:
			var recipe_label = Label.new()
			recipe_label.text = "  • " + recipe_name.replace("_", " ").capitalize()
			recipe_label.add_theme_font_size_override("font_size", 12)
			recipe_label.modulate = Color(0.7, 0.7, 0.9)
			item_details.add_child(recipe_label)

func _on_equip_item(slot: String, item_name: String):
	var success = PlayerData.equip_item(slot, item_name)
	if success:
		print("Equipped " + item_name + " to " + slot)
		# Refresh to update button state
		display_item_details(item_name)
		refresh_inventory()
	else:
		print("Failed to equip " + item_name)

func _on_unequip_item(slot: String):
	var success = PlayerData.unequip_item(slot)
	if success:
		print("Unequipped item from " + slot)
		# Refresh display
		if selected_item:
			display_item_details(selected_item)
		refresh_inventory()

func get_equipment_slot_for_item(item_name: String) -> String:
	if "pickaxe" in item_name:
		return "pickaxe"
	elif "axe" in item_name and "pickaxe" not in item_name:
		return "axe"
	elif "rod" in item_name:
		return "fishing_rod"
	elif "armor" in item_name:
		return "armor"
	else:
		return "accessory"

func get_item_category(item_name: String) -> String:
	if item_info.has(item_name):
		return item_info[item_name]["category"]
	
	# Fallback category detection
	if "ore" in item_name or "coal" in item_name:
		return "ore"
	elif "pickaxe" in item_name or "axe" in item_name or "rod" in item_name:
		return "tool"
	else:
		return "misc"

func get_item_display_name(item_name: String) -> String:
	if item_info.has(item_name):
		return item_info[item_name]["display_name"]
	return item_name.replace("_", " ").capitalize()

func get_item_description(item_name: String) -> String:
	if item_info.has(item_name):
		return item_info[item_name]["description"]
	return "A valuable item."

func get_item_color(item_name: String) -> Color:
	if item_info.has(item_name):
		return item_info[item_name]["color"]
	return Color(0.7, 0.7, 0.7)

func _on_item_changed(_item_name: String, _amount: int):
	# Refresh inventory when items are added/removed
	if visible:
		refresh_inventory()
		if selected_item:
			display_item_details(selected_item)

func _on_close_pressed():
	hide_inventory()

# Keyboard shortcut to toggle inventory
func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel") and visible:
		hide_inventory()
		get_viewport().set_input_as_handled()

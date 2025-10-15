extends Node
# InventoryTest.gd - Test script to demonstrate inventory functionality
# Attach this to a Node in a test scene

var inventory_ui = null

func _ready():
	print("\n=== INVENTORY UI TEST ===\n")
	
	# Load and instantiate the inventory UI
	var inventory_scene = load("res://UI/inventory_ui.tscn")
	if inventory_scene == null:
		print("ERROR: Could not load inventory_ui.tscn!")
		print("Make sure the file is at res://UI/inventory_ui.tscn")
		return
	
	inventory_ui = inventory_scene.instantiate()
	add_child(inventory_ui)
	print("Inventory UI added to scene")
	
	# Add some test items to PlayerData
	PlayerData.add_item("copper_ore", 25)
	PlayerData.add_item("tin_ore", 15)
	PlayerData.add_item("iron_ore", 10)
	PlayerData.add_item("coal", 5)
	PlayerData.add_item("bronze_pickaxe", 1)
	PlayerData.add_item("iron_pickaxe", 1)
	
	print("Added test items to inventory")
	print("Press 'I' to toggle inventory")
	print("Press 'Space' to add random items")
	print("Inventory UI visible: " + str(inventory_ui.visible))
	
	# Show inventory immediately for testing
	await get_tree().create_timer(0.5).timeout
	print("\nShowing inventory automatically...")
	inventory_ui.show_inventory()
	print("Inventory UI visible after show: " + str(inventory_ui.visible))
	
	# Connect inventory signals if needed
	if inventory_ui:
		inventory_ui.inventory_closed.connect(_on_inventory_closed)
		inventory_ui.item_selected.connect(_on_item_selected)

func _unhandled_input(event):
	# Toggle inventory with 'I' key
	if event.is_action_pressed("ui_text_completion_accept"):  # This is 'I' by default
		toggle_inventory()
	
	# Add random item with Space (for testing)
	if event.is_action_pressed("ui_accept"):  # Space key
		add_random_item()

func toggle_inventory():
	if not inventory_ui:
		print("ERROR: inventory_ui is null!")
		return
		
	print("Toggling inventory. Currently visible: " + str(inventory_ui.visible))
	if inventory_ui.visible:
		inventory_ui.hide_inventory()
	else:
		inventory_ui.show_inventory()
	print("After toggle, visible: " + str(inventory_ui.visible))

func add_random_item():
	var items = ["copper_ore", "tin_ore", "iron_ore", "coal", "gold_ore", "mithril_ore"]
	var random_item = items[randi() % items.size()]
	var random_amount = randi_range(1, 10)
	
	PlayerData.add_item(random_item, random_amount)
	print("Added " + str(random_amount) + "x " + random_item)

func _on_inventory_closed():
	print("Inventory closed")

func _on_item_selected(item_name: String):
	print("Selected item: " + item_name)

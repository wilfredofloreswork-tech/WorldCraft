extends Node3D
# MainHub.gd - Main 3D hub scene controller with GPS integration

# UI References
@onready var inventory_button = $HubUI/TopBar/HBoxContainer/MenuButtons/InventoryButton
@onready var crafting_button = $HubUI/TopBar/HBoxContainer/MenuButtons/CraftingButton
@onready var skills_button = $HubUI/TopBar/HBoxContainer/MenuButtons/SkillsButton
@onready var equipment_button = $HubUI/TopBar/HBoxContainer/MenuButtons/EquipmentButton
@onready var pets_button = $HubUI/TopBar/HBoxContainer/MenuButtons/PetsButton

@onready var mining_button = $HubUI/BottomBar/VBoxContainer/ActivityButtons/MiningButton
@onready var woodcutting_button = $HubUI/BottomBar/VBoxContainer/ActivityButtons/WoodcuttingButton
@onready var fishing_button = $HubUI/BottomBar/VBoxContainer/ActivityButtons/FishingButton

@onready var player_name_label = $HubUI/TopBar/HBoxContainer/PlayerInfo/PlayerName
@onready var total_level_label = $HubUI/TopBar/HBoxContainer/PlayerInfo/TotalLevel

# 3D Scene References
@onready var camera = $Camera3D
@onready var player_avatar = $PlayerAvatar

# UI Scenes
var inventory_ui = null
var crafting_ui = null
var skills_ui = null
var pets_ui = null
var equipment_ui = null

# Camera animation
var camera_rotation = 0.0
var camera_rotation_speed = 0.1

func _ready():
	print("\n=== MAIN HUB LOADED ===")
	
	# Connect UI buttons
	equipment_button.pressed.connect(_on_equipment_pressed)
	inventory_button.pressed.connect(_on_inventory_pressed)
	crafting_button.pressed.connect(_on_crafting_pressed)
	skills_button.pressed.connect(_on_skills_pressed)
	pets_button.pressed.connect(_on_pets_pressed)
	
	# Connect activity buttons
	mining_button.pressed.connect(_on_mining_pressed)
	woodcutting_button.pressed.connect(_on_woodcutting_pressed)
	fishing_button.pressed.connect(_on_fishing_pressed)
	
	
	# Update player info
	update_player_info()
	
	# Load UI scenes
	load_ui_scenes()

func _process(delta):
	# Slowly rotate camera around player
	camera_rotation += camera_rotation_speed * delta
	var radius = 5.0
	var height = 3.0
	camera.position.x = sin(camera_rotation) * radius
	camera.position.z = cos(camera_rotation) * radius
	camera.position.y = height
	camera.look_at(player_avatar.position, Vector3.UP)

func load_ui_scenes():
	# Load inventory UI
	var inventory_scene = load("res://UI/inventory_ui.tscn")
	if inventory_scene:
		inventory_ui = inventory_scene.instantiate()
		inventory_ui.visible = false
		$HubUI.add_child(inventory_ui)
		inventory_ui.inventory_closed.connect(_on_inventory_closed)
		print("Inventory UI loaded")
	else:
		print("WARNING: Could not load inventory_ui.tscn")
	
	# Load crafting UI
	var crafting_scene = load("res://UI/crafting_ui.tscn")
	if crafting_scene:
		crafting_ui = crafting_scene.instantiate()
		crafting_ui.visible = false
		$HubUI.add_child(crafting_ui)
		crafting_ui.crafting_closed.connect(_on_crafting_closed)
		print("Crafting UI loaded")
	else:
		print("WARNING: Could not load crafting_ui.tscn")
	
	# Load skills UI
	var skills_scene = load("res://UI/skills_ui.tscn")
	if skills_scene:
		skills_ui = skills_scene.instantiate()
		skills_ui.visible = false
		$HubUI.add_child(skills_ui)
		skills_ui.skills_closed.connect(_on_skills_closed)
		print("Skills UI loaded")
	else:
		print("WARNING: Could not load skills_ui.tscn")
	
	# Load equipment UI
	var equipment_scene = load("res://UI/equipment_ui.tscn")
	if equipment_scene:
		equipment_ui = equipment_scene.instantiate()
		equipment_ui.visible = false
		$HubUI.add_child(equipment_ui)
		equipment_ui.equipment_closed.connect(_on_equipment_closed)
		print("Equipment UI loaded")
	else:
		print("WARNING: Could not load equipment_ui.tscn")

func update_player_info():
	# Calculate total level
	var total_level = 0
	for skill_name in PlayerData.player_data["skills"]:
		total_level += PlayerData.get_skill_level(skill_name)
	
	player_name_label.text = "Player"
	total_level_label.text = "Total Level: " + str(total_level)

# ===== MENU BUTTON HANDLERS =====

func _on_inventory_pressed():
	print("Opening inventory...")
	close_all_menus()
	if inventory_ui:
		inventory_ui.show_inventory()

func _on_crafting_pressed():
	print("Opening crafting...")
	close_all_menus()
	if crafting_ui:
		crafting_ui.show_crafting()

func _on_skills_pressed():
	print("Opening skills...")
	close_all_menus()
	if skills_ui:
		skills_ui.show_skills()

func _on_equipment_pressed():
	print("Opening equipment...")
	close_all_menus()
	if equipment_ui:
		equipment_ui.show_equipment()

func _on_equipment_closed():
	print("Equipment closed")
	update_player_info()

func _on_pets_pressed():
	print("Pets menu coming soon!")

# ===== ACTIVITY BUTTON HANDLERS (GPS INTEGRATED) =====

func _on_mining_pressed():
	print("Starting mining minigame...")
	
	if not has_node("/root/GPSManager"):
		print("ERROR: GPSManager not available!")
		get_tree().change_scene_to_file("res://scenes/mining_mini.tscn")
		return
	
	var gps = get_node("/root/GPSManager")
	
	# Get ore type from current biome
	var ore_type = gps.get_biome_resource("mining")
	var ore_display_name = ItemDatabase.get_item_display_name(ore_type)
	
	print("Mining " + ore_display_name + " in " + gps.get_biome_name())
	
	# Store settings for minigame to pick up
	gps.set("pending_ore_type", get_ore_type_id(ore_type))
	gps.set("pending_ore_name", ore_type)
	
	# Change scene
	get_tree().change_scene_to_file("res://scenes/mining_mini.tscn")

func _on_woodcutting_pressed():
	print("Starting woodcutting minigame...")
	
	if not has_node("/root/GPSManager"):
		print("ERROR: GPSManager not available!")
		get_tree().change_scene_to_file("res://scenes/woodcutting_mini.tscn")
		return
	
	var gps = get_node("/root/GPSManager")
	
	# Get log type from current biome
	var log_type = gps.get_biome_resource("woodcutting")
	var log_display_name = ItemDatabase.get_item_display_name(log_type)
	
	print("Cutting " + log_display_name + " in " + gps.get_biome_name())
	
	# Store settings for minigame to pick up
	gps.set("pending_log_type", log_type)
	
	# Change scene
	get_tree().change_scene_to_file("res://scenes/woodcutting_mini.tscn")

func _on_fishing_pressed():
	print("Starting fishing minigame...")
	
	if not has_node("/root/GPSManager"):
		print("ERROR: GPSManager not available!")
		get_tree().change_scene_to_file("res://scenes/fishing_mini.tscn")
		return
	
	var gps = get_node("/root/GPSManager")
	
	# Get fish type from current biome
	var fish_type = gps.get_biome_resource("fishing")
	var fish_display_name = ItemDatabase.get_item_display_name(fish_type)
	
	print("Fishing for " + fish_display_name + " in " + gps.get_biome_name())
	
	# Store settings for minigame to pick up
	gps.set("pending_fish_type", fish_type)
	gps.set("pending_fish_name", fish_display_name)
	
	# Change scene
	get_tree().change_scene_to_file("res://scenes/fishing_mini.tscn")

func get_ore_type_id(ore_name: String) -> int:
	"""Convert ore name to ore type ID for mining minigame"""
	match ore_name:
		"copper_ore":
			return 0
		"tin_ore":
			return 1
		"iron_ore":
			return 2
		"coal":
			return 3
		"gold_ore":
			return 4
		"mithril_ore":
			return 5
		_:
			return 0  # Default to copper

func _on_inventory_closed():
	print("Inventory closed")
	update_player_info()

func _on_crafting_closed():
	print("Crafting closed")
	update_player_info()

func _on_skills_closed():
	print("Skills closed")
	update_player_info()

func close_all_menus():
	if inventory_ui and inventory_ui.visible:
		inventory_ui.hide_inventory()
	if crafting_ui and crafting_ui.visible:
		crafting_ui.hide_crafting()
	if skills_ui and skills_ui.visible:
		skills_ui.hide_skills()
	if equipment_ui and equipment_ui.visible:
		equipment_ui.hide_equipment()

# ===== INPUT HANDLING =====

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		# Close any open menus
		if inventory_ui and inventory_ui.visible:
			inventory_ui.hide_inventory()
		elif crafting_ui and crafting_ui.visible:
			crafting_ui.hide_crafting()
		elif skills_ui and skills_ui.visible:
			skills_ui.hide_skills()
		elif equipment_ui and equipment_ui.visible:
			equipment_ui.hide_equipment()

# ===== DEBUG FUNCTIONS =====

func _input(event):
	# Debug: Press T to add test items
	if event.is_action_pressed("ui_text_completion_accept"):
		print("Adding test items...")
		PlayerData.debug_add_test_items()
		update_player_info()
	
	# Debug: Press L to test biome changes
	if event.is_action_pressed("ui_page_down"):  # Page Down key
		print("Testing biome changes...")
		if has_node("/root/GPSManager"):
			var gps = get_node("/root/GPSManager")
			gps.test_biome_changes()

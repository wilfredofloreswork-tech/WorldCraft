extends Node3D
# MainHub.gd - Main 3D hub scene with map-textured ground and resource spawning

# UI References
@onready var inventory_button = $HubUI/TopBar/HBoxContainer/MenuButtons/InventoryButton
@onready var crafting_button = $HubUI/TopBar/HBoxContainer/MenuButtons/CraftingButton
@onready var skills_button = $HubUI/TopBar/HBoxContainer/MenuButtons/SkillsButton
@onready var equipment_button = $HubUI/TopBar/HBoxContainer/MenuButtons/EquipmentButton
@onready var pets_button = $HubUI/TopBar/HBoxContainer/MenuButtons/PetsButton
@onready var debug_location_label: Label = null

@onready var mining_button = $HubUI/BottomBar/VBoxContainer/ActivityButtons/MiningButton
@onready var woodcutting_button = $HubUI/BottomBar/VBoxContainer/ActivityButtons/WoodcuttingButton
@onready var fishing_button = $HubUI/BottomBar/VBoxContainer/ActivityButtons/FishingButton
@onready var combat_button = $HubUI/BottomBar/VBoxContainer/ActivityButtons/CombatButton

@onready var player_name_label = $HubUI/TopBar/HBoxContainer/PlayerInfo/PlayerName
@onready var total_level_label = $HubUI/TopBar/HBoxContainer/PlayerInfo/TotalLevel

# 3D Scene References
@onready var camera = $Camera3D
@onready var player_avatar = $PlayerAvatar
@onready var ground = $Ground
@onready var map_viewport = $MapViewport

# Ground material
var ground_material: StandardMaterial3D

# Resource spawning
var daily_seed: int = 0
var spawned_resources = {}
var resource_spawn_radius = 3  # How many cells around player to spawn resources

const DEFAULT_BIOME = "temperate"
const BIOME_SEQUENCE = ["forest", "mountain", "coast", "urban", "temperate"]
const BIOMES = {
	"forest": {
		"name": "🌲 Forest",
		"description": "Dense woodland area",
		"mining": "copper_ore",
		"woodcutting": "oak_log",
		"fishing": "raw_fish"
	},
	"mountain": {
		"name": "⛰️ Mountains",
		"description": "Rocky highland terrain",
		"mining": "iron_ore",
		"woodcutting": "oak_log",
		"fishing": "salmon"
	},
	"coast": {
		"name": "🏖️ Coastal",
		"description": "Seaside area",
		"mining": "gold_ore",
		"woodcutting": "oak_log",
		"fishing": "tuna"
	},
	"urban": {
		"name": "🏙️ Urban",
		"description": "City area",
		"mining": "coal",
		"woodcutting": "oak_log",
		"fishing": "raw_fish"
	},
	"temperate": {
		"name": "🌾 Temperate",
		"description": "Mixed terrain",
		"mining": "copper_ore",
		"woodcutting": "oak_log",
		"fishing": "raw_fish"
	}
}

# UI Scenes
var inventory_ui = null
var crafting_ui = null
var skills_ui = null
var pets_ui = null
var equipment_ui = null

# Camera controls
var camera_zoom = 15.0  # Distance from player
var camera_angle = 60.0  # Angle from vertical (degrees)
var camera_yaw = 0.0  # Rotation around player
var is_dragging = false
var last_mouse_pos = Vector2.ZERO
var drag_sensitivity = 0.3
var zoom_speed = 2.0
var min_zoom = 5.0
var max_zoom = 30.0

# Touch controls
var touch_points = {}  # Track multiple touch points
var initial_pinch_distance = 0.0
var is_pinching = false

func _ready():
	_setup_debug_display()
	_setup_map_ground()
	_setup_camera()
	_generate_daily_seed()
	
	# Connect to location changes to spawn resources
	if PraxisCore:
		PraxisCore.plusCode_changed.connect(_on_location_changed)
	
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
	combat_button.pressed.connect(_on_combat_pressed)
	
	# Update player info
	update_player_info()
	
	# Load UI scenes
	load_ui_scenes()
	
	# Wait a moment then apply map texture and spawn resources
	await get_tree().create_timer(2.0).timeout
	_apply_map_to_ground()
	
	# Spawn initial resources
	if PraxisCore and PraxisCore.currentPlusCode != "":
		_spawn_resources_around_player()
	else:
		# Try again after location is acquired
		await get_tree().create_timer(3.0).timeout
		if PraxisCore and PraxisCore.currentPlusCode != "":
			_spawn_resources_around_player()

func _setup_camera():
	"""Set up the camera in top-down view"""
	_update_camera_position()

func _update_camera_position():
	"""Update camera position - orbits around player while always looking at them"""
	if not camera or not player_avatar:
		return
	
	var angle_rad = deg_to_rad(camera_angle)
	var yaw_rad = deg_to_rad(camera_yaw)
	
	# Calculate camera position in a sphere around the player
	# Height component (vertical distance)
	var height = max(camera_zoom * cos(angle_rad), 0.1)  # Ensure minimum height
	# Horizontal distance from player
	var horizontal_distance = camera_zoom * sin(angle_rad)
	
	# Apply yaw rotation to determine position on the horizontal plane
	var offset_x = horizontal_distance * sin(yaw_rad)
	var offset_z = horizontal_distance * cos(yaw_rad)
	
	# Set camera position relative to player
	var new_position = Vector3(
		player_avatar.global_position.x + offset_x,
		player_avatar.global_position.y + height,
		player_avatar.global_position.z + offset_z
	)
	
	camera.global_position = new_position
	
	# Safety check: ensure camera is not at the same position as player
	var distance_to_player = camera.global_position.distance_to(player_avatar.global_position)
	if distance_to_player < 0.1:
		# If too close, push camera back slightly
		camera.global_position.y += 1.0
	
	# Always look at the player (this ensures camera faces character)
	# Use a safe look_at with error checking
	var look_direction = player_avatar.global_position - camera.global_position
	if look_direction.length() > 0.01:  # Only look_at if there's a valid direction
		camera.look_at(player_avatar.global_position, Vector3.UP)

func _generate_daily_seed():
	"""Generate today's seed (in real implementation, fetch from server)"""
	var now = Time.get_datetime_dict_from_system()
	var date_string = "%04d%02d%02d" % [now.year, now.month, now.day]
	daily_seed = date_string.hash()

func _setup_map_ground():
	"""Initialize the ground to use the SubViewport texture"""
	if not ground:
		return
	
	# Create material that will use the viewport texture
	ground_material = StandardMaterial3D.new()
	ground_material.albedo_color = Color(1, 1, 1)
	ground_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	ground.material_override = ground_material

func _apply_map_to_ground():
	"""Apply the ScrollingCenteredMap viewport texture to the ground"""
	if not map_viewport or not ground_material:
		return
	
	# Get the viewport texture
	var viewport_texture = map_viewport.get_texture()
	
	if viewport_texture:
		ground_material.albedo_texture = viewport_texture
	else:
		# Try again in a moment
		await get_tree().create_timer(1.0).timeout
		_apply_map_to_ground()

# ===== RESOURCE SPAWNING SYSTEM =====

func _on_location_changed(new_code: String, old_code: String):
	"""When player moves to new area, respawn resources"""
	if new_code.substr(0, 8) != old_code.substr(0, 8):
		_spawn_resources_around_player()

func _spawn_resources_around_player():
	"""Spawn resource nodes around the player's current location"""
	if not PraxisCore or PraxisCore.currentPlusCode == "":
		return
	
	# Clear old resources
	_clear_resources()
	
	var center_code = PraxisCore.currentPlusCode.substr(0, 8)
	
	# Spawn in a grid around player
	for x in range(-resource_spawn_radius, resource_spawn_radius + 1):
		for y in range(-resource_spawn_radius, resource_spawn_radius + 1):
			var cell_code = PlusCodes.ShiftCode(center_code, x, y)
			var resource = _generate_resource_for_cell(cell_code)
			
			if resource.has("type"):
				_spawn_resource_node(resource, x, y)

func _generate_resource_for_cell(pluscode: String) -> Dictionary:
	"""Generate a resource for a specific cell using deterministic seed"""
	
	# Combine daily seed with pluscode
	var combined_seed = _combine_seeds(daily_seed, pluscode)
	var rng = RandomNumberGenerator.new()
	rng.seed = combined_seed
	
	# 30% chance of having a resource
	if rng.randf() > 0.3:
		return {}
	
	# Random roll 1-10000 for resource type
	var roll = rng.randi_range(1, 10000)
	
	var resource_type = ""
	if roll <= 4000:  # 40% - Mining
		resource_type = "mining"
	elif roll <= 7000:  # 30% - Woodcutting
		resource_type = "woodcutting"
	elif roll <= 9000:  # 20% - Fishing
		resource_type = "fishing"
	else:  # 10% - Combat
		resource_type = "combat"
	
	return {
		"type": resource_type,
		"pluscode": pluscode,
		"quality": rng.randf_range(0.8, 1.2)
	}

func _combine_seeds(daily_seed: int, pluscode: String) -> int:
	"""Combine daily seed with pluscode for deterministic generation"""
	var pluscode_hash = pluscode.hash()
	return (daily_seed ^ pluscode_hash) & 0x7FFFFFFF

func _spawn_resource_node(resource: Dictionary, grid_x: int, grid_y: int):
	"""Create a 3D node for the resource"""
	
	var node = MeshInstance3D.new()
	var material = StandardMaterial3D.new()
	
	# Set mesh and color based on type
	match resource.type:
		"mining":
			var sphere = SphereMesh.new()
			sphere.radius = 0.3
			sphere.height = 0.6
			node.mesh = sphere
			material.albedo_color = Color.RED
		"woodcutting":
			var cube = BoxMesh.new()
			cube.size = Vector3(0.5, 0.8, 0.5)
			node.mesh = cube
			material.albedo_color = Color.GREEN
		"fishing":
			var cylinder = CylinderMesh.new()
			cylinder.top_radius = 0.25
			cylinder.bottom_radius = 0.25
			cylinder.height = 0.7
			node.mesh = cylinder
			material.albedo_color = Color.BLUE
		"combat":
			var capsule = CapsuleMesh.new()
			capsule.radius = 0.25
			capsule.height = 0.8
			node.mesh = capsule
			material.albedo_color = Color.YELLOW
	
	# Apply material
	material.emission_enabled = true
	material.emission = material.albedo_color * 0.5
	node.material_override = material
	
	# Store resource data in metadata
	node.set_meta("resource_type", resource.type)
	node.set_meta("pluscode", resource.pluscode)
	node.set_meta("quality", resource.quality)
	
	# Add to scene FIRST (before setting position)
	add_child(node)
	spawned_resources[resource.pluscode] = node
	
	# THEN position in world (scale: each cell = ~10 units)
	var world_pos = Vector3(grid_x * 10.0, 0.5, -grid_y * 10.0)
	# Add slight random offset within cell
	var rng = RandomNumberGenerator.new()
	rng.seed = resource.pluscode.hash()
	world_pos.x += rng.randf_range(-3, 3)
	world_pos.z += rng.randf_range(-3, 3)
	
	node.global_position = world_pos
	
	# Make it clickable - Create proper collision hierarchy
	var collision = StaticBody3D.new()
	collision.name = "CollisionBody"
	var shape = CollisionShape3D.new()
	shape.name = "CollisionShape"
	var collision_shape = SphereShape3D.new()
	collision_shape.radius = 0.5
	shape.shape = collision_shape
	
	# Add shape to collision body, then collision body to node
	collision.add_child(shape)
	node.add_child(collision)

func _clear_resources():
	"""Remove all spawned resource nodes"""
	for pluscode in spawned_resources:
		var node = spawned_resources[pluscode]
		if is_instance_valid(node):
			node.queue_free()
	spawned_resources.clear()

# ===== RESOURCE INTERACTION =====

func _input(event):
	# Handle touch input for mobile
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)
	
	# Handle mouse input for desktop
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				is_dragging = true
				last_mouse_pos = event.position
			else:
				is_dragging = false
		
		# Zoom - Mouse wheel
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_zoom = max(min_zoom, camera_zoom - zoom_speed)
			_update_camera_position()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_zoom = min(max_zoom, camera_zoom + zoom_speed)
			_update_camera_position()
		
		# Click to collect resources - Left mouse button
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_check_resource_click(event.position)
	
	# Camera drag (desktop)
	elif event is InputEventMouseMotion and is_dragging:
		var delta = event.position - last_mouse_pos
		camera_yaw += delta.x * drag_sensitivity
		# Immediately update camera position while dragging
		_update_camera_position()
		last_mouse_pos = event.position
	
	# Debug: Press T to add test items
	if event.is_action_pressed("ui_text_completion_accept"):
		PlayerData.debug_add_test_items()
		update_player_info()

func _handle_touch(event: InputEventScreenTouch):
	"""Handle touch press/release events"""
	if event.pressed:
		# Touch started
		touch_points[event.index] = event.position
		
		if touch_points.size() == 1:
			# Single touch - could be tap or start of drag
			last_mouse_pos = event.position
		elif touch_points.size() == 2:
			# Two fingers - start pinch zoom
			is_pinching = true
			var points = touch_points.values()
			initial_pinch_distance = points[0].distance_to(points[1])
	else:
		# Touch released
		if touch_points.size() == 1 and not is_dragging:
			# Single tap - try to collect resource
			_check_resource_click(event.position)
		
		touch_points.erase(event.index)
		
		if touch_points.size() < 2:
			is_pinching = false
		
		if touch_points.size() == 0:
			is_dragging = false

func _handle_drag(event: InputEventScreenDrag):
	"""Handle touch drag events"""
	touch_points[event.index] = event.position
	
	if is_pinching and touch_points.size() == 2:
		# Pinch zoom with two fingers
		var points = touch_points.values()
		var current_distance = points[0].distance_to(points[1])
		var zoom_delta = (initial_pinch_distance - current_distance) * 0.05
		camera_zoom = clamp(camera_zoom + zoom_delta, min_zoom, max_zoom)
		initial_pinch_distance = current_distance
		_update_camera_position()
	elif touch_points.size() == 1:
		# Single finger drag - rotate camera
		is_dragging = true
		var delta = event.position - last_mouse_pos
		camera_yaw += delta.x * drag_sensitivity * 0.5  # Slightly less sensitive on mobile
		_update_camera_position()
		last_mouse_pos = event.position

func _check_resource_click(mouse_pos: Vector2):
	"""Check if player clicked on a resource node - Web-compatible version"""
	if not camera:
		return
	
	# Instead of physics raycast, check all spawned resources manually
	var closest_resource = null
	var closest_distance = 999999.0
	
	for pluscode in spawned_resources:
		var node = spawned_resources[pluscode]
		if not is_instance_valid(node):
			continue
		
		# Project resource position to screen space
		var screen_pos = camera.unproject_position(node.global_position)
		
		# Check if click is near this resource on screen
		var distance = mouse_pos.distance_to(screen_pos)
		
		# If within 50 pixels and closer than previous matches
		if distance < 50.0 and distance < closest_distance:
			closest_distance = distance
			closest_resource = node
	
	if closest_resource:
		_collect_resource(closest_resource)

func _collect_resource(node: Node3D):
	"""Collect a resource node"""
	var resource_type = node.get_meta("resource_type")
	var pluscode = node.get_meta("pluscode")
	var quality = node.get_meta("quality")
	
	# Add visual feedback
	var tween = create_tween()
	tween.tween_property(node, "scale", Vector3.ZERO, 0.3)
	tween.tween_callback(node.queue_free)
	
	# Remove from tracking
	spawned_resources.erase(pluscode)
	
	# Start the appropriate minigame
	var scene_path = ""
	match resource_type:
		"mining":
			scene_path = "res://scenes/mining_mini.tscn"
		"woodcutting":
			scene_path = "res://scenes/woodcutting_mini.tscn"
		"fishing":
			scene_path = "res://scenes/fishing_mini.tscn"
		"combat":
			scene_path = "res://scenes/circular_combat_scene.tscn"
	
	if scene_path != "" and ResourceLoader.exists(scene_path):
		get_tree().change_scene_to_file(scene_path)

# ===== CAMERA & RENDERING =====

func _process(delta):
	# Update camera position every frame to ensure smooth movement
	_update_camera_position()
	
	if debug_location_label:
		_update_debug_display()

# ===== UI MANAGEMENT =====

func load_ui_scenes():
	# Load inventory UI
	var inventory_scene = load("res://UI/inventory_ui.tscn")
	if inventory_scene:
		inventory_ui = inventory_scene.instantiate()
		inventory_ui.visible = false
		$HubUI.add_child(inventory_ui)
		inventory_ui.inventory_closed.connect(_on_inventory_closed)
	
	# Load crafting UI
	var crafting_scene = load("res://UI/crafting_ui.tscn")
	if crafting_scene:
		crafting_ui = crafting_scene.instantiate()
		crafting_ui.visible = false
		$HubUI.add_child(crafting_ui)
		crafting_ui.crafting_closed.connect(_on_crafting_closed)
	
	# Load skills UI
	var skills_scene = load("res://UI/skills_ui.tscn")
	if skills_scene:
		skills_ui = skills_scene.instantiate()
		skills_ui.visible = false
		$HubUI.add_child(skills_ui)
		skills_ui.skills_closed.connect(_on_skills_closed)
	
	# Load equipment UI
	var equipment_scene = load("res://UI/equipment_UI.tscn")
	if equipment_scene:
		equipment_ui = equipment_scene.instantiate()
		equipment_ui.visible = false
		$HubUI.add_child(equipment_ui)
		equipment_ui.equipment_closed.connect(_on_equipment_closed)

func update_player_info():
	# Calculate total level
	var total_level = 0
	for skill_name in PlayerData.player_data["skills"]:
		total_level += PlayerData.get_skill_level(skill_name)
	
	player_name_label.text = "Player"
	total_level_label.text = "Total Level: " + str(total_level)

# ===== MENU BUTTON HANDLERS =====

func _on_inventory_pressed():
	close_all_menus()
	if inventory_ui:
		inventory_ui.show_inventory()

func _on_crafting_pressed():
	close_all_menus()
	if crafting_ui:
		crafting_ui.show_crafting()

func _on_skills_pressed():
	close_all_menus()
	if skills_ui:
		skills_ui.show_skills()

func _on_equipment_pressed():
	close_all_menus()
	if equipment_ui:
		equipment_ui.show_equipment()

func _on_equipment_closed():
	update_player_info()

func _on_pets_pressed():
	pass  # Pets menu coming soon

# ===== ACTIVITY BUTTON HANDLERS =====

func _on_mining_pressed():
	get_tree().change_scene_to_file("res://scenes/mining_mini.tscn")

func _on_woodcutting_pressed():
	get_tree().change_scene_to_file("res://scenes/woodcutting_mini.tscn")

func _on_fishing_pressed():
	get_tree().change_scene_to_file("res://scenes/fishing_mini.tscn")

func _on_combat_pressed():
	get_tree().change_scene_to_file("res://scenes/circular_combat_scene.tscn")

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
	update_player_info()

func _on_crafting_closed():
	update_player_info()

func _on_skills_closed():
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

# ===== DEBUG DISPLAY =====

func _setup_debug_display():
	# Create a label for debug info
	debug_location_label = Label.new()
	debug_location_label.name = "DebugLocationLabel"
	debug_location_label.position = Vector2(10, 10)
	debug_location_label.z_index = 1000
	
	# Style it
	debug_location_label.add_theme_font_size_override("font_size", 18)
	debug_location_label.add_theme_color_override("font_color", Color.WHITE)
	debug_location_label.add_theme_color_override("font_outline_color", Color.BLACK)
	debug_location_label.add_theme_constant_override("outline_size", 3)
	
	# Add to HubUI so it's always on top
	$HubUI/Panel.add_child(debug_location_label)
	
func _update_debug_display():
	if PraxisCore == null:
		debug_location_label.text = "PraxisCore not found"
		return
	
	var plus_code = PraxisCore.currentPlusCode
	var lat = 0.0
	var lon = 0.0
	
	# Try to get location from PraxisCore
	if PraxisCore.last_location and typeof(PraxisCore.last_location) == TYPE_DICTIONARY:
		lat = float(PraxisCore.last_location.get("latitude", 0.0))
		lon = float(PraxisCore.last_location.get("longitude", 0.0))
	
	# Calculate biome
	var biome_name = _get_biome_display_name()
	
	var resource_count = spawned_resources.size()
	
	debug_location_label.text = "Plus Code: %s\nLat/Lon: %.6f, %.6f\nBiome: %s\nResources: %d" % [
		plus_code if plus_code != "" else "N/A",
		lat,
		lon,
		biome_name,
		resource_count
	]

func _get_biome_display_name() -> String:
	var lat = 0.0
	var lon = 0.0
	
	if PraxisCore and PraxisCore.last_location:
		lat = float(PraxisCore.last_location.get("latitude", 0.0))
		lon = float(PraxisCore.last_location.get("longitude", 0.0))
	
	var biome_id = _calculate_biome(lat, lon)
	return BIOMES.get(biome_id, BIOMES[DEFAULT_BIOME]).get("name", "Unknown")

func _calculate_biome(lat: float, lon: float) -> String:
	if BIOME_SEQUENCE.is_empty():
		return DEFAULT_BIOME

	var lat_zone = posmod(int(floor(lat * 10.0)), BIOME_SEQUENCE.size())
	var lon_zone = posmod(int(floor(lon * 10.0)), BIOME_SEQUENCE.size())
	var index = (lat_zone + lon_zone) % BIOME_SEQUENCE.size()
	return BIOME_SEQUENCE[index]

# ===== DEBUG PRINT STATEMENTS (COMMENTED OUT) =====
# Uncomment these for debugging specific issues

# In _ready():
#print("\n=== MAIN HUB LOADED ===")
#print("Checking if we can spawn resources...")
#print("PraxisCore exists: ", PraxisCore != null)
#if PraxisCore:
#	print("Current pluscode: ", PraxisCore.currentPlusCode)
#print("Cannot spawn resources - waiting for location")
#print("Location acquired! Spawning resources now...")

# In _generate_daily_seed():
#print("Daily seed: ", daily_seed)

# In _setup_map_ground():
#print("Ground mesh not found!")
#print("Map ground initialized")

# In _apply_map_to_ground():
#print("ERROR: MapViewport or ground material not found!")
#print("Map texture applied to ground!")
#print("ERROR: Could not get viewport texture")

# In _spawn_resources_around_player():
#print("ERROR: Cannot spawn - no location data")
#print("=== SPAWNING RESOURCES ===")
#print("Player location: ", PraxisCore.currentPlusCode)
#print("Daily seed: ", daily_seed)
#print("Base code: ", center_code)
#print("Spawning ", resource.type, " at grid [", x, ",", y, "] - ", cell_code)
#print("=== SPAWNED ", spawn_count, " RESOURCES ===")

# In _spawn_resource_node():
#print("Creating node for ", resource.type, " at [", grid_x, ",", grid_y, "]")
#print("Node positioned at: ", world_pos)
#print("Node added to scene: ", node.name)
#print("Collision setup complete for ", resource.type, " node")
#print("  - Node path: ", node.get_path())
#print("  - Collision path: ", collision.get_path())
#print("  - Has meta 'resource_type': ", node.has_meta("resource_type"))

# In _check_resource_click():
#print("ERROR: Camera not found in _check_resource_click")
#print("Checking resource click at mouse pos: ", mouse_pos)
#print("Ray from: ", from, " direction: ", ray_dir)
#print("Found closest resource at distance: ", closest_distance)
#print("No resource clicked. Checked ", spawned_resources.size(), " resources")

# In _collect_resource():
#print("=== COLLECTING RESOURCE ===")
#print("Type: ", resource_type)
#print("Pluscode: ", pluscode)
#print("Quality: ", quality)
#print("→ Opening Mining minigame: ", scene_path)
#print("→ Opening Woodcutting minigame: ", scene_path)
#print("→ Opening Fishing minigame: ", scene_path)
#print("→ Opening Combat: ", scene_path)
#print("Checking if scene exists...")
#print("Scene exists! Attempting to change scene...")
#print("Scene change result code: ", error)
#print("ERROR: Failed to change scene. Error code: ", error)
#print("ERROR: Scene file does not exist: ", scene_path)
#print("ERROR: No scene path determined for resource type: ", resource_type)

# In load_ui_scenes():
#print("Inventory UI loaded")
#print("WARNING: Could not load inventory_ui.tscn")
#print("Crafting UI loaded")
#print("WARNING: Could not load crafting_ui.tscn")
#print("Skills UI loaded")
#print("WARNING: Could not load skills_ui.tscn")
#print("Equipment UI loaded")
#print("WARNING: Could not load equipment_UI.tscn")

# In menu handlers:
#print("Opening inventory...")
#print("Opening crafting...")
#print("Opening skills...")
#print("Opening equipment...")
#print("Equipment closed")
#print("Inventory closed")
#print("Crafting closed")
#print("Skills closed")
#print("Pets menu coming soon!")

# In activity handlers:
#print("Starting mining minigame...")
#print("Starting woodcutting minigame...")
#print("Starting fishing minigame...")
#print("Starting combat...")
#print("Adding test items...")

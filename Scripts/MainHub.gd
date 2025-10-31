
extends Node3D
# MainHub.gd - Main 3D hub scene with map-textured ground and resource spawning

# ===== UI REFERENCES =====
@onready var inventory_button = $HubUI/TopBar/HBoxContainer/MenuButtons/InventoryButton
@onready var crafting_button = $HubUI/TopBar/HBoxContainer/MenuButtons/CraftingButton
@onready var skills_button = $HubUI/TopBar/HBoxContainer/MenuButtons/SkillsButton
@onready var equipment_button = $HubUI/TopBar/HBoxContainer/MenuButtons/EquipmentButton
@onready var pets_button = $HubUI/TopBar/HBoxContainer/MenuButtons/PetsButton

@onready var mining_button = $HubUI/BottomBar/VBoxContainer/ActivityButtons/MiningButton
@onready var woodcutting_button = $HubUI/BottomBar/VBoxContainer/ActivityButtons/WoodcuttingButton
@onready var fishing_button = $HubUI/BottomBar/VBoxContainer/ActivityButtons/FishingButton
@onready var combat_button = $HubUI/BottomBar/VBoxContainer/ActivityButtons/CombatButton

@onready var player_name_label = $HubUI/TopBar/HBoxContainer/PlayerInfo/PlayerName
@onready var total_level_label = $HubUI/TopBar/HBoxContainer/PlayerInfo/TotalLevel

# ===== 3D SCENE REFERENCES =====
@onready var camera = $Camera3D
@onready var player_avatar = $PlayerAvatar
@onready var ground = $Ground
@onready var map_viewport = $MapViewport

# ===== MAP TRACKING =====
var map_origin_lat: float = 0.0  # Fixed reference point
var map_origin_lon: float = 0.0
var map_center_lat: float = 0.0
var map_center_lon: float = 0.0
var meters_per_unit: float = 4.08  # How many real-world meters = 1 3D unit

# ===== DEBUG =====
@onready var debug_location_label: Label = null

# ===== MATERIALS =====
var ground_material: StandardMaterial3D

# ===== RESOURCE SPAWNING =====
var daily_seed: int = 0
var spawned_resources = {}
var resource_spawn_radius = 2
var active_cells = {}  # Track which cells are currently loaded

# ===== BIOME SYSTEM =====
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

# ===== UI SCENES =====
var inventory_ui = null
var crafting_ui = null
var skills_ui = null
var pets_ui = null
var equipment_ui = null

# ===== CAMERA CONTROLS =====
var camera_zoom = 15.0
var camera_angle = 60.0
var camera_yaw = 0.0
var is_dragging = false
var last_mouse_pos = Vector2.ZERO
var drag_sensitivity = 0.3
var zoom_speed = 2.0
var min_zoom = 5.0
var max_zoom = 30.0

# ===== TOUCH CONTROLS =====
var touch_points = {}
var initial_pinch_distance = 0.0
var is_pinching = false

# ===== INITIALIZATION =====

func _ready():
	_setup_debug_display()
	_setup_map_ground()
	_setup_camera()
	_generate_daily_seed()
	_connect_signals()
	_load_ui_scenes()
	update_player_info()

	
	# Apply map texture and spawn resources after short delay
	#await get_tree().create_timer(2.0).timeout
	_apply_map_to_ground()
	
	# Get initial map center
	_update_map_center()
	
	if PraxisCore and PraxisCore.currentPlusCode != "":
		_spawn_resources_around_player()
	else:
		# Retry if location not yet acquired
		await get_tree().create_timer(3.0).timeout
		if PraxisCore and PraxisCore.currentPlusCode != "":
			_spawn_resources_around_player()

func _connect_signals():
	"""Connect all button and system signals"""
	# PraxisCore location changes
	if PraxisCore:
		PraxisCore.plusCode_changed.connect(_on_location_changed)
	
	# Menu buttons
	equipment_button.pressed.connect(_on_equipment_pressed)
	inventory_button.pressed.connect(_on_inventory_pressed)
	crafting_button.pressed.connect(_on_crafting_pressed)
	skills_button.pressed.connect(_on_skills_pressed)
	pets_button.pressed.connect(_on_pets_pressed)
	
	# Activity buttons
	mining_button.pressed.connect(_on_mining_pressed)
	woodcutting_button.pressed.connect(_on_woodcutting_pressed)
	fishing_button.pressed.connect(_on_fishing_pressed)
	combat_button.pressed.connect(_on_combat_pressed)

func _load_ui_scenes():
	"""Load all UI scene instances"""
	# Inventory
	var inventory_scene = load("res://UI/inventory_ui.tscn")
	if inventory_scene:
		inventory_ui = inventory_scene.instantiate()
		inventory_ui.visible = false
		$HubUI.add_child(inventory_ui)
		inventory_ui.inventory_closed.connect(_on_inventory_closed)
	
	# Crafting
	var crafting_scene = load("res://UI/crafting_ui.tscn")
	if crafting_scene:
		crafting_ui = crafting_scene.instantiate()
		crafting_ui.visible = false
		$HubUI.add_child(crafting_ui)
		crafting_ui.crafting_closed.connect(_on_crafting_closed)
	
	# Skills
	var skills_scene = load("res://UI/skills_ui.tscn")
	if skills_scene:
		skills_ui = skills_scene.instantiate()
		skills_ui.visible = false
		$HubUI.add_child(skills_ui)
		skills_ui.skills_closed.connect(_on_skills_closed)
	
	# Equipment
	var equipment_scene = load("res://UI/equipment_UI.tscn")
	if equipment_scene:
		equipment_ui = equipment_scene.instantiate()
		equipment_ui.visible = false
		$HubUI.add_child(equipment_ui)
		equipment_ui.equipment_closed.connect(_on_equipment_closed)

# ===== CAMERA SYSTEM =====

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
	var height = max(camera_zoom * cos(angle_rad), 0.1)
	var horizontal_distance = camera_zoom * sin(angle_rad)
	
	# Apply yaw rotation
	var offset_x = horizontal_distance * sin(yaw_rad)
	var offset_z = horizontal_distance * cos(yaw_rad)
	
	# Set camera position
	var new_position = Vector3(
		player_avatar.global_position.x + offset_x,
		player_avatar.global_position.y + height,
		player_avatar.global_position.z + offset_z
	)
	
	camera.global_position = new_position
	
	# Safety check: ensure camera is not at the same position as player
	var distance_to_player = camera.global_position.distance_to(player_avatar.global_position)
	if distance_to_player < 0.1:
		camera.global_position.y += 1.0
	
	# Always look at the player
	var look_direction = player_avatar.global_position - camera.global_position
	if look_direction.length() > 0.01:
		camera.look_at(player_avatar.global_position, Vector3.UP)

# ===== MAP & GROUND SYSTEM =====

func _setup_map_ground():
	"""Initialize the ground to use the SubViewport texture"""
	if not ground:
		return
	
	ground_material = StandardMaterial3D.new()
	ground_material.albedo_color = Color(1, 1, 1)
	ground_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	ground.material_override = ground_material

func _apply_map_to_ground():
	"""Apply the ScrollingCenteredMap viewport texture to the ground"""
	if not map_viewport or not ground_material:
		return
	
	var viewport_texture = map_viewport.get_texture()
	
	if viewport_texture:
		ground_material.albedo_texture = viewport_texture
	else:
		# Retry
		await get_tree().create_timer(1.0).timeout
		_apply_map_to_ground()

func _process(_delta):
	# Update camera position every frame for smooth movement
	_update_camera_position()
	
	# Update map center and resource positions as player moves
	var old_center_lat = map_center_lat
	var old_center_lon = map_center_lon
	_update_map_center()
	
	# Only update resource positions if map center actually changed
	if old_center_lat != map_center_lat or old_center_lon != map_center_lon:
		_update_all_resource_positions()

	if debug_location_label:
		_update_debug_display()

# ===== RESOURCE SPAWNING SYSTEM =====

func _generate_daily_seed():
	"""Generate today's seed (in real implementation, fetch from server)"""
	var now = Time.get_datetime_dict_from_system()
	var date_string = "%04d%02d%02d" % [now.year, now.month, now.day]
	daily_seed = date_string.hash()

func _on_location_changed(new_code: String, old_code: String):
	"""When player moves to new area, update resources intelligently"""
	_update_map_center()
	
	# Always update positions since map moved
	_update_all_resource_positions()
	
	# If we moved to a new cell, check which resources need spawning/despawning
	if new_code.substr(0, 8) != old_code.substr(0, 8):
		_update_resource_spawns()

func _spawn_resources_around_player():
	"""Initial spawn of resources around the player's current location"""
	if not PraxisCore or PraxisCore.currentPlusCode == "":
		print("Cannot spawn resources - no Plus Code")
		return
	
	# Set the fixed map origin the first time
	if map_origin_lat == 0.0 and map_origin_lon == 0.0:
		_update_map_center()
		map_origin_lat = map_center_lat
		map_origin_lon = map_center_lon
		#print("Set map origin to: ", map_origin_lat, ", ", map_origin_lon)
	
	var center_code = PraxisCore.currentPlusCode.substr(0, 8)
	#print("=== INITIAL RESOURCE SPAWN ===")
	#print("Center code: ", center_code)
	
	_update_resource_spawns()


func _update_resource_spawns():
	"""Smart resource spawning - only add/remove what's needed"""
	if not PraxisCore or PraxisCore.currentPlusCode == "":
		return
	
	var center_code = PraxisCore.currentPlusCode.substr(0, 8)
	var cells_in_range = {}
	
	# Build list of cells that should be loaded
	for x in range(-resource_spawn_radius, resource_spawn_radius + 1):
		for y in range(-resource_spawn_radius, resource_spawn_radius + 1):
			var cell_code = PlusCodes.ShiftCode(center_code, x, y)
			cells_in_range[cell_code] = true
	
	# Remove resources from cells no longer in range
	for cell_code in active_cells.keys():
		if not cells_in_range.has(cell_code):
			_despawn_cell_resources(cell_code)
	
	# Spawn resources for new cells in range
	var spawn_count = 0
	for cell_code in cells_in_range.keys():
		if not active_cells.has(cell_code):
			_spawn_cell_resources(cell_code)
			spawn_count += 1
	
	if spawn_count > 0:
		print("Spawned resources for ", spawn_count, " new cells")

func _spawn_cell_resources(cell_code: String):
	"""Spawn all resources for a specific cell"""
	active_cells[cell_code] = true
	
	# 3 spawn attempts per cell with decreasing probability
	for attempt in range(3):
		var spawn_chance = 1.0  # 100% for first attempt
		if attempt == 1:
			spawn_chance = 0.8  # 80% for second attempt
		elif attempt == 2:
			spawn_chance = 0.6  # 60% for third attempt
		
		var resource = await _generate_resource_for_cell(cell_code, attempt, spawn_chance)
		
		if resource.has("type"):
			_spawn_resource_node(resource)

func _despawn_cell_resources(cell_code: String):
	"""Remove all resources from a specific cell"""
	active_cells.erase(cell_code)
	
	# Remove all resources that belong to this cell
	var resources_to_remove = []
	for pluscode in spawned_resources.keys():
		if pluscode.begins_with(cell_code):
			resources_to_remove.append(pluscode)
	
	for pluscode in resources_to_remove:
		var node = spawned_resources[pluscode]
		if is_instance_valid(node):
			node.queue_free()
		spawned_resources.erase(pluscode)

func _generate_resource_for_cell(pluscode: String, attempt: int, spawn_chance: float) -> Dictionary:
	"""Generate a resource for a specific cell using deterministic seed AND biome data"""
	# Create deterministic seed
	var seed_string = ""
	if attempt == 0:
		seed_string = "PRIMARY_" + pluscode
	elif attempt == 1:
		seed_string = "SECONDARY_" + pluscode
	elif attempt == 2:
		seed_string = "TERTIARY_" + pluscode
	
	var combined_seed = _combine_seeds(daily_seed, seed_string)
	var rng = RandomNumberGenerator.new()
	rng.seed = combined_seed
	
	# Check spawn chance
	if rng.randf() > spawn_chance:
		return {}
	
	# Get biome data from PraxisOfflineData
        var biome_data = PraxisOfflineData.GetBiomeDataForCell(pluscode)
	var spawn_weights = biome_data["spawn_weights"]
	
	# Calculate weighted random selection
	var total_weight = 0.0
	for resource_type in spawn_weights:
		total_weight += spawn_weights[resource_type]
	
	var roll = rng.randf() * total_weight
	var cumulative = 0.0
	var resource_type = "mining"  # default
	
	for res_type in spawn_weights:
		cumulative += spawn_weights[res_type]
		if roll <= cumulative:
			resource_type = res_type
			break
	
	return {
		"type": resource_type,
		"pluscode": pluscode + "_" + str(attempt),
		"quality": rng.randf_range(0.8, 1.2)
	}

func _combine_seeds(daily_seed_val: int, pluscode_with_prefix: String) -> int:
	"""Combine daily seed with pluscode for deterministic generation"""
	var pluscode_hash = pluscode_with_prefix.hash()
	return (daily_seed_val ^ pluscode_hash) & 0x7FFFFFFF

func _spawn_resource_node(resource: Dictionary):
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
	
	# Apply material with emission
	material.emission_enabled = true
	material.emission = material.albedo_color * 0.5
	node.material_override = material
	
	# Store resource data in metadata
	node.set_meta("resource_type", resource.type)
	node.set_meta("pluscode", resource.pluscode)
	node.set_meta("quality", resource.quality)
	
	# Calculate and store the real-world lat/lon for this resource
	var resource_lat_lon = _calculate_resource_lat_lon(resource.pluscode)
	node.set_meta("latitude", resource_lat_lon.x)
	node.set_meta("longitude", resource_lat_lon.y)
	
	# Add to scene first
	add_child(node)
	spawned_resources[resource.pluscode] = node
	
	# Position based on lat/lon - FIXED to map, not player
	_update_resource_position(node)
	#print("Resource spawn: ", resource.type, " @ ", node.global_position)
	
	# Make it clickable - Create proper collision hierarchy
	var collision = StaticBody3D.new()
	collision.name = "CollisionBody"
	var shape = CollisionShape3D.new()
	shape.name = "CollisionShape"
	var collision_shape = SphereShape3D.new()
	collision_shape.radius = 0.5
	shape.shape = collision_shape
	
	collision.add_child(shape)
	node.add_child(collision)

func _clear_resources():
	"""Remove all spawned resource nodes"""
	for pluscode in spawned_resources:
		var node = spawned_resources[pluscode]
		if is_instance_valid(node):
			node.queue_free()
	spawned_resources.clear()
	active_cells.clear()

# ===== RESOURCE INTERACTION =====

func _calculate_resource_lat_lon(pluscode: String) -> Vector2:
	"""Convert a pluscode to lat/lon coordinates"""
	# Extract attempt number from pluscode (format: "PLUSCODE_0", "PLUSCODE_1", etc.)
	var pluscode_parts = pluscode.split("_")
	var base_pluscode = pluscode_parts[0]
	var attempt = 0
	if pluscode_parts.size() > 1:
		attempt = int(pluscode_parts[1])
	
	var center = PlusCodes.Decode(base_pluscode)
	
	if center and center != Vector2.ZERO:
		# Check if PlusCodes.decode returns (lat, lon) or (lon, lat)
		# Based on the output, it seems to return (lon, lat) - let's swap them
		var center_lat = center.y  # Second component is latitude
		var center_lon = center.x  # First component is longitude
		
		#print("Decoding pluscode: ", pluscode, " -> lat:", center_lat, " lon:", center_lon)
		
		# Add random offset within the cell for variety - use attempt number for unique positioning
		var rng = RandomNumberGenerator.new()
		rng.seed = pluscode.hash()
		# Plus code cell is approximately 0.000125 degrees (14m x 14m at equator)
		var cell_size = 0.000125
		
		# Generate different offsets based on attempt number
		for i in range(attempt + 1):
			var offset_lat = rng.randf_range(-cell_size * 20, cell_size * 20)
			var offset_lon = rng.randf_range(-cell_size * 20, cell_size * 20)
			if i == attempt:
				center_lat += offset_lat
				center_lon += offset_lon
		
		return Vector2(center_lat, center_lon)
	
	# Fallback: if decode fails, use a simple grid offset from current position
	#print("WARNING: Could not decode pluscode, using fallback positioning")
	return Vector2(map_center_lat, map_center_lon)

func _update_map_center():
	"""Update the current map center coordinates"""
	if PraxisCore and PraxisCore.last_location:
		var new_lat = float(PraxisCore.last_location.get("latitude", 0.0))
		var new_lon = float(PraxisCore.last_location.get("longitude", 0.0))
		
		# In debug mode, coordinates might be fake (like 1.0, 1.0)
		# If we detect obviously fake coords, decode from Plus Code instead
		if (new_lat == 1.0 and new_lon == 1.0) or (abs(new_lat) < 0.01 and abs(new_lon) < 0.01):
			if PraxisCore.currentPlusCode != "":
				var decoded = PlusCodes.Decode(PraxisCore.currentPlusCode)
				if decoded and decoded != Vector2.ZERO:
					map_center_lat = decoded.y  # lat
					map_center_lon = decoded.x  # lon
					return
		
		map_center_lat = new_lat
		map_center_lon = new_lon

func _lat_lon_to_3d_position(lat: float, lon: float) -> Vector3:
	"""Convert lat/lon to 3D world position - relative to current map center"""
	# Calculate offset in degrees from the current map center (where player is)
		# Calculate offset from the FIXED map origin, not current position
	var lat_offset = lat - map_center_lat
	var lon_offset = lon - map_center_lon
	
	# Convert to meters (approximate)
	var meters_per_degree_lat = 111320.0  # roughly constant
	var meters_per_degree_lon = 111320.0 * cos(deg_to_rad(map_center_lat))
	
	var meters_north = lat_offset * meters_per_degree_lat
	var meters_east = lon_offset * meters_per_degree_lon
	
	# Convert to 3D units - positioned relative to world origin
	# X = East/West, Z = North/South (negative because north is -Z in Godot)
	var x = meters_east / meters_per_unit
	var z = -meters_north / meters_per_unit
	
	return Vector3(x, 0.5, z)  # Y=0.5 to float above ground

func _update_resource_position(node: Node3D):
	"""Update a single resource's position based on its lat/lon"""
	if not node.has_meta("latitude") or not node.has_meta("longitude"):
		return
	
	var lat = node.get_meta("latitude")
	var lon = node.get_meta("longitude")
	
	node.global_position = _lat_lon_to_3d_position(lat, lon)

func _update_all_resource_positions():
	"""Update all resource positions when player moves"""
	for pluscode in spawned_resources:
		var node = spawned_resources[pluscode]
		if is_instance_valid(node):
			_update_resource_position(node)

func _check_resource_click(mouse_pos: Vector2):
	"""Check if player clicked on a resource node - Web-compatible version"""
	if not camera:
		return
	
	# Check all spawned resources manually
	var closest_resource = null
	var closest_distance = 999999.0
	
	for pluscode in spawned_resources:
		var node = spawned_resources[pluscode]
		if not is_instance_valid(node):
			continue
		
		# Project resource position to screen space
		var screen_pos = camera.unproject_position(node.global_position)
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

# ===== INPUT HANDLING =====

func _input(event):
	# Handle touch input for mobile
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)
	
	# Handle mouse input for desktop
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_dragging = event.pressed
			if event.pressed:
				last_mouse_pos = event.position
		
		# Zoom - Mouse wheel
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_zoom = max(min_zoom, camera_zoom - zoom_speed)
			_update_camera_position()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_zoom = min(max_zoom, camera_zoom + zoom_speed)
			_update_camera_position()
		
		# Click to collect resources
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_check_resource_click(event.position)
	
	# Camera drag (desktop)
	elif event is InputEventMouseMotion and is_dragging:
		var delta = event.position - last_mouse_pos
		camera_yaw += delta.x * drag_sensitivity
		_update_camera_position()
		last_mouse_pos = event.position
	
	# Debug: Press T to add test items
	if event.is_action_pressed("ui_text_completion_accept"):
		PlayerData.debug_add_test_items()
		update_player_info()

func _handle_touch(event: InputEventScreenTouch):
	"""Handle touch press/release events"""
	if event.pressed:
		touch_points[event.index] = event.position
		
		if touch_points.size() == 1:
			last_mouse_pos = event.position
		elif touch_points.size() == 2:
			# Two fingers - start pinch zoom
			is_pinching = true
			var points = touch_points.values()
			initial_pinch_distance = points[0].distance_to(points[1])
	else:
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
		camera_yaw += delta.x * drag_sensitivity * 0.5
		_update_camera_position()
		last_mouse_pos = event.position

# ===== UI MANAGEMENT =====

func update_player_info():
	"""Update player name and total level display"""
	var total_level = 0
	for skill_name in PlayerData.player_data["skills"]:
		total_level += PlayerData.get_skill_level(skill_name)
	
	player_name_label.text = "Player"
	total_level_label.text = "Total Level: " + str(total_level)

func close_all_menus():
	"""Close all open UI menus"""
	if inventory_ui and inventory_ui.visible:
		inventory_ui.hide_inventory()
	if crafting_ui and crafting_ui.visible:
		crafting_ui.hide_crafting()
	if skills_ui and skills_ui.visible:
		skills_ui.hide_skills()
	if equipment_ui and equipment_ui.visible:
		equipment_ui.hide_equipment()

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

func _on_pets_pressed():
	pass  # Pets menu coming soon

func _on_inventory_closed():
	update_player_info()

func _on_crafting_closed():
	update_player_info()

func _on_skills_closed():
	update_player_info()

func _on_equipment_closed():
	update_player_info()

# ===== ACTIVITY BUTTON HANDLERS =====

func _on_mining_pressed():
	get_tree().change_scene_to_file("res://scenes/mining_mini.tscn")

func _on_woodcutting_pressed():
	get_tree().change_scene_to_file("res://scenes/woodcutting_mini.tscn")

func _on_fishing_pressed():
	get_tree().change_scene_to_file("res://scenes/fishing_mini.tscn")

func _on_combat_pressed():
	get_tree().change_scene_to_file("res://scenes/circular_combat_scene.tscn")

# ===== UTILITY FUNCTIONS =====

func get_ore_type_id(ore_name: String) -> int:
	"""Convert ore name to ore type ID for mining minigame"""
	match ore_name:
		"copper_ore": return 0
		"tin_ore": return 1
		"iron_ore": return 2
		"coal": return 3
		"gold_ore": return 4
		"mithril_ore": return 5
		_: return 0

func _calculate_biome(lat: float, lon: float) -> String:
	"""Calculate biome based on latitude and longitude"""
	if BIOME_SEQUENCE.is_empty():
		return DEFAULT_BIOME
	
	var lat_zone = posmod(int(floor(lat * 10.0)), BIOME_SEQUENCE.size())
	var lon_zone = posmod(int(floor(lon * 10.0)), BIOME_SEQUENCE.size())
	var index = (lat_zone + lon_zone) % BIOME_SEQUENCE.size()
	return BIOME_SEQUENCE[index]

# ===== DEBUG DISPLAY =====

func _setup_debug_display():
	"""Create and configure debug display label"""
	debug_location_label = Label.new()
	debug_location_label.name = "DebugLocationLabel"
	debug_location_label.position = Vector2(10, 10)
	debug_location_label.z_index = 1000
	
	# Style
	debug_location_label.add_theme_font_size_override("font_size", 18)
	debug_location_label.add_theme_color_override("font_color", Color.WHITE)
	debug_location_label.add_theme_color_override("font_outline_color", Color.BLACK)
	debug_location_label.add_theme_constant_override("outline_size", 3)
	
	$HubUI/Panel.add_child(debug_location_label)

func _update_debug_display():
	"""Update debug display with current location and biome info"""
	if PraxisCore == null:
		debug_location_label.text = "PraxisCore not found"
		return
	
	var plus_code = PraxisCore.currentPlusCode
	var lat = 0.0
	var lon = 0.0
	
	if PraxisCore.last_location and typeof(PraxisCore.last_location) == TYPE_DICTIONARY:
		lat = float(PraxisCore.last_location.get("latitude", 0.0))
		lon = float(PraxisCore.last_location.get("longitude", 0.0))
	
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
	"""Get the display name for the current biome"""
        if PraxisCore and PraxisCore.currentPlusCode != "":
                var biome_data = PraxisOfflineData.GetBiomeDataForCell(PraxisCore.currentPlusCode)
                return biome_data.get("biome_name", "🌾 Wilderness")
	return "Unknown"

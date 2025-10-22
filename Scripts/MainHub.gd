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
@onready var gps_status_label = $HubUI/BottomBar/VBoxContainer/GPSInfoPanel/MarginContainer/GPSInfo/GPSStatusLabel
@onready var plus_code_label = $HubUI/BottomBar/VBoxContainer/GPSInfoPanel/MarginContainer/GPSInfo/PlusCodeLabel
@onready var coordinates_label = $HubUI/BottomBar/VBoxContainer/GPSInfoPanel/MarginContainer/GPSInfo/CoordinatesLabel
@onready var biome_label = $HubUI/BottomBar/VBoxContainer/GPSInfoPanel/MarginContainer/GPSInfo/BiomeLabel
@onready var resource_label = $HubUI/BottomBar/VBoxContainer/GPSInfoPanel/MarginContainer/GPSInfo/ResourceLabel

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

const FALLBACK_RESOURCES = {
        "mining": "copper_ore",
        "woodcutting": "oak_log",
        "fishing": "raw_fish"
}

const DEBUG_LOCATIONS = [
        {"name": "Los Angeles", "latitude": 34.0722, "longitude": -118.2606},
        {"name": "New York", "latitude": 40.7128, "longitude": -74.0060},
        {"name": "London", "latitude": 51.5074, "longitude": -0.1278},
        {"name": "Tokyo", "latitude": 35.6762, "longitude": 139.6503},
        {"name": "Sydney", "latitude": -33.8688, "longitude": 151.2093},
        {"name": "Paris", "latitude": 48.8566, "longitude": 2.3522}
]

var praxis_core: Node = null
var current_plus_code: String = ""
var current_biome_id: String = DEFAULT_BIOME
var current_location := {
        "latitude": 0.0,
        "longitude": 0.0,
        "has_precise": false,
        "plus_code": ""
}
var _debug_location_index := 0

func _sanitize_plus_code(raw_value) -> String:
        if raw_value == null:
                return ""

        var type_id := typeof(raw_value)
        var text := ""

        match type_id:
                TYPE_STRING:
                        text = raw_value
                TYPE_STRING_NAME:
                        text = String(raw_value)
                TYPE_NODE_PATH:
                        text = String(raw_value)
                TYPE_BOOL, TYPE_NIL:
                        return ""
                _:
                        return ""

        text = text.strip_edges().to_upper()

        var normalized := text.replace("+", "")
        if normalized.length() < 2:
                return ""

        for i in normalized.length():
                var char := normalized[i]
                if PlusCodes.CODE_ALPHABET_.find(char) == -1:
                        return ""

        if text.find("+") == -1 and text.length() >= 8:
                text = text.substr(0, 8) + "+" + text.substr(8)

        return text

func _get_location_snapshot() -> Dictionary:
        var snapshot := current_location.duplicate(true)
        if snapshot.has("plus_code"):
                snapshot["plus_code"] = _sanitize_plus_code(snapshot["plus_code"])
        return snapshot

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

        # Clear any lingering activity context from previous sessions
        PlayerData.clear_activity_context()

        _setup_gps_integration()
        _update_gps_labels()

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

# ===== GPS INTEGRATION =====

func _setup_gps_integration():
        praxis_core = get_node_or_null("/root/PraxisCore")
        if praxis_core == null:
                print("WARNING: PraxisCore autoload not found - GPS features disabled")
                return

        if praxis_core.plusCode_changed.is_connected(_on_plus_code_changed):
                praxis_core.plusCode_changed.disconnect(_on_plus_code_changed)
        praxis_core.plusCode_changed.connect(_on_plus_code_changed)

        if praxis_core.location_changed.is_connected(_on_location_changed):
                praxis_core.location_changed.disconnect(_on_location_changed)
        praxis_core.location_changed.connect(_on_location_changed)

        var starting_plus_code := _sanitize_plus_code(praxis_core.currentPlusCode)
        current_location = _extract_location_from_praxis()
        _apply_plus_code_location(starting_plus_code, true)
        _update_biome()

func _extract_location_from_praxis() -> Dictionary:
        var result = {
                "latitude": 0.0,
                "longitude": 0.0,
                "has_precise": false,
                "plus_code": praxis_core != null ? _sanitize_plus_code(praxis_core.currentPlusCode) : ""
        }

        if praxis_core == null:
                return result

        if typeof(praxis_core.last_location) == TYPE_DICTIONARY:
                var loc: Dictionary = praxis_core.last_location
                if loc.has("latitude") and loc.has("longitude"):
                        var lat = float(loc["latitude"])
                        var lon = float(loc["longitude"])
                        var has_accuracy = loc.has("accuracy") or praxis_core.gps_provider != null
                        if has_accuracy:
                                result["latitude"] = lat
                                result["longitude"] = lon
                                result["has_precise"] = true

        var plus_code := result.get("plus_code", "")
        if not result["has_precise"] and plus_code != "":
                var coords = PlusCodes.Decode(plus_code)
                result["latitude"] = coords.y
                result["longitude"] = coords.x

        return result

func _apply_plus_code_location(raw_plus_code, force: bool = false):
        var plus_code := _sanitize_plus_code(raw_plus_code)
        if plus_code == "":
                return

        current_plus_code = plus_code
        current_location["plus_code"] = plus_code

        if force or not current_location.get("has_precise", false):
                var coords = PlusCodes.Decode(plus_code)
                current_location["latitude"] = coords.y
                current_location["longitude"] = coords.x

func _update_biome():
        var lat = float(current_location.get("latitude", 0.0))
        var lon = float(current_location.get("longitude", 0.0))
        var new_biome = _calculate_biome(lat, lon)

        if not BIOMES.has(new_biome):
                new_biome = DEFAULT_BIOME

        if new_biome != current_biome_id:
                print("Biome updated: %s -> %s" % [current_biome_id, new_biome])
                current_biome_id = new_biome

func _calculate_biome(lat: float, lon: float) -> String:
        if BIOME_SEQUENCE.is_empty():
                return DEFAULT_BIOME

        var lat_zone = posmod(int(floor(lat * 10.0)), BIOME_SEQUENCE.size())
        var lon_zone = posmod(int(floor(lon * 10.0)), BIOME_SEQUENCE.size())
        var index = (lat_zone + lon_zone) % BIOME_SEQUENCE.size()
        return BIOME_SEQUENCE[index]

func _get_biome_display_name() -> String:
        return BIOMES.get(current_biome_id, BIOMES[DEFAULT_BIOME]).get("name", "Unknown")

func _get_resource_for_skill(skill: String) -> String:
        if BIOMES.has(current_biome_id) and BIOMES[current_biome_id].has(skill):
                return BIOMES[current_biome_id][skill]
        return FALLBACK_RESOURCES.get(skill, "copper_ore")

func _update_gps_labels():
        if gps_status_label == null:
                return

        if praxis_core == null:
                gps_status_label.text = "GPS: Unavailable"
        else:
                var status_text = "GPS: "
                var precise = current_location.get("has_precise", false)
                if praxis_core.gps_provider != null:
                        status_text += "Active"
                elif precise:
                        status_text += "Active"
                else:
                        status_text += "Simulated"
                gps_status_label.text = status_text

        var plus_code_text = _sanitize_plus_code(current_plus_code)
        if plus_code_text == "":
                plus_code_text = "--"
        plus_code_label.text = "Plus Code: %s" % plus_code_text

        var lat = float(current_location.get("latitude", 0.0))
        var lon = float(current_location.get("longitude", 0.0))
        coordinates_label.text = "Coordinates: %.5f°, %.5f°" % [lat, lon]

        biome_label.text = "Biome: %s" % _get_biome_display_name()

        var mining_line = _compose_resource_line("⛏", "mining")
        var wood_line = _compose_resource_line("🪓", "woodcutting")
        var fish_line = _compose_resource_line("🎣", "fishing")
        resource_label.text = "Resources:\n%s\n%s\n%s" % [mining_line, wood_line, fish_line]

func _compose_resource_line(icon_text: String, skill: String) -> String:
        var resource_id = _get_resource_for_skill(skill)
        var display_name = ItemDatabase.get_item_display_name(resource_id)
        return "%s %s: %s" % [icon_text, skill.capitalize(), display_name]

func _on_plus_code_changed(current: String, _previous: String):
        _apply_plus_code_location(current, false)
        _update_biome()
        _update_gps_labels()

func _on_location_changed(location: Dictionary):
        if location == null:
                return

        if location.has("latitude") and location.has("longitude"):
                current_location["latitude"] = float(location["latitude"])
                current_location["longitude"] = float(location["longitude"])
                current_location["has_precise"] = true

        if location.has("plus_code"):
                _apply_plus_code_location(location["plus_code"], false)
        elif praxis_core != null:
                _apply_plus_code_location(praxis_core.currentPlusCode, false)

        _update_biome()
        _update_gps_labels()

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

        var ore_type = _get_resource_for_skill("mining")
        var ore_display_name = ItemDatabase.get_item_display_name(ore_type)
        print("Mining %s in %s" % [ore_display_name, _get_biome_display_name()])

        var safe_plus_code := _sanitize_plus_code(current_plus_code)
        var location_snapshot := _get_location_snapshot()

        var context = {
                "skill": "mining",
                "resource_id": ore_type,
                "resource_name": ore_display_name,
                "ore_type_id": get_ore_type_id(ore_type),
                "biome_id": current_biome_id,
                "biome_name": _get_biome_display_name(),
                "plus_code": safe_plus_code,
                "location": location_snapshot
        }
        PlayerData.set_activity_context(context)

        get_tree().change_scene_to_file("res://scenes/mining_mini.tscn")

func _on_woodcutting_pressed():
        print("Starting woodcutting minigame...")

        var log_type = _get_resource_for_skill("woodcutting")
        var log_display_name = ItemDatabase.get_item_display_name(log_type)
        print("Cutting %s in %s" % [log_display_name, _get_biome_display_name()])

        var safe_plus_code := _sanitize_plus_code(current_plus_code)
        var location_snapshot := _get_location_snapshot()

        PlayerData.set_activity_context({
                "skill": "woodcutting",
                "resource_id": log_type,
                "resource_name": log_display_name,
                "biome_id": current_biome_id,
                "biome_name": _get_biome_display_name(),
                "plus_code": safe_plus_code,
                "location": location_snapshot
        })

        get_tree().change_scene_to_file("res://scenes/woodcutting_mini.tscn")

func _on_fishing_pressed():
        print("Starting fishing minigame...")

        var fish_type = _get_resource_for_skill("fishing")
        var fish_display_name = ItemDatabase.get_item_display_name(fish_type)
        print("Fishing for %s in %s" % [fish_display_name, _get_biome_display_name()])

        var safe_plus_code := _sanitize_plus_code(current_plus_code)
        var location_snapshot := _get_location_snapshot()

        PlayerData.set_activity_context({
                "skill": "fishing",
                "resource_id": fish_type,
                "resource_name": fish_display_name,
                "biome_id": current_biome_id,
                "biome_name": _get_biome_display_name(),
                "plus_code": safe_plus_code,
                "location": location_snapshot
        })

        get_tree().change_scene_to_file("res://scenes/fishing_mini.tscn")

func _debug_cycle_locations():
        if praxis_core == null:
                print("PraxisCore not available - cannot cycle debug locations")
                return

        if DEBUG_LOCATIONS.is_empty():
                return

        var location_info = DEBUG_LOCATIONS[_debug_location_index % DEBUG_LOCATIONS.size()]
        _debug_location_index += 1

        var plus_code = PlusCodes.EncodeLatLon(location_info["latitude"], location_info["longitude"])
        print("Debug teleport to %s (%s)" % [location_info["name"], plus_code])

        var location_dict = {
                "latitude": location_info["latitude"],
                "longitude": location_info["longitude"],
                "accuracy": 5.0,
                "plus_code": plus_code
        }

        praxis_core.on_monitoring_location_result(location_dict)
        praxis_core.ForceChange(plus_code)

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
                _debug_cycle_locations()

extends Node
# PlaceDataManager.gd - Manages place data and determines spawn weights based on location features

# ===== PLACE DATA CACHE =====
var cell_place_data = {}  # Cache loaded place data by cell code

# ===== FEATURE TYPE DEFINITIONS =====
# Based on the JSON structure, tid values represent different feature types
const FEATURE_TYPES = {
	3000: "water",          # Lakes, rivers, ponds
	10: "road",             # Roads, paths, highways
	900: "terrain",         # General terrain/land
	2000: "boundary",       # Large areas/boundaries
	800: "developed",       # Developed/urban areas
	1800: "recreation",     # Parks, campgrounds, recreational areas
	3800: "natural",        # Natural features
	1500: "trail",          # Trails, paths
	1700: "point_feature",  # Points of interest
	390: "camping",         # Camping areas
	1000: "wildlife",       # Wildlife/nature reserves
	30: "landmark",         # Landmarks
	1900: "residential"     # Residential areas
}

# ===== SPAWN WEIGHT MODIFIERS =====
# How different features affect resource spawn chances
const SPAWN_WEIGHTS = {
	"water": {
		"fishing": 3.0,      # 3x fishing near water
		"mining": 0.3,       # Less mining near water
		"woodcutting": 1.0,
		"combat": 0.5
	},
	"trail": {
		"fishing": 0.8,
		"mining": 1.2,
		"woodcutting": 1.5,  # More trees near trails
		"combat": 1.0
	},
	"wildlife": {
		"fishing": 1.2,
		"mining": 0.5,
		"woodcutting": 1.8,  # More woodcutting in wildlife areas
		"combat": 2.0        # 2x combat in wildlife areas
	},
	"recreation": {
		"fishing": 1.5,
		"mining": 0.7,
		"woodcutting": 1.3,
		"combat": 0.8
	},
	"developed": {
		"fishing": 0.3,
		"mining": 1.5,       # More mining in developed areas
		"woodcutting": 0.5,  # Less trees
		"combat": 1.8        # More combat in urban
	},
	"residential": {
		"fishing": 0.2,
		"mining": 0.8,
		"woodcutting": 0.3,
		"combat": 2.0        # High combat in residential
	},
	"natural": {
		"fishing": 1.3,
		"mining": 1.2,
		"woodcutting": 2.0,  # High woodcutting in natural areas
		"combat": 1.5
	},
	"camping": {
		"fishing": 1.8,
		"mining": 0.9,
		"woodcutting": 1.5,
		"combat": 1.2
	}
}

# Default weights if no place data available
const DEFAULT_WEIGHTS = {
	"fishing": 1.0,
	"mining": 1.0,
	"woodcutting": 1.0,
	"combat": 1.0
}

# ===== INITIALIZATION =====

func _ready():
	print("PlaceDataManager initialized")

# ===== PLACE DATA LOADING =====

func get_place_data_for_cell(cell_code: String) -> Dictionary:
	"""Get place data for a specific Plus Code cell"""
	# Check cache first
	if cell_place_data.has(cell_code):
		return cell_place_data[cell_code]
	
	# Try to load from file
	var place_data = _load_place_data_from_file(cell_code)
	
	if not place_data.is_empty():
		cell_place_data[cell_code] = place_data
	
	return place_data

func _load_place_data_from_file(cell_code: String) -> Dictionary:
	"""Load place data JSON file for a cell"""
	var file_path = "res://place_data/" + cell_code + ".json"
	
	if not FileAccess.file_exists(file_path):
		#print("No place data file found for cell: ", cell_code)
		return {}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		#print("Failed to open place data file: ", file_path)
		return {}
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		#print("Failed to parse place data JSON: ", cell_code)
		return {}
	
	var data = json.get_data()
	print("Loaded place data for cell: ", cell_code)
	return data

# ===== FEATURE ANALYSIS =====

func analyze_cell_features(cell_code: String) -> Dictionary:
	"""Analyze what features are present in a cell"""
	var place_data = get_place_data_for_cell(cell_code)
	
	if place_data.is_empty():
		return {}
	
	var features = {
		"has_water": false,
		"has_trails": false,
		"has_wildlife": false,
		"has_recreation": false,
		"has_developed": false,
		"has_residential": false,
		"has_natural": false,
		"has_camping": false,
		"feature_counts": {}
	}
	
	# Check entries for map tiles
	if place_data.has("entries") and place_data["entries"].has("mapTiles"):
		var map_tiles = place_data["entries"]["mapTiles"]
		
		for tile in map_tiles:
			if tile.has("tid"):
				var tid = tile["tid"]
				var feature_type = FEATURE_TYPES.get(tid, "unknown")
				
				# Count features
				if not features["feature_counts"].has(feature_type):
					features["feature_counts"][feature_type] = 0
				features["feature_counts"][feature_type] += 1
				
				# Set flags
				match feature_type:
					"water":
						features["has_water"] = true
					"trail":
						features["has_trails"] = true
					"wildlife":
						features["has_wildlife"] = true
					"recreation":
						features["has_recreation"] = true
					"developed":
						features["has_developed"] = true
					"residential":
						features["has_residential"] = true
					"natural":
						features["has_natural"] = true
					"camping":
						features["has_camping"] = true
	
	return features

# ===== SPAWN WEIGHT CALCULATION =====

func get_spawn_weights_for_cell(cell_code: String) -> Dictionary:
	"""Calculate spawn weights for each resource type based on cell features"""
	var features = analyze_cell_features(cell_code)
	
	if features.is_empty():
		#print("No features found for cell ", cell_code, ", using default weights")
		return DEFAULT_WEIGHTS.duplicate()
	
	# Start with default weights
	var weights = DEFAULT_WEIGHTS.duplicate()
	var modifier_count = 0
	
	# Apply modifiers based on present features
	if features["has_water"]:
		_apply_weight_modifier(weights, "water")
		modifier_count += 1
	
	if features["has_trails"]:
		_apply_weight_modifier(weights, "trail")
		modifier_count += 1
	
	if features["has_wildlife"]:
		_apply_weight_modifier(weights, "wildlife")
		modifier_count += 1
	
	if features["has_recreation"]:
		_apply_weight_modifier(weights, "recreation")
		modifier_count += 1
	
	if features["has_developed"]:
		_apply_weight_modifier(weights, "developed")
		modifier_count += 1
	
	if features["has_residential"]:
		_apply_weight_modifier(weights, "residential")
		modifier_count += 1
	
	if features["has_natural"]:
		_apply_weight_modifier(weights, "natural")
		modifier_count += 1
	
	if features["has_camping"]:
		_apply_weight_modifier(weights, "camping")
		modifier_count += 1
	
	# Average the modifiers if multiple features present
	if modifier_count > 1:
		for resource_type in weights:
			weights[resource_type] = (weights[resource_type] + (modifier_count - 1)) / modifier_count
	
	print("Spawn weights for cell ", cell_code, ": ", weights)
	return weights

func _apply_weight_modifier(weights: Dictionary, feature_type: String):
	"""Apply a feature's weight modifiers to the weights dictionary"""
	if not SPAWN_WEIGHTS.has(feature_type):
		return
	
	var modifiers = SPAWN_WEIGHTS[feature_type]
	for resource_type in modifiers:
		weights[resource_type] *= modifiers[resource_type]

# ===== RESOURCE TYPE SELECTION =====

func get_resource_type_for_cell(cell_code: String, rng: RandomNumberGenerator) -> String:
	"""Determine resource type using weighted random selection based on place data"""
	var weights = get_spawn_weights_for_cell(cell_code)
	
	# Calculate total weight
	var total_weight = 0.0
	for resource_type in weights:
		total_weight += weights[resource_type]
	
	# Random selection based on weights
	var roll = rng.randf() * total_weight
	var cumulative = 0.0
	
	for resource_type in weights:
		cumulative += weights[resource_type]
		if roll <= cumulative:
			return resource_type
	
	# Fallback (shouldn't happen)
	return "mining"

# ===== BIOME DISPLAY =====

func get_biome_name_for_cell(cell_code: String) -> String:
	"""Get a display name for the biome based on dominant features"""
	var features = analyze_cell_features(cell_code)
	
	if features.is_empty():
		return "🌾 Wilderness"
	
	# Determine dominant biome
	if features["has_water"]:
		return "🏖️ Waterfront"
	elif features["has_wildlife"] or features["has_natural"]:
		return "🌲 Wildlife Reserve"
	elif features["has_camping"] or features["has_recreation"]:
		return "🏕️ Recreation Area"
	elif features["has_residential"]:
		return "🏘️ Residential"
	elif features["has_developed"]:
		return "🏙️ Urban"
	elif features["has_trails"]:
		return "🥾 Trail System"
	else:
		return "🌾 Mixed Terrain"

# ===== UTILITY =====

func clear_cache():
	"""Clear the place data cache"""
	cell_place_data.clear()
	print("Place data cache cleared")

func preload_cells(cell_codes: Array):
	"""Preload place data for multiple cells"""
	for cell_code in cell_codes:
		get_place_data_for_cell(cell_code)

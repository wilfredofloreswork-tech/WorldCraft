extends Node
class_name PraxisOfflineData

#Once we read a file from disk, keep it in memory. Odds are high the player will read it again.
static var allData = {}

# ===== BIOME SYSTEM CONSTANTS =====

# Feature type to biome mapping (based on tid values from worldcraftstyle.json)
const BIOME_FEATURE_WEIGHTS = {
	800: {"water": 1.0},             # water
	790: {"water": 1.0},             # bgwater
	900: {"water": 1.0},             # wetland (partial water)
	1000: {"recreation": 1.0},       # park
	1200: {"wildlife": 1.5},         # natureReserve
	1300: {"developed": 0.5},        # cemetery
	1400: {"trail": 5.0},            # trailFilled
	1500: {"trail": 5.0},            # trail
	1800: {"natural": 0.5},          # grass
	2000: {"natural": 1.5},          # forest
	2100: {"developed": 1.0},        # industrial
	2200: {"residential": 4.0},      # residential
	390: {"camping": 1.0},           # camping
	3800: {"natural": 1.0},          # scrub
	4100: {"recreation": 0.8},       # sportspitch
	4200: {"recreation": 0.8},       # golfgreen
	4300: {"recreation": 0.8},       # golfcourse
	5700: {"natural": 0.8},          # orchard
	3600: {"terrain": 0.5},          # farmland
	3700: {"terrain": 0.5}           # farmyard
}

# Spawn modifiers for each biome type
const SPAWN_MODIFIERS = {
	"water": {
		"fishing": 3.0,
		"mining": 0.2,
		"woodcutting": 0.2,
		"combat": 0.2
	},
	"trail": {
		"fishing": 0.8,
		"mining": 1.2,
		"woodcutting": 1.5,
		"combat": 1.0
	},
	"wildlife": {
		"fishing": 1.2,
		"mining": 0.5,
		"woodcutting": 1.8,
		"combat": 4.0
	},
	"recreation": {
		"fishing": 1.5,
		"mining": 0.7,
		"woodcutting": 1.3,
		"combat": 0.8
	},
	"developed": {
		"fishing": 0.3,
		"mining": 4.5,
		"woodcutting": 0.5,
		"combat": 1.8
	},
	"residential": {
		"fishing": 0.2,
		"mining": 0.8,
		"woodcutting": 0.3,
		"combat": 2.0
	},
	"natural": {
		"fishing": 1.3,
		"mining": 1.2,
		"woodcutting": 6.0,
		"combat": 1.5
	},
	"camping": {
		"fishing": 1.0,
		"mining": 0.9,
		"woodcutting": 1.5,
		"combat": 1.2
	},
	"terrain": {
		"fishing": 1.0,
		"mining": 1.0,
		"woodcutting": 1.0,
		"combat": 1.0
	}
}

# ===== FILE EXISTENCE CHECK =====

static func OfflineDataExists(plusCode):
	if FileAccess.file_exists("res://OfflineData/Full/" + plusCode.substr(0,2) + "/" + plusCode.substr(0,4) + ".zip"):
		return true
	if FileAccess.file_exists("user://Data/Full/" + plusCode.substr(0,4)+ ".zip"):
		return true
	if FileAccess.file_exists("user://Data/Full/" + plusCode.substr(0,6)+ ".json"):
		return true
	return false

# ===== DATA LOADING =====

static func GetDataFromZip(plusCode): #full, drawable offline data.
	if allData.has(plusCode):
		return allData[plusCode]
	
	var code2 = plusCode.substr(0, 2)
	var code4 = plusCode.substr(2, 2)
	var zipReader = ZIPReader.new()
	
	#CHECK: if we have a single downloaded JSON file, use it.
	if FileAccess.file_exists("user://Data/Full/" + plusCode.substr(0,6) + ".json"):
		var soloFile = FileAccess.open("user://Data/Full/" + plusCode.substr(0,6) + ".json", FileAccess.READ)
		var json = JSON.new()
		json.parse(soloFile.get_as_text())
		
		var jsonData = json.data
		if jsonData == null: #no good data here? this area is missing or empty?
			return null
		return ProcessData(jsonData)

	#Now check if we have the zip file that should hold this data, built in or downloaded
	var err
	if FileAccess.file_exists("res://OfflineData/Full/" + code2 + "/" + code2 + code4 + ".zip"):
		err = await zipReader.open("res://OfflineData/Full/" + plusCode.substr(0,2) + "/" + plusCode.substr(0,4) + ".zip")
	elif FileAccess.file_exists("user://Data/Full/" + code2 + code4 + ".zip"):
		err = await zipReader.open("user://Data/Full/" + code2 + code4 + ".zip")

	if err != OK:
		#print("No FullOffline data found (or zip corrupt/incomplete) for " + plusCode + ": " + str(err))
		return 
		
	var rawdata := await zipReader.read_file(plusCode + ".json")
	var realData = await rawdata.get_string_from_utf8()
	var json = JSON.new()
	await json.parse(realData)
	var jsonData = json.data
	if jsonData == null: #no file in this zip, this area is missing or empty.
		return 
	
	return ProcessData(jsonData)

# ===== DATA PROCESSING WITH BIOME SYSTEM =====

static func ProcessData(jsonData):
	if jsonData == null: #may happen if data is partially loaded.
		return
		
	print("processing data for " + jsonData.olc)
	var totalCount = 0
	var start = Time.get_unix_time_from_system()
	
	var placeIndex = {} # A list of places by OsmID
	var areaIndex = {} #An array of items in a Cell8
	var typeIndex = {} #an array of items by type. NOTE: Category is the styleSet, not entry type.
	var biomeIndex = {}  # NEW: Biome tracking per Cell8
		
	#This is envelope detection, so yes I want a big min and tiny max to start
	#because they'll get flipped to the right values on the first point.
	var minVector = Vector2i(20000,20000)
	var maxVector = Vector2i(0,0)
	for category in jsonData.entries:
		totalCount += jsonData.entries[category].size()
		var styleData = PraxisCore.GetStyle(category)
		if styleData == null:
			styleData = {}
		for entry in jsonData.entries[category]:
			minVector = Vector2i(20000,20000)
			maxVector = Vector2i(0,0)
			#entry.p is a string of coords separated by a pipe in the text file.
			#EX: 0,0|20,0|20,20|20,0|0,0 is a basic square.
			var coords = entry.p.split("|", false)
			var polyCoords = PackedVector2Array()
			for i in coords.size():
				var point = coords[i].split(",")
				var workVector = Vector2i(int(point[0]), int(point[1]))
				polyCoords.append(workVector)
				
				if workVector.x > maxVector.x:
					maxVector.x = workVector.x
				if workVector.y > maxVector.y:
					maxVector.y = workVector.y
				if workVector.x < minVector.x:
					minVector.x = workVector.x
				if workVector.y < minVector.y:
					minVector.y = workVector.y
				
			entry.p = polyCoords
			entry.envelope = Rect2(minVector, (maxVector - minVector))
			
			# NEW: Calculate which Cell8s this feature overlaps and update biome data
			if entry.has("tid"):
				_update_biome_for_feature(entry, jsonData.olc, biomeIndex)
			
			#Place indexing for named locations
			if entry.has("OsmId") and entry.has("nid") and entry.nid != 0 and styleData.has(str(int(entry.tid))):
				var indexed = {
					OSMID = entry.OsmId,
					name = jsonData.nameTable[str(int(entry.nid))],
					category = category,
					center = PraxisOfflineData.DataCoordsToPlusCode(entry.envelope.get_center(), jsonData.olc),
					itemtype = styleData[str(int(entry.tid))].name
				}
				placeIndex[entry.OsmId] = indexed
				if typeIndex.has(indexed.itemtype):
					typeIndex[indexed.itemtype].append(indexed)
				else:
					typeIndex[indexed.itemtype] = [indexed]
				var area = indexed.center.substr(0,8)
				if areaIndex.has(area):
					areaIndex[area].append(indexed)
				else:
					areaIndex[area] = [indexed]

	# NEW: Calculate final biome weights for each Cell8
	_finalize_biomes(biomeIndex)
	
	# Debug: Show what we calculated
	#print("=== Biome Summary ===")
	var biome_counts = {}
	for cell8 in biomeIndex:
		var biome_name = biomeIndex[cell8]["biome_name"]
		if not biome_counts.has(biome_name):
			biome_counts[biome_name] = 0
		biome_counts[biome_name] += 1
	print("Biome distribution: ", biome_counts)

	jsonData.index = {
		places = placeIndex, 
		areas = areaIndex, 
		types = typeIndex,
		biomes = biomeIndex  # NEW: Add biome index
	}
	
	var end = Time.get_unix_time_from_system()
	var diff = end - start
	#print("Data processed " + str(totalCount) + " items in " + str(diff) + " seconds")
	#print("Biome data calculated for " + str(biomeIndex.size()) + " Cell8 areas")
	allData[jsonData.olc] = jsonData
	return jsonData

# ===== BIOME HELPER FUNCTIONS =====

static func _update_biome_for_feature(entry, cell6Base, biomeIndex):
	"""Update biome data for all Cell8s that this feature overlaps"""
	var tid = int(entry.tid)  # Convert to int to match dictionary keys
	
	# Skip if this feature type doesn't affect biomes
	if not BIOME_FEATURE_WEIGHTS.has(tid):
		return
	
	# Get the biome contributions from this feature
	var biome_contributions = BIOME_FEATURE_WEIGHTS[tid]
	
	# Calculate which Cell8 areas this feature covers
	var envelope = entry.envelope
	var center = envelope.get_center()
	
	# Convert center to Plus Code
	var center_pluscode = DataCoordsToPlusCode(center, cell6Base)
	var cell8 = center_pluscode.substr(0, 8)
	
	# Initialize biome data for this Cell8 if needed
	if not biomeIndex.has(cell8):
		biomeIndex[cell8] = {
			"feature_counts": {},
			"total_weight": 0.0
		}
	
	# Add this feature's biome contributions
	for biome_type in biome_contributions:
		var weight = biome_contributions[biome_type]
		
		if not biomeIndex[cell8]["feature_counts"].has(biome_type):
			biomeIndex[cell8]["feature_counts"][biome_type] = 0.0
		
		biomeIndex[cell8]["feature_counts"][biome_type] += weight
		biomeIndex[cell8]["total_weight"] += weight

static func _finalize_biomes(biomeIndex):
	"""Calculate final spawn weights for each Cell8 based on accumulated features"""
	for cell8 in biomeIndex:
		var cell_data = biomeIndex[cell8]
		
		# SPECIAL CASE: If there's ANY water, it's a water biome
		var has_water = cell_data["feature_counts"].has("water") and cell_data["feature_counts"]["water"] > 0
		
		var dominant_biome = "terrain"
		var max_weight = 0.0
		
		if has_water:
			# Water overrides everything
			dominant_biome = "water"
			#print("Cell8 ", cell8, " has water - forcing water biome")
		else:
			# Determine dominant biome type from other features
			for biome_type in cell_data["feature_counts"]:
				if cell_data["feature_counts"][biome_type] > max_weight:
					max_weight = cell_data["feature_counts"][biome_type]
					dominant_biome = biome_type
		
		# Calculate spawn weights
		var spawn_weights = {
			"fishing": 1.0,
			"mining": 1.0,
			"woodcutting": 1.0,
			"combat": 1.0
		}
		
		if has_water:
			# Pure water biome - use only water modifiers
			spawn_weights = SPAWN_MODIFIERS["water"].duplicate()
		else:
			# Apply modifiers from all present biome types
			var total_influence = 0.0
			for biome_type in cell_data["feature_counts"]:
				if SPAWN_MODIFIERS.has(biome_type):
					var influence = cell_data["feature_counts"][biome_type]
					total_influence += influence
					
					var modifiers = SPAWN_MODIFIERS[biome_type]
					for resource_type in modifiers:
						spawn_weights[resource_type] += (modifiers[resource_type] - 1.0) * influence
			
			# Normalize weights by total influence
			if total_influence > 0:
				for resource_type in spawn_weights:
					spawn_weights[resource_type] = spawn_weights[resource_type] / (1.0 + total_influence)
		
		# Store final data
		cell_data["dominant_biome"] = dominant_biome
		cell_data["spawn_weights"] = spawn_weights
		cell_data["biome_name"] = _get_biome_display_name(dominant_biome)

static func _get_biome_display_name(biome_type: String) -> String:
	"""Get display name for a biome type"""
	match biome_type:
		"water":
			return "🏖️ Waterfront"
		"wildlife":
			return "🌲 Wildlife Reserve"
		"camping", "recreation":
			return "🏕️ Recreation Area"
		"residential":
			return "🏘️ Residential"
		"developed":
			return "🏙️ Urban"
		"trail":
			return "🥾 Trail System"
		"natural":
			return "🌲 Forest"
		_:
			return "🌾 Mixed Terrain"

# ===== PUBLIC BIOME ACCESS =====

static func GetBiomeDataForCell(plusCode: String) -> Dictionary:
	"""Get biome spawn weights for a specific Cell8"""
	var cell6 = plusCode.substr(0, 6)
	var cell8 = plusCode.substr(0, 8)
	
	
	# Load the data if not cached
	var data = await GetDataFromZip(cell6)
	if data == null or not data.has("index") or not data.index.has("biomes"):
		print("No biome data available")
		return _get_default_biome()
	
	#print("Biome index has ", data.index.biomes.size(), " entries")
	
	# Return biome data for this Cell8
	if data.index.biomes.has(cell8):
		#print("Found exact match for ", cell8, ": ", data.index.biomes[cell8]["biome_name"])
		return data.index.biomes[cell8]
	else:
		#print("No exact match for ", cell8)
		#print("Available Cell8s near target:")
		# Show nearby Cell8s that DO have biomes
		var count = 0
		for available_cell8 in data.index.biomes.keys():
			if available_cell8.begins_with(cell6):
				#if count < 10:
					#print("  ", available_cell8, " -> ", data.index.biomes[available_cell8]["biome_name"])
				count += 1
		
		# No features in this specific Cell8 - search nearby Cell8s
		var nearby_biome = _find_nearest_biome(cell8, data.index.biomes)
		if nearby_biome != null:
			#print("Using nearby biome: ", nearby_biome["biome_name"])
			return nearby_biome
		else:
			print("No nearby biomes found, using default")
			return _get_default_biome()

static func _find_nearest_biome(target_cell8: String, biome_index: Dictionary) -> Dictionary:
	"""Find the nearest Cell8 with biome data"""
	# Try adjacent cells first (shift by 1 in each direction)
	for x_offset in range(-1, 2):
		for y_offset in range(-1, 2):
			if x_offset == 0 and y_offset == 0:
				continue
			
			var shifted = PlusCodes.ShiftCode(target_cell8, x_offset, y_offset)
			if biome_index.has(shifted):
				return biome_index[shifted]
	
	# If no adjacent cells, return the closest one we can find
	var min_distance = 999999.0
	var closest_biome = null
	
	for cell8 in biome_index:
		# Simple string distance as approximation
		var distance = abs(cell8.hash() - target_cell8.hash())
		if distance < min_distance:
			min_distance = distance
			closest_biome = biome_index[cell8]
	
	return closest_biome

static func _get_default_biome() -> Dictionary:
	return {
		"spawn_weights": {
			"fishing": 1.0,
			"mining": 1.0,
			"woodcutting": 1.0,
			"combat": 1.0
		},
		"dominant_biome": "terrain",
		"biome_name": "🌾 Wilderness"
	}

# ===== PLACE DETECTION =====

static func GetPlacesPresent(plusCode):
	var data = await GetDataFromZip(plusCode.substr(0,6))
	if data == null:
		return
	var point = PlusCodeToDataCoords(plusCode)
	var results = []
	var size = plusCode.length()
	
	for category in data.entries:
		for entry in data.entries[category]:
			if entry.has("nid") and entry.nid != 0:
				if IsPointInPlace(point, entry, size, data.nameTable[str(int(entry.nid))]):
					results.push_back({ 
						name  = data.nameTable[str(int(entry.nid))],
						category = category,
						typeId = entry.tid
					})
					print(data.nameTable[str(int(entry.nid))])
	return results

static func IsPlusCodeInPlace(plusCode, place):
	var point = PlusCodeToDataCoords(plusCode)
	return IsPointInPlace(point, place, plusCode.size())
	
static func IsPointInPlace(point, place, size, name = "unnamed"):
	var cell10 = PackedVector2Array()
	cell10.append(Vector2(point + Vector2(-8, -12)))
	cell10.append(Vector2(point + Vector2(-8, 12)))
	cell10.append(Vector2(point + Vector2(8, 12)))
	cell10.append(Vector2(point + Vector2(8, -12)))
	cell10.append(Vector2(point+ Vector2(-8, -12)))

	if place.gt == 1:
		#JUST DO DISTANCE FOR POINTS
		return abs(point.distance_to(place.p[0])) <= 10.25 #Avg. of half a cell10 radius.
	elif place.gt == 2:
		#its an open line
		var results =  Geometry2D.intersect_polyline_with_polygon(place.p, cell10)
		if results != null and results.size() > 0:
			return true
	elif place.gt == 3:
		#A closed shape. Check envelope first for speed.
		var cell10Env = Rect2(point - Vector2(8, 12), point + Vector2(8, 12))
		var envelopeCheck = cell10Env.intersects(place.envelope, true)
		if envelopeCheck == true:
			var results = Geometry2D.intersect_polygons(cell10, place.p)
			if results != null and results.size() > 0:
				return true
	return false

# ===== COORDINATE CONVERSION =====

static func PlusCodeToDataCoords(plusCode):
	#This is the Cell10 coords, because we multiply the value by the cell12 pixels on the axis.
	#Increasing Y here goes DOWN.
	plusCode = plusCode.replace("+", "")
	var testPointY = (PlusCodes.GetLetterIndex(plusCode[6]) * 500) + (PlusCodes.GetLetterIndex(plusCode[8]) * 25)
	var testPointX = (PlusCodes.GetLetterIndex(plusCode[7]) * 320) + (PlusCodes.GetLetterIndex(plusCode[9]) * 16)
	
	if plusCode.length() > 10:
		testPointX += PlusCodes.GetLetterIndex(plusCode[10]) % 4
		testPointY += int(PlusCodes.GetLetterIndex(plusCode[10]) / 5)
	
	var point = Vector2(testPointX, testPointY)
	return point
	
static func DataCoordsToPlusCode(coords, cell6Base):
	var shiftXCell10s = int(coords.x / 16)
	var shiftYCell10s = int(coords.y / 25)
	
	return PlusCodes.ShiftCode(cell6Base + "2222", shiftXCell10s, shiftYCell10s)

# GPSDebugTest.gd
# Attach this to any Node in your scene to test GPS
# Or run it from the debugger console

extends Node

func _ready():
	print("\n=== GPS DEBUG TEST ===")
	
	# Test 1: Check if GPSManager exists
	print("\n1. Checking GPSManager...")
	if has_node("/root/GPSManager"):
		print("✅ GPSManager found!")
		var gps = get_node("/root/GPSManager")
		
		# Test 2: Check GPS properties
		print("\n2. GPS Properties:")
		print("  - GPS Enabled: " + str(gps.gps_enabled))
		print("  - Current Latitude: " + str(gps.current_latitude))
		print("  - Current Longitude: " + str(gps.current_longitude))
		print("  - Current Biome: " + str(gps.current_biome))
		
		# Test 3: Call GPS functions
		print("\n3. GPS Functions:")
		print("  - get_current_biome(): " + gps.get_current_biome())
		print("  - get_biome_name(): " + gps.get_biome_name())
		print("  - get_biome_description(): " + gps.get_biome_description())
		
		# Test 4: Check biome resources
		print("\n4. Biome Resources:")
		print("  - Mining: " + gps.get_biome_resource("mining"))
		print("  - Woodcutting: " + gps.get_biome_resource("woodcutting"))
		print("  - Fishing: " + gps.get_biome_resource("fishing"))
		
		# Test 5: Manually call debug function
		print("\n5. Calling debug_print_status():")
		gps.debug_print_status()
		
	else:
		print("❌ GPSManager NOT FOUND!")
		print("   Check Project -> Project Settings -> Autoload")
		print("   Make sure GPSManager.gd is in the list")
	
	# Test 6: Check LocationPanel nodes
	print("\n6. Checking LocationPanel in scene tree:")
	var root = get_tree().root
	print("  Root children: " + str(root.get_child_count()))
	
	# Search for LocationPanel
	var found = search_for_node(root, "LocationPanel")
	if found:
		print("  ✅ LocationPanel found at: " + str(found.get_path()))
		
		# Check children
		print("  LocationPanel children: " + str(found.get_child_count()))
		for child in found.get_children():
			print("    - " + child.name + " (" + child.get_class() + ")")
			
			# If it's BiomeLabel, check its text
			if child.name == "BiomeLabel":
				if child is Label:
					print("      Text: '" + child.text + "'")
					print("      Visible: " + str(child.visible))
	else:
		print("  ❌ LocationPanel NOT FOUND in scene tree")
	
	print("\n=== END DEBUG TEST ===\n")

func search_for_node(node: Node, target_name: String) -> Node:
	"""Recursively search for a node by name"""
	if node.name == target_name:
		return node
	
	for child in node.get_children():
		var result = search_for_node(child, target_name)
		if result:
			return result
	
	return null

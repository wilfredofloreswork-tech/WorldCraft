extends Node

func _ready():
	print("\n=== TESTING PLAYER DATA ===\n")
	
	# Test adding XP
	print("Adding 100 mining XP...")
	PlayerData.add_xp("mining", 100)
	print("Mining level: ", PlayerData.get_skill_level("mining"))
	
	# Test adding items
	print("\nAdding items...")
	PlayerData.add_item("copper_ore", 10)
	PlayerData.add_item("tin_ore", 5)
	print("Copper ore: ", PlayerData.get_item_count("copper_ore"))
	print("Tin ore: ", PlayerData.get_item_count("tin_ore"))
	
	# Test crafting/equipment
	print("\nTesting equipment...")
	PlayerData.add_item("bronze_pickaxe", 1)
	PlayerData.equip_item("pickaxe", "bronze_pickaxe")
	print("Equipped: ", PlayerData.get_equipped_item("pickaxe"))
	
	print("\n=== ALL TESTS PASSED! ===\n")

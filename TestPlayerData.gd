extends Node
# TestPlayerData.gd - Attach this to any Node to test the PlayerData system
# You can attach this to a Control node or just run it in a test scene

func _ready():
	print("\n========== TESTING PLAYER DATA SYSTEM ==========\n")
	
	# Test 1: Add some XP
	print("TEST 1: Adding XP")
	print("Current Mining Level: " + str(PlayerData.get_skill_level("mining")))
	PlayerData.add_xp("mining", 100)
	print("After adding 100 XP: Level " + str(PlayerData.get_skill_level("mining")))
	print("Progress to next level: " + str(PlayerData.get_skill_progress("mining") * 100) + "%")
	
	print("\n---")
	
	# Test 2: Add items to inventory
	print("TEST 2: Adding Items")
	PlayerData.add_item("copper_ore", 10)
	PlayerData.add_item("tin_ore", 5)
	print("Copper Ore count: " + str(PlayerData.get_item_count("copper_ore")))
	print("Tin Ore count: " + str(PlayerData.get_item_count("tin_ore")))
	
	print("\n---")
	
	# Test 3: Remove items
	print("TEST 3: Removing Items")
	var success = PlayerData.remove_item("copper_ore", 3)
	print("Removed 3 copper ore: " + str(success))
	print("Copper Ore count now: " + str(PlayerData.get_item_count("copper_ore")))
	
	print("\n---")
	
	# Test 4: Equipment
	print("TEST 4: Equipment")
	PlayerData.add_item("bronze_pickaxe", 1)
	print("Added bronze pickaxe to inventory")
	var equipped = PlayerData.equip_item("pickaxe", "bronze_pickaxe")
	print("Equipped bronze pickaxe: " + str(equipped))
	print("Currently equipped pickaxe: " + str(PlayerData.get_equipped_item("pickaxe")))
	
	print("\n---")
	
	# Test 5: Level up multiple times
	print("TEST 5: Mass XP Gain (Level-ups)")
	print("Current Mining Level: " + str(PlayerData.get_skill_level("mining")))
	PlayerData.add_xp("mining", 5000)  # This should level up multiple times
	print("After adding 5000 XP: Level " + str(PlayerData.get_skill_level("mining")))
	
	print("\n---")
	
	# Test 6: Print all data
	print("TEST 6: Full Data Dump")
	PlayerData.debug_print_data()
	
	print("\n========== TESTS COMPLETE ==========\n")
	print("Check user://player_save.json to see the saved data!")
	print("Save file location: " + OS.get_user_data_dir())

# You can also connect to signals to respond to events
func _on_player_data_ready():
	# Connect to signals
	PlayerData.level_up.connect(_on_level_up)
	PlayerData.item_added.connect(_on_item_added)

func _on_level_up(skill_name: String, new_level: int):
	print("🎉 LEVEL UP! " + skill_name.capitalize() + " is now level " + str(new_level))

func _on_item_added(item_name: String, amount: int):
	print("📦 Obtained " + str(amount) + "x " + item_name)

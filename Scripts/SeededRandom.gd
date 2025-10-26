# SeededRandom.gd
# Functions for generating evenly distributed random numbers with seeds

extends Node

# ===== MAIN FUNCTION =====

func get_random_1_to_10k(daily_seed: int, pluscode: String) -> int:
	"""
	Generate a random number between 1 and 10,000 (inclusive)
	Same inputs always produce the same output (deterministic)
	Evenly distributed across the range
	"""
	
	# Combine the daily seed with the pluscode
	var combined_seed = _combine_seeds(daily_seed, pluscode)
	
	# Create RNG with that seed
	var rng = RandomNumberGenerator.new()
	rng.seed = combined_seed
	
	# Generate number between 1 and 10,000 inclusive
	return rng.randi_range(1, 10000)

# ===== HELPER FUNCTIONS =====

func _combine_seeds(daily_seed: int, pluscode: String) -> int:
	"""
	Combine daily seed with pluscode to create unique seed per cell
	Uses XOR for good mixing properties
	"""
	var pluscode_hash = pluscode.hash()
	return (daily_seed ^ pluscode_hash) & 0x7FFFFFFF  # Keep positive

# ===== ALTERNATIVE: Multiple Random Values from Same Seed =====

func get_multiple_randoms(daily_seed: int, pluscode: String, count: int) -> Array:
	"""
	Generate multiple random numbers from the same seed
	Useful if you need multiple values for one cell
	"""
	var combined_seed = _combine_seeds(daily_seed, pluscode)
	var rng = RandomNumberGenerator.new()
	rng.seed = combined_seed
	
	var results = []
	for i in count:
		results.append(rng.randi_range(1, 10000))
	
	return results

# ===== EXAMPLES & TESTING =====

func test_distribution():
	"""
	Test that the distribution is actually even
	Run this to verify randomness quality
	"""
	print("\n=== Testing Random Distribution ===")
	
	var daily_seed = 123456789
	var buckets = {}  # Count how many fall in each range
	var test_count = 1000
	
	# Initialize 10 buckets (1-1000, 1001-2000, etc.)
	for i in 10:
		buckets[i] = 0
	
	# Generate 1000 random numbers
	for i in test_count:
		var fake_pluscode = "87G74P" + str(i).pad_zeros(4)
		var random_num = get_random_1_to_10k(daily_seed, fake_pluscode)
		
		# Determine which bucket it falls into
		var bucket = int((random_num - 1) / 1000)
		buckets[bucket] += 1
	
	# Print distribution
	print("Distribution across 10 ranges (should be ~100 each):")
	for i in 10:
		var range_start = i * 1000 + 1
		var range_end = (i + 1) * 1000
		print("  %d-%d: %d occurrences" % [range_start, range_end, buckets[i]])

func example_usage():
	"""Show how to use this in your game"""
	print("\n=== Example Usage ===")
	
	# Server provides daily seed
	var daily_seed = 987654321
	
	# Player is at this location
	var player_location = "87G74PJC+2R"
	
	# Get the random number for this cell today
	var roll = get_random_1_to_10k(daily_seed, player_location)
	print("Roll for %s: %d" % [player_location, roll])
	
	# Use the roll to determine resource
	var resource = _determine_resource_from_roll(roll)
	print("Resource spawned: %s" % resource)
	
	# Tomorrow (different seed) will produce different result
	var tomorrow_seed = 111222333
	var tomorrow_roll = get_random_1_to_10k(tomorrow_seed, player_location)
	print("Tomorrow's roll for same location: %d" % tomorrow_roll)

func _determine_resource_from_roll(roll: int) -> String:
	"""
	Example: Use the 1-10k roll to determine resource type
	Allows fine-grained probability control
	"""
	
	# Define spawn rates (out of 10,000)
	if roll <= 5000:  # 50% - Common
		return "Copper Ore"
	elif roll <= 7500:  # 25% - Uncommon
		return "Iron Ore"
	elif roll <= 9000:  # 15% - Rare
		return "Gold Ore"
	elif roll <= 9800:  # 8% - Very Rare
		return "Mithril Ore"
	elif roll <= 9950:  # 1.5% - Epic
		return "Rare Gem"
	else:  # 0.5% - Legendary
		return "Legendary Crystal"

# ===== ADVANCED: Custom Range Function =====

func get_random_in_range(daily_seed: int, pluscode: String, min_val: int, max_val: int) -> int:
	"""
	Generic function for any range
	get_random_in_range(seed, code, 1, 100) → number between 1-100
	"""
	var combined_seed = _combine_seeds(daily_seed, pluscode)
	var rng = RandomNumberGenerator.new()
	rng.seed = combined_seed
	return rng.randi_range(min_val, max_val)

# ===== BONUS: Weighted Random with Roll =====

func weighted_random_from_roll(roll: int, weights: Array) -> int:
	"""
	Convert a roll (1-10000) into a weighted random choice
	
	Example:
	var weights = [
		{"name": "common", "weight": 70},    # 70% chance
		{"name": "rare", "weight": 25},      # 25% chance  
		{"name": "legendary", "weight": 5}   # 5% chance
	]
	"""
	
	var total_weight = 0
	for item in weights:
		total_weight += item.weight
	
	# Scale roll to total weight
	var scaled_roll = int((float(roll) / 10000.0) * total_weight)
	
	var current_weight = 0
	for i in weights.size():
		current_weight += weights[i].weight
		if scaled_roll < current_weight:
			return i
	
	return weights.size() - 1  # Fallback to last item

# ===== RUN TESTS =====

func _ready():
	# Uncomment to run tests
	# test_distribution()
	# example_usage()
	pass

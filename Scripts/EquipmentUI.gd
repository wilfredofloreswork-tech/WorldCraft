extends CanvasLayer
# EquipmentUI.gd - Visual equipment management interface

signal equipment_closed

# UI References
@onready var equipment_slots_container = $Panel/VBoxContainer/EquipmentSlots if has_node("Panel/VBoxContainer/EquipmentSlots") else null
@onready var stats_panel = $Panel/VBoxContainer/StatsPanel if has_node("Panel/VBoxContainer/StatsPanel") else null
@onready var close_button = $Panel/VBoxContainer/TopBar/CloseButton if has_node("Panel/VBoxContainer/TopBar/CloseButton") else null
@onready var title_label = $Panel/VBoxContainer/TopBar/Title if has_node("Panel/VBoxContainer/TopBar/Title") else null

var starter_equipment_given = false

# Equipment slot display data
var equipment_slots = {
	"pickaxe": {
		"display_name": "Pickaxe",
		"icon": "⛏️",
		"description": "Used for mining ores"
	},
	"axe": {
		"display_name": "Axe",
		"icon": "🪓",
		"description": "Used for woodcutting"
	},
	"fishing_rod": {
		"display_name": "Fishing Rod",
		"icon": "🎣",
		"description": "Used for fishing"
	},
	"armor": {
		"display_name": "Armor",
		"icon": "🛡️",
		"description": "Protective gear"
	},
	"accessory": {
		"display_name": "Accessory",
		"icon": "💎",
		"description": "Special item slot"
	}
}

func _ready():
	visible = false
	
	# Connect buttons
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	
	# Connect to PlayerData signals
	PlayerData.equipment_changed.connect(_on_equipment_changed)
	
	# Ensure equipment structure exists
	_ensure_equipment_structure()

func _ensure_equipment_structure():
	"""Make sure PlayerData has proper equipment structure"""
	if not PlayerData.player_data.has("equipment"):
		PlayerData.player_data["equipment"] = {}
	
	# Ensure all slots exist
	for slot in equipment_slots.keys():
		if not PlayerData.player_data["equipment"].has(slot):
			PlayerData.player_data["equipment"][slot] = null
	
	# Give starter equipment on first load
	if not starter_equipment_given and _is_equipment_empty():
		_add_starter_equipment()

func _is_equipment_empty() -> bool:
	"""Check if player has any equipment"""
	if not PlayerData.player_data.has("equipment"):
		return true
	
	for slot in equipment_slots.keys():
		var item = PlayerData.get_equipped_item(slot)
		if item != null:
			return false
	
	# Also check inventory for any equipment items
	var inventory = PlayerData.get_all_items()
	for item_name in inventory.keys():
		if ItemDatabase.get_equipment_slot(item_name) != "":
			return false
	
	return true

func _add_starter_equipment():
	"""Give player starter tools"""
	if not starter_equipment_given:
		PlayerData.add_item("bronze_pickaxe", 1)
		PlayerData.add_item("bronze_axe", 1)
		PlayerData.add_item("fishing_rod", 1)
		starter_equipment_given = true
		print("Added starter equipment")

func show_equipment():
	_ensure_equipment_structure()
	visible = true
	refresh_equipment()
	refresh_stats()

func hide_equipment():
	visible = false
	equipment_closed.emit()

func refresh_equipment():
	if not equipment_slots_container:
		print("ERROR: EquipmentSlots container not found!")
		return
	
	# Clear existing slots
	for child in equipment_slots_container.get_children():
		child.queue_free()
	
	# Create slot displays in order
	var slot_order = ["pickaxe", "axe", "fishing_rod", "armor", "accessory"]
	
	for slot_name in slot_order:
		var slot_card = create_equipment_slot_card(slot_name)
		equipment_slots_container.add_child(slot_card)

func create_equipment_slot_card(slot_name: String) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 100)
	
	# Style the card
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.9)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	
	# Check if slot is equipped
	var equipped_item = PlayerData.get_equipped_item(slot_name)
	if equipped_item:
		style.border_color = Color(0.3, 0.8, 0.3)  # Green border if equipped
	else:
		style.border_color = Color(0.3, 0.3, 0.3)  # Gray border if empty
	
	card.add_theme_stylebox_override("panel", style)
	
	# Main container
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)
	margin.add_child(hbox)
	
	# Left side - Icon
	var icon_container = VBoxContainer.new()
	icon_container.custom_minimum_size = Vector2(60, 0)
	icon_container.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(icon_container)
	
	var icon_label = Label.new()
	icon_label.text = equipment_slots[slot_name]["icon"]
	icon_label.add_theme_font_size_override("font_size", 36)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_container.add_child(icon_label)
	
	# Middle - Slot info
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(info_vbox)
	
	# Slot name
	var slot_label = Label.new()
	slot_label.text = equipment_slots[slot_name]["display_name"]
	slot_label.add_theme_font_size_override("font_size", 16)
	slot_label.modulate = Color(0.9, 0.9, 1.0)
	info_vbox.add_child(slot_label)
	
	if equipped_item:
		# Show equipped item
		var item_name_label = Label.new()
		item_name_label.text = "📦 " + ItemDatabase.get_item_display_name(equipped_item)
		item_name_label.add_theme_font_size_override("font_size", 14)
		item_name_label.modulate = Color(0.3, 1.0, 0.3)
		info_vbox.add_child(item_name_label)
		
		# Show bonus
		var bonus_time = ItemDatabase.get_bonus_time(equipped_item)
		if bonus_time > 0:
			var bonus_label = Label.new()
			bonus_label.text = "⏱️ +%.1fs time" % bonus_time
			bonus_label.add_theme_font_size_override("font_size", 12)
			bonus_label.modulate = Color(1.0, 1.0, 0.5)
			info_vbox.add_child(bonus_label)
		
		# Fishing rod bar bonus
		if slot_name == "fishing_rod":
			var bar_bonus = ItemDatabase.get_bar_size_bonus(equipped_item)
			if bar_bonus > 0:
				var bar_label = Label.new()
				bar_label.text = "📊 +%.0f%% catch bar" % (bar_bonus * 100)
				bar_label.add_theme_font_size_override("font_size", 12)
				bar_label.modulate = Color(0.5, 0.8, 1.0)
				info_vbox.add_child(bar_label)
	else:
		# Empty slot
		var empty_label = Label.new()
		empty_label.text = "Empty"
		empty_label.add_theme_font_size_override("font_size", 14)
		empty_label.modulate = Color(0.5, 0.5, 0.5)
		info_vbox.add_child(empty_label)
		
		var desc_label = Label.new()
		desc_label.text = equipment_slots[slot_name]["description"]
		desc_label.add_theme_font_size_override("font_size", 11)
		desc_label.modulate = Color(0.6, 0.6, 0.6)
		info_vbox.add_child(desc_label)
	
	# Right side - Action buttons
	var button_vbox = VBoxContainer.new()
	button_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	button_vbox.add_theme_constant_override("separation", 5)
	hbox.add_child(button_vbox)
	
	if equipped_item:
		# Unequip button
		var unequip_btn = Button.new()
		unequip_btn.text = "Unequip"
		unequip_btn.custom_minimum_size = Vector2(80, 35)
		unequip_btn.modulate = Color(1.0, 0.6, 0.6)
		unequip_btn.pressed.connect(_on_unequip_pressed.bind(slot_name))
		button_vbox.add_child(unequip_btn)
	else:
		# Change/Equip button
		var equip_btn = Button.new()
		equip_btn.text = "Equip"
		equip_btn.custom_minimum_size = Vector2(80, 35)
		equip_btn.modulate = Color(0.6, 1.0, 0.6)
		equip_btn.pressed.connect(_on_equip_pressed.bind(slot_name))
		button_vbox.add_child(equip_btn)
	
	return card

func refresh_stats():
	if not stats_panel:
		return
	
	# Clear existing stats
	for child in stats_panel.get_children():
		child.queue_free()
	
	# Title
	var title = Label.new()
	title.text = "Equipment Bonuses"
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_panel.add_child(title)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	stats_panel.add_child(spacer)
	
	# Calculate total bonuses
	var total_mining_bonus = 0.0
	var total_woodcutting_bonus = 0.0
	var total_fishing_bonus = 0.0
	var total_bar_bonus = 0.0
	
	var pickaxe = PlayerData.get_equipped_item("pickaxe")
	if pickaxe:
		total_mining_bonus += ItemDatabase.get_bonus_time(pickaxe)
	
	var axe = PlayerData.get_equipped_item("axe")
	if axe:
		total_woodcutting_bonus += ItemDatabase.get_bonus_time(axe)
	
	var rod = PlayerData.get_equipped_item("fishing_rod")
	if rod:
		total_fishing_bonus += ItemDatabase.get_bonus_time(rod)
		total_bar_bonus += ItemDatabase.get_bar_size_bonus(rod)
	
	# Display bonuses
	add_stat_row(stats_panel, "⛏️ Mining Time:", "+%.1fs" % total_mining_bonus if total_mining_bonus > 0 else "No bonus")
	add_stat_row(stats_panel, "🪓 Woodcutting Time:", "+%.1fs" % total_woodcutting_bonus if total_woodcutting_bonus > 0 else "No bonus")
	add_stat_row(stats_panel, "🎣 Fishing Time:", "+%.1fs" % total_fishing_bonus if total_fishing_bonus > 0 else "No bonus")
	if total_bar_bonus > 0:
		add_stat_row(stats_panel, "📊 Catch Bar Size:", "+%.0f%%" % (total_bar_bonus * 100))
	
	# Show equipment count
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 10)
	stats_panel.add_child(spacer2)
	
	var equipped_count = 0
	# Safe equipment counting
	if PlayerData.player_data.has("equipment") and typeof(PlayerData.player_data["equipment"]) == TYPE_DICTIONARY:
		for slot in equipment_slots.keys():
			if PlayerData.get_equipped_item(slot) != null:
				equipped_count += 1
	
	var count_label = Label.new()
	count_label.text = "Equipped: %d / 5" % equipped_count
	count_label.add_theme_font_size_override("font_size", 14)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.modulate = Color(0.8, 0.8, 1.0)
	stats_panel.add_child(count_label)

func add_stat_row(container: Control, label_text: String, value_text: String):
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	container.add_child(hbox)
	
	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 13)
	label.modulate = Color(0.8, 0.8, 0.8)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)
	
	var value = Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 13)
	value.modulate = Color(1.0, 1.0, 0.7)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(value)

func _on_equip_pressed(slot_name: String):
	print("Equip button pressed for: " + slot_name)
	show_equip_selection(slot_name)

func _on_unequip_pressed(slot_name: String):
	print("Unequipping from: " + slot_name)
	var success = PlayerData.unequip_item(slot_name)
	if success:
		show_feedback("Unequipped!")
		refresh_equipment()
		refresh_stats()

func show_equip_selection(slot_name: String):
	"""Show a selection dialog with available items for this slot"""
	# Get all items in inventory that can go in this slot
	var available_items = []
	var inventory = PlayerData.get_all_items()
	
	for item_name in inventory.keys():
		if ItemDatabase.get_equipment_slot(item_name) == slot_name:
			available_items.append(item_name)
	
	if available_items.size() == 0:
		show_feedback("No items available for this slot!")
		return
	
	# Create selection popup
	create_selection_popup(slot_name, available_items)

func create_selection_popup(slot_name: String, items: Array):
	"""Create a popup dialog for selecting an item to equip"""
	# Create popup background
	var popup_bg = ColorRect.new()
	popup_bg.color = Color(0, 0, 0, 0.7)
	popup_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup_bg.name = "SelectionPopup"
	add_child(popup_bg)
	
	# Create popup panel
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 400)
	panel.position = Vector2(90, 160)
	popup_bg.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "Select " + equipment_slots[slot_name]["display_name"]
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Scroll container for items
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 280)
	vbox.add_child(scroll)
	
	var item_list = VBoxContainer.new()
	item_list.add_theme_constant_override("separation", 5)
	scroll.add_child(item_list)
	
	# Add item buttons
	for item_name in items:
		var item_btn = Button.new()
		item_btn.custom_minimum_size = Vector2(0, 50)
		
		var btn_text = ItemDatabase.get_item_display_name(item_name)
		var bonus_time = ItemDatabase.get_bonus_time(item_name)
		if bonus_time > 0:
			btn_text += " (+%.1fs)" % bonus_time
		
		item_btn.text = btn_text
		item_btn.pressed.connect(_on_item_selected_for_equip.bind(slot_name, item_name, popup_bg))
		item_list.add_child(item_btn)
	
	# Cancel button
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(0, 40)
	cancel_btn.pressed.connect(func(): popup_bg.queue_free())
	vbox.add_child(cancel_btn)

func _on_item_selected_for_equip(slot_name: String, item_name: String, popup: Control):
	"""Handle selecting an item to equip"""
	var success = PlayerData.equip_item(slot_name, item_name)
	if success:
		show_feedback("Equipped: " + ItemDatabase.get_item_display_name(item_name))
		refresh_equipment()
		refresh_stats()
	else:
		show_feedback("Failed to equip item!")
	
	popup.queue_free()

func show_feedback(text: String):
	"""Show temporary feedback message"""
	var feedback = Label.new()
	feedback.text = text
	feedback.add_theme_font_size_override("font_size", 20)
	feedback.modulate = Color(1.0, 1.0, 0.5)
	feedback.position = Vector2(180, 100)
	add_child(feedback)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(feedback, "position:y", 70, 1.0)
	tween.tween_property(feedback, "modulate:a", 0.0, 1.0)
	
	await tween.finished
	feedback.queue_free()

func _on_equipment_changed(_slot: String, _item_name):
	# Refresh display when equipment changes
	if visible:
		refresh_equipment()
		refresh_stats()

func _on_close_pressed():
	hide_equipment()

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel") and visible:
		hide_equipment()
		get_viewport().set_input_as_handled()

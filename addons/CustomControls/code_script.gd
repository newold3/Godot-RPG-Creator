@tool
class_name RPGCodeList
extends Node


func get_available_code() -> String:
	var used_codes = []
	used_codes += CustomEditItemList.EDITABLE_CODES
	used_codes += CustomEditItemList.NO_EDITABLE_CODES
	used_codes += CustomEditItemList.SUB_CODES
	used_codes.sort()
	
	var available_codes := []
	
	for i in range(1, 10000000, 1):
		if not i in used_codes:
			available_codes.append(i)
		
		if i > used_codes.size():
			break
	
	if not used_codes[-1] + 1 in available_codes:
		available_codes.append(str(used_codes[-1] + 1) + " or greater")
		
	return str(available_codes)


# Identifies which command each button belongs to (ID Button : {ID Command, dialog name).
var command_codes = {
	# Command Config Text Dialog (Code 1)
	# Code 1 (Parent) parameters {
	# 	scene_path, max_width, max_lines, character_delay, dot_delay comma_delay,
	# 	can_skip, skip_mode, skip_speed, start_animation,
	# 	end_animation, text_transition, fx_path, fx_volume, fx_pitch_min, fx_pitch_max }
	1 : {"command_code" : 1, "dialog" : "message_config_dialog"},
	# Command Text Dialog (Codes 2, 3)
	# Code 2 (Parent) parameters: { position, face, character_name -> { type, value }, is_floating_string }
	# Code 3 (Text Line) parameters: { line }
	2 : {"command_code" : 2, "dialog" : "advanced_text_editor_dialog"},
	# Command Resume Dialog (Code 95)
	# Code 95 (Parent) parameters: {  }
	117 : {"command_code" : 95, "dialog" : ""},
	# Command Show Choices (Codes 4, 5, 6, 7)
	# Code 4 (Parent) parameters {
	#	scene_path, cancel, default, max_choices, next, position, previous, move_fx, select_fx, cancel_fx }
	#   move_fx, select_fx, cancel_fx  = { path, volume, pitch }
	# Code 5 (When) parameters { name }
	# Code 6 (Cancel) parameters { }
	# Code 7 (End) parameters { }
	3 : {"command_code" : 4, "dialog" : "show_choices_dialog"},
	# Command Input Number (Code 8)
	# Code 8 (Parent) parameters { type, variable_id, digits, text_format }
	4 : {"command_code" : 8, "dialog" : "numerical_input_dialog"},
	# Command Select Item (Code 9)
	# Code 9 (Parent) parameters { variable_id, item_type }
	5 : {"command_code" : 9, "dialog" : "select_item_dialog"},
	# Comand Scrolling Dialog (Codes 10, 11)
	# Code 10 (Parent) parameters: { scroll_speed, scroll_direction, scroll_scene, enable_fast_forward }
	# Code 11 (Scrolling Text Line) parameters: { line }
	6 : {"command_code" : 10, "dialog" : "advanced_text_editor_dialog"},
	# Command Instant Text (Codes 34, 35)
	# Code 34 (Line 1) parameters: { first_line }
	# Code 35 (All other lines) parameters: { line }
	108 : {"command_code" : 34, "dialog" : "advanced_text_editor_dialog"},
	# Command Change Gold (Code 12)
	# Code 12 (Parent) parameters { operation_type, value_type, value }
	7 : {"command_code" : 12, "dialog" : "change_gold_dialog"},
	# Command Change Items (Code 13)
	# Code 13 (Parent) parameters { operation_type, value_type, value, item_id }
	8 : {"command_code" : 13, "dialog" : "change_item_dialog"},
	# Command Change Weapons (Code 14)
	# Code 14 (Parent) parameters { operation_type, value_type, value, level, item_id, include_equipment }
	9 : {"command_code" : 14, "dialog" : "change_weapon_dialog"},
	# Command Change Armors (Code 15)
	# Code 15 (Parent) parameters { operation_type, value_type, value, level, item_id, include_equipment }
	10 : {"command_code" : 15, "dialog" : "change_armor_dialog"},
	# Command Change Party Members (Code 16)
	# Code 16 (Parent) parameters { operation_type, actor_id, initialize }
	11 : {"command_code" : 16, "dialog" : "change_party_member_dialog"},
	# Command Change Leader (Code 36)
	# Code 36 (Parent) parameters { leader_id, is_locked }
	109 : {"command_code" : 36, "dialog" : "change_leader_dialog"},
	# Command Combar Experience Mode Leader (Code 60)
	# Code 60 (Parent) parameters { type }
	115 : {"command_code" : 60, "dialog" : "change_combat_xp_dialog"},
	# Command Control Switches (Code 17)
	# Code 17 (Parent) parameters { operation_type, from, to }
	12 : {"command_code" : 17, "dialog" : "control_switches_dialog"},
	# Command Control Variables (Code 18)
	# Code 18 (Parent) parameters { from, to, operation_type, operand_type, value1, value2, value3 }
	13 : {"command_code" : 18, "dialog" : "control_variables_dialog"},
	# Command Combar Experience Mode Leader (Code 61)
	# Code 61 (Parent) parameters { id, value }
	113 : {"command_code" : 61, "dialog" : "text_variable_dialog"},
	# Command Control Self Switches (Code 19)
	# Code 19 (Parent) parameters { operation_type, switch_id }
	14 : {"command_code" : 19, "dialog" : "control_self_switches_dialog"},
	# Command Change User Parameter (Code 302)
	# Code 302 (Parent) parameters { target_id, param_id, value }
	130 : {"command_code" : 302, "dialog" : "change_user_parameter_dialog"},
	# Command Change Stat (Code 303)
	# Code 303 (Parent) parameters { stat_id, value }
	131 : {"command_code" : 303, "dialog" : "change_stat_dialog"},
	# Command Control Timer Dialog (Code 20)
	# Code 20 (Parent) parameters { operation_type, minutes, soconds, timer_scene, timer_id, timer_title, extra_config }
	15 : {"command_code" : 20, "dialog" : "control_timer_dialog"},
	# Command Conditional Branch (Codes 21, 22, 23)
	# Code 21 (Parent) parameters { item_selected, value1, value2, value3, value4 }
	# Code 22 (Else) parameters { }
	# Code 23 (End) parameters { }
	16 : {"command_code" : 21, "dialog" : "conditional_branch_dialog"},
	# Command Start Loop (Codes 24, 25)
	# Code 24 (Parent) parameters { }
	# Code 25 (Repeat / End) parameters { }
	17 : {"command_code" : 24, "dialog" : ""},
	# Command Break Loop (Code 26)
	# Code 26 (Parent) parameters { }
	18 : {"command_code" : 26, "dialog" : ""},
	# Command Exit Event Processing (Codes 27)
	# Code 27 (Parent) parameters { }
	19 : {"command_code" : 27, "dialog" : ""},
	# Command Select Common Event (Code 28)
	# Code 28 (Parent) parameters { id }
	20 : {"command_code" : 28, "dialog" : ""},
	# Command Set Label (Code 29)
	# Code 29 (Parent) parameters { text }
	21 : {"command_code" : 29, "dialog" : ""},
	# Command Jump To Label (Code 30)
	# Code 30 (Parent) parameters { text }
	22 : {"command_code" : 30, "dialog" : "jump_to_label_dialog"},
	# Command Comment (Codes 31, 32)
	# Code 31 (Parent) parameters: { first_line }
	# Code 32 (Comment Line) parameters: { line }
	23 : {"command_code" : 31, "dialog" : "simple_text_editor"},
	# Command Wait (Code 33)
	# Code 33 (Parent) parameters { duration, is_local }
	24 : {"command_code" : 33, "dialog" : "wait_dialog"},
	# Command Change Actor HP (Code 37)
	# Code 37 (Parent) parameters { actor_type, actor_id, operand, operand_type, operand_value }
	25 : {"command_code" : 37, "dialog" : "change_actor_parameter_dialog"},
	# Command Change Actor MP (Code 38)
	# Code 38 (Parent) parameters { actor_type, actor_id, operand, operand_type, operand_value }
	26 : {"command_code" : 38, "dialog" : "change_actor_parameter_dialog"},
	# Command Change Actor TP (Code 39)
	# Code 39 (Parent) parameters { actor_type, actor_id, operand, operand_type, operand_value }
	27 : {"command_code" : 39, "dialog" : "change_actor_parameter_dialog"},
	# Command Change Actor State (Code 40)
	# Code 40 (Parent) parameters { actor_type, actor_id, operand, state_id }
	28 : {"command_code" : 40, "dialog" : "change_actor_state_dialog"},
	# Command Actor Recover All (Code 41)
	# Code 41 (Parent) parameters { actor_type, actor_id }
	29 : {"command_code" : 41, "dialog" : "actor_full_recovery_dialog"},
	# Command Change Actor Experience (Code 42)
	# Code 42 (Parent) parameters { actor_type, actor_id, operand, operand_type, operand_value, show_level_up }
	30 : {"command_code" : 42, "dialog" : "change_actor_parameter_dialog"},
	# Command Change Actor Level (Code 43)
	# Code 43 (Parent) parameters { actor_type, actor_id, operand, operand_type, operand_value, show_level_up }
	31 : {"command_code" : 43, "dialog" : "change_actor_parameter_dialog"},
	# Command Change Actor Parameter (Code 44)
	# Code 44 (Parent) parameters { actor_type, actor_id, operand, operand_type, operand_value, parameter_id }
	32 : {"command_code" : 44, "dialog" : "change_actor_parameter_dialog"},
	# Command Change Actor Skill (Code 45)
	# Code 45 (Parent) parameters { actor_type, actor_id, operand, skill_id }
	33 : {"command_code" : 45, "dialog" : "change_actor_skill_dialog"},
	# Command Change Actor Equipment (Code 46)
	# Code 46 (Parent) parameters { actor_id, equipment_type_id, item_id }
	34 : {"command_code" : 46, "dialog" : "change_equipment_dialog"},
	# Command Change Actor Equipment (Code 47)
	# Code 47 (Parent) parameters { actor_id, name }
	35 : {"command_code" : 47, "dialog" : "change_actor_name_dialog"},
	# Command Change Actor Class (Code 48)
	# Code 48 (Parent) parameters { actor_id, class_id, keep_level }
	36 : {"command_code" : 48, "dialog" : "change_actor_class_dialog"},
	# Command Change Profession (Code 300)
	# Code 300 (Parent) parameters { type, profession_id, reset_level, level, preserve_level, action_type }
	128 : {"command_code" : 300, "dialog" : "change_profession_dialog"},
	# Command Change Profession (Code 301)
	# Code 301 (Parent) parameters { profession_id }
	129 : {"command_code" : 301, "dialog" : "upgrade_profession_dialog"},
	# Command Change Actor Nickname (Code 49)
	# Code 49 (Parent) parameters { actor_id, nickname}
	37 : {"command_code" : 49, "dialog" : "change_actor_nickname_dialog"},
	# Command Change Actor Profile (Code 50, 51)
	# Code 50 (Line 1) parameters { actor_id }
	# Code 51 (All Other Lines) parameters { line }
	38 : {"command_code" : 50, "dialog" : "change_actor_profile_dialog"},
	# Command Add Or Revome Trait (Code 62)
	# Code 62 parameters { actor_id, type, RPGTrait }
	114: {"command_code" : 62, "dialog" : "add_or_remove_actor_trait_dialog"},
	# Command Set Transition Config (Code 52)
	# Code 52 parameters { type, duration, transition_image*, transition_color*, invert*}
	39: {"command_code" : 52, "dialog" : "set_transition_dialog"},
	# Command Transfer Player (Code 53)
	# Code 53 parameters { target, type, vehicle_id*, direction*, assigned_map_id*,
	# assigned_x*, assigned_y*, map_id*, x*, y*, event_id*, swap_event_id*, *delay_transfer, wait_animation }
	40: {"command_code" : 53, "dialog" : "transfer_dialog", "target": 0},
	41: {"command_code" : 53, "dialog" : "transfer_dialog", "target": 1},
	42: {"command_code" : 53, "dialog" : "transfer_dialog", "target": 2},
	# Command Scroll / Zoom Map (Code 54)
	# Code 54 parameters { type, duration, wait, direction*, amount*, zoom* }
	43: {"command_code" : 54, "dialog" : "scroll_zoom_map_dialog"},
	# Command Set Movement Route (Code 57, 58)
	# Code 57 parameters { target, loop, skippable, wait }
	# Code 58 parameters { movement_command }
	44 : {"command_code" : 57, "dialog" : "movement_route_dialog"},
	# Command Scroll / Zoom Map (Code 59)
	# Code 59 parameters { type, transport_id* }
	45: {"command_code" : 59, "dialog" : "get_in_out_vehicle_dialog"},
	# Fade Out (Code 63)
	# Code 63 parameters { duration }
	46: {"command_code" : 63, "dialog" : "fade_in_out_dialog"},
	# Fade In (Code 64)
	# Code 64 parameters { duration }
	47: {"command_code" : 64, "dialog" : "fade_in_out_dialog"},
	# Tint Screen (Code 65)
	# Code 65 parameters { color, duration, wait, remove }
	48: {"command_code" : 65, "dialog" : "tint_screen_and_flash_dialog"},
	# Flash Screen (Code 66)
	# Code 66 parameters { color, duration, wait }
	49: {"command_code" : 66, "dialog" : "tint_screen_and_flash_dialog"},
	# Shake Screen (Code 67)
	# Code 67 parameters { duration, power }
	50: {"command_code" : 67, "dialog" : "shake_screen_dialog"},
	# Add or Remove Weather Scene (Code 68)
	# Code 68 parameters { type, id, scene }
	51: {"command_code" : 68, "dialog" : "set_weather_effects_dialog"},
	# Change Transparency (Code 69)
	# Code 69 parameters { value }
	52: {"command_code" : 69, "dialog" : "change_player_transparency_dialog"},
	# Change Player Followers (Code 70)
	# Code 70 parameters { value }
	53: {"command_code" : 70, "dialog" : "change_player_followers_dialog"},
	# Followers Leader Tracking (Code 71)
	# Code 71 parameters { value }
	54: {"command_code" : 71, "dialog" : "gather_followers_dialog"},
	# Show Animation (Code 72)
	# Code 72 parameters { target_id, animation_id, wait }
	55: {"command_code" : 72, "dialog" : "show_animation_dialog"},
	# Show Ballon Icon (Code 73)
	# Code 73 parameters { target_id, path, wait }
	56: {"command_code" : 73, "dialog" : "show_ballon_icon_dialog"},
	# Show Player Action (Code 74)
	# Code 74 parameters { index }
	57: {"command_code" : 74, "dialog" : "show_player_action_dialog"},
	# Show Image (Code 75)
	# Code 75 parameters { index, path, ImageType, origin, position_type, position, scale, rotation, modulate, blend_type, start_animation, end_animation, start_animation_duration, end_animation_duration, z_index, enable_sort }
	58: {"command_code" : 75, "dialog" : "show_image_dialog"},
	# Move Image (Code 76)
	# Code 76 parameters { index, relative_movement, position_type, position, duration, wait }
	59: {"command_code" : 76, "dialog" : "move_image_dialog"},
	# Rotate Image (Code 77)
	# Code 77 parameters { index, rotation, duration, wait }
	60: {"command_code" : 77, "dialog" : "rotate_image_dialog"},
	# Scale Image (Code 78)
	# Code 78 parameters { index, scale, duration, wait }
	116: {"command_code" : 78, "dialog" : "scale_image_dialog"},
	# Tint Image (Code 79)
	# Code 79 parameters { index, duration, modulate, wait }
	61: {"command_code" : 79, "dialog" : "tint_image_dialog"},
	# Erase Image (Code 80)
	# Code 80 parameters { index }
	62: {"command_code" : 80, "dialog" : "erase_image_dialog"},
	# Add Scene (Code 81)
	# Code 81 parameters { index, path, wait, is_map_scene }
	63: {"command_code" : 81, "dialog" : "select_scene_dialog"},
	# Manipulate Scene (Code 124)
	# Code 124 parameters { index, function_name, wait, params }
	127: {"command_code" : 124, "dialog" : "manipulate_scene_dialog"},
	# Remove Scene (Code 82)
	# Code 82 parameters { index }
	64: {"command_code" : 82, "dialog" : "erase_scene_dialog"},
	# Play BGM (Code 83)
	# Code 83 parameters { path, volume, pitch, fadein }
	65: {"command_code" : 83, "dialog" : "select_sound_dialog", "target": "bgm"},
	# Stop BGM (Code 84)
	# Code 84 parameters { duration }
	66: {"command_code" : 84, "dialog" : "wait_dialog"},
	# Save BGM (Code 85)
	# Code 85 parameters {  }
	67: {"command_code" : 85, "dialog" : ""},
	# Resume BGM (Code 86)
	# Code 86 parameters {  }
	68: {"command_code" : 86, "dialog" : ""},
	# Play BGS (Code 87)
	# Code 87 parameters { path, volume, pitch, fadein }
	69: {"command_code" : 87, "dialog" : "select_sound_dialog", "target": "bgs"},
	# Stop BGS (Code 88)
	# Code 88 parameters { duration }
	70: {"command_code" : 88, "dialog" : "wait_dialog"},
	# Play ME (Code 89)
	# Code 89 parameters { path, volume, pitch }
	71: {"command_code" : 89, "dialog" : "select_sound_dialog", "target": "me"},
	# Play SE (Code 90)
	# Code 90 parameters { path, volume, pitch, pitch2 }
	72: {"command_code" : 90, "dialog" : "select_sound_dialog", "target": "se"},
	# Stop SE (Code 91)
	# Code 91 parameters {  }
	73: {"command_code" : 91, "dialog" : ""},
	# Play Video (Code 92)
	# Code 92 parameters { path, wait, loop, fadein, fadeout, color }
	74: {"command_code" : 92, "dialog" : "select_video_scene_dialog"},
	# Stop Video (Code 93)
	# Code 93 parameters { duration }
	75: {"command_code" : 93, "dialog" : "wait_dialog"},
	# Manage Camera Targets (Code 123)
	# Code 123 parameters { targets, priorities }
	126: {"command_code" : 123, "dialog" : "manage_camera_targets_dialog"},
	# Erase Event (Code 94)
	# Code 94 parameters {  }
	107: {"command_code" : 94, "dialog" : ""},
	# Show Shop (Codes 96, 97)
	# Code 96 parameters { sales_mode, buy_list, purchase_ratio, sales_ratio, shop_name, shop_scene, shop_keeper }
	# Code 97 parameters { type, item_id, quantity, price_mode, price }
	76: {"command_code" : 96, "dialog" : "show_shop_dialog"},
	# Open Blacksmith Shop (Code 200)
	# Code 200 parameters {  }
	118: {"command_code" : 200, "dialog" : ""},
	# Open Class upgrade Shop (Codes 201)
	# Code 96 parameters {  }
	119: {"command_code" : 201, "dialog" : "show_shop_dialog"},
	# Input Actor Name (Code 98)
	# Code 98 parameters { actor_id, max_letters }
	77: {"command_code" : 98, "dialog" : "change_actor_name"},
	# Show Menu Scene (Code 99)
	# Code 99 parameters {  }
	78: {"command_code" : 99, "dialog" : ""},
	# Show Save Scene (Code 100)
	# Code 100 parameters {  }
	79: {"command_code" : 100, "dialog" : ""},
	# Show Game Over Scene (Code 101)
	# Code 101 parameters {  }
	80: {"command_code" : 101, "dialog" : ""},
	# Show Title Scene (Code 102)
	# Code 102 parameters {  }
	81: {"command_code" : 102, "dialog" : ""},
	# Change Map name Display (Code 103)
	# Code 103 parameters { selected }
	82: {"command_code" : 103, "dialog" : "enabled_disabled_dialog"},
	# Change Battle back (Code 104)
	# Code 104 parameters { path }
	83: {"command_code" : 104, "dialog" : "select_image_or_scene_dialog"},
	# Change Battle Parallax (Code 105)
	# Code 105 parameters { path }
	84: {"command_code" : 105, "dialog" : "select_image_or_scene_dialog"},
	# Get Location Info (Code 106)
	# Code 106 parameters { variable_type, variable_id, info_selected, location_type, cell }
	85: {"command_code" : 106, "dialog" : "get_location_info_dialog"},
	# Change Battle BGM (Code 110)
	# Code 110 parameters { path, volume, pitch, fade_in }
	86: {"command_code" : 110, "dialog" : "select_sound_dialog"},
	# Change Victory ME (Code 111)
	# Code 111 parameters { path, volume, pitch, fade_in }
	87: {"command_code" : 111, "dialog" : "select_sound_dialog"},
	# Change Defeat ME (Code 112)
	# Code 112 parameters { path, volume, pitch, fade_in }
	88: {"command_code" : 112, "dialog" : "select_sound_dialog"},
	# Change Vehicle BGM (Code 110)
	# Code 110 parameters { vehicle_id, path, volume, pitch, fade_in }
	110: {"command_code" : 121, "dialog" : "change_vehicle_sound_dialog"},
	# Change Save Access (Code 113)
	# Code 113 parameters { selected }
	89: {"command_code" : 113, "dialog" : "enabled_disabled_dialog"},
	# Change Menu Access (Code 114)
	# Code 114 parameters { selected }
	90: {"command_code" : 114, "dialog" : "enabled_disabled_dialog"},
	# Change Encounter Rate (Code 115)
	# Code 115 parameters { value }
	91: {"command_code" : 115, "dialog" : "select_number_value_dialog"},
	# Change Formation Access (Code 116)
	# Code 116 parameters { selected }
	92: {"command_code" : 116, "dialog" : "enabled_disabled_dialog"},
	# Change Game Speed (Code 117)
	# Code 117 parameters { value }
	93: {"command_code" : 117, "dialog" : "select_number_value_dialog"},
	# Change Actor Scene (Code 118)
	# Code 118 parameters { index, path }
	94: {"command_code" : 118, "dialog" : "change_actor_or_vehicle_scene_dialog", "type": 1},
	# Change vehicle Scene (Code 119)
	# Code 119 parameters { index, path }
	95: {"command_code" : 119, "dialog" : "change_actor_or_vehicle_scene_dialog", "type": 0},
	# Change Tileset (Code 107)
	# Code 107 parameters { layer, path }
	111: {"command_code" : 202, "dialog" : "change_tileset_dialog"},
	# Change Tile State (Code 125)
	# Code 125 parameters { layer, use_all_layers, state, tiles }
	132: {"command_code" : 125, "dialog" : "disable_tile_from_tilemap_layer_dialog"},
	# Change Language (Code 120)
	# Code 120 parameters { locale }
	112: {"command_code" : 120, "dialog" : "change_language_dialog"},
	# Change Formation Access (Code 210)
	# Code 210 parameters { selected }
	122: {"command_code" : 210, "dialog" : "enabled_disabled_dialog"},
	# Change Formation Access (Code 211)
	# Code 211 parameters { selected }
	123: {"command_code" : 211, "dialog" : "enabled_disabled_dialog"},
	# Perform Transition (Code 55)
	# Code 55 parameters { type }
	124: {"command_code" : 55, "dialog" : "perform_transition_dialog"},
	# Start Batlle (Code 500, 501, 502, 503, 504)
	# Code 500 (parent) parameters { type, value }
	# Code 501 (when win) parameters { }
	# Code 502 (when lost) parameters { }
	# Code 503 (when retreat) parameters { }
	# Code 504 (end) parameters { }
	96: {"command_code" : 500, "dialog" : "start_battle_dialog"},
	# Execute Command Script (Code 5000)
	# Code 5000 parameters { script }
	106: {"command_code" : 5000, "dialog" : "execute_script_command_dialog"},
}

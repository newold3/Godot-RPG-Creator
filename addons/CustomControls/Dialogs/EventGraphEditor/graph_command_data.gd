@tool
class_name GraphCommandData
extends RefCounted

## Category Colors for GraphNodes
const CATEGORY_COLORS: Dictionary = {
	"Messages": Color("#3a86ff"),
	"Flow Control": Color("#ffbe0b"),
	"Game Progress": Color("#06d6a0"),
	"Party Management": Color("#fb5607"),
	"Actor Management": Color("#ff006e"),
	"Movement & Map": Color("#8338ec"),
	"Character & Followers": Color("#38b000"),
	"Pictures & Scenes": Color("#9d4edd"),
	"Screen & Effects": Color("#ff758f"),
	"Audio & Video": Color("#4cc9f0"),
	"Scene Control & System": Color("#7209b7"),
	"Battle": Color("#d90429"),
	"Advanced": Color("#4a5568")
}

## Master Command Definitions
const ALL_CATEGORIES: Dictionary = {
	"Messages": [
		{"button_id": 1, "code": 1, "text": "⚙️ Dialog Settings", "dialog": "message_config_dialog", "tooltip": "Configure dialogue box appearance and speed."},
		{"button_id": 2, "code": 2, "text": "💬 Show Dialog Text", "dialog": "advanced_text_editor_dialog", "tooltip": "Display character dialogue or narration."},
		{"button_id": 117, "code": 95, "text": "⏯️ Resume Dialog", "dialog": "", "tooltip": "Resume paused dialogue."},
		{"button_id": 3, "code": 4, "text": "❓ Show Choices", "dialog": "show_choices_dialog", "tooltip": "Present selectable options to the player."},
		{"button_id": 4, "code": 8, "text": "⌨️ Number / Text Input", "dialog": "numerical_input_dialog", "tooltip": "Prompt player for number or text input."},
		{"button_id": 5, "code": 9, "text": "⭐ Select Key Item", "dialog": "select_item_dialog", "tooltip": "Prompt player to select an item."},
		{"button_id": 6, "code": 10, "text": "📜 Scrolling Text", "dialog": "advanced_text_editor_dialog", "tooltip": "Display scrolling text lines."},
		{"button_id": 108, "code": 34, "text": "⚡ Instant Text", "dialog": "advanced_text_editor_dialog", "tooltip": "Display text immediately without delay."}
	],
	"Flow Control": [
		{"button_id": 16, "code": 21, "text": "⚖️ Conditional Branch", "dialog": "conditional_branch_dialog", "tooltip": "Branch logic based on condition."},
		{"button_id": 17, "code": 24, "text": "🔁 Loop", "dialog": "", "tooltip": "Repeat actions until broken."},
		{"button_id": 18, "code": 26, "text": "💥 Break Loop", "dialog": "", "tooltip": "Exit the current loop."},
		{"button_id": 19, "code": 27, "text": "⏹️ Exit Event Processing", "dialog": "", "tooltip": "Halt current event execution."},
		{"button_id": 20, "code": 28, "text": "🌐 Call Common Event", "dialog": "select_any_data_dialog", "tooltip": "Execute a shared common event."},
		{"button_id": 21, "code": 29, "text": "🚩 Set Label", "dialog": "", "tooltip": "Create a jump target marker."},
		{"button_id": 22, "code": 30, "text": "⏩ Jump To Label", "dialog": "jump_to_label_dialog", "tooltip": "Jump execution to a label marker."},
		{"button_id": 23, "code": 31, "text": "💭 Comment", "dialog": "simple_text_editor", "tooltip": "Non-executable developer note."},
		{"button_id": 24, "code": 33, "text": "⏸️ Wait", "dialog": "wait_dialog", "tooltip": "Pause execution for frames or seconds."}
	],
	"Game Progress": [
		{"button_id": 12, "code": 17, "text": "🎛️ Control Switch", "dialog": "control_switches_dialog", "tooltip": "Turn global switches ON or OFF."},
		{"button_id": 13, "code": 18, "text": "🔢 Control Variable", "dialog": "control_variables_dialog", "tooltip": "Set or calculate integer variables."},
		{"button_id": 113, "code": 61, "text": "✍️ Text Variable Control", "dialog": "text_variable_dialog", "tooltip": "Modify string variables."},
		{"button_id": 14, "code": 19, "text": "📍 Local Switch Control", "dialog": "control_self_switches_dialog", "tooltip": "Change local switch (A, B, C, D)."},
		{"button_id": 130, "code": 302, "text": "🎚️ User Parameter", "dialog": "change_user_parameter_dialog", "tooltip": "Modify custom user parameter."},
		{"button_id": 131, "code": 303, "text": "🥧 Change Stat", "dialog": "change_stat_dialog", "tooltip": "Modify a database stat value."},
		{"button_id": 15, "code": 20, "text": "⏰ Set Timer", "dialog": "control_timer_dialog", "tooltip": "Start or stop countdown timer."},
		{"button_id": 125, "code": 126, "text": "📋 Manage Quest", "dialog": "manage_quest_dialog", "tooltip": "Unlock, start, update, or finish quests."}
	],
	"Party Management": [
		{"button_id": 7, "code": 12, "text": "🪙 Change Gold", "dialog": "change_gold_dialog", "tooltip": "Add or remove gold."},
		{"button_id": 8, "code": 13, "text": "📦 Change Items", "dialog": "change_item_dialog", "tooltip": "Add or remove items in inventory."},
		{"button_id": 9, "code": 14, "text": "🗡️ Change Weapons", "dialog": "change_weapon_dialog", "tooltip": "Add or remove weapons."},
		{"button_id": 10, "code": 15, "text": "🛡️ Change Armors", "dialog": "change_armor_dialog", "tooltip": "Add or remove armors."},
		{"button_id": 133, "code": 127, "text": "👗 Change Sets / Costumes", "dialog": "change_set_dialog", "tooltip": "Change actor sets or costumes."},
		{"button_id": 11, "code": 16, "text": "👥 Change Party Members", "dialog": "change_party_member_dialog", "tooltip": "Add or remove heroes from active party."},
		{"button_id": 109, "code": 36, "text": "👑 Change Party Leader", "dialog": "change_leader_dialog", "tooltip": "Set who leads the party."},
		{"button_id": 115, "code": 60, "text": "🎮 Combat Experience Mode", "dialog": "change_combat_xp_dialog", "tooltip": "Configure battle XP distribution."}
	],
	"Actor Management": [
		{"button_id": 25, "code": 37, "text": "❤️ Change HP", "dialog": "change_actor_parameter_dialog", "tooltip": "Increase or decrease actor HP."},
		{"button_id": 26, "code": 38, "text": "💙 Change MP", "dialog": "change_actor_parameter_dialog", "tooltip": "Increase or decrease actor MP."},
		{"button_id": 27, "code": 39, "text": "🎯 Change TP", "dialog": "change_actor_parameter_dialog", "tooltip": "Increase or decrease actor TP."},
		{"button_id": 28, "code": 40, "text": "✨ Change State", "dialog": "change_actor_state_dialog", "tooltip": "Apply or remove status effect."},
		{"button_id": 29, "code": 41, "text": "🌟 Full Recovery", "dialog": "actor_full_recovery_dialog", "tooltip": "Recover all HP, MP, and remove debuffs."},
		{"button_id": 30, "code": 42, "text": "📈 Change Experience", "dialog": "change_actor_parameter_dialog", "tooltip": "Grant or remove EXP."},
		{"button_id": 31, "code": 43, "text": "📊 Change Level", "dialog": "change_actor_parameter_dialog", "tooltip": "Set or increase level."},
		{"button_id": 32, "code": 44, "text": "💪 Change Parameter", "dialog": "change_actor_parameter_dialog", "tooltip": "Modify stats like ATK, DEF, etc."},
		{"button_id": 33, "code": 45, "text": "🎪 Change Skills", "dialog": "change_actor_skill_dialog", "tooltip": "Learn or forget skills."},
		{"button_id": 34, "code": 46, "text": "🎒 Change Equipment", "dialog": "change_equipment_dialog", "tooltip": "Force equip weapons or gear."},
		{"button_id": 35, "code": 47, "text": "🏷️ Change Name", "dialog": "change_actor_name_dialog", "tooltip": "Rename an actor."},
		{"button_id": 36, "code": 48, "text": "👤 Change Class", "dialog": "change_actor_class_dialog", "tooltip": "Change actor character class."},
		{"button_id": 128, "code": 300, "text": "⛏️ Change Profession", "dialog": "change_profession_dialog", "tooltip": "Assign a gathering/crafting profession."},
		{"button_id": 129, "code": 301, "text": "⚒️ Upgrade Profession", "dialog": "upgrade_profession_dialog", "tooltip": "Level up profession tier."},
		{"button_id": 37, "code": 49, "text": "🗣️ Change Nickname", "dialog": "change_actor_nickname_dialog", "tooltip": "Change actor title/nickname."},
		{"button_id": 38, "code": 50, "text": "📸 Change Profile", "dialog": "change_actor_profile_dialog", "tooltip": "Edit actor lore description."},
		{"button_id": 114, "code": 62, "text": "➕ Add / Remove Trait", "dialog": "add_or_remove_actor_trait_dialog", "tooltip": "Add or remove passive trait."}
	],
	"Movement & Map": [
		{"button_id": 39, "code": 52, "text": "🚀 Set Transition", "dialog": "set_transition_dialog", "tooltip": "Configure map transfer transition effect."},
		{"button_id": 40, "code": 53, "text": "🚶 Transfer Player", "dialog": "transfer_dialog", "tooltip": "Teleport player to coordinates/map."},
		{"button_id": 41, "code": 53, "text": "🚗 Set Vehicle Location", "dialog": "transfer_dialog", "tooltip": "Teleport a vehicle."},
		{"button_id": 42, "code": 53, "text": "🧭 Set Event Location", "dialog": "transfer_dialog", "tooltip": "Move an event to new position."},
		{"button_id": 43, "code": 54, "text": "🗺️ Scroll / Zoom Map", "dialog": "scroll_zoom_map_dialog", "tooltip": "Pan camera or zoom map view."},
		{"button_id": 44, "code": 57, "text": "🛤️ Set Movement Route", "dialog": "movement_route_dialog", "tooltip": "Assign step-by-step movement path."},
		{"button_id": 45, "code": 59, "text": "🚶‍♂️↔️🚗 Get In/Out Vehicle", "dialog": "get_in_out_vehicle_dialog", "tooltip": "Mount or dismount vehicle."},
		{"button_id": 82, "code": 103, "text": "🗺️ Change Map Name Display", "dialog": "enabled_disabled_dialog", "tooltip": "Toggle map title banner on entry."},
		{"button_id": 83, "code": 104, "text": "🌄 Change Battle Background", "dialog": "select_image_or_scene_dialog", "tooltip": "Set combat backdrop."},
		{"button_id": 84, "code": 105, "text": "🌀 Change Parallax Background", "dialog": "select_image_or_scene_dialog", "tooltip": "Change parallax layer graphic."},
		{"button_id": 85, "code": 106, "text": "❓ Get Location Info", "dialog": "get_location_info_dialog", "tooltip": "Store terrain/tile info in variable."},
		{"button_id": 111, "code": 202, "text": "🧱 Change Tileset", "dialog": "change_tileset_dialog", "tooltip": "Swap map tileset resource."},
		{"button_id": 132, "code": 125, "text": "🧩 Set Tile State", "dialog": "disable_tile_from_tilemap_layer_dialog", "tooltip": "Disable or enable specific tile."}
	],
	"Character & Followers": [
		{"button_id": 52, "code": 69, "text": "👻 Change Transparency", "dialog": "change_player_transparency_dialog", "tooltip": "Make player invisible or visible."},
		{"button_id": 53, "code": 70, "text": "👥 Change Player Followers", "dialog": "change_player_followers_dialog", "tooltip": "Toggle visible party followers."},
		{"button_id": 54, "code": 71, "text": "🔄 Followers Leader Tracking", "dialog": "gather_followers_dialog", "tooltip": "Gather followers to leader position."},
		{"button_id": 55, "code": 72, "text": "💫 Show Animation", "dialog": "show_animation_dialog", "tooltip": "Play animation over character."},
		{"button_id": 56, "code": 73, "text": "🗯️ Show Balloon Icon", "dialog": "show_ballon_icon_dialog", "tooltip": "Show emotion bubble icon."},
		{"button_id": 57, "code": 74, "text": "🕺 Show Player Action", "dialog": "show_player_action_dialog", "tooltip": "Trigger pose or custom gesture."}
	],
	"Pictures & Scenes": [
		{"button_id": 58, "code": 75, "text": "🖼️ Show Picture", "dialog": "show_image_dialog", "tooltip": "Display an image on screen."},
		{"button_id": 59, "code": 76, "text": "✋➡️ Move Picture", "dialog": "move_image_dialog", "tooltip": "Tween image position on screen."},
		{"button_id": 60, "code": 77, "text": "🔃 Rotate Picture", "dialog": "rotate_image_dialog", "tooltip": "Rotate image over time."},
		{"button_id": 116, "code": 78, "text": "⬛↔️ Scale Picture", "dialog": "scale_image_dialog", "tooltip": "Scale image dimensions."},
		{"button_id": 61, "code": 79, "text": "🎨 Tint Picture", "dialog": "tint_image_dialog", "tooltip": "Apply color tint to picture."},
		{"button_id": 62, "code": 80, "text": "🧹 Erase Picture", "dialog": "erase_image_dialog", "tooltip": "Remove image from screen."},
		{"button_id": 63, "code": 81, "text": "🎬➕ Add Scene", "dialog": "select_scene_dialog", "tooltip": "Instantiate scene overlay."},
		{"button_id": 127, "code": 124, "text": "🔧🎬 Manipulate Scene", "dialog": "manipulate_scene_dialog", "tooltip": "Call function on added scene."},
		{"button_id": 64, "code": 82, "text": "🎬➖ Remove Scene", "dialog": "erase_scene_dialog", "tooltip": "Remove overlay scene."}
	],
	"Screen & Effects": [
		{"button_id": 46, "code": 63, "text": "🌑 Fadeout Screen", "dialog": "fade_in_out_dialog", "tooltip": "Fade screen to black."},
		{"button_id": 47, "code": 64, "text": "🌕 Fadein Screen", "dialog": "fade_in_out_dialog", "tooltip": "Fade screen in from black."},
		{"button_id": 124, "code": 55, "text": "🔁 Perform Transition", "dialog": "perform_transition_dialog", "tooltip": "Run transition shader effect."},
		{"button_id": 48, "code": 65, "text": "🌈 Tint Screen", "dialog": "tint_screen_and_flash_dialog", "tooltip": "Color grade the whole screen."},
		{"button_id": 49, "code": 66, "text": "⚡ Flash Screen", "dialog": "tint_screen_and_flash_dialog", "tooltip": "Quick color flash flashbang."},
		{"button_id": 50, "code": 67, "text": "📳 Shake Screen", "dialog": "shake_screen_dialog", "tooltip": "Earthquake or impact shake."},
		{"button_id": 51, "code": 68, "text": "🌦️ Set Weather Effects", "dialog": "set_weather_effects_dialog", "tooltip": "Rain, snow, dust, or fog."}
	],
	"Audio & Video": [
		{"button_id": 65, "code": 83, "text": "🎵 Play BGM", "dialog": "select_sound_dialog", "tooltip": "Start background music."},
		{"button_id": 66, "code": 84, "text": "⏹️ Stop BGM", "dialog": "wait_dialog", "tooltip": "Fade out background music."},
		{"button_id": 67, "code": 85, "text": "💾 Save BGM", "dialog": "", "tooltip": "Remember currently playing BGM."},
		{"button_id": 68, "code": 86, "text": "▶️ Resume BGM", "dialog": "", "tooltip": "Restore remembered BGM."},
		{"button_id": 69, "code": 87, "text": "🌊 Play BGS", "dialog": "select_sound_dialog", "tooltip": "Play environmental ambient sound."},
		{"button_id": 70, "code": 88, "text": "🚫 Stop BGS", "dialog": "wait_dialog", "tooltip": "Stop background sound."},
		{"button_id": 71, "code": 89, "text": "📯 Play ME", "dialog": "select_sound_dialog", "tooltip": "Play short music stinger."},
		{"button_id": 72, "code": 90, "text": "🔊 Play SE", "dialog": "select_sound_dialog", "tooltip": "Play sound effect."},
		{"button_id": 73, "code": 91, "text": "🔇 Stop SE", "dialog": "", "tooltip": "Halt all active sound effects."},
		{"button_id": 74, "code": 92, "text": "📽️ Play Movie", "dialog": "select_video_scene_dialog", "tooltip": "Play pre-rendered video cutscene."},
		{"button_id": 75, "code": 93, "text": "⏹️ Stop Movie", "dialog": "wait_dialog", "tooltip": "Stop active video playback."},
		{"button_id": 86, "code": 110, "text": "🎵 Change Battle BGM", "dialog": "select_sound_dialog", "tooltip": "Change combat BGM track."},
		{"button_id": 87, "code": 111, "text": "🎶 Change Victory ME", "dialog": "select_sound_dialog", "tooltip": "Set victory fanfare."},
		{"button_id": 88, "code": 112, "text": "☠️ Change Defeat ME", "dialog": "select_sound_dialog", "tooltip": "Set defeat fanfare."},
		{"button_id": 110, "code": 121, "text": "🚗 Change Vehicle BGM", "dialog": "change_vehicle_sound_dialog", "tooltip": "Set vehicle ride music."}
	],
	"Scene Control & System": [
		{"button_id": 76, "code": 96, "text": "🛒 Open Shop", "dialog": "show_shop_dialog", "tooltip": "Launch merchant shopping interface."},
		{"button_id": 118, "code": 200, "text": "⚒️ Open Blacksmith Shop", "dialog": "", "tooltip": "Launch blacksmith crafting UI."},
		{"button_id": 119, "code": 201, "text": "🎖️ Class Upgrade Shop", "dialog": "show_shop_dialog", "tooltip": "Launch class advancement UI."},
		{"button_id": 77, "code": 98, "text": "✒️ Name Input Dialog", "dialog": "change_actor_name", "tooltip": "Open character rename keyboard screen."},
		{"button_id": 78, "code": 99, "text": "🏠 Open Menu Screen", "dialog": "", "tooltip": "Open pause / in-game menu."},
		{"button_id": 79, "code": 100, "text": "💾 Open Save Screen", "dialog": "", "tooltip": "Open save / load screen."},
		{"button_id": 80, "code": 101, "text": "☠️ Game Over", "dialog": "", "tooltip": "Trigger game over sequence."},
		{"button_id": 81, "code": 102, "text": "🚪 Return To Title Screen", "dialog": "", "tooltip": "Exit back to main game title."},
		{"button_id": 89, "code": 113, "text": "💾🚫 Change Save Access", "dialog": "enabled_disabled_dialog", "tooltip": "Allow or forbid saving in menu."},
		{"button_id": 90, "code": 114, "text": "📋🚫 Change Menu Access", "dialog": "enabled_disabled_dialog", "tooltip": "Allow or forbid opening pause menu."},
		{"button_id": 91, "code": 115, "text": "🎲 Change Encounter Rate", "dialog": "select_number_value_dialog", "tooltip": "Multiply random encounter frequency."},
		{"button_id": 92, "code": 116, "text": "👥♻️ Change Formation Access", "dialog": "enabled_disabled_dialog", "tooltip": "Allow or forbid changing party order."},
		{"button_id": 93, "code": 117, "text": "🐢⚡ Change Game Speed", "dialog": "select_number_value_dialog", "tooltip": "Game clock speed factor."},
		{"button_id": 94, "code": 118, "text": "👤🎭 Change Actor Scene", "dialog": "change_actor_or_vehicle_scene_dialog", "tooltip": "Swap actor sprite/scene."},
		{"button_id": 95, "code": 119, "text": "🚗 Change Vehicle Scene", "dialog": "change_actor_or_vehicle_scene_dialog", "tooltip": "Swap vehicle sprite/scene."},
		{"button_id": 112, "code": 120, "text": "🗣️ Change Language", "dialog": "change_language_dialog", "tooltip": "Switch active localization."},
		{"button_id": 122, "code": 210, "text": "💾 Toggle Auto-Save", "dialog": "enabled_disabled_dialog", "tooltip": "Enable or disable auto-saving."},
		{"button_id": 123, "code": 211, "text": "🧾🏆 Post-Battle Summary", "dialog": "enabled_disabled_dialog", "tooltip": "Show post-combat result screens."},
		{"button_id": 126, "code": 123, "text": "🎥 Manage Camera Targets", "dialog": "manage_camera_targets_dialog", "tooltip": "Add or remove camera targets."},
		{"button_id": 107, "code": 94, "text": "❌📅 Erase Event", "dialog": "", "tooltip": "Delete this event until map reload."}
	],
	"Battle": [
		{"button_id": 96, "code": 500, "text": "⚔️ Start Battle", "dialog": "start_battle_dialog", "tooltip": "Initiate combat with troop."},
		{"button_id": 105, "code": 505, "text": "🛑 Abort Battle", "dialog": "", "tooltip": "Interrupt active combat."}
	],
	"Advanced": [
		{"button_id": 106, "code": 5000, "text": "💻 Script", "dialog": "execute_script_command_dialog", "tooltip": "Run custom GDScript expression."}
	]
}

static var _code_to_info: Dictionary = {}
static var _button_to_info: Dictionary = {}

static func _ensure_cache() -> void:
	if not _code_to_info.is_empty():
		return
	for cat in ALL_CATEGORIES:
		for item in ALL_CATEGORIES[cat]:
			var info = item.duplicate()
			info["category"] = cat
			_code_to_info[info["code"]] = info
			_button_to_info[info["button_id"]] = info

static func get_info_for_code(code: int) -> Dictionary:
	_ensure_cache()
	if code in _code_to_info:
		return _code_to_info[code]
	return {
		"button_id": -1,
		"code": code,
		"text": "Command %d" % code,
		"category": "Advanced",
		"dialog": "",
		"tooltip": "Command Code %d" % code
	}

static func get_info_for_button(button_id: int) -> Dictionary:
	_ensure_cache()
	if button_id in _button_to_info:
		return _button_to_info[button_id]
	return {}

static func get_category_color(category_name: String) -> Color:
	return CATEGORY_COLORS.get(category_name, Color("#4a5568"))

static func is_branch_command(code: int) -> bool:
	return code in [4, 21, 24, 500]

static func is_sub_command(code: int) -> bool:
	return code in [3, 5, 6, 7, 11, 22, 23, 25, 26, 32, 35, 51, 58, 97, 501, 502, 503, 504]

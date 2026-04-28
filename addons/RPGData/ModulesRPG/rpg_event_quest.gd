@tool
class_name RPGEventPQuest
extends Resource


func get_class(): return "RPGEventPQuest"


## Unique identifier used for internal referencing and persistence.
@export var _uniq_id: int = -1 :
	get():
		if _uniq_id < 0: _uniq_id = RPGSYSTEM.generate_16_digit_id()
		return _uniq_id

## Real id in database for this quest (use _uniq_id)
@export var id: int = 1
## Override the name for this quest (Leave blank to use the default name).
@export var override_name: String = ""
## Override the description for this quest (Leave blank to use the default description).
@export var override_description: String = ""
## Event pages that need to be active in order to obtain or deliver
## this mission to this event
@export var required_pages: PackedInt32Array = []
## Level of relationship you must have with this NPC for
## this quest to be available (0 = no requirements).
@export var relationship_requeriment_level: int = 0
## Page that will be activated when talking to this event while having this quest active.
@export var start_page: RPGMapEventID = RPGMapEventID.new()
## Event and page required to complete this quest.
@export var target_page: RPGMapEventID = RPGMapEventID.new()
## Initial dialogue that this event will reproduce before giving
## this quest to the player.
@export var dialogue_on_start: String = ""
## Dialogue that this event will reproduce when delivering the completed quest
@export var dialogue_on_finish: String = ""
## Dialogue that this event will reproduce if this quest was given
## to the player and they failed to complete it.
@export var dialogue_on_failure: String = ""
## Start the specified event page if it exists and is set as the mission page when the mission begins.
@export var on_start_quest_page: int = -1
## Start the specified event page if it exists and is set as the mission page when the mission ends.
@export var on_finish_quest_page: int = -1
## Start the specified event page if it exists and is set as the mission page when the mission fails.
@export var on_failure_quest_page: int = -1

## Enables a custom time limit for this specific quest offering.
@export var use_custom_timer: bool = false

## Time limit in seconds to complete the quest (minimum 1.0).
## If the timer reaches 0, the quest automatically fails.
@export var custom_timer: float = 1.0

## Display a confirmation message to the player to accept this quest. If this option is disabled,
## after the start message, the quest will be given to the player automatically.
@export var use_confirm_message: bool = true
## Message displayed in the quest "accept" option
@export var confirm_ok_option: String = tr("Accept quest")
## Message displayed in the quest "cancel" option
@export var confirm_cancel_option: String = tr("Decline")

## Common Event ID triggered automatically when this quest is successfully completed (-1 to disable).
## This event fires universally regardless of whether the quest delivery was automatic or manual.
## WARNING: Do not include quest-altering commands within this Common Event to avoid conflicts with the Quest Manager.
@export var on_complete_common_event: int = -1

## Common Event ID triggered automatically when this quest is failed or canceled (-1 to disable).
## This event fires universally as soon as the quest enters a failed state.
## WARNING: Do not include quest-altering commands within this Common Event to avoid conflicts with the Quest Manager.
@export var on_fail_common_event: int = -1


func clone(value: bool = true) -> RPGEventPQuest:
	return duplicate(value)

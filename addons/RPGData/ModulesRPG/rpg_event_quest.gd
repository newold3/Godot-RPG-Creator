@tool
class_name RPGEventPQuest
extends Resource


func get_class(): return "RPGEventPQuest"


## Real id in database for this quest
@export var id: int = 1
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
## Overwrite the timer to complete this quest defined in the
## database with a specific timer.
@export var use_custom_timer: bool = false
## Time limit to complete the quest. A value of 0 means there is no time
## limit to complete the quest.
## This time is used to automatically finish the quest (terminating it as failed).
@export var custom_timer: float = 0.0
## Display a confirmation message to the player to accept this quest. If this option is disabled,
## after the start message, the quest will be given to the player automatically.
@export var use_confirm_message: bool = true
## Message displayed in the quest "accept" option
@export var confirm_ok_option: String = tr("Accept quest")
## Message displayed in the quest "cancel" option
@export var confirm_cancel_option: String = tr("Decline")


func clone(value: bool = true) -> RPGEventPQuest:
	return duplicate(value)

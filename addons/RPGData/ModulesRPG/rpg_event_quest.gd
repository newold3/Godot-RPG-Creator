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
## Initial dialogue that this event will reproduce before giving
## this quest to the player.
@export var dialogue_on_start: String = ""
## Dialogue that this event will reproduce if this mission has already
## been given to the player and is in progress.
@export var dialogue_in_progress: String = ""
## Dialogue that this event will reproduce when delivering the completed quest
@export var dialogue_on_finish: String = ""
## Dialogue that this event will reproduce if this quest was given
## to the player and they failed to complete it.
@export var dialogue_on_failure: String = ""
## Self switch that is activated when this quest is given to the player
## (this may activate other pages of the event if they have that switch
## as their start condition). You can choose not to activate any self switches.
@export var self_switch_enabled: int = -1
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

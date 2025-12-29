@tool
class_name RPGCommonEvent
extends Resource

## Handles reusable events that can be triggered in different game
## situations. Perfect for recurring actions.


## Returns the class name of the resource.
## @return String - The class name.
func get_class():
	return "RPGCommonEvent"

## Unique identifier for the common event.
@export var id: int = 0

## Name of the common event.
@export var name: String = ""

## Trigger for the common event.
@export var trigger: int = 0

## Switch ID for the common event.
@export var switch_id: int = 1

## List of event commands for the common event.
@export var list: Array[RPGEventCommand] = []

## Additional notes about this common event.
@export var notes: String = ""

## Initializes the common event.
func _init() -> void:
	if list.size() == 0:
		var command = RPGEventCommand.new()
		list.append(command)

## Clears all the properties of the common event.
func clear() -> void:
	name = ""
	trigger = 0
	switch_id = 1
	list.clear()
	var command = RPGEventCommand.new()
	list.append(command)

## Clones the common event and its properties.
## @param value bool - Whether to perform a deep clone.
## @return RPGCommonEvent - The cloned common event.
func clone(value: bool = true) -> RPGCommonEvent:
	var new_common_event = duplicate(value)

	for i in new_common_event.list.size():
		new_common_event.list[i] = new_common_event.list[i].clone(value)

	return new_common_event

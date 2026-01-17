@tool
class_name RPGCharacterCreationOptions
extends Resource

## Controls the entire character creation system: appearance, equipment
## and visual customization.


## Returns the class name of the resource.
## @return String - The class name.
func get_class():
	return "RPGCharacterCreationOptions"

## Folder path for character data.
@export var character_folder: String = "res://Scenes/NPCs/"

## Name of the character.
@export var name: String = ""

## Whether to create a sub-folder for the character.
@export var create_sub_folder: bool = true

## Whether to create the character.
@export var create_character: bool = true

## Whether to create an event character.
@export var create_event_character: bool = false

## Create a generic NPC (with only idle/walking animations). This generates a reduced LPC character that will have a single texture with idle and walking animations, with all parts merged. Ideal for creating generic characters that are lighter to load compared to a full LPC character.
@export var is_generic_lpc_event: bool = true

## Whether to create a face preview for the character.
@export var create_face_preview: bool = true

## Whether to create a character preview for the character.
@export var create_character_preview: bool = true

## Whether to create a battler preview for the character.
@export var create_battler_preview: bool = true

## Whether to always show the weapon.
@export var always_show_weapon: bool = false

## Whether the character is immutable.
@export var inmutable: bool = false

## Whether to create equipment parts for the character.
@export var create_equipment_parts: bool = false

## Folder path for equipment data.
@export var equipment_folder: String = "res://Data/Equipment/"

## Whether to create equipment set.
@export var create_equipment_set: bool = false

## Whether to create ingame custome.
@export var create_ingame_costume: bool = false

## Recording mode for the set[br]
## 0 = FULL_STRICT: Delete everything that is not included in the set (including weapons).[br]
## 1 = FULL_HYBRID: Delete all clothing that is not brought, but KEEP previous weapons.[br]
## 2 = PARTIAL: Solo sustituye lo que trae, mantiene todo lo demás (capa)
## 3 = INGAME CUSTOME: Solo sustituye lo que trae, mantiene todo lo demás (capa)
@export var set_mode: int = 0 

## Dictionary of parts to save.
@export var save_parts: Dictionary = {"mask": true, "hat": true, "glasses": true, "suit": true, "jacket": true, "shirt": true, "gloves": true, "belt": true, "pants": true, "shoes": true, "back": true, "mainhand": true, "offhand": true, "ammo": true}

## Whether to save all parts.
@export var all: bool = true

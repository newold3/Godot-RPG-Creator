@tool
class_name IngameCostume
extends RPGLPCCharacter

func get_class(): return "IngameCostume"


## Unique ID generated for this item
@export var uniq_id: int = -1
## Real database ID
@export var id: int = 0
## Number of items in possession of this type
@export var quantity: int = 0
## Indicates the type of equipment (0 = IngameCostume, 1 = IngameGearSet)
@export var type: int
## Flag indicating that the item has just been acquired
@export var newly_added: bool = false
## Date of most recent acquisition
@export var last_added_date: int = 0


func _init() -> void:
	uniq_id = RPGSYSTEM.generate_16_digit_id()


func get_real_data() -> RPGCostume:
	return RPGSYSTEM.get_data("costumes", id)


func _to_string() -> String:
	var parent_text = super()
	return "<IngameCostume %s>" % parent_text


## Creates a new IngameCostume instance based on an existing character.
## Uses reflection to automatically copy all storage properties.
static func create_from_character(source: RPGLPCCharacter) -> IngameCostume:
	var costume = IngameCostume.new()

	# Iterate over all properties of the source object
	for prop in source.get_property_list():
		if not (prop.usage & PROPERTY_USAGE_STORAGE):
			continue

		var name: String = prop.name
		
		# Skip internal Godot properties that we should not overwrite
		if name in ["script", "resource_path", "resource_local_to_scene", "resource_name"]:
			continue

		# Get the value from the source
		var value = source.get(name)

		# HANDLE DEEP COPIES
		# If it is a Resource (like EquipmentData) or a collection (Array/Dictionary),
		# we must duplicate it to avoid shared references.
		if value is Resource and value.has_method("duplicate"):
			costume.set(name, value.duplicate_deep(DEEP_DUPLICATE_ALL))
		elif value is Array or value is Dictionary:
			costume.set(name, value.duplicate_deep(DEEP_DUPLICATE_ALL))
		else:
			# For primitive types (String, int, bool), simple assignment is fine
			costume.set(name, value)

	return costume

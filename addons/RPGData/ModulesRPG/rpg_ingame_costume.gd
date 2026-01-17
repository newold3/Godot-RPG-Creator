@tool
class_name IngameCostume
extends Resource

func get_class(): return "IngameCostume"

@export var body_parts: RPGLPCBodyData = RPGLPCBodyData.new()
@export var equipment_parts: RPGLPCEquipmentData = RPGLPCEquipmentData.new()
@export var hidden_items: Array = []

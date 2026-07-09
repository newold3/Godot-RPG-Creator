@tool
class_name RPGLPCEquipmentData
extends  Resource


func get_class(): return "RPGLPCEquipmentData"

const SetMode = RPGEnums.SetMode


@export var mask: RPGLPCEquipmentPart = RPGLPCEquipmentPart.new()
@export var hat: RPGLPCEquipmentPart = RPGLPCEquipmentPart.new()
@export var glasses: RPGLPCEquipmentPart = RPGLPCEquipmentPart.new()
@export var suit: RPGLPCEquipmentPart = RPGLPCEquipmentPart.new()
@export var jacket: RPGLPCEquipmentPart = RPGLPCEquipmentPart.new()
@export var shirt: RPGLPCEquipmentPart = RPGLPCEquipmentPart.new()
@export var gloves: RPGLPCEquipmentPart = RPGLPCEquipmentPart.new()
@export var belt: RPGLPCEquipmentPart = RPGLPCEquipmentPart.new()
@export var pants: RPGLPCEquipmentPart = RPGLPCEquipmentPart.new()
@export var shoes: RPGLPCEquipmentPart = RPGLPCEquipmentPart.new()
@export var back: RPGLPCEquipmentPart = RPGLPCEquipmentPart.new()
@export var mainhand: RPGLPCEquipmentPart = RPGLPCEquipmentPart.new()
@export var offhand: RPGLPCEquipmentPart = RPGLPCEquipmentPart.new()
@export var ammo: RPGLPCEquipmentPart = RPGLPCEquipmentPart.new()
@export_enum("Full Strict (Replace All)", "Hybrid (Keep Weapons)", "Partial (Overlay)", "Custome") var application_mode: int = SetMode.FULL_STRICT


func clear() -> void:
	application_mode = SetMode.FULL_STRICT
	for key in ["mask", "hat", "glasses", "suit", "jacket", "shirt", "gloves", "belt", "pants", "shoes", "back", "mainhand", "offhand", "ammo"]:
		get(key).clear()

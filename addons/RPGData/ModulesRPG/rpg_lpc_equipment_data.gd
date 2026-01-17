@tool
class_name RPGLPCEquipmentData
extends  Resource


func get_class(): return "RPGLPCEquipmentData"

enum SetMode {
	FULL_STRICT = 0, # Delete everything that is not included in the set (including weapons).
	FULL_HYBRID = 1, # Delete all clothing that is not brought, but KEEP previous weapons.
	PARTIAL     = 2, # Just replace what it comes with, keep everything else (layer)
	CUSTOME     = 3  # Solo sustituye lo que trae, mantiene todo lo demás (capa)
}


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

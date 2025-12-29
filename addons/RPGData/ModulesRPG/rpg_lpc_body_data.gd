@tool
class_name RPGLPCBodyData
extends  Resource


func get_class(): return "RPGLPCBodyData"


@export var body: RPGLPCBodyPart = RPGLPCBodyPart.new()
@export var head: RPGLPCBodyPart = RPGLPCBodyPart.new()
@export var eyes: RPGLPCBodyPart = RPGLPCBodyPart.new()
@export var wings: RPGLPCBodyPart = RPGLPCBodyPart.new()
@export var tail: RPGLPCBodyPart = RPGLPCBodyPart.new()
@export var horns: RPGLPCBodyPart = RPGLPCBodyPart.new()
@export var hair: RPGLPCBodyPart = RPGLPCBodyPart.new()
@export var hairadd: RPGLPCBodyPart = RPGLPCBodyPart.new()
@export var ears: RPGLPCBodyPart = RPGLPCBodyPart.new()
@export var nose: RPGLPCBodyPart = RPGLPCBodyPart.new()
@export var facial: RPGLPCBodyPart = RPGLPCBodyPart.new()
@export var add1: RPGLPCBodyPart = RPGLPCBodyPart.new()
@export var add2: RPGLPCBodyPart = RPGLPCBodyPart.new()
@export var add3: RPGLPCBodyPart = RPGLPCBodyPart.new()


func _to_string() -> String:
	var ids = [body, head, eyes, wings, tail, horns, hair, hairadd, ears, nose, facial, add1, add2, add3]
	var s: String = "RPGLPCBodyData"
	for id in ids:
		s += "\n" + str(id)
	
	return s
	

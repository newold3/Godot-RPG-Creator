@tool
extends Label

var last_text: String
var internal_timer: float = 0.0


func _ready() -> void:
	if material:
		material = material.duplicate()
	item_rect_changed.connect(_update_material_shader)
	refresh()


func refresh() -> void:
	_update_material_shader()

func _process(delta: float) -> void:
	if last_text != text:
		last_text = text
		refresh()
		
	if Engine.is_editor_hint() and internal_timer > 0.0:
		internal_timer -= delta
		if internal_timer <= 0.0:
			internal_timer = 0.0
			notify_property_list_changed()


func _update_material_shader() -> void:
	var mat: ShaderMaterial = material
	if mat:
		mat.set_shader_parameter("size", size)
		internal_timer = 0.5

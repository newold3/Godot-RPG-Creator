@tool
extends BaseButton


@export var current_color: Color = Color.BLACK :
	set(color):
		current_color = color
		if is_inside_tree():
			set_color(current_color)


signal middle_clicked()


func _ready() -> void:
	RPGMapPlugin.reload_inputs_safely()
	#InputMap.load_from_project_settings()
	gui_input.connect(
		func(event: InputEvent):
			if event.is_action("MouseMidClick"):
				middle_clicked.emit()
	)


func set_color(color: Color) -> void:
	var style: StyleBoxFlat = get("theme_override_styles/normal")
	style.bg_color = color
	style = get("theme_override_styles/hover")
	style.bg_color = color
	style = get("theme_override_styles/pressed")
	style.bg_color = color


func get_color() -> Color:
	var style: StyleBoxFlat = get("theme_override_styles/normal")
	return style.bg_color

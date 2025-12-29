@tool
extends CheckBox

@export var hover_color: Color = Color.CORAL: set = set_hover_color
@export var selected_color: Color = Color.GREEN_YELLOW: set = set_selected_color
@export var rich_text: String : set = set_text


func _ready() -> void:
	toggled.connect(_on_toggled)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	set_hover_color(hover_color)
	set_selected_color(selected_color)
	toggled.emit(is_pressed())


func set_text(new_text: String) -> void:
	rich_text = new_text
	%MainLabel.text = rich_text


func _on_toggled(toggled_on: bool) -> void:
	%SelectedColor.visible = toggled_on


func _on_mouse_entered() -> void:
	%LabelHoverColor.set_visible(true)
	%SelectedColor.set_visible(false)


func _on_mouse_exited() -> void:
	%LabelHoverColor.set_visible(false)
	%SelectedColor.set_visible(is_pressed())


func set_hover_color(color: Color) -> void:
	hover_color = color
	if is_inside_tree():
		%LabelHoverColor.color = color


func set_selected_color(color: Color) -> void:
	selected_color = color
	if is_inside_tree():
		%SelectedColor.color = color

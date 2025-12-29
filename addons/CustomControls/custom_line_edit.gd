@tool
extends LineEdit


@export var disabled: bool = false : set = set_disabled


var select_all_delay: float = 0


func _ready() -> void:
	set_disabled(!is_editable())
	text_changed.connect(_on_text_changed)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)


func _process(delta: float) -> void:
	if select_all_delay > 0:
		select_all_delay -= delta
		if select_all_delay <= 0:
			if is_editable():
				_start_selection()


func _physics_process(delta: float) -> void:
	if not has_focus():
		if not get_selected_text().is_empty():
			deselect()


func set_disabled(value: bool) -> void:
	disabled = value
	
	if !value:
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_ALL
		if has_meta("original_text"):
			text = get_meta("original_text")
		set_editable(true)
		set_selecting_enabled(true)
		set_process(true)
		set_process_input(true)
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		set_process(false)
		set_process_input(false)
		set_editable(false)
		set_selecting_enabled(false)
		set_meta("original_text", text)
		text = ""


func _start_selection():
	set_caret_column(text.length())
	select_all()


func grab_focus() -> void:
	if not editable: return
	super()


func _on_focus_entered() -> void:
	select_all_delay = 0.08


func _on_focus_exited() -> void:
	call_deferred("deselect")


func _on_text_changed(_new_text: String) -> void:
	if select_all_delay > 0:
		select_all_delay = 0

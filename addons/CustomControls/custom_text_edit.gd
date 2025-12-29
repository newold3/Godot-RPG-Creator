@tool
extends TextEdit

@export var using_the_built_in_expanded_editor: bool = true
@export var show_expand_icon: bool = true :
	set(value):
		show_expand_icon = value
		queue_redraw()


var select_all_delay: float = 0
var back_normal_style

var is_focused: bool = false

const EXPAND_ICON = preload("res://addons/CustomControls/Images/expand_icon.png")

var expand_icon_rect: Rect2
var is_over_expand_icon: bool = false
var using_custom_tooltip: bool = false

const CUSTOM_TOOLTIP = preload("res://addons/CustomControls/custom_tooltip.tscn")

signal expand_requested(target: TextEdit)


func _ready() -> void:
	set_process(false)
	text_changed.connect(_on_text_changed)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	gui_input.connect(_on_gui_input)


func disabled_expand_icon() -> void:
	show_expand_icon = false
	set_process_input(false)
	queue_redraw()


func _process(delta: float) -> void:
	if select_all_delay > 0:
		select_all_delay -= delta
		if select_all_delay <= 0:
			if is_editable():
				select_all()
			set_process(false)


func set_disabled(value: bool) -> void:
	set_editable(!value)
	if !value:
		set_selecting_enabled(true)
		set_process_input(true)
		if has_meta("original_text"):
			text = get_meta("original_text")
		if back_normal_style:
			set("theme_override_styles/normal", back_normal_style)
	else:
		set_selecting_enabled(false)
		set_process_input(false)
		if text.length() > 0:
			set_meta("original_text", text)
		text = ""
		back_normal_style = get("theme_override_styles/normal")
		set("theme_override_styles/normal", StyleBoxEmpty.new())


func _on_focus_entered() -> void:
	if !is_focused:
		select_all_delay = 0.08
		set_process(true)
		is_focused = true


func _on_focus_exited() -> void:
	is_focused = false
	queue_redraw()
	deselect()


func _on_text_changed() -> void:
	if select_all_delay > 0:
		set_process(false)
		select_all_delay = 0


func _on_gui_input(event: InputEvent) -> void:
	if !show_expand_icon: return
	
	if event is InputEventMouseMotion:
		if expand_icon_rect and expand_icon_rect.has_point(event.position):
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			if !is_over_expand_icon:
				is_over_expand_icon = true
				using_custom_tooltip = true
				CustomTooltipManager.busy = true
				CustomTooltipManager.destroy_all_tooltips.emit()
				queue_redraw()
				call_deferred("_show_custom_tooltip_text_for_node")
		else:
			mouse_default_cursor_shape = Control.CURSOR_IBEAM
			if is_over_expand_icon:
				is_over_expand_icon = false
				queue_redraw()
				call_deferred("_show_normal_tooltip_text_for_node")
	
	if is_over_expand_icon:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.is_pressed():
					if using_the_built_in_expanded_editor:
						open_expanded_editor()
					else:
						expand_requested.emit(self)


func open_expanded_editor() -> void:
	var path = "res://addons/CustomControls/Dialogs/default_expanded_text_editor_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.set_target(self)


func _show_custom_tooltip_text_for_node() -> void:
	CustomTooltipManager.destroy_all_tooltips.emit()
	var title = TranslationManager.tr("ExpandTextEditor")
	var contents = TranslationManager.tr("Opens a dialog to edit\nthe text of this control")
	CustomTooltipManager.show_tooltip(title, contents, self)
	CustomTooltipManager.set_deferred("busy", false)


func _show_normal_tooltip_text_for_node() -> void:
	CustomTooltipManager.show_tooltip_from_node(self)


func _draw() -> void:
	if !show_expand_icon: return
	
	var w = EXPAND_ICON.get_width()
	var h = EXPAND_ICON.get_height()
	expand_icon_rect = Rect2(size.x - w - 10, size.y - h - 10, w, h)
	var color = Color.WHITE if !is_over_expand_icon else Color.ORANGE
	draw_texture_rect(EXPAND_ICON, expand_icon_rect, false, color)

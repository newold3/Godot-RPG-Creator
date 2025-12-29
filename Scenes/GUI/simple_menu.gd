@tool
extends Control


@export_enum("DRAW_LEVEL_AND_QUANTITY", "DRAW_LEVEL_ONLY", "DRAW_QUANTITY_ONLY") var display_mode: int = 0 : set = _set_display_mode

var is_enabled: bool = false
var last_item_hovered: int = -1

@onready var smooth_scroll_container: SmoothScrollContainer = %SmoothScrollContainer


signal cancel()
signal item_hovered(index: int, item: Dictionary)
signal item_selected(index: int, item: Dictionary)
signal item_clicked(index: int, item: Dictionary)


func _ready() -> void:
	if Engine.is_editor_hint():
		resized.connect(
			func():
				%Main.custom_minimum_size = Vector2.ZERO
				await get_tree().process_frame
				if is_inside_tree():
					%Main._update_layout()
		)
	else:
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		%Main.cancel.connect(func(): cancel.emit())
		%Main.item_hovered.connect(_on_main_item_hovered)
		%Main.item_clicked.connect(_on_main_item_clicked)
		%Main.item_selected.connect(_on_main_item_selected)
		%Main._update_layout()


func _on_main_item_hovered(index: int, item: Dictionary) -> void:
	if last_item_hovered != index:
		item_hovered.emit(index, item)
		last_item_hovered = index


func _on_main_item_clicked(index: int, item: Dictionary) -> void:
	item_hovered.emit(index, item)
	item_clicked.emit(index, item)


func _on_main_item_selected(index: int, item: Dictionary) -> void:
	item_selected.emit(index, item)
	await get_tree().process_frame
	if is_inside_tree():
		await get_tree().process_frame
		smooth_scroll_container.call_deferred("bring_focus_target_into_view", 0.5)


func _set_display_mode(value: int) -> void:
	display_mode = value
	%Main.display_mode = value


func get_gears() -> Array:
	return [%GearTop, %GearBottom]


func set_items(new_items: Array[Dictionary]) -> void:
	%Main.set_items(new_items)


func enabled() -> void:
	is_enabled = true
	%Main.enabled()


func disabled() -> void:
	is_enabled = false
	%Main.disabled()

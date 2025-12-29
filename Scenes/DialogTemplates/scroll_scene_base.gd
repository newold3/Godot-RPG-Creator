@tool
class_name ScrollText
extends NinePatchRect


var config: Dictionary # {scroll_speed, scroll_direction, scroll_scene, enable_fast_forward}
var speed: int = 100
var direction: int
var can_skip: bool = false
var enabled: bool = false

@onready var message: RichTextLabel = %Message
@onready var message_container: VBoxContainer = %MessageContainer


signal scroll_finished()


func _ready() -> void:
	setup_effects()
	set_process(false)
	scroll_finished.connect(end)


func setup_effects():
	var paths = [
		"res://addons/CustomControls/Resources/RichTextEffects/ColorMod.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/Cuss.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/ghost.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/Heart.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/Jump.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/L33T.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/Nervous.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/Number.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/Rain.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/Sparkle.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/UwU.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/Woo.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/lenguage_learning.gd"
	]
	for path in paths:
		var effect = load(path).new()
		message.install_effect(effect)


func _process(delta: float) -> void:
	var current_speed: float = speed
	if config.get("enable_fast_forward", true):
		if Input.is_action_pressed("ui_select"):
			current_speed = speed * config.get("multiply_value", 2.5)
	message_container.position.y += current_speed * delta
	if (
		(direction == 0 and message_container.position.y <= -message.get_content_height()) or
		(direction == 1 and message_container.position.y >= %MessageParent.size.y)
	):
		scroll_finished.emit()
		set_process(false)


func set_config(_config: Dictionary) -> void:
	config = _config


func reset() -> void:
	set_process(false)
	var node = message
	var h = node.get_content_height()
	node = message_container
	node.visible = false
	direction = config.get("scroll_direction", 0)
	node.position.x = 0
	%MainMarginContainer.size = %MainPanelContainer.size
	var ml = %MainMarginContainer.get("patch_margin_left")
	var mr = %MainMarginContainer.get("patch_margin_right")
	var mt = %MainMarginContainer.get("patch_margin_top")
	var mb = %MainMarginContainer.get("patch_margin_bottom")
	%MessageParent.size = %MainMarginContainer.size - Vector2(
		0 if not ml else ml + 0 if not mr else mr,
		0 if not mt else mt + 0 if not mb else mb
	)
	%MainMarginContainer.queue_sort()
	%MainPanelContainer.queue_sort()
	%MessageParent.queue_redraw()
	
	if direction == 0:
		node.position.y = %MessageParent.size.y
	else:
		node.position.y = -h

	speed = config.get("scroll_speed", 100)
	speed = -speed if direction == 0 else speed
	can_skip = config.get("enable_fast_forward", false)
	
	await get_tree().process_frame
	
	node.visible = true
	set_process(true)


func set_text(text: String) -> void:
	var node = message
	node.text = text
	
	reset()


func start() -> void:
	pass


func end() -> void:
	queue_free()

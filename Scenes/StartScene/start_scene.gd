extends Control

@export var title: String
@export var sub_title: String

var show_logo: bool = true # fast debug game. Set in release

var title_labels = []
var tween

@onready var background: ColorRect = %Background
@onready var label_template: Label = %Label1
@onready var subtitle_label: Label = %Label2


func _ready() -> void:
	get_viewport().transparent_bg = false
	load_options()
	
	if show_logo:
		setup_logo()
	else:
		call_deferred("create_main_scene")


func load_options() -> void:
	var path = "user://game_options.res"
	var current_options: RPGGameOptions
	if ResourceLoader.exists(path):
		current_options = load(path)
	else:
		current_options = RPGGameOptions.new()
	
	GameManager.set_options(current_options)


func create_main_scene() -> void:
	var node = preload("res://Scenes/main_scene.tscn")
	var ins = node.instantiate()
	ins.initialize_title_scene = true
	get_parent().add_child(ins)
	
	await get_tree().process_frame
	queue_free()


func setup_logo() -> void:
	GameManager.set_text_config(self)
	
	var viewport_size = get_viewport_rect().size
	label_template.visible = false
	label_template.text = title
	
	var test_size = get_title_font_size(viewport_size.x * 0.45, 1, 500)
	var title_font_size = test_size
	var subtitle_font_size = title_font_size / 2.0
	
	# Create labels for each letter of the title
	var center_x = viewport_size.x / 2
	var center_y = viewport_size.y / 2
	
	for i in range(title.length()):
		var new_label
		if i == 0:
			new_label = label_template
		else:
			new_label = label_template.duplicate()
			add_child(new_label)
			
		new_label.text = title[i]
		new_label.set("theme_override_font_sizes/font_size", title_font_size)
		new_label.visible = false
		new_label.position = Vector2(center_x - new_label.size.x / 2, center_y - new_label.size.y / 2)
		new_label.pivot_offset = Vector2(new_label.size.x / 2, new_label.size.y / 2) # Important for zoom
		title_labels.append(new_label)
	
	# Configure subtitle
	subtitle_label.text = sub_title
	subtitle_label.set("theme_override_font_sizes/font_size", subtitle_font_size)
	subtitle_label.visible = false
	var font = label_template.get("theme_override_fonts/font")
	var posy = font.get_string_size(" ", HORIZONTAL_ALIGNMENT_CENTER, -1, title_font_size).y
	subtitle_label.position = Vector2(
		center_x - subtitle_label.size.x / 2,
		center_y - subtitle_label.size.y / 2 - posy
	)
	
	start_animation()


func get_title_font_size(target_width: float, min_size: int, max_size: int) -> int:
	var current_size
	var best_size = min_size
	
	var font = label_template.get("theme_override_fonts/font")
	
	while min_size <= max_size:
		current_size = (min_size + max_size) / 2.0
		label_template.set("theme_override_font_sizes/font_size", current_size)
		var current_width = font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, current_size).x
		
		if abs(current_width - target_width) < 1:
			return current_size
		
		if current_width < target_width:
			min_size = current_size + 1
			best_size = current_size
		else:
			max_size = current_size - 1
			
	return best_size


func _animate_ripple(value: float) -> void:
	var node = %RippleEffect
	node.scale = Vector2(value, clamp(value, 0.1, 1))
	node.modulate.a -= value * get_process_delta_time()


func start_animation():
	tween = create_tween()
	
	tween.tween_interval(0.15)
	tween.tween_callback(%AudioStreamPlayer.play)
	
	# Configure first letter
	title_labels[0].visible = true
	title_labels[0].modulate.a = 0
	title_labels[0].scale = Vector2(0, 0) # Starts 10 times larger
	
	tween.set_parallel(true)
	
	var node = %RippleEffect
	node.modulate = Color.WHITE
	node.scale = Vector2(0.1, 0.1)
	
	tween.tween_property(title_labels[0], "modulate:a", 1.0, 0.25)
	tween.set_parallel(false)
	tween.tween_interval(0.01)
	tween.set_parallel(true)
	

	tween.tween_method(
		_animate_ripple,
		0.1,
		5.5,
		2.6
	).set_delay(0.1)
	
	# Animate first letter with fade in and zoom out
	tween.tween_property(title_labels[0], "scale", Vector2(2.5, 2.5), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(title_labels[0], "scale", Vector2(1, 1), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).set_delay(0.2)
	
	# Fade in subtitle
	subtitle_label.visible = true
	subtitle_label.modulate.a = 0
	tween.tween_property(subtitle_label, "modulate:a", 1.0, 0.8).set_delay(0.3)
	
	# Calculate final position of letters
	var total_width = 0
	for label in title_labels:
		total_width += label.size.x
	
	var start_x = (get_viewport_rect().size.x - total_width) / 2
	var current_x = start_x
	
	# Animate rest of letters
	for i in range(title_labels.size()):
		var label = title_labels[i]
		label.visible = true
		label.modulate.a = 0
		
		tween.tween_property(label, "modulate:a", 1.0, 0.3).set_delay(0.5)
		tween.tween_property(label, "position:x", current_x, 0.3).set_delay(0.5)
		current_x += label.size.x
	
	# Fade out everything
	for label in title_labels:
		tween.tween_property(label, "modulate:a", 0.0, 1.1).set_delay(2.5)
	tween.tween_property(subtitle_label, "modulate:a", 0.0, 1.1).set_delay(2.5)
	
	tween.set_parallel(false)
	
	tween.tween_callback(create_main_scene)

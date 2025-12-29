class_name GameImage
extends Sprite2D

var id: int
var image_path: String
var is_active: bool = false
var start_animation: int = 0 # instant, fade-in, scale-up, pop-in
var start_duration: float = 0.25
var end_animation: int = 0 # instant, fade-out, scale-down, pop-down
var end_duration: float = 0.25


func _init(p_id: int, p_image_path: String) -> void:
	visible = false
	material = CanvasItemMaterial.new()
	id = p_id
	image_path = p_image_path
	if ResourceLoader.exists(image_path):
		texture = load(image_path)


func start(p_start_animation: int, p_start_duration: float, p_end_animation: int, p_end_duration: float) -> void:
	start_animation = p_start_animation
	start_duration = p_start_duration
	end_animation = p_end_animation
	end_duration = p_end_duration
	visible = true
	
	is_active = true
	
	if not GameManager.loading_game:
		var t = create_tween()
		t.tween_callback(set.bind("visible", true))
		
		match start_animation:
			1: # Fade-in:
				var current_modulate = modulate
				modulate = Color.TRANSPARENT
				t.tween_property(self, "modulate", current_modulate, start_duration)
			2: # Scale-up:
				var current_scale = scale
				scale = Vector2.ZERO
				t.tween_property(self, "scale", current_scale, start_duration)
			3: # Pop-down:
				t.set_parallel(true)
				var current_scale = scale
				var current_modulate = modulate
				scale = Vector2.ZERO
				modulate = Color.TRANSPARENT
				t.tween_property(self, "modulate", current_modulate, start_duration)
				t.tween_property(self, "scale", current_scale, start_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		visible = true


func end() -> void:
	is_active = false
	var t = create_tween()
	
	match end_animation:
		1: # Fade-out:
			t.tween_property(self, "modulate", Color.TRANSPARENT, end_duration)
		2: # Scale-down:
			t.tween_property(self, "scale", Vector2.ZERO, end_duration)
		3: # Pop-out:
			t.set_parallel(true)
			t.tween_property(self, "modulate", Color.TRANSPARENT, end_duration).set_delay(0.05)
			t.tween_property(self, "scale", Vector2.ZERO, end_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	t.set_parallel(false)
	t.tween_callback(queue_free)

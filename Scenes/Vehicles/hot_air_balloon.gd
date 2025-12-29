@tool
extends RPGVehicle


var old_zoom: Vector2
var current_scale: Vector2 = Vector2.ONE
var is_flying: bool = false


func _ready() -> void:
	super()
	starting.connect(_on_board)
	ending.connect(_on_disembark)
	
	%FinalBalloon.texture = %Ballon.get_texture()
	%FinalShadow.texture = %Ballon.get_texture()
	%Vehicle.texture = %Ballon.get_texture()
	%VehicleTop.texture = %Ballon.get_texture()


func launch() -> void:
	var camera = get_viewport().get_camera_2d()
	if camera:
		old_zoom = camera.zoom
		camera.target_zoom = camera.zoom * 0.8
	%AnimationPlayer.play("Launch")


func exit() -> void:
	var t = create_tween()
	t.tween_callback(set.bind("is_flying", false)).set_delay(0.7)
	is_enabled = false
	%AnimationPlayer.play("land")
	var camera = get_viewport().get_camera_2d()
	if camera:
		camera.target_zoom = old_zoom
	await %AnimationPlayer.animation_finished


func start_flying_animation() -> void:
	%AnimationPlayer.play("Flying")
	is_enabled = true
	is_passable = true


func end_flying_animation() -> void:
	is_passable = false


func start(passenger: LPCCharacter) -> void:
	super(passenger)
	var camera = get_viewport().get_camera_2d()
	if camera:
		camera.target = %VehicleContainer


func end() -> void:
	await exit()
	super()


func _on_board() -> void:
	is_flying = true
	is_enabled = false
	%Vehicle.z_index = 60
	%VehicleTop.z_index = 60
	launch()


func _on_disembark() -> void:
	is_enabled = false
	%Vehicle.z_index = 1
	%VehicleTop.z_index = 60


func get_shadow_data() -> Dictionary:
	var tex = $Ballon.get_texture()
	
	var shadow = {
		"texture": tex,
		"position": global_position - tex.get_size() * 0.5 + %VehicleContainer.position,
		"is_shadow_viewport": true,
		"texture_viewport": %Shadow.get_texture(),
		"sprite_shadow": %FinalShadow,
		"shadow_position": global_position - %Shadow.get_texture().get_size() * 0.5,
		"scale": current_scale,
		"node": self
	}
	
	if GameManager.current_map:
		shadow.cell = Vector2i(global_position / Vector2(GameManager.current_map.tile_size))
	
	return shadow

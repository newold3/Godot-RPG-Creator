extends VBoxContainer

@onready var actor_name: Label = $ActorName
@onready var actor_image: TextureRect = %ActorImage


func set_actor(actor: GameActor) -> void:
	if not actor: return
	
	var data = RPGSYSTEM.database.actors
	if actor.id > 0 and data.size() > actor.id:
		var real_actor: RPGActor = data[actor.id]
		var img = real_actor.character_preview
		if ResourceLoader.exists(img):
			actor_image.texture = ResourceLoader.load(img)
		else:
			actor_image.texture = null
		actor_image.position.y = real_actor.pose_vertical_offset
			
	actor_name.text = actor.current_name

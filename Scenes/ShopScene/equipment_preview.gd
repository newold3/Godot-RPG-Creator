extends PanelContainer


const ACTOR_PREVIEW_PANEL = preload("res://Scenes/ShopScene/actor_preview_panel.tscn")

@onready var actors_container: VBoxContainer = %ActorsContainer
@onready var item_icon: TextureRect = %ItemIcon
@onready var item_name: Label = %ItemName


func _ready() -> void:
	_create_hero_panels()


func _create_hero_panels() -> void:
	var container = actors_container
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	
	if GameManager.game_state:
		for member_id: int in GameManager.game_state.current_party:
			var actor: GameActor = GameManager.get_actor(member_id)
			if actor:
				var panel = ACTOR_PREVIEW_PANEL.instantiate()
				container.add_child(panel)
				panel.set_actor(actor)


func set_item_to_compare(item_type: int, item_id: int, item_level: int) -> void:
	for child in actors_container.get_children():
		child.set_item_to_compare(item_type, item_id, item_level)
	
	if item_id > 0:
		var real_item: Variant
		match item_type:
			1: if RPGSYSTEM.database.weapons.size() > item_id: real_item = RPGSYSTEM.database.weapons[item_id]
			2: if RPGSYSTEM.database.armors.size() > item_id: real_item = RPGSYSTEM.database.armors[item_id]
		if real_item:
			item_name.text = real_item.name + ("" if item_level <= 1 else " +%s" % int(item_level))
			var icon: RPGIcon = real_item.icon
			if ResourceLoader.exists(icon.path):
				item_icon.texture.atlas = load(icon.path)
				item_icon.texture.region = icon.region
			else:
				item_icon.texture.atlas = null


func animate_modulation_alpha(alpha: float) -> void:
	modulate.a = alpha
	for child in actors_container.get_children():
		child.animate_modulation_alpha(alpha)

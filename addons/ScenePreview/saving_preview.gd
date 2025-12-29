@tool
extends Node2D

func save_texture(scene_path: String, tex: ImageTexture) -> void:
	%MainViewport.size = tex.get_size()
	%MainSprite.get_material().set_shader_parameter("mask_color", ProjectSettings.get("rendering/environment/defaults/default_clear_color"))
	%MainSprite.texture = tex
	
	await RenderingServer.frame_post_draw
	
	var img = %FinalSprite.texture.get_image()
	var image_path = scene_path.get_basename() + "_preview.png"
	img.save_png(image_path)
	var editor_fs = EditorInterface.get_resource_filesystem()
	editor_fs.scan()
	editor_fs.scan_sources()
	%MainSprite.texture = null
	print(tr("Preview image created in") + " \"%s\"" % image_path)

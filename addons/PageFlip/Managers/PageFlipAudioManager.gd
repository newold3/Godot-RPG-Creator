class_name PageFlipAudioManager extends RefCounted

## Reference to the main book node.
var book: Node2D


## Initializes the audio manager.
func _init(book_node: Node2D) -> void:
	book = book_node


## Plays a specific audio stream using the book's audio player.
func play_sound(stream: AudioStream) -> void:
	if not book.audio_player or not stream:
		return
		
	book.audio_player.stream = stream
	book.audio_player.pitch_scale = randf_range(
		book.min_fpage_flip_fx_pitch,
		book.max_fpage_flip_fx_pitch
	)
	book.audio_player.play()

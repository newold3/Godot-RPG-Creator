class_name SystemAudioManager
extends Node


var fx_busy: bool = false
var last_fx_ids: Dictionary = {}
var audio_players: Dictionary = {}


func _ready() -> void:
	_initialize_audio_players()


func _process(delta: float) -> void:
	if not last_fx_ids.is_empty():
		for key in last_fx_ids.keys():
			last_fx_ids[key] -= delta
			if last_fx_ids[key] <= 0:
				last_fx_ids.erase(key)


func _initialize_audio_players() -> void:
	audio_players = {
		"se": {
			"players": [%SEPlayer1, %SEPlayer2, %SEPlayer3, %SEPlayer4, %SEPlayer5],
			"current_index": 0
		},
		"bgm": {
			"players": [%BGMPlayer1, %BGMPlayer2],
			"current_index": 0,
			"current_player": null
		},
		"bgs": {
			"players": [%BGSPlayer1, %BGSPlayer2],
			"current_index": 0,
			"current_player": null
		},
		"me": {
			"players": [%MEPlayer]
		}
	}
	audio_players.bgm.current_player = audio_players.bgm.players[0]


func _load_audio_stream(audio: Variant) -> AudioStream:
	if audio is AudioStream:
		return audio
	elif audio is String and AssetManager.exists(audio):
		return load(audio)
	return null


func _play_audio_on_player(player: AudioStreamPlayer, audio_stream: AudioStream, volume: float = 0.0, pitch: float = 1.0) -> void:
	player.stop()
	player.stream = audio_stream
	player.volume_db = volume
	player.pitch_scale = pitch
	player.play()


func _stop_audio_players_with_fade(players: Array, fade_duration: float = 0.0) -> void:
	if fade_duration == 0:
		for player in players:
			player.stop()
	else:
		var any_playing = false
		for player in players:
			if player.is_playing():
				any_playing = true
				break
		
		if any_playing:
			var tween = create_tween()
			tween.set_parallel(true)
			for player in players:
				tween.tween_property(player, "volume_db", -80, fade_duration)
			tween.set_parallel(false)
			for player in players:
				tween.tween_callback(player.stop)


func _play_audio_with_crossfade(audio_type: String, audio: Variant, volume: float = 0.0, pitch: float = 1.0, fade_duration: float = 0.0) -> void:
	var audio_stream = _load_audio_stream(audio)
	if not audio_stream:
		return
	
	var audio_data = audio_players[audio_type]
	var old_player = audio_data.players[audio_data.current_index]
	
	audio_data.current_index = (audio_data.current_index + 1) % audio_data.players.size()
	var new_player = audio_data.players[audio_data.current_index]
	
	if audio_type == "bgm" or audio_type == "bgs":
		audio_data.current_player = new_player
	
	if old_player.is_playing() and old_player.stream and old_player.stream.resource_path == audio_stream.resource_path:
		return
	
	new_player.stream = audio_stream
	new_player.pitch_scale = pitch
	new_player.play()
	
	if fade_duration > 0:
		new_player.volume_db = -80
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(old_player, "volume_db", -80, fade_duration)
		tween.tween_property(new_player, "volume_db", volume, fade_duration)
		tween.set_parallel(false)
		tween.tween_callback(old_player.stop)
	else:
		new_player.volume_db = volume
		old_player.stop()


func play_bgm(bgm: Variant, volume: float = 0.0, pitch: float = 1.0, fade_duration: float = 0.0) -> void:
	_play_audio_with_crossfade("bgm", bgm, volume, pitch, fade_duration)


func play_bgs(bgs: Variant, volume: float = 0.0, pitch: float = 1.0, fade_duration: float = 0.0) -> void:
	_play_audio_with_crossfade("bgs", bgs, volume, pitch, fade_duration)


func play_se(fx: Variant, volume: float = 0.0, pitch: float = 1.0) -> void:
	var audio_stream = _load_audio_stream(fx)
	if not audio_stream:
		return
	
	var se_data = audio_players.se
	se_data.current_index = (se_data.current_index + 1) % se_data.players.size()
	var player = se_data.players[se_data.current_index]
	
	_play_audio_on_player(player, audio_stream, volume, pitch)


func play_me(me: Variant, volume: float = 0.0, pitch: float = 1.0) -> void:
	var audio_stream = _load_audio_stream(me)
	if not audio_stream:
		return
	
	stop_bgm()
	_play_audio_on_player(audio_players.me.players[0], audio_stream, volume, pitch)


func stop_bgm(fade_duration: float = 0) -> void:
	_stop_audio_players_with_fade(audio_players.bgm.players, fade_duration)


func stop_bgs(fade_duration: float = 0) -> void:
	_stop_audio_players_with_fade(audio_players.bgs.players, fade_duration)


func stop_se() -> void:
	_stop_audio_players_with_fade(audio_players.se.players)


func save_bgm() -> void:
	var current_bgm_player = audio_players.bgm.current_player
	if current_bgm_player and current_bgm_player.is_playing() and current_bgm_player.stream and GameManager.game_state:
		GameManager.game_state.bgm_saved = {
			"volume": current_bgm_player.volume_db,
			"pitch": current_bgm_player.pitch_scale,
			"path": current_bgm_player.stream.get_path(),
			"playback_position": current_bgm_player.get_playback_position()
		}


func restore_bgm() -> void:
	if not GameManager.game_state or not GameManager.game_state.bgm_saved:
		return
	
	stop_bgm()
	var saved_data = GameManager.game_state.bgm_saved
	var volume = saved_data.get("volume", 0.0)
	var pitch = saved_data.get("pitch", 1.0)
	var path = saved_data.get("path", "")
	var playback_position = saved_data.get("playback_position", 0.0)
	
	if AssetManager.exists(path):
		var player = audio_players.bgm.players[0]
		player.stream = load(path)
		player.volume_db = volume
		player.pitch_scale = pitch
		player.play()
		player.seek(playback_position)


func play_fx(id: Variant) -> void:
	if fx_busy or id in last_fx_ids: return 
	last_fx_ids[id] = 0.05
	var sound_data = _get_system_sound_data("game_fxs", id, _get_fx_sound_id(id))
	if sound_data:
		var pitch = _calculate_pitch(sound_data)
		play_se(sound_data.get("path", ""), sound_data.get("volume", 0.0), pitch)


func play_music(id: Variant) -> void:
	var sound_data = _get_system_sound_data("game_musics", id, _get_music_sound_id(id))
	if sound_data:
		var pitch = _calculate_pitch(sound_data)
		play_bgm(sound_data.get("path", ""), sound_data.get("volume", 0.0), pitch, 1.5)


func get_fx_path(id: Variant) -> String:
	var fxs = RPGSYSTEM.database.system.game_fxs
	var fx_id = _get_fx_sound_id(id)
	
	if fx_id > -1 and fxs.size() > fx_id:
		return RPGSYSTEM.database.system.game_fxs[fx_id].path
	
	return ""


func _get_fx_sound_id(id: Variant) -> int:
	var sound_list = [
		["cursor", "hover"],
		["select", "accept", "ok"],
		["cancel", "back"],
		["error"],
		["equip"],
		["save"],
		["load"],
		["erase_save"],
		["battle_start"],
		["battle_end"],
		["escape"],
		["lost_battle", "lost"],
		["win_battle", "win"],
		["failure"],
		["evasion"],
		["reflex", "magic_reflex"],
		["buy", "buy_item"],
		["sell", "sell_item"],
		["transaction", "complete_transaction"],
		["no_money_error"],
		["restock"],
		["use_item"],
		["use_skill"],
		["start_extraction"],
		["extraction_success"],
		["extraction_cancel"],
		["extraction_critical"],
		["switch_hero_panels"]
	]
	
	if typeof(id) == TYPE_INT:
		if id < 0 or id >= sound_list.size():
			return -1
		else:
			return id
	
	id = str(id).to_lower().replace(" ", "_")
	for i in sound_list.size():
		if id in sound_list[i]:
			return i
	
	return -1


func _get_music_sound_id(id: Variant) -> int:
	match id:
		"title", 0: return 0
		"battle", 1: return 1
		"victory", 2: return 2
		"defeat", 3: return 3
		"game_end", 4: return 4
		"land_transport", 5: return 5
		"sea_transport", 6: return 6
		"air_transport", 7: return 7
	return -1


func _get_system_sound_data(array_name: String, _id: Variant, sound_id: int) -> Dictionary:
	if sound_id > -1 and RPGSYSTEM.database.system.get(array_name).size() > sound_id:
		return RPGSYSTEM.database.system.get(array_name)[sound_id]
	return {}


func _calculate_pitch(sound_data: Dictionary) -> float:
	var pitch1 = sound_data.get("pitch", 1.0)
	var pitch2 = sound_data.get("pitch2", -1)
	return pitch1 if pitch2 == -1 else randf_range(pitch1, pitch2)

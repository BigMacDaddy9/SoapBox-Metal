extends Node

# =========================================================
# MENU MUSIC
# =========================================================
# Persistent music controller used for:
# - menu music playback
# - gameplay track playback
# - fade transitions between scenes
# - loading screen display during transitions
# - now playing popup text
#
# This script survives scene changes and keeps audio flowing
# without restarting every time the player moves between menus.
# =========================================================

# =========================================================
# AUDIO PLAYER REFERENCES
# =========================================================
# Two players are used so tracks can crossfade cleanly.
# =========================================================
var _player_a: AudioStreamPlayer
var _player_b: AudioStreamPlayer
var _active_player: AudioStreamPlayer
var _inactive_player: AudioStreamPlayer

# =========================================================
# MUSIC LIBRARIES
# =========================================================
# Menu tracks are used in front-end scenes.
# Gameplay tracks are used in races and other active gameplay scenes.
# =========================================================
var _menu_tracks: Array[AudioStream] = []
var _menu_track_names: Array[String] = []

var _gameplay_tracks: Array[AudioStream] = []
var _gameplay_track_names: Array[String] = []

# =========================================================
# PLAYBACK STATE
# =========================================================
var _current_track_name: String = ""
var _current_mode: String = "menu"
var _is_transitioning: bool = false

# =========================================================
# NOW PLAYING UI
# =========================================================
# Bottom-left popup used to show the current track name.
# =========================================================
var _ui_layer: CanvasLayer
var _popup_panel: PanelContainer
var _now_playing_label: Label
var _now_playing_timer: SceneTreeTimer = null

# =========================================================
# LOADING SCREEN UI
# =========================================================
# Transition overlay used when changing scenes so the music can
# fade cleanly without hard cuts.
# =========================================================
var loading_layer: CanvasLayer
var loading_rect: ColorRect
var loading_label: Label

# =========================================================
# READY
# =========================================================
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_create_players()
	_load_music()
	_create_now_playing_ui()
	_build_loading_ui()

	if not _menu_tracks.is_empty():
		play_random_menu_track()

# =========================================================
# PLAYER SETUP
# =========================================================
# Create two music players so we can crossfade between tracks.
# =========================================================
func _create_players() -> void:
	_player_a = AudioStreamPlayer.new()
	_player_a.name = "MusicPlayerA"
	_player_a.bus = "Master"
	add_child(_player_a)

	_player_b = AudioStreamPlayer.new()
	_player_b.name = "MusicPlayerB"
	_player_b.bus = "Master"
	add_child(_player_b)

	_active_player = _player_a
	_inactive_player = _player_b

	_active_player.volume_db = 0.0
	_inactive_player.volume_db = -80.0

# =========================================================
# MUSIC LOADING
# =========================================================
# Loads the configured menu and gameplay song lists.
# Missing files are skipped safely.
# =========================================================
func _load_music() -> void:
	_menu_tracks.clear()
	_menu_track_names.clear()
	_gameplay_tracks.clear()
	_gameplay_track_names.clear()

	var menu_songs := [
		{"path": "res://audio/Demolition_Derby.mp3", "name": "Demolition Derby"},
		{"path": "res://audio/Grind_The_Asphalt.mp3", "name": "Grind The Asphalt"},
		{"path": "res://audio/Downhill_Overdrive.mp3", "name": "Downhill Overdrive"},
		{"path": "res://audio/Ramp_Grease_Fever.mp3", "name": "Ramp Grease Fever"},
		{"path": "res://audio/Speed_Limit.mp3", "name": "Speed Limit"},
		{"path": "res://audio/Soapbox_Metal.mp3", "name": "Soapbox Metal"},
		{"path": "res://audio/Soapbox_Chill.mp3", "name": "Soapbox Chillin'"},
		{"path": "res://audio/Bug_Buffet.mp3", "name": "Bug Buffet"},
		{"path": "res://audio/Tiny_Little_Trophy.mp3", "name": "Tiny Little Trophy"}, 
		{"path": "res://audio/Big_Mac_Rocket.mp3", "name": "Big Mac Rocket"},
		{"path": "res://audio/Soapbox_Serenade.mp3", "name": "Soapbox Serenade"}, 
		{"path": "res://audio/Reposado.mp3", "name": "Reposado"}
	]

	var gameplay_songs := [
		{"path": "res://audio/Demolition_Derby.mp3", "name": "Demolition Derby"},
		{"path": "res://audio/Grind_The_Asphalt.mp3", "name": "Grind The Asphalt"},
		{"path": "res://audio/Downhill_Overdrive.mp3", "name": "Downhill Overdrive"},
		{"path": "res://audio/Ramp_Grease_Fever.mp3", "name": "Ramp Grease Fever"},
		{"path": "res://audio/Speed_Limit.mp3", "name": "Speed Limit"},
		{"path": "res://audio/Soapbox_Metal.mp3", "name": "Soapbox Metal"},
		{"path": "res://audio/Soapbox_Chill.mp3", "name": "Soapbox Chillin'"},
		{"path": "res://audio/Bug_Buffet.mp3", "name": "Bug Buffet"},
		{"path": "res://audio/Tiny_Little_Trophy.mp3", "name": "Tiny Little Trophy"},
		{"path": "res://audio/Big_Mac_Rocket.mp3", "name": "Big Mac Rocket"},
		{"path": "res://audio/Soapbox_Serenade.mp3", "name": "Soapbox Serenade"},
		{"path": "res://audio/Reposado.mp3", "name": "Reposado"}
	]

	for song in menu_songs:
		var path: String = str(song["path"])
		var track_name: String = str(song["name"])

		if ResourceLoader.exists(path):
			var stream := load(path) as AudioStream
			if stream != null:
				_menu_tracks.append(stream)
				_menu_track_names.append(track_name)

	for song in gameplay_songs:
		var path: String = str(song["path"])
		var track_name: String = str(song["name"])

		if ResourceLoader.exists(path):
			var stream := load(path) as AudioStream
			if stream != null:
				_gameplay_tracks.append(stream)
				_gameplay_track_names.append(track_name)

# =========================================================
# NOW PLAYING UI SETUP
# =========================================================
# Creates a bottom-left popup panel with a text label inside it.
# =========================================================
func _create_now_playing_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "NowPlayingUI"
	add_child(_ui_layer)

	_popup_panel = PanelContainer.new()
	_popup_panel.name = "NowPlayingPanel"
	_popup_panel.visible = false
	_popup_panel.anchor_left = 0.0
	_popup_panel.anchor_top = 1.0
	_popup_panel.anchor_right = 0.0
	_popup_panel.anchor_bottom = 1.0
	_popup_panel.offset_left = 20.0
	_popup_panel.offset_top = -90.0
	_popup_panel.offset_right = 320.0
	_popup_panel.offset_bottom = -20.0
	_ui_layer.add_child(_popup_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	_popup_panel.add_child(margin)

	_now_playing_label = Label.new()
	_now_playing_label.name = "NowPlayingLabel"
	_now_playing_label.text = ""
	_now_playing_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_now_playing_label.add_theme_font_size_override("font_size", 18)
	margin.add_child(_now_playing_label)

# =========================================================
# LOADING SCREEN SETUP
# =========================================================
# Builds the full-screen loading overlay used during transitions.
# =========================================================
func _build_loading_ui() -> void:
	loading_layer = CanvasLayer.new()
	loading_layer.name = "LoadingLayer"
	add_child(loading_layer)

	loading_rect = ColorRect.new()
	loading_rect.name = "LoadingRect"
	loading_rect.visible = false
	loading_rect.anchor_left = 0.0
	loading_rect.anchor_top = 0.0
	loading_rect.anchor_right = 1.0
	loading_rect.anchor_bottom = 1.0
	loading_rect.offset_left = 0.0
	loading_rect.offset_top = 0.0
	loading_rect.offset_right = 0.0
	loading_rect.offset_bottom = 0.0
	loading_rect.color = Color(0.02, 0.02, 0.02, 0.0)
	loading_layer.add_child(loading_rect)

	loading_label = Label.new()
	loading_label.name = "LoadingLabel"
	loading_label.visible = false
	loading_label.text = "Loading..."
	loading_label.anchor_left = 0.5
	loading_label.anchor_top = 0.5
	loading_label.anchor_right = 0.5
	loading_label.anchor_bottom = 0.5
	loading_label.offset_left = -220.0
	loading_label.offset_top = -30.0
	loading_label.offset_right = 220.0
	loading_label.offset_bottom = 30.0
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	loading_label.add_theme_font_size_override("font_size", 28)
	loading_layer.add_child(loading_label)

# =========================================================
# MODE PLAYBACK
# =========================================================
# Pick and play a random track from the relevant track pool.
# =========================================================
func play_random_menu_track() -> void:
	if _menu_tracks.is_empty():
		return

	var index: int = randi() % _menu_tracks.size()
	_play_track(_menu_tracks[index], _menu_track_names[index], "menu")

func play_random_gameplay_track() -> void:
	if _gameplay_tracks.is_empty():
		return

	var index: int = randi() % _gameplay_tracks.size()
	_play_track(_gameplay_tracks[index], _gameplay_track_names[index], "gameplay")

# =========================================================
# TRACK PLAYBACK
# =========================================================
# Crossfades between tracks by swapping the active/inactive player.
# =========================================================
func _play_track(stream: AudioStream, track_name: String, mode: String) -> void:
	if stream == null:
		return

	_current_mode = mode
	_current_track_name = track_name

	_inactive_player.stop()
	_inactive_player.stream = stream
	_inactive_player.volume_db = -80.0
	_inactive_player.play()

	var old_active := _active_player
	_active_player = _inactive_player
	_inactive_player = old_active

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_active_player, "volume_db", 0.0, 1.0)
	tween.parallel().tween_property(_inactive_player, "volume_db", -80.0, 1.0)
	tween.finished.connect(func():
		_inactive_player.stop()
	)

	_show_now_playing(track_name)

# =========================================================
# NOW PLAYING DISPLAY
# =========================================================
# Shows the currently playing track name for a short time.
# =========================================================
func _show_now_playing(track_name: String) -> void:
	if _popup_panel == null or _now_playing_label == null:
		return

	_now_playing_label.text = "Now Playing: %s" % track_name
	_popup_panel.visible = true

	_now_playing_timer = get_tree().create_timer(6.0)
	_now_playing_timer.timeout.connect(func():
		if _popup_panel != null:
			_popup_panel.visible = false
	)

# =========================================================
# LOADING OVERLAY DISPLAY
# =========================================================
# Shows the loading overlay and fades it in.
# =========================================================
func _show_loading_overlay(text: String) -> void:
	if loading_rect == null or loading_label == null:
		return

	loading_label.text = text if text != "" else "Loading..."
	loading_rect.visible = true
	loading_label.visible = true
	loading_rect.color.a = 0.0
	loading_label.modulate.a = 0.0

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(loading_rect, "color:a", 0.92, 0.25)
	tween.parallel().tween_property(loading_label, "modulate:a", 1.0, 0.25)

# =========================================================
# LOADING OVERLAY HIDE
# =========================================================
# Fades the loading overlay back out after the new scene loads.
# =========================================================
func _finish_transition() -> void:
	if loading_rect == null or loading_label == null:
		return

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(loading_rect, "color:a", 0.0, 0.25)
	tween.parallel().tween_property(loading_label, "modulate:a", 0.0, 0.25)
	tween.finished.connect(func():
		if loading_rect != null:
			loading_rect.visible = false
		if loading_label != null:
			loading_label.visible = false
	)

# =========================================================
# FADE HELPERS
# =========================================================
# Fades down both players, usually before a scene transition.
# =========================================================
func fade_out_music(duration: float = 1.0) -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_active_player, "volume_db", -80.0, duration)
	tween.parallel().tween_property(_inactive_player, "volume_db", -80.0, duration)

# =========================================================
# SCENE TRANSITIONS
# =========================================================
# Used when moving between menus/gameplay so the correct music mode
# is restored automatically after the scene change.
# =========================================================
func transition_to_scene(scene_path: String, loading_message: String = "") -> void:
	if _is_transitioning:
		return

	_is_transitioning = true
	_show_loading_overlay(loading_message)

	var is_gameplay_scene: bool = not (
		scene_path.ends_with("main_menu.tscn")
		or scene_path.ends_with("build_menu.tscn")
		or scene_path.ends_with("track_select.tscn")
	)

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_active_player, "volume_db", -80.0, 0.8)

	tween.finished.connect(func():
		get_tree().change_scene_to_file(scene_path)

		await get_tree().process_frame
		await get_tree().process_frame

		if is_gameplay_scene:
			play_random_gameplay_track()
		else:
			play_random_menu_track()

		_finish_transition()
		_is_transitioning = false
	)

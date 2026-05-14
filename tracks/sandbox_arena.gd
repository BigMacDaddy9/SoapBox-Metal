extends Node3D

# =========================================================
# SANDBOX ARENA
# =========================================================
# Arena-style gameplay scene responsible for:
# - spawning the player vehicle
# - optionally spawning an AI opponent
# - wiring the AI to target the player
#
# This scene acts as a simple testbed for combat, physics,
# and vehicle destruction systems.
# =========================================================

# =========================================================
# EXPORT VARIABLES
# =========================================================
# Scene used for spawning the enemy vehicle.
# =========================================================
@export var enemy_scene: PackedScene = preload("res://vehicles/platform_4w.tscn")

# =========================================================
# NODE REFERENCES
# =========================================================
# Spawn points for player and enemy vehicles.
# =========================================================
@onready var player_spawn: Marker3D = $PlayerSpawn
@onready var enemy_spawn: Marker3D = $EnemySpawn

# =========================================================
# RUNTIME STATE
# =========================================================
# References to the currently spawned player and enemy.
# =========================================================
var _player: Node3D = null
var _enemy: Node3D = null

# =========================================================
# READY
# =========================================================
# Called when the scene is loaded.
# Spawns the player and conditionally spawns the enemy AI.
# =========================================================
func _ready() -> void:
	_spawn_player()
	_spawn_enemy_if_enabled()

# =========================================================
# PLAYER SPAWNING
# =========================================================
# Spawns the player using the selected platform from settings.
# Falls back to the default platform if settings are unavailable.
# =========================================================
func _spawn_player() -> void:
	var scene_path := "res://vehicles/platform_4w.tscn"

	if has_node("/root/SBSettings"):
		scene_path = SBSettings.get_current_platform_scene_path()

	var player_scene := load(scene_path) as PackedScene
	if player_scene == null:
		push_error("SandboxArena: Failed to load player platform scene: " + scene_path)
		return

	_player = player_scene.instantiate()
	add_child(_player)
	_player.global_transform = player_spawn.global_transform
	_player.add_to_group("player")

# =========================================================
# ENEMY SPAWNING
# =========================================================
# Spawns an AI-controlled enemy if AI is enabled in settings.
# Also attaches the AI script and configures targeting and tuning.
# =========================================================
func _spawn_enemy_if_enabled() -> void:
	var enable_ai := true
	if has_node("/root/SBSettings"):
		enable_ai = SBSettings.ai_enabled

	if not enable_ai:
		print("SandboxArena: AI disabled, not spawning enemy.")
		return

	if enemy_scene == null:
		push_error("SandboxArena: enemy_scene is null.")
		return

	_enemy = enemy_scene.instantiate()
	add_child(_enemy)
	_enemy.global_transform = enemy_spawn.global_transform

	# =========================================================
	# AI SCRIPT ATTACHMENT
	# =========================================================
	# Dynamically attaches the enemy AI script to the spawned vehicle.
	# =========================================================
	var ai_script := load("res://enemy_ai.gd")
	if ai_script == null:
		push_error("SandboxArena: Could not load enemy_ai.gd")
		return

	_enemy.set_script(ai_script)

	# =========================================================
	# TARGET ASSIGNMENT
	# =========================================================
	# Ensures the AI targets the spawned player vehicle.
	# =========================================================
	if _player != null and "target_path" in _enemy:
		_enemy.target_path = _player.get_path()

	# =========================================================
	# AI TUNING OVERRIDES
	# =========================================================
	# Applies tuning values if the properties exist on the AI script.
	# This keeps compatibility with different AI versions.
	# =========================================================
	if "aggression" in _enemy:
		_enemy.aggression = 1.2
	if "steer_smoothing" in _enemy:
		_enemy.steer_smoothing = 10.0
	if "throttle" in _enemy:
		_enemy.throttle = 1.0
	if "lead_time" in _enemy:
		_enemy.lead_time = 0.15
	if "lead_time_max" in _enemy:
		_enemy.lead_time_max = 0.45
	if "ram_bias" in _enemy:
		_enemy.ram_bias = 0.08
	if "stuck_speed_threshold" in _enemy:
		_enemy.stuck_speed_threshold = 0.18
	if "stuck_time_to_trigger" in _enemy:
		_enemy.stuck_time_to_trigger = 1.2
	if "unstuck_time" in _enemy:
		_enemy.unstuck_time = 0.55
	if "unstuck_throttle" in _enemy:
		_enemy.unstuck_throttle = 1.0

	print("SandboxArena: Enemy spawned. AI enabled =", enable_ai)

# =========================================================
# MISSILE SYSTEM NOTE
# =========================================================
# Missiles are spawned by soapbox.gd (player) and enemy_ai.gd (AI).
# The arena does not need to manage missiles directly, as it inherits
# this behaviour from the vehicle scripts.
# =========================================================

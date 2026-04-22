extends CanvasLayer

# =========================================================
# DAMAGE HUD
# =========================================================
# This HUD currently handles two jobs:
# 1. Wheel damage display
# 2. Optional lap counter display
#
# The lap counter stays hidden by default and is only enabled
# by tracks that explicitly support lap counting.
# =========================================================

# =========================================================
# WHEEL DAMAGE UI REFERENCES
# =========================================================
@onready var rf_bar: TextureProgressBar = $WheelPanel/RF/Bar
@onready var lf_bar: TextureProgressBar = $WheelPanel/LF/Bar
@onready var rb_bar: TextureProgressBar = $WheelPanel/RB/Bar
@onready var lb_bar: TextureProgressBar = $WheelPanel/LB/Bar

@onready var rf_label: Label = $WheelPanel/RF/Label
@onready var lf_label: Label = $WheelPanel/LF/Label
@onready var rb_label: Label = $WheelPanel/RB/Label
@onready var lb_label: Label = $WheelPanel/LB/Label

# =========================================================
# LAP COUNTER UI REFERENCES
# =========================================================
@onready var lap_panel: Control = $LapPanel
@onready var track_label: Label = $LapPanel/TrackLabel
@onready var lap_label: Label = $LapPanel/LapLabel

# =========================================================
# RUNTIME STATE
# =========================================================
var _player: Node = null
var _lap_counter_enabled: bool = false


# =========================================================
# READY
# =========================================================
func _ready() -> void:
	# Lap UI is off by default so older tracks do not show it.
	lap_panel.visible = false
	track_label.text = ""
	lap_label.text = ""


# =========================================================
# PROCESS
# =========================================================
# We keep looking for the player until one exists, then update
# the wheel damage bars every frame.
# =========================================================
func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return

	_update_wheel("RightFrontWheel", rf_bar, rf_label, "RF")
	_update_wheel("LeftFrontWheel", lf_bar, lf_label, "LF")
	_update_wheel("RightBackWheel", rb_bar, rb_label, "RB")
	_update_wheel("LeftBackWheel", lb_bar, lb_label, "LB")


# =========================================================
# WHEEL UPDATE
# =========================================================
func _update_wheel(wheel_name: String, bar: TextureProgressBar, label: Label, short_name: String) -> void:
	if not _player.has_method("get_wheel_damage_ratio_by_name"):
		return

	var ratio: float = float(_player.call("get_wheel_damage_ratio_by_name", wheel_name))
	var detached: bool = false

	if _player.has_method("is_wheel_detached_by_name"):
		detached = bool(_player.call("is_wheel_detached_by_name", wheel_name))

	var pct: int = int(round(ratio * 100.0))
	bar.value = pct
	label.text = ("%s: OFF" % short_name) if detached else ("%s: %d%%" % [short_name, pct])


# =========================================================
# LAP COUNTER CONTROL
# =========================================================
# Tracks can call this to enable / disable lap UI without having
# to create a separate HUD system.
# =========================================================
func set_lap_counter_enabled(enabled: bool) -> void:
	_lap_counter_enabled = enabled
	lap_panel.visible = enabled

	if not enabled:
		track_label.text = ""
		lap_label.text = ""


# =========================================================
# LAP COUNTER DATA
# =========================================================
# Call this from lap-based tracks whenever the lap count changes.
# =========================================================
func set_lap_counter(track_name: String, lap_number: int) -> void:
	if not _lap_counter_enabled:
		return

	track_label.text = track_name
	lap_label.text = "Lap %d" % lap_number
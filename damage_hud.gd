extends CanvasLayer

@export var player_path: NodePath = NodePath("../Soapbox")

@onready var rf_bar: TextureProgressBar = $WheelPanel/RF/Bar
@onready var lf_bar: TextureProgressBar = $WheelPanel/LF/Bar
@onready var rb_bar: TextureProgressBar = $WheelPanel/RB/Bar
@onready var lb_bar: TextureProgressBar = $WheelPanel/LB/Bar

@onready var rf_label: Label = $WheelPanel/RF/Label
@onready var lf_label: Label = $WheelPanel/LF/Label
@onready var rb_label: Label = $WheelPanel/RB/Label
@onready var lb_label: Label = $WheelPanel/LB/Label

var _player: Node = null

func _ready() -> void:
	_player = get_node_or_null(player_path)

func _process(_delta: float) -> void:
	if _player == null:
		return

	_update_wheel("RightFrontWheel", rf_bar, rf_label, "RF")
	_update_wheel("LeftFrontWheel",  lf_bar, lf_label, "LF")
	_update_wheel("RightBackWheel",  rb_bar, rb_label, "RB")
	_update_wheel("LeftBackWheel",   lb_bar, lb_label, "LB")

func _update_wheel(wheel_name: String, bar: TextureProgressBar, label: Label, short_name: String) -> void:
	if not _player.has_method("get_wheel_damage_ratio_by_name"):
		return

	var ratio: float = float(_player.call("get_wheel_damage_ratio_by_name", wheel_name))
	var detached: bool = false
	if _player.has_method("is_wheel_detached_by_name"):
		detached = bool(_player.call("is_wheel_detached_by_name", wheel_name))

	var pct: int = int(round(ratio * 100.0))
	bar.value = pct

	if detached:
		label.text = "%s: OFF" % short_name
	else:
		label.text = "%s: %d%%" % [short_name, pct]

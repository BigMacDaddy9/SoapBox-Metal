extends Control

# =========================================================
# BUILD MENU
# =========================================================
# Main vehicle build screen for selecting:
# - platform
# - base
# - modular parts
#
# The menu also keeps the live preview in sync while the player
# switches tabs and changes their current build.
# =========================================================

const MAIN_MENU := "res://main_menu.tscn"

# =========================================================
# PART CARD
# =========================================================
# Drag-enabled button used in the parts palette.
# =========================================================
class PartCard extends Button:
	signal drag_started(part_id: String)

	var part_id: String = ""
	var display_name: String = ""

	func _get_drag_data(_at_position: Vector2) -> Variant:
		var data := {
			"type": "build_part",
			"part_id": part_id,
		}

		var preview := PanelContainer.new()
		preview.custom_minimum_size = Vector2(180, 42)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_bottom", 8)
		preview.add_child(margin)

		var label := Label.new()
		label.text = display_name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 16)
		margin.add_child(label)

		set_drag_preview(preview)
		emit_signal("drag_started", part_id)
		return data

# =========================================================
# MOUNT DROP SLOT
# =========================================================
# Drop target used for each build mount in the build tab.
# =========================================================
class MountDropSlot extends PanelContainer:
	signal part_dropped(mount_name: String, part_id: String)
	signal clear_pressed(mount_name: String)

	var mount_name: String = ""
	var title_label: Label
	var value_label: Label
	var hint_label: Label
	var clear_button: Button

	func setup(mount_id: String, assigned_part_id: String) -> void:
		mount_name = mount_id
		custom_minimum_size = Vector2(0, 110)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 14)
		margin.add_theme_constant_override("margin_top", 12)
		margin.add_theme_constant_override("margin_right", 14)
		margin.add_theme_constant_override("margin_bottom", 12)
		add_child(margin)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 6)
		margin.add_child(vbox)

		title_label = Label.new()
		title_label.text = SBSettings.get_mount_display_name(mount_name)
		title_label.add_theme_font_size_override("font_size", 18)
		vbox.add_child(title_label)

		value_label = Label.new()
		value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		value_label.add_theme_font_size_override("font_size", 16)
		vbox.add_child(value_label)

		hint_label = Label.new()
		hint_label.text = "Drag any part here"
		hint_label.modulate = Color(0.78, 0.78, 0.78, 1.0)
		hint_label.add_theme_font_size_override("font_size", 14)
		vbox.add_child(hint_label)

		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_END
		row.add_theme_constant_override("separation", 8)
		vbox.add_child(row)

		clear_button = Button.new()
		clear_button.text = "Clear"
		clear_button.custom_minimum_size = Vector2(96, 40)
		clear_button.add_theme_font_size_override("font_size", 15)
		clear_button.pressed.connect(func(): emit_signal("clear_pressed", mount_name))
		row.add_child(clear_button)

		set_part(assigned_part_id)

	func set_part(part_id: String) -> void:
		if part_id == "":
			value_label.text = "Attached: Empty"
		else:
			value_label.text = "Attached: %s" % SBSettings.get_part_display_name(part_id)

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.get("type", "") == "build_part" and str(data.get("part_id", "")) != ""

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if not _can_drop_data(_at_position, data):
			return
		emit_signal("part_dropped", mount_name, str(data["part_id"]))

# =========================================================
# NODE REFERENCES
# =========================================================
@onready var title_label: Label = $ScreenMargin/MainHBox/ConfigPanel/ConfigMargin/ConfigVBox/HeaderPanel/HeaderMargin/HeaderVBox/Title
@onready var current_platform_label: Label = $ScreenMargin/MainHBox/ConfigPanel/ConfigMargin/ConfigVBox/HeaderPanel/HeaderMargin/HeaderVBox/CurrentPlatformLabel
@onready var current_base_label: Label = $ScreenMargin/MainHBox/ConfigPanel/ConfigMargin/ConfigVBox/HeaderPanel/HeaderMargin/HeaderVBox/CurrentBaseLabel
@onready var description_label: Label = $ScreenMargin/MainHBox/ConfigPanel/ConfigMargin/ConfigVBox/HeaderPanel/HeaderMargin/HeaderVBox/DescriptionLabel
@onready var tabs: TabContainer = $ScreenMargin/MainHBox/ConfigPanel/ConfigMargin/ConfigVBox/Tabs
@onready var platform_list: VBoxContainer = $ScreenMargin/MainHBox/ConfigPanel/ConfigMargin/ConfigVBox/Tabs/PlatformTab/PlatformMargin/PlatformVBox/PlatformList
@onready var base_list: VBoxContainer = $ScreenMargin/MainHBox/ConfigPanel/ConfigMargin/ConfigVBox/Tabs/BaseTab/BaseMargin/BaseVBox/BaseList
@onready var build_tab_description: Label = $ScreenMargin/MainHBox/ConfigPanel/ConfigMargin/ConfigVBox/Tabs/BuildTab/BuildMargin/BuildVBox/BuildTabDescription
@onready var selected_part_label: Label = $ScreenMargin/MainHBox/ConfigPanel/ConfigMargin/ConfigVBox/Tabs/BuildTab/BuildMargin/BuildVBox/SelectedPartLabel
@onready var part_palette: VBoxContainer = $ScreenMargin/MainHBox/ConfigPanel/ConfigMargin/ConfigVBox/Tabs/BuildTab/BuildMargin/BuildVBox/BuildHBox/PartsPanel/PartsMargin/PartsVBox/PartScroll/PartPalette
@onready var mount_palette: VBoxContainer = $ScreenMargin/MainHBox/ConfigPanel/ConfigMargin/ConfigVBox/Tabs/BuildTab/BuildMargin/BuildVBox/BuildHBox/MountPanel/MountMargin/MountVBox/MountScroll/MountPalette
@onready var preview: Node = $ScreenMargin/MainHBox/PreviewPanel/PreviewMargin/PreviewVBox/PreviewViewportContainer/SubViewport/BuildPreview
@onready var save_button: Button = $ScreenMargin/MainHBox/ConfigPanel/ConfigMargin/ConfigVBox/FooterRow/SaveButton
@onready var back_button: Button = $ScreenMargin/MainHBox/ConfigPanel/ConfigMargin/ConfigVBox/FooterRow/BackButton

# =========================================================
# RUNTIME STATE
# =========================================================
var _pending_base: String = "light"
var _pending_platform: String = "four_wheeler"
var _pending_parts: Dictionary = {}
var _selected_part_id: String = ""
var _mount_rows: Dictionary = {}

# =========================================================
# READY
# =========================================================
func _ready() -> void:
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_pending_base = SBSettings.selected_base
	if _pending_base == "thin" or _pending_base == "none":
		_pending_base = "light"

	_pending_platform = SBSettings.selected_platform
	_pending_parts = SBSettings.get_sanitized_selected_parts().duplicate(true)

	save_button.pressed.connect(_on_save_pressed)
	back_button.pressed.connect(_on_back_pressed)
	tabs.tab_changed.connect(_on_tab_changed)

	_apply_text_sizing()
	_build_platform_tab()
	_build_base_tab()
	_build_build_tab()
	_refresh_all()

# =========================================================
# UI SETUP
# =========================================================
func _apply_text_sizing() -> void:
	title_label.add_theme_font_size_override("font_size", 30)
	current_platform_label.add_theme_font_size_override("font_size", 19)
	current_base_label.add_theme_font_size_override("font_size", 19)
	description_label.add_theme_font_size_override("font_size", 16)
	build_tab_description.add_theme_font_size_override("font_size", 16)
	selected_part_label.add_theme_font_size_override("font_size", 18)
	tabs.add_theme_font_size_override("font_size", 18)
	save_button.add_theme_font_size_override("font_size", 18)
	back_button.add_theme_font_size_override("font_size", 18)

func _build_platform_tab() -> void:
	for child in platform_list.get_children():
		child.queue_free()

	var ids: Array[String] = ["four_wheeler", "three_wheeler", "two_wheeler"]
	for platform_id in ids:
		var button := Button.new()
		button.text = str(SBSettings.platform_presets[platform_id]["display_name"])
		button.custom_minimum_size = Vector2(0, 70)
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(_select_platform.bind(platform_id))
		platform_list.add_child(button)

func _build_base_tab() -> void:
	for child in base_list.get_children():
		child.queue_free()

	var ids: Array[String] = ["light", "heavy"]
	for base_id in ids:
		var button := Button.new()
		button.text = str(SBSettings.base_presets[base_id]["display_name"])
		button.custom_minimum_size = Vector2(0, 70)
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(_select_base.bind(base_id))
		base_list.add_child(button)

func _build_build_tab() -> void:
	for child in part_palette.get_children():
		child.queue_free()

	for child in mount_palette.get_children():
		child.queue_free()

	_mount_rows.clear()

	var part_ids: Array[String] = []
	for part_id in SBSettings.part_presets.keys():
		part_ids.append(str(part_id))
	part_ids.sort()

	for part_id in part_ids:
		var card := PartCard.new()
		card.part_id = part_id
		card.display_name = SBSettings.get_part_display_name(part_id)
		card.text = card.display_name
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.custom_minimum_size = Vector2(0, 58)
		card.add_theme_font_size_override("font_size", 17)
		card.drag_started.connect(_on_part_drag_started)
		card.pressed.connect(_select_part.bind(part_id))
		part_palette.add_child(card)

	for mount_name in SBSettings.build_mount_order:
		var row := MountDropSlot.new()
		row.setup(mount_name, str(_pending_parts.get(mount_name, "")))
		row.part_dropped.connect(_on_mount_part_dropped)
		row.clear_pressed.connect(_on_mount_clear_pressed)
		mount_palette.add_child(row)
		_mount_rows[mount_name] = row

# =========================================================
# INPUT / SELECTION
# =========================================================
func _select_platform(platform_name: String) -> void:
	_pending_platform = platform_name
	_refresh_all()

func _select_base(base_name: String) -> void:
	_pending_base = base_name
	_refresh_all()

func _select_part(part_id: String) -> void:
	_selected_part_id = part_id
	_refresh_ui_only()

func _on_part_drag_started(part_id: String) -> void:
	_selected_part_id = part_id
	_refresh_ui_only()

func _on_mount_part_dropped(mount_name: String, part_id: String) -> void:
	_pending_parts[mount_name] = part_id
	_selected_part_id = part_id
	_refresh_all()

func _on_mount_clear_pressed(mount_name: String) -> void:
	_pending_parts[mount_name] = ""
	_refresh_all()

# =========================================================
# REFRESH
# =========================================================
func _refresh_all() -> void:
	_refresh_mount_rows()
	_refresh_ui_only()
	_refresh_preview()

func _refresh_mount_rows() -> void:
	for mount_name in _mount_rows.keys():
		var row := _mount_rows[mount_name] as MountDropSlot
		if row:
			row.set_part(str(_pending_parts.get(mount_name, "")))

func _refresh_ui_only() -> void:
	current_platform_label.text = "Current Platform: %s" % str(SBSettings.platform_presets[_pending_platform]["display_name"])
	current_base_label.text = "Current Base: %s" % str(SBSettings.base_presets[_pending_base]["display_name"])

	if _selected_part_id == "":
		selected_part_label.text = "Selected Part: None"
	else:
		selected_part_label.text = "Selected Part: %s" % SBSettings.get_part_display_name(_selected_part_id)

	description_label.text = "The live preview on the right updates on every tab. Choose a platform, choose a base plate, then drag any part onto any mount point in the Build tab."
	build_tab_description.text = "Drag a part from the left panel and drop it onto any mount point on the right. The preview stays live while you build, and your current platform, base, and parts stay remembered as you switch tabs."

func _refresh_preview() -> void:
	if preview and preview.has_method("set_build"):
		preview.set_build(_pending_platform, _pending_base, _pending_parts)

	if preview and preview.has_method("set_rotate_preview"):
		preview.set_rotate_preview(true)

# =========================================================
# TAB / BUTTON EVENTS
# =========================================================
func _on_tab_changed(_tab_index: int) -> void:
	_refresh_ui_only()
	_refresh_preview()

func _on_save_pressed() -> void:
	SBSettings.selected_base = _pending_base
	SBSettings.selected_platform = _pending_platform
	SBSettings.selected_parts = _pending_parts.duplicate(true)
	get_tree().change_scene_to_file(MAIN_MENU)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)

extends Window

const SETTINGS_PATH: String = "user://settings.cfg"

@onready var tabs: TabContainer = $Margin/VBox/Tabs
@onready var autosave_toggle: CheckBox = $Margin/VBox/Tabs/Gameplay/GameplayVBox/AutosaveToggle
@onready var push_scroll_toggle: CheckBox = $Margin/VBox/Tabs/Gameplay/GameplayVBox/PushScrollToggle
@onready var difficulty_option: OptionButton = $Margin/VBox/Tabs/Gameplay/GameplayVBox/DifficultyRow/DifficultyOption
@onready var tooltip_slider: HSlider = $Margin/VBox/Tabs/Gameplay/GameplayVBox/TooltipRow/TooltipSlider
@onready var tooltip_value_label: Label = $Margin/VBox/Tabs/Gameplay/GameplayVBox/TooltipRow/TooltipValue
@onready var window_mode_option: OptionButton = $Margin/VBox/Tabs/Video/VideoVBox/WindowModeRow/WindowModeOption
@onready var vsync_toggle: CheckBox = $Margin/VBox/Tabs/Video/VideoVBox/VSyncToggle
@onready var ui_scale_slider: HSlider = $Margin/VBox/Tabs/Video/VideoVBox/UIScaleRow/UIScaleSlider
@onready var ui_scale_value_label: Label = $Margin/VBox/Tabs/Video/VideoVBox/UIScaleRow/UIScaleValue
@onready var master_slider: HSlider = $Margin/VBox/Tabs/Audio/AudioVBox/MasterRow/MasterSlider
@onready var master_value_label: Label = $Margin/VBox/Tabs/Audio/AudioVBox/MasterRow/MasterValue
@onready var music_slider: HSlider = $Margin/VBox/Tabs/Audio/AudioVBox/MusicRow/MusicSlider
@onready var music_value_label: Label = $Margin/VBox/Tabs/Audio/AudioVBox/MusicRow/MusicValue
@onready var sfx_slider: HSlider = $Margin/VBox/Tabs/Audio/AudioVBox/SfxRow/SfxSlider
@onready var sfx_value_label: Label = $Margin/VBox/Tabs/Audio/AudioVBox/SfxRow/SfxValue
@onready var reduce_motion_toggle: CheckBox = $Margin/VBox/Tabs/Accessibility/AccessibilityVBox/ReduceMotionToggle
@onready var high_contrast_toggle: CheckBox = $Margin/VBox/Tabs/Accessibility/AccessibilityVBox/HighContrastToggle
@onready var text_speed_option: OptionButton = $Margin/VBox/Tabs/Accessibility/AccessibilityVBox/TextSpeedRow/TextSpeedOption
@onready var actions_list: ItemList = $Margin/VBox/Tabs/Controls/ControlsVBox/ActionsList
@onready var reset_button: Button = $Margin/VBox/Buttons/ResetButton
@onready var cancel_button: Button = $Margin/VBox/Buttons/CancelButton
@onready var apply_button: Button = $Margin/VBox/Buttons/ApplyButton

var _settings: Dictionary = {}


func _ready() -> void:
	title = "Settings"
	unresizable = false
	close_requested.connect(hide)
	_setup_options()
	_bind_events()
	_load_or_default_settings()
	_apply_settings_to_ui()
	_refresh_slider_labels()
	_populate_actions_list()


func _setup_options() -> void:
	difficulty_option.add_item("Story", 0)
	difficulty_option.add_item("Standard", 1)
	difficulty_option.add_item("Harsh", 2)

	window_mode_option.add_item("Windowed", Window.MODE_WINDOWED)
	window_mode_option.add_item("Maximized", Window.MODE_MAXIMIZED)
	window_mode_option.add_item("Fullscreen", Window.MODE_FULLSCREEN)

	text_speed_option.add_item("Slow", 0)
	text_speed_option.add_item("Normal", 1)
	text_speed_option.add_item("Fast", 2)


func _bind_events() -> void:
	tooltip_slider.value_changed.connect(_on_slider_changed)
	ui_scale_slider.value_changed.connect(_on_slider_changed)
	master_slider.value_changed.connect(_on_slider_changed)
	music_slider.value_changed.connect(_on_slider_changed)
	sfx_slider.value_changed.connect(_on_slider_changed)
	reset_button.pressed.connect(_on_reset_pressed)
	cancel_button.pressed.connect(hide)
	apply_button.pressed.connect(_on_apply_pressed)


func _default_settings() -> Dictionary:
	return {
		"gameplay/autosave": false,
		"gameplay/push_scroll": GameState.enable_push_scroll,
		"gameplay/difficulty": 1,
		"gameplay/tooltip_seconds": 2.0,
		"video/window_mode": Window.MODE_WINDOWED,
		"video/vsync": true,
		"video/ui_scale": 1.0,
		"audio/master_volume": 0.8,
		"audio/music_volume": 0.7,
		"audio/sfx_volume": 0.8,
		"accessibility/reduce_motion": false,
		"accessibility/high_contrast": false,
		"accessibility/text_speed": 1,
	}


func _load_or_default_settings() -> void:
	_settings = _default_settings()
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return

	for key in _settings.keys():
		var key_str: String = str(key)
		var parts: PackedStringArray = key_str.split("/")
		_settings[key_str] = cfg.get_value(parts[0], parts[1], _settings[key_str])


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in _settings.keys():
		var key_str: String = str(key)
		var parts: PackedStringArray = key_str.split("/")
		cfg.set_value(parts[0], parts[1], _settings[key_str])
	cfg.save(SETTINGS_PATH)


func _apply_settings_to_ui() -> void:
	autosave_toggle.button_pressed = _settings["gameplay/autosave"]
	push_scroll_toggle.button_pressed = _settings["gameplay/push_scroll"]
	difficulty_option.select(int(_settings["gameplay/difficulty"]))
	tooltip_slider.value = float(_settings["gameplay/tooltip_seconds"])
	window_mode_option.select(window_mode_option.get_item_index(int(_settings["video/window_mode"])))
	vsync_toggle.button_pressed = _settings["video/vsync"]
	ui_scale_slider.value = float(_settings["video/ui_scale"])
	master_slider.value = float(_settings["audio/master_volume"])
	music_slider.value = float(_settings["audio/music_volume"])
	sfx_slider.value = float(_settings["audio/sfx_volume"])
	reduce_motion_toggle.button_pressed = _settings["accessibility/reduce_motion"]
	high_contrast_toggle.button_pressed = _settings["accessibility/high_contrast"]
	text_speed_option.select(int(_settings["accessibility/text_speed"]))


func _collect_ui_settings() -> void:
	_settings["gameplay/autosave"] = autosave_toggle.button_pressed
	_settings["gameplay/push_scroll"] = push_scroll_toggle.button_pressed
	_settings["gameplay/difficulty"] = difficulty_option.get_selected_id()
	_settings["gameplay/tooltip_seconds"] = tooltip_slider.value
	_settings["video/window_mode"] = window_mode_option.get_selected_id()
	_settings["video/vsync"] = vsync_toggle.button_pressed
	_settings["video/ui_scale"] = ui_scale_slider.value
	_settings["audio/master_volume"] = master_slider.value
	_settings["audio/music_volume"] = music_slider.value
	_settings["audio/sfx_volume"] = sfx_slider.value
	_settings["accessibility/reduce_motion"] = reduce_motion_toggle.button_pressed
	_settings["accessibility/high_contrast"] = high_contrast_toggle.button_pressed
	_settings["accessibility/text_speed"] = text_speed_option.get_selected_id()


func _apply_runtime_effects() -> void:
	var root_window := get_tree().root
	GameState.set_push_scroll_enabled(bool(_settings["gameplay/push_scroll"]))
	root_window.mode = int(_settings["video/window_mode"])
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if _settings["video/vsync"] else DisplayServer.VSYNC_DISABLED)
	root_window.content_scale_factor = float(_settings["video/ui_scale"])
	AudioServer.set_bus_volume_db(0, linear_to_db(max(0.0001, float(_settings["audio/master_volume"]))))


func _on_slider_changed(_value: float) -> void:
	_refresh_slider_labels()


func _refresh_slider_labels() -> void:
	tooltip_value_label.text = "%.1fs" % tooltip_slider.value
	ui_scale_value_label.text = "%.0f%%" % (ui_scale_slider.value * 100.0)
	master_value_label.text = "%.0f%%" % (master_slider.value * 100.0)
	music_value_label.text = "%.0f%%" % (music_slider.value * 100.0)
	sfx_value_label.text = "%.0f%%" % (sfx_slider.value * 100.0)


func _populate_actions_list() -> void:
	actions_list.clear()
	for action_name in InputMap.get_actions():
		actions_list.add_item(action_name)


func _on_reset_pressed() -> void:
	_settings = _default_settings()
	_apply_settings_to_ui()
	_refresh_slider_labels()


func _on_apply_pressed() -> void:
	_collect_ui_settings()
	_apply_runtime_effects()
	_save_settings()
	hide()

extends Control
## A full-screen page from the book with a caption. Tap anywhere (or the button) to continue.

signal finished

var _texture: Texture2D
var _caption := ""
var _button_text := "Next"
var _ready_at := 0
var _done := false


func setup(texture: Texture2D, caption: String, button_text: String) -> void:
	_texture = texture
	_caption = caption
	_button_text = button_text


func _ready() -> void:
	%Picture.texture = _texture
	%Caption.text = _caption
	%NextButton.text = _button_text
	%NextButton.pressed.connect(_continue)
	_ready_at = Time.get_ticks_msec() + 800
	# Slow "Ken Burns" drift so the page feels alive.
	await get_tree().process_frame
	%Picture.pivot_offset = %Picture.size / 2
	%Picture.scale = Vector2(1.04, 1.04)
	create_tween().tween_property(%Picture, "scale", Vector2.ONE, 6.0).set_trans(Tween.TRANS_SINE)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_continue()


func _continue() -> void:
	if _done or Time.get_ticks_msec() < _ready_at:
		return
	_done = true
	Sfx.play("pop")
	finished.emit()

extends Control
## Ned, Lola's best friend, popping up from the bottom of the screen to help.
## Add it full-screen (it never blocks touches) and call say().

const INK := Color(0.149, 0.102, 0.18)

## Ned waving (from the book's last page), cut off at the bottom so he rises from the screen edge.
@export var texture: Texture2D = preload("res://assets/ui/ned_wave.png")
## How tall Ned is drawn, and how much of him peeks above the bottom edge.
@export var ned_height := 600.0
@export var peek := 600.0
@export var bubble_width := 440.0
## Put the bubble above Ned's head instead of beside it.
@export var bubble_above := false

var _ned := TextureRect.new()
var _bubble := PanelContainer.new()
var _label := Label.new()
var _say_id := 0
var _side := "right"
var _tween: Tween


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ned.texture = texture
	_ned.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ned.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_ned.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w := ned_height * texture.get_width() / texture.get_height()
	_ned.size = Vector2(w, ned_height)
	_ned.pivot_offset = Vector2(w / 2, ned_height)
	add_child(_ned)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.957, 1)
	style.set_border_width_all(6)
	style.border_color = INK
	style.set_corner_radius_all(34)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 14
	style.content_margin_bottom = 18
	_bubble.add_theme_stylebox_override("panel", style)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(bubble_width, 0)
	_label.add_theme_font_size_override("font_size", 40)
	_label.add_theme_color_override("font_color", INK)
	_bubble.add_child(_label)
	add_child(_bubble)
	_bubble.modulate.a = 0.0
	_ned.position.y = 100000.0  # off screen until Ned has something to say


## Ned pops up on `side` ("left" or "right") and says something. hold <= 0 keeps him up.
func say(text: String, hold := 3.5, side := "right") -> void:
	_say_id += 1
	var my_id := _say_id
	var was_up := is_up()
	if was_up and side != _side:
		await _hide()
		if my_id != _say_id:
			return
	_side = side
	_label.text = text
	_place(was_up and side == _side)
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel()
	_tween.tween_property(_ned, "position:y", _view().y - peek, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_bubble, "modulate:a", 1.0, 0.25).set_delay(0.15)
	hop()
	Sfx.play("pop", 0.1, -8.0)
	if hold <= 0.0:
		return
	await get_tree().create_timer(hold).timeout
	if my_id == _say_id:
		_hide()


## A happy little bounce.
func hop() -> void:
	var tw := create_tween()
	tw.tween_property(_ned, "rotation", -0.06 if _side == "right" else 0.06, 0.1)
	tw.tween_property(_ned, "scale", Vector2(1.04, 0.96), 0.08)
	tw.tween_property(_ned, "scale", Vector2(0.98, 1.04), 0.1)
	tw.tween_property(_ned, "scale", Vector2.ONE, 0.12)
	tw.tween_property(_ned, "rotation", 0.0, 0.15)


func hide_now() -> void:
	_say_id += 1
	_hide()


func is_up() -> bool:
	return _ned.position.y < _view().y - 1.0


func _hide() -> Signal:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel()
	_tween.tween_property(_bubble, "modulate:a", 0.0, 0.15)
	_tween.tween_property(_ned, "position:y", _view().y + 10.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	return _tween.finished


## Screen size (this Control may not be laid out yet, so ask the viewport).
func _view() -> Vector2:
	return get_viewport_rect().size


## Puts Ned at the chosen edge and his bubble beside his head.
func _place(keep_y: bool) -> void:
	var margin := 24.0
	var w := _ned.size.x
	_ned.position.x = _view().x - w - margin if _side == "right" else margin
	_ned.flip_h = _side == "right"  # the art faces right; always face into the room
	if not keep_y:
		_ned.position.y = _view().y + 10.0
	_bubble.reset_size()
	var bw := _bubble.size.x
	var top := _view().y - peek + 10.0
	if bubble_above:
		var x := clampf(_ned.position.x + w / 2 - bw / 2, margin, _view().x - bw - margin)
		_bubble.position = Vector2(x, top - _bubble.size.y - 16.0)
	else:
		_bubble.position = Vector2(_ned.position.x - bw - 6.0 if _side == "right" else _ned.position.x + w + 6.0, top)

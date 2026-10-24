extends CanvasLayer
## Lola's speech bubble + portrait, the "mess left" meter, and the hint button.

signal hint_pressed

const MOODS := {
	"worried": preload("res://assets/ui/lola_worried.png"),
	"happy": preload("res://assets/ui/lola_happy.png"),
	"joy": preload("res://assets/ui/lola_joy.png"),
}

@onready var _margin: MarginContainer = %Margin
@onready var _badge: TextureRect = %LolaBadge
@onready var _bubble: PanelContainer = %Bubble
@onready var _bubble_label: Label = %BubbleLabel
@onready var _count: Label = %CountLabel
@onready var _bar: ProgressBar = %Bar
@onready var _hint: Button = %HintButton

var _say_id := 0
var _mood := ""


func _ready() -> void:
	_hint.pressed.connect(func(): hint_pressed.emit())
	_bubble.modulate.a = 0.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.58, 0.39, 0.78)
	fill.set_corner_radius_all(20)
	fill.set_border_width_all(5)
	fill.border_color = Color(0.149, 0.102, 0.18)
	_bar.add_theme_stylebox_override("fill", fill)
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)


## Keep the HUD clear of notches / rounded corners on phones.
func _apply_safe_area() -> void:
	var win := Vector2(DisplayServer.window_get_size())
	if win.x <= 0:
		return
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var to_view := get_viewport().get_visible_rect().size.x / win.x
	var left := maxf(28.0, safe.position.x * to_view + 8.0)
	var right := maxf(28.0, (win.x - safe.end.x) * to_view + 8.0)
	var top := maxf(24.0, safe.position.y * to_view + 8.0)
	if safe.size.x <= 0 or safe.size.x > win.x:
		left = 28.0
		right = 28.0
		top = 24.0
	_margin.add_theme_constant_override("margin_left", int(left))
	_margin.add_theme_constant_override("margin_right", int(right))
	_margin.add_theme_constant_override("margin_top", int(top))


func set_mood(mood: String) -> void:
	if mood == _mood:
		return
	_mood = mood
	_badge.texture = MOODS[mood]
	_pop(_badge)


## Shows a line in Lola's speech bubble. hold <= 0 keeps it up until the next line.
func say(text: String, hold := 3.5) -> void:
	_say_id += 1
	var my_id := _say_id
	_bubble_label.text = text
	_bubble.modulate.a = 0.0
	create_tween().tween_property(_bubble, "modulate:a", 1.0, 0.2)
	_pop(_badge)
	if hold <= 0.0:
		return
	await get_tree().create_timer(hold).timeout
	if my_id == _say_id and is_instance_valid(_bubble):
		create_tween().tween_property(_bubble, "modulate:a", 0.0, 0.4)


func set_progress(remaining: int, total: int) -> void:
	_count.text = "Mess left: %d" % remaining
	var target := 100.0 * float(total - remaining) / maxf(1.0, float(total))
	create_tween().tween_property(_bar, "value", target, 0.35).set_trans(Tween.TRANS_SINE)


func set_hint_visible(on: bool) -> void:
	_hint.visible = on


## True when a screen position is over a HUD button (so the room ignores that touch).
func blocks(screen_pos: Vector2) -> bool:
	return _hint.visible and _hint.get_global_rect().grow(8).has_point(screen_pos)


func _pop(c: Control) -> void:
	c.pivot_offset = c.size / 2
	var tw := create_tween()
	tw.tween_property(c, "scale", Vector2(1.12, 1.12), 0.08)
	tw.tween_property(c, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

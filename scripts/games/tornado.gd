extends Control
## Chapter 1 game: "Like a purple tornado, her room was a mess!"
## Lola's things whirl around the purple tornado from the book's two-page spread. Tap them to catch them and
## they hop into the toy box; every catch makes the tornado a little smaller, until it's gone.

signal finished

const PAGES := "res://assets/story/pages/pages.json"
const TOYS := ["teddy", "cat", "ball", "boat", "teacup_a", "block_a", "butterfly", "cloud",
	"bunny", "flower", "pajamas", "notebook", "block_b", "teacup_b"]
const GOAL := 10
const INK := Color(0.149, 0.102, 0.18)
const TEX_SPARKLE := preload("res://assets/ui/sparkle.png")
const TEX_PUFF := preload("res://assets/ui/puff.png")

var _tornado := Node2D.new()   # both halves of the swirl, centred on this node
var _tornado_size := Vector2.ZERO
var _box := Sprite2D.new()
var _toys: Array = []          # {node, angle, speed, height, radius, done}
var _caught := 0
var _label := Label.new()
var _lola := TextureRect.new()
var _center := Vector2.ZERO
var _spin := 0.0
var _over := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.64, 0.52, 0.71)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var pages: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PAGES))
	var x := 0.0
	var halves: Array[Sprite2D] = []
	for id in ["5", "6"]:
		for c in pages[id].chunks:
			if c.part == "tornado":
				var half := Sprite2D.new()
				half.texture = load(c.tex)
				half.position = Vector2(c.pos[0] + x, c.pos[1])
				halves.append(half)
		x += pages[id].size[0]
	var r := Rect2()
	for i in halves.size():
		var hr := Rect2(halves[i].position - halves[i].texture.get_size() / 2, halves[i].texture.get_size())
		r = hr if i == 0 else r.merge(hr)
	for h in halves:
		h.position -= r.get_center()
		_tornado.add_child(h)
	_tornado_size = r.size
	add_child(_tornado)
	_box.texture = preload("res://assets/room/props/toybox.png")
	add_child(_box)
	for id in TOYS:
		var s := Sprite2D.new()
		s.texture = load("res://assets/room/items/%s.png" % id)
		add_child(s)
		_toys.append({"node": s, "angle": randf() * TAU, "speed": randf_range(0.8, 1.4),
			"height": randf_range(-0.42, 0.25), "radius": randf_range(0.7, 1.15), "done": false})
	_lola.texture = preload("res://assets/ui/lola_worried.png")
	_lola.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_lola.size = Vector2(170, 170)
	_lola.position = Vector2(28, 24)
	_lola.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lola)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.957, 1)
	style.set_border_width_all(6)
	style.border_color = INK
	style.set_corner_radius_all(30)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 10
	style.content_margin_bottom = 14
	_label.add_theme_stylebox_override("normal", style)
	_label.add_theme_font_size_override("font_size", 46)
	_label.add_theme_color_override("font_color", INK)
	_label.position = Vector2(215, 50)
	add_child(_label)
	_update_label()
	resized.connect(_layout)
	_layout()
	Sfx.play("whoosh")


func _layout() -> void:
	var vs := get_viewport_rect().size
	_center = Vector2(vs.x * 0.5, vs.y * 0.52)
	var shrink := 1.0 - 0.45 * _caught / float(GOAL)
	_tornado.position = _center
	_tornado.scale = Vector2.ONE * minf(vs.x * 0.95 / _tornado_size.x, vs.y * 0.9 / _tornado_size.y) * shrink
	_box.position = Vector2(vs.x - 190, vs.y - 120)
	_box.scale = Vector2.ONE * 0.75


func _update_label() -> void:
	if _caught == 0:
		_label.text = "Catch the toys flying out of the tornado!"
	else:
		_label.text = "Caught %d of %d!" % [mini(_caught, GOAL), GOAL]


func _process(delta: float) -> void:
	_spin += delta
	var vs := get_viewport_rect().size
	var shrink := 1.0 - 0.45 * _caught / float(GOAL)
	# the swirl leans and stretches so it looks like it's spinning
	_tornado.skew = sin(_spin * 2.2) * 0.08
	_tornado.rotation = sin(_spin * 1.3) * 0.03
	for t in _toys:
		if t.done:
			continue
		t.angle += delta * t.speed * 1.6
		var w: float = vs.x * 0.36 * t.radius * shrink
		var h: float = vs.y * 0.12 * shrink
		var depth := sin(t.angle)
		var p := _center + Vector2(cos(t.angle) * w, vs.y * t.height * shrink + depth * h)
		t.node.position = p
		t.node.scale = Vector2.ONE * (0.55 + 0.25 * depth) * clampf(vs.y / 1080.0, 0.6, 1.4)
		t.node.rotation = t.angle * 0.6
		t.node.z_index = 2 if depth > 0 else -1
		t.node.modulate.a = 1.0 if depth > -0.6 else 0.75


func _gui_input(event: InputEvent) -> void:
	if _over:
		return
	var pressed: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if not pressed:
		return
	var best = null
	var best_d := INF
	for t in _toys:
		if t.done:
			continue
		var s: Sprite2D = t.node
		var r := maxf(s.texture.get_width(), s.texture.get_height()) * s.scale.x * 0.5 + 40.0
		var d := s.position.distance_to(event.position)
		if d < r and d < best_d:
			best = t
			best_d = d
	if best:
		_catch(best)


func _catch(t: Dictionary) -> void:
	t.done = true
	_caught += 1
	_update_label()
	var s: Sprite2D = t.node
	s.z_index = 5
	Sfx.play("pop")
	_sparkle(s.position, 4)
	var start := s.position
	var end := _box.position + Vector2(0, -40)
	var arc := func(k: float) -> void:
		s.position = start.lerp(end, k) + Vector2(0, -260 * 4.0 * k * (1.0 - k))
		s.scale = Vector2.ONE * lerpf(0.7, 0.25, k)
		s.rotation = lerpf(s.rotation, 0.0, k)
	var tw := create_tween()
	tw.tween_method(arc, 0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE)
	tw.tween_property(s, "modulate:a", 0.0, 0.1)
	tw.tween_callback(_land)
	var shrink := create_tween()
	shrink.tween_method(func(_v): _layout(), 0.0, 1.0, 0.3)
	if _caught == GOAL / 2:
		_lola.texture = preload("res://assets/ui/lola_happy.png")
	if _caught >= GOAL:
		_win()


func _land() -> void:
	Sfx.play("plop")
	var tw := create_tween()
	tw.tween_property(_box, "scale", Vector2(0.8, 0.7), 0.08)
	tw.tween_property(_box, "scale", Vector2.ONE * 0.75, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _win() -> void:
	_over = true
	await get_tree().create_timer(0.7).timeout
	for t in _toys:
		if not t.done:
			t.done = true
			create_tween().tween_property(t.node, "modulate:a", 0.0, 0.4)
	Sfx.play("sparkle")
	var tw := create_tween().set_parallel()
	tw.tween_property(_tornado, "scale", Vector2.ZERO, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(_tornado, "rotation", TAU * 2, 0.7)
	for i in 8:
		_puff(_center + Vector2(randf_range(-200, 200), randf_range(-200, 200)))
	_lola.texture = preload("res://assets/ui/lola_joy.png")
	_label.text = "Phew! The tornado's gone... but the room is still a mess!"
	await get_tree().create_timer(3.2).timeout
	finished.emit()


func _sparkle(at: Vector2, n: int) -> void:
	for i in n:
		var s := Sprite2D.new()
		s.texture = TEX_SPARKLE
		s.position = at
		s.z_index = 10
		s.scale = Vector2.ZERO
		add_child(s)
		var tw := create_tween().set_parallel()
		tw.tween_property(s, "position", at + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(60, 140), 0.5)
		tw.tween_property(s, "scale", Vector2.ONE * randf_range(0.4, 0.8), 0.2)
		tw.tween_property(s, "modulate:a", 0.0, 0.3).set_delay(0.25)
		tw.chain().tween_callback(s.queue_free)


func _puff(at: Vector2) -> void:
	var p := Sprite2D.new()
	p.texture = TEX_PUFF
	p.position = at
	p.z_index = 10
	p.scale = Vector2(0.4, 0.4)
	add_child(p)
	var tw := create_tween().set_parallel()
	tw.tween_property(p, "scale", Vector2(1.2, 1.2), 0.5)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(p.queue_free)

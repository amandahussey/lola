extends CanvasLayer
## Close-up folding: the garment fills the screen and the player folds it in three swipes.
##   swipe left  -> the right side folds over
##   swipe right -> the left side folds over
##   swipe up    -> the bottom folds up
## Emits `folded` with the folded image so the room can carry it to the dresser drawer.

signal folded(image: Image, screen_pos: Vector2, screen_scale: float)
signal cancelled

const STEPS := ["left", "right", "up"]
const PROMPTS := {"left": "Swipe left to fold!", "right": "Now swipe right!", "up": "Swipe up!"}
const ARROW_ANGLE := {"left": PI, "right": 0.0, "up": -PI / 2}
const TEX_ARROW := preload("res://assets/ui/arrow.png")
const NedHelper := preload("res://scripts/ned_helper.gd")
const NED_LINES := {
	"left": "Fold one side over. Swipe left!",
	"right": "Now the other side!",
	"up": "Last one! Swipe up!",
}
const TEX_SPARKLE := preload("res://assets/ui/sparkle.png")
const INK := Color(0.149, 0.102, 0.18)
const BACK_SIDE := Color(0.84, 0.82, 0.9)  # the underside of the fabric is a little darker
const MIN_SWIPE := 60.0

@onready var _card: Panel = %Card
@onready var _prompt: Label = %Prompt
@onready var _dots: HBoxContainer = %Dots
@onready var _close: Button = %CloseButton

var _img: Image
var _step := 0
var _busy := true
var _holder := Node2D.new()
var _sprite := Sprite2D.new()
var _arrow := Sprite2D.new()
var _ned := NedHelper.new()
var _arrow_tween: Tween
var _touch_start := Vector2.ZERO
var _tracking := false


func setup(closeup: Texture2D) -> void:
	_img = closeup.get_image()
	if _img.is_compressed():
		_img.decompress()
	_img.convert(Image.FORMAT_RGBA8)
	_img = _img.get_region(_img.get_used_rect())


func _ready() -> void:
	_close.pressed.connect(_on_close)
	add_child(_holder)
	_holder.add_child(_sprite)
	_sprite.texture = ImageTexture.create_from_image(_img)
	_arrow.texture = TEX_ARROW
	_arrow.modulate.a = 0.0
	add_child(_arrow)
	_ned.texture = preload("res://assets/ui/ned_full.png")  # Ned holding folded clothes
	_ned.ned_height = 680.0
	_ned.peek = 560.0
	_ned.bubble_width = 300.0
	_ned.bubble_above = true
	add_child(_ned)
	await get_tree().process_frame
	var card := _card.get_global_rect()
	var area := Vector2(card.size.x * 0.8, card.size.y * 0.62)
	var fit := minf(area.x / _img.get_width(), area.y / _img.get_height())
	fit = minf(fit, 2.5)
	_holder.position = card.get_center() + Vector2(0, 10)
	_holder.scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(_holder, "scale", Vector2(fit, fit), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	_busy = false
	_show_step()


func _show_step() -> void:
	var dir: String = STEPS[_step]
	_prompt.text = PROMPTS[dir]
	_ned.say(NED_LINES[dir], 0.0, "left")
	for i in _dots.get_child_count():
		var dot: Panel = _dots.get_child(i)
		dot.self_modulate = Color(0.62, 0.42, 0.85) if i < _step else Color.WHITE
	# A big arrow slides across the garment in the swipe direction.
	var v := Vector2.RIGHT.rotated(ARROW_ANGLE[dir])
	var reach := 140.0
	_arrow.rotation = ARROW_ANGLE[dir]
	if _arrow_tween:
		_arrow_tween.kill()
	_arrow_tween = create_tween().set_loops()
	_arrow_tween.tween_callback(func(): _arrow.position = _holder.position - v * reach)
	_arrow_tween.tween_property(_arrow, "modulate:a", 0.95, 0.15)
	_arrow_tween.tween_property(_arrow, "position", _holder.position + v * reach, 0.7).set_trans(Tween.TRANS_SINE)
	_arrow_tween.tween_property(_arrow, "modulate:a", 0.0, 0.2)
	_arrow_tween.tween_interval(0.35)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		get_viewport().set_input_as_handled()
		if event.pressed:
			if _close.get_global_rect().grow(10).has_point(event.position):
				return
			_touch_start = event.position
			_tracking = true
		elif _tracking:
			_tracking = false
			_evaluate(event.position - _touch_start)
	elif event is InputEventScreenDrag:
		get_viewport().set_input_as_handled()
		if _tracking and (event.position - _touch_start).length() > MIN_SWIPE * 1.6:
			_tracking = false
			_evaluate(event.position - _touch_start)


func _evaluate(swipe: Vector2) -> void:
	if _busy:
		return
	if swipe.length() < MIN_SWIPE:
		_nudge()
		return
	var dir := ""
	if absf(swipe.x) > absf(swipe.y):
		dir = "left" if swipe.x < 0 else "right"
	else:
		dir = "up" if swipe.y < 0 else "down"
	if dir == STEPS[_step]:
		fold(dir)
	else:
		_nudge()


## Wrong way (or just a tap): wiggle and repeat the instruction.
func _nudge() -> void:
	Sfx.play("boop")
	_ned.say("Oops! Try the way the arrow goes.", 0.0, "left")
	var tw := create_tween()
	for a in [0.06, -0.05, 0.03, 0.0]:
		tw.tween_property(_holder, "rotation", a, 0.06)
	var flash := create_tween()
	flash.tween_property(_prompt, "scale", Vector2(1.08, 1.08), 0.08)
	flash.tween_property(_prompt, "scale", Vector2.ONE, 0.15)
	_prompt.pivot_offset = _prompt.size / 2


## Folds the current image along one line, animating the flap flipping over.
func fold(dir: String) -> void:
	_busy = true
	if _arrow_tween:
		_arrow_tween.kill()
	_arrow.modulate.a = 0.0
	Sfx.play("fold")
	var w := _img.get_width()
	var h := _img.get_height()
	var keep: Rect2i
	var flap: Rect2i
	var dst := Vector2i.ZERO  # where the flipped flap lands, in `keep` coordinates
	match dir:
		"left":
			var fx := int(ceil(w * 2.0 / 3.0))
			keep = Rect2i(0, 0, fx, h)
			flap = Rect2i(fx, 0, w - fx, h)
			dst = Vector2i(fx - flap.size.x, 0)
		"right":
			var fx := int(floor(w / 2.0))
			keep = Rect2i(fx, 0, w - fx, h)
			flap = Rect2i(0, 0, fx, h)
		"up":
			var fy := int(ceil(h / 2.0))
			keep = Rect2i(0, 0, w, fy)
			flap = Rect2i(0, fy, w, h - fy)
			dst = Vector2i(0, fy - flap.size.y)
	var half := Vector2(w, h) / 2.0

	# --- animate: keep-part stays, flap swings over the fold line ---
	var keep_sprite := Sprite2D.new()
	keep_sprite.texture = ImageTexture.create_from_image(_img.get_region(keep))
	keep_sprite.centered = false
	keep_sprite.position = Vector2(keep.position) - half
	var flap_sprite := Sprite2D.new()
	flap_sprite.texture = ImageTexture.create_from_image(_img.get_region(flap))
	flap_sprite.centered = false
	match dir:
		"left":
			flap_sprite.position = Vector2(flap.position) - half
		"right":
			flap_sprite.position = Vector2(flap.end.x, 0) - half
			flap_sprite.offset = Vector2(-flap.size.x, 0)
		"up":
			flap_sprite.position = Vector2(flap.position) - half
	_sprite.visible = false
	_holder.add_child(keep_sprite)
	_holder.add_child(flap_sprite)
	var vertical := dir == "up"
	var swing := func(t: float) -> void:
		var s := cos(PI * t)
		var bulge := 1.0 + 0.12 * sin(PI * t)  # the flap lifts toward you as it turns
		flap_sprite.scale = Vector2(bulge, s) if vertical else Vector2(s, bulge)
		flap_sprite.modulate = Color.WHITE if t < 0.5 else BACK_SIDE
	var tw := create_tween()
	tw.tween_method(swing, 0.0, 1.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished

	# --- bake the result into a new image ---
	var base := _img.get_region(keep)
	var back := _img.get_region(flap)
	if vertical:
		back.flip_y()
	else:
		back.flip_x()
	back.adjust_bcs(0.84, 1.0, 0.95)
	base.blend_rect(back, Rect2i(Vector2i.ZERO, back.get_size()), dst)
	_draw_crease(base, dir, dst, back.get_size())
	var used := base.get_used_rect()
	_img = base.get_region(used)
	keep_sprite.queue_free()
	flap_sprite.queue_free()
	_sprite.texture = ImageTexture.create_from_image(_img)
	_sprite.position = Vector2(keep.position + used.position) + Vector2(used.size) / 2.0 - half
	_sprite.visible = true
	var settle := create_tween()
	settle.tween_property(_sprite, "position", Vector2.ZERO, 0.25).set_trans(Tween.TRANS_SINE)
	_sparkle(_holder.position, 3)

	_step += 1
	if _step < STEPS.size():
		await settle.finished
		_busy = false
		_show_step()
	else:
		_finish()


## A dark line along the folded edge so the fold reads clearly.
func _draw_crease(img: Image, dir: String, at: Vector2i, size: Vector2i) -> void:
	var w := img.get_width()
	var h := img.get_height()
	match dir:
		"left":
			for y in h:
				for x in range(at.x + size.x - 4, at.x + size.x):
					if x >= 0 and x < w and img.get_pixel(x, y).a > 0.5:
						img.set_pixel(x, y, INK)
		"right":
			for y in h:
				for x in range(0, 4):
					if x < w and img.get_pixel(x, y).a > 0.5:
						img.set_pixel(x, y, INK)
		"up":
			for y in range(at.y + size.y - 4, at.y + size.y):
				for x in w:
					if y >= 0 and y < h and img.get_pixel(x, y).a > 0.5:
						img.set_pixel(x, y, INK)


func _finish() -> void:
	for dot in _dots.get_children():
		dot.self_modulate = Color(0.62, 0.42, 0.85)
	_prompt.text = "Neatly folded!"
	_ned.say("Perfect fold! Just like I do it.", 0.0, "left")
	Sfx.play("sparkle", 0.0, -6.0)
	_sparkle(_holder.position, 10)
	var pop := create_tween()
	pop.tween_property(_sprite, "scale", Vector2(1.15, 1.15), 0.12)
	pop.tween_property(_sprite, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.8).timeout
	folded.emit(_img, _holder.position + _sprite.position * _holder.scale.x, _holder.scale.x)
	queue_free()


func _on_close() -> void:
	if _step > 0 and _busy:
		return
	Sfx.play("pop")
	cancelled.emit()
	queue_free()


func _sparkle(at: Vector2, count: int) -> void:
	for i in count:
		var s := Sprite2D.new()
		s.texture = TEX_SPARKLE
		s.position = at
		s.scale = Vector2.ZERO
		add_child(s)
		var dir := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(120, 300)
		var size := randf_range(0.4, 0.9)
		var tw := create_tween().set_parallel()
		tw.tween_property(s, "position", at + dir, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "scale", Vector2(size, size), 0.2)
		tw.tween_property(s, "modulate:a", 0.0, 0.3).set_delay(0.3)
		tw.chain().tween_callback(s.queue_free)

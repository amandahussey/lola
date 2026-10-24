extends Control
## Plays one stretch of the storybook: a list of beats from story_script.gd.
## Each book page is rebuilt from its Procreate layers (grouped into parts that can move),
## shown on the left like the picture side of a book, with the words on the right.
## Tap anywhere (or Next) to turn to the next line. Narration plays when a recording exists.

signal finished

const PAGES := "res://assets/story/pages/pages.json"
const INK := Color(0.149, 0.102, 0.18)
const PAPER := Color(0.98, 0.957, 1)
const FONT_TITLE := preload("res://assets/fonts/Sniglet-ExtraBold.ttf")
const TEX_SPARKLE := preload("res://assets/ui/sparkle.png")
const TEX_GLOW := preload("res://assets/ui/glow.png")
const SPEAKERS := {
	"lola": preload("res://assets/ui/lola_happy.png"),
	"lola_worried": preload("res://assets/ui/lola_worried.png"),
	"lola_joy": preload("res://assets/ui/lola_joy.png"),
	"ned": preload("res://assets/ui/ned_badge.png"),
	"grandpa": preload("res://assets/ui/grandpa_badge.png"),
}
const NAMES := {"lola": "Lola", "lola_worried": "Lola", "lola_joy": "Lola", "ned": "Ned", "grandpa": "Grandpa"}

static var _pages: Dictionary

var _beats: Array = []
var _i := -1
var _bg := ColorRect.new()
var _stage := Control.new()       # the picture side
var _art := Node2D.new()          # page art in page pixels, scaled to fit the stage
var _parts := {}                  # part name -> Node2D (pivot at its bottom centre)
var _page_id := ""
var _page_size := Vector2(1000, 1250)
var _panel := PanelContainer.new()  # the words side
var _col := VBoxContainer.new()
var _row := HBoxContainer.new()
var _spread := false
var _speaker := TextureRect.new()
var _speaker_name := Label.new()
var _text := Label.new()
var _next := Button.new()
var _chapter := Label.new()
var _voice := AudioStreamPlayer.new()
var _waiting := ""                # "tap" (next line), "part" (tap something in the picture), ""
var _wait_part := ""
var _ready_at := 0
var _idle_tweens: Array[Tween] = []
var _rub := {}      # the thing being rubbed clean, its fog and how much is clean
var _hops := {}     # who is hopping, and the steps left
var _spots: Array = []  # places to search on this page
var _busy := false
var _focus_rect := Rect2()  # part of the page to zoom in on (page pixels)
var _focus_t := 0.0


func setup(beats: Array) -> void:
	_beats = beats


func _ready() -> void:
	if _pages.is_empty():
		_pages = JSON.parse_string(FileAccess.get_file_as_string(PAGES))
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.color = Color(0.467, 0.349, 0.592)
	add_child(_bg)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.clip_contents = true
	add_child(_stage)
	_stage.add_child(_art)
	_build_panel()
	_chapter.add_theme_font_override("font", FONT_TITLE)
	_chapter.add_theme_font_size_override("font_size", 96)
	_chapter.add_theme_color_override("font_color", PAPER)
	_chapter.add_theme_color_override("font_outline_color", INK)
	_chapter.add_theme_constant_override("outline_size", 24)
	_chapter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chapter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_chapter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_chapter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chapter.modulate.a = 0.0
	add_child(_chapter)
	add_child(_voice)
	_voice.finished.connect(_on_voice_done)
	resized.connect(_layout)
	_layout()
	_step()


func _build_panel() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.set_border_width_all(7)
	style.border_width_bottom = 11
	style.border_color = INK
	style.set_corner_radius_all(40)
	style.content_margin_left = 44
	style.content_margin_right = 44
	style.content_margin_top = 36
	style.content_margin_bottom = 30
	_panel.add_theme_stylebox_override("panel", style)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_col.add_theme_constant_override("separation", 14)
	_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_col)
	# [portrait] [name / words] [Next, on spreads]  - with Next underneath on single pages
	_row.add_theme_constant_override("separation", 24)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_col.add_child(_row)
	_speaker.custom_minimum_size = Vector2(120, 120)
	_speaker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_speaker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_speaker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(_speaker)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(words)
	_speaker_name.add_theme_font_override("font", FONT_TITLE)
	_speaker_name.add_theme_font_size_override("font_size", 40)
	_speaker_name.add_theme_color_override("font_color", Color(0.45, 0.29, 0.62))
	words.add_child(_speaker_name)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 52)
	_text.add_theme_color_override("font_color", INK)
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(_text)
	_next.text = "Next  >"
	_next.size_flags_horizontal = Control.SIZE_SHRINK_END
	_next.size_flags_vertical = Control.SIZE_SHRINK_END
	_next.custom_minimum_size = Vector2(240, 0)
	_next.pressed.connect(_advance)
	_col.add_child(_next)
	_panel.modulate.a = 0.0
	add_child(_panel)


## A single page fills the left side with the words on the right, like an open book.
## A two-page spread fills the screen and the words sit in a caption box along the bottom.
func _layout() -> void:
	var vs := size
	if vs.x <= 0:
		vs = get_viewport_rect().size
	var margin := 28.0
	_spread = _page_size.x / _page_size.y > 1.2
	var pic: Rect2
	var band := clampf(vs.y * 0.25, 220.0, 330.0)  # room for the words under a spread
	if _spread:
		pic = Rect2(margin, margin * 0.6, vs.x - margin * 2, vs.y - band - margin * 1.2)
	else:
		var pic_w := minf(vs.x * 0.6, (vs.y - margin * 2) * _page_size.x / _page_size.y)
		pic = Rect2(margin, margin, pic_w, vs.y - margin * 2)
	_stage.position = pic.position
	_stage.size = pic.size
	var fit := minf(pic.size.x / _page_size.x, pic.size.y / _page_size.y)
	_art.scale = Vector2(fit, fit)
	_art.position = (pic.size - _page_size * fit) / 2
	if _focus_rect.size != Vector2.ZERO:
		# zoomed in on one thing (like the mirror while it's being rubbed)
		var zf := minf(pic.size.x * 0.8 / _focus_rect.size.x, pic.size.y * 0.8 / _focus_rect.size.y)
		var zp := pic.size / 2 - _focus_rect.get_center() * zf
		_art.scale = Vector2.ONE * lerpf(fit, zf, _focus_t)
		_art.position = _art.position.lerp(zp, _focus_t)
	var next_parent: BoxContainer = _row if _spread else _col
	if _next.get_parent() != next_parent:
		_next.reparent(next_parent)
	if _spread:
		var w := minf(_page_size.x * fit + 40.0, vs.x - margin * 2)
		_panel.custom_minimum_size = Vector2(w, band - margin * 1.2)
		_panel.size = _panel.custom_minimum_size
		_panel.position = Vector2((vs.x - w) / 2, vs.y - band + margin * 0.2)
	else:
		var px := pic.end.x + margin * 1.5
		_panel.custom_minimum_size = Vector2.ZERO
		_panel.position = Vector2(px, vs.y * 0.2)
		_panel.size = Vector2(vs.x - px - margin * 1.5, vs.y * 0.6)


# ------------------------------------------------------------------ beats

func _step() -> void:
	_i += 1
	if _i >= _beats.size():
		_end()
		return
	var b: Dictionary = _beats[_i]
	if b.has("chapter"):
		await _show_chapter(b.chapter)
		_step()
	elif b.has("page"):
		await _show_page(b)
		_step()
	elif b.has("text") or b.has("say"):
		_show_words(b)
	elif b.has("show"):
		_reveal(b.show, b.get("anim", "pop"))
		await _pause(b.get("wait", 0.35))
		_step()
	elif b.has("hide"):
		var p: Node2D = _parts.get(b.hide)
		if p:
			var tw := create_tween()
			tw.tween_property(p, "modulate:a", 0.0, b.get("time", 0.3))
		await _pause(b.get("wait", 0.3))
		_step()
	elif b.has("act"):
		_act(b.act, b.do, b)
		await _pause(b.get("wait", 0.0))
		_step()
	elif b.has("tap"):
		_ask_tap(b)
	elif b.has("rub"):
		_start_rub(b)
	elif b.has("hop"):
		_start_hops(b)
	elif b.has("spots"):
		_start_spots(b)
	elif b.has("screen"):
		await _screen(b.screen)
		_step()
	elif b.has("sfx"):
		Sfx.play(b.sfx)
		_step()
	elif b.has("wait"):
		await _pause(b.wait)
		_step()
	else:
		push_warning("story beat not understood: %s" % b)
		_step()


func _pause(t: float) -> void:
	if t > 0.0:
		await get_tree().create_timer(t).timeout


func _end() -> void:
	_voice.stop()
	finished.emit()


## Big chapter title over the page colour.
func _show_chapter(title: String) -> void:
	_clear_page()
	var tw := create_tween()
	tw.tween_property(_panel, "modulate:a", 0.0, 0.2)
	_chapter.text = title
	_chapter.scale = Vector2(0.8, 0.8)
	_chapter.pivot_offset = get_viewport_rect().size / 2
	var t2 := create_tween().set_parallel()
	t2.tween_property(_chapter, "modulate:a", 1.0, 0.4)
	t2.tween_property(_chapter, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("sparkle", 0.0, -6.0)
	await get_tree().create_timer(2.2).timeout
	var t3 := create_tween()
	t3.tween_property(_chapter, "modulate:a", 0.0, 0.4)
	await t3.finished


func _clear_page() -> void:
	for t in _idle_tweens:
		t.kill()
	_idle_tweens.clear()
	for c in _art.get_children():
		c.queue_free()
	_parts.clear()


## Turns to a book page, or a two-page spread ("page": [3, 4]) shown as one scene.
## Parts listed in "hidden" wait for a "show" beat; the rest pop in one after another,
## so the picture draws itself. A part name used on both pages of a spread is the left
## page's; the right page's is "<page>.<part>" (e.g. "14.lola").
func _show_page(b: Dictionary) -> void:
	var ids: Array = b.page if b.page is Array else [b.page]
	var out := create_tween().set_parallel()
	out.tween_property(_art, "modulate:a", 0.0, 0.25)
	await out.finished
	_clear_page()
	_page_id = "-".join(ids.map(func(i): return str(i)))
	var x := 0.0
	var order: Array = []
	for id in ids:
		var page: Dictionary = _pages[str(id)]
		for c in page.chunks:
			var tex: Texture2D = load(c.tex)
			var center := Vector2(c.pos[0] + x, c.pos[1])
			var key: String = c.part
			if _parts.has(key):
				key = "%s.%s" % [id, c.part]
			var root := Node2D.new()
			root.name = key.replace(".", "_")
			root.set_meta("base", c.part.begins_with("base"))
			root.position = center + Vector2(0, tex.get_height() / 2.0)
			var inner := Node2D.new()
			inner.name = "Inner"
			inner.position = Vector2(0, -tex.get_height() / 2.0)
			root.add_child(inner)
			var spr := Sprite2D.new()
			spr.texture = tex
			inner.add_child(spr)
			_art.add_child(root)
			_parts[key] = root
			_parts["%s.%s" % [id, c.part]] = root
			order.append(key)
		x += page.size[0]
	var first: Dictionary = _pages[str(ids[0])]
	_page_size = Vector2(x, first.size[1])
	var bg: Array = first.bg
	create_tween().tween_property(_bg, "color", Color(bg[0], bg[1], bg[2]), 0.4)
	_layout()
	var hidden: Array = b.get("hidden", []).map(func(h): return _parts.get(h))
	for part in order:
		_parts[part].modulate.a = 0.0
	_art.modulate.a = 1.0
	var delay := 0.0
	for part in order:
		if _parts[part] in hidden:
			continue
		if _parts[part].get_meta("base"):
			create_tween().tween_property(_parts[part], "modulate:a", 1.0, 0.35)
		else:
			_reveal.call_deferred(part, "pop", delay)
			delay += 0.12
	for part in b.get("idle", {}):
		_idle(part, b.idle[part])
	await get_tree().create_timer(0.35 + delay).timeout


func _reveal(part: String, anim: String, delay := 0.0) -> void:
	var p: Node2D = _parts.get(part)
	if p == null:
		push_warning("no part %s on page %s" % [part, _page_id])
		return
	var tw := create_tween().set_parallel()
	match anim:
		"fade":
			tw.tween_property(p, "modulate:a", 1.0, 0.45).set_delay(delay)
		"drop":
			var home := p.position
			p.position = home + Vector2(0, -_page_size.y * 0.5)
			tw.tween_property(p, "modulate:a", 1.0, 0.1).set_delay(delay)
			tw.tween_property(p, "position", home, 0.5).set_delay(delay).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		"left", "right":
			var home2 := p.position
			p.position = home2 + Vector2(_page_size.x * (-0.6 if anim == "left" else 0.6), 0)
			tw.tween_property(p, "modulate:a", 1.0, 0.2).set_delay(delay)
			tw.tween_property(p, "position", home2, 0.6).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		"up":
			var home3 := p.position
			p.position = home3 + Vector2(0, _page_size.y * 0.5)
			tw.tween_property(p, "modulate:a", 1.0, 0.2).set_delay(delay)
			tw.tween_property(p, "position", home3, 0.6).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_:  # pop
			p.scale = Vector2(0.6, 0.6)
			tw.tween_property(p, "modulate:a", 1.0, 0.15).set_delay(delay)
			tw.tween_property(p, "scale", Vector2.ONE, 0.45).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## One-off movements on a part.
func _act(part: String, what: String, b: Dictionary) -> void:
	var p: Node2D = _parts.get(part)
	if p == null:
		push_warning("no part %s on page %s" % [part, _page_id])
		return
	var inner: Node2D = p.get_node("Inner")
	var tw := create_tween()
	match what:
		"hop":
			tw.tween_property(p, "scale", Vector2(1.1, 0.9), 0.08)
			tw.tween_property(p, "position:y", p.position.y - 60, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(p, "scale", Vector2(0.94, 1.08), 0.16)
			tw.tween_property(p, "position:y", p.position.y, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(p, "scale", Vector2.ONE, 0.16)
		"wiggle":
			for a in [0.12, -0.1, 0.07, -0.04, 0.0]:
				tw.tween_property(inner, "rotation", a, 0.08)
		"shake":
			for k in 8:
				tw.tween_property(inner, "position:x", inner.position.x + (14 if k % 2 == 0 else -14), 0.04)
			tw.tween_property(inner, "position:x", inner.position.x, 0.04)
		"spin":
			tw.tween_property(inner, "rotation", inner.rotation + TAU, b.get("time", 0.8)).set_trans(Tween.TRANS_SINE)
		"grow":
			tw.tween_property(p, "scale", Vector2.ONE * b.get("to", 1.2), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		"move":
			var by: Array = b.by
			tw.tween_property(p, "position", p.position + Vector2(by[0], by[1]), b.get("time", 0.6)).set_trans(Tween.TRANS_SINE)
		"tip":
			tw.tween_property(inner, "rotation", b.get("angle", -0.6), b.get("time", 0.35)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		"sparkle":
			for k in 3:
				tw.tween_callback(_sparkle_at.bind(p, 2))
				tw.tween_interval(0.2)
		"duck":
			tw.tween_property(p, "scale", Vector2(1.12, 0.78), 0.12).set_trans(Tween.TRANS_QUAD)
			tw.tween_interval(0.35)
			tw.tween_property(p, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Gentle looping life on a part while the page is up.
func _idle(part: String, what: String) -> void:
	var p: Node2D = _parts.get(part)
	if p == null:
		return
	var inner: Node2D = p.get_node("Inner")
	var tw := p.create_tween().set_loops()  # stops by itself when the page is cleared
	match what:
		"breathe":
			tw.tween_property(p, "scale", Vector2(1.015, 0.985), 1.1).set_trans(Tween.TRANS_SINE)
			tw.tween_property(p, "scale", Vector2.ONE, 1.1).set_trans(Tween.TRANS_SINE)
		"sway":
			tw.tween_property(inner, "rotation", 0.04, 1.3).set_trans(Tween.TRANS_SINE)
			tw.tween_property(inner, "rotation", -0.04, 1.3).set_trans(Tween.TRANS_SINE)
		"bob":
			tw.tween_property(inner, "position:y", inner.position.y - 18, 0.9).set_trans(Tween.TRANS_SINE)
			tw.tween_property(inner, "position:y", inner.position.y, 0.9).set_trans(Tween.TRANS_SINE)
		"spin":
			tw.tween_property(inner, "rotation", TAU, 2.5).from(0.0)
		"twinkle":
			tw.tween_property(p, "modulate", Color(1.25, 1.2, 1.3), 0.5).set_trans(Tween.TRANS_SINE)
			tw.tween_property(p, "modulate", Color.WHITE, 0.5).set_trans(Tween.TRANS_SINE)
			tw.tween_callback(_sparkle_at.bind(p, 1))
		"wave":
			tw.tween_property(inner, "rotation", 0.08, 0.35).set_trans(Tween.TRANS_SINE)
			tw.tween_property(inner, "rotation", -0.04, 0.35).set_trans(Tween.TRANS_SINE)
	_idle_tweens.append(tw)


func _screen(what: String) -> void:
	match what:
		"shake":
			var tw := create_tween()
			for k in 10:
				tw.tween_property(_stage, "position", _stage.position + Vector2(randf_range(-24, 24), randf_range(-18, 18)), 0.035)
			tw.tween_callback(_layout)
			await tw.finished
		"flash":
			var f := ColorRect.new()
			f.color = Color(1, 1, 1, 0.85)
			f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			f.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(f)
			var tw2 := create_tween()
			tw2.tween_property(f, "color:a", 0.0, 0.35)
			tw2.tween_callback(f.queue_free)
			await tw2.finished


# ------------------------------------------------------------------ words

## A line of the story (narrator) or something a character says, with their portrait.
func _show_words(b: Dictionary) -> void:
	var who: String = b.get("who", "")
	_speaker.visible = SPEAKERS.has(who)
	_speaker_name.visible = SPEAKERS.has(who)
	if SPEAKERS.has(who):
		_speaker.texture = SPEAKERS[who]
		_speaker_name.text = NAMES[who]
		_text.text = "“%s”" % b.say
	else:
		_text.text = b.get("text", b.get("say", ""))
	var font_size: float = b.get("size", 52)
	if _spread:
		# the caption strip under a spread is short: fit the lines into it
		var lines := _text.text.count("\n") + 1
		var room := clampf(get_viewport_rect().size.y * 0.25, 220.0, 330.0) - 100.0
		font_size = minf(font_size * 0.8, room / (lines * 1.3))
	_text.add_theme_font_size_override("font_size", int(font_size))
	_layout()
	_panel.pivot_offset = _panel.size / 2
	_panel.scale = Vector2(0.97, 0.97)
	var tw := create_tween().set_parallel()
	tw.tween_property(_panel, "modulate:a", 1.0, 0.2)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if who != "" and _parts.has(b.get("part", who)):
		_act(b.get("part", who), "hop", {})
	_next.visible = true
	_ready_at = Time.get_ticks_msec() + 500
	_waiting = "tap"
	_voice.stop()
	var line := Narration.find(b.get("voice", ""))
	if line:
		_voice.stream = line
		_voice.play()


func _on_voice_done() -> void:
	if _waiting == "tap":
		await get_tree().create_timer(0.9).timeout
		if _waiting == "tap" and not _voice.playing:
			_advance()


func _advance() -> void:
	if _waiting != "tap" or Time.get_ticks_msec() < _ready_at:
		return
	_waiting = ""
	_voice.stop()
	Sfx.play("pop", 0.08, -8.0)
	_step()


## Waits for the player to tap something in the picture (it glows and sparkles).
func _ask_tap(b: Dictionary) -> void:
	_wait_part = b.tap
	_waiting = "part"
	_next.visible = false
	if b.has("prompt"):
		_prompt(b.prompt)
	var p: Node2D = _parts.get(_wait_part)
	if p == null:
		_waiting = ""
		_step()
		return
	if p.modulate.a < 0.5:
		_reveal(_wait_part, "pop")
	var glow := Sprite2D.new()
	glow.name = "TapGlow"
	glow.texture = TEX_GLOW
	glow.modulate = Color(1, 0.95, 0.7, 0.0)
	var r := _part_rect(p)
	glow.scale = Vector2.ONE * maxf(r.size.x, r.size.y) / 200.0
	glow.show_behind_parent = true
	p.get_node("Inner").add_child(glow)
	var tw := glow.create_tween().set_loops()  # ends with the glow when it's tapped
	tw.tween_property(glow, "modulate:a", 0.9, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(glow, "modulate:a", 0.25, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_sparkle_at.bind(p, 1))


func _part_rect(p: Node2D) -> Rect2:
	var r := Rect2()
	var first := true
	for s in p.get_node("Inner").get_children():
		if s is Sprite2D and s.name != "TapGlow":
			var sr := Rect2(s.position - s.texture.get_size() / 2, s.texture.get_size())
			r = sr if first else r.merge(sr)
			first = false
	return r


func _gui_input(event: InputEvent) -> void:
	if _waiting == "rub":
		_rub_input(event)
		return
	var pressed: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if not pressed:
		return
	if _waiting == "hop":
		_hop()
	elif _waiting == "spots":
		_search(_art.get_global_transform_with_canvas().affine_inverse() * event.position)
	elif _waiting == "tap":
		_advance()
	elif _waiting == "part":
		var p: Node2D = _parts.get(_wait_part)
		var local: Vector2 = (p.get_node("Inner") as Node2D).get_global_transform_with_canvas().affine_inverse() * event.position
		if _part_rect(p).grow(60).has_point(local):
			_waiting = ""
			var g := p.get_node_or_null("Inner/TapGlow")
			if g:
				g.queue_free()
			Sfx.play("sparkle")
			_sparkle_at(p, 6)
			_act(_wait_part, "hop", {})
			await get_tree().create_timer(0.5).timeout
			_step()


func _sparkle_at(p: Node2D, count: int) -> void:
	var r := _part_rect(p)
	for i in count:
		var s := Sprite2D.new()
		s.texture = TEX_SPARKLE
		s.position = p.get_node("Inner").position + p.position + r.get_center() + Vector2(randf_range(-0.5, 0.5) * r.size.x, randf_range(-0.5, 0.5) * r.size.y)
		s.scale = Vector2.ZERO
		s.modulate = [Color(1, 1, 1), Color(1, 0.9, 0.6), Color(0.9, 0.8, 1)][i % 3]
		_art.add_child(s)
		var size := randf_range(0.6, 1.3)
		var tw := create_tween()
		tw.tween_property(s, "scale", Vector2(size, size), 0.2)
		tw.parallel().tween_property(s, "rotation", randf_range(-1.5, 1.5), 0.5)
		tw.tween_property(s, "modulate:a", 0.0, 0.3)
		tw.tween_callback(s.queue_free)


# ------------------------------------------------------------------ little games inside a page

## Shows an instruction (or a character's line) in the words box, without a Next button.
func _prompt(text: String, who := "") -> void:
	_speaker.visible = SPEAKERS.has(who)
	_speaker_name.visible = SPEAKERS.has(who)
	if SPEAKERS.has(who):
		_speaker.texture = SPEAKERS[who]
		_speaker_name.text = NAMES[who]
		text = "\u201c%s\u201d" % text
	_text.text = text
	_text.add_theme_font_size_override("font_size", 46 if _spread else 50)
	_next.visible = false
	_layout()
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.2)


## {rub = "mirror", tool = "rag", reveal = "reflection"}: the part is fogged up; rub it with
## a finger (the tool follows along) until it's clean. The reveal part fades in as it clears.
func _start_rub(b: Dictionary) -> void:
	var p: Node2D = _parts[b.rub]
	var r := _part_rect(p)
	var fw := maxi(8, int(r.size.x / 4))
	var fh := maxi(8, int(r.size.y / 4))
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.04
	var fog := Image.create(fw, fh, false, Image.FORMAT_RGBA8)
	for y in fh:
		for x in fw:
			var n := noise.get_noise_2d(x, y) * 0.5 + 0.5
			fog.set_pixel(x, y, Color(0.93, 0.92, 0.97, 0.55 + 0.4 * n))
	var mask := Image.create(maxi(4, fw / 2), maxi(4, fh / 2), false, Image.FORMAT_L8)
	var mask_tex := ImageTexture.create_from_image(mask)
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = """
shader_type canvas_item;
uniform sampler2D clean : filter_linear;
void fragment() {
	COLOR.a *= 1.0 - smoothstep(0.15, 0.85, texture(clean, UV).r);
}
"""
	mat.set_shader_parameter("clean", mask_tex)
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(fog)
	sprite.scale = r.size / Vector2(fw, fh)
	sprite.position = r.get_center()
	sprite.material = mat
	p.get_node("Inner").add_child(sprite)
	sprite.modulate.a = 0.0
	create_tween().tween_property(sprite, "modulate:a", 1.0, 0.4)
	_rub = {"part": p, "rect": r, "fog": sprite, "mask": mask, "tex": mask_tex, "clean": 0,
		"tool": _parts.get(b.get("tool", "")), "reveal": _parts.get(b.get("reveal", "")),
		"down": false, "goal": b.get("goal", 0.7)}
	if _rub.reveal:
		_rub.reveal.modulate.a = 0.0
	_prompt(b.get("prompt", "Rub it clean!"))
	await _zoom(Rect2(p.position + p.get_node("Inner").position + r.position, r.size), true)
	_waiting = "rub"


func _rub_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_rub.down = event.pressed
		if event.pressed:
			_rub_at(event.position)
	elif event is InputEventMouseMotion and _rub.down:
		_rub_at(event.position)


func _rub_at(screen: Vector2) -> void:
	var p: Node2D = _rub.part
	var local: Vector2 = p.get_node("Inner").get_global_transform_with_canvas().affine_inverse() * screen
	var tool: Node2D = _rub.tool
	if tool:
		var art_pos: Vector2 = _art.get_global_transform_with_canvas().affine_inverse() * screen
		var h := _part_rect(tool).size.y
		tool.position = art_pos + Vector2(0, h / 2)
	var r: Rect2 = _rub.rect
	var mask: Image = _rub.mask
	var c := (local - r.position) / r.size * Vector2(mask.get_size())
	var rad := mask.get_width() * 0.14
	for y in range(maxi(0, floori(c.y - rad)), mini(mask.get_height(), ceili(c.y + rad))):
		for x in range(maxi(0, floori(c.x - rad)), mini(mask.get_width(), ceili(c.x + rad))):
			var d := Vector2(x, y).distance_to(c) / rad
			if d >= 1.0:
				continue
			var old := mask.get_pixel(x, y).r
			var v := maxf(old, minf(1.0, (1.0 - d) * 1.8))
			if v > old:
				mask.set_pixel(x, y, Color(v, v, v))
				if old < 0.5 and v >= 0.5:
					_rub.clean += 1
	_rub.tex.update(mask)
	var done: float = _rub.clean / float(mask.get_width() * mask.get_height())
	if _rub.reveal:
		_rub.reveal.modulate.a = clampf(done * 1.4, 0.0, 1.0)
	if Time.get_ticks_msec() % 250 < 20:
		Sfx.play("whoosh", 0.3, -16.0)
	if done >= _rub.goal and _waiting == "rub":
		_waiting = ""
		_finish_rub()


func _finish_rub() -> void:
	var tw := create_tween().set_parallel()
	tw.tween_property(_rub.fog, "modulate:a", 0.0, 0.4)
	if _rub.reveal:
		tw.tween_property(_rub.reveal, "modulate:a", 1.0, 0.4)
	Sfx.play("sparkle")
	_sparkle_at(_rub.part, 8)
	await tw.finished
	_rub.fog.queue_free()
	_rub = {}
	await get_tree().create_timer(0.4).timeout
	await _zoom(_focus_rect, false)
	_step()


## {hop = ["lola"], steps = [[dx, dy], ...]}: every tap hops them one step (down the stairs).
func _start_hops(b: Dictionary) -> void:
	_hops = {"who": b.hop, "steps": b.steps, "i": 0}
	_prompt(b.get("prompt", "Tap to hop!"))
	_waiting = "hop"


func _hop() -> void:
	if _busy:
		return
	_busy = true
	var step: Array = _hops.steps[_hops.i]
	_hops.i += 1
	Sfx.play("boop", 0.0, -4.0)
	var tw := create_tween().set_parallel()
	for name in _hops.who:
		var p: Node2D = _parts[name]
		var from := p.position
		var to := from + Vector2(step[0], step[1])
		var arc := func(k: float) -> void:
			p.position = from.lerp(to, k) + Vector2(0, -70.0 * 4.0 * k * (1.0 - k))
		tw.tween_method(arc, 0.0, 1.0, 0.32).set_trans(Tween.TRANS_SINE)
		tw.tween_property(p, "scale", Vector2(1.08, 0.92), 0.08).set_delay(0.32)
	await tw.finished
	for name in _hops.who:
		create_tween().tween_property(_parts[name], "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK)
	_busy = false
	var left: int = _hops.steps.size() - _hops.i
	if left > 0:
		_text.text = "%d more!" % left if left > 1 else "Last one!"
		return
	_waiting = ""
	Sfx.play("plop")
	await get_tree().create_timer(0.5).timeout
	_step()


## {spots = [{at = [x, y], r = 100, say = "...", who = "lola"} or {part = "ned", ...}]}:
## places in the picture to search; each one, when tapped, gets its own line.
func _start_spots(b: Dictionary) -> void:
	_spots = []
	for spot in b.spots:
		var s: Dictionary = spot.duplicate()
		var glow := Sprite2D.new()
		glow.texture = TEX_GLOW
		glow.modulate = Color(1, 0.95, 0.7, 0.0)
		if s.has("part"):
			var p: Node2D = _parts[s.part]
			var r := _part_rect(p)
			glow.position = p.position + p.get_node("Inner").position + r.get_center()
			s.r = maxf(r.size.x, r.size.y) * 0.6
			s.at = [glow.position.x, glow.position.y]
		else:
			glow.position = Vector2(s.at[0], s.at[1])
		glow.scale = Vector2.ONE * s.get("r", 100.0) * 2.4 / 256.0
		_art.add_child(glow)
		var tw := glow.create_tween().set_loops()
		tw.tween_property(glow, "modulate:a", 0.75, 0.6).set_trans(Tween.TRANS_SINE)
		tw.tween_property(glow, "modulate:a", 0.15, 0.6).set_trans(Tween.TRANS_SINE)
		s.glow = glow
		_spots.append(s)
	_spots_prompt = b.get("prompt", "Tap the glowing places to search!")
	_prompt(_spots_prompt)
	_waiting = "spots"


var _spots_prompt := ""


func _search(at: Vector2) -> void:
	if _busy:
		return
	for s in _spots:
		if s.get("found", false):
			continue
		if at.distance_to(Vector2(s.at[0], s.at[1])) <= s.get("r", 100.0) + 30.0:
			_busy = true
			s.found = true
			s.glow.queue_free()
			Sfx.play("pop")
			if s.has("part"):
				_act(s.part, "wiggle", {})
			_puff(Vector2(s.at[0], s.at[1]))
			_prompt(s.say, s.get("who", ""))
			var line := Narration.find(s.get("voice", ""))
			if line:
				_voice.stream = line
				_voice.play()
			await get_tree().create_timer(2.4).timeout
			_busy = false
			var left := _spots.filter(func(x): return not x.get("found", false)).size()
			if left == 0:
				_waiting = ""
				_step()
			else:
				_prompt("%s (%d more to check)" % [_spots_prompt, left])
			return


func _puff(at: Vector2) -> void:
	for i in 5:
		var p := Sprite2D.new()
		p.texture = preload("res://assets/ui/puff.png")
		p.position = at
		p.scale = Vector2(0.3, 0.3)
		_art.add_child(p)
		var tw := create_tween().set_parallel()
		tw.tween_property(p, "position", at + Vector2.RIGHT.rotated(TAU * i / 5.0) * 70.0, 0.4)
		tw.tween_property(p, "modulate:a", 0.0, 0.4)
		tw.chain().tween_callback(p.queue_free)


func _zoom(rect: Rect2, on: bool) -> void:
	_focus_rect = rect
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		_focus_t = t
		_layout(), _focus_t, 1.0 if on else 0.0, 0.6).set_trans(Tween.TRANS_SINE)
	await tw.finished
	if not on:
		_focus_rect = Rect2()

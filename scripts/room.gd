extends Node2D
## Lola's messy room. First rub the covers to make the bed, then tap clothes to fold them
## up close and tap toys to tidy them.
## When the very last thing is put away, the ring shimmers right where it was.

signal ring_found
signal halfway  # time for the book's sad moment and Ned's pep talk

const MessItem := preload("res://scripts/mess_item.gd")
const FoldStation := preload("res://scenes/fold_station.tscn")
const MANIFEST := "res://assets/room/manifest.json"
const TEX_RING := preload("res://assets/ui/ring.png")
const TEX_GLOW := preload("res://assets/ui/glow.png")
const TEX_SPARKLE := preload("res://assets/ui/sparkle.png")
const TEX_PUFF := preload("res://assets/ui/puff.png")

const SWIPE_DIST := 46.0      # screen px a finger must travel to count as a swipe
const TAP_TOLERANCE := 38.0   # screen px of forgiveness around small items
const HINT_AFTER := 9.0       # seconds of no progress before a free hint
const FLY_Z := 1500
const INK_COLOR := Color(0.149, 0.102, 0.18)
const BED_BRUSH := 115.0      # world px smoothed around the finger
const BED_MASK_SCALE := 8     # the reveal mask is 1/8 of the made-bed picture
const BED_DONE := 0.6         # how much of the covers must be smoothed
const REVEAL_SHADER := """
shader_type canvas_item;
uniform sampler2D reveal : filter_linear;
uniform float all_in = 0.0;
void fragment() {
	COLOR.a *= max(smoothstep(0.15, 0.85, texture(reveal, UV).r), all_in);
}
"""

@onready var _items_root: Node2D = $Items
@onready var _cam: Camera2D = $Camera2D
@onready var _hud = $HUD

var _data: Dictionary
var _room_size := Vector2.ZERO
var _items: Array = []
var _props := {}
var _total := 0
var _remaining := 0
var _last_spot := Vector2.ZERO  # where the last floor item was: the ring turns up there
var _ring: Sprite2D
var _ring_collected := false
var _idle := 0.0
var _min_zoom := 0.3
var _max_zoom := 2.0
var _touches := {}
var _gesture := {}
var _pinch := {}
var _cam_tween: Tween
var _modal := false        # the close-up folding view is open
var _drawer_rig: Node2D
var _drawer_users := 0
var _drawer_t := 0.0
var _drawer_tween: Tween
var _bed_made := false
var _duvet  # the rumpled duvet item
var _bed_unmade: Sprite2D
var _bed_smooth: Sprite2D  # the made bed, revealed where the finger rubs
var _bed_posts: Sprite2D
var _bed_hit := BitMap.new()
var _bed_mask: Image
var _bed_mask_tex: ImageTexture
var _bed_inside := PackedByteArray()  # mask cells that are part of the covers
var _bed_cells := 0
var _bed_smoothed := 0
var _bed_last := Vector2.INF
var _bed_cheered := false
var _swish_cooldown := 0.0


func _ready() -> void:
	_data = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	_room_size = Vector2(_data.room_size[0], _data.room_size[1])
	_build_room()
	_hud.hint_pressed.connect(_show_hint)
	get_viewport().size_changed.connect(_fit_camera.bind(false))
	_fit_camera(true)
	_hud.set_mood("worried")
	_hud.set_progress(_remaining, _total)
	_intro_lines()


func _intro_lines() -> void:
	await get_tree().create_timer(0.7).timeout
	_hud.say("We could find it if I could actually see the ground...", 4.0)
	await get_tree().create_timer(4.4).timeout
	if _bed_made:
		return
	_hud.ned_say("Let's start with your bed. If you only make your bed, you'll feel better!", 4.5,
		_ned_side_away_from(_bed_smooth.position))
	_move_camera(_bed_smooth.position, minf(_max_zoom, _min_zoom * 1.7), 1.0)
	await get_tree().create_timer(4.8).timeout
	if not _bed_made and _bed_smoothed == 0:
		_hud.ned_say("Rub the covers with your finger to smooth them out!", 4.0,
			_ned_side_away_from(_bed_smooth.position))
		_rub_hint()


func _build_room() -> void:
	for entry in _data.items:
		var item := MessItem.new()
		item.setup(entry)
		_items_root.add_child(item)
		_items.append(item)
		if item.dest == "make_bed":
			_duvet = item
	_build_bed()
	for o in _data.overlays:
		var s := Sprite2D.new()
		s.texture = load(o.tex)
		s.position = Vector2(o.pos[0], o.pos[1])
		s.z_index = int(o.z)
		_items_root.add_child(s)
	for prop_name in _data.props:
		var p: Dictionary = _data.props[prop_name]
		var s := Sprite2D.new()
		s.texture = load(p.tex)
		s.centered = false
		s.offset = Vector2(-s.texture.get_width() / 2.0, -s.texture.get_height())
		s.position = Vector2(p.bottom[0], p.bottom[1])
		s.z_index = int(p.z)
		_items_root.add_child(s)
		_props[prop_name] = s
	_total = _items.size()
	_remaining = _total


## The unmade bed sits on top; the made bed from the clean room waits above the rumpled
## duvet, invisible until it's rubbed smooth.
func _build_bed() -> void:
	var bed: Dictionary = _data.bed
	_bed_unmade = _bed_sprite(bed.messy)
	_bed_smooth = _bed_sprite(bed.made)
	_bed_posts = _bed_sprite(bed.posts)
	_bed_posts.modulate.a = 0.0
	var img := _bed_smooth.texture.get_image()
	if img.is_compressed():
		img.decompress()
	_bed_hit.create_from_image_alpha(img, 0.3)
	var small := img.duplicate()
	var mw := ceili(img.get_width() / float(BED_MASK_SCALE))
	var mh := ceili(img.get_height() / float(BED_MASK_SCALE))
	small.resize(mw, mh, Image.INTERPOLATE_BILINEAR)
	_bed_inside.resize(mw * mh)
	for y in mh:
		for x in mw:
			var inside: bool = small.get_pixel(x, y).a > 0.5
			_bed_inside[y * mw + x] = 1 if inside else 0
			_bed_cells += 1 if inside else 0
	_bed_mask = Image.create(mw, mh, false, Image.FORMAT_L8)
	_bed_mask_tex = ImageTexture.create_from_image(_bed_mask)
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = REVEAL_SHADER
	mat.set_shader_parameter("reveal", _bed_mask_tex)
	mat.set_shader_parameter("all_in", 0.0)
	_bed_smooth.material = mat


func _bed_sprite(d: Dictionary) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(d.tex)
	s.position = Vector2(d.pos[0], d.pos[1])
	s.z_index = int(d.z)
	_items_root.add_child(s)
	return s


func _on_bed(world: Vector2) -> bool:
	var p := world - _bed_smooth.position + _bed_smooth.texture.get_size() / 2
	var size := Vector2(_bed_hit.get_size())
	if p.x >= 0 and p.y >= 0 and p.x < size.x and p.y < size.y and _bed_hit.get_bitv(Vector2i(p)):
		return true
	return _duvet.hit_distance(world, 0.0) == 0.0


## Smooths the covers under the finger, from the last point to this one.
func _rub_bed(world: Vector2) -> void:
	var from := world if _bed_last == Vector2.INF else _bed_last
	var steps := maxi(1, ceili(from.distance_to(world) / (BED_BRUSH * 0.3)))
	for i in steps:
		_dab(from.lerp(world, (i + 1) / float(steps)))
	_bed_last = world
	_bed_mask_tex.update(_bed_mask)
	if _swish_cooldown <= 0.0:
		_swish_cooldown = 0.22
		Sfx.play("whoosh", 0.25, -14.0)
		_sparkle_burst(world, 1)
	var done := _bed_smoothed / float(maxi(1, _bed_cells))
	if done > 0.4 and not _bed_cheered:
		_bed_cheered = true
		_hud.say("Ooh, it's getting so smooth!", 2.5)
	if done >= BED_DONE:
		_finish_bed()


func _dab(world: Vector2) -> void:
	var c := (world - _bed_smooth.position + _bed_smooth.texture.get_size() / 2) / BED_MASK_SCALE
	var r := BED_BRUSH / BED_MASK_SCALE
	var w := _bed_mask.get_width()
	for y in range(maxi(0, floori(c.y - r)), mini(_bed_mask.get_height(), ceili(c.y + r))):
		for x in range(maxi(0, floori(c.x - r)), mini(w, ceili(c.x + r))):
			var d := Vector2(x, y).distance_to(c) / r
			if d >= 1.0:
				continue
			var old := _bed_mask.get_pixel(x, y).r
			var v := maxf(old, minf(1.0, (1.0 - d) * 1.8))
			if v <= old:
				continue
			_bed_mask.set_pixel(x, y, Color(v, v, v))
			if old < 0.5 and v >= 0.5 and _bed_inside[y * w + x] == 1:
				_bed_smoothed += 1


## The bed is made: the rest of the covers smooth out, the pillow plumps up.
func _finish_bed() -> void:
	if _bed_made:
		return
	_bed_made = true
	_bed_last = Vector2.INF
	_mark_done(_duvet)
	_hud.ned_hide()
	Sfx.play("whoosh")
	var tw := create_tween().set_parallel()
	tw.tween_property(_bed_smooth.material, "shader_parameter/all_in", 1.0, 0.45)
	tw.tween_property(_duvet, "modulate:a", 0.0, 0.45)
	tw.tween_property(_bed_unmade, "modulate:a", 0.0, 0.45)
	tw.tween_property(_bed_posts, "modulate:a", 1.0, 0.45)
	var squash := create_tween()
	squash.tween_property(_bed_smooth, "scale", Vector2(1.03, 0.96), 0.12).set_trans(Tween.TRANS_SINE)
	squash.tween_property(_bed_smooth, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in 8:
		_sparkle_burst(_bed_smooth.position + Vector2(randf_range(-320, 320), randf_range(-260, 260)), 2)
	await tw.finished
	_duvet.visible = false
	Sfx.play("sparkle", 0.0, -4.0)
	_hud.set_mood("happy")
	_hud.say("See? Isn't that better already?", 3.5)
	await get_tree().create_timer(3.4).timeout
	if _remaining > 0 and not _modal:
		_hud.ned_say("So much better! Now let's put the fluffies on top. Tap Mr. Teddy!", 4.0,
			_ned_side_away_from(_bed_smooth.position))


## A sparkle rubbing back and forth across the covers.
func _rub_hint() -> void:
	var s := Sprite2D.new()
	s.texture = TEX_SPARKLE
	s.z_index = FLY_Z + 10
	_items_root.add_child(s)
	var c := _bed_smooth.position + Vector2(0, 40)
	var pts := [Vector2(-260, -60), Vector2(200, -150), Vector2(-200, 40), Vector2(260, -40), Vector2(-120, 150), Vector2(240, 90)]
	s.position = c + pts[0]
	var tw := create_tween()
	for p in pts.slice(1):
		tw.tween_property(s, "position", c + p, 0.28).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(_sparkle_burst.bind(c + p, 1))
	tw.tween_callback(s.queue_free)


func _process(delta: float) -> void:
	_swish_cooldown -= delta
	if _remaining > 0 and not _modal:
		_idle += delta
		if _idle > HINT_AFTER:
			_show_hint()


# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if _modal:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _hud.blocks(event.position):
				return
			_touches[event.index] = event.position
			if _touches.size() == 1:
				_begin_gesture(event.index, event.position)
			elif _touches.size() == 2:
				_cancel_gesture()
				_begin_pinch()
		else:
			_touches.erase(event.index)
			_pinch = {}
			if not _gesture.is_empty() and _gesture.index == event.index:
				_end_gesture(event.position)
	elif event is InputEventScreenDrag:
		if not _touches.has(event.index):
			return
		_touches[event.index] = event.position
		if _touches.size() >= 2:
			_update_pinch()
		elif not _gesture.is_empty() and _gesture.index == event.index:
			_drag_gesture(event)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(event.position, 1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(event.position, 1.0 / 1.1)
	elif event is InputEventMagnifyGesture:
		_zoom_at(event.position, event.factor)
	elif event is InputEventPanGesture:
		_pan_by(-event.delta * 12.0)


func _begin_gesture(index: int, pos: Vector2) -> void:
	_idle = 0.0
	if _ring and not _ring_collected and _to_world(pos).distance_to(_ring.position) < 150.0 + 60.0 / _cam.zoom.x:
		_collect_ring()
		return
	if not _bed_made and _on_bed(_to_world(pos)):
		_gesture = {"index": index, "start": pos, "item": null, "bed": true, "consumed": false, "panning": false}
		_bed_last = Vector2.INF
		return
	var item = _pick(pos)
	_gesture = {"index": index, "start": pos, "item": item, "consumed": false, "panning": false}
	if item:
		item.lift()


func _drag_gesture(event: InputEventScreenDrag) -> void:
	if _gesture.consumed:
		return
	var travel: Vector2 = event.position - _gesture.start
	if _gesture.get("bed", false):
		if travel.length() > 12.0 and not _bed_made:
			_rub_bed(_to_world(event.position))
		return
	var item = _gesture.item
	if item and not item.done:
		if travel.length() > SWIPE_DIST:
			_gesture.consumed = true
			_on_swipe(item, travel)
	elif _gesture.panning or travel.length() > 12.0:
		_gesture.panning = true
		_pan_by(event.relative)


func _end_gesture(pos: Vector2) -> void:
	if _gesture.get("bed", false):
		_bed_last = Vector2.INF
		if not _bed_made and (pos - _gesture.start).length() < SWIPE_DIST and _bed_smoothed == 0:
			_hud.say("Rub the covers to smooth them out!", 2.5)
			_rub_hint()
		_gesture = {}
		return
	var item = _gesture.item
	if item and not _gesture.consumed and not item.done:
		item.drop()
		if (pos - _gesture.start).length() < SWIPE_DIST:
			_on_tap(item)
	_gesture = {}


func _cancel_gesture() -> void:
	if not _gesture.is_empty() and _gesture.item and not _gesture.item.done:
		_gesture.item.drop()
	_gesture = {}


## Finds the mess under a finger. Exact pixel hits win (topmost first),
## otherwise the nearest item within a forgiving radius.
func _pick(screen_pos: Vector2):
	var world := _to_world(screen_pos)
	var tol := TAP_TOLERANCE / _cam.zoom.x
	var best = null
	var best_d := INF
	for item in _items:
		if item.done:
			continue
		var d: float = item.hit_distance(world, tol)
		if d == INF:
			continue
		if best == null or d < best_d - 0.01 or (absf(d - best_d) <= 0.01 and item.z_index > best.z_index):
			best = item
			best_d = d
	return best


# ------------------------------------------------------------------ actions

func _on_tap(item) -> void:
	if not _bed_made:
		_bed_first(item)
	elif item.kind == "tap":
		_tidy(item)
	else:
		_open_fold_station(item)


func _on_swipe(item, _travel: Vector2) -> void:
	if not _bed_made:
		_bed_first(item)
	elif item.kind == "fold":
		_open_fold_station(item)
	else:
		_tidy(item)  # be forgiving: a swipe on a toy tidies it too


func _mark_done(item) -> void:
	item.done = true
	_remaining -= 1
	if item.on_floor:
		_last_spot = item.home
	_idle = 0.0
	_hud.set_progress(_remaining, _total)
	_cheer()
	if _remaining == 0:
		_hud.set_hint_visible(false)
		_reveal_ring()


func _cheer() -> void:
	var cleaned := _total - _remaining
	if _remaining == 1:
		_hud.say("Just one more thing...", 3.0)
	elif cleaned == int(_total * 0.25):
		_hud.say("Look, I can see the rug!", 3.0)
	elif cleaned == int(_total * 0.5):
		halfway.emit.call_deferred()
	elif cleaned == int(_total * 0.75):
		_hud.say("So much cleaner! Is it here somewhere?", 3.0)


## Tap to tidy: toys hop into the toy box, dollhouse, trash... or onto the bed and desk.
func _tidy(item) -> void:
	_mark_done(item)
	Sfx.play("pop")
	item.z_index = FLY_Z
	match item.dest:
		"bed":
			await _settle(item, 0.7)
		"desk":
			var slot: Array = _data.slots[item.id]
			await _fly(item, Vector2(slot[0], slot[1]), slot[2], deg_to_rad(slot[3]), 0.65)
			item.z_index = 96
			_sparkle_burst(item.position, 5)
			Sfx.play("plop")
		"tuck":
			var tw := create_tween().set_parallel()
			tw.tween_property(item, "scale", Vector2(0.2, 0.2), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tw.tween_property(item, "modulate:a", 0.0, 0.3)
			await tw.finished
			item.visible = false
			_bounce("dresser")
			Sfx.play("plop")
		"pencil_cup":
			# stand the pencil up, then drop it in with the others
			await _fly(item, _dest_point("pencil_cup") + Vector2(0, -40), 0.75, -1.25, 0.6)
			var drop := create_tween().set_parallel()
			drop.tween_property(item, "position:y", item.position.y + 30.0, 0.12)
			drop.tween_property(item, "modulate:a", 0.0, 0.12)
			await drop.finished
			item.visible = false
			_fill_pencil_cup()
		_:
			await _fly(item, _dest_point(item.dest), 0.3, randf_range(-0.6, 0.6), 0.6)
			_vanish_into(item, item.dest)


## The story takes over the screen for a moment (the room keeps its place).
func pause_for_story(on: bool) -> void:
	_modal = on
	_cancel_gesture()
	_touches.clear()
	_idle = 0.0
	if on:
		_hud.ned_hide()
		return
	_hud.set_mood("happy")
	await get_tree().create_timer(0.5).timeout
	_hud.ned_say("Fresh energy! We make a great team. Let's keep going!", 3.5, _ned_side_away_from(_cam.position))


## Before the bed is made, everything else waits: point back at the bed.
func _bed_first(item) -> void:
	item.drop()
	item.wiggle()
	Sfx.play("boop")
	_hud.say("Bed first! Then everything else.", 2.5)
	_move_camera(_bed_smooth.position, _cam.zoom.x, 0.6)
	_rub_hint()


## Flies a fluffy (or the folded throw) onto the made bed, where it turns into
## exactly how it looks in the clean room: sitting up, propped, folded across the foot.
func _settle(item, duration: float) -> void:
	var to: Dictionary = _data.settle[item.id]
	var tex: Texture2D = load(to.tex)
	var land := float(tex.get_height()) / maxf(1.0, item.half_height() * 2.0 / item.scale.y)
	await _fly(item, Vector2(to.pos[0], to.pos[1]), clampf(land, 0.3, 1.5), 0.0, duration)
	item.set_texture(tex)
	item.scale = Vector2.ONE
	item.rotation = 0.0
	item.z_index = int(to.z)
	var tw := create_tween()
	tw.tween_property(item, "scale", Vector2(1.08, 0.92), 0.08)
	tw.tween_property(item, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_puff(item.position, 6, 90.0)
	_sparkle_burst(item.position, 5)
	Sfx.play("plop")


## Tap on clothes: open the close-up folding view (swipe left, right, up).
func _open_fold_station(item) -> void:
	if _modal or item.done:
		return
	_modal = true
	_idle = 0.0
	_hud.ned_hide()
	_cancel_gesture()
	_touches.clear()
	Sfx.play("pop")
	item.visible = false
	var station := FoldStation.instantiate()
	station.setup(load(item.closeup))
	station.folded.connect(_finish_fold.bind(item))
	station.cancelled.connect(_on_fold_cancelled.bind(item))
	add_child(station)


func _on_fold_cancelled(item) -> void:
	item.visible = true
	item.drop()
	_modal = false


## The folded clothes come out of the close-up and go into the dresser drawer
## (the throw blanket goes to the foot of the bed instead).
func _finish_fold(image: Image, screen_pos: Vector2, screen_scale: float, item) -> void:
	_modal = false
	_mark_done(item)
	item.set_texture(ImageTexture.create_from_image(image))
	item.visible = true
	item.modulate.a = 1.0
	item.rotation = 0.0
	item.position = _to_world(screen_pos)
	item.scale = Vector2.ONE * screen_scale / _cam.zoom.x
	item.z_index = FLY_Z
	var art := 0.75  # close-up art is full resolution; the room is drawn at 75%
	if item.dest == "bed_foot":
		await _settle(item, 0.7)
		return
	_open_drawer()
	var mouth := _drawer_mouth()
	var q: Array = _data.drawer.quad
	var drawer_width := Vector2(q[1][0], q[1][1]).distance_to(Vector2(q[0][0], q[0][1]))
	var fit := minf(art * 0.6, drawer_width * 0.7 / float(image.get_width()))
	await _fly(item, mouth + Vector2(0, -30), fit, 0.0, 0.7)
	# drop it in behind the drawer front
	item.z_index = 28
	var drop := create_tween().set_parallel()
	drop.tween_property(item, "position", mouth + Vector2(0, 30), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop.tween_property(item, "scale", item.scale * 0.8, 0.22)
	await drop.finished
	item.visible = false
	Sfx.play("plop")
	_close_drawer()


# ------------------------------------------------------------------ dresser drawer

func _drawer_mouth() -> Vector2:
	var q: Array = _data.drawer.quad
	var pull := Vector2(_data.drawer.pull[0], _data.drawer.pull[1])
	return (Vector2(q[0][0], q[0][1]) + Vector2(q[1][0], q[1][1])) / 2.0 + pull * 0.5


## Slides the top-left drawer out toward you, showing the dark inside.
func _open_drawer() -> void:
	_drawer_users += 1
	if _drawer_rig == null:
		var d: Dictionary = _data.drawer
		var quad := PackedVector2Array()
		for p in d.quad:
			quad.append(Vector2(p[0], p[1]))
		_drawer_rig = Node2D.new()
		var hole := Polygon2D.new()
		hole.polygon = quad
		hole.color = Color(0.17, 0.11, 0.22)
		hole.z_index = 27
		var side := Polygon2D.new()
		side.name = "Side"
		side.color = Color(0.48, 0.36, 0.3)
		side.z_index = 29
		var edge := Line2D.new()
		edge.name = "Edge"
		edge.width = 5.0
		edge.default_color = INK_COLOR
		edge.closed = true
		edge.z_index = 29
		var front := Sprite2D.new()
		front.name = "Front"
		front.texture = load(d.tex)
		front.z_index = 30
		_drawer_rig.add_child(hole)
		_drawer_rig.add_child(side)
		_drawer_rig.add_child(edge)
		_drawer_rig.add_child(front)
		_items_root.add_child(_drawer_rig)
		_set_drawer(0.0)
	_animate_drawer(1.0, 0.3)


func _close_drawer() -> void:
	_drawer_users -= 1
	if _drawer_users > 0:
		return
	await _animate_drawer(0.0, 0.25)
	if _drawer_users == 0 and _drawer_rig:
		_drawer_rig.queue_free()
		_drawer_rig = null
		_bounce("dresser")


func _animate_drawer(to: float, duration: float) -> Signal:
	if _drawer_tween:
		_drawer_tween.kill()
	_drawer_tween = create_tween()
	_drawer_tween.tween_method(_set_drawer, _drawer_t, to, duration).set_trans(Tween.TRANS_SINE)
	return _drawer_tween.finished


func _set_drawer(t: float) -> void:
	_drawer_t = t
	if _drawer_rig == null:
		return
	var d: Dictionary = _data.drawer
	var off := Vector2(d.pull[0], d.pull[1]) * t
	var tl := Vector2(d.quad[0][0], d.quad[0][1])
	var bl := Vector2(d.quad[3][0], d.quad[3][1])
	var side := PackedVector2Array([tl, tl + off, bl + off, bl])
	_drawer_rig.get_node("Side").polygon = side
	_drawer_rig.get_node("Edge").points = side
	_drawer_rig.get_node("Front").position = Vector2(d.pos[0], d.pos[1]) + off


## Lola's pencil joins the others in the cup.
func _fill_pencil_cup() -> void:
	var p: Sprite2D = _props.get("pencil_cup")
	var full: Dictionary = _data.props.pencil_cup.full
	p.texture = load(full.tex)
	p.offset = Vector2(-p.texture.get_width() / 2.0, -p.texture.get_height())
	p.position = Vector2(full.bottom[0], full.bottom[1])
	_bounce("pencil_cup")
	_sparkle_burst(p.position + Vector2(0, -p.texture.get_height()), 4)
	Sfx.play("plop")


func _dest_point(dest_name: String) -> Vector2:
	var d: Array = _data.dests[dest_name]
	return Vector2(d[0], d[1])


## Arcs an item through the air with a shadow sliding along the floor (the 2.5D bit).
func _fly(item, target: Vector2, end_scale: float, end_rot: float, duration: float) -> Signal:
	var start: Vector2 = item.position
	var start_scale: float = item.scale.x
	var height := clampf(start.distance_to(target) * 0.35, 90.0, 520.0)
	var foot: float = item.half_height()
	var shadow := Sprite2D.new()
	shadow.texture = TEX_GLOW
	shadow.modulate = Color(0.15, 0.05, 0.22, 0.35)
	shadow.z_index = FLY_Z - 1
	_items_root.add_child(shadow)
	var step := func(t: float) -> void:
		var ground := start.lerp(target, t)
		item.position = ground + Vector2(0, -height * 4.0 * t * (1.0 - t))
		var s := lerpf(start_scale, end_scale, t)
		item.scale = Vector2(s, s)
		item.rotation = lerpf(0.0, end_rot, t)
		shadow.position = ground + Vector2(0, foot * s)
		var lift := sin(PI * t)
		shadow.scale = Vector2(1.6, 0.45) * s * (1.0 - 0.45 * lift) * 1.4
		shadow.modulate.a = 0.35 * (1.0 - 0.5 * lift)
	var tw := create_tween()
	tw.tween_method(step, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(shadow.queue_free)
	return tw.finished


func _vanish_into(item, container: String) -> void:
	var tw := create_tween().set_parallel()
	tw.tween_property(item, "scale", Vector2(0.05, 0.05), 0.14)
	tw.tween_property(item, "modulate:a", 0.0, 0.14)
	tw.chain().tween_callback(func(): item.visible = false)
	_bounce(container)
	_puff(_dest_point(container) if _data.dests.has(container) else item.position, 4, 50.0)
	Sfx.play("plop")


func _bounce(prop_name: String) -> void:
	var p: Sprite2D = _props.get(prop_name)
	if p == null:
		return
	var tw := create_tween()
	tw.tween_property(p, "scale", Vector2(1.05, 1.09), 0.08).set_trans(Tween.TRANS_SINE)
	tw.tween_property(p, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_SINE)


# ------------------------------------------------------------------ the ring

func _reveal_ring() -> void:
	await get_tree().create_timer(1.1).timeout
	_hud.set_mood("happy")
	_hud.say("Wait... something is shimmering!", 0.0)
	Sfx.play("sparkle")
	var spot := _last_spot
	var glow := Sprite2D.new()
	glow.texture = TEX_GLOW
	glow.modulate = Color(1.0, 0.92, 1.0, 0.9)
	glow.position = spot
	glow.z_index = 1990
	glow.scale = Vector2.ZERO
	_items_root.add_child(glow)
	_ring = Sprite2D.new()
	_ring.texture = TEX_RING
	_ring.position = spot
	_ring.z_index = 2000
	_ring.scale = Vector2.ZERO
	_items_root.add_child(_ring)
	var tw := create_tween().set_parallel()
	tw.tween_property(glow, "scale", Vector2(2.4, 2.4), 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_ring, "scale", Vector2(0.7, 0.7), 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var pulse := create_tween().set_loops()
	pulse.tween_property(glow, "modulate:a", 0.45, 0.7).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(glow, "modulate:a", 0.95, 0.7).set_trans(Tween.TRANS_SINE)
	var bob := create_tween().set_loops()
	bob.tween_property(_ring, "rotation", 0.15, 0.8).set_trans(Tween.TRANS_SINE)
	bob.tween_property(_ring, "rotation", -0.15, 0.8).set_trans(Tween.TRANS_SINE)
	_move_camera(spot, minf(_max_zoom, _cam.zoom.x * 1.5), 1.2)
	_keep_sparkling(spot)
	await get_tree().create_timer(2.0).timeout
	if not _ring_collected:
		_hud.say("Tap the sparkle!", 0.0)


func _keep_sparkling(spot: Vector2) -> void:
	while is_inside_tree() and not _ring_collected:
		_sparkle_burst(spot + Vector2(randf_range(-110, 110), randf_range(-140, 60)), 1)
		await get_tree().create_timer(0.3).timeout


func _collect_ring() -> void:
	_ring_collected = true
	Sfx.play("win", 0.0)
	_hud.set_mood("joy")
	_hud.say("My ring! We found it!", 0.0)
	_ned_cheer_ring()
	_sparkle_burst(_ring.position, 16)
	var tw := create_tween().set_parallel()
	tw.tween_property(_ring, "scale", Vector2(1.6, 1.6), 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_ring, "position", _ring.position + Vector2(0, -160), 0.9).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(2.6).timeout
	ring_found.emit()


# ------------------------------------------------------------------ hints & effects

func _show_hint() -> void:
	_idle = 0.0
	var view := Rect2(_cam.position - _view_size() / 2, _view_size())
	var candidates := _items.filter(func(i): return not i.done)
	if candidates.is_empty():
		return
	if not _bed_made:
		if not view.grow(-100).has_point(_bed_smooth.position):
			_move_camera(_bed_smooth.position, _cam.zoom.x, 0.6)
		_hud.ned_say("Rub the covers with your finger to make the bed!", 3.5, _ned_side_away_from(_bed_smooth.position))
		Sfx.play("boop", 0.0, -6.0)
		_rub_hint()
		return
	# the fluffies go on the freshly made bed first
	var fluffies := candidates.filter(func(i): return i.dest == "bed")
	if not fluffies.is_empty():
		candidates = fluffies
	var on_screen := candidates.filter(func(i): return view.has_point(i.position))
	var pool := on_screen if not on_screen.is_empty() else candidates
	var item = pool[0]
	for c in pool:
		if c.position.distance_to(_cam.position) < item.position.distance_to(_cam.position):
			item = c
	if not view.grow(-100).has_point(item.position):
		_move_camera(item.position, _cam.zoom.x, 0.6)
	var glow := Sprite2D.new()
	glow.texture = TEX_GLOW
	glow.position = item.position
	glow.z_index = item.z_index - 1
	glow.modulate = Color(1, 0.95, 0.7, 0.0)
	var r: float = maxf(item.half_height(), 60.0) / 90.0
	glow.scale = Vector2(r, r)
	_items_root.add_child(glow)
	var tw := create_tween()
	for i in 3:
		tw.tween_property(glow, "modulate:a", 0.85, 0.3)
		tw.tween_property(glow, "modulate:a", 0.15, 0.3)
	tw.tween_callback(glow.queue_free)
	item.wiggle()
	_sparkle_burst(item.position, 3)
	Sfx.play("boop", 0.0, -6.0)
	_hud.ned_say(_ned_tip(item), 3.5, _ned_side_away_from(item.position))


## Ned's tip for one piece of mess, in his kind, helpful voice.
func _ned_tip(item) -> String:
	var id: String = item.id
	if id == "teddy":
		return "Mr. Teddy wants to go back on the bed! Tap him."
	if id == "flower":
		return "The flower pillow goes on the bed, next to Mr. Teddy!"
	if id.begins_with("doll_"):
		return "Those little doll things go in the dollhouse!"
	if id in ["coloring_book", "notebook"]:
		return "Books go on the desk. Tap it!"
	if id == "pencil":
		return "That pencil goes in the cup with the others!"
	if id == "wrapper":
		return "A wrapper! Tap it for the trash."
	if id == "dresser_sock":
		return "A sock is poking out of the drawer! Tap it."
	if id == "cup":
		return "Uh oh, a tipped-over cup! Tap it for the trash."
	if id == "tissue":
		return "A used tissue! That goes in the trash."
	if id == "throw_blanket":
		return "Let's fold that blanket. Tap it!"
	if item.kind == "fold":
		return "Clothes! Tap them and we'll fold them together."
	var names := {"cat": "kitty", "ball": "ball", "boat": "boat", "teacup_a": "teacup",
		"teacup_b": "teacup", "block_a": "block", "block_b": "block", "butterfly": "butterfly",
		"cloud": "cloud", "bunny": "bear"}
	return "Tap the %s to put it in the toy box!" % names.get(id, "toy")


## Ned stands on the opposite side of the screen from what he's pointing at.
func _ned_side_away_from(world_pos: Vector2) -> String:
	var screen_x := (world_pos.x - _cam.position.x) * _cam.zoom.x + get_viewport_rect().size.x / 2
	return "left" if screen_x > get_viewport_rect().size.x * 0.55 else "right"


func _ned_cheer_ring() -> void:
	await get_tree().create_timer(0.9).timeout
	_hud.ned_say("You found it, Lola! I knew we would!", 0.0, _ned_side_away_from(_ring.position))


func _sparkle_burst(at: Vector2, count: int) -> void:
	for i in count:
		var s := Sprite2D.new()
		s.texture = TEX_SPARKLE
		s.position = at
		s.z_index = 2100
		s.modulate = [Color(1, 1, 1), Color(1, 0.9, 0.6), Color(0.9, 0.8, 1)][i % 3]
		s.scale = Vector2.ZERO
		_items_root.add_child(s)
		var dir := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(60, 160)
		var size := randf_range(0.35, 0.8)
		var tw := create_tween().set_parallel()
		tw.tween_property(s, "position", at + dir, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "scale", Vector2(size, size), 0.2)
		tw.tween_property(s, "rotation", randf_range(-1.5, 1.5), 0.55)
		tw.tween_property(s, "modulate:a", 0.0, 0.3).set_delay(0.3)
		tw.chain().tween_callback(s.queue_free)


func _puff(at: Vector2, count: int, spread: float) -> void:
	for i in count:
		var p := Sprite2D.new()
		p.texture = TEX_PUFF
		p.position = at
		p.z_index = 2050
		p.scale = Vector2(0.3, 0.3)
		_items_root.add_child(p)
		var dir := Vector2.RIGHT.rotated(TAU * i / count + randf() * 0.5) * spread
		var tw := create_tween().set_parallel()
		tw.tween_property(p, "position", at + dir, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "scale", Vector2(0.7, 0.7), 0.4)
		tw.tween_property(p, "modulate:a", 0.0, 0.4)
		tw.chain().tween_callback(p.queue_free)


# ------------------------------------------------------------------ camera

func _view_size() -> Vector2:
	return get_viewport_rect().size / _cam.zoom.x


func _to_world(screen_pos: Vector2) -> Vector2:
	return _cam.position + (screen_pos - get_viewport_rect().size / 2) / _cam.zoom.x


## Whole room visible at minimum zoom; starts a little closer on wide phones.
func _fit_camera(reset: bool) -> void:
	var vs := get_viewport_rect().size
	var contain := minf(vs.x / _room_size.x, vs.y / _room_size.y)
	var cover := maxf(vs.x / _room_size.x, vs.y / _room_size.y)
	_min_zoom = contain
	_max_zoom = contain * 3.2
	if reset:
		var z := clampf(cover, contain, contain * 1.3)
		_cam.zoom = Vector2(z, z)
		_cam.position = Vector2(_room_size.x / 2, _room_size.y - vs.y / z / 2)
	else:
		var z := clampf(_cam.zoom.x, _min_zoom, _max_zoom)
		_cam.zoom = Vector2(z, z)
	_clamp_camera()


func _clamp_camera() -> void:
	var half := _view_size() / 2
	var p := _cam.position
	for axis in 2:
		if half[axis] * 2.0 >= _room_size[axis]:
			p[axis] = _room_size[axis] / 2
		else:
			p[axis] = clampf(p[axis], half[axis], _room_size[axis] - half[axis])
	_cam.position = p


func _pan_by(screen_delta: Vector2) -> void:
	if _cam_tween and _cam_tween.is_running():
		return
	_cam.position -= screen_delta / _cam.zoom.x
	_clamp_camera()


func _zoom_at(screen_pos: Vector2, factor: float) -> void:
	if _cam_tween and _cam_tween.is_running():
		return
	var anchor := _to_world(screen_pos)
	var z := clampf(_cam.zoom.x * factor, _min_zoom, _max_zoom)
	_cam.zoom = Vector2(z, z)
	_cam.position = anchor - (screen_pos - get_viewport_rect().size / 2) / z
	_clamp_camera()


func _begin_pinch() -> void:
	var pts: Array = _touches.values()
	_pinch = {"dist": maxf(1.0, pts[0].distance_to(pts[1])), "zoom": _cam.zoom.x, "mid": (pts[0] + pts[1]) / 2}


func _update_pinch() -> void:
	if _pinch.is_empty():
		_begin_pinch()
	var pts: Array = _touches.values()
	var mid: Vector2 = (pts[0] + pts[1]) / 2
	var target: float = _pinch.zoom * pts[0].distance_to(pts[1]) / _pinch.dist
	_zoom_at(mid, target / _cam.zoom.x)
	_pan_by(mid - _pinch.mid)
	_pinch.mid = mid


func _move_camera(target: Vector2, zoom: float, duration: float) -> void:
	if _cam_tween:
		_cam_tween.kill()
	var start_pos := _cam.position
	var start_zoom := _cam.zoom.x
	var step := func(t: float) -> void:
		var z := lerpf(start_zoom, zoom, t)
		_cam.zoom = Vector2(z, z)
		_cam.position = start_pos.lerp(target, t)
		_clamp_camera()
	_cam_tween = create_tween()
	_cam_tween.tween_method(step, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

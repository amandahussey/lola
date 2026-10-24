extends Node
## Dev-only: plays through the whole game and saves screenshots.
## Run:  godot --path . -- --autotest   (screenshots land in user://autotest/)

var _main: Node
var _dir := ""


func _ready() -> void:
	_main = get_parent()
	_dir = OS.get_user_data_dir() + "/autotest"
	DirAccess.make_dir_recursive_absolute(_dir)
	print("AUTOTEST screenshots -> ", _dir)
	_run()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, name])
	print("AUTOTEST shot ", name)


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _run() -> void:
	await _wait(1.0)
	await _shot("00_title")
	if "--tornado" in OS.get_cmdline_user_args():
		_main._step = 0
		_main._next()
		await _play_tornado()
		get_tree().quit()
		return
	_main.play_chapter(1)
	await _drive(await _story_screen(), "ch1")
	await _play_tornado()
	for ch in ["ch2", "ch3", "ch4", "ch5"]:
		await _drive(await _story_screen(), ch)
	await _play_room()
	await _drive(await _story_screen(), "ch6")
	await _wait(1.5)
	await _shot("99_back_to_title")
	print("AUTOTEST unlocked chapters: ", _main.unlocked())
	print("AUTOTEST done")
	get_tree().quit()


func _story_screen():
	for k in 40:
		await _wait(0.25)
		var s = _main.current_screen()
		if s and s.has_method("_advance") and not s.is_queued_for_deletion():
			return s
	push_error("AUTOTEST no story screen")


## Reads through a stretch of the storybook like a player: taps Next, and taps whatever
## the page asks for. Saves a screenshot of each page.
func _drive(p, tag: String) -> void:
	var done := [false]
	p.finished.connect(func(): done[0] = true)
	var last := ""
	var n := 0
	while not done[0] and is_instance_valid(p):
		await _wait(0.3)
		if p._waiting == "tap":
			if p._page_id != last:
				last = p._page_id
				n += 1
				await _wait(0.5)
				await _shot("%s_%02d_page%s" % [tag, n, last])
			p._ready_at = 0
			p._advance()
		elif p._waiting == "rub":
			await _wait(0.5)
			await _shot("%s_rub_start" % tag)
			var part: Node2D = p._rub.part
			var xf: Transform2D = part.get_node("Inner").get_global_transform_with_canvas()
			var r: Rect2 = p._rub.rect
			var rows := 9
			var pts: Array[Vector2] = []
			for k in rows:
				var y := r.position.y + r.size.y * (k + 0.5) / rows
				pts.append(xf * Vector2(r.position.x if k % 2 == 0 else r.end.x, y))
				pts.append(xf * Vector2(r.end.x if k % 2 == 0 else r.position.x, y))
			_mouse(pts[0], true)
			var half := false
			for k in range(1, pts.size()):
				for t in 6:
					_motion(pts[k - 1].lerp(pts[k], (t + 1) / 6.0))
					await _wait(0.02)
				if k == pts.size() / 2 and not half:
					half = true
					await _shot("%s_rub_half" % tag)
				if p._waiting != "rub":
					break
			_mouse(pts[-1], false)
			print("AUTOTEST rubbed clean=", p._waiting != "rub")
		elif p._waiting == "hop":
			if p._hops.i == 0:
				await _shot("%s_hop_start" % tag)
			_click(Vector2(960, 540))
			await _wait(0.6)
			if p._hops.i == 3:
				await _shot("%s_hop_mid" % tag)
		elif p._waiting == "spots":
			await _wait(0.4)
			for spot in p._spots:
				if spot.get("found", false):
					continue
				var at: Vector2 = p._art.get_global_transform_with_canvas() * Vector2(spot.at[0], spot.at[1])
				_click(at)
				await _wait(0.5)
				await _shot("%s_search_%d" % [tag, p._spots.filter(func(x): return x.get("found", false)).size()])
				await _wait(2.4)
				break
		elif p._waiting == "part":
			await _wait(0.4)
			var part: Node2D = p._parts[p._wait_part]
			var at: Vector2 = part.get_node("Inner").get_global_transform_with_canvas() * p._part_rect(part).get_center()
			await _shot("%s_tap_%s" % [tag, p._wait_part])
			_click(at)
	print("AUTOTEST story ", tag, " done, pages=", n)
	while is_instance_valid(p) and _main.current_screen() == p and p.get_parent() != _main._overlay:
		await _wait(0.1)


func _mouse(at: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.position = at
	e.pressed = pressed
	get_viewport().push_input(e, true)


func _motion(at: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = at
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(e, true)


func _click(at: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = at
	down.pressed = true
	get_viewport().push_input(down, true)
	var up := down.duplicate()
	up.pressed = false
	get_viewport().push_input(up, true)


func _play_tornado() -> void:
	var t = null
	for k in 40:
		await _wait(0.25)
		t = _main.current_screen()
		if t and t.has_method("_catch"):
			break
	await _wait(1.0)
	await _shot("t1_tornado_start")
	var done := [false]
	t.finished.connect(func(): done[0] = true)
	var taps := 0
	var caught := 0
	while not done[0] and taps < 60:
		for toy in t._toys:
			if not toy.done and sin(toy.angle) > 0.0:
				_click(toy.node.position)
				taps += 1
				break
		await _wait(0.35)
		if not done[0]:
			caught = t._caught
		if caught == 4:
			await _shot("t2_tornado_catching")
	await _shot("t3_tornado_done")
	print("AUTOTEST tornado caught=", caught, " taps=", taps)
	while not done[0]:
		await _wait(0.3)


func _play_room() -> void:
	var room = null
	for k in 40:
		await _wait(0.25)
		room = _main.current_screen()
		if room and room.has_method("_finish_bed"):
			break
	await _wait(1.6)
	await _shot("r03_room_start")
	await _wait(4.2)
	await _shot("r03b_ned_intro")
	room._show_hint()
	await _wait(0.8)
	await _shot("r03c_ned_hint")
	await _wait(3.6)
	# Bed first: tapping a toy before the bed is made just points back at the bed.
	await _touch_item(room, "ball", Vector2.ZERO)
	print("AUTOTEST ball before bed done=", _item(room, "ball").done)
	await _wait(0.7)
	# Rub the covers with real drags until the bed is made.
	room._fit_camera(true)
	room._move_camera(room._bed_smooth.position, room._min_zoom * 1.7, 0.01)
	await _wait(0.2)
	var bed: Vector2 = (room._bed_smooth.position - room._cam.position) * room._cam.zoom.x + room.get_viewport_rect().size / 2
	var rubs := [[Vector2(-300, -120), Vector2(560, 0)], [Vector2(260, -40), Vector2(-560, 60)],
		[Vector2(-280, 40), Vector2(560, 20)], [Vector2(240, 120), Vector2(-500, 40)],
		[Vector2(-200, 200), Vector2(420, 0)], [Vector2(-60, -200), Vector2(200, 380)]]
	var k := 0
	for r in rubs:
		await _swipe(bed + r[0], r[1])
		k += 1
		if k == 2:
			await _shot("r03d_bed_rubbing")
		if room._bed_made:
			break
	print("AUTOTEST bed made=", room._bed_made, " smoothed=", room._bed_smoothed, "/", room._bed_cells)
	await _wait(0.6)
	await _shot("r03e_bed_made")
	await _wait(3.6)
	await _shot("r03f_fluffies_tip")
	# Real input path: tap a toy...
	await _touch_item(room, "ball", Vector2.ZERO)
	# ...tap the tights to open the close-up, then fold with real swipes.
	await _touch_item(room, "tights", Vector2.ZERO)
	await _wait(0.8)
	await _shot("r04_closeup")
	var vs: Vector2 = room.get_viewport_rect().size
	var mid := vs / 2
	await _swipe(mid, Vector2(0, 260))   # wrong way: should only wiggle
	await _wait(0.3)
	print("AUTOTEST wrong-way swipe, tights done=", _item(room, "tights").done)
	await _swipe(mid, Vector2(-300, 0))
	await _wait(0.9)
	await _shot("r05_fold_left")
	await _swipe(mid, Vector2(300, 0))
	await _wait(0.9)
	await _shot("r06_fold_right")
	await _swipe(mid, Vector2(0, -260))
	await _wait(0.6)
	await _shot("r07_folded")
	await _wait(0.3)
	room._move_camera(room._drawer_mouth(), room._cam.zoom.x * 2.4, 0.4)
	await _wait(0.45)
	await _shot("r08_into_drawer")
	await _wait(0.2)
	await _shot("r08b_into_drawer")
	room._fit_camera(true)
	print("AUTOTEST tights done=", _item(room, "tights").done)
	await _wait(1.0)
	await _touch_item(room, "pencil", Vector2.ZERO)
	await _wait(1.6)
	room._move_camera(room._dest_point("pencil_cup"), room._cam.zoom.x * 2.5, 0.3)
	await _wait(0.6)
	await _shot("r09_pencil_cup")
	room._fit_camera(true)
	var i := 0
	for item in room._items:
		if item.done:
			continue
		if item.dest == "make_bed":
			room._finish_bed()
		elif item.kind == "fold":
			var img: Image = load(item.closeup).get_image()
			img.convert(Image.FORMAT_RGBA8)
			room._finish_fold(img.get_region(Rect2i(0, 0, img.get_width() / 3, img.get_height() / 2)), mid, 0.6, item)
		else:
			room._tidy(item)
		i += 1
		await _wait(0.15)
		if room._modal and is_instance_valid(_main._overlay):
			await _wait(0.6)
			await _drive(_main._overlay.get_child(0), "ch5_halfway")
			await _wait(1.0)
		if i == 20:
			await _wait(0.4)
			await _shot("r10_midway")
		if item.id == "throw_blanket" or item.id == "tissue":
			await _wait(1.0)
			room._move_camera(room._bed_smooth.position + Vector2(-150, -150), room._min_zoom * 1.8, 0.01)
			await _wait(0.2)
			await _shot("r10b_bed_" + item.id)
			room._fit_camera(true)
	await _wait(3.5)
	await _shot("r11_ring")
	room._collect_ring()
	await _wait(1.0)
	await _shot("r12_collected")


## Sends real touch events at an item so the gesture code is exercised too.
func _touch_item(room, id: String, swipe: Vector2) -> void:
	var item
	for it in room._items:
		if it.id == id:
			item = it
	var vs: Vector2 = room.get_viewport_rect().size
	var screen: Vector2 = (item.position - room._cam.position) * room._cam.zoom.x + vs / 2
	var down := InputEventScreenTouch.new()
	down.position = screen
	down.pressed = true
	get_viewport().push_input(down, true)
	await _wait(0.05)
	if swipe != Vector2.ZERO:
		for k in 4:
			var drag := InputEventScreenDrag.new()
			drag.position = screen + swipe * (k + 1) / 4.0
			drag.relative = swipe / 4.0
			get_viewport().push_input(drag, true)
			await _wait(0.02)
	var up := InputEventScreenTouch.new()
	up.position = screen + swipe
	up.pressed = false
	get_viewport().push_input(up, true)
	print("AUTOTEST touched ", id, " done=", item.done)


func _item(room, id: String):
	for it in room._items:
		if it.id == id:
			return it


func _swipe(from: Vector2, delta: Vector2) -> void:
	var down := InputEventScreenTouch.new()
	down.position = from
	down.pressed = true
	get_viewport().push_input(down, true)
	for k in 6:
		await _wait(0.02)
		var drag := InputEventScreenDrag.new()
		drag.position = from + delta * (k + 1) / 6.0
		drag.relative = delta / 6.0
		get_viewport().push_input(drag, true)
	var up := InputEventScreenTouch.new()
	up.position = from + delta
	up.pressed = false
	get_viewport().push_input(up, true)
	await _wait(0.05)

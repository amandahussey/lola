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
	await _shot("01_title")
	_main.show_intro()
	await _wait(1.5)
	await _shot("02_intro")
	_main.show_game()
	await _wait(1.6)
	var room = _main.current_screen()
	await _shot("03_room_start")
	await _wait(4.2)
	await _shot("03b_ned_intro")
	room._show_hint()
	await _wait(0.8)
	await _shot("03c_ned_hint")
	await _wait(3.6)
	# Real input path: tap a toy...
	await _touch_item(room, "ball", Vector2.ZERO)
	# ...tap the tights to open the close-up, then fold with real swipes.
	await _touch_item(room, "tights", Vector2.ZERO)
	await _wait(0.8)
	await _shot("04_closeup")
	var vs: Vector2 = room.get_viewport_rect().size
	var mid := vs / 2
	await _swipe(mid, Vector2(0, 260))   # wrong way: should only wiggle
	await _wait(0.3)
	print("AUTOTEST wrong-way swipe, tights done=", _item(room, "tights").done)
	await _swipe(mid, Vector2(-300, 0))
	await _wait(0.9)
	await _shot("05_fold_left")
	await _swipe(mid, Vector2(300, 0))
	await _wait(0.9)
	await _shot("06_fold_right")
	await _swipe(mid, Vector2(0, -260))
	await _wait(0.6)
	await _shot("07_folded")
	await _wait(0.3)
	room._move_camera(room._drawer_mouth(), room._cam.zoom.x * 2.4, 0.4)
	await _wait(0.45)
	await _shot("08_into_drawer")
	await _wait(0.2)
	await _shot("08b_into_drawer")
	room._fit_camera(true)
	print("AUTOTEST tights done=", _item(room, "tights").done)
	await _wait(1.0)
	await _touch_item(room, "pencil", Vector2.ZERO)
	await _wait(1.6)
	room._move_camera(room._dest_point("pencil_cup"), room._cam.zoom.x * 2.5, 0.3)
	await _wait(0.6)
	await _shot("09_pencil_cup")
	room._fit_camera(true)
	var i := 0
	for item in room._items:
		if item.done:
			continue
		if item.dest == "make_bed":
			room._make_bed(item, Vector2(200, 0))
		elif item.kind == "fold":
			var img: Image = load(item.closeup).get_image()
			img.convert(Image.FORMAT_RGBA8)
			room._finish_fold(img.get_region(Rect2i(0, 0, img.get_width() / 3, img.get_height() / 2)), mid, 0.6, item)
		else:
			room._tidy(item)
		i += 1
		await _wait(0.15)
		if i == 20:
			await _wait(0.4)
			await _shot("10_midway")
	await _wait(3.5)
	await _shot("11_ring")
	room._collect_ring()
	await _wait(1.0)
	await _shot("12_collected")
	await _wait(2.5)
	await _shot("13_ring_card")
	_main.show_finale()
	await _wait(1.5)
	await _shot("14_finale")
	print("AUTOTEST done")
	get_tree().quit()


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

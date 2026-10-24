extends Node
## Game flow: the title, then the book chapter by chapter. Story pages lead into small games
## (the purple tornado, cleaning Lola's room...), and the room's halfway point pauses for the
## book's sad moment and Ned's pep talk. Reaching a chapter unlocks it on the title screen.

const TitleScene := preload("res://scenes/title.tscn")
const RoomScene := preload("res://scenes/room.tscn")
const StoryPlayer := preload("res://scripts/story/story_player.gd")
const StoryScript := preload("res://scripts/story/story_script.gd")
const Tornado := preload("res://scripts/games/tornado.gd")
const SAVE := "user://progress.cfg"

## What happens, in order. "chapter" marks where each chapter starts (1-based).
const FLOW := [
	{"story": "ch1", "chapter": 1},
	{"game": "tornado"},
	{"story": "ch2", "chapter": 2},
	{"story": "ch3", "chapter": 3},
	{"story": "ch4", "chapter": 4},
	{"story": "ch5", "chapter": 5},
	{"game": "room"},
	{"story": "ch6", "chapter": 6},
]

@onready var _world: Node = $World
@onready var _screens: CanvasLayer = $Screens
@onready var _fade: ColorRect = $Fade/FadeRect

var _current: Node
var _switching := false
var _step := -1
var _overlay: CanvasLayer


func _ready() -> void:
	Sfx.play_music()
	_show(_make_title(), true)
	if "--autotest" in OS.get_cmdline_user_args():
		add_child(load("res://tools/autotest.gd").new())


func show_title() -> void:
	_show(_make_title())


## Starts the book at chapter n (1-based).
func play_chapter(n: int) -> void:
	for i in FLOW.size():
		if FLOW[i].get("chapter", 0) == n:
			_step = i - 1
			_next()
			return


func _next() -> void:
	_step += 1
	if _step >= FLOW.size():
		show_title()
		return
	var f: Dictionary = FLOW[_step]
	if f.has("chapter"):
		_unlock(f.chapter)
	if f.has("story"):
		_show(_make_story(f.story, _next))
	elif f.game == "tornado":
		var t := Tornado.new()
		t.finished.connect(_next)
		_show(t)
	elif f.game == "room":
		var room := RoomScene.instantiate()
		room.ring_found.connect(_next)
		room.halfway.connect(_halfway.bind(room))
		_show(room)


func _make_story(id: String, then: Callable) -> Node:
	var player := StoryPlayer.new()
	player.setup(StoryScript.STORY[id])
	player.finished.connect(then, CONNECT_ONE_SHOT)
	return player


## Halfway through cleaning: the book's sad page and Ned's kind words, then back to work.
func _halfway(room) -> void:
	room.pause_for_story(true)
	_overlay = CanvasLayer.new()
	_overlay.layer = 50
	add_child(_overlay)
	var player := _make_story("ch5_sad", _end_halfway.bind(room))
	player.modulate.a = 0.0
	_overlay.add_child(player)
	create_tween().tween_property(player, "modulate:a", 1.0, 0.4)


func _end_halfway(room) -> void:
	var tw := create_tween()
	tw.tween_property(_overlay.get_child(0), "modulate:a", 0.0, 0.4)
	await tw.finished
	_overlay.queue_free()
	room.pause_for_story(false)


func _make_title() -> Node:
	var title := TitleScene.instantiate()
	title.setup(StoryScript.CHAPTERS, unlocked())
	title.chapter_pressed.connect(play_chapter)
	return title


func unlocked() -> int:
	var cfg := ConfigFile.new()
	cfg.load(SAVE)
	return int(cfg.get_value("progress", "chapter", 1))


func _unlock(n: int) -> void:
	if n <= unlocked():
		return
	var cfg := ConfigFile.new()
	cfg.load(SAVE)
	cfg.set_value("progress", "chapter", n)
	cfg.save(SAVE)


## Cross-fades to a new screen. Rooms (Node2D) live in World, UI screens in the Screens layer.
func _show(next: Node, instant := false) -> void:
	if _switching:
		await get_tree().create_timer(0.8).timeout
	_switching = true
	if not instant:
		var out := create_tween()
		out.tween_property(_fade, "color:a", 1.0, 0.3)
		await out.finished
	if _current:
		_current.queue_free()
	_current = next
	if next is Control:
		_screens.add_child(next)
	else:
		_world.add_child(next)
	var back := create_tween()
	back.tween_property(_fade, "color:a", 0.0, 0.45)
	await back.finished
	_switching = false


func current_screen() -> Node:
	return _current

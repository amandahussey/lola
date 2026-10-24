extends Node
## Game flow: title -> story intro -> messy room -> ring found -> ending cards -> title.

const TitleScene := preload("res://scenes/title.tscn")
const StoryCardScene := preload("res://scenes/story_card.tscn")
const RoomScene := preload("res://scenes/room.tscn")

@onready var _world: Node = $World
@onready var _screens: CanvasLayer = $Screens
@onready var _fade: ColorRect = $Fade/FadeRect

var _current: Node
var _switching := false


func _ready() -> void:
	Sfx.play_music()
	_show(_make_title(), true)
	if "--autotest" in OS.get_cmdline_user_args():
		add_child(load("res://tools/autotest.gd").new())


func show_title() -> void:
	_show(_make_title())


func show_intro() -> void:
	var card := StoryCardScene.instantiate()
	card.setup(
		preload("res://assets/story/intro_spread.jpg"),
		"Oh no! Lola's rare purple diamond ring is lost somewhere in her messy room.",
		"Let's find it!")
	card.finished.connect(show_game)
	_show(card)


func show_game() -> void:
	var room := RoomScene.instantiate()
	room.ring_found.connect(show_ring_card)
	_show(room)


func show_ring_card() -> void:
	var card := StoryCardScene.instantiate()
	card.setup(
		preload("res://assets/story/ring_spread.jpg"),
		"You found Lola's ring!",
		"Yay!")
	card.finished.connect(show_finale)
	_show(card)


func show_finale() -> void:
	var card := StoryCardScene.instantiate()
	card.setup(
		preload("res://assets/story/high_five.jpg"),
		"You did it! Lola's room is tidy and her ring is found.\nThanks for helping!",
		"Play again")
	card.finished.connect(show_title)
	_show(card)


func _make_title() -> Node:
	var title := TitleScene.instantiate()
	title.play_pressed.connect(show_intro)
	return title


## Cross-fades to a new screen. Rooms (Node2D) live in World, UI screens in the Screens layer.
func _show(next: Node, instant := false) -> void:
	if _switching:
		next.queue_free()
		return
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

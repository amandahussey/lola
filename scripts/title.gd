extends Control
## Title: Play starts the book from the beginning; the chapter buttons jump to any chapter
## you've already reached.

signal chapter_pressed(n: int)

@onready var _ring: TextureRect = %Ring
@onready var _play: Button = %PlayButton
@onready var _chapters: HBoxContainer = %Chapters

var _list: Array = []
var _unlocked := 1


func setup(chapters: Array, unlocked: int) -> void:
	_list = chapters
	_unlocked = unlocked


func _ready() -> void:
	_play.pressed.connect(_on_chapter.bind(1))
	for i in _list.size():
		var b := Button.new()
		b.text = str(i + 1)
		b.tooltip_text = _list[i].title
		b.custom_minimum_size = Vector2(96, 96)
		b.add_theme_font_size_override("font_size", 48)
		b.disabled = i + 1 > _unlocked
		b.pressed.connect(_on_chapter.bind(i + 1))
		_chapters.add_child(b)
	%ChapterLabel.visible = _unlocked > 1
	_chapters.visible = _unlocked > 1
	# Gentle bob on the ring and a heartbeat on the Play button.
	await get_tree().process_frame
	_ring.pivot_offset = _ring.size / 2
	_play.pivot_offset = _play.size / 2
	var bob := create_tween().set_loops()
	bob.tween_property(_ring, "rotation", 0.12, 0.9).set_trans(Tween.TRANS_SINE)
	bob.tween_property(_ring, "rotation", -0.12, 0.9).set_trans(Tween.TRANS_SINE)
	var beat := create_tween().set_loops()
	beat.tween_property(_play, "scale", Vector2(1.06, 1.06), 0.5).set_trans(Tween.TRANS_SINE)
	beat.tween_property(_play, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)


func _on_chapter(n: int) -> void:
	Sfx.play("pop")
	chapter_pressed.emit(n)

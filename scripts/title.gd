extends Control

signal play_pressed

@onready var _ring: TextureRect = %Ring
@onready var _play: Button = %PlayButton


func _ready() -> void:
	_play.pressed.connect(_on_play)
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


func _on_play() -> void:
	Sfx.play("pop")
	play_pressed.emit()

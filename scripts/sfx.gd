extends Node
## Autoload "Sfx": fire-and-forget sound effects plus the looping music box.

const SOUNDS := {
	"pop": preload("res://assets/audio/pop.wav"),
	"plop": preload("res://assets/audio/plop.wav"),
	"fold": preload("res://assets/audio/fold.wav"),
	"whoosh": preload("res://assets/audio/whoosh.wav"),
	"boop": preload("res://assets/audio/boop.wav"),
	"sparkle": preload("res://assets/audio/sparkle.wav"),
	"win": preload("res://assets/audio/win.wav"),
}

var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.stream = preload("res://assets/audio/music_box.wav")
	_music.volume_db = -10.0
	_music.finished.connect(_music.play)
	add_child(_music)


func play(sound: String, pitch_jitter := 0.06, volume_db := 0.0) -> void:
	for p in _players:
		if not p.playing:
			p.stream = SOUNDS[sound]
			p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
			p.volume_db = volume_db
			p.play()
			return


func play_music() -> void:
	if not _music.playing:
		_music.play()

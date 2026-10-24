extends Node
## Autoload "Narration": finds the recording for a story line, if one has been added.
## Drop files named after the line's voice id into assets/narration/ (e.g. p02_a.ogg);
## every line and its id is listed in assets/narration/SCRIPT.md for recording.

const DIR := "res://assets/narration/"
const EXTENSIONS := ["ogg", "mp3", "wav"]


func find(id: String) -> AudioStream:
	if id == "":
		return null
	for ext in EXTENSIONS:
		var path := "%s%s.%s" % [DIR, id, ext]
		if ResourceLoader.exists(path):
			return load(path)
	return null

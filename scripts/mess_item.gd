extends Node2D
## One piece of mess from the Procreate art (a sock, a toy, the duvet...).
## kind "fold" = swipe to fold, kind "tap" = tap to tidy.

var id := ""
var kind := ""
var dest := ""
var base_z := 0
var home := Vector2.ZERO
var done := false
var on_floor := true
var closeup := ""  # full-resolution art for the folding close-up (clothes only)

var sprite := Sprite2D.new()
var _mask := BitMap.new()
var _size := Vector2.ZERO
var _lift_tween: Tween


func setup(data: Dictionary) -> void:
	id = data.id
	kind = data.kind
	dest = data.dest
	base_z = int(data.z)
	home = Vector2(data.pos[0], data.pos[1])
	on_floor = data.get("floor", true)
	position = home
	z_index = base_z
	sprite.texture = load(data.tex)
	add_child(sprite)
	closeup = data.get("closeup", "")
	var img := sprite.texture.get_image()
	if img.is_compressed():
		img.decompress()
	_mask.create_from_image_alpha(img, 0.15)
	_size = Vector2(img.get_size())


## Swaps the picture (e.g. for the folded version) and keeps sizes in sync.
func set_texture(tex: Texture2D) -> void:
	sprite.texture = tex
	_size = Vector2(tex.get_size())


func half_height() -> float:
	return _size.y * 0.5 * scale.y


## 0 for a direct hit on a painted pixel, up to `tol` for a near miss, INF for a miss.
func hit_distance(world: Vector2, tol: float) -> float:
	var local := world - global_position
	if not Rect2(-_size / 2, _size).grow(tol).has_point(local):
		return INF
	if _alpha_at(local):
		return 0.0
	for r in [tol * 0.5, tol]:
		for k in 8:
			if _alpha_at(local + Vector2.RIGHT.rotated(k * PI / 4.0) * r):
				return r
	return INF


func _alpha_at(local: Vector2) -> bool:
	var p := local + _size / 2
	if p.x < 0 or p.y < 0 or p.x >= _size.x or p.y >= _size.y:
		return false
	return _mask.get_bitv(Vector2i(p))


func lift() -> void:
	_scale_to(1.08, 0.08)


func drop() -> void:
	_scale_to(1.0, 0.12)


func _scale_to(s: float, t: float) -> void:
	if _lift_tween:
		_lift_tween.kill()
	_lift_tween = create_tween()
	_lift_tween.tween_property(self, "scale", Vector2(s, s), t).set_trans(Tween.TRANS_SINE)


func wiggle() -> void:
	var tw := create_tween()
	for a in [0.14, -0.12, 0.08, -0.05, 0.0]:
		tw.tween_property(self, "rotation", a, 0.07)

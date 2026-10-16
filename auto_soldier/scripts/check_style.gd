extends RefCounted
## メニューのチェックボックスの見た目：白い四角に、チェックすると黒いチェックが入る

const SIZE := 26

static var _unchecked: ImageTexture
static var _checked: ImageTexture


## チェックボックスに白い四角＋黒いチェックの見た目をつける
static func apply(c: CheckBox) -> void:
	if _unchecked == null:
		_unchecked = ImageTexture.create_from_image(_make(false))
		_checked = ImageTexture.create_from_image(_make(true))
	for n in ["unchecked", "unchecked_disabled"]:
		c.add_theme_icon_override(n, _unchecked)
	for n in ["checked", "checked_disabled"]:
		c.add_theme_icon_override(n, _checked)
	c.add_theme_color_override("icon_normal_color", Color.WHITE)
	c.add_theme_color_override("icon_pressed_color", Color.WHITE)
	c.add_theme_color_override("icon_hover_color", Color(0.9, 0.95, 1.0))
	c.add_theme_color_override("icon_hover_pressed_color", Color(0.9, 0.95, 1.0))
	c.add_theme_color_override("icon_focus_color", Color.WHITE)


static func _make(checked: bool) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# 白い四角（ふちは灰色）
	img.fill_rect(Rect2i(1, 1, SIZE - 2, SIZE - 2), Color(0.45, 0.45, 0.5))
	img.fill_rect(Rect2i(3, 3, SIZE - 6, SIZE - 6), Color.WHITE)
	if checked:
		# 黒いチェック（レの字）
		_line(img, Vector2(6, 13), Vector2(11, 19), 3.0)
		_line(img, Vector2(11, 19), Vector2(20, 7), 3.0)
	return img


static func _line(img: Image, a: Vector2, b: Vector2, w: float) -> void:
	for y in SIZE:
		for x in SIZE:
			var p := Vector2(x + 0.5, y + 0.5)
			var q := Geometry2D.get_closest_point_to_segment(p, a, b)
			if p.distance_to(q) <= w / 2.0:
				img.set_pixel(x, y, Color(0.05, 0.05, 0.05))

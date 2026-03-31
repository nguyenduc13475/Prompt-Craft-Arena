extends Control


func _ready():
	# 1. Background mờ
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.05, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 2. Text trạng thái Loading
	var lbl = Label.new()
	lbl.text = "ĐANG TẢI BẢN ĐỒ VÀ DỮ LIỆU TƯỚNG..."
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", Color.AQUA)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(lbl)

	# 3. Thanh tiến trình giả lập (Fake Progress)
	var progress = ProgressBar.new()
	progress.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	progress.position = Vector2(300, 800)  # Canh giữa theo size 1000x1000
	progress.size = Vector2(400, 30)
	add_child(progress)

	# Chạy Tween để thanh loading đầy lên từ từ trong 2.5 giây
	var tween = get_tree().create_tween()
	tween.tween_property(progress, "value", 100.0, 2.5)

	# 4. Khi đầy, tự động quăng vào màn Main
	tween.finished.connect(func(): get_tree().change_scene_to_file("res://scenes/Main.tscn"))

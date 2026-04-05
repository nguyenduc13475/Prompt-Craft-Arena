extends Control

var is_ready_to_switch = false


func _ready():
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.05, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var lbl = Label.new()
	lbl.text = "ĐANG TẢI BẢN ĐỒ VÀ DỮ LIỆU TƯỚNG..."
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", Color.AQUA)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(lbl)

	var progress = ProgressBar.new()
	progress.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	progress.position = Vector2(300, 800)
	progress.size = Vector2(400, 30)
	add_child(progress)

	var tween = get_tree().create_tween()
	tween.tween_property(progress, "value", 100.0, 2.0)
	tween.finished.connect(func(): is_ready_to_switch = true)


func _process(_delta):
	# Bỏ điều kiện check size > 0. Server sẽ stream data liên tục,
	# Main scene load xong nhận data rỗng (sương mù) cũng không sao.
	if is_ready_to_switch:
		set_process(false)
		get_tree().change_scene_to_file("res://scenes/Main.tscn")

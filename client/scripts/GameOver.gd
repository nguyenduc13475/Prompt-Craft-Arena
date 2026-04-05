extends Control


func _ready():
	# Tạo nền mờ đen
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.8)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.position = Vector2(250, 200)
	vbox.size = Vector2(500, 600)
	add_child(vbox)

	var lbl_title = Label.new()
	lbl_title.add_theme_font_size_override("font_size", 40)
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var winner = GameManager.get_meta("winner_team")
	lbl_title.text = "TRẬN ĐẤU KẾT THÚC\nTEAM " + str(winner) + " CHIẾN THẮNG!"
	lbl_title.modulate = Color.GOLD
	vbox.add_child(lbl_title)

	# Khoảng trắng
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer)

	var lbl_stats_title = Label.new()
	lbl_stats_title.text = "BẢNG XẾP HẠNG (K / D / A - VÀNG)"
	lbl_stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl_stats_title)

	# Bảng stats
	var stats_data = GameManager.get_meta("last_stats")
	if stats_data != null and stats_data is Array:
		for p in stats_data:
			var p_lbl = Label.new()
			p_lbl.text = (
				"[Team %d] %s: %d / %d / %d  - 💰 %d"
				% [p["team"], p["name"], p["k"], p["d"], p["a"], p["gold"]]
			)
			if p["team"] == winner:
				p_lbl.modulate = Color.CYAN
			vbox.add_child(p_lbl)

	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 50)
	vbox.add_child(spacer2)

	var btn_back = Button.new()
	btn_back.text = "QUAY LẠI SẢNH CHÍNH"
	btn_back.custom_minimum_size = Vector2(0, 60)
	# Thêm hiệu ứng màu cho nút nổi bật
	btn_back.modulate = Color(0.2, 1.0, 0.2)
	btn_back.pressed.connect(
		func():
			# Giải phóng hoàn toàn rác trước khi quay về sảnh
			GameManager.clear_all_objects()
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			get_tree().change_scene_to_file("res://scenes/HeroManager.tscn")
	)
	vbox.add_child(btn_back)

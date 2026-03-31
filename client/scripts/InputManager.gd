extends Node


func _unhandled_input(event):
	# Lấy tọa độ chuột thật trên bản đồ
	var mouse_pos = get_viewport().get_mouse_position()

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			NetworkManager.send_input("right", mouse_pos)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			# Check click Shop
			var clicked_shop = false
			for obj_id in GameManager._latest_server_data:
				var data = GameManager._latest_server_data[obj_id]
				if data.get("is_shop", false):
					if mouse_pos.distance_to(Vector2(data["coord"][0], data["coord"][1])) < 50:
						var ui = get_tree().current_scene.get_node_or_null("UILayer/Control")
						if ui and ui.has_method("open_shop"):
							ui.open_shop(obj_id, data["stock"])
						clicked_shop = true
						break
			if not clicked_shop:
				NetworkManager.send_input("left", mouse_pos)

	elif event is InputEventKey and event.pressed:
		var key_char = OS.get_keycode_string(event.keycode).to_upper()
		# Chặn Spam: Chỉ nhận các phím kỹ năng định sẵn
		if key_char in ["Q", "W", "E", "R", "1", "2", "3", "4", "5", "6"]:
			NetworkManager.send_input(key_char, mouse_pos)

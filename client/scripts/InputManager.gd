extends Node


func _unhandled_input(event):
	var mouse_pos = get_viewport().get_mouse_position()

	# Hệ thống ngắm mục tiêu 3D sang Map 2D Logic
	var game_coord = Vector2.ZERO
	var current_scene = get_tree().current_scene
	var camera = current_scene.get_node_or_null("Camera3D") if current_scene else null

	if camera:
		var ray_origin = camera.project_ray_origin(mouse_pos)
		var ray_dir = camera.project_ray_normal(mouse_pos)
		# Mặt phẳng sàn Y=0 (Vector3.UP)
		var floor_plane = Plane(Vector3.UP, 0)
		var hit_pos = floor_plane.intersects_ray(ray_origin, ray_dir)
		if hit_pos != null:
			# Map [x, z] của 3D sang [x, y] của Server Logic
			game_coord = Vector2(hit_pos.x, hit_pos.z)
	else:
		# Fallback nếu đang ở màn hình khác
		game_coord = mouse_pos

	# Xử lý xoay Camera bằng chuột giữa (Middle Mouse)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			GameManager.is_middle_mouse_pressed = event.pressed
	elif event is InputEventMouseMotion and GameManager.is_middle_mouse_pressed:
		GameManager.cam_yaw -= event.relative.x * 0.3
		GameManager.cam_pitch -= event.relative.y * 0.3
		# Khóa Pitch để không bị lật ngược camera (nhìn từ trên xuống hoặc ngang mặt)
		GameManager.cam_pitch = clamp(GameManager.cam_pitch, -89.0, -10.0)

	if event is InputEventMouseButton and event.pressed:
		# Bắt sự kiện cuộn chuột để điều chỉnh camera_zoom (giới hạn từ 0.2 xa đến 2.0 gần)
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			GameManager.camera_zoom = clamp(GameManager.camera_zoom - 0.1, 0.2, 2.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			GameManager.camera_zoom = clamp(GameManager.camera_zoom + 0.1, 0.2, 2.0)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# Triệt tiêu delay 3s, lập tức Snap Camera về hướng di chuyển của Hero
			GameManager.force_camera_snap()

			var is_space_held = Input.is_key_pressed(KEY_SPACE)
			if is_space_held:
				NetworkManager.send_custom(
					"right", {"coord": [game_coord.x, game_coord.y], "space_pressed": true}
				)
			else:
				NetworkManager.send_input("right", game_coord)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			# Check click Shop
			var clicked_shop = false
			for obj_id in GameManager._latest_server_data:
				var data = GameManager._latest_server_data[obj_id]
				if data.get("is_shop", false):
					if game_coord.distance_to(Vector2(data["coord"][0], data["coord"][1])) < 50:
						var ui = get_tree().current_scene.get_node_or_null("UILayer/Control")
						if ui and ui.has_method("open_shop"):
							ui.open_shop(obj_id, data["stock"])
						clicked_shop = true
						break
			if not clicked_shop:
				NetworkManager.send_input("left", game_coord)

	elif event is InputEventKey and event.pressed:
		var key_char = OS.get_keycode_string(event.keycode).to_upper()
		# Chặn Spam: Chỉ nhận các phím kỹ năng định sẵn
		if key_char in ["Q", "W", "E", "R", "1", "2", "3", "4", "5", "6"]:
			NetworkManager.send_input(key_char, game_coord)

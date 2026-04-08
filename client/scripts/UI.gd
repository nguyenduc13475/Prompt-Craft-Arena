extends Control

const MAP_REAL_SIZE = 1000.0
const MINIMAP_SIZE = 200.0

var draw_panel: Panel
var is_drawing = false
var draw_lines = []
var current_line: Line2D
var uploaded_ugc_url: String = ""
var http_upload: HTTPRequest

# --- RPG UI ---
var lbl_stats: Label
var inv_container: HBoxContainer
var shop_panel: Panel
var shop_list: VBoxContainer
var current_shop_id: String = ""

# --- HỆ THỐNG MINIMAP ---
var minimap_panel: Panel
var minimap_container: Control

# --- CHAT SYSTEM ---
var chat_log: RichTextLabel
var chat_input: LineEdit

@onready var prompt_input = find_child("PromptInput", true, false)
@onready var generate_btn = find_child("GenerateButton", true, false)


func open_shop(shop_id: String, stock: Array):
	current_shop_id = shop_id
	shop_panel.show()
	for child in shop_list.get_children():
		child.queue_free()
	for item in stock:
		var hbox = HBoxContainer.new()
		var lbl = Label.new()
		lbl.text = str(item.get("name", "Unknown")) + " (" + str(item.get("price", 0)) + "G)"
		lbl.custom_minimum_size = Vector2(150, 0)
		var btn = Button.new()
		btn.text = "Mua"
		btn.pressed.connect(
			func():
				NetworkManager.send_custom(
					"buy_item", {"shop_id": shop_id, "item_id": item.get("id", "")}
				)
		)
		hbox.add_child(lbl)
		hbox.add_child(btn)
		shop_list.add_child(hbox)


func _ready():
	# Mở lại InputManager bị khóa từ màn hình Login để người chơi điều khiển được tướng
	if has_node("/root/InputManager"):
		get_node("/root/InputManager").set_process_unhandled_input(true)

	# --- Dựng UI RPG thủ công ---
	lbl_stats = Label.new()
	lbl_stats.position = Vector2(10, 10)
	lbl_stats.add_theme_font_size_override("font_size", 18)
	lbl_stats.add_theme_color_override("font_color", Color.YELLOW)
	add_child(lbl_stats)

	inv_container = HBoxContainer.new()
	inv_container.position = Vector2(10, 850)  # Đáy màn hình
	add_child(inv_container)

	shop_panel = Panel.new()
	shop_panel.size = Vector2(300, 400)
	shop_panel.position = Vector2(650, 100)
	shop_panel.hide()
	add_child(shop_panel)

	var shop_title = Label.new()
	shop_title.text = "[ CỬA HÀNG ]"
	shop_panel.add_child(shop_title)

	var close_btn = Button.new()
	close_btn.text = "Đóng"
	close_btn.position = Vector2(250, 0)
	close_btn.pressed.connect(func(): shop_panel.hide())
	shop_panel.add_child(close_btn)

	shop_list = VBoxContainer.new()
	shop_list.position = Vector2(10, 40)
	shop_panel.add_child(shop_list)

	# --- KHUNG XƯƠNG CHAT BOX ---
	_setup_chatbox()

	var timer = Timer.new()
	timer.wait_time = 0.2
	timer.autostart = true
	timer.timeout.connect(_update_hud)
	add_child(timer)
	# -----------------------------

	_setup_minimap()

	# --- HỆ THỐNG HYDRATION NÂNG CAO CHO CUSTOM MAP DICTIONARY ---
	var map_config = GameManager.get_meta("map_config")
	if map_config != null:
		var current_scene = get_tree().current_scene
		var base_fallback_mat = StandardMaterial3D.new()  # Đổi tên để tránh conflict
		base_fallback_mat.uv1_scale = Vector3(1, 1, 1)
		base_fallback_mat.roughness = 0.95
		base_fallback_mat.metallic = 0.0
		base_fallback_mat.metallic_specular = 0.05

		# Hàm tải file chung cho cả ảnh lẫn model
		var download_or_cache = func(url_path: String, expected_hash: String, callback: Callable):
			var file_name = url_path.get_file()
			var cache_dir = "user://map_cache/"
			if not DirAccess.dir_exists_absolute(cache_dir):
				DirAccess.make_dir_recursive_absolute(cache_dir)

			var local_res_path = "res://assets/" + url_path
			var user_cache_path = cache_dir + file_name

			if ResourceLoader.exists(local_res_path):
				callback.call(local_res_path, true)
				return

			if FileAccess.file_exists(user_cache_path):
				var local_hash = FileAccess.get_md5(user_cache_path)
				if expected_hash == "" or local_hash == expected_hash:
					callback.call(user_cache_path, false)
					return

			# Tải mới
			print("[Hydration] Đang kéo tài nguyên từ Server: ", url_path)
			var req = HTTPRequest.new()
			add_child(req)
			req.request_completed.connect(
				func(_res, code, _hdrs, body):
					if code == 200:
						var file = FileAccess.open(user_cache_path, FileAccess.WRITE)
						file.store_buffer(body)
						file.close()
						callback.call(user_cache_path, false)
					else:
						print("[Lỗi] Hydration thất bại cho: ", url_path)
					req.queue_free()
			)
			req.request("http://127.0.0.1:8000/static/" + url_path)

		# 1. Ốp Model Đất (.glb) thay thế PlaneMesh cũ
		if map_config.has("ground_model") and map_config["ground_model"] != null:
			var h_model = map_config.get("hash_ground_model", "")
			download_or_cache.call(
				map_config["ground_model"],
				h_model,
				func(path, is_res):
					var gltf = GLTFDocument.new()
					var state = GLTFState.new()
					var err = OK
					var new_floor = null  # Biến cục bộ để không bị dính scope capture

					if is_res:
						var p_scene = load(path)
						if p_scene:
							new_floor = p_scene.instantiate()
					else:
						err = gltf.append_from_file(path, state)
						if err == OK:
							new_floor = gltf.generate_scene(state)

					if new_floor:
						new_floor.name = "Floor"  # Đổi tên TRƯỚC KHI add vào cây Node
						# Tự động căn giữa mặt đất cho mọi loại kích thước map (kể cả map quái thai)
						var map_s = map_config.get("map_size", [1000.0, 1000.0])
						new_floor.position = Vector3(map_s[0] / 2.0, 0, map_s[1] / 2.0)
						var old_mesh = current_scene.get_node_or_null("Floor")
						if old_mesh:
							old_mesh.queue_free()

						# [FIX] Dùng call_deferred để tránh lỗi Blocked Scene Tree khi _ready() đang chạy
						current_scene.add_child.call_deferred(new_floor)

						# Hàm đệ quy quét TẤT CẢ các mesh con (Dùng chung cho cả Shader lẫn Fallback)
						var apply_mat_to_meshes = func(
							node: Node, target_mat: Material, f_ref: Callable
						):
							if node is MeshInstance3D:
								node.material_override = target_mat
							for child in node.get_children():
								f_ref.call(child, target_mat, f_ref)

						# 2. Xử lý Shader và Texture sau khi Model tải xong
						if map_config.has("ground_shader"):
							var shader_mat = ShaderMaterial.new()
							var shader_path = map_config["ground_shader"]
							if ResourceLoader.exists(shader_path):
								shader_mat.shader = load(shader_path)

								shader_mat.set_shader_parameter(
									"map_size", Vector2(map_s[0], map_s[1])
								)

								# Đảm bảo có tint mặc định là trắng tinh để không bị đen (do Day/Night cycle)
								shader_mat.set_shader_parameter(
									"global_tint", Color(1.0, 1.0, 1.0, 1.0)
								)

								apply_mat_to_meshes.call(new_floor, shader_mat, apply_mat_to_meshes)

								# Tải HeightMap
								if map_config.has("height_map"):
									download_or_cache.call(
										map_config["height_map"],
										map_config.get("hash_height_map", ""),
										func(h_path, is_res_h):  # Đổi tên biến tránh trùng lặp
											var img = Image.new()
											var load_err = OK
											if is_res_h:
												var tex = load(h_path)
												if tex:
													img = tex.get_image()
												else:
													load_err = FAILED
											else:
												load_err = img.load(h_path)

											if load_err == OK and img and not img.is_empty():
												img.generate_mipmaps()
												shader_mat.set_shader_parameter(
													"height_map",
													ImageTexture.create_from_image(img)
												)
												GameManager.set_meta("height_map_img", img)
									)

								# Tải danh sách Texture 10K & Pedestal
								if (
									map_config.has("ground_texture")
									and typeof(map_config["ground_texture"]) == TYPE_ARRAY
								):
									var tex_list = map_config["ground_texture"]
									var hash_list = map_config.get("hash_ground_texture", [])

									for i in range(tex_list.size()):
										var expected_h = (
											hash_list[i] if i < hash_list.size() else ""
										)
										var param_name = ""
										if i == 0:
											param_name = "tex_ground_1"
										elif i == 1:
											param_name = "tex_ground_2"
										elif i == 2:
											param_name = "tex_pedestal"

										if param_name != "":
											# FIX CLOSURE: Dùng biến bound_param_name để chốt giá trị của vòng lặp hiện tại
											var cb_tex = func(t_path, is_res_t, bound_param_name):
												var tex: Texture2D
												if is_res_t:
													tex = load(t_path)
												else:
													var img = Image.new()
													if img.load(t_path) == OK:
														img.generate_mipmaps()
														tex = ImageTexture.create_from_image(img)
												if tex:
													shader_mat.set_shader_parameter(
														bound_param_name, tex
													)
											# Sử dụng .bind() để nối tham số vào Lambda
											download_or_cache.call(
												tex_list[i], expected_h, cb_tex.bind(param_name)
											)

						else:
							# Không dùng shader thì ốp fallback material bằng hàm đệ quy an toàn
							apply_mat_to_meshes.call(
								new_floor, base_fallback_mat, apply_mat_to_meshes
							)
			)

			var cache_dir = "user://map_cache/"
			if not DirAccess.dir_exists_absolute(cache_dir):
				DirAccess.make_dir_recursive_absolute(cache_dir)

			# --- TÍNH NĂNG QUÉT RÁC THÔNG MINH (DỌN PNG CŨ KHI CẬP NHẬT JPG MỚI) ---
			var active_map_files = []
			# Bổ sung đúng các key trong CONFIG_3LANE để tránh xóa nhầm file đang dùng
			for tex_key in [
				"ground",
				"displacement",
				"water",
				"swamp",
				"ground_model",
				"height_map",
				"background"
			]:
				if map_config.has(tex_key) and map_config[tex_key] != null:
					if typeof(map_config[tex_key]) == TYPE_STRING:
						active_map_files.append(map_config[tex_key].get_file())

			# Quét thêm Array ground_texture
			if (
				map_config.has("ground_texture")
				and typeof(map_config["ground_texture"]) == TYPE_ARRAY
			):
				for t in map_config["ground_texture"]:
					if typeof(t) == TYPE_STRING:
						active_map_files.append(t.get_file())

			var dir = DirAccess.open(cache_dir)
			if dir:
				dir.list_dir_begin()
				var file_name = dir.get_next()
				while file_name != "":
					if not dir.current_is_dir():
						if not file_name in active_map_files:
							dir.remove(file_name)
							print("[Client] Đã dọn dẹp file Map Cache cũ/rác: ", file_name)
					file_name = dir.get_next()
			# ----------------------------------------------------------------------

			# Hàm Hydration nâng cấp: Nhận vào expected_hash từ Server
			var apply_texture = func(
				url_path: String, is_displacement: bool, expected_hash: String = ""
			):
				var file_name = url_path.get_file()
				var local_res_path = "res://assets/" + url_path
				var user_cache_path = cache_dir + file_name

				var set_tex_to_mat = func(tex: Texture2D, raw_img: Image = null):
					if is_displacement:
						base_fallback_mat.heightmap_enabled = true
						base_fallback_mat.heightmap_texture = tex
						base_fallback_mat.heightmap_scale = 20.0  # Nâng nhẹ scale để đồi núi rõ hơn
						base_fallback_mat.heightmap_deep_parallax = true
					else:
						base_fallback_mat.albedo_texture = tex
						base_fallback_mat.normal_enabled = true
						base_fallback_mat.normal_scale = 1.2
						var img = raw_img if raw_img != null else tex.get_image()
						if img != null:
							var normal_img = img.duplicate()
							normal_img.bump_map_to_normal_map(3.0)
							base_fallback_mat.normal_texture = ImageTexture.create_from_image(
								normal_img
							)

				var need_download = true

				# 1. Ưu tiên resource có sẵn trong file build
				if ResourceLoader.exists(local_res_path):
					set_tex_to_mat.call(load(local_res_path))
					print("[Client] Đã ốp Texture từ Res: ", local_res_path)
					need_download = false

				# 2. Kiểm tra Cache và Hash
				elif FileAccess.file_exists(user_cache_path):
					var local_hash = FileAccess.get_md5(user_cache_path)
					if expected_hash == "" or local_hash == expected_hash:
						var img = Image.new()
						var err = img.load(user_cache_path)
						if err == OK:
							img.generate_mipmaps()  # FIX MIPMAP
							set_tex_to_mat.call(ImageTexture.create_from_image(img), img)
							print("[Client] Cache hợp lệ (Hash MATCH). Đã ốp từ: ", user_cache_path)
							need_download = false
						else:
							print("[Client] Lỗi đọc file cache, tiến hành tải lại.")
					else:
						print(
							"[Client] Hash MISMATCH! Bản đồ đã có bản cập nhật mới. Đang tải lại: ",
							url_path
						)

				# 3. Tải mới nếu thiếu hoặc sai Hash
				if need_download:
					print(
						"[Client] Hydration: Đang kéo texture từ Server (Co the ton vai giay cho file >10MB) -> ",
						url_path
					)
					var req = HTTPRequest.new()
					add_child(req)
					req.request_completed.connect(
						func(_res, code, _hdrs, body):
							if code == 200:
								# Ghi file xuống ổ cứng trước
								var file = FileAccess.open(user_cache_path, FileAccess.WRITE)
								file.store_buffer(body)
								file.close()

								# FIX BUG LỚN: Thay vì ép kiểu PNG (load_png_from_buffer),
								# ta load thẳng từ file trên đĩa để Godot tự nhận diện định dạng (JPG, WEBP, PNG)
								var img = Image.new()
								var err = img.load(user_cache_path)
								if err == OK:
									img.generate_mipmaps()  # FIX MIPMAP
									set_tex_to_mat.call(ImageTexture.create_from_image(img), img)
									print(
										"[Client] Hydration thành công & Đã lưu Cache mới: ",
										file_name
									)
								else:
									print("[Client] Lỗi giải mã hình ảnh tải về. Mã lỗi: ", err)
							else:
								print("[Client] Lỗi Hydration tải Map: Code ", code)
							req.queue_free()
					)
					req.request("http://127.0.0.1:8000/static/" + url_path)

			# Gọi hàm ốp ảnh Base Ground, truyền kèm Hash Server gửi xuống
			if map_config.has("ground") and map_config["ground"] != null:
				var h_ground = map_config.get("hash_ground", "")
				apply_texture.call(map_config["ground"], false, h_ground)

			# Gọi hàm ốp ảnh Nhấp nhô (nếu có)
			if map_config.has("displacement") and map_config["displacement"] != null:
				var h_disp = map_config.get("hash_displacement", "")
				apply_texture.call(map_config["displacement"], true, h_disp)

			# 4. Ốp Skybox Background (Không gian vô cực bên ngoài map)
			if map_config.has("background") and map_config["background"] != null:
				var h_bg = map_config.get("hash_background", "")
				download_or_cache.call(
					map_config["background"],
					h_bg,
					func(bg_path, is_res_bg):
						var tex: Texture2D
						if is_res_bg:
							tex = load(bg_path)
						else:
							var img = Image.new()
							if img.load(bg_path) == OK:
								img.generate_mipmaps()
								tex = ImageTexture.create_from_image(img)
						if tex:
							var env_node = current_scene.get_node_or_null("WorldEnvironment")
							if env_node and env_node.environment:
								var sky_mat = PanoramaSkyMaterial.new()
								sky_mat.panorama = tex
								var sky = Sky.new()
								sky.sky_material = sky_mat
								env_node.environment.background_mode = Environment.BG_SKY
								env_node.environment.sky = sky
								print("[Client] Đã ốp Background Panorama thành công!")
				)

	if generate_btn:
		generate_btn.pressed.connect(_on_generate_pressed)
		self.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vbox = find_child("VBoxContainer", true, false)
	if vbox:
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	http_upload = HTTPRequest.new()
	add_child(http_upload)
	http_upload.request_completed.connect(_on_upload_completed)

	_setup_ugc_canvas()


func _setup_ugc_canvas():
	var toggle_btn = Button.new()
	toggle_btn.text = "✏️ Mở bảng vẽ kỹ năng"
	var save_ugc_btn = Button.new()
	save_ugc_btn.text = "💾 Lưu & Tải lên máy chủ"

	var vbox = find_child("VBoxContainer", true, false)
	if vbox:
		vbox.add_child(toggle_btn)
		vbox.move_child(toggle_btn, 0)  # Đẩy lên vị trí đầu tiên của thanh menu cho dễ nhìn
		vbox.add_child(save_ugc_btn)
	else:
		add_child(toggle_btn)
		add_child(save_ugc_btn)
		toggle_btn.position = Vector2(10, 10)
		save_ugc_btn.position = Vector2(10, 50)

	draw_panel = Panel.new()
	draw_panel.size = Vector2(400, 400)
	# Ép bảng vẽ ra giữa màn hình, tránh lọt ra ngoài hoặc bị che mất
	draw_panel.position = Vector2(300, 200)
	draw_panel.hide()
	draw_panel.clip_contents = true  # Ngăn nét vẽ lòi ra ngoài viền

	# Tạo viền nổi bật để biết chắc chắn nó đã mở
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.95)
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_color = Color.AQUA
	draw_panel.add_theme_stylebox_override("panel", style)

	# Thêm trực tiếp vào gốc của UI thay vì trỏ ra cha
	self.add_child(draw_panel)

	# Tách hẳn signal ra thành hàm tường minh
	toggle_btn.pressed.connect(_on_toggle_btn_pressed)
	save_ugc_btn.pressed.connect(_on_save_ugc_pressed)
	draw_panel.gui_input.connect(_on_draw_panel_input)


func _on_toggle_btn_pressed():
	draw_panel.visible = not draw_panel.visible


func _on_draw_panel_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_drawing = true
				current_line = Line2D.new()
				current_line.width = 15.0
				current_line.default_color = Color.AQUA
				current_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
				current_line.end_cap_mode = Line2D.LINE_CAP_ROUND
				draw_panel.add_child(current_line)
				draw_lines.append(current_line)

				# QUAN TRỌNG: Cắm bút vào tọa độ hiện tại ngay khi chạm chuột
				current_line.add_point(event.position)
			else:
				is_drawing = false
	elif event is InputEventMouseMotion and is_drawing:
		current_line.add_point(event.position)


func _on_save_ugc_pressed():
	if not draw_panel.visible:
		print("Vui lòng mở Canvas và vẽ trước!")
		return

	print("Đang chụp hình UGC...")
	# Phải đợi engine vẽ xong khung hình mới được chụp để không bị đen màn
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	var region = Rect2i(
		int(draw_panel.global_position.x),
		int(draw_panel.global_position.y),
		int(draw_panel.size.x),
		int(draw_panel.size.y)
	)
	var cropped_img = img.get_region(region)

	var buffer = cropped_img.save_png_to_buffer()
	var base64_str = Marshalls.raw_to_base64(buffer)

	var payload = {"image_base64": base64_str, "folder": "vfx"}
	var json_str = JSON.stringify(payload)
	http_upload.request(
		"http://127.0.0.1:8000/api/uploads/base64",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		json_str
	)


func _update_hud():
	_draw_minimap()  # Cập nhật các chấm trên bản đồ nhỏ
	if not GameManager._latest_server_data:
		return
	# Tìm hero của mình bằng cách vét (hack tạm vì client chưa lưu cứng ID của object mình)
	for obj_id in GameManager._latest_server_data:
		var data = GameManager._latest_server_data[obj_id]
		if data.has("inventory") and not data.get("is_shop"):
			# Rất bẩn nhưng hiệu quả: nếu mảng kho đồ đổi số lượng, ta rải lại nút
			lbl_stats.text = (
				"Lvl: %d | 💰 %d\nK/D/A: %d / %d / %d"
				% [
					int(data.get("level", 1)),
					int(data.get("gold", 0)),
					int(data.get("kills", 0)),
					int(data.get("deaths", 0)),
					int(data.get("assists", 0))
				]
			)

			if inv_container.get_child_count() != data.get("inventory", []).size():
				for c in inv_container.get_children():
					c.queue_free()
				var idx = 0
				for item in data.get("inventory", []):
					var btn = Button.new()
					btn.text = item.name
					btn.custom_minimum_size = Vector2(80, 80)
					var c_idx = idx
					btn.gui_input.connect(
						func(ev):
							if ev is InputEventMouseButton and ev.pressed:
								if ev.button_index == MOUSE_BUTTON_LEFT:
									NetworkManager.send_custom("use_item", {"item_idx": c_idx})
								elif ev.button_index == MOUSE_BUTTON_RIGHT and shop_panel.visible:
									NetworkManager.send_custom(
										"sell_item", {"shop_id": current_shop_id, "item_idx": c_idx}
									)
					)
					inv_container.add_child(btn)
					idx += 1
			break


func _on_upload_completed(_result, response_code, _headers, body):
	if response_code == 200:
		var res = JSON.parse_string(body.get_string_from_utf8())
		uploaded_ugc_url = res["url"]
		print("Đã tải UGC lên máy chủ thành công! URL: ", uploaded_ugc_url)
		draw_panel.hide()  # Tự động đóng bảng vẽ lại sau khi lưu xong
	else:
		print("Lỗi tải lên UGC: ", response_code, body.get_string_from_utf8())


func _on_generate_pressed():
	var text = prompt_input.text
	if text != "":
		HeroAPIService.create_and_save_hero(
			"Hero_InMatch_" + str(randi() % 100), text, uploaded_ugc_url
		)
		prompt_input.text = ""
		prompt_input.release_focus()


func _setup_minimap():
	minimap_panel = Panel.new()
	minimap_panel.size = Vector2(MINIMAP_SIZE, MINIMAP_SIZE)
	# Góc phải dưới, canh theo size 1000x1000
	minimap_panel.position = Vector2(800 - MINIMAP_SIZE, 1000 - MINIMAP_SIZE)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_color = Color.DARK_GRAY
	minimap_panel.add_theme_stylebox_override("panel", style)

	minimap_container = Control.new()
	minimap_container.size = minimap_panel.size
	minimap_panel.add_child(minimap_container)

	# Lắng nghe sự kiện click trên minimap
	minimap_panel.gui_input.connect(_on_minimap_input)

	add_child(minimap_panel)


func _on_minimap_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Quy đổi từ tọa độ Minimap (0->200) ra tọa độ World (0->1000)
			var local_pos = event.position
			var ratio = MAP_REAL_SIZE / MINIMAP_SIZE
			var world_x = local_pos.x * ratio
			var world_y = local_pos.y * ratio

			# Gửi lệnh click chuột phải (di chuyển) lên Server với tọa độ mới
			NetworkManager.send_input("right", Vector2(world_x, world_y))


func _draw_minimap():
	if not GameManager._latest_server_data:
		return

	# Xóa các chấm cũ
	for child in minimap_container.get_children():
		child.queue_free()

	var ratio = MINIMAP_SIZE / MAP_REAL_SIZE

	for obj_id in GameManager._latest_server_data:
		var data = GameManager._latest_server_data[obj_id]
		if data.has("coord"):
			var dot = ColorRect.new()
			# Mặc định Trắng, Team 1 Xanh, Team 2 Đỏ, Team 3 (Quái/Thiên thạch) Vàng
			dot.color = Color.WHITE
			if data.get("team") == 1:
				dot.color = Color.DODGER_BLUE
			elif data.get("team") == 2:
				dot.color = Color.CRIMSON
			elif data.get("team") == 3:
				dot.color = Color.YELLOW

			# Kích thước chấm trên minimap
			dot.size = Vector2(4, 4) if not data.get("is_shop") else Vector2(8, 8)

			var mx = data["coord"][0] * ratio
			var my = data["coord"][1] * ratio
			dot.position = Vector2(mx - dot.size.x / 2, my - dot.size.y / 2)
			minimap_container.add_child(dot)


func _setup_chatbox():
	var chat_panel = Panel.new()
	chat_panel.size = Vector2(300, 200)
	chat_panel.position = Vector2(10, 600)  # Nằm góc dưới bên trái, trên inventory

	# Làm mờ nền chat
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.5)
	chat_panel.add_theme_stylebox_override("panel", style)

	chat_log = RichTextLabel.new()
	chat_log.size = Vector2(280, 150)
	chat_log.position = Vector2(10, 10)
	chat_log.scroll_following = true
	chat_log.bbcode_enabled = true
	chat_panel.add_child(chat_log)

	chat_input = LineEdit.new()
	chat_input.size = Vector2(280, 30)
	chat_input.position = Vector2(10, 165)
	chat_input.placeholder_text = "Nhấn Enter để chat..."
	chat_input.gui_input.connect(_on_chat_input_gui)
	chat_panel.add_child(chat_input)

	add_child(chat_panel)


func _on_chat_input_gui(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		var text = chat_input.text.strip_edges()
		if text != "":
			# Mặc định in-game là chat room
			NetworkManager.send_custom(
				"chat", {"message": text, "sender": AuthManager.username, "channel": "room"}
			)
			chat_input.text = ""
		# Reset focus để tiếp tục chơi
		chat_input.release_focus()


func receive_chat(sender: String, message: String, channel: String):
	var color_tag = "[color=yellow]" if channel == "room" else "[color=gray]"
	chat_log.text += color_tag + "[" + sender + "]:[/color] " + message + "\n"

extends Control

var lbl_welcome: Label
var lbl_coins: Label
var opt_model_select: OptionButton
var btn_matchmaking: Button

# UI Chi Tiết Hero
var txt_edit_name: LineEdit
var opt_edit_model: OptionButton
var txt_readonly_prompt: TextEdit
var opt_prompt_code: OptionButton
var item_list_skins: ItemList
var opt_new_skin: OptionButton
var btn_add_skin: Button
var btn_save_changes: Button

var current_editing_hero_id: String = ""
var full_hero_list = []
var current_hero_prompt: String = ""
var current_hero_code: String = ""
var current_hero_skins: Array = []

var preview_root: Node3D
var anim_vbox: VBoxContainer
var preview_cam: Camera3D


func _ready():
	# --- TẠO BACKGROUND ĐỘNG ---
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -1
	var mat = ShaderMaterial.new()
	mat.shader = load("res://assets/bg_animated.gdshader")
	bg.material = mat
	add_child(bg)
	move_child(bg, 0)
	# ---------------------------

	# Tìm node an toàn bất chấp cấu trúc lồng nhau
	lbl_welcome = find_child("LblWelcome", true, true)
	lbl_coins = find_child("LblCoins", true, true)
	opt_model_select = find_child("OptModelSelect", true, true)
	btn_matchmaking = find_child("BtnGoToMatchmaking", true, true)

	if lbl_welcome:
		lbl_welcome.text = (
			"Chào " + (AuthManager.username if AuthManager.username != "" else "Khách")
		)

	var btn_logout = find_child("BtnLogout", true, true)
	if btn_logout:
		btn_logout.pressed.connect(func(): AuthManager.logout())
	if lbl_coins:
		lbl_coins.text = "💰 Tiền: " + str(AuthManager.coins) + " xu"

	# Tìm và khởi tạo UI Chi Tiết
	txt_edit_name = find_child("TxtEditName", true, true)
	opt_edit_model = find_child("OptEditModel", true, true)
	txt_readonly_prompt = find_child("TxtReadonlyPrompt", true, true)
	btn_save_changes = find_child("BtnSaveChanges", true, true)
	opt_prompt_code = find_child("OptPromptCode", true, true)
	item_list_skins = find_child("ItemListSkins", true, true)
	opt_new_skin = find_child("OptNewSkin", true, true)
	btn_add_skin = find_child("BtnAddSkin", true, true)

	HeroAPIService.default_models_loaded.connect(_on_default_models_loaded)
	HeroAPIService.load_default_models()

	if opt_prompt_code:
		opt_prompt_code.item_selected.connect(_on_prompt_code_toggled)

	if btn_add_skin:
		btn_add_skin.pressed.connect(_on_add_skin_pressed)

	_setup_3d_preview()

	if btn_save_changes:
		btn_save_changes.pressed.connect(
			func():
				if current_editing_hero_id != "":
					var new_name = txt_edit_name.text.strip_edges()
					var model_url = opt_edit_model.get_item_metadata(opt_edit_model.selected)
					if new_name != "":
						btn_save_changes.text = "ĐANG LƯU..."
						btn_save_changes.disabled = true

						# Gom danh sách skin lại để gửi lên server
						var skins_to_save = []
						for i in range(item_list_skins.get_item_count()):
							skins_to_save.append(item_list_skins.get_item_metadata(i))

						# Tạm dùng HTTPRequest gửi tay vì HeroAPIService chưa support params skins
						var payload = {
							"name": new_name, "model_url": model_url, "skins": skins_to_save
						}
						var body = JSON.stringify(payload)
						var headers = AuthManager.get_auth_header()
						headers.append("Content-Type: application/json")

						var req = HTTPRequest.new()
						add_child(req)
						req.request_completed.connect(
							func(_res, _code, _hdrs, _body):
								btn_save_changes.text = "LƯU THAY ĐỔI"
								btn_save_changes.disabled = false
								HeroAPIService.load_my_heroes()
								req.queue_free()
						)
						req.request(
							"http://127.0.0.1:8000/api/heroes/" + current_editing_hero_id,
							headers,
							HTTPClient.METHOD_PUT,
							body
						)
		)

	HeroAPIService.hero_updated_success.connect(
		func(_hero_dto):
			if btn_save_changes:
				btn_save_changes.text = "LƯU THAY ĐỔI"
				btn_save_changes.disabled = false
			HeroAPIService.load_my_heroes()  # Reload list
	)

	# --- TÍNH NĂNG UPLOAD SKIN ---
	var btn_upload_skin = Button.new()
	btn_upload_skin.text = "Tải Skin từ máy (.glb)"
	if find_child("HBoxAddSkin", true, true):
		find_child("HBoxAddSkin", true, true).add_child(btn_upload_skin)

	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.add_filter("*.glb", "3D Models")
	add_child(file_dialog)

	btn_upload_skin.pressed.connect(func(): file_dialog.popup_centered_ratio(0.6))

	file_dialog.file_selected.connect(
		func(path: String):
			print("Đang tải model lên server: ", path)
			var req = HTTPRequest.new()
			add_child(req)
			var file = FileAccess.open(path, FileAccess.READ)
			var buffer = file.get_buffer(file.get_length())
			var body = PackedByteArray()
			var boundary = "----WebKitFormBoundary" + str(randi())
			body.append_array(("--" + boundary + "\r\n").to_utf8_buffer())
			body.append_array(
				(
					('Content-Disposition: form-data; name="file"; filename="upload.glb"\r\n')
					. to_utf8_buffer()
				)
			)
			body.append_array(("Content-Type: model/gltf-binary\r\n\r\n").to_utf8_buffer())
			body.append_array(buffer)
			body.append_array(("\r\n--" + boundary + "--\r\n").to_utf8_buffer())

			var headers = ["Content-Type: multipart/form-data; boundary=" + boundary]
			req.request_completed.connect(
				func(_res, code, _hdrs, res_body):
					if code == 200:
						var json = JSON.parse_string(res_body.get_string_from_utf8())
						var url = json.get("url")
						var s_name = path.get_file().get_basename() + " (Custom)"
						item_list_skins.add_item(s_name)
						item_list_skins.set_item_metadata(item_list_skins.get_item_count() - 1, url)
						print("Tải skin thành công!")
					else:
						print("Lỗi tải skin: ", res_body.get_string_from_utf8())
					req.queue_free()
			)
			req.request(
				"http://127.0.0.1:8000/api/uploads/model", headers, HTTPClient.METHOD_POST, body
			)
	)

	# Gắn sự kiện cho nút Tạo Hero bằng AI
	var btn_generate = find_child("BtnGenerateAndSave", true, true)
	var txt_name = find_child("TxtNewHeroName", true, true)
	var txt_prompt = find_child("TxtPrompt", true, true)

	if btn_generate and txt_name and txt_prompt:
		btn_generate.pressed.connect(
			func():
				var h_name = txt_name.text.strip_edges()
				var prompt = txt_prompt.text.strip_edges()
				if h_name != "" and prompt != "":
					HeroAPIService.create_and_save_hero(h_name, prompt, "")
					btn_generate.text = "ĐANG TẠO BẰNG GEMINI..."
					btn_generate.disabled = true
		)

	# Lắng nghe kết quả từ Server AI trả về
	HeroAPIService.hero_created_success.connect(
		func(hero_dto):
			if btn_generate:
				btn_generate.text = "💾 GỌI GEMINI & LƯU TƯỚNG"
				btn_generate.disabled = false
			# Tự động gán Hero vừa tạo làm Hero chiến đấu
			GameManager.selected_battle_hero_id = hero_dto["id"]
			GameManager.selected_battle_hero_name = hero_dto["name"]
			print("Đã chọn Hero: ", hero_dto["name"])
			if btn_matchmaking:
				btn_matchmaking.disabled = false
			# Tự động làm mới danh sách Tướng bên trái
			HeroAPIService.load_my_heroes()
	)

	# Lắng nghe LỖI từ Server AI để nhả nút bấm và báo lỗi
	HeroAPIService.api_error.connect(
		func(error_msg):
			if btn_generate:
				btn_generate.text = "❌ LỖI: " + str(error_msg) + " (THỬ LẠI)"
				btn_generate.disabled = false
	)

	# Mở khóa nút và nối Scene
	if btn_matchmaking:
		# Nút này ban đầu nên tắt, chờ có Hero mới được bấm
		btn_matchmaking.pressed.connect(
			func(): get_tree().change_scene_to_file("res://scenes/Lobby.tscn")
		)

	# --- TẢI DANH SÁCH HERO TỪ SERVER ---
	HeroAPIService.heroes_list_loaded.connect(_on_heroes_loaded)
	HeroAPIService.load_my_heroes()

	# KẾT NỐI NGẦM TRƯỚC VỚI SERVER ĐỂ TRÁNH RACE-CONDITION TẠI LOBBY
	if NetworkManager.websocket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		NetworkManager.connect_to_server()

	print("[UI] Hero Manager sẵn sàng!")


func _setup_3d_preview():
	var chi_tiet_tab = find_child("Chi Tiết Hero", true, true)
	if not chi_tiet_tab:
		return
	var vbox = chi_tiet_tab.get_node_or_null("VBoxContainer")
	if not vbox:
		return

	var preview_container = HBoxContainer.new()
	preview_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(preview_container)
	# Đẩy khung 3D lên ngay phía trên Nút "LƯU THAY ĐỔI"
	vbox.move_child(preview_container, vbox.get_child_count() - 2)

	var viewport_container = SubViewportContainer.new()
	viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL  # FIX: Ép không cho tràn Tab
	viewport_container.stretch = true
	preview_container.add_child(viewport_container)

	var viewport = SubViewport.new()
	viewport.transparent_bg = true
	viewport_container.add_child(viewport)

	preview_cam = Camera3D.new()
	preview_cam.position = Vector3(0, 2.5, 7.0)  # FIX: Lùi camera ra xa hơn để thấy toàn bộ model
	preview_cam.rotation_degrees = Vector3(-15, 0, 0)  # Hơi cúi góc nhìn xuống một chút
	viewport.add_child(preview_cam)

	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, 45, 0)
	viewport.add_child(light)

	preview_root = Node3D.new()
	viewport.add_child(preview_root)

	# FIX: Dùng ScrollContainer bọc ngoài danh sách Animation để cuộn mượt mà
	var anim_scroll = ScrollContainer.new()
	anim_scroll.custom_minimum_size = Vector2(200, 0)
	anim_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_container.add_child(anim_scroll)

	anim_vbox = VBoxContainer.new()
	anim_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	anim_scroll.add_child(anim_vbox)

	# Xử lý Xoay (Chuột trái), Tịnh tiến (Chuột phải), và Zoom (Con lăn)
	var cam_state = {
		"drag_left": false, "drag_right": false, "dist": 7.0, "pan_x": 0.0, "pan_y": 2.5
	}
	viewport_container.gui_input.connect(
		func(event):
			if event is InputEventMouseButton:
				if event.button_index == MOUSE_BUTTON_LEFT:
					cam_state["drag_left"] = event.pressed
				elif event.button_index == MOUSE_BUTTON_RIGHT:
					cam_state["drag_right"] = event.pressed
				elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
					cam_state["dist"] = max(2.0, cam_state["dist"] - 0.5)
					preview_cam.position.z = cam_state["dist"]
				elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					cam_state["dist"] = min(15.0, cam_state["dist"] + 0.5)
					preview_cam.position.z = cam_state["dist"]
			elif event is InputEventMouseMotion:
				if cam_state["drag_left"]:
					preview_root.rotation.y -= event.relative.x * 0.01
					preview_root.rotation.x -= event.relative.y * 0.01
					preview_root.rotation.x = clamp(preview_root.rotation.x, -1.0, 1.0)  # Nới rộng góc cúi/ngửa
				elif cam_state["drag_right"]:
					# Tịnh tiến camera (Pan)
					cam_state["pan_x"] -= event.relative.x * 0.005
					cam_state["pan_y"] += event.relative.y * 0.005
					preview_cam.position.x = cam_state["pan_x"]
					preview_cam.position.y = cam_state["pan_y"]
	)

	# Khi chọn model khác, tự động load lại preview
	if opt_edit_model:
		opt_edit_model.item_selected.connect(
			func(idx):
				var url = opt_edit_model.get_item_metadata(idx)
				_load_preview_model(url)
		)


func _on_default_models_loaded(models: Array):
	if opt_model_select:
		opt_model_select.clear()
	if opt_edit_model:
		opt_edit_model.clear()
	if opt_new_skin:
		opt_new_skin.clear()

	for i in range(models.size()):
		var m = models[i]
		if opt_model_select:
			opt_model_select.add_item(m.name)
			opt_model_select.set_item_metadata(i, m.url)
		if opt_edit_model:
			opt_edit_model.add_item(m.name)
			opt_edit_model.set_item_metadata(i, m.url)
		if opt_new_skin:
			opt_new_skin.add_item(m.name)
			opt_new_skin.set_item_metadata(i, m.url)


func _on_prompt_code_toggled(index: int):
	if index == 0:
		txt_readonly_prompt.text = current_hero_prompt
	else:
		txt_readonly_prompt.text = current_hero_code


func _on_add_skin_pressed():
	if opt_new_skin.get_item_count() > 0:
		var skin_name = opt_new_skin.get_item_text(opt_new_skin.selected)
		var skin_url = opt_new_skin.get_item_metadata(opt_new_skin.selected)

		# Tránh add trùng
		for i in range(item_list_skins.get_item_count()):
			if item_list_skins.get_item_metadata(i) == skin_url:
				return

		item_list_skins.add_item(skin_name)
		item_list_skins.set_item_metadata(item_list_skins.get_item_count() - 1, skin_url)


func _load_preview_model(url: String):
	if not preview_root or not anim_vbox:
		return

	for c in preview_root.get_children():
		c.queue_free()
	for c in anim_vbox.get_children():
		c.queue_free()

	var lbl = Label.new()
	lbl.text = "Đang tải 3D..."
	anim_vbox.add_child(lbl)

	# Định nghĩa hàm helper để tạo nút Animation (dùng chung cho cả Local và HTTP)
	var setup_anims = func(scene_node):
		if is_instance_valid(lbl):
			lbl.queue_free()
		preview_root.add_child(scene_node)
		var player = _find_animation_player(scene_node)
		if player:
			var title = Label.new()
			title.text = "- ANIMATIONS -"
			title.modulate = Color.CYAN
			anim_vbox.add_child(title)
			for anim_name in player.get_animation_list():
				var btn = Button.new()
				btn.text = "▶ " + anim_name
				btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
				btn.pressed.connect(func(): player.play(anim_name))
				anim_vbox.add_child(btn)

	# --- RẼ NHÁNH XỬ LÝ URL ---
	if url.begins_with("res://"):
		if ResourceLoader.exists(url):
			var packed_scene = load(url)
			if packed_scene:
				setup_anims.call(packed_scene.instantiate())
		else:
			lbl.text = "Lỗi: Không tìm thấy file local!"
		return

	# Xử lý HTTP cho model tạo từ AI hoặc User Upload
	var req = HTTPRequest.new()
	add_child(req)
	var full_url = "http://127.0.0.1:8000" + url
	req.request_completed.connect(
		func(_res, code, _hdrs, body):
			if code == 200:
				var doc = GLTFDocument.new()
				var state = GLTFState.new()
				var err = doc.append_from_buffer(body, "", state)
				if err == OK:
					setup_anims.call(doc.generate_scene(state))
			else:
				if is_instance_valid(lbl):
					lbl.text = "Lỗi tải Model HTTP!"
			req.queue_free()
	)
	req.request(full_url)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found = _find_animation_player(child)
		if found:
			return found
	return null


func _on_heroes_loaded(heroes):
	full_hero_list = heroes
	var container = find_child("HeroListContainer", true, true)
	if not container:
		return

	# Xóa danh sách cũ để cập nhật lại
	for c in container.get_children():
		c.queue_free()

	# Đổ dữ liệu Hero thành các Nút bấm
	for h in heroes:
		var btn = Button.new()
		btn.text = h["name"]
		btn.custom_minimum_size = Vector2(0, 50)
		btn.pressed.connect(
			func():
				GameManager.selected_battle_hero_id = h["id"]
				GameManager.selected_battle_hero_name = h["name"]
				GameManager.selected_battle_hero_model = h.get(
					"model_url", "/static/default_assets/mannequin.glb"
				)
				GameManager.selected_battle_hero_skins = h.get("skins", [])
				print("Đã chọn Hero: ", h["name"])
				if btn_matchmaking:
					btn_matchmaking.disabled = false
				# Đổi màu nút để hiển thị trạng thái đang chọn
				for b in container.get_children():
					b.modulate = Color.WHITE
				btn.modulate = Color.GREEN

				# Điền dữ liệu vào Tab Chi tiết
				# Điền dữ liệu vào Tab Chi tiết
				current_editing_hero_id = h["id"]
				current_hero_prompt = h["prompt"]
				current_hero_code = h.get("code", "Không có mã nguồn (Lỗi sinh code).")
				current_hero_skins = h.get("skins", [])

				if txt_edit_name:
					txt_edit_name.text = h["name"]
				if txt_readonly_prompt:
					# Gọi lại hàm toggle để update text theo trạng thái dropdown hiện tại
					_on_prompt_code_toggled(opt_prompt_code.selected if opt_prompt_code else 0)

				# Render danh sách Skins
				if item_list_skins:
					item_list_skins.clear()
					for skin_data in current_hero_skins:
						var s_name = ""
						var s_url = ""
						if typeof(skin_data) == TYPE_STRING:
							s_url = skin_data
							s_name = s_url.get_file().get_basename()
						else:
							s_url = skin_data.get("url", "")
							s_name = skin_data.get("name", s_url.get_file().get_basename())

						item_list_skins.add_item(s_name)
						item_list_skins.set_item_metadata(
							item_list_skins.get_item_count() - 1, s_url
						)

				var model_to_load = h.get("model_url")
				if model_to_load == null or model_to_load == "":
					model_to_load = "/static/default_assets/mannequin.glb"

				# Đồng bộ Dropdown Box về đúng model đang lưu trên Server
				if opt_edit_model:
					for idx in range(opt_edit_model.get_item_count()):
						if opt_edit_model.get_item_metadata(idx) == model_to_load:
							opt_edit_model.select(idx)
							break

				# Tải model vào Khung 3D Viewport mới tạo
				_load_preview_model(model_to_load)

				# Tự động chuyển qua tab Chi Tiết Hero
				var tab_container = find_child("TabContainer", true, true)
				if tab_container:
					tab_container.current_tab = 1  # Tab thứ 2 là Chi Tiết
		)
		container.add_child(btn)

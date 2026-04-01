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

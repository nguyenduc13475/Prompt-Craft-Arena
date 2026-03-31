extends Control

var lbl_welcome: Label
var lbl_coins: Label
var opt_model_select: OptionButton
var btn_matchmaking: Button


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

	if opt_model_select:
		opt_model_select.add_item("Ma-nơ-canh (Miễn phí)")
		opt_model_select.set_item_metadata(0, "/static/default_assets/mannequin.glb")

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

	print("[UI] Hero Manager sẵn sàng!")


func _on_heroes_loaded(heroes):
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
				print("Đã chọn Hero: ", h["name"])
				if btn_matchmaking:
					btn_matchmaking.disabled = false
				# Đổi màu nút để hiển thị trạng thái đang chọn
				for b in container.get_children():
					b.modulate = Color.WHITE
				btn.modulate = Color.GREEN
		)
		container.add_child(btn)

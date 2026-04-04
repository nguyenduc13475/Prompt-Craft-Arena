extends Control

var spin_min: SpinBox
var spin_max: SpinBox

@onready var btn_aram = $VBoxContainer/BtnARAM
@onready var btn_3lane = $VBoxContainer/Btn3Lane
@onready var btn_random = $VBoxContainer/BtnRandom
@onready var status_label = $VBoxContainer/StatusLabel


func _ready():
	# Xóa nền tĩnh (nếu có) và áp dụng Shader nền động
	if has_node("ColorRect"):
		$ColorRect.queue_free()

	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -1
	var mat = ShaderMaterial.new()
	mat.shader = load("res://assets/bg_animated.gdshader")
	bg.material = mat
	add_child(bg)
	move_child(bg, 0)

	var ws_state = NetworkManager.websocket.get_ready_state()
	if ws_state == WebSocketPeer.STATE_CLOSED:
		NetworkManager.connect_to_server()
		status_label.text = "Đang kết nối lại Server Game..."
		_disable_buttons(true)
	elif ws_state == WebSocketPeer.STATE_CONNECTING:
		status_label.text = "Đang thiết lập đường truyền..."
		_disable_buttons(true)
	else:
		status_label.text = "Sẵn sàng tìm trận."
		_disable_buttons(false)

	var lbl_hero = Label.new()
	var h_name = GameManager.selected_battle_hero_name
	if h_name == "":
		h_name = "Chưa chọn (Tướng Test)"
	lbl_hero.text = "Hero đang dùng: " + h_name
	lbl_hero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_hero.modulate = Color.AQUA
	$VBoxContainer.add_child(lbl_hero)
	$VBoxContainer.move_child(lbl_hero, 1)

	# --- BỔ SUNG CHỌN TRANG PHỤC TRƯỚC KHI VÀO TRẬN ---
	var hbox_skin = HBoxContainer.new()
	hbox_skin.name = "HBoxSkin"  # Đặt tên rành mạch để hệ thống nhận diện được path
	var lbl_skin = Label.new()
	lbl_skin.text = "Trang phục:"
	var opt_skin = OptionButton.new()
	opt_skin.name = "OptSkin"

	# Add mặc định
	opt_skin.add_item("Mặc định")
	opt_skin.set_item_metadata(0, GameManager.selected_battle_hero_model)

	# Add các custom skins
	for skin_data in GameManager.selected_battle_hero_skins:
		var skin_url = ""
		var skin_name = ""
		if typeof(skin_data) == TYPE_STRING:
			skin_url = skin_data
			skin_name = skin_url.get_file().get_basename()
		else:
			skin_url = skin_data.get("url", "")
			skin_name = skin_data.get("name", skin_url.get_file().get_basename())

		opt_skin.add_item(skin_name)
		opt_skin.set_item_metadata(opt_skin.get_item_count() - 1, skin_url)

	hbox_skin.add_child(lbl_skin)
	hbox_skin.add_child(opt_skin)
	$VBoxContainer.add_child(hbox_skin)
	$VBoxContainer.move_child(hbox_skin, 2)

	# --- BỔ SUNG UI CHỌN SỐ LƯỢNG NGƯỜI CHƠI ---
	var hbox_settings = HBoxContainer.new()

	var lbl_min = Label.new()
	lbl_min.text = "Min Player/Team:"
	spin_min = SpinBox.new()
	spin_min.min_value = 1
	spin_min.max_value = 15
	spin_min.value = 1  # Để test 1 mình thì set min = 1

	var lbl_max = Label.new()
	lbl_max.text = "Max Player/Team:"
	spin_max = SpinBox.new()
	spin_max.min_value = 1
	spin_max.max_value = 15
	spin_max.value = 5

	hbox_settings.add_child(lbl_min)
	hbox_settings.add_child(spin_min)
	hbox_settings.add_child(lbl_max)
	hbox_settings.add_child(spin_max)

	$VBoxContainer.add_child(hbox_settings)
	$VBoxContainer.move_child(hbox_settings, 2)
	# ------------------------------------------

	var btn_back = Button.new()
	btn_back.text = "<- Quay lại Quản lý Hero"
	btn_back.pressed.connect(
		func(): get_tree().change_scene_to_file("res://scenes/HeroManager.tscn")
	)
	$VBoxContainer.add_child(btn_back)

	btn_aram.pressed.connect(func(): _start_match("aram"))
	btn_3lane.pressed.connect(func(): _start_match("3lane"))
	btn_random.pressed.connect(func(): _start_match("random"))

	# Kiểm tra nếu chưa có Hero thì khóa nút tìm trận
	if GameManager.selected_battle_hero_id == "":
		status_label.text = "⚠️ VUI LÒNG QUAY LẠI VÀ CHỌN 1 HERO ĐỂ VÀO TRẬN!"
		status_label.modulate = Color.RED
		_disable_buttons(true)

	NetworkManager.match_found.connect(_on_match_found)


func _start_match(map_type: String):
	status_label.text = (
		"Đang tìm trận "
		+ map_type.to_upper()
		+ " (Yêu cầu "
		+ str(spin_min.value)
		+ "-"
		+ str(spin_max.value)
		+ " người)..."
	)
	_disable_buttons(true)

	var selected_skin_url = GameManager.selected_battle_hero_model
	# Tìm chính xác Node thông qua tên đã đặt ở _ready()
	var opt_skin_node = $VBoxContainer.get_node_or_null("HBoxSkin/OptSkin")
	if opt_skin_node:
		selected_skin_url = opt_skin_node.get_item_metadata(opt_skin_node.selected)

	NetworkManager.join_queue(map_type, int(spin_min.value), int(spin_max.value), selected_skin_url)


func _process(_delta):
	# Vòng lặp kiểm tra liên tục: Khi mạng kết nối thành công, tự động mở khóa nút Tìm trận
	if NetworkManager.websocket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		# Mở khóa nếu UI đang kẹt ở các dòng text chờ kết nối
		if (
			status_label.text == "Đang thiết lập đường truyền..."
			or status_label.text == "Đang kết nối lại Server Game..."
			or status_label.text == ""
		):
			status_label.text = "Sẵn sàng tìm trận."
			_disable_buttons(false)


func _on_match_found(_map_type: String):
	status_label.text = "TÌM THẤY TRẬN! Đang khởi tạo màn hình tải..."
	GameManager.clear_all_objects()

	# Gọi tới Loading Screen bằng cách hoán đổi Node trực tiếp trên Root
	var loading_node = Control.new()
	loading_node.name = "Loading"
	loading_node.set_script(load("res://scripts/Loading.gd"))

	var root = get_tree().root
	var current_scene = get_tree().current_scene
	root.add_child(loading_node)
	current_scene.queue_free()
	get_tree().current_scene = loading_node


func _disable_buttons(disabled: bool):
	btn_aram.disabled = disabled
	btn_3lane.disabled = disabled
	btn_random.disabled = disabled

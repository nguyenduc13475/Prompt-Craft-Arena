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

	if not NetworkManager.websocket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		NetworkManager.connect_to_server()
		status_label.text = "Đang kết nối Server Game..."
	else:
		status_label.text = "Sẵn sàng tìm trận."

	var lbl_hero = Label.new()
	lbl_hero.text = "Hero đang dùng: " + GameManager.selected_battle_hero_id
	lbl_hero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_hero.modulate = Color.AQUA
	$VBoxContainer.add_child(lbl_hero)
	$VBoxContainer.move_child(lbl_hero, 1)

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
	NetworkManager.join_queue(map_type, int(spin_min.value), int(spin_max.value))


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

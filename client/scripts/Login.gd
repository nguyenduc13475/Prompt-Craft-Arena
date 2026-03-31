extends Control

@onready var txt_username = $Panel/VBoxContainer/TxtUsername
@onready var txt_password = $Panel/VBoxContainer/TxtPassword
@onready var lbl_status = $Panel/VBoxContainer/LblStatus
@onready var btn_login = $Panel/VBoxContainer/HBoxContainer/BtnLogin
@onready var btn_register = $Panel/VBoxContainer/HBoxContainer/BtnRegister


func _ready():
	# --- TẠO BACKGROUND ĐỘNG TẠI SẢNH ĐĂNG NHẬP ---
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -1
	var mat = ShaderMaterial.new()
	mat.shader = load("res://assets/bg_animated.gdshader")
	bg.material = mat
	add_child(bg)
	move_child(bg, 0)

	# Kết nối tín hiệu autoload
	AuthManager.login_success.connect(_on_login_success)
	AuthManager.login_failed.connect(_on_auth_failed)
	AuthManager.register_success.connect(_on_register_success)

	btn_login.pressed.connect(_on_btn_login_pressed)
	btn_register.pressed.connect(_on_btn_register_pressed)

	# Block input game cũ nếu có autoload input hoạt động
	if has_node("/root/InputManager"):
		get_node("/root/InputManager").set_process_unhandled_input(false)


func _on_btn_login_pressed():
	var user = txt_username.text.strip_edges()
	var password_text = txt_password.text.strip_edges()
	if user == "" or password_text == "":
		lbl_status.text = "Vui lòng nhập đủ thông tin."
		return
	lbl_status.text = "Đang đăng nhập..."
	lbl_status.modulate = Color.WHITE
	_set_buttons_disabled(true)
	AuthManager.login(user, password_text)


func _on_btn_register_pressed():
	var user = txt_username.text.strip_edges()
	var password_text = txt_password.text.strip_edges()
	if user == "" or password_text == "":
		lbl_status.text = "Vui lòng nhập user/pass để đăng ký."
		return
	lbl_status.text = "Đang đăng ký..."
	lbl_status.modulate = Color.WHITE
	_set_buttons_disabled(true)
	AuthManager.register(user, password_text)


func _on_login_success(_uname):
	lbl_status.text = "Đăng nhập thành công! Đang chuyển cảnh..."
	lbl_status.modulate = Color.GREEN
	get_tree().change_scene_to_file("res://scenes/HeroManager.tscn")


func _on_auth_failed(msg):
	lbl_status.text = "Lỗi: " + msg
	lbl_status.modulate = Color.RED
	_set_buttons_disabled(false)


func _on_register_success():
	lbl_status.text = "Đăng ký thành công! Vui lòng bấm Đăng nhập."
	lbl_status.modulate = Color.AQUA
	_set_buttons_disabled(false)
	txt_password.text = ""


func _set_buttons_disabled(disabled):
	btn_login.disabled = disabled
	btn_register.disabled = disabled

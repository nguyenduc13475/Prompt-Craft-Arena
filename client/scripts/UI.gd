extends Control

@onready var prompt_input = $VBoxContainer/PromptInput
@onready var generate_btn = $VBoxContainer/GenerateButton

var draw_panel: Panel
var is_drawing = false
var draw_lines = []
var current_line: Line2D
var uploaded_ugc_url: String = ""
var http_upload: HTTPRequest

func _ready():
    generate_btn.pressed.connect(_on_generate_pressed)
    self.mouse_filter = Control.MOUSE_FILTER_IGNORE
    $VBoxContainer.mouse_filter = Control.MOUSE_FILTER_IGNORE

    http_upload = HTTPRequest.new()
    add_child(http_upload)
    http_upload.request_completed.connect(_on_upload_completed)

    _setup_ugc_canvas()

func _setup_ugc_canvas():
    var toggle_btn = Button.new()
    toggle_btn.text = "✏️ Mở bảng vẽ kỹ năng"
    $VBoxContainer.add_child(toggle_btn)
    $VBoxContainer.move_child(toggle_btn, 0) # Đẩy lên vị trí đầu tiên của thanh menu cho dễ nhìn

    var save_ugc_btn = Button.new()
    save_ugc_btn.text = "💾 Lưu & Tải lên máy chủ"
    $VBoxContainer.add_child(save_ugc_btn)

    draw_panel = Panel.new()
    draw_panel.size = Vector2(400, 400)
    # Ép bảng vẽ ra giữa màn hình, tránh lọt ra ngoài hoặc bị che mất
    draw_panel.position = Vector2(300, 200)
    draw_panel.hide()
    draw_panel.clip_contents = true # Ngăn nét vẽ lòi ra ngoài viền

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
    var region = Rect2i(draw_panel.global_position.x, draw_panel.global_position.y, draw_panel.size.x, draw_panel.size.y)
    var cropped_img = img.get_region(region)

    var buffer = cropped_img.save_png_to_buffer()
    var base64_str = Marshalls.raw_to_base64(buffer)

    var payload = {
        "image_base64": base64_str,
        "folder": "vfx"
    }
    var json_str = JSON.stringify(payload)
    http_upload.request("http://127.0.0.1:8000/api/uploads/base64", ["Content-Type: application/json"], HTTPClient.METHOD_POST, json_str)

func _on_upload_completed(result, response_code, headers, body):
    if response_code == 200:
        var res = JSON.parse_string(body.get_string_from_utf8())
        uploaded_ugc_url = res["url"]
        print("Đã tải UGC lên máy chủ thành công! URL: ", uploaded_ugc_url)
        draw_panel.hide() # Tự động đóng bảng vẽ lại sau khi lưu xong
    else:
        print("Lỗi tải lên UGC: ", response_code, body.get_string_from_utf8())

func _on_generate_pressed():
    var text = prompt_input.text
    if text != "":
        GameManager.generate_hero_from_prompt(text, uploaded_ugc_url)
        prompt_input.text = ""
        prompt_input.release_focus()
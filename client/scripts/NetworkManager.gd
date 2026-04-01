extends Node
signal match_found(map_type)

var websocket: WebSocketPeer = WebSocketPeer.new()
# Dùng User ID từ AuthManager làm Client ID cố định cho WS thay vì randi()
var client_id: String = ""
var current_room_id: String = ""


func connect_to_server():
	if not AuthManager.is_logged_in:
		return

	# CHẶN LỖI: Chỉ gọi connect nếu socket thực sự đang đóng
	if websocket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		print("[WS] Socket đang mở hoặc đang kết nối, bỏ qua lệnh connect mới.")
		return

	client_id = str(AuthManager.user_id)  # Dùng User ID để server nhận diện trong DB

	var url = "ws://127.0.0.1:8000/ws/" + client_id
	print("[WS] Dang ket noi voi Client ID cố định (User ID): ", client_id)

	var err = websocket.connect_to_url(url)
	if err != OK:
		print("[WS Lỗi] Không thể gọi connect_to_url, mã lỗi: ", err)
	else:
		set_process(true)  # Đảm bảo vòng lặp poll() được đánh thức


func _ready():
	set_process(true)


func _process(_delta):
	websocket.poll()
	var state = websocket.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		while websocket.get_available_packet_count():
			var packet = websocket.get_packet()
			var message = packet.get_string_from_utf8()
			_handle_server_message(message)

	# Bỏ hẳn đoạn chặn STATE_CLOSED để hàm poll() luôn được chạy


func _handle_server_message(json_str: String):
	var data = JSON.parse_string(json_str)
	if data != null:
		# Nhận lệnh ghép trận thành công
		if data.has("type") and data["type"] == "match_found":
			current_room_id = data["room_id"]
			print("ĐÃ TÌM THẤY TRẬN! Room: ", current_room_id, " Map: ", data["map_type"])
			match_found.emit(data["map_type"])
		elif data.has("type") and data["type"] == "chat_message":
			# Bắn tín hiệu hoặc gọi hàm update chat UI thẳng
			var ui = get_tree().current_scene.get_node_or_null("UILayer/Control")
			if ui and ui.has_method("receive_chat"):
				ui.receive_chat(data["sender"], data["message"], data["channel"])
		elif data.has("type") and data["type"] == "game_over":
			print("GAME OVER! Team win: ", data["winner_team"])
			current_room_id = ""  # Reset room
			# Chuyển sang scene kết quả và truyền stats
			GameManager.clear_all_objects()
			# Hack tạm: Lưu stats vào GameManager để truyền qua scene mới
			GameManager.set_meta("last_stats", data["stats"])
			GameManager.set_meta("winner_team", data["winner_team"])

			var gameover_node = Control.new()
			gameover_node.name = "GameOver"
			gameover_node.set_script(load("res://scripts/GameOver.gd"))

			var root = get_tree().root
			var current_scene = get_tree().current_scene
			root.add_child(gameover_node)
			if current_scene:
				current_scene.queue_free()
			get_tree().current_scene = gameover_node
		# Cập nhật state game bình thường
		elif data.has("objects"):
			GameManager.update_objects(data["objects"])


# --- THAY ĐỔI LOGIC JOIN QUEUE THÔNG MINH ---
func join_queue(map_type: String, min_p: int = 1, max_p: int = 5, model_url: String = ""):
	if websocket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var hero_id = GameManager.selected_battle_hero_id
		if hero_id == "":
			# Sinh ID giả để test nếu chưa chọn tướng thật từ DB
			hero_id = "test-hero-id-" + str(randi() % 1000)

		var data = {
			"type": "join_queue",
			"map_type": map_type,
			"hero_id": hero_id,
			"model_url": model_url,
			"min_p": min_p,
			"max_p": max_p
		}
		websocket.send_text(JSON.stringify(data))
		print(
			"[WS] Da gui yeu cau tim tran voi Hero: ",
			hero_id,
			" | Min/Team: ",
			min_p,
			" | Max/Team: ",
			max_p
		)


func send_input(event_type: String, mouse_coord: Vector2):
	if websocket.get_ready_state() == WebSocketPeer.STATE_OPEN and current_room_id != "":
		var data = {"type": event_type, "coord": [mouse_coord.x, mouse_coord.y]}
		websocket.send_text(JSON.stringify(data))


func send_custom(event_type: String, payload: Dictionary):
	if websocket.get_ready_state() == WebSocketPeer.STATE_OPEN and current_room_id != "":
		payload["type"] = event_type
		websocket.send_text(JSON.stringify(payload))

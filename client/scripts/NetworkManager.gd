extends Node

var websocket: WebSocketPeer = WebSocketPeer.new()
var client_id: String = str(randi()) # ID tạm thời của client

func _ready():
    var url = "ws://127.0.0.1:8000/ws/" + client_id
    var err = websocket.connect_to_url(url)
    if err != OK:
        print("Không thể kết nối tới Server WebSocket!")
        set_process(false)
    else:
        print("Đang kết nối tới Server...")

func _process(_delta):
    websocket.poll()
    var state = websocket.get_ready_state()
    
    if state == WebSocketPeer.STATE_OPEN:
        while websocket.get_available_packet_count():
            var packet = websocket.get_packet()
            var message = packet.get_string_from_utf8()
            _handle_server_state(message)
            
    elif state == WebSocketPeer.STATE_CLOSED:
        print("Mất kết nối với Server. Đang thử kết nối lại sau 2 giây...")
        set_process(false)
        await get_tree().create_timer(2.0).timeout
        _ready() # Khởi động lại luồng kết nối
        set_process(true)

func _handle_server_state(json_str: String):
    var game_state = JSON.parse_string(json_str)
    if game_state != null and game_state.has("objects"):
        # Gửi toàn bộ dữ liệu objects sang GameManager để vẽ lên màn hình
        GameManager.update_objects(game_state["objects"])
    else:
        print("Lỗi parse JSON từ server: ", json_str)

func send_input(event_type: String, mouse_coord: Vector2):
    """Hàm này sẽ được gọi khi người chơi bấm Q, W, E, R hoặc chuột"""
    if websocket.get_ready_state() == WebSocketPeer.STATE_OPEN:
        var data = {
            "type": event_type,
            "coord": [mouse_coord.x, mouse_coord.y]
        }
        websocket.send_text(JSON.stringify(data))
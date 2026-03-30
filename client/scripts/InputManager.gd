extends Node

func _unhandled_input(event):
    # Lấy tọa độ chuột thật trên bản đồ
    var mouse_pos = get_viewport().get_mouse_position()

    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_RIGHT:
            NetworkManager.send_input("right", mouse_pos)
        elif event.button_index == MOUSE_BUTTON_LEFT:
            NetworkManager.send_input("left", mouse_pos)

    elif event is InputEventKey and event.pressed:
        var key_char = OS.get_keycode_string(event.keycode).to_upper()
        # Chặn Spam: Chỉ nhận các phím kỹ năng định sẵn
        if key_char in ["Q", "W", "E", "R", "1", "2", "3", "4", "5", "6"]:
            NetworkManager.send_input(key_char, mouse_pos)
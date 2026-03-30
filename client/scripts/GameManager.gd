extends Node

var objects_in_scene = {}
var texture_cache = {} # Cache ảnh để không tải lại nhiều lần
var http_request: HTTPRequest

func _ready():
    http_request = HTTPRequest.new()
    add_child(http_request)
    http_request.request_completed.connect(self._on_hero_generated)

func generate_hero_from_prompt(prompt_text: String, ugc_url: String = ""):
    print("Đang gọi AI tạo Hero với prompt: ", prompt_text)
    var payload = {
        "client_id": NetworkManager.client_id,
        "prompt": prompt_text,
        "team": 1,
        "ugc_vfx_url": ugc_url
    }
    var body = JSON.stringify(payload)
    http_request.request("http://127.0.0.1:8000/api/heroes/generate", ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)

func _on_hero_generated(result, response_code, headers, body):
    if response_code == 200:
        print("Đã tạo Hero thành công qua Gemini AI! Đã nạp vào GameLoop.")
    else:
        print("Lỗi tạo Hero: ", body.get_string_from_utf8())

func update_objects(server_objects: Dictionary):
    var current_ids = server_objects.keys()

    for obj_id in current_ids:
        var data = server_objects[obj_id]
        var server_pos = Vector2(data["coord"][0], data["coord"][1])

        if objects_in_scene.has(obj_id):
            var node = objects_in_scene[obj_id]
            node.position = node.position.lerp(server_pos, 0.4)
            
            if node.has_node("HPBar"):
                var hp_bar = node.get_node("HPBar")
                hp_bar.max_value = data.get("max_hp", 100)
                hp_bar.value = data.get("hp", 100)
                hp_bar.visible = data.get("hp", 100) < data.get("max_hp", 100)
        else:
            _create_new_object(obj_id, data, server_pos)

    # Dọn dẹp
    var keys_to_remove = []
    for obj_id in objects_in_scene.keys():
        if not current_ids.has(obj_id):
            objects_in_scene[obj_id].queue_free()
            keys_to_remove.append(obj_id)
    for k in keys_to_remove:
        objects_in_scene.erase(k)

func _create_new_object(obj_id: String, data: Dictionary, start_pos: Vector2):
    var new_node = Node2D.new()
    
    var obj_color = Color(data.get("color", "WHITE"))
    var obj_size = Vector2(data.get("size", [40, 40])[0], data.get("size", [40, 40])[1])
    var vfx_type = data.get("vfx_type", "none")
    var vfx_url = data.get("vfx_url", "")
    var visual_node
    
    # Render hình tĩnh/Sprite
    if vfx_url != "":
        visual_node = Sprite2D.new()
        _load_texture_from_url(vfx_url, visual_node, obj_size)
    else:
        visual_node = ColorRect.new()
        visual_node.size = obj_size
        visual_node.position = -obj_size / 2 
        if data["team"] == 1 and vfx_type == "none":
            visual_node.color = Color.DODGER_BLUE
        elif data["team"] == 2 and vfx_type == "none":
            visual_node.color = Color.CRIMSON
        else:
            visual_node.color = obj_color

    # Cài đặt Shader
    if vfx_type != "none":
        var mat = ShaderMaterial.new()
        mat.shader = load("res://assets/vfx_procedural.gdshader")
        mat.set_shader_parameter("base_color", obj_color)
        if vfx_type == "electric":
            mat.set_shader_parameter("speed", 15.0)
        visual_node.material = mat

    new_node.add_child(visual_node)
    new_node.position = start_pos

    var hp_bar = ProgressBar.new()
    hp_bar.name = "HPBar"
    hp_bar.position = Vector2(-obj_size.x/2, -obj_size.y/2 - 15)
    hp_bar.size = Vector2(obj_size.x, 10)
    hp_bar.show_percentage = false
    hp_bar.modulate = Color.GREEN
    hp_bar.max_value = data.get("max_hp", 100)
    hp_bar.value = data.get("hp", 100)
    hp_bar.visible = hp_bar.value < hp_bar.max_value
    new_node.add_child(hp_bar)

    get_tree().current_scene.add_child(new_node)
    objects_in_scene[obj_id] = new_node

func _load_texture_from_url(url: String, sprite: Sprite2D, target_size: Vector2):
    var full_url = "http://127.0.0.1:8000" + url
    if texture_cache.has(full_url):
        _apply_texture(sprite, texture_cache[full_url], target_size)
        return

    var req = HTTPRequest.new()
    add_child(req)
    req.request_completed.connect(func(result, response_code, headers, body):
        if response_code == 200:
            var img = Image.new()
            img.load_png_from_buffer(body)
            var tex = ImageTexture.create_from_image(img)
            texture_cache[full_url] = tex
            _apply_texture(sprite, tex, target_size)
        req.queue_free()
    )
    req.request(full_url)

func _apply_texture(sprite: Sprite2D, tex: Texture2D, target_size: Vector2):
    sprite.texture = tex
    var tex_size = tex.get_size()
    sprite.scale = Vector2(target_size.x / tex_size.x, target_size.y / tex_size.y)
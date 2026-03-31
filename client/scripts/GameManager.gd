extends Node

# Bien luu tru Hero ID da chon tu sảnh
var selected_battle_hero_id: String = ""

var objects_in_scene = {}
var texture_cache = {}  # Cache ảnh để không tải lại nhiều lần
var http_request: HTTPRequest
var _latest_server_data = {}  # Truy cập bằng UI


func _ready():
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(self._on_hero_generated)


func _on_hero_generated(_result, response_code, _headers, body):
	if response_code == 200:
		print("Đã tạo Hero thành công qua Gemini AI! Đã nạp vào GameLoop.")
	else:
		print("Lỗi tạo Hero: ", body.get_string_from_utf8())


# Thêm hàm dọn dẹp để gọi khi chuyển Scene
func clear_all_objects():
	for obj in objects_in_scene.values():
		if is_instance_valid(obj):
			obj.queue_free()
	objects_in_scene.clear()


func update_objects(server_objects: Dictionary):
	_latest_server_data = server_objects
	# CHẶN NGAY TẠI CỬA: Chỉ vẽ khi đã thực sự vào màn chơi Main
	if get_tree().current_scene.name != "Main":
		return

	var current_ids = server_objects.keys()

	for obj_id in current_ids:
		var data = server_objects[obj_id]
		var server_pos = Vector2(data["coord"][0], data["coord"][1])

		if objects_in_scene.has(obj_id):
			var node = objects_in_scene[obj_id]
			# LỚP BẢO VỆ: Kiểm tra node còn tồn tại trong Scene Tree không
			if is_instance_valid(node):
				node.position = node.position.lerp(server_pos, 0.4)
				if node.has_node("HPBar"):
					var hp_bar = node.get_node("HPBar")
					hp_bar.max_value = data.get("max_hp", 100)
					hp_bar.value = data.get("hp", 100)
					hp_bar.visible = hp_bar.value < hp_bar.max_value
			else:
				# Node đã bị Godot xóa (do chuyển scene), ta xóa khỏi bộ nhớ và tạo lại
				objects_in_scene.erase(obj_id)
				_create_new_object(obj_id, data, server_pos)
		else:
			_create_new_object(obj_id, data, server_pos)

	# Dọn dẹp các object không còn tồn tại trên Server
	var keys_to_remove = []
	for obj_id in objects_in_scene.keys():
		if not current_ids.has(obj_id):
			if is_instance_valid(objects_in_scene[obj_id]):
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

	# Thêm Label tên tướng (Breadth-first hiển thị)
	if data.has("name_display"):
		var lbl_name = Label.new()
		lbl_name.text = data["name_display"]
		lbl_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_name.position = Vector2(-50, obj_size.y / 2 + 5)
		lbl_name.size = Vector2(100, 20)
		lbl_name.add_theme_font_size_override("font_size", 12)
		new_node.add_child(lbl_name)

	var hp_bar = ProgressBar.new()
	hp_bar.name = "HPBar"
	hp_bar.position = Vector2(-obj_size.x / 2, -obj_size.y / 2 - 15)
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
	req.request_completed.connect(
		func(result, response_code, headers, body):
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

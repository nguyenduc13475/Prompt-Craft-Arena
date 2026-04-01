extends Node

# Bien luu tru Hero ID da chon tu sảnh
var selected_battle_hero_id: String = ""
var selected_battle_hero_name: String = ""
var selected_battle_hero_model: String = ""
var selected_battle_hero_skins: Array = []

var objects_in_scene = {}
var texture_cache = {}  # Cache ảnh để không tải lại nhiều lần
var http_request: HTTPRequest
var camera_zoom: float = 1.0  # Mức độ zoom camera trong trận đấu
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
	# CHẶN NGAY TẠI CỬA: Đảm bảo Scene Tree ổn định trong lúc chuyển cảnh
	var current_scene = get_tree().current_scene
	if (
		current_scene == null
		or not is_instance_valid(current_scene)
		or current_scene.name != "Main"
	):
		return

	var current_ids = server_objects.keys()

	for obj_id in current_ids:
		var data = server_objects[obj_id]
		var server_pos = Vector2(data["coord"][0], data["coord"][1])

		if objects_in_scene.has(obj_id):
			var node = objects_in_scene[obj_id]
			if is_instance_valid(node):
				# Lerp vị trí 3D
				var target_pos_3d = Vector3(server_pos.x, 0, server_pos.y)
				node.position = node.position.lerp(target_pos_3d, 0.4)

				# Cập nhật hướng xoay (Quay mặt Tướng)
				if data.has("orientation"):
					# Xoay model theo trục Y (Lưu ý hệ tọa độ 3D âm dương ngược nhau)
					node.rotation.y = lerp_angle(node.rotation.y, -data["orientation"], 0.2)

				# Play Animation
				if data.has("anim") and node.has_meta("anim_player"):
					var anim_player: AnimationPlayer = node.get_meta("anim_player")
					var current_anim = data["anim"]
					if (
						anim_player.has_animation(current_anim)
						and anim_player.current_animation != current_anim
					):
						# Thêm độ blend nhẹ để chuyển từ Chạy sang Đứng không bị giật
						anim_player.play(current_anim, 0.2)

				# Camera bám theo nhân vật của mình để tạo cảm giác 3D thật (Theo góc MOBA)
				if data.get("client_id") == str(AuthManager.user_id):
					var cam = get_tree().current_scene.get_node_or_null("Camera3D")
					if cam:
						# Sử dụng biến camera_zoom để điều chỉnh độ cao và lùi
						var zoom_offset = Vector3(0, 150.0 * camera_zoom, 120.0 * camera_zoom)
						var cam_target_pos = target_pos_3d + zoom_offset
						cam.position = cam.position.lerp(cam_target_pos, 0.1)

					# Ẩn/Hiện máu tạm thời (Do đã thay bằng Label3D)
					# Cập nhật máu 3D
					var hp_node = node.get_node_or_null("HPBar")
					if hp_node and hp_node is Label3D:
						var c_hp = data.get("hp", 100)
						var m_hp = data.get("max_hp", 100)
						hp_node.text = str(c_hp) + " / " + str(m_hp)
						hp_node.modulate = Color.GREEN if c_hp > m_hp * 0.3 else Color.RED
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
	var new_node = Node3D.new()  # Đổi thành Node3D
	# Map Server [x, y] -> Godot [x, 0, z]
	var pos_3d = Vector3(start_pos.x, 0, start_pos.y)
	new_node.position = pos_3d

	var obj_color = Color(data.get("color", "WHITE"))
	var obj_size = Vector3(
		data.get("size", [40, 40])[0] * 0.4, 4.0, data.get("size", [40, 40])[1] * 0.4
	)  # Tăng hệ số nhân lên 0.4 để Tướng to hơn, dễ nhìn hơn trên map 1000x1000
	var vfx_type = data.get("vfx_type", "none")
	var vfx_url = data.get("vfx_url", "")
	var model_url = data.get("model_url", "")
	var visual_node = Node3D.new()
	new_node.add_child(visual_node)

	# Thêm Label 3D hiển thị Tên và Thanh HP (Sử dụng Sprite3D)
	_add_3d_ui_to_node(new_node, data, obj_size)

	# QUAN TRỌNG: Phải nạp Node vào Tree TRƯỚC để các node con (HTTPRequest) có thể hoạt động
	get_tree().current_scene.add_child(new_node)
	objects_in_scene[obj_id] = new_node

	# 1. TẢI MODEL 3D DÀNH CHO HERO / MINION
	if model_url != "":
		_load_gltf_model(model_url, visual_node, new_node)
	# 2. RENDER KHỐI MẶC ĐỊNH HOẶC KỸ NĂNG (VFX)
	else:
		var mesh_inst = MeshInstance3D.new()
		if vfx_type != "none" or vfx_url != "":
			# Thể hiện đạn bay/chiêu thức bằng khối cầu
			var sphere = SphereMesh.new()
			sphere.radius = obj_size.x
			sphere.height = obj_size.x * 2
			mesh_inst.mesh = sphere
		else:
			# Các khối môi trường hoặc quái chưa có skin
			var box = BoxMesh.new()
			box.size = obj_size
			mesh_inst.mesh = box

		var mat = StandardMaterial3D.new()
		mat.albedo_color = obj_color
		if data["team"] == 1 and obj_color == Color("WHITE"):
			mat.albedo_color = Color.DODGER_BLUE
		elif data["team"] == 2 and obj_color == Color("WHITE"):
			mat.albedo_color = Color.CRIMSON

		mesh_inst.material_override = mat
		mesh_inst.position.y = obj_size.y / 2.0
		visual_node.add_child(mesh_inst)


func _load_gltf_model(url: String, parent_node: Node3D, root_node: Node3D):
	var full_url = "http://127.0.0.1:8000" + url

	var req = HTTPRequest.new()
	root_node.add_child(req)
	req.request_completed.connect(
		func(_result, response_code, _headers, body):
			if response_code == 200:
				var doc = GLTFDocument.new()
				var state = GLTFState.new()
				var err = doc.append_from_buffer(body, "", state)
				if err == OK:
					var scene = doc.generate_scene(state)
					parent_node.add_child(scene)

					# Tìm kiếm xương (AnimationPlayer)
					var anim_player = _find_animation_player(scene)
					if anim_player:
						# Lưu tham chiếu để update_objects có thể gọi
						root_node.set_meta("anim_player", anim_player)
			req.queue_free()
	)
	req.request(full_url)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found = _find_animation_player(child)
		if found:
			return found
	return null


func _add_3d_ui_to_node(parent: Node3D, data: Dictionary, obj_size: Vector3):
	# 1. Hiển thị Tên
	var lbl_name = Label3D.new()
	lbl_name.text = data.get("name_display", "Khuyết Danh")
	lbl_name.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl_name.position = Vector3(0, obj_size.y + 2.5, 0)
	lbl_name.font_size = 64
	lbl_name.outline_size = 8
	parent.add_child(lbl_name)

	# 2. Hiển thị Máu bằng Text 3D thay vì ProgressBar (Vì Progressbar 2D ko sống được trong Node3D)
	var lbl_hp = Label3D.new()
	lbl_hp.name = "HPBar"  # Giữ tên để hàm update tìm thấy
	var current_hp = data.get("hp", 100)
	var max_hp = data.get("max_hp", 100)
	lbl_hp.text = str(current_hp) + " / " + str(max_hp)
	lbl_hp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl_hp.position = Vector3(0, obj_size.y + 1.5, 0)
	lbl_hp.font_size = 48
	lbl_hp.modulate = Color.GREEN if current_hp > max_hp * 0.3 else Color.RED
	lbl_hp.outline_size = 6
	parent.add_child(lbl_hp)


func _load_texture_from_url(url: String, sprite: Sprite2D, target_size: Vector2):
	var full_url = "http://127.0.0.1:8000" + url
	if texture_cache.has(full_url):
		_apply_texture(sprite, texture_cache[full_url], target_size)
		return

	var req = HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(
		func(_result, response_code, _headers, body):
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

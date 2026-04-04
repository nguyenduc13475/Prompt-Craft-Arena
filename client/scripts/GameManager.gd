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
var _is_night_state: bool = false
var _light_tween: Tween


func _ready():
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(self._on_hero_generated)


func _on_hero_generated(_result, response_code, _headers, body):
	if response_code == 200:
		print("Đã tạo Hero thành công qua Gemini AI! Đã nạp vào GameLoop.")
	else:
		print("Lỗi tạo Hero: ", body.get_string_from_utf8())


func update_day_night_cycle(is_night: bool):
	if _is_night_state == is_night:
		return
	_is_night_state = is_night

	var current_scene = get_tree().current_scene
	if current_scene and current_scene.name == "Main":
		var dir_light = current_scene.get_node_or_null("DirectionalLight3D")
		var floor_mesh = current_scene.get_node_or_null("Floor")
		if dir_light:
			if _light_tween:
				_light_tween.kill()
			_light_tween = create_tween()
			var target_color = Color(0.2, 0.2, 0.4, 1.0) if is_night else Color(1.0, 0.95, 0.8, 1.0)
			var target_energy = 0.2 if is_night else 1.0
			_light_tween.tween_property(dir_light, "light_color", target_color, 3.0)
			_light_tween.tween_property(dir_light, "light_energy", target_energy, 3.0)

			# Làm cho mặt đất mờ đi theo vào ban đêm
			if floor_mesh and floor_mesh.material:
				var target_albedo = (
					Color(0.08, 0.1, 0.15, 1) if is_night else Color(0.18, 0.2, 0.25, 1)
				)
				_light_tween.tween_property(floor_mesh.material, "albedo_color", target_albedo, 3.0)


# Thêm hàm dọn dẹp để gọi khi chuyển Scene
func clear_all_objects():
	for obj in objects_in_scene.values():
		if is_instance_valid(obj):
			obj.queue_free()
	objects_in_scene.clear()


func update_objects(server_objects: Dictionary, is_night: bool = false):
	_latest_server_data = server_objects

	# Gọi cập nhật ánh sáng
	update_day_night_cycle(is_night)

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

				# Camera bám theo nhân vật của mình (Chuẩn MOBA Isometric)
				if data.get("client_id") == str(AuthManager.user_id):
					var cam = get_tree().current_scene.get_node_or_null("Camera3D")
					if cam:
						# Điều chỉnh góc xoay cố định cho Camera chuẩn MOBA
						cam.rotation_degrees = Vector3(-55, 0, 0)  # Cúi xuống 55 độ
						# Vị trí lùi ra sau và nâng lên cao dựa trên zoom
						var zoom_offset = Vector3(0, 300.0 * camera_zoom, 200.0 * camera_zoom)
						var cam_target_pos = target_pos_3d + zoom_offset
						# Lerp mượt mà
						cam.position = cam.position.lerp(cam_target_pos, 0.15)

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
	var new_node = Node3D.new()
	var pos_3d = Vector3(start_pos.x, 0, start_pos.y)
	new_node.position = pos_3d

	var obj_color = Color(data.get("color", "WHITE"))
	var obj_size = Vector3(data.get("size", [40, 40])[0], 10.0, data.get("size", [40, 40])[1])

	var model_scale_factor = data.get("size", [40, 40])[0] / 100.0
	var vfx_type = data.get("vfx_type", "none")
	var vfx_url = data.get("vfx_url", "")
	var model_url = data.get("model_url", "")
	var visual_node = Node3D.new()
	# Áp dụng scale factor để model to nhỏ theo đúng thuộc tính "size" từ Server
	visual_node.scale = Vector3(model_scale_factor, model_scale_factor, model_scale_factor)
	new_node.add_child(visual_node)

	_add_3d_ui_to_node(new_node, data, obj_size)
	get_tree().current_scene.add_child(new_node)
	objects_in_scene[obj_id] = new_node

	# --- XỬ LÝ RENDER 3D ---
	if model_url != "":
		if "tree" in model_url or "rock" in model_url:
			visual_node.rotation.y = randf() * PI * 2.0
			# Phóng to ngẫu nhiên mạnh hơn để tán cây đan vào nhau che khuất biên giới map
			var random_scale = randf_range(1.2, 2.5)
			if "rock" in model_url:
				random_scale = randf_range(0.8, 1.5)  # Đá thì nhỏ hơn xíu
			visual_node.scale = Vector3(random_scale, random_scale, random_scale)
			# Random nghiêng nhẹ thân cây cho tự nhiên
			visual_node.rotation.x = randf_range(-0.1, 0.1)
			visual_node.rotation.z = randf_range(-0.1, 0.1)

		if model_url.begins_with("res://"):
			_load_local_model(model_url, visual_node, new_node)
		else:
			_load_gltf_model(model_url, visual_node, new_node)

	elif vfx_url != "" or vfx_type != "none":
		# XỬ LÝ KỸ NĂNG: DÙNG SPRITE 3D BILLBOARD KẾT HỢP SHADER SPATIAL
		var quad = MeshInstance3D.new()
		var plane = QuadMesh.new()
		plane.size = Vector2(obj_size.x, obj_size.z)  # Kích thước chiêu thức
		quad.mesh = plane
		quad.position.y = 5.0  # Nâng nhẹ lên khỏi mặt đất

		var mat = ShaderMaterial.new()
		mat.shader = load("res://assets/vfx_procedural.gdshader")
		mat.set_shader_parameter("base_color", obj_color)
		quad.material_override = mat
		visual_node.add_child(quad)

		if vfx_url != "":
			# Nếu có ảnh UGC, tải về và nạp vào tham số ugc_texture của shader
			_load_texture_for_shader(vfx_url, mat)

	else:
		if vfx_type == "bush":
			# Bụi cỏ MOBA chuyên nghiệp: Render nhiều Plane lá cây đan chéo nhau
			var bush_node = Node3D.new()
			for i in range(3):
				var plane = MeshInstance3D.new()
				var quad = QuadMesh.new()
				quad.size = Vector2(obj_size.x * 1.2, obj_size.x * 0.8)
				plane.mesh = quad
				plane.rotation_degrees.y = i * 60 + randf_range(-10, 10)
				plane.position.y = quad.size.y / 2.0

				var mat = StandardMaterial3D.new()
				mat.albedo_color = Color(0.1, 0.35, 0.15, 0.85)  # Xanh rêu đậm
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED  # Hiện cả 2 mặt
				plane.material_override = mat
				bush_node.add_child(plane)
			visual_node.add_child(bush_node)

		elif vfx_type == "river":
			# Sông: Áp dụng Shader Nước mới tạo
			var p_mesh = PlaneMesh.new()
			p_mesh.size = Vector2(obj_size.x, obj_size.z)
			p_mesh.subdivide_width = 5  # Chia nhỏ để shader sóng mượt hơn
			p_mesh.subdivide_depth = 5

			var mesh_inst = MeshInstance3D.new()
			mesh_inst.mesh = p_mesh
			mesh_inst.position.y = 0.1  # Đặt ngay trên mặt đất một chút

			var mat = ShaderMaterial.new()
			mat.shader = load("res://assets/water_animated.gdshader")
			mesh_inst.material_override = mat
			visual_node.add_child(mesh_inst)

		else:
			# Dự phòng cho các Object cơ bản (Tướng chưa có model, viên đạn base...)
			var mesh_inst = MeshInstance3D.new()
			var mat = StandardMaterial3D.new()
			mat.albedo_color = obj_color
			var box = BoxMesh.new()
			box.size = obj_size
			mesh_inst.mesh = box
			mesh_inst.position.y = obj_size.y / 2.0

			if data.get("team") == 1 and obj_color == Color("WHITE"):
				mat.albedo_color = Color.DODGER_BLUE
			elif data.get("team") == 2 and obj_color == Color("WHITE"):
				mat.albedo_color = Color.CRIMSON

			mesh_inst.material_override = mat
			visual_node.add_child(mesh_inst)


func _load_texture_for_shader(url: String, mat: ShaderMaterial):
	var full_url = "http://127.0.0.1:8000" + url
	if texture_cache.has(full_url):
		mat.set_shader_parameter("ugc_texture", texture_cache[full_url])
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
				mat.set_shader_parameter("ugc_texture", tex)
			req.queue_free()
	)
	req.request(full_url)


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
					# Áp dụng Tỉ lệ để Tướng/Trụ/Nhà chính hiển thị đúng kích cỡ của bounding box logic
					scene.scale = Vector3(1.5, 1.5, 1.5)
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


func _load_local_model(path: String, parent_node: Node3D, root_node: Node3D):
	if ResourceLoader.exists(path):
		var scene_res = load(path)
		if scene_res and scene_res is PackedScene:
			var instance = scene_res.instantiate()
			# Phóng to/thu nhỏ model môi trường nếu cần thiết
			parent_node.add_child(instance)
			var anim_player = _find_animation_player(instance)
			if anim_player:
				root_node.set_meta("anim_player", anim_player)
	else:
		print("[Lỗi] Không tìm thấy asset môi trường cục bộ: ", path)

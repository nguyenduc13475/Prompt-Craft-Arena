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

# --- CAMERA MOBA CONFIG ---
var is_camera_locked: bool = true
var pan_speed: float = 1200.0  # Tốc độ trượt camera
var pan_margin: float = 20.0  # Khoảng cách chuột cách mép màn hình (pixels)

# --- CAMERA ROTATION & DELAY CONFIG ---
var cam_yaw: float = 0.0
var cam_pitch: float = -50.0
var is_middle_mouse_pressed: bool = false
var debug_axes_created: bool = false
var _cam_return_timer: float = 0.0

var _latest_server_data = {}  # Truy cập bằng UI
var _is_night_state: bool = false
var _light_tween: Tween

# --- CAMERA BIẾN TOÀN CỤC ---
var _locked_cam_offset: Vector3 = Vector3.ZERO
var _unlocked_cam_pos: Vector3 = Vector3(500, 0, 500)
var _is_first_camera_snap: bool = true


func force_camera_snap():
	_cam_return_timer = 0.0


func _ready():
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(self._on_hero_generated)


func _unhandled_key_input(event):
	if event.pressed and event.keycode == KEY_Y:
		is_camera_locked = not is_camera_locked
		print("Camera Lock: ", is_camera_locked)


func _process(delta):
	# Xoay OrbContainer của các objects có orbs
	for obj_id in objects_in_scene:
		var node = objects_in_scene[obj_id]
		if is_instance_valid(node):
			var orb_container = node.get_node_or_null("OrbContainer")
			if orb_container and orb_container.get_child_count() > 0:
				orb_container.rotation.y -= 4.0 * delta  # Xoay ngược chiều kim đồng hồ

	var current_scene = get_tree().current_scene
	if not current_scene or current_scene.name != "Main":
		return
	var cam = current_scene.get_node_or_null("Camera3D")
	if not cam:
		return

	var mouse_pos = get_viewport().get_mouse_position()
	var viewport_size = get_viewport().get_visible_rect().size
	var move_vec = Vector3.ZERO

	if mouse_pos.x < pan_margin:
		move_vec.x -= 1
	elif mouse_pos.x > viewport_size.x - pan_margin:
		move_vec.x += 1
	if mouse_pos.y < pan_margin:
		move_vec.z -= 1
	elif mouse_pos.y > viewport_size.y - pan_margin:
		move_vec.z += 1

	if move_vec != Vector3.ZERO:
		move_vec = move_vec.normalized()

	# Tìm Hero của bản thân
	var my_hero_node = null
	if _latest_server_data:
		for id in _latest_server_data:
			if _latest_server_data[id].get("client_id") == str(AuthManager.user_id):
				my_hero_node = objects_in_scene.get(id)
				break

	# Sinh World Axes phục vụ Debug nếu chưa có
	if current_scene.name == "Main" and not debug_axes_created:
		_create_debug_axes(current_scene)
		debug_axes_created = true

	# Tính toán hệ trục dựa trên độ xoay Camera hiện tại (Hỗ trợ xoay bằng Chuột Giữa)
	cam.fov = 40.0
	cam.rotation_degrees = Vector3(cam_pitch, cam_yaw, 0)

	var cam_basis = Basis.from_euler(Vector3(deg_to_rad(cam_pitch), deg_to_rad(cam_yaw), 0))
	var distance = 350.0 * camera_zoom
	# Camera lùi ra sau trục Z local của nó
	var zoom_offset = cam_basis * Vector3(0, 0, distance)

	# Nhấn Space để lập tức kéo Camera về giữa Hero và Reset Orientation/Zoom
	if Input.is_key_pressed(KEY_SPACE):
		_locked_cam_offset = Vector3.ZERO
		_cam_return_timer = 0.0
		cam_yaw = 0.0
		cam_pitch = -50.0
		camera_zoom = 1.0
		if is_instance_valid(my_hero_node):
			_unlocked_cam_pos = my_hero_node.position

	# LOGIC CAMERA SOFT-LOCK KẾT HỢP DELAY 3S VÀ XOAY
	if is_camera_locked and is_instance_valid(my_hero_node):
		if move_vec != Vector3.ZERO:
			# Đảm bảo lia chuột ra mép thì tịnh tiến đúng theo hướng camera đang nhìn
			var aligned_move = move_vec.rotated(Vector3.UP, deg_to_rad(cam_yaw))
			_locked_cam_offset += aligned_move * pan_speed * delta * 0.4 * camera_zoom

			var max_offset = 450.0 * camera_zoom
			if _locked_cam_offset.length() > max_offset:
				_locked_cam_offset = _locked_cam_offset.normalized() * max_offset

			# Đặt lại timer 3s mỗi khi tay người chơi còn thao tác lia cam
			_cam_return_timer = 3.0
		else:
			# Đếm ngược 3s trước khi auto snap về hero
			if _cam_return_timer > 0:
				_cam_return_timer -= delta
			else:
				# Chuột rời mép và đã hết 3s -> trôi mượt về Hero
				_locked_cam_offset = _locked_cam_offset.lerp(Vector3.ZERO, delta * 3.5)

		var target_look_pos = my_hero_node.position + _locked_cam_offset
		var cam_target_pos = target_look_pos + zoom_offset

		if _is_first_camera_snap or cam.position.distance_to(cam_target_pos) > 1000:
			cam.position = cam_target_pos
			_is_first_camera_snap = false
		else:
			cam.position = cam.position.lerp(cam_target_pos, 10.0 * delta)

		_unlocked_cam_pos = my_hero_node.position + _locked_cam_offset

	# LOGIC CAMERA UNLOCKED (Trôi tự do)
	elif not is_camera_locked:
		var aligned_move = move_vec.rotated(Vector3.UP, deg_to_rad(cam_yaw))
		_unlocked_cam_pos += aligned_move * pan_speed * delta * camera_zoom
		var cam_target_pos = _unlocked_cam_pos + zoom_offset

		if _is_first_camera_snap:
			cam.position = cam_target_pos
			_is_first_camera_snap = false
		else:
			cam.position = cam.position.lerp(cam_target_pos, 15.0 * delta)


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

			# Làm cho mặt đất ám xanh nhẹ vào ban đêm thay vì đen thui
			if floor_mesh:
				var target_albedo = (
					Color(0.6, 0.65, 0.8, 1.0) if is_night else Color(1.0, 1.0, 1.0, 1.0)
				)

				# Quét đệ quy tìm tất cả MeshInstance3D trong Floor (do GLB là cụm Node3D) để đổi màu
				var apply_night_to_meshes = func(node: Node, f_ref: Callable):
					if node is MeshInstance3D and node.material_override:
						if node.material_override is ShaderMaterial:
							_light_tween.tween_property(
								node.material_override,
								"shader_parameter/global_tint",
								target_albedo,
								3.0
							)
						else:
							_light_tween.tween_property(
								node.material_override, "albedo_color", target_albedo, 3.0
							)
					for child in node.get_children():
						f_ref.call(child, f_ref)

				apply_night_to_meshes.call(floor_mesh, apply_night_to_meshes)


# Thêm hàm dọn dẹp để gọi khi chuyển Scene
func clear_all_objects():
	debug_axes_created = false
	for obj in objects_in_scene.values():
		if is_instance_valid(obj):
			obj.queue_free()
	objects_in_scene.clear()


func _create_debug_axes(parent_node: Node3D):
	var axes_root = Node3D.new()
	axes_root.name = "DebugAxes"

	# Hàm tạo trục bằng BoxMesh để dễ nhìn hơn Line
	var create_axis = func(size_vec, pos_vec, color):
		var mesh_inst = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = size_vec
		mesh_inst.mesh = box
		mesh_inst.position = pos_vec
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = color
		mesh_inst.material_override = mat
		return mesh_inst

	# Trục X (Đỏ), Y (Xanh lá), Z (Xanh dương)
	axes_root.add_child(create_axis.call(Vector3(1000, 2, 2), Vector3(500, 1, 0), Color.RED))
	axes_root.add_child(create_axis.call(Vector3(2, 200, 2), Vector3(0, 100, 0), Color.GREEN))
	axes_root.add_child(create_axis.call(Vector3(2, 2, 1000), Vector3(0, 1, 500), Color.BLUE))

	# Đánh dấu các mốc mỗi 100 đơn vị
	for i in range(0, 1001, 100):
		if i > 0:
			var lx = Label3D.new()
			lx.text = "X:" + str(i)
			lx.position = Vector3(i, 5, 0)
			lx.modulate = Color.RED
			lx.font_size = 64
			lx.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			axes_root.add_child(lx)

			var lz = Label3D.new()
			lz.text = "Z:" + str(i)
			lz.position = Vector3(0, 5, i)
			lz.modulate = Color.DODGER_BLUE
			lz.font_size = 64
			lz.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			axes_root.add_child(lz)

	parent_node.add_child(axes_root)


func update_objects(server_objects: Dictionary, is_night: bool = false):
	_latest_server_data = server_objects

	update_day_night_cycle(is_night)

	var current_scene = get_tree().current_scene
	if (
		current_scene == null
		or not is_instance_valid(current_scene)
		or current_scene.name != "Main"
	):
		return

	var current_ids = server_objects.keys()

	# Đọc hàm nội suy cao độ
	var h_img = get_meta("height_map_img") if has_meta("height_map_img") else null
	var get_ground_y = func(pos_x, pos_z):
		if h_img and not h_img.is_empty():
			var map_s = get_meta("map_config").get("map_size", [1000.0, 1000.0])
			var uv_x = clamp(pos_x / map_s[0], 0.0, 1.0)
			var uv_y = clamp(pos_z / map_s[1], 0.0, 1.0)
			var px = int(uv_x * (h_img.get_width() - 1))
			var py = int(uv_y * (h_img.get_height() - 1))
			var pixel_r = h_img.get_pixel(px, py).r
			return (pixel_r * 255.0) - 128.0
		return 0.0

	for obj_id in current_ids:
		var data = server_objects[obj_id]
		var server_pos = Vector2(data["coord"][0], data["coord"][1])
		var ground_y = get_ground_y.call(server_pos.x, server_pos.y)

		if objects_in_scene.has(obj_id):
			var node = objects_in_scene[obj_id]
			if is_instance_valid(node):
				# Áp dụng cao độ Y để tướng đi dốc lên dốc xuống tự nhiên cộng với offset môi trường
				var target_pos_3d = Vector3(
					server_pos.x, ground_y + data.get("height_offset", 0.0), server_pos.y
				)
				node.position = node.position.lerp(target_pos_3d, 0.4)

				# NGĂN CHẶN XOAY TRỤC ĐỐI VỚI MÔI TRƯỜNG DẠNG ĐƯỜNG (Sông, Đầm lầy)
				if (
					data.has("orientation")
					and not data.get("vfx_type") in ["river_bezier", "swamp_bezier"]
				):
					node.rotation.y = lerp_angle(
						node.rotation.y, -data["orientation"] + (PI / 2.0), 0.2
					)

				if data.has("anim") and node.has_meta("anim_player"):
					var anim_player: AnimationPlayer = node.get_meta("anim_player")
					var current_anim = data["anim"]
					anim_player.speed_scale = data.get("anim_speed", 1.0)

					if (
						anim_player.has_animation(current_anim)
						and anim_player.current_animation != current_anim
					):
						anim_player.play(current_anim, 0.2)

				if data.has("attachments"):
					var attachments = data["attachments"]
					var orb_container = node.get_node_or_null("OrbContainer")
					if orb_container:
						if orb_container.get_child_count() != attachments.size():
							for c in orb_container.get_children():
								c.queue_free()

							var angle_step = PI * 2.0 / float(max(1, attachments.size()))
							for i in range(attachments.size()):
								var att_data = attachments[i]
								var pivot = Node3D.new()
								var angle = i * angle_step
								pivot.position = Vector3(cos(angle) * 25.0, 0, sin(angle) * 25.0)
								orb_container.add_child(pivot)

								var url = att_data.get("model_url", "")
								if url.begins_with("res://"):
									_load_local_model(url, pivot, pivot, {})
								else:
									_load_gltf_model(url, pivot, pivot, {})

				if data.get("client_id") == str(AuthManager.user_id):
					var hp_node = node.get_node_or_null("HPBar")
					if hp_node and hp_node is Label3D:
						var c_hp = data.get("hp", 100)
						var m_hp = data.get("max_hp", 100)
						hp_node.text = str(c_hp) + " / " + str(m_hp)
						hp_node.modulate = Color.GREEN if c_hp > m_hp * 0.3 else Color.RED
			else:
				objects_in_scene.erase(obj_id)
				_create_new_object(obj_id, data, server_pos)
		else:
			_create_new_object(obj_id, data, server_pos)

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

	# Lấy độ cao ngay lúc sinh ra
	var h_img = get_meta("height_map_img") if has_meta("height_map_img") else null
	var ground_y = 0.0
	if h_img and not h_img.is_empty():
		var map_s = get_meta("map_config").get("map_size", [1000.0, 1000.0])
		var uv_x = clamp(start_pos.x / map_s[0], 0.0, 1.0)
		var uv_y = clamp(start_pos.y / map_s[1], 0.0, 1.0)
		var px = int(uv_x * (h_img.get_width() - 1))
		var py = int(uv_y * (h_img.get_height() - 1))
		ground_y = (h_img.get_pixel(px, py).r * 255.0) - 128.0

	var pos_3d = Vector3(start_pos.x, ground_y + data.get("height_offset", 0.0), start_pos.y)
	new_node.position = pos_3d

	# FIX 1: GÁN GÓC XOAY NGAY TỪ ĐẦU ĐỂ KHÔNG BỊ SPIN TRÊN FRAME 1
	if data.has("orientation") and not data.get("vfx_type") in ["river_bezier", "swamp_bezier"]:
		new_node.rotation.y = -data["orientation"] + (PI / 2.0)

	var obj_color = Color(data.get("color", "WHITE"))
	var raw_size = data.get("size", [40, 40])
	var size_x = raw_size[0]
	var size_y = raw_size[1] if raw_size.size() > 1 else raw_size[0]
	var logic_size = Vector2(size_x, size_y)
	var obj_size = Vector3(logic_size.x, 10.0, logic_size.y)
	var vfx_type = data.get("vfx_type", "none")
	var vfx_url = data.get("vfx_url", "")
	var model_url = data.get("model_url", "")

	var visual_node = Node3D.new()
	visual_node.name = "VisualNode"
	new_node.add_child(visual_node)

	var orb_container = Node3D.new()
	orb_container.name = "OrbContainer"
	orb_container.position.y = 15.0
	new_node.add_child(orb_container)

	if model_url != "" and vfx_type == "none" and not model_url.begins_with("res://"):
		var fallback_mesh = MeshInstance3D.new()
		var capsule = CapsuleMesh.new()
		capsule.radius = logic_size.x / 2.0
		capsule.height = logic_size.x * 1.5
		fallback_mesh.mesh = capsule
		fallback_mesh.position.y = capsule.height / 2.0
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color.DEEP_PINK
		fallback_mesh.material_override = mat
		fallback_mesh.name = "FallbackMesh"
		visual_node.add_child(fallback_mesh)

	var is_my_team = false
	if _latest_server_data:
		for id in _latest_server_data:
			if _latest_server_data[id].get("client_id") == str(AuthManager.user_id):
				if _latest_server_data[id].get("team") == data.get("team"):
					is_my_team = true
				break

	if is_my_team and not data.get("indestructible", false):
		var vision_light = SpotLight3D.new()
		vision_light.position = Vector3(0, 60, 40)
		vision_light.rotation_degrees = Vector3(-55, 0, 0)
		vision_light.spot_range = 800.0
		vision_light.spot_angle = 45.0
		vision_light.light_energy = 8.0
		vision_light.shadow_enabled = true
		vision_light.light_color = Color(0.85, 0.95, 1.0, 1.0)
		vision_light.shadow_blur = 2.0
		new_node.add_child(vision_light)

		var personal_light = OmniLight3D.new()
		personal_light.position = Vector3(0, 70, 0)
		personal_light.omni_range = 180.0
		personal_light.light_energy = 0.5
		personal_light.shadow_enabled = false
		new_node.add_child(personal_light)

	_add_3d_ui_to_node(new_node, data, obj_size, 1.0)
	get_tree().current_scene.add_child(new_node)
	objects_in_scene[obj_id] = new_node

	if model_url != "":
		if model_url.begins_with("res://"):
			_load_local_model(model_url, visual_node, new_node, data)
		else:
			_load_gltf_model(model_url, visual_node, new_node, data)
	elif vfx_url != "" or vfx_type != "none":
		if vfx_type == "bush":
			# BỤI CỎ ĐÍCH THỰC (MULTIMESH PROCEDURAL GRASS BLADES)
			var multi_mesh = MultiMesh.new()
			multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
			multi_mesh.instance_count = int(obj_size.x * obj_size.z / 10.0)  # Mật độ dày đặc

			# Code cứng 1 cọng cỏ (1 tam giác vuốt nhọn lên cao)
			var st = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			st.set_uv(Vector2(0, 1))
			st.add_vertex(Vector3(-1.5, 0, 0))
			st.set_uv(Vector2(1, 1))
			st.add_vertex(Vector3(1.5, 0, 0))
			st.set_uv(Vector2(0.5, 0))
			st.add_vertex(Vector3(0, 15.0, 0))  # Ngọn cỏ cao 15 đơn vị
			st.generate_normals()
			multi_mesh.mesh = st.commit()

			# Scatter ngẫu nhiên hàng ngàn cọng cỏ trong Bounding Box
			var rng = RandomNumberGenerator.new()
			rng.seed = obj_id.hash()
			for i in range(multi_mesh.instance_count):
				var pos = Vector3(
					rng.randf_range(-obj_size.x / 2, obj_size.x / 2),
					0,
					rng.randf_range(-obj_size.z / 2, obj_size.z / 2)
				)
				var basis = Basis().rotated(Vector3.UP, rng.randf_range(0, PI * 2))
				multi_mesh.set_instance_transform(i, Transform3D(basis, pos))

			var mm_inst = MultiMeshInstance3D.new()
			mm_inst.multimesh = multi_mesh
			mm_inst.position.y = 0.5  # Nâng lên 1 chút cho khỏi cấn mặt đất

			var grass_mat = ShaderMaterial.new()
			grass_mat.shader = load("res://assets/grass_wind.gdshader")
			grass_mat.set_shader_parameter("color_top", Color(0.2, 0.6, 0.2, 1.0))
			grass_mat.set_shader_parameter("color_bottom", Color(0.05, 0.25, 0.1, 1.0))
			grass_mat.set_shader_parameter("wind_speed", 2.0)
			mm_inst.material_override = grass_mat
			visual_node.add_child(mm_inst)

		elif vfx_type in ["river_bezier", "swamp_bezier"]:
			var st = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)

			var pts = data.get("river_points", [])
			if pts.size() >= 2:
				var uv_x = 0.0
				var segments = 100
				var cap_segments = 12
				var v_count = [0]

				# HÀM VẼ GÓC BO TRÒN (ĐÃ ĐƯỢC FIX TOÁN HỌC SIN/COS TUYỆT ĐỐI KHỚP VỚI THÂN)
				var draw_cap = func(
					center_pos: Vector2,
					forward_dir: Vector2,
					radius: float,
					is_start: bool,
					base_uv_x: float
				):
					var right = Vector2(-forward_dir.y, forward_dir.x)

					var c_local = Vector3(
						center_pos.x - start_pos.x, 0.0, center_pos.y - start_pos.y
					)
					st.set_color(Color(1.0, 1.0, 1.0, 1.0))  # Tâm của CAP an toàn tuyệt đối
					st.set_uv(Vector2(base_uv_x, 0.5))
					st.set_normal(Vector3.UP)
					st.set_tangent(Plane(right.x, 0.0, right.y, 1.0))
					st.add_vertex(c_local)

					var c_idx = v_count[0]
					v_count[0] += 1

					var arc_idx = v_count[0]
					for k in range(cap_segments + 1):
						var t = float(k) / float(cap_segments)
						# Tuyệt đối đi từ -90 độ (Mép trái) tới 90 độ (Mép phải)
						var angle = lerp(-PI / 2.0, PI / 2.0, t)

						var offset = Vector2.ZERO
						if is_start:
							# Đỉnh bắt đầu: Bầu ra phía sau (ngược hướng chảy)
							offset = (
								right * (sin(angle) * radius) - forward_dir * (cos(angle) * radius)
							)
						else:
							# Đỉnh kết thúc: Bầu ra phía trước (theo hướng chảy)
							offset = (
								right * (sin(angle) * radius) + forward_dir * (cos(angle) * radius)
							)

						var l_pos = Vector3(
							center_pos.x + offset.x - start_pos.x,
							0.0,
							center_pos.y + offset.y - start_pos.y
						)

						var u_val = base_uv_x + (offset.dot(forward_dir) / 80.0)
						var v_val = (offset.dot(right) / (radius * 2.0)) + 0.5

						st.set_color(Color(0.0, 0.0, 0.0, 1.0))  # Mép ngoài của CAP bị ăn mòn
						st.set_uv(Vector2(u_val, v_val))
						st.set_normal(Vector3.UP)
						st.set_tangent(Plane(right.x, 0.0, right.y, 1.0))
						st.add_vertex(l_pos)
						v_count[0] += 1

						if k > 0:
							if is_start:
								st.add_index(c_idx)
								st.add_index(arc_idx + k)
								st.add_index(arc_idx + k - 1)
							else:
								st.add_index(c_idx)
								st.add_index(arc_idx + k - 1)
								st.add_index(arc_idx + k)

				# 1. Vẽ chỏm tròn đầu tiên
				var p0 = Vector2(pts[0][0], pts[0][1])
				var p1 = Vector2(pts[1][0], pts[1][1])
				draw_cap.call(p0, (p1 - p0).normalized(), pts[0][2] + 30.0, true, 0.0)

				var body_start = v_count[0]

				# 2. Vẽ thân Sông / Đầm lầy
				for i in range(pts.size()):
					var pt = pts[i]
					var p_pos = Vector2(pt[0], pt[1])
					var radius = pt[2] + 30.0

					var forward = Vector2()
					if i < pts.size() - 1:
						forward = (Vector2(pts[i + 1][0], pts[i + 1][1]) - p_pos).normalized()
					elif i > 0:
						forward = (p_pos - Vector2(pts[i - 1][0], pts[i - 1][1])).normalized()

					var right = Vector2(-forward.y, forward.x)
					if i > 0:
						uv_x += p_pos.distance_to(Vector2(pts[i - 1][0], pts[i - 1][1])) / 80.0

					for j in range(segments + 1):
						var t = float(j) / float(segments)
						var offset = right * ((t - 0.5) * 2.0 * radius)

						# Nội suy màu từ Tâm (1.0) ra Rìa (0.0)
						var edge_factor = 1.0 - abs(t - 0.5) * 2.0
						st.set_color(Color(edge_factor, edge_factor, edge_factor, 1.0))

						st.set_uv(Vector2(uv_x, t))
						st.set_normal(Vector3.UP)
						st.set_tangent(Plane(right.x, 0.0, right.y, 1.0))
						st.add_vertex(
							Vector3(
								p_pos.x + offset.x - start_pos.x,
								0.0,
								p_pos.y + offset.y - start_pos.y
							)
						)
						v_count[0] += 1

					if i > 0:
						for j in range(segments):
							var c_row = body_start + i * (segments + 1)
							var p_row = body_start + (i - 1) * (segments + 1)
							st.add_index(p_row + j)
							st.add_index(c_row + j)
							st.add_index(p_row + j + 1)
							st.add_index(p_row + j + 1)
							st.add_index(c_row + j)
							st.add_index(c_row + j + 1)

				# 3. Vẽ chỏm tròn cuối
				var idx_last = pts.size() - 1
				var p_last = Vector2(pts[idx_last][0], pts[idx_last][1])
				var p_prev = Vector2(pts[idx_last - 1][0], pts[idx_last - 1][1])
				draw_cap.call(
					p_last, (p_last - p_prev).normalized(), pts[idx_last][2] + 30.0, false, uv_x
				)

				var water_mesh = MeshInstance3D.new()
				water_mesh.mesh = st.commit()
				water_mesh.custom_aabb = AABB(Vector3(-2000, -100, -2000), Vector3(4000, 200, 4000))

				var mat = ShaderMaterial.new()
				var shader_path = (
					"res://assets/swamp_animated.gdshader"
					if vfx_type == "swamp_bezier"
					else "res://assets/water_animated.gdshader"
				)

				if ResourceLoader.exists(shader_path):
					mat.shader = load(shader_path)
				else:
					mat = StandardMaterial3D.new()
					mat.albedo_color = (
						Color(0.25, 0.2, 0.1, 0.8)
						if vfx_type == "swamp_bezier"
						else Color(0.05, 0.4, 0.6, 0.8)
					)
					mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

				if vfx_type == "swamp_bezier":
					water_mesh.position.y = 1.0
				else:
					water_mesh.position.y = 3.0

				water_mesh.material_override = mat
				visual_node.add_child(water_mesh)

		else:
			# CHỈ CHIÊU THỨC KỸ NĂNG: Mới xài Billboard và QuadMesh đứng dựng lên
			var quad = MeshInstance3D.new()
			var plane = QuadMesh.new()  # QuadMesh mặc định quay mặt ra trước
			plane.size = Vector2(obj_size.x, obj_size.z)
			quad.mesh = plane
			quad.position.y = 5.0
			var mat = ShaderMaterial.new()
			mat.shader = load("res://assets/vfx_procedural.gdshader")
			mat.set_shader_parameter("base_color", obj_color)
			quad.material_override = mat
			visual_node.add_child(quad)
			if vfx_url != "":
				_load_texture_for_shader(vfx_url, mat)
	else:
		var mesh_inst = MeshInstance3D.new()
		mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat = StandardMaterial3D.new()
		mat.albedo_color = obj_color
		mat.emission_enabled = true
		mat.emission = obj_color
		mat.emission_energy = 2.0

		if data.get("team") == 1 and obj_color == Color("WHITE"):
			mat.albedo_color = Color.DODGER_BLUE
			mat.emission = Color.DODGER_BLUE
		elif data.get("team") == 2 and obj_color == Color("WHITE"):
			mat.albedo_color = Color.CRIMSON
			mat.emission = Color.CRIMSON

		var box = BoxMesh.new()
		box.size = Vector3(obj_size.x, 10.0, obj_size.z)
		mesh_inst.mesh = box
		mesh_inst.position.y = 5.0
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


func _load_gltf_model(url: String, parent_node: Node3D, root_node: Node3D, data: Dictionary = {}):
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
					var sc = data.get("scale", 1.0)
					if typeof(sc) == TYPE_ARRAY:
						scene.scale = Vector3(sc[0], sc[1], sc[2])
					else:
						scene.scale = Vector3(sc, sc, sc)

					parent_node.add_child(scene)
					var fallback = parent_node.get_node_or_null("FallbackMesh")
					if fallback:
						fallback.hide()
					var anim_player = _find_animation_player(scene)
					if anim_player:
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


func _add_3d_ui_to_node(
	parent: Node3D, data: Dictionary, obj_size: Vector3, ui_offset_scale: float = 1.0
):
	var y_offset = (obj_size.y + 2.5) * ui_offset_scale * 2.0

	var lbl_name = Label3D.new()
	lbl_name.text = data.get("name_display", "Khuyết Danh")
	lbl_name.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl_name.position = Vector3(0, y_offset + 10.0, 0)
	lbl_name.font_size = 64
	lbl_name.outline_size = 8
	parent.add_child(lbl_name)

	var lbl_hp = Label3D.new()
	lbl_hp.name = "HPBar"
	var current_hp = data.get("hp", 100)
	var max_hp = data.get("max_hp", 100)
	lbl_hp.text = str(current_hp) + " / " + str(max_hp)
	lbl_hp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl_hp.position = Vector3(0, y_offset, 0)
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


func _load_local_model(path: String, parent_node: Node3D, root_node: Node3D, data: Dictionary = {}):
	if ResourceLoader.exists(path):
		var packed_scene = load(path)
		if packed_scene:
			var instance = packed_scene.instantiate()
			var sc = data.get("scale", 1.0)
			if typeof(sc) == TYPE_ARRAY:
				instance.scale = Vector3(sc[0], sc[1], sc[2])
			else:
				instance.scale = Vector3(sc, sc, sc)

			parent_node.add_child(instance)
			var anim_player = _find_animation_player(instance)
			if anim_player:
				root_node.set_meta("anim_player", anim_player)
	else:
		print("[Lỗi] Không tìm thấy asset: ", path)

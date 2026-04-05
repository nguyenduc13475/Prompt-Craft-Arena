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

var _latest_server_data = {}  # Truy cập bằng UI
var _is_night_state: bool = false
var _light_tween: Tween

# --- CAMERA BIẾN TOÀN CỤC ---
var _locked_cam_offset: Vector3 = Vector3.ZERO
var _unlocked_cam_pos: Vector3 = Vector3(500, 0, 500)
var _is_first_camera_snap: bool = true


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

	# Cấu hình góc nhìn chuẩn MOBA
	var height = 250.0 * camera_zoom
	var backward_dist = 200.0 * camera_zoom
	var zoom_offset = Vector3(0, height, backward_dist)
	cam.fov = 40.0
	cam.rotation_degrees = Vector3(-50, 0, 0)

	# Nhấn Space để lập tức kéo Camera về giữa Hero (Giống LOL/HotS)
	if Input.is_key_pressed(KEY_SPACE):
		_locked_cam_offset = Vector3.ZERO
		if is_instance_valid(my_hero_node):
			_unlocked_cam_pos = my_hero_node.position

	# LOGIC CAMERA SOFT-LOCK (HotS Style)
	if is_camera_locked and is_instance_valid(my_hero_node):
		if move_vec != Vector3.ZERO:
			# Dịch chuyển offset khi chuột ở mép
			_locked_cam_offset += move_vec * pan_speed * delta * 0.4 * camera_zoom
			var max_offset = 350.0 * camera_zoom  # Tối đa lùi ra xa được bao nhiêu
			if _locked_cam_offset.length() > max_offset:
				_locked_cam_offset = _locked_cam_offset.normalized() * max_offset
		else:
			# Chuột rời mép, camera tự trôi mượt về Hero
			_locked_cam_offset = _locked_cam_offset.lerp(Vector3.ZERO, delta * 3.5)

		var target_look_pos = my_hero_node.position + _locked_cam_offset
		var cam_target_pos = target_look_pos + zoom_offset

		if _is_first_camera_snap or cam.position.distance_to(cam_target_pos) > 500:
			cam.position = cam_target_pos
			_is_first_camera_snap = false
		else:
			cam.position = cam.position.lerp(cam_target_pos, 10.0 * delta)

		# Đồng bộ vị trí cho Unlocked mode
		_unlocked_cam_pos = my_hero_node.position + _locked_cam_offset

	# LOGIC CAMERA UNLOCKED (Trôi tự do)
	elif not is_camera_locked:
		_unlocked_cam_pos += move_vec * pan_speed * delta * camera_zoom
		var cam_target_pos = _unlocked_cam_pos + zoom_offset

		if _is_first_camera_snap:
			cam.position = cam_target_pos
			_is_first_camera_snap = false
		else:
			cam.position = cam.position.lerp(cam_target_pos, 15.0 * delta)


# --- THUẬT TOÁN AUTO-SCALE CHUẨN MOBA CỦA ANH ĐỨC ---
func _apply_auto_scale(scene_node: Node3D, obj_id: String, data: Dictionary = {}):
	var aabb = _get_model_aabb(scene_node)
	var vertex_count = _get_vertex_count(scene_node)

	# Kích thước gốc của Model (Width lấy trục lớn nhất giữa X và Z, Height là Y)
	var current_width = max(aabb.size.x, aabb.size.z)
	var current_height = aabb.size.y

	if current_width < 0.01:
		current_width = 1.0  # Tránh chia cho 0

	var obj_type = data.get("type", "")
	var model_url = data.get("model_url", "")

	if obj_type == "":
		if "tree" in model_url:
			obj_type = "tree"
		elif "rock" in model_url:
			obj_type = "rock"
		elif "wall" in model_url or "cliff" in model_url:
			obj_type = "wall"
		elif "tower" in model_url:
			obj_type = "tower"
		elif "nexus" in model_url:
			obj_type = "nexus"
		elif "shop" in model_url:
			obj_type = "shop"
		elif "minion" in model_url:
			obj_type = "minion"
		elif obj_id.begins_with("orb_"):
			obj_type = "orb"
		elif data.get("client_id", "") != "":
			obj_type = "hero"
		else:
			obj_type = "skill_object"

	var target_width = current_width
	var target_scale = 1.0
	var final_scale_vec = Vector3.ONE

	match obj_type:
		"hero", "monster", "shop_keeper":
			target_width = clamp(data.get("size", [15])[0], 10.0, 20.0)
			target_scale = target_width / current_width
			var expected_height = current_height * target_scale
			final_scale_vec = Vector3(target_scale, target_scale, target_scale)
			if expected_height > 60.0:
				final_scale_vec.y = 60.0 / current_height

		"nexus", "shop":
			target_width = clamp(data.get("size", [60])[0], 40.0, 60.0)
			target_scale = target_width / current_width
			final_scale_vec = Vector3(target_scale, target_scale, target_scale)

		"tower":
			target_width = clamp(data.get("size", [35])[0], 40.0, 50.0)
			target_scale = target_width / current_width
			final_scale_vec = Vector3(target_scale, target_scale, target_scale)

		"tree":
			target_width = clamp(data.get("size", [15])[0], 8.0, 15.0)
			target_scale = (
				(target_width / current_width) * clamp(float(vertex_count) / 3000.0, 0.2, 2.0)
			)
			final_scale_vec = Vector3(target_scale, target_scale, target_scale)

		"rock":
			target_width = clamp(data.get("size", [25])[0], 10.0, 20.0)
			target_scale = (
				(target_width / current_width) * clamp(float(vertex_count) / 3000.0, 0.2, 2.0)
			)
			final_scale_vec = Vector3(target_scale, target_scale, target_scale)

		"wall", "cliff":
			target_width = clamp(data.get("size", [45])[0], 40.0, 50.0)
			target_scale = (
				(target_width / current_width) * clamp(float(vertex_count) / 5000.0, 0.5, 2.0)
			)
			final_scale_vec = Vector3(target_scale, target_scale, target_scale)

		"minion":
			target_width = clamp(data.get("size", [8])[0], 10.0, 20.0)
			target_scale = target_width / current_width
			final_scale_vec = Vector3(target_scale, target_scale, target_scale)

		"orb":
			target_width = 8.0  # Orb thì nhỏ gọn thôi
			target_scale = target_width / current_width
			final_scale_vec = Vector3(target_scale, target_scale, target_scale)

		_:  # Mặc định (Skill object, đạn...)
			target_width = data.get("size", [10])[0]
			target_scale = target_width / current_width
			final_scale_vec = Vector3(target_scale, target_scale, target_scale)

	# --- THÊM NOISE CỐ ĐỊNH DỰA TRÊN OBJ_ID ---
	var rng = RandomNumberGenerator.new()
	rng.seed = obj_id.hash()

	# Tạo độ lệch scale từ -15% đến +15%
	var noise_factor = rng.randf_range(0.85, 1.15)

	# Chặn noise cho các object cần hitbox chuẩn / không phải môi trường
	if obj_type in ["nexus", "tower", "shop", "hero", "minion", "orb", "skill_object"]:
		noise_factor = 1.0

	final_scale_vec *= noise_factor
	scene_node.scale = final_scale_vec

	# Tìm điểm thấp nhất của model sau khi scale và kéo nó lên Y = 0
	var bottom_y = aabb.position.y * final_scale_vec.y
	scene_node.position.y = -bottom_y


func _get_vertex_count(node: Node) -> int:
	var count = 0
	if node is MeshInstance3D and node.mesh:
		for i in range(node.mesh.get_surface_count()):
			var arrays = node.mesh.surface_get_arrays(i)
			if arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] != null:
				count += arrays[Mesh.ARRAY_VERTEX].size()
	for child in node.get_children():
		count += _get_vertex_count(child)
	return count


func _get_model_aabb(node: Node) -> AABB:
	var bounds = AABB()
	var first = true
	var meshes = _get_all_mesh_instances(node)
	for m in meshes:
		if m.mesh:
			var mesh_aabb = m.mesh.get_aabb()
			# Transform AABB theo local transform của mesh con
			var transformed_aabb = m.transform * mesh_aabb
			if first:
				bounds = transformed_aabb
				first = false
			else:
				bounds = bounds.merge(transformed_aabb)
	if first:  # Không tìm thấy mesh nào, trả về hòm mặc định
		bounds = AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))
	return bounds


func _get_all_mesh_instances(node: Node) -> Array:
	var arr = []
	if node is MeshInstance3D:
		arr.append(node)
	for child in node.get_children():
		arr.append_array(_get_all_mesh_instances(child))
	return arr


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
			if floor_mesh and floor_mesh.material_override:
				var target_albedo = (
					Color(0.6, 0.65, 0.8, 1.0) if is_night else Color(1.0, 1.0, 1.0, 1.0)
				)
				_light_tween.tween_property(
					floor_mesh.material_override, "albedo_color", target_albedo, 3.0
				)


# Thêm hàm dọn dẹp để gọi khi chuyển Scene
func clear_all_objects():
	for obj in objects_in_scene.values():
		if is_instance_valid(obj):
			obj.queue_free()
	objects_in_scene.clear()


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

	for obj_id in current_ids:
		var data = server_objects[obj_id]
		var server_pos = Vector2(data["coord"][0], data["coord"][1])

		if objects_in_scene.has(obj_id):
			var node = objects_in_scene[obj_id]
			if is_instance_valid(node):
				var target_pos_3d = Vector3(server_pos.x, 0, server_pos.y)
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
								# FIX: Cấp phát ID riêng cho Orb để hàm _apply_auto_scale không bị loạn hash
								var safe_orb_id = obj_id + "_orb_" + str(i)
								if url.begins_with("res://"):
									_load_local_model(url, pivot, pivot, safe_orb_id, {})
								else:
									_load_gltf_model(url, pivot, pivot, safe_orb_id, {})

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
	var pos_3d = Vector3(start_pos.x, 0, start_pos.y)
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
		# Tự động xoay ngẫu nhiên nếu nó là cây cối / đất đá
		var is_nature = "tree" in model_url or "rock" in model_url
		if is_nature:
			var rng = RandomNumberGenerator.new()
			rng.seed = obj_id.hash()
			visual_node.rotation.y = rng.randf() * PI * 2.0

		if model_url.begins_with("res://"):
			_load_local_model(model_url, visual_node, new_node, obj_id, data)
		else:
			_load_gltf_model(model_url, visual_node, new_node, obj_id, data)
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


func _load_gltf_model(
	url: String, parent_node: Node3D, root_node: Node3D, obj_id: String, data: Dictionary = {}
):
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
					_apply_auto_scale(scene, obj_id, data)
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


func _load_local_model(
	path: String, parent_node: Node3D, root_node: Node3D, obj_id: String, data: Dictionary = {}
):
	if ResourceLoader.exists(path):
		var packed_scene = load(path)
		if packed_scene:
			var instance = packed_scene.instantiate()
			_apply_auto_scale(instance, obj_id, data)
			parent_node.add_child(instance)
			var anim_player = _find_animation_player(instance)
			if anim_player:
				root_node.set_meta("anim_player", anim_player)
	else:
		print("[Lỗi] Không tìm thấy asset: ", path)

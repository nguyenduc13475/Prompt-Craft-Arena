extends Node

signal heroes_list_loaded(heroes_array)
signal hero_created_success(hero_dto)
signal hero_updated_success(hero_dto)
signal api_error(msg)
signal default_models_loaded(models_array)

const API_URL = "http://127.0.0.1:8000/api/heroes"


func load_default_models():
	print("[API] Dang tai danh sach model mac dinh...")
	var req = HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(
		func(_result, code, _headers, body):
			if code == 200:
				var json = JSON.parse_string(body.get_string_from_utf8())
				default_models_loaded.emit(json)
			req.queue_free()
	)
	req.request(API_URL + "/default_models")


func load_my_heroes():
	if not AuthManager.is_logged_in:
		return
	print("[API] Dang tai danh sach Hero...")
	var req = HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(
		func(result, response_code, _headers, body):
			_handle_response(result, response_code, body, "load_heroes")
			req.queue_free()
	)
	req.request(API_URL, AuthManager.get_auth_header(), HTTPClient.METHOD_GET)


func create_and_save_hero(hero_name: String, prompt: String, ugc_vfx_url: String = ""):
	if not AuthManager.is_logged_in:
		return
	print("[API] Dang gui prompt den Gemini de tao Hero...")
	var payload = {"name": hero_name, "prompt": prompt, "ugc_vfx_url": ugc_vfx_url}
	var body_json = JSON.stringify(payload)
	var headers = AuthManager.get_auth_header()
	headers.append("Content-Type: application/json")

	var req = HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(
		func(result, response_code, _headers, body):
			_handle_response(result, response_code, body, "create_hero")
			req.queue_free()
	)
	req.request(API_URL, headers, HTTPClient.METHOD_POST, body_json)


func update_hero(hero_id: String, hero_name: String, model_url: String, skins: Array = []):
	if not AuthManager.is_logged_in:
		return
	print("[API] Dang cap nhat Hero ", hero_id, "...")
	var payload = {"name": hero_name, "model_url": model_url, "skins": skins}
	var body_json = JSON.stringify(payload)
	var headers = AuthManager.get_auth_header()
	headers.append("Content-Type: application/json")

	var req = HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(
		func(result, response_code, _headers, body):
			_handle_response(result, response_code, body, "update_hero")
			req.queue_free()
	)
	req.request(API_URL + "/" + hero_id, headers, HTTPClient.METHOD_PUT, body_json)


func _handle_response(result, response_code, body, action_type):
	if result != HTTPRequest.RESULT_SUCCESS:
		print("[API Loi] Ket noi mang that bai (Result Code: ", result, ")")
		api_error.emit("Lỗi kết nối mạng. Vui lòng kiểm tra lại đường truyền.")
		return

	var body_str = body.get_string_from_utf8()
	var json = JSON.parse_string(body_str)
	if response_code == 200:
		if action_type == "load_heroes" and typeof(json) == TYPE_ARRAY:
			heroes_list_loaded.emit(json)
		elif action_type == "create_hero":
			hero_created_success.emit(json)
		elif action_type == "update_hero":
			hero_updated_success.emit(json)
	else:
		var error_msg = "Lỗi API."
		if json and json.has("detail"):
			error_msg = json["detail"]
		print("[API Loi] ", response_code, " : ", error_msg)
		api_error.emit(str(error_msg))

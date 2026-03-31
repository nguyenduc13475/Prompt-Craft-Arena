extends Node

signal heroes_list_loaded(heroes_array)
signal hero_created_success(hero_dto)
signal api_error(msg)

const API_URL = "http://127.0.0.1:8000/api/heroes"
var http_req: HTTPRequest


func _ready():
	http_req = HTTPRequest.new()
	add_child(http_req)
	http_req.request_completed.connect(_on_request_completed)


func load_my_heroes():
	if not AuthManager.is_logged_in:
		return
	print("[API] Dang tai danh sach Hero...")
	var headers = AuthManager.get_auth_header()
	http_req.request(API_URL, headers, HTTPClient.METHOD_GET)


func create_and_save_hero(hero_name: String, prompt: String, ugc_vfx_url: String = ""):
	if not AuthManager.is_logged_in:
		return
	print("[API] Dang gui prompt den Gemini de tao Hero...")
	var payload = {"name": hero_name, "prompt": prompt, "ugc_vfx_url": ugc_vfx_url}
	var body = JSON.stringify(payload)
	var headers = AuthManager.get_auth_header()
	headers.append("Content-Type: application/json")
	http_req.request(API_URL, headers, HTTPClient.METHOD_POST, body)


func _on_request_completed(result, response_code, _headers, body):
	# Bắt lỗi rớt mạng hoặc không kết nối được Server
	if result != HTTPRequest.RESULT_SUCCESS:
		print("[API Loi] Ket noi mang that bai (Result Code: ", result, ")")
		api_error.emit("Lỗi kết nối mạng. Vui lòng kiểm tra lại đường truyền.")
		return

	var body_str = body.get_string_from_utf8()
	var json = JSON.parse_string(body_str)
	if response_code == 200:
		if typeof(json) == TYPE_ARRAY:
			# List heroes
			heroes_list_loaded.emit(json)
		elif typeof(json) == TYPE_DICTIONARY and json.has("id"):
			# Created hero
			print("[API] Tao va luu Hero thanh cong.")
			hero_created_success.emit(json)
	else:
		var error_msg = "Loi API."
		if json and json.has("detail"):
			error_msg = json["detail"]
		print("[API Loi] ", response_code, " : ", error_msg)
		api_error.emit(str(error_msg))

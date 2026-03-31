extends Node

# Signal báo trạng thái
signal login_success(username)
signal login_failed(error_message)
signal register_success

const API_BASE_URL = "http://127.0.0.1:8000/api/auth"

var auth_token: String = ""
var username: String = ""
var user_id: int = -1
var coins: int = 0
var is_logged_in: bool = false
var http_token_req: HTTPRequest


func _ready():
	http_token_req = HTTPRequest.new()
	add_child(http_token_req)
	http_token_req.request_completed.connect(_on_request_completed)


func register(user: String, password_text: String):
	print("[Auth] Dang ky user: ", user)
	var payload = {"username": user, "password": password_text}
	var body = JSON.stringify(payload)
	var headers = PackedStringArray(["Content-Type: application/json"])
	http_token_req.request(API_BASE_URL + "/register", headers, HTTPClient.METHOD_POST, body)


func login(user: String, password_text: String):
	print("[Auth] Dang nhap user: ", user)
	var payload = {"username": user, "password": password_text}
	var body = JSON.stringify(payload)
	var headers = PackedStringArray(["Content-Type: application/json"])
	# Dùng custom binding để phân biệt response login/register
	http_token_req.request(API_BASE_URL + "/login", headers, HTTPClient.METHOD_POST, body)


func get_auth_header() -> PackedStringArray:
	if auth_token != "":
		return PackedStringArray(["Authorization: Bearer " + auth_token])
	return PackedStringArray()


func _on_request_completed(_result, _response_code, _headers, body):
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null or typeof(json) != TYPE_DICTIONARY:
		login_failed.emit("Lỗi server hoặc sai định dạng dữ liệu.")
		return

	# Dựa vào URL hoặc nội dung để biết là API nào
	# Cách Breadth-first nhanh: check field trả về
	if json.has("access_token"):
		# Login thanh cong
		auth_token = json["access_token"]
		username = json["username"]
		user_id = json["user_id"]
		coins = json.get("coins", 0)
		is_logged_in = true
		print("[Auth] Dang nhap thanh cong! Chào ", username)
		login_success.emit(username)
	elif json.has("message") and json["message"] == "Dang ky thanh cong":
		print("[Auth] Dang ky thanh cong.")
		register_success.emit()
	elif json.has("detail"):
		# Co loi tra ve tu FastAPI
		print("[Auth] Loi API: ", json["detail"])
		login_failed.emit(str(json["detail"]))
	else:
		login_failed.emit("Loi khong xac dinh.")


func logout():
	auth_token = ""
	username = ""
	is_logged_in = false
	get_tree().change_scene_to_file("res://scenes/Login.tscn")

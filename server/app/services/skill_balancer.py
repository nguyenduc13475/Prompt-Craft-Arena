# Mã gốc: toàn bộ tệp

# Mã thay thế:
import json
import os

from google import genai
from google.genai import types

# Khởi tạo Client API mới
# Lưu ý: Client tự động ưu tiên đọc biến môi trường GEMINI_API_KEY nếu có
api_key = os.environ.get("GEMINI_API_KEY", "YOUR_API_KEY")
client = genai.Client(api_key=api_key)

SYSTEM_PROMPT = """
Bạn là AI Game Designer cho game MOBA Top-down.
Nhiệm vụ: Trả về JSON gồm "attributes" và "code" (mã nguồn Python).

Quy tắc Server Game:
- Mỗi tick 0.033s. Object tự động di chuyển nếu `velocity` khác [0,0].
- event.coord là tọa độ [x, y] của chuột.
- TUYỆT ĐỐI KHÔNG dùng lệnh `import`.
- TUYỆT ĐỐI KHÔNG dùng toán tử gán tăng cường (+=, -=). Viết rõ: `enemy.hp = enemy.hp - 100`.
- HỒI CHIÊU: Dùng `getattr(event.self, 'q_last_cast', 0)`. Kiểm tra `event.current_time > q_last_cast + cooldown`.
- HIỂN THỊ (VFX BLUEPRINT): `create_object()` cho các kỹ năng BẮT BUỘC phải có `size` (vd: [30, 30]), `color` (tên màu tiếng Anh, vd: 'ORANGE', 'CYAN', 'PURPLE') và `vfx_type` (chọn một trong: 'fire', 'ice', 'electric', 'dark', 'slash') trong dict thuộc tính để Client áp dụng Shader tương ứng. ĐẶC BIỆT QUAN TRỌNG: Nếu `event.self` có thuộc tính `ugc_vfx_url` (kiểm tra bằng `getattr(event.self, 'ugc_vfx_url', '')`), bạn BẮT BUỘC phải truyền giá trị này vào dictionary của `create_object` với key là `'vfx_url'`, ví dụ: `{'team': event.self.team, 'vfx_url': getattr(event.self, 'ugc_vfx_url', ''), 'size': [40,40], ...}`.
- DI CHUYỂN CƠ BẢN: BẠN BẮT BUỘC PHẢI THÊM ĐOẠN CODE XỬ LÝ DI CHUYỂN BẰNG CHUỘT PHẢI (event.type == 'right') VÀO ĐẦU HÀM `execute`, trừ khi người chơi có yêu cầu cách di chuyển khác lạ.

LƯU Ý QUAN TRỌNG VỀ JSON:
Field `code` BẮT BUỘC là MẢNG CÁC CHUỖI (Array of strings).

Ví dụ Output JSON hợp lệ (Di chuyển mượt mà + Cooldown + Hiển thị):
{
  "attributes": {
    "speed": 250,
    "hp": 1000,
    "max_hp": 1000
  },
  "code": [
    "def execute(event):",
    "    # 1. Nhận lệnh di chuyển",
    "    if event.type == 'right':",
    "        event.self.target_coord = event.coord",
    "    ",
    "    # 2. Xử lý di chuyển vật lý mỗi tick",
    "    if hasattr(event.self, 'target_coord'):",
    "        dx = event.self.target_coord[0] - event.self.coord[0]",
    "        dy = event.self.target_coord[1] - event.self.coord[1]",
    "        dist = math.hypot(dx, dy)",
    "        if dist > 5:",
    "            angle = math.atan2(dy, dx)",
    "            event.self.velocity = [math.cos(angle) * event.self.speed, math.sin(angle) * event.self.speed]",
    "        else:",
    "            event.self.velocity = [0.0, 0.0]",
    "            delattr(event.self, 'target_coord')",
    "    ",
    "    # 3. Kỹ năng người chơi tạo",
    "    if event.type == 'Q':",
    "        q_last = getattr(event.self, 'q_last_cast', 0)",
    "        if event.current_time > q_last + 3.0:",
    "            event.self.q_last_cast = event.current_time",
    "            dx = event.coord[0] - event.self.coord[0]",
    "            dy = event.coord[1] - event.self.coord[1]",
    "            angle = math.atan2(dy, dx)",
    "            proj_vel = [math.cos(angle) * 600, math.sin(angle) * 600]",
    "            def proj_cb(e):",
    "                if e.current_time > e.self.spawn_time + 1.5:",
    "                    delete_object(e.self.id)",
    "                    return",
    "                enemies = get_objects(e.self.coord, 30.0)",
    "                for enemy in enemies:",
    "                    if enemy.team != e.self.team and getattr(enemy, 'hp', None) is not None:",
    "                        enemy.hp = enemy.hp - 100",
    "                        delete_object(e.self.id)",
    "                        break",
    "            create_object({'team': event.self.team, 'velocity': proj_vel, 'spawn_time': event.current_time, 'coord': list(event.self.coord), 'size': [30, 30], 'color': 'ORANGE', 'vfx_type': 'fire', 'vfx_url': getattr(event.self, 'ugc_vfx_url', '')}, proj_cb)"
  ]
}
"""


def generate_skill_logic(prompt: str) -> dict:
    """Gọi Gemini bằng SDK mới để sinh JSON logic kỹ năng"""
    try:
        response = client.models.generate_content(
            model="gemini-3.1-flash-lite-preview",
            contents=f"Mô tả của người chơi: {prompt}",
            config=types.GenerateContentConfig(
                system_instruction=SYSTEM_PROMPT,
                temperature=0.2,  # Nhiệt độ thấp để đảm bảo code sinh ra ổn định và chuẩn cú pháp
                response_mime_type="application/json",  # Ép API trả về JSON thuần túy, không có text hay markdown
            ),
        )

        result = json.loads(response.text.strip())

        # Ghép mảng code thành chuỗi hoàn chỉnh để nạp vào Sandbox
        if "code" in result and isinstance(result["code"], list):
            result["code"] = "\n".join(result["code"])

        return result
    except Exception as e:
        print(f"Lỗi khi gọi Gemini: {e}")
        # In thêm văn bản thô AI trả về để dễ fix nếu vẫn lỗi
        if "response" in locals() and hasattr(response, "text"):
            print(f"Raw response: {response.text}")
        return None

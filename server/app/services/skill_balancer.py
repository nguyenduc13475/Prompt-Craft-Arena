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
- QUAY MẶT KHI DI CHUYỂN (TẦM NHÌN): Khi thay đổi `velocity` để di chuyển, BẮT BUỘC phải cập nhật `event.self.orientation = angle` để hệ thống Sương Mù hình nón biết Tướng đang nhìn hướng nào.
{ANIMATION_INSTRUCTION}

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


def generate_skill_logic(prompt: str, animations: list = None) -> dict:
    """Gọi Gemini bằng SDK mới để sinh JSON logic kỹ năng"""
    try:
        # Chuẩn bị instruction cho animation
        anim_text = ""
        if animations and len(animations) > 0:
            anim_text = f"- ANIMATION 3D: Gán `event.self.current_anim = 'tên_anim'` khi di chuyển hoặc tung chiêu. DANH SÁCH ANIMATION HỢP LỆ CỦA MODEL NÀY LÀ: {animations}. NẾU ĐỨNG IM, GÁN LÀ '{animations[0]}'."
        else:
            anim_text = "- ANIMATION 3D: Model này không có animation. Bỏ qua việc gán `current_anim`."

        final_system_prompt = SYSTEM_PROMPT.replace(
            "{ANIMATION_INSTRUCTION}", anim_text
        )

        print("\n" + "=" * 80)
        print("=== [DEBUG] SYSTEM PROMPT GỬI CHO GEMINI ===")
        print(final_system_prompt)
        print("-" * 80)
        print("=== [DEBUG] USER PROMPT ===")
        print(f"Mô tả của người chơi: {prompt}")
        print("=" * 80 + "\n")

        response = client.models.generate_content(
            model="gemini-3.1-flash-lite-preview",
            contents=f"Mô tả của người chơi: {prompt}",
            config=types.GenerateContentConfig(
                system_instruction=final_system_prompt,
                temperature=0.2,  # Nhiệt độ thấp để đảm bảo code sinh ra ổn định và chuẩn cú pháp
                response_mime_type="application/json",  # Ép API trả về JSON thuần túy, không có text hay markdown
            ),
        )

        raw_text = response.text.strip()

        # Tiền xử lý: Bóc tách JSON an toàn, bỏ qua markdown và thought_signature
        start_idx = raw_text.find("{")
        end_idx = raw_text.rfind("}")

        if start_idx != -1 and end_idx != -1:
            json_str = raw_text[start_idx : end_idx + 1]
            result = json.loads(json_str)
        else:
            raise ValueError("Không tìm thấy cấu trúc JSON hợp lệ trong phản hồi.")

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


def map_animations_with_ai(old_anims: list, new_anims: list) -> dict:
    """Nhờ Gemini hiểu ngữ nghĩa để nối Animation cũ sang Animation mới"""
    if not old_anims or not new_anims:
        return {}

    prompt = f"""
    Tôi có 2 danh sách tên Animation trong game 3D. 
    Danh sách Cũ: {old_anims}
    Danh sách Mới: {new_anims}
    
    Hãy ghép nối mỗi tên trong Danh sách Cũ với một tên có ngữ nghĩa giống/phù hợp nhất trong Danh sách Mới.
    Nếu không có cái nào phù hợp, hãy chọn animation mang tính chất đứng im (Idle) hoặc di chuyển cơ bản trong Danh sách Mới.
    
    TRẢ VỀ DUY NHẤT 1 FILE JSON dạng dictionary (Key là tên cũ, Value là tên mới). Không giải thích gì thêm.
    """
    try:
        response = client.models.generate_content(
            model="gemini-3.1-flash-lite-preview",
            contents=prompt,
            config=types.GenerateContentConfig(
                temperature=0.1,
                response_mime_type="application/json",
            ),
        )
        # Bóc tách JSON
        raw_text = response.text.strip()
        start_idx = raw_text.find("{")
        end_idx = raw_text.rfind("}")
        if start_idx != -1 and end_idx != -1:
            return json.loads(raw_text[start_idx : end_idx + 1])
        return {}
    except Exception as e:
        print(f"[AI Mapper Lỗi] Không thể map animation: {e}")
        # Fallback lười biếng nếu AI sập: Trả về cái đầu tiên của mảng mới
        return {old: new_anims[0] for old in old_anims}

from app.models.object import GameObject
from app.sandbox.compiler import compile_callback

# Thư viện Callback tiêu chuẩn cho Terrain/Cấu trúc
TERRAIN_CALLBACKS = {
    "wall": """
def execute(event):
    # Đẩy lùi các object có máu (Hero, Minion) khi va vào tường (AABB Collider đơn giản)
    objs = get_objects(event.self.coord, max(event.self.size[0], event.self.size[1])/2 + 20)
    for obj in objs:
        if getattr(obj, 'hp', None) is not None and obj.id != event.self.id:
            dx = obj.coord[0] - event.self.coord[0]
            dy = obj.coord[1] - event.self.coord[1]
            # Đẩy ra xa theo trục bị lấn sâu nhất
            if abs(dx) > abs(dy):
                obj.coord[0] = obj.coord[0] + (5 if dx > 0 else -5)
            else:
                obj.coord[1] = obj.coord[1] + (5 if dy > 0 else -5)
""",
    "mud": """
def execute(event):
    # Đầm lầy: Làm chậm 50% bằng cách kéo giật lùi vị trí mỗi tick
    objs = get_objects(event.self.coord, max(event.self.size[0], event.self.size[1])/2)
    for obj in objs:
        if getattr(obj, 'hp', None) is not None and obj.id != event.self.id:
            obj.coord[0] = obj.coord[0] - (obj.velocity[0] * 0.01 * 0.5)
            obj.coord[1] = obj.coord[1] - (obj.velocity[1] * 0.01 * 0.5)
""",
    "spawner": """
def execute(event):
    if not hasattr(event.self, 'last_spawn'):
        event.self.last_spawn = event.current_time
    # Sinh lính dựa trên tham số spawn_rate
    if event.current_time > event.self.last_spawn + getattr(event.self, 'spawn_rate', 5.0):
        event.self.last_spawn = event.current_time
        def minion_ai(e):
            # Minion tự động tìm đường chim bay thẳng về target_base
            target_coord = getattr(e.self, 'target_base', [500, 500])
            dx = target_coord[0] - e.self.coord[0]
            dy = target_coord[1] - e.self.coord[1]
            dist = math.hypot(dx, dy)
            if dist > 50:
                angle = math.atan2(dy, dx)
                e.self.velocity = [math.cos(angle)*60, math.sin(angle)*60]
                e.self.orientation = angle
            else:
                e.self.velocity = [0.0, 0.0]
        # Sinh lính
        create_object({
            'team': event.self.team, 
            'hp': 100, 'max_hp': 100, 
            'coord': list(event.self.coord), 
            'size': [25, 25], 
            'color': 'ORANGE', 
            'bounty': 30, 'exp_reward': 20, 
            'target_base': getattr(event.self, 'target_base', [500,500])
        }, minion_ai)
""",
}


class MapFramework:
    @staticmethod
    def load_from_config(game_state, config_dict: dict):
        """
        Duyệt qua cấu hình JSON Dictionary và sinh các GameObject tương ứng vào game_state.
        Điều này giúp giải phóng hoàn toàn code Hardcode trong game.
        """
        objects_data = config_dict.get("objects", [])

        for obj_data in objects_data:
            obj_type = obj_data.get("type", "generic")
            team = obj_data.get("team", 3)  # Mặc định 3 là Môi trường/Neutral

            # 1. Trích xuất attributes hiển thị cơ bản
            attributes = {
                "name_display": obj_data.get("name", ""),
                "size": obj_data.get("size", [40, 40]),
                "color": obj_data.get("color", "WHITE"),
            }

            # Nạp thêm các thuộc tính riêng biệt (HP, target, stats...)
            if "attributes" in obj_data:
                attributes.update(obj_data["attributes"])

            # 2. Xử lý các cờ phân loại logic hệ thống
            if obj_type == "shop":
                attributes["is_shop"] = True
            elif obj_type == "nexus":
                attributes["is_nexus"] = True

            # Khởi tạo GameObject
            g_obj = GameObject(team=team, attributes=attributes)
            g_obj.coord = obj_data.get("coord", [0.0, 0.0])

            # 3. Gắn Logic Terrain thông minh
            callback_code = None
            if obj_type in TERRAIN_CALLBACKS:
                callback_code = TERRAIN_CALLBACKS[obj_type]
            elif "custom_logic" in obj_data:
                callback_code = obj_data["custom_logic"]

            if callback_code:
                g_obj.callback_func = compile_callback(callback_code)

            # Nạp vào State
            game_state.add_object(g_obj)

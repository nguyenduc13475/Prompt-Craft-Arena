import random

from app.models.object import GameObject
from app.sandbox.compiler import compile_callback

# Thư viện Callback tiêu chuẩn cho Terrain/Cấu trúc
TERRAIN_CALLBACKS = {
    "bush": """
def execute(event):
    # Những ai đứng trong bụi cỏ sẽ được gắn cờ in_bush
    # Lưu ý: Sandbox không cho dùng +=, -= nên ta phải gán trực tiếp
    objs = get_objects(event.self.coord, max(event.self.size[0], event.self.size[1])/2)
    for obj in objs:
        if getattr(obj, 'hp', None) is not None:
            obj.in_bush_id = event.self.id
""",
    "river": """
def execute(event):
    # Làm chậm những ai đi ngang qua sông 20%
    objs = get_objects(event.self.coord, max(event.self.size[0], event.self.size[1])/2)
    for obj in objs:
        if getattr(obj, 'hp', None) is not None and getattr(obj, 'in_river_id', '') != event.self.id:
            obj.in_river_id = event.self.id
""",
    "wall": """
def execute(event):
    # Đẩy lùi các object có máu khi va vào tường (AABB Collider)
    objs = get_objects(event.self.coord, max(event.self.size[0], event.self.size[1])/2 + 20)
    for obj in objs:
        if getattr(obj, 'hp', None) is not None and obj.id != event.self.id:
            dx = obj.coord[0] - event.self.coord[0]
            dy = obj.coord[1] - event.self.coord[1]
            if abs(dx) > abs(dy):
                obj.coord[0] = obj.coord[0] + (5 if dx > 0 else -5)
            else:
                obj.coord[1] = obj.coord[1] + (5 if dy > 0 else -5)
""",
    "mud": """
def execute(event):
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
    if event.current_time > event.self.last_spawn + getattr(event.self, 'spawn_rate', 15.0):
        event.self.last_spawn = event.current_time
        
        def minion_ai(e):
            # Di chuyển theo Waypoints
            wps = getattr(e.self, 'waypoints', [])
            idx = getattr(e.self, 'wp_index', 0)
            if idx < len(wps):
                target_coord = wps[idx]
                dx = target_coord[0] - e.self.coord[0]
                dy = target_coord[1] - e.self.coord[1]
                dist = math.hypot(dx, dy)
                if dist > 30:
                    angle = math.atan2(dy, dx)
                    e.self.velocity = [math.cos(angle)*80, math.sin(angle)*80]
                    e.self.orientation = angle
                else:
                    e.self.wp_index = idx + 1
            else:
                e.self.velocity = [0.0, 0.0]
            
            # AI Tấn công cơ bản
            if not hasattr(e.self, 'last_atk'): e.self.last_atk = 0
            if e.current_time > e.self.last_atk + 1.5:
                enemies = get_objects(e.self.coord, 120.0)
                for en in enemies:
                    if en.team != e.self.team and getattr(en, 'hp', None) is not None and en.hp > 0:
                        en.hp = en.hp - getattr(e.self, 'attack_damage', 15)
                        e.self.last_atk = e.current_time
                        e.self.velocity = [0.0, 0.0] # Dừng lại để đánh
                        break

        create_object({
            'team': event.self.team, 'hp': 300, 'max_hp': 300, 
            'coord': list(event.self.coord), 'size': [20, 20], 
            'color': 'DODGER_BLUE' if event.self.team==1 else 'CRIMSON', 
            'bounty': 20, 'exp_reward': 20, 
            'waypoints': getattr(event.self, 'waypoints', []), 'wp_index': 0,
            'model_url': getattr(event.self, 'minion_model', '')
        }, minion_ai)
""",
    "tower": """
def execute(event):
    if not hasattr(event.self, 'last_attack'):
        event.self.last_attack = event.current_time
        
    if getattr(event.self, 'hp', 0) <= 0:
        event.self.is_deleted = True
        return

    # Tốc đánh của trụ
    if event.current_time > event.self.last_attack + getattr(event.self, 'attack_speed', 1.2):
        enemies = get_objects(event.self.coord, getattr(event.self, 'attack_range', 300.0))
        target = None
        for e in enemies:
            if e.team != event.self.team and getattr(e, 'hp', None) is not None and e.hp > 0:
                target = e
                break
                
        if target:
            event.self.last_attack = event.current_time
            target_pos = list(target.coord)
            
            def bullet_cb(ev):
                if not hasattr(ev.self, 'target_pos'):
                    ev.self.target_pos = target_pos
                dx = ev.self.target_pos[0] - ev.self.coord[0]
                dy = ev.self.target_pos[1] - ev.self.coord[1]
                dist = math.hypot(dx, dy)
                if dist < 20:
                    hit_objs = get_objects(ev.self.coord, 40.0)
                    for ho in hit_objs:
                        if ho.team != ev.self.team and getattr(ho, 'hp', None) is not None:
                            ho.hp = ho.hp - getattr(ev.self, 'damage', 120)
                    delete_object(ev.self.id)
                else:
                    angle = math.atan2(dy, dx)
                    ev.self.velocity = [math.cos(angle)*500, math.sin(angle)*500]
                    
            create_object({
                'team': event.self.team, 'coord': list(event.self.coord),
                'size': [15, 15], 'color': 'YELLOW', 
                'damage': getattr(event.self, 'attack_damage', 120)
            }, bullet_cb)
""",
}


class MapFramework:
    @staticmethod
    @staticmethod
    def load_from_layers(game_state, layers: dict):
        CELL_SIZE = 40.0  # 25x25 grid * 40 = 1000x1000 map

        wp_t1_top = [[100, 400], [100, 900], [500, 900], [900, 900]]
        wp_t1_mid = [[300, 300], [500, 500], [700, 700], [900, 900]]
        wp_t1_bot = [[400, 100], [900, 100], [900, 500], [900, 900]]
        wp_t2_top = [[500, 900], [100, 900], [100, 400], [100, 100]]
        wp_t2_mid = [[700, 700], [500, 500], [300, 300], [100, 100]]
        wp_t2_bot = [[900, 500], [900, 100], [400, 100], [100, 100]]

        spawner_idx_t1 = 0
        spawner_idx_t2 = 0
        wps_t1 = [wp_t1_top, wp_t1_mid, wp_t1_bot]
        wps_t2 = [wp_t2_top, wp_t2_mid, wp_t2_bot]

        nature_props = [
            "res://assets/environments/tree_1.glb",
            "res://assets/environments/tree_2.glb",
            "res://assets/environments/tree_3.glb",
            "res://assets/environments/tree_4.glb",
            "res://assets/environments/tree_5.glb",
            "res://assets/environments/tree_6.glb",
            "res://assets/environments/tree_7.glb",
            "res://assets/environments/tree_8.glb",
            "res://assets/environments/tree_9.glb",
            "res://assets/environments/tree_10.glb",
            "res://assets/environments/rock.glb",
        ]

        # Xử lý từng layer một
        for layer_name, ascii_lines in layers.items():
            for row_idx, row_str in enumerate(ascii_lines):
                for col_idx, char in enumerate(row_str):
                    if char == " ":
                        continue

                    x = col_idx * CELL_SIZE + (CELL_SIZE / 2)
                    y = row_idx * CELL_SIZE + (CELL_SIZE / 2)
                    obj_data = None

                    if char == "X" and layer_name == "boundary":
                        # Tường viền cứng
                        obj_data = {
                            "type": "wall",
                            "team": 3,
                            "coord": [x, y],
                            "size": [CELL_SIZE, CELL_SIZE],
                            "color": "DARK_GRAY",
                            "attributes": {
                                "indestructible": True,
                                "model_url": random.choice(nature_props),
                            },
                        }
                    elif char == "W" and layer_name == "wall":
                        # Rừng nội bộ (có thể phá)
                        obj_data = {
                            "type": "wall",
                            "team": 3,
                            "coord": [x, y],
                            "size": [CELL_SIZE, CELL_SIZE],
                            "color": "GRAY",
                            "attributes": {
                                "hp": 500,
                                "model_url": random.choice(nature_props),
                            },
                        }
                    elif char == "~" and layer_name == "river":
                        obj_data = {
                            "type": "river",
                            "team": 3,
                            "coord": [x, y],
                            "size": [CELL_SIZE, CELL_SIZE],
                            "color": "AQUA",
                            "attributes": {"vfx_type": "river"},
                        }
                    elif char == "B" and layer_name == "bush":
                        obj_data = {
                            "type": "bush",
                            "team": 3,
                            "coord": [x, y],
                            "size": [CELL_SIZE, CELL_SIZE],
                            "color": "DARK_GREEN",
                            "attributes": {"vfx_type": "bush"},
                        }
                    elif char == "M" and layer_name == "structures":
                        obj_data = {
                            "type": "shop",
                            "team": 3,
                            "coord": [x, y],
                            "size": [60, 60],
                            "name": "Cửa Hàng",
                            "color": "YELLOW",
                            "attributes": {
                                "is_shop": True,
                                "stock": [
                                    {
                                        "id": "item_1",
                                        "name": "Giày Chạy Phóng",
                                        "price": 300,
                                        "drop": False,
                                        "type": "passive",
                                        "stats": {"speed_mult": 1.5},
                                    }
                                ],
                            },
                        }
                    elif char == "S" and layer_name == "structures":
                        team = 1 if row_idx < len(ascii_lines) / 2 else 2
                        wp_list = (
                            wps_t1[spawner_idx_t1 % 3]
                            if team == 1
                            else wps_t2[spawner_idx_t2 % 3]
                        )
                        if team == 1:
                            spawner_idx_t1 += 1
                        else:
                            spawner_idx_t2 += 1

                        obj_data = {
                            "type": "spawner",
                            "team": team,
                            "coord": [x, y],
                            "size": [40, 40],
                            "attributes": {"waypoints": wp_list, "spawn_rate": 15.0},
                        }

                    if obj_data:
                        attributes = {
                            "name_display": obj_data.get("name", ""),
                            "size": obj_data.get("size", [CELL_SIZE, CELL_SIZE]),
                            "color": obj_data.get("color", "WHITE"),
                        }
                        if "attributes" in obj_data:
                            attributes.update(obj_data["attributes"])

                        g_obj = GameObject(
                            team=obj_data.get("team", 3), attributes=attributes
                        )
                        g_obj.coord = obj_data["coord"]

                        callback_code = TERRAIN_CALLBACKS.get(obj_data["type"], None)
                        if callback_code:
                            g_obj.callback_func = compile_callback(callback_code)

                        game_state.add_object(g_obj)

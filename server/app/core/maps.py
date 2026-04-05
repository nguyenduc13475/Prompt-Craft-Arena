# Mã thay thế:
import os
import random

from app.core.map_framework import TERRAIN_CALLBACKS
from app.models.object import GameObject
from app.sandbox.compiler import compile_callback
from PIL import Image

# ==========================================
# 1. CẤU HÌNH MAP 3 ĐƯỜNG CỔ ĐIỂN (CHUẨN LOL)
# ==========================================
CONFIG_3LANE = {
    "displacement": None,
    "ground": "environments/grounds/ground_1.jpg",
    "water": [  # Dòng sông vắt chéo từ Top-Left xuống Bottom-Right
        (0.0, 0.0, 80.0),
        (300.0, 300.0, 90.0),
        (500.0, 500.0, 140.0),  # Phình to ở Mid để giao tranh
        (700.0, 700.0, 90.0),
        (1000.0, 1000.0, 80.0),
    ],
    "swamp": None,
    "tree": [
        # Thêm ngẫu nhiên hàng trăm cây vào các khu vực Rừng (Jungle) để tạo sương mù và chướng ngại vật
    ]
    + [
        (
            x,
            y,
            random.uniform(0, 6.28),
            f"res://assets/environments/tree/tree_{random.randint(1, 4)}.glb",
            True,
        )
        for x in range(150, 450, 80)
        for y in range(550, 850, 80)
        if abs(x - y) > 150
    ]
    + [
        (
            x,
            y,
            random.uniform(0, 6.28),
            f"res://assets/environments/tree/tree_{random.randint(5, 8)}.glb",
            True,
        )
        for x in range(550, 850, 80)
        for y in range(150, 450, 80)
        if abs(x - y) > 150
    ],
    "rock": [
        # Vài mỏm đá rải rác
        (400, 600, 0.0, "res://assets/environments/rock/rock_1.glb", True),
        (600, 400, 1.5, "res://assets/environments/rock/rock_2.glb", True),
    ],
    "wall": [
        # --- TƯỜNG BAO QUANH BẢN ĐỒ (OUTER WALLS) ---
    ]
    + [
        (x, 20, 0.0, "res://assets/environments/wall/wall_1.glb", False)
        for x in range(20, 1000, 50)
    ]
    + [
        (x, 980, 0.0, "res://assets/environments/wall/wall_1.glb", False)
        for x in range(20, 1000, 50)
    ]
    + [
        (20, y, 1.57, "res://assets/environments/wall/wall_1.glb", False)
        for y in range(20, 1000, 50)
    ]
    + [
        (980, y, 1.57, "res://assets/environments/wall/wall_1.glb", False)
        for y in range(20, 1000, 50)
    ]
    # --- TƯỜNG BẢO VỆ BASE TEAM 1 (Bottom-Left) ---
    + [
        (x, 700, 0.0, "res://assets/environments/wall/wall_2.glb", False)
        for x in range(20, 350, 50)
        if x not in [70, 120, 270, 320]
    ]  # Cổng Top và Mid
    + [
        (300, y, 1.57, "res://assets/environments/wall/wall_2.glb", False)
        for y in range(700, 1000, 50)
        if y not in [700, 750, 850, 900]
    ]  # Cổng Mid và Bot
    # --- TƯỜNG BẢO VỆ BASE TEAM 2 (Top-Right) ---
    + [
        (x, 300, 0.0, "res://assets/environments/wall/wall_2.glb", False)
        for x in range(700, 1000, 50)
        if x not in [700, 750, 850, 900]
    ]  # Cổng Mid và Bot
    + [
        (700, y, 1.57, "res://assets/environments/wall/wall_2.glb", False)
        for y in range(20, 350, 50)
        if y not in [70, 120, 270, 320]
    ],  # Cổng Top và Mid
    "cliff": [],
    "bush": [
        # (x, y, w, h, rotation, destructivity)
        # Bụi cỏ ven sông (Gank Mid)
        (400, 450, 80, 60, 0.0, False),
        (600, 550, 80, 60, 0.0, False),
        # Bụi cỏ Rừng
        (250, 650, 100, 60, -0.5, False),
        (750, 350, 100, 60, -0.5, False),
        # Bụi cỏ rình rập ở 2 rãnh Top/Bot
        (100, 500, 40, 120, 0.0, False),
        (900, 500, 40, 120, 0.0, False),
    ],
    "structure": [
        [  # ================== TEAM 1 (Góc Trái Dưới) ==================
            (
                100,
                900,
                0.78,
                "res://assets/environments/nexus/nexus_1.glb",
                True,
            ),  # Nhà Chính
            (
                50,
                950,
                0.78,
                "res://assets/environments/shop/magic/shop_magic_1.glb",
                False,
            ),  # Cửa Hàng
            # Nhà Lính (Spawners)
            (100, 750, 0.0, "res://assets/environments/nexus/nexus_2.glb", True),  # Top
            (
                200,
                800,
                0.78,
                "res://assets/environments/nexus/nexus_2.glb",
                True,
            ),  # Mid
            (
                250,
                900,
                1.57,
                "res://assets/environments/nexus/nexus_2.glb",
                True,
            ),  # Bot
            # Trụ (Towers)
            (
                100,
                500,
                0.0,
                "res://assets/environments/tower/tower_1.glb",
                True,
            ),  # Top Tier 1
            (
                100,
                200,
                0.0,
                "res://assets/environments/tower/tower_2.glb",
                True,
            ),  # Top Tier 2
            (
                350,
                650,
                0.78,
                "res://assets/environments/tower/tower_1.glb",
                True,
            ),  # Mid Tier 1
            (
                450,
                550,
                0.78,
                "res://assets/environments/tower/tower_2.glb",
                True,
            ),  # Mid Tier 2
            (
                500,
                900,
                0.0,
                "res://assets/environments/tower/tower_1.glb",
                True,
            ),  # Bot Tier 1
            (
                800,
                900,
                0.0,
                "res://assets/environments/tower/tower_2.glb",
                True,
            ),  # Bot Tier 2
        ],
        [  # ================== TEAM 2 (Góc Phải Trên) ==================
            (
                900,
                100,
                0.78,
                "res://assets/environments/nexus/nexus_1.glb",
                True,
            ),  # Nhà Chính
            (
                950,
                50,
                0.78,
                "res://assets/environments/shop/magic/shop_magic_1.glb",
                False,
            ),  # Cửa Hàng
            # Nhà Lính (Spawners)
            (900, 250, 0.0, "res://assets/environments/nexus/nexus_2.glb", True),  # Bot
            (
                800,
                200,
                0.78,
                "res://assets/environments/nexus/nexus_2.glb",
                True,
            ),  # Mid
            (
                750,
                100,
                1.57,
                "res://assets/environments/nexus/nexus_2.glb",
                True,
            ),  # Top
            # Trụ (Towers)
            (
                200,
                100,
                0.0,
                "res://assets/environments/tower/tower_2.glb",
                True,
            ),  # Top Tier 2
            (
                500,
                100,
                0.0,
                "res://assets/environments/tower/tower_1.glb",
                True,
            ),  # Top Tier 1
            (
                650,
                350,
                0.78,
                "res://assets/environments/tower/tower_2.glb",
                True,
            ),  # Mid Tier 2
            (
                550,
                450,
                0.78,
                "res://assets/environments/tower/tower_1.glb",
                True,
            ),  # Mid Tier 1
            (
                900,
                500,
                0.0,
                "res://assets/environments/tower/tower_1.glb",
                True,
            ),  # Bot Tier 1
            (
                900,
                800,
                0.0,
                "res://assets/environments/tower/tower_2.glb",
                True,
            ),  # Bot Tier 2
        ],
    ],
}


# ==========================================
# 2. HÀM CALLBACK KHỞI TẠO CHO MAP 3 ĐƯỜNG
# ==========================================
def init_3lane_callback(config: dict) -> list:
    """Hàm này đọc Config và sinh ra mảng các Object cho Map 3Lane"""
    objects = []
    CELL_SIZE = 40.0

    # 2.1 Quét Image Mask (Đầm lầy, Sông)
    def process_mask(mask_path, obj_type, color, vfx, callback_code):
        if not mask_path:
            return
        physical_path = (
            f"app/static/{mask_path}" if not mask_path.startswith("app/") else mask_path
        )
        if not os.path.exists(physical_path):
            print(f"[Map Server] Cảnh báo: Không tìm thấy mask tại {physical_path}")
            return

        try:
            img = Image.open(physical_path).convert("L")
            grid_w, grid_h = int(1000 / CELL_SIZE), int(1000 / CELL_SIZE)
            img = img.resize((grid_w, grid_h), Image.NEAREST)

            for y in range(grid_h):
                for x in range(grid_w):
                    if img.getpixel((x, y)) > 128:
                        g_obj = GameObject(
                            team=3,
                            attributes={
                                "type": obj_type,
                                "size": [CELL_SIZE * 1.5, CELL_SIZE * 1.5],
                                "color": color,
                                "vfx_type": vfx,
                                "indestructible": True,
                            },
                        )
                        g_obj.coord = [
                            x * CELL_SIZE + (CELL_SIZE / 2),
                            y * CELL_SIZE + (CELL_SIZE / 2),
                        ]
                        if callback_code:
                            g_obj.callback_func = compile_callback(callback_code)
                        objects.append(g_obj)
        except Exception as e:
            print(f"[Init Map] Loi doc mask {mask_path}: {e}")

    # Khởi tạo object Sông Toán Học (Bezier)
    river_points = config.get("water", [])
    if river_points:
        g_obj = GameObject(
            team=3,
            attributes={
                "type": "river",
                "size": [1000, 1000],
                "color": "AQUA",
                "vfx_type": "river_bezier",
                "indestructible": True,
                "river_points": river_points,
            },
        )
        g_obj.coord = [500.0, 500.0]
        cb = TERRAIN_CALLBACKS.get("river_bezier")
        if cb:
            g_obj.callback_func = compile_callback(cb)
        objects.append(g_obj)

    process_mask(
        config.get("swamp"), "mud", "BROWN", "dark", TERRAIN_CALLBACKS.get("mud")
    )

    # 2.2 Môi trường Tĩnh
    for prop in ["tree", "rock", "wall", "cliff"]:
        for item in config.get(prop, []):
            x, y, rot, url, destruct = item
            g_obj = GameObject(
                team=3,
                attributes={
                    "type": prop,
                    "size": [40, 40],
                    "model_url": url,
                    "indestructible": not destruct,
                },
            )
            g_obj.coord = [x, y]
            g_obj.orientation = rot
            cb = TERRAIN_CALLBACKS.get("wall")
            if cb:
                g_obj.callback_func = compile_callback(cb)
            objects.append(g_obj)

    # 2.3 Bụi cỏ
    for item in config.get("bush", []):
        x, y, w, h, rot, destruct = item
        g_obj = GameObject(
            team=3,
            attributes={
                "type": "bush",
                "size": [w, h],
                "vfx_type": "bush",
                "indestructible": not destruct,
            },
        )
        g_obj.coord = [x, y]
        g_obj.orientation = rot
        cb = TERRAIN_CALLBACKS.get("bush")
        if cb:
            g_obj.callback_func = compile_callback(cb)
        objects.append(g_obj)

    # 2.4 Cấu trúc (Trụ, Nhà chính, Quái rừng)
    for team_idx, team_structs in enumerate(config.get("structure", [])):
        team_id = team_idx + 1
        for item in team_structs:
            x, y, rot, url, destruct = item
            obj_type, size, cb_code, extra_attrs = "structure", [50, 50], None, {}

            if "nexus" in url:
                obj_type, size, extra_attrs = (
                    "nexus",
                    [80, 80],
                    {"hp": 5000, "max_hp": 5000},
                )
                if "nexus_2" in url:
                    obj_type, size = "spawner", [40, 40]

                    # --- AI WAYPOINTS THÔNG MINH CHO LÍNH ---
                    waypoints = []
                    if team_id == 1:
                        if x < 150:
                            waypoints = [[100, 100], [900, 100]]  # Đi Top
                        elif y > 850:
                            waypoints = [[900, 900], [900, 100]]  # Đi Bot
                        else:
                            waypoints = [[500, 500], [900, 100]]  # Đi Mid
                    elif team_id == 2:
                        if y < 150:
                            waypoints = [[100, 100], [100, 900]]  # Đi Top
                        elif x > 850:
                            waypoints = [[900, 900], [100, 900]]  # Đi Bot
                        else:
                            waypoints = [[500, 500], [100, 900]]  # Đi Mid

                    extra_attrs.update({"spawn_rate": 15.0, "waypoints": waypoints})
                    cb_code = TERRAIN_CALLBACKS.get("spawner")

            elif "tower" in url:
                obj_type, size, cb_code = (
                    "tower",
                    [40, 40],
                    TERRAIN_CALLBACKS.get("tower"),
                )
                extra_attrs = {
                    "hp": 2500,
                    "max_hp": 2500,
                    "attack_damage": 150,
                    "attack_range": 350.0,
                }
            elif "shop" in url:
                obj_type, size = "shop", [60, 60]
                extra_attrs = {
                    "is_shop": True,
                    "stock": [
                        {
                            "id": "item_1",
                            "name": "Giày Phóng",
                            "price": 300,
                            "type": "passive",
                            "stats": {"speed_mult": 1.5},
                        }
                    ],
                }

            attrs = {
                "type": obj_type,
                "size": size,
                "model_url": url,
                "indestructible": not destruct,
                "name_display": obj_type.upper(),
            }
            attrs.update(extra_attrs)

            g_obj = GameObject(team=team_id, attributes=attrs)
            g_obj.coord = [x, y]
            g_obj.orientation = rot
            if cb_code:
                g_obj.callback_func = compile_callback(cb_code)
            objects.append(g_obj)

    # 2.5 Tự động Spawn Quái Rừng bằng Logic Callback (Không phụ thuộc config tĩnh)
    monster_spawns = [
        (
            250,
            250,
            0.0,
            "res://assets/environments/monster/tauren/monster_tauren_1.glb",
        ),
        (750, 750, 0.0, "res://assets/environments/monster/cat/monster_cat_1.glb"),
    ]

    monster_ai_code = """
def execute(event):
    if getattr(event.self, 'hp', 0) <= 0:
        event.self.is_deleted = True
        # Ghi chú: Có thể thêm logic tạo object Spawner tàng hình ở đây để 60s sau hồi sinh lại bãi quái
        return
    if not hasattr(event.self, 'last_attack'): event.self.last_attack = 0
    if event.current_time > event.self.last_attack + 1.5:
        enemies = get_objects(event.self.coord, 70.0)
        for e in enemies:
            if getattr(e, 'hp', None) is not None and e.id != event.self.id and e.team != event.self.team:
                e.hp = e.hp - getattr(event.self, 'attack_damage', 60)
                event.self.last_attack = event.current_time
                event.self.current_anim = 'Attack'
                break
"""
    for x, y, rot, url in monster_spawns:
        m_obj = GameObject(
            team=3,  # Team 3 là Neutral (Quái rừng)
            attributes={
                "type": "monster",
                "size": [45, 45],
                "model_url": url,
                "hp": 1500,
                "max_hp": 1500,
                "attack_damage": 60,
                "bounty": 150,
                "exp_reward": 200,
                "indestructible": False,
                "name_display": "MONSTER",
            },
        )
        m_obj.coord = [x, y]
        m_obj.orientation = rot
        m_obj.callback_func = compile_callback(monster_ai_code)
        objects.append(m_obj)

    return objects


# ==========================================
# 3. CẤU HÌNH & CALLBACK MAP ARAM (Dự phòng)
# ==========================================
CONFIG_ARAM = {}


def init_aram_callback(config: dict) -> list:
    return []


# ==========================================
# HỆ THỐNG REGISTRY CHO MAP
# ==========================================
MAP_REGISTRY = {
    "3lane": (CONFIG_3LANE, init_3lane_callback),
    "aram": (CONFIG_ARAM, init_aram_callback),
}


# ==========================================
# 4. HÀM MAIN ĐỂ GAME_LOOP GỌI
# ==========================================
def load_map(game_state, map_type: str):
    if map_type == "random":
        available_maps = list(MAP_REGISTRY.keys())
        map_type = random.choice(available_maps)

    if map_type not in MAP_REGISTRY:
        print(f"[Warning] Khong tim thay map '{map_type}', Fallback ve '3lane'.")
        map_type = "3lane"

    config, init_callback = MAP_REGISTRY[map_type]
    map_objects = init_callback(config)

    for obj in map_objects:
        game_state.add_object(obj)

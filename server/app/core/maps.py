import os
import random

from app.core.map_framework import TERRAIN_CALLBACKS
from app.models.object import GameObject
from app.sandbox.compiler import compile_callback
from PIL import Image

# ==========================================
# 1. CẤU HÌNH MAP 3 ĐƯỜNG CỔ ĐIỂN
# ==========================================
CONFIG_3LANE = {
    "displacement": None,
    "ground": "environments/grounds/ground_1.png",
    "water": "environments/masks/mask_1.png",
    "swamp": None,
    "tree": [
        (150, 250, 0.5, "res://assets/environments/tree/tree_1.glb", True),
        (200, 800, 1.2, "res://assets/environments/tree/tree_2.glb", True),
    ],
    "rock": [
        (450, 450, 0.0, "res://assets/environments/rock/rock_1.glb", True),
    ],
    "wall": [],
    "cliff": [
        (500, 100, 0.0, "res://assets/environments/cliff/cliff_1.glb", False),
    ],
    "bush": [
        (350, 350, 80, 80, 0.0, False),
        (650, 650, 80, 80, 0.0, False),
    ],
    "structure": [
        [  # Team 1
            (100, 100, 0, "res://assets/environments/nexus/nexus_1.glb", True),
            (150, 100, 0, "res://assets/environments/nexus/nexus_2.glb", True),
            (300, 100, 0, "res://assets/environments/tower/tower_1.glb", True),
            (50, 50, 0, "res://assets/environments/shop/magic/shop_magic_1.glb", True),
        ],
        [  # Team 2
            (900, 900, 0, "res://assets/environments/nexus/nexus_1.glb", True),
            (850, 900, 0, "res://assets/environments/nexus/nexus_2.glb", True),
            (700, 900, 0, "res://assets/environments/tower/tower_1.glb", True),
            (
                950,
                950,
                0,
                "res://assets/environments/shop/magic/shop_magic_1.glb",
                True,
            ),
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
        # Fix: Khớp đường dẫn vật lý trên server để đọc Mask bằng PIL
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

    process_mask(
        config.get("water"), "river", "AQUA", "river", TERRAIN_CALLBACKS.get("river")
    )
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

    # 2.4 Cấu trúc (Trụ, Nhà chính...)
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
                    extra_attrs.update({"spawn_rate": 15.0, "waypoints": []})
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

    return objects


# ==========================================
# 3. CẤU HÌNH & CALLBACK MAP ARAM (Dự phòng)
# ==========================================
CONFIG_ARAM = {}  # TODO sau


def init_aram_callback(config: dict) -> list:
    return []


# ==========================================
# HỆ THỐNG REGISTRY CHO MAP (List of Tuples / Dict)
# ==========================================
MAP_REGISTRY = {
    "3lane": (CONFIG_3LANE, init_3lane_callback),
    "aram": (CONFIG_ARAM, init_aram_callback),
}


# ==========================================
# 4. HÀM MAIN ĐỂ GAME_LOOP GỌI
# ==========================================
def load_map(game_state, map_type: str):
    """
    Hàm này giờ chỉ đóng vai trò phân phối (Router).
    Gặp map nào -> Lấy Config + Callback tương ứng -> Nạp vào GameState.
    """
    if map_type == "random":
        # Tự động lấy danh sách tất cả các map đang có trong Registry để random
        # Đéo bao giờ sợ phải sửa lại đoạn này khi thêm map thứ 100 hay 1000
        available_maps = list(MAP_REGISTRY.keys())
        map_type = random.choice(available_maps)

    if map_type not in MAP_REGISTRY:
        print(f"[Warning] Khong tim thay map '{map_type}', Fallback ve '3lane'.")
        map_type = "3lane"

    config, init_callback = MAP_REGISTRY[map_type]

    # 1. GỌI CALLBACK ĐỂ LẤY MẢNG OBJECTS DỰA TRÊN CONFIG ĐÓ
    map_objects = init_callback(config)

    # 2. ĐẨY VÀO GAME STATE
    for obj in map_objects:
        game_state.add_object(obj)

from app.core.map_framework import MapFramework


def load_map(game_state, map_type: str):
    """Sử dụng Framework để tải bản đồ bằng Data-Driven thay vì Hardcode"""

    # Blueprint chung cho cửa hàng (có thể tái sử dụng ở mọi map)
    shop_config = {
        "type": "shop",
        "coord": [500.0, 500.0],
        "name": "Thương Nhân",
        "color": "YELLOW",
        "size": [60, 60],
        "attributes": {
            "stock": [
                {
                    "id": "item_1",
                    "name": "Giày Tốc Độ",
                    "price": 300,
                    "drop": False,
                    "type": "passive",
                    "stats": {"speed_mult": 1.5},
                },
                {
                    "id": "item_2",
                    "name": "Đá Lời Nguyền",
                    "price": 50,
                    "drop": True,
                    "type": "passive",
                    "stats": {"speed_mult": 0.1},
                },
                {
                    "id": "item_3",
                    "name": "Bình Máu",
                    "price": 50,
                    "drop": False,
                    "type": "consumable",
                    "stats": {"heal": 500},
                },
            ]
        },
    }

    if map_type == "aram":
        config = {
            "name": "Đấu trường ARAM",
            "objects": [
                shop_config,
                # Hai nhà chính
                {
                    "type": "nexus",
                    "team": 1,
                    "coord": [200.0, 500.0],
                    "color": "BLUE",
                    "size": [80, 80],
                    "attributes": {"hp": 2000, "max_hp": 2000},
                },
                {
                    "type": "nexus",
                    "team": 2,
                    "coord": [800.0, 500.0],
                    "color": "DARK_RED",
                    "size": [80, 80],
                    "attributes": {"hp": 2000, "max_hp": 2000},
                },
                # Máy đẻ lính
                {
                    "type": "spawner",
                    "team": 1,
                    "coord": [250.0, 500.0],
                    "size": [0, 0],
                    "attributes": {"target_base": [800, 500], "spawn_rate": 4.0},
                },
                {
                    "type": "spawner",
                    "team": 2,
                    "coord": [750.0, 500.0],
                    "size": [0, 0],
                    "attributes": {"target_base": [200, 500], "spawn_rate": 4.0},
                },
                # MÔI TRƯỜNG TƯƠNG TÁC
                # Tường định hình đường đi thẳng
                {
                    "type": "wall",
                    "coord": [500.0, 200.0],
                    "color": "GRAY",
                    "size": [600, 100],
                },
                {
                    "type": "wall",
                    "coord": [500.0, 800.0],
                    "color": "GRAY",
                    "size": [600, 100],
                },
                # Bãi đầm lầy giữa map làm chậm người chơi
                {
                    "type": "mud",
                    "coord": [500.0, 500.0],
                    "color": "BROWN",
                    "size": [150, 150],
                },
            ],
        }
    else:
        # TÍNH NĂNG ĐỈNH CAO: TRẬN ĐỊA HỖN LOẠN (RANDOM MAP CHUẨN)
        # Sinh ngẫu nhiên tường và đầm lầy tạo ra map không bao giờ đụng hàng
        import random

        random_walls = [
            {
                "type": "wall",
                "coord": [random.uniform(300, 700), random.uniform(300, 700)],
                "color": "GRAY",
                "size": [random.uniform(50, 150), random.uniform(50, 150)],
            }
            for _ in range(8)
        ]
        random_muds = [
            {
                "type": "mud",
                "coord": [random.uniform(200, 800), random.uniform(200, 800)],
                "color": "BROWN",
                "size": [random.uniform(80, 120), random.uniform(80, 120)],
            }
            for _ in range(4)
        ]

        config = {
            "name": "Map Hỗn Loạn Chống Đoán Trước",
            "objects": [
                shop_config,
                {
                    "type": "nexus",
                    "team": 1,
                    "coord": [150.0, 150.0],
                    "color": "BLUE",
                    "size": [80, 80],
                    "attributes": {"hp": 2000, "max_hp": 2000},
                },
                {
                    "type": "nexus",
                    "team": 2,
                    "coord": [850.0, 850.0],
                    "color": "DARK_RED",
                    "size": [80, 80],
                    "attributes": {"hp": 2000, "max_hp": 2000},
                },
                {
                    "type": "spawner",
                    "team": 1,
                    "coord": [200.0, 200.0],
                    "size": [0, 0],
                    "attributes": {"target_base": [850, 850], "spawn_rate": 5.0},
                },
                {
                    "type": "spawner",
                    "team": 2,
                    "coord": [800.0, 800.0],
                    "size": [0, 0],
                    "attributes": {"target_base": [150, 150], "spawn_rate": 5.0},
                },
            ]
            + random_walls
            + random_muds,
        }

    # Đưa Config vào Framework để chế tạo Map
    MapFramework.load_from_config(game_state, config)

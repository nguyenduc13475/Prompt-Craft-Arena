import random

from app.core.map_framework import TERRAIN_CALLBACKS
from app.models.object import GameObject
from app.sandbox.compiler import compile_callback

# ==========================================
# 1. CẤU HÌNH MAP 3 ĐƯỜNG CỔ ĐIỂN (CHUẨN LOL)
# Cấu trúc mới: (x, y, rotation, scale, height_offset, glb_url, destructivity)
# ==========================================
CONFIG_3LANE = {
    "background": "environments/textures/background_1.png",
    "ground_model": "environments/models/ground_model_2.glb",
    "ground_texture": [
        "environments/textures/ground_texture_1.jpg",
        "environments/textures/ground_texture_2.jpg",
        "environments/textures/pedestal_texture_1.png",
    ],
    "ground_shader": "res://assets/ground_1.gdshader",
    "height_map": "environments/masks/height_map_2.png",
    "map_size": (1000.0, 1000.0),
    "water": [
        [  # Hồ 1: Vắt chéo từ Top-Left xuống Mid
            (200.0, 200.0, 80.0),
            (250.0, 250.0, 90.0),
            (300.0, 300.0, 140.0),
            (350.0, 350.0, 90.0),
            (400.0, 400.0, 80.0),
        ],
        [  # Hồ 2: Vắt chéo từ Mid xuống Bottom-Right
            (600.0, 600.0, 80.0),
            (650.0, 650.0, 90.0),
            (700.0, 700.0, 140.0),
            (750.0, 750.0, 90.0),
            (800.0, 800.0, 80.0),
        ],
    ],
    "swamp": [
        [(170.0, 380.0, 20.0), (160.0, 410.0, 25.0), (220.0, 430.0, 20.0)],
        [(830.0, 620.0, 20.0), (840.0, 590.0, 25.0), (780.0, 570.0, 20.0)],
    ],
    "tree": [
        (68, 1000, 0, 2, 0, "tree_2.glb", False),
        (200, 1005, 0, 3, 0, "tree_3.glb", False),
        (300, 1005, 0, 2, 0, "tree_4.glb", False),
        (400, 1005, 0, 5, 0, "tree_5.glb", False),
        (500, 1005, 0, 3, 0, "tree_6.glb", False),
        (600, 1005, 0, 3, 0, "tree_7.glb", False),
        (700, 1005, 0, 4, 0, "tree_8.glb", False),
        (800, 1005, 0, 9, 0, "tree_9.glb", False),
        (900, 1005, 0, 10, 0, "tree_10.glb", False),
        (950, 1005, 0, 4, 0, "tree_3.glb", False),
        (330, 1015, 0.5, 3, 0, "tree_3.glb", False),
        (250, 1025, 0.6, 2, 0, "tree_4.glb", False),
        (470, 1025, 0.8, 5, 0, "tree_5.glb", False),
        (420, 1015, 0.9, 3, 0, "tree_6.glb", False),
        (690, 1025, 1.4, 3, 0, "tree_7.glb", False),
        (290, 1025, 0.1, 4, 0, "tree_8.glb", False),
        (550, 1015, 0.9, 9, 0, "tree_9.glb", False),
        (620, 1025, 0.3, 10, 0, "tree_10.glb", False),
        (850, 1015, 0.7, 4, 0, "tree_3.glb", False),
        (0, 932, 0.1, 1.8, 0, "tree_2.glb", False),
        (-5, 800, 0.2, 2.8, 0, "tree_3.glb", False),
        (-5, 700, 0.3, 1.8, 0, "tree_4.glb", False),
        (-5, 600, 0.4, 4.8, 0, "tree_5.glb", False),
        (-5, 500, 0.5, 2.8, 0, "tree_6.glb", False),
        (-5, 400, 0.6, 2.8, 0, "tree_7.glb", False),
        (-5, 300, 0.7, 3.5, 0, "tree_8.glb", False),
        (-5, 200, 0.8, 9, 0, "tree_9.glb", False),
        (-5, 100, 0.9, 10, 0, "tree_10.glb", False),
        (-5, 50, 1.0, 4, 0, "tree_3.glb", False),
        (-15, 670, 1.5, 3.2, 0, "tree_3.glb", False),
        (-25, 750, 1.6, 2.2, 0, "tree_4.glb", False),
        (-25, 530, 1.8, 5.2, 0, "tree_5.glb", False),
        (-15, 580, 1.9, 3.2, 0, "tree_6.glb", False),
        (-25, 310, 2.4, 3.2, 0, "tree_7.glb", False),
        (-25, 710, 1.1, 4.2, 0, "tree_8.glb", False),
        (-15, 450, 1.9, 9.2, 0, "tree_9.glb", False),
        (-25, 380, 1.3, 10.2, 0, "tree_10.glb", False),
        (-15, 150, 1.7, 4.2, 0, "tree_3.glb", False),
        (932, 0, 0.5, 2.3, 0, "tree_2.glb", False),
        (800, -5, 0.8, 3.2, 0, "tree_3.glb", False),
        (700, -5, 0.34, 2.1, 0, "tree_4.glb", False),
        (600, -5, 0.1, 5.5, 0, "tree_5.glb", False),
        (500, -5, 0.41, 2.6, 0, "tree_6.glb", False),
        (400, -5, 0.5, 2.8, 0, "tree_7.glb", False),
        (300, -5, 0.6, 3.6, 0, "tree_8.glb", False),
        (200, -5, 0.1, 8.6, 0, "tree_9.glb", False),
        (100, -5, 0.9, 9, 0, "tree_10.glb", False),
        (50, -5, 0.4, 4.2, 0, "tree_3.glb", False),
        (670, -15, 0.5, 3, 0, "tree_3.glb", False),
        (750, -25, 0.6, 2, 0, "tree_4.glb", False),
        (530, -25, 0.7, 5, 0, "tree_5.glb", False),
        (420, -15, 0.8, 3, 0, "tree_6.glb", False),
        (310, -25, 1.2, 3, 0, "tree_7.glb", False),
        (710, -25, 0.12, 4, 0, "tree_8.glb", False),
        (450, -15, 0.94, 9, 0, "tree_9.glb", False),
        (380, -25, 0.34, 10, 0, "tree_10.glb", False),
        (150, -15, 0.72, 4, 0, "tree_3.glb", False),
        (1000, 68, 0.41, 1.8, 0, "tree_2.glb", False),
        (1005, 200, 0.42, 2.8, 0, "tree_3.glb", False),
        (1005, 300, 0.43, 1.8, 0, "tree_4.glb", False),
        (1005, 400, 0.44, 4.8, 0, "tree_5.glb", False),
        (1005, 500, 0.45, 2.8, 0, "tree_6.glb", False),
        (1005, 600, 0.46, 2.8, 0, "tree_7.glb", False),
        (1005, 700, 0.47, 3.5, 0, "tree_8.glb", False),
        (1005, 800, 0.48, 9, 0, "tree_9.glb", False),
        (1005, 900, 0.49, 10, 0, "tree_10.glb", False),
        (1005, 950, 1.40, 4, 0, "tree_3.glb", False),
        (1015, 330, 1.45, 3.2, 0, "tree_3.glb", False),
        (1025, 250, 1.46, 2.2, 0, "tree_4.glb", False),
        (1025, 470, 1.48, 5.2, 0, "tree_5.glb", False),
        (1015, 420, 1.49, 3.2, 0, "tree_6.glb", False),
        (1025, 690, 2.44, 3.2, 0, "tree_7.glb", False),
        (1025, 290, 1.41, 4.2, 0, "tree_8.glb", False),
        (1015, 550, 1.49, 9.2, 0, "tree_9.glb", False),
        (1025, 620, 1.43, 10.2, 0, "tree_10.glb", False),
        (1015, 850, 1.47, 4.2, 0, "tree_3.glb", False),
    ],
    "rock": [
        (140, 1000, 3.14, 8, 0, "rock_13.glb", False),
        (165, 1000, 3.14, 10, 0, "rock_15.glb", False),
        (192, 1003, 0, 20, 10, "rock_12.glb", False),
        (210, 1015, 0, 40, 0, "rock_1.glb", False),
        (310, 1015, 0, 40, 0, "rock_2.glb", False),
        (410, 1025, 0, 20, 0, "rock_3.glb", False),
        (510, 1015, 0, 20, 0, "rock_4.glb", False),
        (610, 1005, 0, 40, 0, "rock_5.glb", False),
        (710, 1015, 0, 40, 0, "rock_6.glb", False),
        (810, 1025, 0, 40, 0, "rock_7.glb", False),
        (910, 1015, 0, 40, 0, "rock_8.glb", False),
        (940, 1005, 0, 20, 0, "rock_9.glb", False),
        (850, 1015, 0, 40, 0, "rock_10.glb", False),
        (750, 1025, 0, 40, 0, "rock_11.glb", False),
        (650, 1015, 0, 40, 0, "rock_12.glb", False),
        (550, 1005, 0, 5, 0, "rock_13.glb", False),
        (450, 1015, 0, 5, 0, "rock_14.glb", False),
        (350, 1025, 0, 5, 0, "rock_15.glb", False),
        (285, 1025, 0.14, 35, 0, "rock_1.glb", False),
        (385, 1015, 1.17, 45, 0, "rock_2.glb", False),
        (238, 1025, 2.46, 23, 0, "rock_3.glb", False),
        (235, 1015, 1.5, 27, 0, "rock_4.glb", False),
        (320, 1025, 2.0, 38, 0, "rock_5.glb", False),
        (770, 1025, 2.3, 33, 0, "rock_6.glb", False),
        (441, 1025, 1.2, 45, 0, "rock_7.glb", False),
        (182, 1005, 0.6, 47, 0, "rock_8.glb", False),
        (924, 1015, 4.5, 18, 0, "rock_9.glb", False),
        (503, 1015, 3.2, 43, 0, "rock_10.glb", False),
        (642, 1005, 2.2, 39, 0, "rock_11.glb", False),
        (401, 1015, 2.1, 37, 0, "rock_12.glb", False),
        (255, 1015, 0.9, 6, 0, "rock_13.glb", False),
        (762, 1025, 4.2, 7, 0, "rock_14.glb", False),
        (696, 1015, 2.8, 8, 0, "rock_15.glb", False),
        (0, 860, 1.57, 8, 0, "rock_13.glb", False),
        (0, 835, 1.57, 10, 0, "rock_15.glb", False),
        (-3, 808, -1.57, 20, 10, "rock_12.glb", False),
        (-15, 790, -1.57, 40, 0, "rock_1.glb", False),
        (-15, 690, -1.57, 40, 0, "rock_2.glb", False),
        (-25, 590, -1.57, 20, 0, "rock_3.glb", False),
        (-15, 490, -1.57, 20, 0, "rock_4.glb", False),
        (-5, 390, -1.57, 40, 0, "rock_5.glb", False),
        (-15, 290, -1.57, 40, 0, "rock_6.glb", False),
        (-25, 190, -1.57, 40, 0, "rock_7.glb", False),
        (-15, 90, -1.57, 40, 0, "rock_8.glb", False),
        (-5, 60, -1.57, 20, 0, "rock_9.glb", False),
        (-15, 150, -1.57, 40, 0, "rock_10.glb", False),
        (-25, 250, -1.57, 40, 0, "rock_11.glb", False),
        (-15, 350, -1.57, 40, 0, "rock_12.glb", False),
        (-5, 450, -1.57, 5, 0, "rock_13.glb", False),
        (-15, 550, -1.57, 5, 0, "rock_14.glb", False),
        (-25, 650, -1.57, 5, 0, "rock_15.glb", False),
        (-25, 715, 0.14, 35, 0, "rock_1.glb", False),
        (-15, 615, 1.17, 45, 0, "rock_2.glb", False),
        (-25, 762, 2.46, 23, 0, "rock_3.glb", False),
        (-15, 765, 1.5, 27, 0, "rock_4.glb", False),
        (-25, 680, 2.0, 38, 0, "rock_5.glb", False),
        (-25, 230, 2.3, 33, 0, "rock_6.glb", False),
        (-25, 559, 1.2, 45, 0, "rock_7.glb", False),
        (-5, 818, 0.6, 47, 0, "rock_8.glb", False),
        (-15, 76, 4.5, 18, 0, "rock_9.glb", False),
        (-15, 497, 3.2, 43, 0, "rock_10.glb", False),
        (-5, 358, 2.2, 39, 0, "rock_11.glb", False),
        (-15, 599, 2.1, 37, 0, "rock_12.glb", False),
        (-15, 745, 0.9, 6, 0, "rock_13.glb", False),
        (-25, 238, 4.2, 7, 0, "rock_14.glb", False),
        (-15, 304, 2.8, 8, 0, "rock_15.glb", False),
        (860, 0, 0, 8, 0, "rock_13.glb", False),
        (835, 0, 0, 10, 0, "rock_15.glb", False),
        (808, -3, -3.14, 20, 10, "rock_12.glb", False),
        (790, -15, -3.14, 40, 0, "rock_1.glb", False),
        (690, -15, -3.14, 40, 0, "rock_2.glb", False),
        (590, -25, -3.14, 20, 0, "rock_3.glb", False),
        (490, -15, -3.14, 20, 0, "rock_4.glb", False),
        (390, -5, -3.14, 40, 0, "rock_5.glb", False),
        (290, -15, -3.14, 40, 0, "rock_6.glb", False),
        (190, -25, -3.14, 40, 0, "rock_7.glb", False),
        (90, -15, -3.14, 40, 0, "rock_8.glb", False),
        (60, -5, -3.14, 20, 0, "rock_9.glb", False),
        (150, -15, -3.14, 40, 0, "rock_10.glb", False),
        (250, -25, -3.14, 40, 0, "rock_11.glb", False),
        (350, -15, -3.14, 40, 0, "rock_12.glb", False),
        (450, -5, -3.14, 5, 0, "rock_13.glb", False),
        (550, -15, -3.14, 5, 0, "rock_14.glb", False),
        (650, -25, -3.14, 5, 0, "rock_15.glb", False),
        (715, -25, 0.14, 35, 0, "rock_1.glb", False),
        (615, -15, 1.17, 45, 0, "rock_2.glb", False),
        (762, -25, 2.46, 23, 0, "rock_3.glb", False),
        (765, -15, 1.5, 27, 0, "rock_4.glb", False),
        (680, -25, 2.0, 38, 0, "rock_5.glb", False),
        (230, -25, 2.3, 33, 0, "rock_6.glb", False),
        (559, -25, 1.2, 45, 0, "rock_7.glb", False),
        (818, -5, 0.6, 47, 0, "rock_8.glb", False),
        (76, -15, 4.5, 18, 0, "rock_9.glb", False),
        (497, -15, 3.2, 43, 0, "rock_10.glb", False),
        (358, -5, 2.2, 39, 0, "rock_11.glb", False),
        (599, -15, 2.1, 37, 0, "rock_12.glb", False),
        (745, -15, 0.9, 6, 0, "rock_13.glb", False),
        (238, -25, 4.2, 7, 0, "rock_14.glb", False),
        (304, -15, 2.8, 8, 0, "rock_15.glb", False),
        (1000, 140, -1.57, 8, 0, "rock_13.glb", False),
        (1000, 165, -1.57, 10, 0, "rock_15.glb", False),
        (1003, 192, 1.57, 20, 10, "rock_12.glb", False),
        (1015, 210, 1.57, 40, 0, "rock_1.glb", False),
        (1015, 310, 1.57, 40, 0, "rock_2.glb", False),
        (1025, 410, 1.57, 20, 0, "rock_3.glb", False),
        (1015, 510, 1.57, 20, 0, "rock_4.glb", False),
        (1005, 610, 1.57, 40, 0, "rock_5.glb", False),
        (1015, 710, 1.57, 40, 0, "rock_6.glb", False),
        (1025, 810, 1.57, 40, 0, "rock_7.glb", False),
        (1015, 910, 1.57, 40, 0, "rock_8.glb", False),
        (1005, 940, 1.57, 20, 0, "rock_9.glb", False),
        (1015, 850, 1.57, 40, 0, "rock_10.glb", False),
        (1025, 750, 1.57, 40, 0, "rock_11.glb", False),
        (1015, 650, 1.57, 40, 0, "rock_12.glb", False),
        (1005, 550, 1.57, 5, 0, "rock_13.glb", False),
        (1015, 450, 1.57, 5, 0, "rock_14.glb", False),
        (1025, 350, 1.57, 5, 0, "rock_15.glb", False),
        (1025, 285, 0.14, 35, 0, "rock_1.glb", False),
        (1015, 385, 1.17, 45, 0, "rock_2.glb", False),
        (1025, 238, 2.46, 23, 0, "rock_3.glb", False),
        (1015, 235, 1.5, 27, 0, "rock_4.glb", False),
        (1025, 320, 2.0, 38, 0, "rock_5.glb", False),
        (1025, 770, 2.3, 33, 0, "rock_6.glb", False),
        (1025, 441, 1.2, 45, 0, "rock_7.glb", False),
        (1005, 182, 0.6, 47, 0, "rock_8.glb", False),
        (1015, 924, 4.5, 18, 0, "rock_9.glb", False),
        (1015, 503, 3.2, 43, 0, "rock_10.glb", False),
        (1005, 642, 2.2, 39, 0, "rock_11.glb", False),
        (1015, 401, 2.1, 37, 0, "rock_12.glb", False),
        (1015, 255, 0.9, 6, 0, "rock_13.glb", False),
        (1025, 762, 4.2, 7, 0, "rock_14.glb", False),
        (1015, 696, 2.8, 8, 0, "rock_15.glb", False),
    ],
    "wall": [
        (20, 20, 2.35, 15, 0, "wall_4.glb", False),
        (20, 980, 0.77, 15, 0, "wall_4.glb", False),
        (980, 20, -2.35, 15, 0, "wall_4.glb", False),
        (980, 980, -0.77, 15, 0, "wall_4.glb", False),
        (100, 1000, 3.14, 10, 0, "wall_5.glb", False),
        (900, 0, 0.0, 10, 0, "wall_5.glb", False),
        (1000, 100, 1.57, 10, 0, "wall_5.glb", False),
        (0, 900, -1.57, 10, 0, "wall_5.glb", False),
        (135, 630, 0.2, 10, 0, "wall_5.glb", False),
        (205, 660, 0.6, 10, 0, "wall_5.glb", False),
        (370, 865, 1.37, 10, 0, "wall_5.glb", False),
        (340, 795, 0.97, 10, 0, "wall_5.glb", False),
        (630, 135, -1.77, 10, 0, "wall_5.glb", False),
        (660, 205, -2.17, 10, 0, "wall_5.glb", False),
        (865, 370, -2.84, 10, 0, "wall_5.glb", False),
        (795, 340, -2.54, 10, 0, "wall_5.glb", False),
    ]
    + [(i, 1000, 3.14, 10, 0, "wall_3.glb", False) for i in range(225, 500, 45)]
    + [(i, 1000, 3.14, 8, 0, "wall_2.glb", False) for i in range(535, 800, 30)]
    + [(i, 1000, 3.14, 9, 0, "wall_1.glb", False) for i in range(810, 950, 30)]
    + [(1000 - i, 0, 0.0, 10, 0, "wall_3.glb", False) for i in range(225, 500, 45)]
    + [(1000 - i, 0, 0.0, 8, 0, "wall_2.glb", False) for i in range(535, 800, 30)]
    + [(1000 - i, 0, 0.0, 9, 0, "wall_1.glb", False) for i in range(810, 950, 30)]
    + [(1000, i, 1.57, 10, 0, "wall_3.glb", False) for i in range(225, 500, 45)]
    + [(1000, i, 1.57, 8, 0, "wall_2.glb", False) for i in range(535, 800, 30)]
    + [(1000, i, 1.57, 9, 0, "wall_1.glb", False) for i in range(810, 950, 30)]
    + [(0, 1000 - i, -1.57, 10, 0, "wall_3.glb", False) for i in range(225, 500, 45)]
    + [(0, 1000 - i, -1.57, 8, 0, "wall_2.glb", False) for i in range(535, 800, 30)]
    + [(0, 1000 - i, -1.57, 9, 0, "wall_1.glb", False) for i in range(810, 950, 30)],
    "cliff": [],
    "bush": [
        # (x, y, w, h, rotation, destructivity)
        (400, 450, 80, 60, 0.0, False),
        (600, 550, 80, 60, 0.0, False),
        (250, 650, 100, 60, -0.5, False),
        (750, 350, 100, 60, -0.5, False),
        (100, 500, 40, 120, 0.0, False),
        (900, 500, 40, 120, 0.0, False),
    ],
    "structure": [
        [
            (150, 850, 2.34, 70, 30.0, "nexus/nexus_7.glb", True),
            (50, 790, 0.78, 15, 0.0, "shop/magic/shop_magic_1.glb", False),
            (250, 950, 0.78, 12, 0.0, "shop/mechanic/shop_mechanic_1.glb", False),
            (185, 930, 0, 12, 0.0, "shop/scifi/shop_scifi_1.glb", False),
            (50, 700, 0.0, 10, 0.0, "nexus/nexus_3.glb", True),
            (235, 765, 0.78, 10, 0.0, "nexus/nexus_3.glb", True),
            (300, 950, 1.57, 10, 0.0, "nexus/nexus_3.glb", True),
            (150, 800, 1.57, 10, 0.0, "tower/tower_3.glb", True),
            (200, 850, 0.0, 10, 0.0, "tower/tower_3.glb", True),
            (70, 550, 0.0, 15, 0.0, "tower/tower_1.glb", True),
            (70, 300, 0.0, 15, 0.0, "tower/tower_4.glb", True),
            (320, 680, 0.78, 15, 0.0, "tower/tower_1.glb", True),
            (420, 580, 0.78, 15, 0.0, "tower/tower_4.glb", True),
            (450, 930, 1.57, 15, 0.0, "tower/tower_1.glb", True),
            (700, 930, 1.57, 15, 0.0, "tower/tower_4.glb", True),
        ],
        [
            (850, 150, -0.80, 70, 30.0, "nexus/nexus_7.glb", True),
            (950, 210, -2.36, 15, 0.0, "shop/magic/shop_magic_1.glb", False),
            (750, 50, -2.36, 12, 0.0, "shop/mechanic/shop_mechanic_1.glb", False),
            (815, 70, 3.14, 12, 0.0, "shop/scifi/shop_scifi_1.glb", False),
            (700, 50, 3.14, 10, 0.0, "nexus/nexus_3.glb", True),
            (765, 235, -2.36, 10, 0.0, "nexus/nexus_3.glb", True),
            (950, 300, -1.57, 10, 0.0, "nexus/nexus_3.glb", True),
            (850, 200, -1.57, 10, 0.0, "tower/tower_3.glb", True),
            (800, 150, 3.14, 10, 0.0, "tower/tower_3.glb", True),
            (930, 450, -3.14, 15, 0.0, "tower/tower_1.glb", True),
            (930, 700, -3.14, 15, 0.0, "tower/tower_4.glb", True),
            (680, 320, -2.36, 15, 0.0, "tower/tower_1.glb", True),
            (580, 420, -2.36, 15, 0.0, "tower/tower_4.glb", True),
            (550, 70, -1.57, 15, 0.0, "tower/tower_1.glb", True),
            (300, 70, -1.57, 15, 0.0, "tower/tower_4.glb", True),
        ],
    ],
}


def init_3lane_callback(config: dict) -> list:
    objects = []

    # 1. Khởi tạo River / Swamp Bezier
    for terrain_key, obj_type, color_val in [
        ("water", "river", "AQUA"),
        ("swamp", "swamp", "BROWN"),
    ]:
        groups = config.get(terrain_key, [])
        if groups and not isinstance(groups[0], list):
            groups = [groups]
        for pts in groups:
            if not pts:
                continue
            obj = GameObject(
                team=3,
                attributes={
                    "type": obj_type,
                    "size": [1000, 1000],
                    "color": color_val,
                    "vfx_type": f"{obj_type}_bezier",
                    "indestructible": True,
                    "river_points": pts,
                },
            )
            obj.coord = [500.0, 500.0]
            cb = TERRAIN_CALLBACKS.get(f"{obj_type}_bezier")
            if cb:
                obj.callback_func = compile_callback(cb)
            objects.append(obj)

    # 2. Môi trường Tĩnh
    for prop in ["tree", "rock", "wall", "cliff"]:
        for item in config.get(prop, []):
            x, y, rot, scale, y_offset, url, destruct = item

            # Tự động nối chuỗi path nếu user nhập dạng rút gọn (vd: "tree_2.glb")
            if not url.startswith("res://") and not url.startswith("/static/"):
                url = f"res://assets/environments/{prop}/{url}"

            g_obj = GameObject(
                team=3,
                attributes={
                    "type": prop,
                    "size": [40, 40],
                    "scale": scale,
                    "height_offset": y_offset,
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

    # 3. Bụi cỏ
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

    # 4. Cấu trúc
    for team_idx, team_structs in enumerate(config.get("structure", [])):
        team_id = team_idx + 1
        for item in team_structs:
            x, y, rot, scale, y_offset, url, destruct = item

            # Tự động nối chuỗi cho cấu trúc (vd: "nexus/nexus_7.glb" hoặc "tower/tower_1.glb")
            if not url.startswith("res://") and not url.startswith("/static/"):
                url = f"res://assets/environments/{url}"

            obj_type, size, cb_code, extra_attrs = "structure", [50, 50], None, {}

            if "nexus" in url:
                obj_type, size, extra_attrs = (
                    "nexus",
                    [80, 80],
                    {"hp": 5000, "max_hp": 5000},
                )
                if "nexus_2" in url:
                    obj_type, size = "spawner", [40, 40]
                    waypoints = []
                    if team_id == 1:
                        waypoints = (
                            [[100, 100], [900, 100]]
                            if x < 150
                            else [[900, 900], [900, 100]]
                            if y > 850
                            else [[500, 500], [900, 100]]
                        )
                    elif team_id == 2:
                        waypoints = (
                            [[100, 100], [100, 900]]
                            if y < 150
                            else [[900, 900], [100, 900]]
                            if x > 850
                            else [[500, 500], [100, 900]]
                        )
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
                "scale": scale,
                "height_offset": y_offset,
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

    # 5. Quái Rừng
    monster_spawns = [
        (
            250,
            250,
            0.0,
            1.5,
            0.0,
            "res://assets/environments/monster/tauren/monster_tauren_1.glb",
        ),
        (
            750,
            750,
            0.0,
            1.2,
            0.0,
            "res://assets/environments/monster/cat/monster_cat_1.glb",
        ),
    ]
    monster_ai_code = """
def execute(event):
    if getattr(event.self, 'hp', 0) <= 0:
        event.self.is_deleted = True
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
    for x, y, rot, scale, y_offset, url in monster_spawns:
        if not url.startswith("res://") and not url.startswith("/static/"):
            url = f"res://assets/environments/monster/{url}"

        m_obj = GameObject(
            team=3,
            attributes={
                "type": "monster",
                "size": [45, 45],
                "scale": scale,
                "height_offset": y_offset,
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


CONFIG_ARAM = {}


def init_aram_callback(config: dict) -> list:
    return []


MAP_REGISTRY = {
    "3lane": (CONFIG_3LANE, init_3lane_callback),
    "aram": (CONFIG_ARAM, init_aram_callback),
}


def load_map(game_state, map_type: str):
    if map_type == "random":
        map_type = random.choice(list(MAP_REGISTRY.keys()))
    if map_type not in MAP_REGISTRY:
        map_type = "3lane"
    config, init_callback = MAP_REGISTRY[map_type]
    for obj in init_callback(config):
        game_state.add_object(obj)

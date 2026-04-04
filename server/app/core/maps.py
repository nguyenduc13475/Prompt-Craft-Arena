from app.core.map_framework import TERRAIN_CALLBACKS, MapFramework
from app.models.object import GameObject
from app.sandbox.compiler import compile_callback

# Map 3 Đường Cổ Điển - Lưới 25x25 (Tương đương 1000x1000 tọa độ)
MAP_3LANE_LAYERS = {
    "boundary": [  # X = Khối chặn viền bản đồ (Không thể phá hủy)
        "XXXXXXXXXXXXXXXXXXXXXXXXX",
        "XX                     XX",
        "XX                     XX",
        "X                       X",
        "X                       X",
        "X                       X",
        "X                       X",
        "X                       X",
        "X                       X",
        "X                       X",
        "X                       X",
        "X                       X",
        "X                       X",
        "X                       X",
        "X                       X",
        "X                       X",
        "X                       X",
        "X                       X",
        "X                       X",
        "X                       X",
        "X                       X",
        "X                       X",
        "XX                     XX",
        "XX                     XX",
        "XXXXXXXXXXXXXXXXXXXXXXXXX",
    ],
    "river": [  # ~ = Sông (Giảm tốc độ)
        "                         ",
        "                         ",
        "       ~~~               ",
        "      ~~~~~              ",
        "     ~~~~~~~             ",
        "    ~~~~~~~~~            ",
        "   ~~~~~~~~~~~           ",
        "  ~~~~~~~~~~~~~          ",
        " ~~~~~~~~~~~~~~~         ",
        "  ~~~~~~~~~~~~~~~        ",
        "   ~~~~~~~~~~~~~~~       ",
        "    ~~~~~~~~~~~~~~~      ",
        "     ~~~~~~~~~~~~~~~     ",
        "      ~~~~~~~~~~~~~~~    ",
        "       ~~~~~~~~~~~~~~~   ",
        "        ~~~~~~~~~~~~~~~  ",
        "         ~~~~~~~~~~~~~~~ ",
        "          ~~~~~~~~~~~~~  ",
        "           ~~~~~~~~~~~   ",
        "            ~~~~~~~~~    ",
        "             ~~~~~~~     ",
        "              ~~~~~      ",
        "               ~~~       ",
        "                         ",
        "                         ",
    ],
    "wall": [  # W = Tường / Rừng / Đá (Có thể tương tác/phá vỡ sau này)
        "                         ",
        "                         ",
        "                         ",
        "                         ",
        "    WWWWW       WWWWW    ",
        "   WW   WW     WW   WW   ",
        "   W     W     W     W   ",
        "   W     W     W     W   ",
        "   WW   WW     WW   WW   ",
        "    WWWWW       WWWWW    ",
        "                         ",
        "      WW         WW      ",
        "      WW         WW      ",
        "      WW         WW      ",
        "                         ",
        "    WWWWW       WWWWW    ",
        "   WW   WW     WW   WW   ",
        "   W     W     W     W   ",
        "   W     W     W     W   ",
        "   WW   WW     WW   WW   ",
        "    WWWWW       WWWWW    ",
        "                         ",
        "                         ",
        "                         ",
        "                         ",
    ],
    "bush": [  # B = Bụi rậm (Tàng hình/Khuất sight)
        "                         ",
        "                         ",
        "                         ",
        "                         ",
        "                         ",
        "                         ",
        "      BBB       BBB      ",
        "                         ",
        "                         ",
        "           BBB           ",
        "                         ",
        "  BBB               BBB  ",
        "                         ",
        "  BBB               BBB  ",
        "                         ",
        "           BBB           ",
        "                         ",
        "                         ",
        "      BBB       BBB      ",
        "                         ",
        "                         ",
        "                         ",
        "                         ",
        "                         ",
        "                         ",
    ],
}


def load_map(game_state, map_type: str):
    if map_type == "3lane":
        MapFramework.load_from_layers(game_state, MAP_3LANE_LAYERS)

        # TEAM 1 (Bottom Left - Xanh)
        game_state.add_object(_create_tower(1, [100.0, 100.0], "Nexus T1"))
        # Trụ ngoài (Top, Mid, Bot)
        game_state.add_object(_create_tower(1, [150.0, 450.0], "Trụ Top 1"))
        game_state.add_object(_create_tower(1, [400.0, 400.0], "Trụ Mid 1"))
        game_state.add_object(_create_tower(1, [450.0, 150.0], "Trụ Bot 1"))

        # TEAM 2 (Top Right - Đỏ)
        game_state.add_object(_create_tower(2, [900.0, 900.0], "Nexus T2"))
        # Trụ ngoài (Top, Mid, Bot)
        game_state.add_object(_create_tower(2, [550.0, 850.0], "Trụ Top 2"))
        game_state.add_object(_create_tower(2, [600.0, 600.0], "Trụ Mid 2"))
        game_state.add_object(_create_tower(2, [850.0, 550.0], "Trụ Bot 2"))
    else:
        # Tương lai thêm ARAM ở đây
        MapFramework.load_from_layers(game_state, MAP_3LANE_LAYERS)


def _create_tower(team, coord, name):
    is_nexus = "Nexus" in name
    attr = {
        "hp": 5000 if is_nexus else 3000,
        "max_hp": 5000 if is_nexus else 3000,
        "attack_range": 0 if is_nexus else 350.0,
        "attack_damage": 0 if is_nexus else 150,
        "attack_speed": 1.2,
        "name_display": name,
        "is_nexus": is_nexus,
        "size": [100, 100] if is_nexus else [50, 50],
        "model_url": "res://assets/environments/nexus.glb"
        if is_nexus
        else "res://assets/environments/tower.glb",
    }
    obj = GameObject(team=team, attributes=attr)
    obj.coord = coord
    if not is_nexus:
        obj.callback_func = compile_callback(TERRAIN_CALLBACKS["tower"])
    return obj

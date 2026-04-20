import bpy

OUTPUT_FILE = r"C:\Users\pc\Desktop\exported_map_config.txt"
MAP_SIZE = (1000.0, 1000.0)


def export_map():
    # 1. Đếm số lượng Team dựa trên các Collection "Team_X"
    team_collections = [
        col for col in bpy.data.collections if col.name.startswith("Team_")
    ]
    num_teams = 0
    if team_collections:
        # Lấy số lớn nhất từ tên Team_N để tránh lỗi nếu thiếu số ở giữa
        for col in team_collections:
            try:
                t_num = int(col.name.split("_")[1])
                if t_num > num_teams:
                    num_teams = t_num
            except:
                continue

    config_dict = {
        "tree": [],
        "rock": [],
        "wall": [],
        "cliff": [],
        "bush": [],  # Thêm mảng rỗng chứa bush
        "structure": [[] for _ in range(num_teams)],  # Khởi tạo List các List rỗng
    }

    for obj in bpy.context.scene.objects:
        if obj.parent is not None:
            continue

        base_name = obj.name.split(".")[0].lower()

        # Tọa độ (Sync với Import: Game_Y = MAP_SIZE - Blender_Y)
        x = round(obj.location.x, 1)
        y = round(MAP_SIZE[1] - obj.location.y, 1)
        z = round(obj.location.z, 1)

        # Góc xoay (Sync với Import: rot = Init - Blender + 1.57)
        init_rot = obj.get("initial_rot_z", 0.0)
        rot = round(init_rot - obj.rotation_euler[2] + 1.57, 2)

        # Tỷ lệ
        scale = round((obj.scale.x + obj.scale.y + obj.scale.z) / 3.0, 2)

        # PHÂN LOẠI
        if base_name.startswith("tree"):
            config_dict["tree"].append((x, y, rot, scale, z, f"{base_name}.glb", False))
        elif base_name.startswith("rock"):
            config_dict["rock"].append((x, y, rot, scale, z, f"{base_name}.glb", False))
        elif base_name.startswith("wall"):
            config_dict["wall"].append((x, y, rot, scale, z, f"{base_name}.glb", False))
        elif base_name.startswith("cliff"):
            config_dict["cliff"].append(
                (x, y, rot, scale, z, f"{base_name}.glb", False)
            )
        elif base_name.startswith("bush"):
            w = round(obj.dimensions.x, 1)
            h = round(obj.dimensions.y, 1)
            # Áp dụng công thức Godot (init_rot = 0, nên đảo dấu và + 1.57)
            bush_rot = round(1.57 - obj.rotation_euler[2], 2)
            config_dict["bush"].append((x, y, w, h, bush_rot, False))
        else:
            # XỬ LÝ STRUCTURE (Dùng List index)
            destruct = True if ("nexus" in base_name or "tower" in base_name) else False

            # Mặc định Team 1 (Index 0)
            team_idx = 0
            for col in obj.users_collection:
                if col.name.startswith("Team_"):
                    try:
                        # Index = Số team - 1 (Vd: Team_1 -> index 0)
                        team_idx = int(col.name.split("_")[1]) - 1
                    except:
                        pass
                    break

            # Chuẩn hóa đường dẫn URL
            url = f"{base_name}.glb"
            if base_name.startswith("nexus"):
                url = f"nexus/{base_name}.glb"
            elif base_name.startswith("tower"):
                url = f"tower/{base_name}.glb"
            elif "shop" in base_name:
                if "magic" in base_name:
                    url = f"shop/magic/{base_name}.glb"
                elif "mechanic" in base_name:
                    url = f"shop/mechanic/{base_name}.glb"
                elif "scifi" in base_name:
                    url = f"shop/scifi/{base_name}.glb"

            # Đẩy vào đúng list của team trong structure
            if 0 <= team_idx < len(config_dict["structure"]):
                config_dict["structure"][team_idx].append(
                    (x, y, rot, scale, z, url, destruct)
                )

    # XUẤT FILE (Giữ nguyên định dạng list 2D cho structure)
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        f.write("GENERATED_MAP_CONFIG = {\n")
        for key, items in config_dict.items():
            f.write(f'    "{key}": [\n')
            for item in items:
                f.write(f"        {item},\n")
            f.write("    ],\n")
        f.write("}\n")

    print(f"Export thành công với {len(config_dict['structure'])} teams (dạng list)!")


export_map()

import math

import bpy


def fix_all_negative_scales():
    print("--- Đang quét TOÀN BỘ object (Empty & Mesh) để sửa Scale âm ---")
    fixed_count = 0

    # Duyệt qua tất cả object không phân biệt loại (Empty, Mesh, Armature...)
    for obj in bpy.context.scene.objects:
        s = obj.scale

        # Chỉ xử lý nếu X hoặc Y bị âm
        if s.x < 0 or s.y < 0:
            old_sx, old_sy = s.x, s.y

            # 1. Lật về dương
            obj.scale.x = abs(s.x)
            obj.scale.y = abs(s.y)

            # 2. Logic bù trừ xoay Z để giữ nguyên hướng nhìn Visual
            # Quy tắc logic:
            # - Nếu chỉ lật 1 trục (X hoặc Y): Hướng bị ngược -> Xoay thêm 180 độ (PI)
            # - Nếu lật cả 2 trục (X và Y): Thực chất là đã xoay 180 độ -> Không cần làm gì thêm

            flips = 0
            if old_sx < 0:
                flips += 1
            if old_sy < 0:
                flips += 1

            if flips == 1:
                # Ép mode XYZ để can thiệp euler chính xác
                if obj.rotation_mode != "XYZ":
                    obj.rotation_mode = "XYZ"

                # Cộng thêm 180 độ vào trục đứng
                obj.rotation_euler[2] += math.pi

            fixed_count += 1
            print(
                f"Fixed {obj.type}: {obj.name} | Scale ({old_sx:.2f}, {old_sy:.2f}) -> Positive"
            )

    print(f"--- Hoàn tất! Đã sửa {fixed_count} đối tượng. ---")


# Thực thi script
fix_all_negative_scales()

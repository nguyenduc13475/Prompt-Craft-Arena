import math

from app.core.state import global_game_state
from app.models.object import GameObject


def safe_get_objects(location: tuple, radius: float = 50.0):
    """Tìm các object xung quanh 1 tọa độ"""
    found = []
    for obj in global_game_state.objects.values():
        if obj.is_deleted:
            continue
        # Công thức khoảng cách cơ bản
        dist = math.hypot(obj.coord[0] - location[0], obj.coord[1] - location[1])
        if dist <= radius:
            found.append(obj)
    return found


def safe_create_object(attributes: dict, callback_func) -> str:
    """Tạo object mới từ code AI (nhận trực tiếp function/lambda)"""
    team = attributes.get("team", 3)
    bbox = attributes.get("bounding_box", ((0, 0), (0, 0), (0, 0), (0, 0)))

    new_obj = GameObject(team=team, bounding_box=bbox, attributes=attributes)
    # Gắn trực tiếp hàm logic AI sinh ra vào object (ví dụ: đạn, vùng sát thương)
    new_obj.callback_func = callback_func

    return global_game_state.add_object(new_obj)


def safe_delete_object(obj_id: str):
    """Đánh dấu xóa object"""
    global_game_state.remove_object(obj_id)


def safe_contain(coord: tuple, bounding_box: tuple, location: tuple) -> bool:
    """Kiểm tra 1 điểm có nằm trong bounding box không (Logic rút gọn)"""
    # TODO: Cần logic tính toán hình học phức tạp hơn dựa trên bounding_box thật
    # Tạm thời trả về khoảng cách cơ bản < 10 để test
    dist = math.hypot(coord[0] - location[0], coord[1] - location[1])
    return dist < 10.0


# Danh sách whitelist các hàm được phép dùng trong môi trường Restricted
SAFE_BUILTINS = {
    "get_objects": safe_get_objects,
    "create_object": safe_create_object,
    "delete_object": safe_delete_object,
    "contain": safe_contain,
    "True": True,
    "False": False,
    "None": None,
    "print": print,  # Có thể tắt khi lên Production
    "math": math,
    "hasattr": hasattr,
    "getattr": getattr,
    "delattr": delattr,
    "list": list,
}

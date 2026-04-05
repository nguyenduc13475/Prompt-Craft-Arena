import uuid
from typing import Callable, Dict, Tuple


class Event:
    """Lớp lưu trữ ngữ cảnh trong 1 time slot để truyền vào callback"""

    def __init__(
        self,
        current_time: float,
        self_obj: "GameObject",
        event_type: str = None,
        coord: Tuple[float, float] = None,
    ):
        self.current_time = current_time
        self.self = self_obj
        self.type = event_type  # "Q", "W", "right", v.v.
        self.coord = coord  # Tọa độ chuột
        self.control_group = []  # Sẽ được gán bởi state
        self.chosen_objects = []


class GameObject:
    """Đại diện cho mọi thứ: Hero, Minion, Skill Object..."""

    def __init__(
        self,
        team: int,
        bounding_box: Tuple = ((0, 0), (0, 0), (0, 0), (0, 0)),
        attributes: Dict = None,
        client_id: str = None,
    ):
        self.id = str(uuid.uuid4())
        self.team = team
        self.client_id = client_id
        self.bounding_box = bounding_box
        self.coord = [0.0, 0.0]
        self.velocity = [0.0, 0.0]

        # Hệ thống Tầm nhìn (Fog of War)
        self.orientation = 0.0  # Góc quay hiện tại (Radian)
        self.vision_range = 450.0  # Khoảng cách nhìn tối đa
        import math

        self.vision_angle = math.pi * 0.6  # Góc nhìn hình nón (Khoảng 108 độ)

        # Hệ thống RPG (KDA, Vàng, Level, Kho đồ)
        self.level = 1
        self.exp = 0
        self.gold = 0
        self.kills = 0
        self.deaths = 0
        self.assists = 0
        self.inventory = []  # Danh sách chứa dict của các Item

        # Thuộc tính hiển thị nâng cao (Animation Speed, Orbs)
        self.current_anim = "Idle"
        self.anim_speed = 1.0
        self.attachments = []  # Pattern chuẩn: List chứa dict [{'model_url': '...', 'scale': 1.0}]

        # Các thuộc tính linh động (HP, mana, damage, ...)
        if attributes:
            for key, value in attributes.items():
                setattr(self, key, value)

        # Callback logic
        self.callback_code = ""
        self.callback_func: Callable[[Event], None] = None
        self.is_deleted = False

    def update_position(self, delta_time: float = 0.01):
        """Hệ thống tự động cập nhật vị trí dựa trên vận tốc"""
        self.coord[0] += self.velocity[0] * delta_time
        self.coord[1] += self.velocity[1] * delta_time

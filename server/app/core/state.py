from typing import Any, Dict, List

from app.models.object import GameObject


class GameState:
    def __init__(self):
        self.objects: Dict[str, GameObject] = {}
        self.current_time: float = 0.0
        # Hàng đợi lưu trữ input từ clients: { client_id: [inputs...] }
        self.client_inputs: Dict[str, List[Dict[str, Any]]] = {}

    def add_input(self, client_id: str, input_data: Dict[str, Any]):
        if client_id not in self.client_inputs:
            self.client_inputs[client_id] = []
        self.client_inputs[client_id].append(input_data)

    def get_and_clear_inputs(self, client_id: str) -> List[Dict[str, Any]]:
        inputs = self.client_inputs.get(client_id, [])
        self.client_inputs[client_id] = []
        return inputs

    def add_object(self, obj: GameObject) -> str:
        self.objects[obj.id] = obj
        return obj.id

    def remove_object(self, obj_id: str):
        if obj_id in self.objects:
            self.objects[obj_id].is_deleted = True

    def get_object(self, obj_id: str) -> GameObject:
        return self.objects.get(obj_id)

    def clean_up_deleted(self):
        """Xóa hẳn các object được đánh dấu xóa ở tick trước"""
        keys_to_delete = [k for k, v in self.objects.items() if v.is_deleted]
        for k in keys_to_delete:
            del self.objects[k]


# Biến toàn cục (Singleton) cho trận đấu hiện tại
# (Trong thực tế nếu có nhiều phòng (rooms), biến này sẽ là 1 dict các GameState)
global_game_state = GameState()

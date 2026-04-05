import uuid
from typing import Any, Dict, List

from app.core.maps import load_map
from app.models.object import GameObject


class GameState:
    def __init__(self):
        self.objects: Dict[str, GameObject] = {}
        self.current_time: float = 0.0
        self.is_night: bool = False  # Cờ hiệu chu kỳ ngày đêm
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
        keys_to_delete = [k for k, v in self.objects.items() if v.is_deleted]
        for k in keys_to_delete:
            del self.objects[k]


class RoomManager:
    def __init__(self):
        self.rooms: Dict[str, GameState] = {}  # Lưu trữ các phòng đang chơi
        # Hàng đợi: { map_type: [client_id_1, client_id_2, ...] }
        self.queue: Dict[str, List[str]] = {"aram": [], "3lane": [], "random": []}
        self.client_to_room: Dict[str, str] = {}  # Map client đang ở room nào
        self.PLAYERS_PER_MATCH = 2  # Setup 2 người 1 phòng để test cho lẹ

    def create_room(self, map_type: str, players: List[str]) -> str:
        room_id = str(uuid.uuid4())
        new_state = GameState()
        load_map(new_state, map_type)  # Nạp bản đồ
        self.rooms[room_id] = new_state

        for p in players:
            self.client_to_room[p] = room_id

        return room_id

    def remove_client(self, client_id: str):
        # Rời hàng đợi
        for q in self.queue.values():
            # queue giờ chứa dict nên phải lọc
            for p in list(q):
                if p["client_id"] == client_id:
                    q.remove(p)
        if client_id in self.client_to_room:
            del self.client_to_room[client_id]

    def process_matchmaking(self, map_type: str) -> list:
        """Thuật toán Smart Matchmaking (Breadth-First): Tìm trận đông nhất có thể"""
        from app.core.maps import MAP_REGISTRY

        matches = []
        queue = self.queue[map_type]

        # Xác định map này đòi bao nhiêu team (từ list structure)
        config = MAP_REGISTRY.get(map_type, MAP_REGISTRY["3lane"])[0]
        num_teams = len(config.get("structure", [[], []]))
        if num_teams == 0:
            num_teams = 2

        # Tìm số K (người/team) lớn nhất có thể (từ 15 lùi về 1)
        for k in range(15, 0, -1):
            # Tìm những người chấp nhận team có K người
            valid_players = [
                p for p in queue if p.get("min_p", 5) <= k <= p.get("max_p", 5)
            ]

            # Cần num_teams, mỗi team K người -> tổng cộng cần num_teams * k người
            total_needed = num_teams * k
            while len(valid_players) >= total_needed:
                # Bốc đủ số người vào 1 trận
                match_players = valid_players[:total_needed]
                matches.append(match_players)

                # Xóa họ khỏi hàng đợi
                for p in match_players:
                    queue.remove(p)
                    valid_players.remove(p)

        return matches


room_manager = RoomManager()
# Đã xóa global_game_state để triệt để fix circular import và chuẩn bị cho multi-room

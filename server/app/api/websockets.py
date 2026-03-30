import json
from typing import Dict

from app.core.state import global_game_state
from fastapi import APIRouter, WebSocket, WebSocketDisconnect

router = APIRouter()


class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[str, WebSocket] = {}

    async def connect(self, websocket: WebSocket, client_id: str):
        await websocket.accept()
        self.active_connections[client_id] = websocket
        print(f"Client {client_id} connected.")

    def disconnect(self, client_id: str):
        if client_id in self.active_connections:
            del self.active_connections[client_id]
            print(f"Client {client_id} disconnected.")

    async def broadcast_state(self):
        """Đóng gói toàn bộ object thành JSON và gửi cho Clients"""
        if not self.active_connections:
            return

        state_data = {
            "time": global_game_state.current_time,
            "objects": {
                obj_id: {
                    "team": obj.team,
                    "coord": obj.coord,
                    # Lấy animation hiện tại, mặc định là idle
                    "anim": getattr(obj, "current_anim", "idle"),
                    "hp": getattr(obj, "hp", 100),
                    "max_hp": getattr(obj, "max_hp", 100),
                    "size": getattr(obj, "size", [40, 40]),
                    "color": getattr(obj, "color", "WHITE"),
                    "vfx_type": getattr(obj, "vfx_type", "none"),
                    "vfx_url": getattr(obj, "vfx_url", ""),
                }
                for obj_id, obj in global_game_state.objects.items()
                if not obj.is_deleted
            },
        }

        message = json.dumps(state_data)
        for connection in list(self.active_connections.values()):
            try:
                await connection.send_text(message)
            except Exception:
                pass


manager = ConnectionManager()


@router.websocket("/ws/{client_id}")
async def websocket_endpoint(websocket: WebSocket, client_id: str):
    await manager.connect(websocket, client_id)
    try:
        while True:
            # Nhận input từ Godot Client (ví dụ: {"type": "Q", "coord": [150, 200]})
            data = await websocket.receive_text()
            input_data = json.loads(data)

            # Lưu input_data vào Queue để Game Loop đọc (vd: {"type": "Q", "coord": [150, 200]})
            global_game_state.add_input(client_id, input_data)

    except WebSocketDisconnect:
        manager.disconnect(client_id)

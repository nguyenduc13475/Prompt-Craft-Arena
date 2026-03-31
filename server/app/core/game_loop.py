import asyncio
import time

# Import manager sau khi đã tạo ở websockets (sẽ xử lý vòng lặp import bên dưới)
from app.api.websockets import manager
from app.core.state import room_manager
from app.models.object import Event


async def run_game_loop():
    """
    Vòng lặp cốt lõi của Server. Chạy 30 lần mỗi giây (Tickrate 30).
    """
    tick_rate = 0.033  # ~30 FPS

    while True:
        start_time = time.time()

        # Quét qua TẤT CẢ các phòng (rooms) đang active
        for room_id, state in list(room_manager.rooms.items()):
            state.current_time += tick_rate

            for obj_id, obj in list(state.objects.items()):
                if obj.is_deleted:
                    continue

                # --- XỬ LÝ NỘI TẠI ITEM (Ví dụ giảm tốc độ chạy) ---
                speed_mult = 1.0
                if hasattr(obj, "inventory"):
                    for item in obj.inventory:
                        if item.get("type") == "passive" and "stats" in item:
                            speed_mult *= item["stats"].get("speed_mult", 1.0)

                # Cập nhật vị trí bị ảnh hưởng bởi hòm đồ
                obj.coord[0] += obj.velocity[0] * tick_rate * speed_mult
                obj.coord[1] += obj.velocity[1] * tick_rate * speed_mult

                if obj.callback_func:
                    client_inputs = []
                    if getattr(obj, "client_id", None):
                        client_inputs = state.get_and_clear_inputs(obj.client_id)

                    if not client_inputs:
                        client_inputs = [{"type": None, "coord": obj.coord}]

                    for input_data in client_inputs:
                        event = Event(
                            current_time=state.current_time,
                            self_obj=obj,
                            event_type=input_data.get("type"),
                            coord=input_data.get("coord", obj.coord),
                        )
                        # Hack tạm thời: gán state hiện tại cho hàm builtins
                        # (Giải pháp lý tưởng là truyền state vào Event, nhưng để "breadth-first" nhanh gọn ta tạm dùng global)
                        import app.sandbox.builtins as builtins

                        builtins.global_game_state = state

                        try:
                            obj.callback_func(event)
                        except Exception as e:
                            print(
                                f"[Sandbox Error] Room {room_id} - Object {obj_id}: {e}"
                            )

            # Kiểm tra máu & Bounds
            for obj_id, obj in list(state.objects.items()):
                if hasattr(obj, "hp") and obj.hp <= 0:
                    # 1. RỚT ITEM XUỐNG ĐẤT
                    if hasattr(obj, "inventory"):
                        for item in obj.inventory:
                            if item.get("drop", False):
                                import app.sandbox.builtins as builtins

                                # Tạo GameObject Item trên sàn
                                builtins.safe_create_object(
                                    {
                                        "team": 4,
                                        "coord": list(obj.coord),
                                        "size": [20, 20],
                                        "color": "GREEN",
                                        "item_data": item,
                                        "name_display": item["name"],
                                    },
                                    builtins.compile_callback(
                                        "def execute(event):\n    looters = get_objects(event.self.coord, 20.0)\n    for l in looters:\n        if getattr(l, 'client_id', None):\n            l.inventory.append(event.self.item_data)\n            delete_object(event.self.id)\n            break"
                                    ),
                                )
                        # Xóa đồ đã rớt khỏi túi người chết
                        obj.inventory = [
                            i for i in obj.inventory if not i.get("drop", False)
                        ]

                    # 2. CHẾT & RÊSPAWN (Tướng) / XÓA (Quái)
                    if getattr(obj, "client_id", None):
                        obj.deaths += 1
                        obj.hp = getattr(obj, "max_hp", 100)
                        obj.coord = [150.0 if obj.team == 1 else 850.0, 500.0]
                        obj.velocity = [0.0, 0.0]
                    else:
                        obj.is_deleted = True

                        # 3. FARM QUÁI LẤY TIỀN/EXP (Thưởng cho Tướng gần nhất)
                        import math

                        nearest_hero = None
                        min_dist = 300.0
                        for h in state.objects.values():
                            if getattr(h, "client_id", None) and h.team != obj.team:
                                dist = math.hypot(
                                    h.coord[0] - obj.coord[0], h.coord[1] - obj.coord[1]
                                )
                                if dist < min_dist:
                                    min_dist = dist
                                    nearest_hero = h
                        if nearest_hero:
                            nearest_hero.gold += getattr(obj, "bounty", 10)
                            nearest_hero.exp += getattr(obj, "exp_reward", 10)
                            # Level up
                            if nearest_hero.exp >= nearest_hero.level * 100:
                                nearest_hero.level += 1
                                nearest_hero.exp = 0
                                nearest_hero.max_hp = (
                                    getattr(nearest_hero, "max_hp", 100) + 150
                                )
                                nearest_hero.hp = nearest_hero.max_hp

                if obj.coord[0] < 20:
                    obj.coord[0] = 20
                if obj.coord[0] > 980:
                    obj.coord[0] = 980
                if obj.coord[1] < 20:
                    obj.coord[1] = 20
                if obj.coord[1] > 980:
                    obj.coord[1] = 980

            state.clean_up_deleted()

            # --- KIỂM TRA ĐIỀU KIỆN KẾT THÚC GAME ---
            game_over = False
            winner_team = 0
            for obj_id, obj in list(state.objects.items()):
                if getattr(obj, "is_nexus", False) and obj.hp <= 0:
                    game_over = True
                    # Nếu nhà chính team 1 nổ, team 2 thắng và ngược lại (logic 2 team)
                    winner_team = 2 if obj.team == 1 else 1
                    break

            if game_over:
                print(f"[Game Loop] Room {room_id} ket thuc. Team {winner_team} win!")
                # Thu thập thống kê người chơi
                stats = []
                for p_obj in state.objects.values():
                    if getattr(p_obj, "client_id", None):
                        stats.append(
                            {
                                "client_id": p_obj.client_id,
                                "name": getattr(p_obj, "name_display", "Unknown"),
                                "team": p_obj.team,
                                "k": p_obj.kills,
                                "d": p_obj.deaths,
                                "a": p_obj.assists,
                                "gold": p_obj.gold,
                            }
                        )

                # Gửi gói tin Game Over
                import json

                game_over_msg = json.dumps(
                    {"type": "game_over", "winner_team": winner_team, "stats": stats}
                )

                # Gửi cho tất cả client trong phòng
                for c_id, r_id in list(room_manager.client_to_room.items()):
                    if r_id == room_id and c_id in manager.active_connections:
                        asyncio.create_task(
                            manager.active_connections[c_id].send_text(game_over_msg)
                        )
                        # Xóa client khỏi room logic
                        del room_manager.client_to_room[c_id]

                # Xóa phòng
                del room_manager.rooms[room_id]
                continue  # Bỏ qua update state phòng này

        await manager.broadcast_room_state()

        elapsed = time.time() - start_time
        sleep_time = max(0.0, tick_rate - elapsed)
        await asyncio.sleep(sleep_time)

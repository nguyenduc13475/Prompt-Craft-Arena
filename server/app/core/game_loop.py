import asyncio
import time

# Import manager sau khi đã tạo ở websockets (sẽ xử lý vòng lặp import bên dưới)
from app.api.websockets import manager
from app.core.state import global_game_state
from app.models.object import Event


async def run_game_loop():
    """
    Vòng lặp cốt lõi của Server. Chạy 30 lần mỗi giây (Tickrate 30).
    """
    tick_rate = 0.033  # ~30 FPS

    while True:
        start_time = time.time()
        global_game_state.current_time += tick_rate

        # 1. Cập nhật vị trí & Thực thi Callback của toàn bộ Object
        for obj_id, obj in list(global_game_state.objects.items()):
            if obj.is_deleted:
                continue

            # Cập nhật vị trí tĩnh (nếu object có velocity)
            obj.update_position(tick_rate)

            # Thực thi logic từ AI sinh ra
            if obj.callback_func:
                # Lấy input từ Client nếu object này là Hero do player điều khiển
                client_inputs = []
                if getattr(obj, "client_id", None):
                    client_inputs = global_game_state.get_and_clear_inputs(
                        obj.client_id
                    )

                # Nếu không có input nào từ player, vẫn gọi callback với event_type = None
                # để các logic nội tại (như tính toán hồi chiêu, tự động di chuyển) tiếp tục chạy
                if not client_inputs:
                    client_inputs = [{"type": None, "coord": obj.coord}]

                for input_data in client_inputs:
                    event = Event(
                        current_time=global_game_state.current_time,
                        self_obj=obj,
                        event_type=input_data.get("type"),
                        coord=input_data.get("coord", obj.coord),
                    )
                    try:
                        obj.callback_func(event)
                    except Exception as e:
                        print(f"[Sandbox Error] Object {obj_id}: {e}")
                        # Có thể tạm comment dòng is_deleted dưới đây khi debug prompt để không bị mất tướng
                        # obj.is_deleted = True

        # Kiểm tra máu (hp) của tất cả object, nếu <= 0 thì xử lý chết/respawn
        for obj_id, obj in list(global_game_state.objects.items()):
            if hasattr(obj, "hp") and obj.hp <= 0:
                if getattr(
                    obj, "client_id", None
                ):  # Là Hero của người chơi -> Hồi sinh
                    obj.hp = obj.max_hp
                    obj.coord = [100.0, 500.0]  # Respawn ở Base Team 1
                    obj.velocity = [0.0, 0.0]  # Xóa đà di chuyển
                else:
                    obj.is_deleted = True  # Quái hoặc đạn thì xóa luôn

            # Giới hạn bản đồ (Map Bounds: X,Y từ 0 tới 1000)
            if obj.coord[0] < 20:
                obj.coord[0] = 20
            if obj.coord[0] > 980:
                obj.coord[0] = 980
            if obj.coord[1] < 20:
                obj.coord[1] = 20
            if obj.coord[1] > 980:
                obj.coord[1] = 980

        # 2. Dọn dẹp Garbage (các object bị delete_object)
        global_game_state.clean_up_deleted()

        # 3. Broadcast trạng thái mới nhất cho tất cả Client
        await manager.broadcast_state()

        # 4. Ngủ phần thời gian còn thừa để giữ ổn định Tickrate
        elapsed = time.time() - start_time
        sleep_time = max(0.0, tick_rate - elapsed)
        await asyncio.sleep(sleep_time)

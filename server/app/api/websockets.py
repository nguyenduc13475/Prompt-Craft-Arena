import asyncio
import copy
import hashlib
import json
import os
import random
from typing import Dict

from app.core.maps import (
    MAP_REGISTRY,  # Import thêm cái này để lấy config bắn cho client
)
from app.core.state import room_manager

# Cần thêm DB để load Hero khi vào trận
from app.models.database import AsyncSessionLocal
from app.models.object import GameObject
from app.models.user_hero import HeroSkillSet
from app.sandbox.compiler import compile_callback
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from sqlalchemy.future import select

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
            room_manager.remove_client(client_id)
            print(f"Client {client_id} disconnected.")

    def _check_vision(self, viewer, target) -> bool:
        """Kiểm tra target có nằm trong tầm nhìn của viewer không"""
        if viewer.team == target.team:
            return True  # Shared vision với đồng minh
        if getattr(target, "is_shop", False) or getattr(target, "is_nexus", False):
            return True  # Cửa hàng và Nhà chính luôn hiển thị

        # LOGIC BỤI CỎ (BUSH)
        target_bush = getattr(target, "in_bush_id", "")
        viewer_bush = getattr(viewer, "in_bush_id", "")
        if target_bush != "" and target_bush != viewer_bush:
            return False  # Target ở trong bụi, mình ở ngoài hoặc ở bụi khác -> Mù

        import math

        dx = target.coord[0] - viewer.coord[0]
        dy = target.coord[1] - viewer.coord[1]
        dist = math.hypot(dx, dy)

        if dist > viewer.vision_range:
            return False

        # Tính góc giữa viewer và target
        angle_to_target = math.atan2(dy, dx)
        # Chuẩn hóa độ lệch góc về khoảng [-pi, pi]
        diff = (angle_to_target - viewer.orientation + math.pi) % (
            2 * math.pi
        ) - math.pi

        # Nằm trong hình nón
        if abs(diff) <= getattr(viewer, "vision_angle", math.pi):
            return True
        return False

    async def broadcast_room_state(self):
        """Broadcast trạng thái ĐÃ LỌC FOG OF WAR (Tầm nhìn chia sẻ) cho từng client"""
        for room_id, state in room_manager.rooms.items():
            # Bước chuẩn bị: Gom nhóm object theo Team để tính Shared Vision nhanh hơn
            team_vision_providers = {1: [], 2: [], 3: []}
            for obj in state.objects.values():
                if not obj.is_deleted and getattr(obj, "hp", None) is not None:
                    # Chỉ các object có máu (Lính, Tướng, Trụ) mới cung cấp tầm nhìn
                    team_vision_providers[obj.team].append(obj)

            # Quét từng client trong phòng này
            for client_id, c_room_id in room_manager.client_to_room.items():
                if c_room_id == room_id and client_id in self.active_connections:
                    # 1. Tìm Hero của Client này để lấy Team (Nếu đã chết, vẫn được xem map của team)
                    my_team = None
                    for o in state.objects.values():
                        if getattr(o, "client_id", None) == client_id:
                            my_team = o.team
                            break

                    if my_team is None:
                        my_team = 1  # Fallback nếu đang load

                    my_allies = team_vision_providers.get(my_team, [])

                    # 2. Lọc danh sách object mà Liên minh của Client này có thể thấy
                    visible_objects = {}
                    for obj_id, obj in state.objects.items():
                        if obj.is_deleted:
                            continue

                        # Môi trường tĩnh (Tường, Cỏ, Sông, Cửa Hàng, Nhà Chính, Mỏ quái) luôn thấy
                        is_static_env = (
                            getattr(obj, "indestructible", False)
                            or getattr(obj, "is_shop", False)
                            or getattr(obj, "is_nexus", False)
                            or getattr(obj, "type", "")
                            in ["wall", "bush", "river", "tower", "spawner"]
                        )

                        # Logic: Thấy nếu là môi trường tĩnh, HOẶC cùng team, HOẶC BẤT KỲ đồng minh nào nhìn thấy nó
                        is_visible = is_static_env or (obj.team == my_team)

                        if not is_visible:
                            # Quét qua toàn bộ đồng minh xem có ai thấy mục tiêu này không
                            for ally in my_allies:
                                if self._check_vision(ally, obj):
                                    is_visible = True
                                    break  # Chỉ cần 1 người thấy là cả team thấy

                        if is_visible:
                            visible_objects[obj_id] = {
                                "team": obj.team,
                                "coord": obj.coord,
                                "orientation": getattr(obj, "orientation", 0.0),
                                "anim": getattr(obj, "current_anim", "idle"),
                                "hp": getattr(obj, "hp", 100),
                                "max_hp": getattr(obj, "max_hp", 100),
                                "size": getattr(obj, "size", [40, 40]),
                                "scale": getattr(obj, "scale", 1.0),
                                "height_offset": getattr(obj, "height_offset", 0.0),
                                "color": getattr(obj, "color", "WHITE"),
                                "vfx_type": getattr(obj, "vfx_type", "none"),
                                "vfx_url": getattr(obj, "vfx_url", ""),
                                "model_url": getattr(obj, "model_url", ""),
                                "name_display": getattr(obj, "name_display", "Unknown"),
                                "client_id": getattr(obj, "client_id", ""),
                                "anim_speed": getattr(obj, "anim_speed", 1.0),
                                "attachments": getattr(obj, "attachments", []),
                                "level": getattr(obj, "level", 1),
                                "gold": getattr(obj, "gold", 0),
                                "kills": getattr(obj, "kills", 0),
                                "deaths": getattr(obj, "deaths", 0),
                                "assists": getattr(obj, "assists", 0),
                                "inventory": getattr(obj, "inventory", []),
                                "is_shop": getattr(obj, "is_shop", False),
                                "stock": getattr(obj, "stock", []),
                                "indestructible": getattr(obj, "indestructible", False),
                                "river_points": getattr(obj, "river_points", []),
                            }
                    # 3. Gửi state đã đóng gói riêng cho Client này
                    state_data = {
                        "time": state.current_time,
                        "is_night": state.is_night,
                        "objects": visible_objects,
                    }
                    try:
                        await self.active_connections[client_id].send_text(
                            json.dumps(state_data)
                        )
                    except Exception:
                        pass


async def load_hero_and_spawn(
    room_id: str,
    client_id: str,
    hero_id: str,
    team: int,
    y_offset: float = 0,
    model_url: str = "",
):
    """Hàm bổ trợ để load dữ liệu tướng từ DB và nạp vào GameState"""
    print(
        f"[GameServer] Dang nap Hero {hero_id} cho Client {client_id} vao phong {room_id}..."
    )

    if room_id not in room_manager.rooms:
        return

    state = room_manager.rooms[room_id]

    async with AsyncSessionLocal() as db:
        result = await db.execute(
            select(HeroSkillSet).where(HeroSkillSet.id == hero_id)
        )
        hero_data = result.scalars().first()

        if not hero_data:
            print(
                f"[Cảnh Báo] Khong tim thay Hero ID {hero_id}. Đang tự động nạp tướng mặc định (Huan Rose)..."
            )
            result = await db.execute(
                select(HeroSkillSet).where(HeroSkillSet.name == "Huan Rose")
            )
            hero_data = result.scalars().first()
            if not hero_data:
                print(
                    "[Lỗi Nghiêm Trọng] Không tìm thấy cả tướng mặc định trong DB. Hủy spawn!"
                )
                return

        # 1. Xác định Code Logic sẽ chạy (Base code hay Skin code)
        active_code = hero_data.callback_code
        if model_url and model_url != getattr(hero_data, "model_url", ""):
            # Tìm code đã được thuật toán map animation cho skin này
            for s in hero_data.skins:
                if isinstance(s, dict) and s.get("url") == model_url:
                    active_code = s.get("code", active_code)
                    break

        # Biên dịch code trong Sandbox
        callback_func = compile_callback(active_code)

        attributes = dict(hero_data.attributes)  # Copy dict
        if hero_data.vfx_url:
            attributes["ugc_vfx_url"] = hero_data.vfx_url

        # Ưu tiên model_url được client chọn từ Sảnh, nếu không có thì lấy mặc định của Hero
        attributes["model_url"] = (
            model_url if model_url else getattr(hero_data, "model_url", "")
        )

        # 2. Tạo GameObject
        hero_obj = GameObject(team=team, attributes=attributes, client_id=client_id)
        hero_obj.callback_func = callback_func

        # Vị trí spawn chuẩn: Team 1 (Góc Trái Dưới), Team 2 (Góc Phải Trên), Team 3+ (Xoay vòng)
        if team == 1:
            hero_obj.coord = [100.0 + y_offset, 900.0 - y_offset]
        elif team == 2:
            hero_obj.coord = [900.0 - y_offset, 100.0 + y_offset]
        else:
            hero_obj.coord = [500.0 + y_offset, 500.0 + y_offset]
        hero_obj.name_display = hero_data.name  # Thêm thuộc tính hiển thị tên

        # 3. Nạp vào state phòng
        state.add_object(hero_obj)
        print(f"[GameServer] Da spawn Hero '{hero_data.name}' thanh cong.")


manager = ConnectionManager()


async def handle_found_matches(matches_found, map_type):
    """Hàm tách rời: Xử lý gom nhóm, tạo room và gửi tín hiệu vào game"""
    for match in matches_found:
        actual_map = (
            map_type if map_type != "random" else random.choice(["aram", "3lane"])
        )
        matched_client_ids = [p["client_id"] for p in match]
        room_id = room_manager.create_room(actual_map, matched_client_ids)

        # Đọc xem map yêu cầu mấy team từ Registry
        map_config = MAP_REGISTRY[actual_map][0]
        num_teams = len(map_config.get("structure", [[], []]))
        if num_teams == 0:
            num_teams = 2

        team_size = len(match) // num_teams

        print(
            f"[Matchmaking] Tạo trận thành công Room {room_id} với {len(match)} người (Chia {num_teams} team, mỗi team {team_size} người)"
        )

        # Lấy cái dict config (Bỏ qua callback) để gửi về cho Client
        map_visual_config = {}
        if actual_map in MAP_REGISTRY:
            map_visual_config = copy.deepcopy(MAP_REGISTRY[actual_map][0])

            # TÍNH HASH TỰ ĐỘNG CHO CÁC TEXTURE (HYDRATION)
            for tex_key in [
                "ground_model",
                "height_map",
                "ground_texture",
                "background",
            ]:
                item_path = map_visual_config.get(tex_key)

                # Hàm hỗ trợ băm file
                def hash_file(path_str):
                    phys_path = (
                        f"app/static/{path_str}"
                        if not path_str.startswith("app/")
                        else path_str
                    )
                    if os.path.exists(phys_path):
                        with open(phys_path, "rb") as f:
                            return hashlib.md5(f.read()).hexdigest()
                    return ""

                if item_path:
                    if isinstance(item_path, str):
                        map_visual_config[f"hash_{tex_key}"] = hash_file(item_path)
                    elif isinstance(item_path, list):
                        hash_list = []
                        for sub_path in item_path:
                            if isinstance(sub_path, str):
                                hash_list.append(hash_file(sub_path))
                        map_visual_config[f"hash_{tex_key}"] = hash_list

        match_msg = json.dumps(
            {
                "type": "match_found",
                "room_id": room_id,
                "map_type": actual_map,
                "map_config": map_visual_config,
            }
        )

        for index, p in enumerate(match):
            if p["client_id"] in manager.active_connections:
                await manager.active_connections[p["client_id"]].send_text(match_msg)

            # Chia team linh hoạt (1, 2, 3...)
            team = (index // team_size) + 1
            if team > num_teams:
                team = num_teams  # Phòng hờ làm tròn

            spawn_y_offset = (index % team_size) * 60 - ((team_size - 1) * 30)

            asyncio.create_task(
                load_hero_and_spawn(
                    room_id,
                    p["client_id"],
                    p["hero_id"],
                    team,
                    spawn_y_offset,
                    p.get("model_url", ""),
                )
            )


async def wait_and_fill_bots(client_id, map_type, hero_id, min_p, max_p):
    """Tiến trình ngầm chờ 1s (Dev Mode), nếu vẫn chưa có trận thật thì tự động sinh Bot"""
    await asyncio.sleep(1)

    # Kểm tra xem người chơi này còn đang chầu chực trong hàng đợi không
    is_still_waiting = any(
        p["client_id"] == client_id for p in room_manager.queue[map_type]
    )
    if not is_still_waiting:
        return  # Đã tìm được trận trong 30s đó hoặc người dùng tự hủy queue

    print(f"[Bot Filler] Đã qua 30s, tiến hành thêm Bot cho người chơi {client_id}...")
    required_players = min_p * 2
    current_in_queue = len(room_manager.queue[map_type])

    if current_in_queue < required_players:
        for i in range(required_players - current_in_queue):
            bot_id = f"bot_{random.randint(1000, 9999)}_{i}"
            room_manager.queue[map_type].append(
                {
                    "client_id": bot_id,
                    "hero_id": hero_id,
                    "min_p": min_p,
                    "max_p": max_p,
                }
            )

    # Gọi lại hàm ghép trận lần nữa (chắc chắn sẽ thành công vì Bot đã bù đủ số)
    matches_found = room_manager.process_matchmaking(map_type)
    if matches_found:
        await handle_found_matches(matches_found, map_type)


@router.websocket("/ws/{client_id}")
async def websocket_endpoint(websocket: WebSocket, client_id: str):
    await manager.connect(websocket, client_id)
    try:
        while True:
            data = await websocket.receive_text()
            input_data = json.loads(data)
            msg_type = input_data.get("type")

            # --- XỬ LÝ CHAT ---
            if msg_type == "chat":
                chat_msg = input_data.get("message", "")
                sender_name = input_data.get("sender", client_id)
                channel = input_data.get("channel", "global")  # global hoặc room

                payload = json.dumps(
                    {
                        "type": "chat_message",
                        "sender": sender_name,
                        "message": chat_msg,
                        "channel": channel,
                    }
                )

                if channel == "room":
                    room_id = room_manager.client_to_room.get(client_id)
                    if room_id:
                        for c_id, r_id in room_manager.client_to_room.items():
                            if r_id == room_id and c_id in manager.active_connections:
                                await manager.active_connections[c_id].send_text(
                                    payload
                                )
                else:  # Global chat (Sảnh)
                    for connection in manager.active_connections.values():
                        await connection.send_text(payload)
                continue

            # --- THAY ĐỔI LOGIC JOIN QUEUE (VỚI DELAY 30S) ---
            elif msg_type == "join_queue":
                map_type = input_data.get("map_type", "random")
                hero_id = input_data.get("hero_id")
                min_p = input_data.get("min_p", 1)
                max_p = input_data.get("max_p", 5)

                if not hero_id:
                    continue

                player_entry = {
                    "client_id": client_id,
                    "hero_id": hero_id,
                    "model_url": input_data.get("model_url", ""),
                    "min_p": min_p,
                    "max_p": max_p,
                }

                # Cập nhật hoặc Thêm người chơi vào hàng đợi
                is_in_queue = False
                for p in room_manager.queue[map_type]:
                    if p["client_id"] == client_id:
                        p.update(player_entry)
                        is_in_queue = True
                        break
                if not is_in_queue:
                    room_manager.queue[map_type].append(player_entry)

                print(
                    f"Player {client_id} (Min: {min_p}, Max: {max_p}) đang chờ map {map_type}. Queue size: {len(room_manager.queue[map_type])}"
                )

                # Cố gắng ghép trận liền xem có ai khác đang đợi cùng không
                matches_found = room_manager.process_matchmaking(map_type)

                if matches_found:
                    # Nếu may mắn có đủ người thật, đánh luôn!
                    await handle_found_matches(matches_found, map_type)
                else:
                    # Nếu không đủ người, tung task đếm ngược 30 giây chạy ngầm
                    asyncio.create_task(
                        wait_and_fill_bots(client_id, map_type, hero_id, min_p, max_p)
                    )

            # Xử lý input game & Lệnh Cửa hàng
            else:
                room_id = room_manager.client_to_room.get(client_id)
                if room_id and room_id in room_manager.rooms:
                    state = room_manager.rooms[room_id]

                    # Tìm Hero của client hiện tại
                    my_hero = next(
                        (
                            o
                            for o in state.objects.values()
                            if getattr(o, "client_id", None) == client_id
                        ),
                        None,
                    )

                    if msg_type == "buy_item" and my_hero:
                        shop = state.get_object(input_data.get("shop_id"))
                        item_id = input_data.get("item_id")
                        if shop and getattr(shop, "is_shop", False):
                            for idx, item in enumerate(shop.stock):
                                if (
                                    item["id"] == item_id
                                    and my_hero.gold >= item["price"]
                                ):
                                    my_hero.gold -= item["price"]
                                    my_hero.inventory.append(item.copy())
                                    shop.stock.pop(idx)  # Xóa khỏi quầy (chỉ có 1 cái)
                                    break
                    elif msg_type == "sell_item" and my_hero:
                        shop = state.get_object(input_data.get("shop_id"))
                        item_idx = input_data.get("item_idx", -1)
                        if (
                            shop
                            and getattr(shop, "is_shop", False)
                            and 0 <= item_idx < len(my_hero.inventory)
                        ):
                            item = my_hero.inventory.pop(item_idx)
                            my_hero.gold += item["price"] // 2
                            item["price"] = item["price"] // 2  # Bán lại giá rẻ
                            shop.stock.append(item)
                    elif msg_type == "use_item" and my_hero:
                        item_idx = input_data.get("item_idx", -1)
                        if 0 <= item_idx < len(my_hero.inventory):
                            item = my_hero.inventory[item_idx]
                            if item["type"] == "consumable":
                                my_hero.inventory.pop(item_idx)
                                if "heal" in item["stats"]:
                                    my_hero.hp = min(
                                        my_hero.hp + item["stats"]["heal"],
                                        getattr(my_hero, "max_hp", 100),
                                    )
                    else:
                        state.add_input(client_id, input_data)

    except WebSocketDisconnect:
        manager.disconnect(client_id)

import asyncio
import os
from contextlib import asynccontextmanager

import uvicorn
from app.api import routes, uploads, websockets
from app.core.game_loop import run_game_loop
from app.core.state import global_game_state
from app.models.object import GameObject
from app.sandbox.compiler import compile_callback
from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

# Load environment variables from the .env file
load_dotenv()


@asynccontextmanager
async def lifespan(app: FastAPI):
    # 1. Tạo Tower / Trụ địch (Máu trâu, đứng im)
    tower = GameObject(
        team=2,
        attributes={"hp": 2000, "max_hp": 2000, "size": [80, 80], "color": "DARK_RED"},
    )
    tower.coord = [900.0, 500.0]
    global_game_state.add_object(tower)

    # 2. Tạo Nhà lính (Spawner) tàng hình, sinh quái (Minion) mỗi 3 giây
    spawner_code = """
def execute(event):
    if not hasattr(event.self, 'last_spawn'):
        event.self.last_spawn = event.current_time
    if event.current_time > event.self.last_spawn + 3.0:
        event.self.last_spawn = event.current_time
        def minion_ai(e):
            # Quái di chuyển về phía Base phe người chơi [100, 500]
            dx = 100 - e.self.coord[0]
            dy = 500 - e.self.coord[1]
            dist = math.hypot(dx, dy)
            if dist > 50:
                angle = math.atan2(dy, dx)
                e.self.velocity = [math.cos(angle)*60, math.sin(angle)*60]
            else:
                e.self.velocity = [0.0, 0.0]
            
            # Gây sát thương nếu chạm đối phương
            if not hasattr(e.self, 'last_atk'): e.self.last_atk = 0
            if e.current_time > e.self.last_atk + 1.0:
                e.self.last_atk = e.current_time
                for obj in get_objects(e.self.coord, 40):
                    if obj.team == 1 and hasattr(obj, 'hp'):
                        obj.hp = obj.hp - 10
        create_object({'team': 2, 'hp': 50, 'max_hp': 50, 'coord': [900, 500], 'size': [25, 25], 'color': 'ORANGE'}, minion_ai)
"""
    spawner = GameObject(team=2, attributes={"size": [0, 0]})
    spawner.callback_code = spawner_code
    spawner.callback_func = compile_callback(spawner_code)
    global_game_state.add_object(spawner)

    # Khởi chạy Game Loop dưới dạng Background Task
    loop_task = asyncio.create_task(run_game_loop())
    yield
    loop_task.cancel()


app = FastAPI(title="PromptCraft-Arena API", version="0.1.0", lifespan=lifespan)

# Mount thư mục tĩnh để Godot có thể tải ảnh UGC về hiển thị
os.makedirs("app/static/uploads", exist_ok=True)
app.mount("/static", StaticFiles(directory="app/static"), name="static")


@app.get("/")
def read_root():
    return {"message": "Welcome to PromptCraft-Arena Game Server!"}


# Mount routers
app.include_router(websockets.router)
app.include_router(routes.router)
app.include_router(uploads.router)

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)

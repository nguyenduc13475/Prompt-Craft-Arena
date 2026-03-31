import asyncio
import os
from contextlib import asynccontextmanager

import app.models.user_hero  # BẮT BUỘC: Import để SQLAlchemy nhận diện các bảng trước khi create_all
import uvicorn
from app.api import (  # Import thêm router mới
    auth_routes,
    hero_routes,
    social_routes,
    uploads,
    websockets,
)
from app.core.game_loop import run_game_loop

# Import Base và engine để tạo bảng
from app.models.database import Base, engine
from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware  # Thêm CORS để Godot gọi API được
from fastapi.staticfiles import StaticFiles

# Load environment variables from the .env file
load_dotenv()


@asynccontextmanager
async def lifespan(app: FastAPI):
    # KHỞI TẠO DATABASE (Tạo bảng nếu chưa có) - Chỉ dùng cho Prototype
    print("[Server] Dang kiem tra va khoi tao Database...")
    async with engine.begin() as conn:
        # Cần import các model vào đây để SQLAlchemy biết mà tạo bảng
        await conn.run_sync(Base.metadata.create_all)
    print("[Server] Database da san sang.")

    # Khởi chạy Game Loop dưới dạng Background Task
    loop_task = asyncio.create_task(run_game_loop())
    yield
    loop_task.cancel()


app = FastAPI(title="PromptCraft-Arena API", version="0.1.0", lifespan=lifespan)

# CẤU HÌNH CORS (Cho phép Godot Client kết nối API)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Prototype cho phép tất, production cần giới hạn
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount thư mục tĩnh
os.makedirs("app/static/uploads", exist_ok=True)
app.mount("/static", StaticFiles(directory="app/static"), name="static")


@app.get("/")
def read_root():
    return {"message": "Welcome to PromptCraft-Arena Game Server!"}


# Mount routers
app.include_router(websockets.router)
app.include_router(uploads.router)
app.include_router(auth_routes.router, tags=["Auth"])  # Router đăng nhập
app.include_router(hero_routes.router, tags=["Heroes"])  # Router quản lý tướng
app.include_router(social_routes.router, tags=["Social"])  # Router Bạn bè/Bang hội

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)

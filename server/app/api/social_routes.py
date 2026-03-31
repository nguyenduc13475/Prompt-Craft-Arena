from fastapi import APIRouter
from pydantic import BaseModel

router = APIRouter()


class GenericResponse(BaseModel):
    message: str


@router.post("/api/social/friends/add")
async def add_friend(friend_username: str):
    # Khung xương: Thêm logic gọi DB sau
    return {"message": f"Đã gửi lời mời kết bạn tới {friend_username}"}


@router.post("/api/social/guild/create")
async def create_guild(guild_name: str):
    # Khung xương: Thêm logic gọi DB sau
    return {"message": f"Đã tạo bang hội {guild_name} thành công!"}

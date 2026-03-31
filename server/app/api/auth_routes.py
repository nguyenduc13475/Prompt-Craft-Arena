from app.models.database import get_db
from app.models.user_hero import User
from app.services import auth_service
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

router = APIRouter()


class AuthRequest(BaseModel):
    username: str
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str
    username: str
    user_id: int
    coins: int


@router.post("/api/auth/register")
async def register(req: AuthRequest, db: AsyncSession = Depends(get_db)):
    # Kiểm tra username tồn tại
    result = await db.execute(select(User).where(User.username == req.username))
    existing_user = result.scalars().first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Ten dang nhap da ton tai.")

    # Tạo user mới (PRODUCTION: PHẢI HASH PASSWORD Ở ĐÂY)
    new_user = User(username=req.username, hashed_password=req.password)
    db.add(new_user)
    await db.commit()
    await db.refresh(new_user)
    return {"message": "Dang ky thanh cong", "username": new_user.username}


@router.post("/api/auth/login", response_model=TokenResponse)
async def login(req: AuthRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.username == req.username))
    user = result.scalars().first()

    # Kiểm tra pass (PRODUCTION: DÙNG pwd_context.verify)
    if not user or user.hashed_password != req.password:
        raise HTTPException(status_code=400, detail="Sai ten dang nhap hoac mat khau.")

    # Tạo JWT Token
    access_token = auth_service.create_access_token(
        data={"sub": user.username, "user_id": user.id}
    )
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "username": user.username,
        "user_id": user.id,
        "coins": user.coins,
    }

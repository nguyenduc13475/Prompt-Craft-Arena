import uuid
from typing import List, Optional

from app.models.database import get_db
from app.models.user_hero import HeroSkillSet, User
from app.services import auth_service
from app.services.skill_balancer import generate_skill_logic
from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

router = APIRouter()


# --- Schemas ---
class HeroApiSaveRequest(BaseModel):
    name: str  # Tên đặt cho tướng
    prompt: str
    ugc_vfx_url: Optional[str] = ""
    model_url: Optional[str] = "/static/default_assets/mannequin.glb"


class HeroDto(BaseModel):  # Data Transfer Object để trả về client
    id: str
    name: str
    prompt: str
    color: str
    created_at: str
    vfx_url: Optional[str] = None
    model_url: Optional[str] = None


# --- Dependency để protect API bằng JWT ---
async def get_current_user_id(authorization: str = Header(...)):
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid auth header")
    token = authorization.split(" ")[1]
    payload = auth_service.decode_access_token(token)
    return payload.get("user_id")


# --- Routes ---


@router.post("/api/heroes", response_model=HeroDto)
async def create_and_save_hero(
    req: HeroApiSaveRequest,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_current_user_id),
):
    """Gọi Gemini gen skill, sau đó LƯU vào database"""
    print(f"[API] User {user_id} dang tao hero '{req.name}' tu prompt...")

    # 1. Gọi Gemini AI (Logic cũ dời sang đây)
    ai_result = generate_skill_logic(req.prompt)
    if not ai_result:
        raise HTTPException(status_code=500, detail="Loi khi goi Gemini AI.")

    attributes = ai_result.get("attributes", {})
    code_str = ai_result.get("code", "")

    # Valid sơ bộ code_str có hàm execute không (sandbox check sau)
    if "def execute(event):" not in code_str:
        raise HTTPException(status_code=500, detail="AI gen code loi cau truc.")

    # 2. Lưu vào DB
    hero_db = HeroSkillSet(
        id=str(uuid.uuid4()),
        name=req.name,
        prompt=req.prompt,
        owner_id=user_id,
        attributes=attributes,
        callback_code=code_str,
        vfx_url=req.ugc_vfx_url,
        model_url=req.model_url,
    )

    db.add(hero_db)
    await db.commit()
    await db.refresh(hero_db)

    return HeroDto(
        id=hero_db.id,
        name=hero_db.name,
        prompt=hero_db.prompt,
        color=attributes.get("color", "WHITE"),
        created_at=hero_db.created_at.strftime("%Y-%m-%d %H:%M"),
        vfx_url=hero_db.vfx_url,
        model_url=hero_db.model_url,
    )


@router.get("/api/heroes", response_model=List[HeroDto])
async def list_my_heroes(
    db: AsyncSession = Depends(get_db), user_id: int = Depends(get_current_user_id)
):
    """Lay danh sach hero da tao cua User dang nhap"""

    result = await db.execute(
        select(HeroSkillSet)
        .where(HeroSkillSet.owner_id == user_id)
        .order_by(HeroSkillSet.created_at.desc())
    )
    heroes = result.scalars().all()

    return [
        HeroDto(
            id=h.id,
            name=h.name,
            prompt=h.prompt,
            color=h.attributes.get("color", "WHITE"),
            created_at=h.created_at.strftime("%Y-%m-%d %H:%M"),
            vfx_url=h.vfx_url,
            model_url=h.model_url,
        )
        for h in heroes
    ]


@router.post("/api/heroes/generate_premium_model")
async def generate_premium_model(
    prompt: str,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_current_user_id),
):
    """API giả lập dùng Shap-E sinh model 3D (Trừ 50 xu)"""
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalars().first()

    if user.coins < 50:
        raise HTTPException(status_code=400, detail="Không đủ xu! Cần 50 xu.")

    # Trừ tiền
    user.coins -= 50
    await db.commit()

    # TODO: Gọi Shap-E thật ở đây. Tạm thời trả về model giả lập.
    import uuid

    fake_ai_model = f"/static/uploads/models/ai_gen_{uuid.uuid4().hex[:6]}.glb"

    return {
        "message": "Đã tạo Model AI thành công!",
        "model_url": fake_ai_model,
        "remaining_coins": user.coins,
    }

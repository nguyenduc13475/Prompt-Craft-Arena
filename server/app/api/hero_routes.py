import re
import uuid
from typing import List, Optional

import pygltflib
from app.models.database import get_db
from app.models.user_hero import HeroSkillSet, User
from app.services import auth_service
from app.services.skill_balancer import generate_skill_logic, map_animations_with_ai
from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel
from sqlalchemy import or_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm.attributes import flag_modified

router = APIRouter()


# --- Schemas ---
class HeroApiSaveRequest(BaseModel):
    name: str  # Tên đặt cho tướng
    prompt: str
    ugc_vfx_url: Optional[str] = ""
    model_url: Optional[str] = "/static/default_assets/mannequin.glb"


class HeroUpdateRequest(BaseModel):
    name: str
    model_url: str
    skins: list = []


class HeroDto(BaseModel):  # Data Transfer Object để trả về client
    id: str
    name: str
    prompt: str
    code: str = ""
    color: str
    created_at: str
    vfx_url: Optional[str] = None
    model_url: Optional[str] = None
    skins: list = []


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
    print(
        f"[API] User {user_id} dang tao hero '{req.name}' tu prompt:\n>>> {req.prompt}\n"
    )

    animations = []
    try:
        physical_path = f"app{req.model_url}"
        gltf = pygltflib.GLTF2().load(physical_path)
        if gltf.animations:
            animations = [a.name for a in gltf.animations]
    except Exception as e:
        print(f"[Canh bao] Khong the doc animation tu {req.model_url}: {e}")

    ai_result = generate_skill_logic(req.prompt, animations)
    if not ai_result:
        raise HTTPException(status_code=500, detail="Loi khi goi Gemini AI.")

    attributes = ai_result.get("attributes", {})
    code_str = ai_result.get("code", "")

    if "def execute(event):" not in code_str:
        raise HTTPException(status_code=500, detail="AI gen code loi cau truc.")

    hero_db = HeroSkillSet(
        id=str(uuid.uuid4()),
        name=req.name,
        prompt=req.prompt,
        owner_id=user_id,
        attributes=attributes,
        callback_code=code_str,
        vfx_url=req.ugc_vfx_url,
        model_url=req.model_url,
        skins=[],
    )

    db.add(hero_db)
    await db.commit()
    await db.refresh(hero_db)

    return HeroDto(
        id=hero_db.id,
        name=hero_db.name,
        prompt=hero_db.prompt,
        code=hero_db.callback_code,
        color=attributes.get("color", "WHITE"),
        created_at=hero_db.created_at.strftime("%Y-%m-%d %H:%M"),
        vfx_url=hero_db.vfx_url,
        model_url=hero_db.model_url,
        skins=hero_db.skins or [],
    )


@router.get("/api/heroes/default_models")
async def get_default_models():
    """Trỏ thẳng về đường dẫn Local (res://) của Godot Client để khỏi phải lưu file ở Server"""
    # Bạn có thể khai báo cứng các model có sẵn trong thư mục của Godot tại đây
    default_models = [
        {"name": "Mannequin", "url": "res://assets/default_assets/mannequin.glb"},
        {"name": "Knight", "url": "res://assets/default_assets/knight.glb"},
    ]
    return default_models


@router.get("/api/heroes", response_model=List[HeroDto])
async def list_my_heroes(
    db: AsyncSession = Depends(get_db), user_id: int = Depends(get_current_user_id)
):
    """Lay danh sach hero da tao cua User dang nhap"""

    # Load cả Hero của user đang đăng nhập VÀ Hero của user 'system' (id=1)
    result = await db.execute(
        select(HeroSkillSet)
        .where(or_(HeroSkillSet.owner_id == user_id, HeroSkillSet.owner_id == 1))
        .order_by(HeroSkillSet.created_at.desc())
    )
    heroes = result.scalars().all()

    return [
        HeroDto(
            id=h.id,
            name=h.name,
            prompt=h.prompt,
            code=h.callback_code,
            color=h.attributes.get("color", "WHITE"),
            created_at=h.created_at.strftime("%Y-%m-%d %H:%M"),
            vfx_url=h.vfx_url,
            model_url=h.model_url,
            skins=h.skins or [],
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


@router.put("/api/heroes/{hero_id}", response_model=HeroDto)
async def update_hero(
    hero_id: str,
    req: HeroUpdateRequest,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_current_user_id),
):
    """API cập nhật tên và model/skin của Hero, tự động map Animation cho Skin mới"""
    result = await db.execute(
        select(HeroSkillSet).where(
            HeroSkillSet.id == hero_id, HeroSkillSet.owner_id == user_id
        )
    )
    hero_db = result.scalars().first()

    if not hero_db:
        raise HTTPException(
            status_code=404, detail="Không tìm thấy Hero hoặc không có quyền."
        )

    hero_db.name = req.name
    hero_db.model_url = req.model_url

    # THUẬT TOÁN ĐỒNG BỘ ANIMATION CHO SKIN (Thay thế Blender)
    updated_skins = []
    for skin in req.skins:
        skin_url = skin if isinstance(skin, str) else skin.get("url")
        skin_name = (
            skin_url.split("/")[-1].replace(".glb", "")
            if isinstance(skin, str)
            else skin.get("name", "Skin")
        )

        # Nếu skin này đã được xử lý trước đó, giữ nguyên code đã biên dịch
        existing_skin = next(
            (
                s
                for s in hero_db.skins
                if isinstance(s, dict) and s.get("url") == skin_url
            ),
            None,
        )
        if existing_skin and "code" in existing_skin:
            updated_skins.append(existing_skin)
            continue

        # Xử lý skin mới: Sửa lại code logic của Base Hero bằng TRÍ TUỆ NHÂN TẠO
        new_code = hero_db.callback_code
        try:
            physical_path = f"app{skin_url}"
            gltf = pygltflib.GLTF2().load(physical_path)
            new_anims = [a.name for a in gltf.animations] if gltf.animations else []

            if new_anims:
                # Quét tất cả các animation ĐANG CÓ trong code cũ của Hero
                matches = list(
                    set(re.findall(r"current_anim\s*=\s*['\"]([^'\"]+)['\"]", new_code))
                )

                if matches:
                    print(
                        f"[AI Mapper] Đang nhờ Gemini map animation cho skin: {skin_name}..."
                    )
                    # Gọi Gemini để map 2 mảng string với nhau bằng ngữ nghĩa
                    mapped_dict = map_animations_with_ai(matches, new_anims)
                    print(f"[AI Mapper] Kết quả map: {mapped_dict}")

                    # Cầm từ điển Gemini trả về để đè lại vào chuỗi Code
                    for old_anim, new_anim in mapped_dict.items():
                        new_code = re.sub(
                            rf"current_anim\s*=\s*['\"]{old_anim}['\"]",
                            f"current_anim = '{new_anim}'",
                            new_code,
                        )
        except Exception as e:
            print(f"[Cảnh báo] Lỗi khi map animation cho skin {skin_url}: {e}")

        updated_skins.append({"name": skin_name, "url": skin_url, "code": new_code})

    hero_db.skins = updated_skins
    flag_modified(hero_db, "skins")  # Ép SQLAlchemy ghi nhận mảng JSON đã bị sửa

    await db.commit()
    await db.refresh(hero_db)

    return HeroDto(
        id=hero_db.id,
        name=hero_db.name,
        prompt=hero_db.prompt,
        code=hero_db.callback_code,
        color=hero_db.attributes.get("color", "WHITE"),
        created_at=hero_db.created_at.strftime("%Y-%m-%d %H:%M"),
        vfx_url=hero_db.vfx_url,
        model_url=hero_db.model_url,
        skins=hero_db.skins or [],
    )

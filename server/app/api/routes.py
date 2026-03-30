import json

from app.core.state import global_game_state
from app.models.object import GameObject
from app.sandbox.compiler import compile_callback
from app.services.skill_balancer import generate_skill_logic
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

router = APIRouter()


class HeroCreateRequest(BaseModel):
    client_id: str
    prompt: str
    team: int = 1
    ugc_vfx_url: str = ""


@router.post("/api/heroes/generate")
async def generate_hero(request: HeroCreateRequest):
    """API nhận prompt và sinh Hero nạp vào trận đấu"""
    print(f"\n[{request.client_id}] ĐANG YÊU CẦU TẠO TƯỚNG...")
    print(f"Prompt: {request.prompt}")

    # 1. Gọi AI sinh logic (Prompt to JSON)
    ai_result = generate_skill_logic(request.prompt)
    if not ai_result:
        raise HTTPException(status_code=500, detail="Lỗi khi gọi AI tạo bộ kỹ năng.")

    attributes = ai_result.get("attributes", {})
    code_str = ai_result.get("code", "")

    print("\n" + "=" * 50)
    print("🤖 GEMINI ĐÃ TRẢ VỀ KẾT QUẢ:")
    print(f"Attributes:\n{json.dumps(attributes, indent=2)}")
    print(f"Code Sandbox:\n{code_str}")
    print("=" * 50 + "\n")

    # 2. Compile code trong môi trường Sandbox
    callback_func = compile_callback(code_str)
    if not callback_func:
        raise HTTPException(
            status_code=400, detail="Mã AI sinh ra bị lỗi cú pháp Sandbox."
        )

    # 3. Tạo Object Hero và gán vào Game State
    if request.ugc_vfx_url:
        attributes["ugc_vfx_url"] = request.ugc_vfx_url

    hero = GameObject(
        team=request.team, attributes=attributes, client_id=request.client_id
    )
    hero.callback_code = code_str
    hero.callback_func = callback_func
    hero.coord = [500.0, 500.0]  # Spawn tướng ở tọa độ giữa map mặc định

    global_game_state.add_object(hero)

    return {
        "message": "Hero generated successfully",
        "hero_id": hero.id,
        "attributes": attributes,
        "code": code_str,
    }

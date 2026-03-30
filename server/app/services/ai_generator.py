import asyncio


async def generate_3d_model(prompt: str) -> str:
    """
    (Khung) Gọi Shap-E để tạo file .glb từ prompt.
    Tạm thời giả lập thời gian chờ và trả về model mặc định.
    """
    print(f"[AI Worker] Đang tạo model 3D cho prompt: {prompt}...")
    await asyncio.sleep(2)  # Giả lập delay sinh model
    # TODO: Tích hợp API Shap-E thật tại đây
    return "/static/default_assets/hero_default.glb"


async def generate_skill_icon(prompt: str) -> str:
    """
    (Khung) Gọi Stable Diffusion để tạo icon kỹ năng.
    """
    print(f"[AI Worker] Đang vẽ icon cho prompt: {prompt}...")
    await asyncio.sleep(1)
    # TODO: Tích hợp API Stable Diffusion thật tại đây
    return "/static/default_assets/skill_default.png"


async def generate_vfx_gif(prompt: str) -> str:
    """
    (Khung) Gọi AnimateDiff để tạo GIF hiệu ứng chiêu thức.
    """
    print(f"[AI Worker] Đang tạo VFX cho prompt: {prompt}...")
    await asyncio.sleep(3)
    # TODO: Tích hợp API AnimateDiff thật tại đây
    return "/static/default_assets/vfx_explosion.gif"

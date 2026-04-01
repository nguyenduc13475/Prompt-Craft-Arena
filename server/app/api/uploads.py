import base64
import os
import uuid

from app.services.asset_manager import UPLOAD_DIR, save_uploaded_file
from fastapi import APIRouter, File, HTTPException, UploadFile
from pydantic import BaseModel

router = APIRouter()


class Base64UploadRequest(BaseModel):
    image_base64: str
    folder: str = "vfx"


@router.post("/api/uploads/base64")
async def upload_base64(request: Base64UploadRequest):
    """API nhận ảnh Base64 từ UGC Canvas của Godot"""
    try:
        target_dir = os.path.join(UPLOAD_DIR, request.folder)
        os.makedirs(target_dir, exist_ok=True)

        safe_filename = f"{uuid.uuid4().hex}.png"
        file_path = os.path.join(target_dir, safe_filename)

        image_data = base64.b64decode(request.image_base64)
        with open(file_path, "wb") as f:
            f.write(image_data)

        return {
            "message": "Tải ảnh UGC thành công",
            "url": f"/static/uploads/{request.folder}/{safe_filename}",
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/api/uploads/icon")
async def upload_icon(file: UploadFile = File(...)):
    """API cho phép user tự upload Icon skill 2D"""
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Chỉ chấp nhận file hình ảnh.")

    file_url = await save_uploaded_file(file, folder="icons")
    return {"message": "Tải icon thành công", "url": file_url}


@router.post("/api/uploads/model")
async def upload_model(file: UploadFile = File(...)):
    """API cho phép user upload Model (.glb). Đã loại bỏ Blender Auto-Rig!"""
    if not file.filename.endswith(".glb"):
        raise HTTPException(status_code=400, detail="Chỉ chấp nhận định dạng .glb")

    # Lưu thẳng file do user up lên (Mặc định file này phải có xương và animation sẵn)
    file_url = await save_uploaded_file(file, folder="models/skins")

    print(f"[Upload] Đã tải model mới (Skin): {file_url}")
    return {"message": "Tải model thành công", "url": file_url}

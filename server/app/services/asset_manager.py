import os
import uuid

import aiofiles
from fastapi import UploadFile

# Cấu hình thư mục lưu trữ tạm thời trên server (sau này có thể đổi thành S3)
UPLOAD_DIR = "app/static/uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)


async def save_uploaded_file(file: UploadFile, folder: str) -> str:
    """Lưu file và trả về đường dẫn URL ảo"""
    target_dir = os.path.join(UPLOAD_DIR, folder)
    os.makedirs(target_dir, exist_ok=True)

    # Tạo tên file ngẫu nhiên để tránh trùng lặp
    ext = file.filename.split(".")[-1]
    safe_filename = f"{uuid.uuid4().hex}.{ext}"
    file_path = os.path.join(target_dir, safe_filename)

    # Ghi file bất đồng bộ
    async with aiofiles.open(file_path, "wb") as out_file:
        content = await file.read()
        await out_file.write(content)

    # Giả lập trả về URL để Client có thể tải
    return f"/static/uploads/{folder}/{safe_filename}"

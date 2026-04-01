import datetime

from app.models.database import Base
from sqlalchemy import (
    JSON,
    Boolean,
    Column,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
)
from sqlalchemy.orm import relationship


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(
        String, nullable=False
    )  # Trong lab này ta lưu thô để pass thối, production PHẢI hash
    is_active = Column(Boolean, default=True)
    coins = Column(Integer, default=500)  # Tặng 500 xu để test tính năng tạo Model AI
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    heroes = relationship("HeroSkillSet", back_populates="owner")


class HeroSkillSet(Base):
    __tablename__ = "hero_skillsets"

    id = Column(String, primary_key=True, index=True)  # Dùng UUID string
    name = Column(String, index=True, nullable=False)  # Tên do User đặt cho Hero
    prompt = Column(Text, nullable=False)  # Prompt gốc
    owner_id = Column(Integer, ForeignKey("users.id"))

    # Lưu dữ liệu đã gen từ Gemini
    attributes = Column(JSON, nullable=False)  # JSON chứa hp, speed, color, v.v.
    callback_code = Column(Text, nullable=False)  # String code Python

    vfx_url = Column(String, nullable=True)  # Đường dẫn ảnh UGC đã vẽ
    model_url = Column(
        String, default="/static/default_assets/mannequin.glb"
    )  # Ngoại hình mặc định
    skins = Column(JSON, default=[])  # Danh sách URL trang phục bổ sung
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    owner = relationship("User", back_populates="heroes")


class Friendship(Base):
    __tablename__ = "friendships"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    friend_id = Column(Integer, ForeignKey("users.id"))
    status = Column(String, default="pending")  # pending, accepted


class Guild(Base):
    __tablename__ = "guilds"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, index=True)
    leader_id = Column(Integer, ForeignKey("users.id"))
    created_at = Column(DateTime, default=datetime.datetime.utcnow)


class GuildMember(Base):
    __tablename__ = "guild_members"
    id = Column(Integer, primary_key=True, index=True)
    guild_id = Column(Integer, ForeignKey("guilds.id"))
    user_id = Column(Integer, ForeignKey("users.id"))
    role = Column(String, default="member")  # leader, officer, member

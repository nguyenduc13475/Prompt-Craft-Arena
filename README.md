PROJECT STRUCTURE:

PromptCraft-Arena/
├── .github/                    # CI/CD workflows (GitHub Actions)
├── client/                     # Godot 4 Client Project
│   ├── assets/                 # Downloaded 3D models, GIFs, Icons from Server
│   ├── scenes/                 # .tscn files (Lobby, Arena, MainMenu)
│   ├── scripts/                # .gd scripts (WebSocket client, rendering logic)
│   └── project.godot           # Godot project configuration file
│
├── server/
│   ├── app/
│   │   ├── api/
│   │   │   ├── routes.py           # Các API thông thường
│   │   │   ├── websockets.py
│   │   │   └── uploads.py          # Endpoint chuyên hứng file từ user (FastAPI UploadFile)
│   │   ├── core/
│   │   │   ├── game_loop.py
│   │   │   ├── state.py
│   │   │   └── security.py         # Rate limiting, check JWT token khi upload
│   │   ├── services/               # Thư mục chứa các service xử lý nghiệp vụ
│   │   │   ├── ai_generator.py     # Chứa logic gọi Shap-E, SD (nếu user trả tiền)
│   │   │   ├── skill_balancer.py   # Chứa logic gọi Gemini để gen và cân bằng bộ skill
│   │   │   └── asset_manager.py    # Xử lý file: validate (.glb, .png), resize, đẩy lên AWS S3/Cloudflare R2
│   │   ├── sandbox/
│   │   │   ├── compiler.py
│   │   │   └── builtins.py
│   │   └── models/
│   │       ├── object.py
│   │       └── database.py         # Schema của PostgreSQL (User, Hero, Skill, Asset)
│   ├── tests/                  # Pytest unit tests (Crucial for testing AI generated code logic)
│   ├── main.py                 # FastAPI application entry point
│   ├── requirements.txt        # Python dependencies
│   └── Dockerfile              # Backend container configuration
│
├── ai_workers/                 # (Optional/Future) Heavy GPU microservices 
│   ├── sd_vfx_worker/          # Stable Diffusion / AnimateDiff scripts
│   └── shape_3d_worker/        # Shap-E scripts
│
├── docker-compose.yml          # Spins up Server, Redis (if needed), and Workers
├── .gitignore                  # Git ignore rules
└── README.md                   # Project documentation
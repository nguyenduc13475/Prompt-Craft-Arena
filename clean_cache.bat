@echo off
echo [PromptCraft-Arena] Dang tien hanh quet sach rac AI...

:: Xoa rac ben Server
del /q /s "server\app\static\uploads\vfx\*.png" 2>nul
del /q /s "server\app\static\uploads\vfx\*.gif" 2>nul
del /q /s "server\app\static\uploads\icons\*.png" 2>nul
del /q /s "server\app\static\uploads\models\*.glb" 2>nul

:: Xoa rac ben Client
del /q /s "client\assets\generated_vfx\*.png" 2>nul
del /q /s "client\assets\generated_vfx\*.gif" 2>nul
del /q /s "client\assets\generated_models\*.glb" 2>nul

echo.
echo Da don sach se!
pause
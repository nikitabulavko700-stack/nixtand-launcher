@echo off
rem SoundPad 2.0.3 (wheel in games) + launcher 1.3.0
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0release-all.ps1" -Only soundpad,launcher
pause

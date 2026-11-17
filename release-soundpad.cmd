@echo off
rem SoundPad 2.0.4: wheel in games, CS2 voice key
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0release-all.ps1" -Only soundpad
pause

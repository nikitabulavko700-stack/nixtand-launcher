@echo off
rem Launcher 1.3.0: home tab, themes, live background, store filters
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0release-all.ps1" -Only launcher
pause

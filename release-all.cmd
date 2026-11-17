@echo off
rem Double-click: build and publish all nixtand apps (bypasses the script policy for this run only)
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0release-all.ps1" %*
pause

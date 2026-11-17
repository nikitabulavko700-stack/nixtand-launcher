@echo off
rem Server fix + transcribe, then publish: SoundPad 2.0.2, Aurora 1.0.1, launcher 1.2.1
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0release-all.ps1" -Only soundpad,aurora,launcher -Server
pause

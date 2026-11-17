@echo off
rem Kursvik 3.1.1, Crosvik 4.0.2, Frostvik 1.0.2, Kinetic 1.0.1, Aurora 1.0.2: update dim screen
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0release-all.ps1" -Only nebula,crosvik,frostvik,kinetic,aurora
pause

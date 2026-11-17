@echo off
rem Push new app icons (icons\*.png) to GitHub - launcher and catalog pick them up in a few minutes
cd /d "%~dp0"
git add icons
git commit -m "New icons: SoundPad, Aurora"
git pull --rebase
git push
pause

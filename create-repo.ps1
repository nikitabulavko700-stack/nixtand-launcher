<#
  create-repo.ps1 — один раз создаёт репозиторий nixtand-launcher на GitHub и загружает туда apps.json и publish.ps1.
  Нужны git и GitHub CLI:  winget install --id Git.Git -e ;  winget install --id GitHub.cli -e
  Запуск в этой папке:  powershell -ExecutionPolicy Bypass -File .\create-repo.ps1
#>
# Windows PowerShell считает любой вывод git/gh в stderr ошибкой, поэтому проверяем коды выхода сами
$ErrorActionPreference = "Continue"
Set-Location $PSScriptRoot
$name = "nixtand-launcher"
function Fail($msg) { Write-Host "`n$msg" -ForegroundColor Red; Read-Host "Enter — закрыть"; exit 1 }

if (!(Get-Command git -ErrorAction SilentlyContinue)) { Fail "Нет git: winget install --id Git.Git -e  (потом открой PowerShell заново)" }
if (!(Get-Command gh  -ErrorAction SilentlyContinue)) { Fail "Нет GitHub CLI: winget install --id GitHub.cli -e  (потом открой PowerShell заново)" }

# вход в GitHub
cmd /c "gh auth status >nul 2>&1"
if ($LASTEXITCODE -ne 0) {
  Write-Host "Вход в GitHub: выбери GitHub.com -> HTTPS -> Y -> Login with a web browser" -ForegroundColor Yellow
  gh auth login --hostname github.com --git-protocol https --web
  cmd /c "gh auth status >nul 2>&1"
  if ($LASTEXITCODE -ne 0) { Fail "Вход в GitHub не выполнен." }
}
$owner = (gh api user -q .login).Trim()
gh auth setup-git | Out-Null

# локальный репозиторий
if (!(Test-Path ".git")) { git init -b main | Out-Null }
if (-not (git config user.email)) {
  git config user.name $owner
  git config user.email "$owner@users.noreply.github.com"
}
git add apps.json publish.ps1 create-repo.ps1 .gitignore README.md
cmd /c "git commit -m ""nixtand launcher: каталог приложений"" >nul 2>&1"

# репозиторий на GitHub (публичный: лаунчеры игроков читают apps.json и скачивают релизы без входа)
cmd /c "gh repo view $owner/$name >nul 2>&1"
if ($LASTEXITCODE -ne 0) {
  gh repo create "$owner/$name" --public --description "Каталог приложений лаунчера nixtand"
  if ($LASTEXITCODE -ne 0) { Fail "Не удалось создать репозиторий на GitHub." }
}
if (-not ((git remote) -contains "origin")) { git remote add origin "https://github.com/$owner/$name.git" }
git push -u origin main
if ($LASTEXITCODE -ne 0) { Fail "git push не прошёл." }

Write-Host "`nГотово! https://github.com/$owner/$name" -ForegroundColor Green
Write-Host "Каталог для лаунчера (Config.CatalogUrl в Core.cs):"
Write-Host "https://raw.githubusercontent.com/$owner/$name/main/apps.json" -ForegroundColor Cyan
Read-Host "Enter — закрыть"

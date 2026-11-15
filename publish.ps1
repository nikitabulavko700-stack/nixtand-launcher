<#
  publish.ps1 — выпустить новую версию приложения в лаунчер nixtand одной командой.

  Что делает:
    1) пакует папку сборки в .zip (или берёт готовый .exe / .zip);
    2) считает SHA-256 и размер;
    3) создаёт GitHub Release и прикладывает файл (нужен gh: winget install GitHub.cli, потом gh auth login);
    4) меняет apps.json (версия, ссылка, хэш, «что нового») и пушит — лаунчеры увидят обновление в течение ~15 минут
       (или сразу по кнопке «Проверить обновления»).

  Запускать из папки клона репозитория nixtand-launcher:
    .\publish.ps1 -App nebula   -Version 3.1.0 -Path "C:\Dev\Nebula-full\Nebula\bin\publish\Kursvik.exe" -Notes "Nebula теперь Kursvik","Своя панель в трее"
    .\publish.ps1 -App soundpad -Version 1.1.0 -Path "C:\dev\SoundPad\bin\Release\net8.0-windows\win-x64\publish"
    .\publish.ps1 -App launcher -Version 1.0.1 -Path "C:\dev\NixLauncher\bin\Release\net8.0-windows\win-x64\publish\nixtand.exe"
#>
param(
  [Parameter(Mandatory)] [string]   $App,
  [Parameter(Mandatory)] [string]   $Version,
  [Parameter(Mandatory)] [string]   $Path,
  [string[]] $Notes = @(),
  [string]   $Repo = "nikitabulavko700-stack/nixtand-launcher"
)
$ErrorActionPreference = "Stop"

# gh и git пишут обычный текст (прогресс, «release not found») в stderr.
# Windows PowerShell 5 при "Stop" считает это ошибкой и рвёт скрипт — поэтому внешние команды
# запускаем через эту обёртку и смотрим только на код возврата.
function Run-Native([scriptblock]$cmd) {
  $old = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try { & $cmd 2>&1 | ForEach-Object { "$_" } | Write-Host } finally { $ErrorActionPreference = $old }
  return $LASTEXITCODE
}
$root = $PSScriptRoot
$jsonPath = Join-Path $root "apps.json"
if (!(Test-Path $jsonPath)) { throw "apps.json не найден рядом со скриптом." }
if (!(Get-Command gh -ErrorAction SilentlyContinue)) { throw "Нужен GitHub CLI: winget install GitHub.cli, затем gh auth login" }
$Version = $Version.TrimStart("v")

# ---------- 1. файл для загрузки
$out = Join-Path $root "dist"
New-Item -ItemType Directory -Force $out | Out-Null
$item = Get-Item $Path
if ($item.PSIsContainer) {
  $file = Join-Path $out "$App-$Version.zip"
  if (Test-Path $file) { Remove-Item $file }
  Write-Host "Пакую $($item.FullName) → $file"
  Compress-Archive -Path (Join-Path $item.FullName "*") -DestinationPath $file -CompressionLevel Optimal
} else {
  $ext = $item.Extension.ToLower()
  if ($ext -ne ".exe" -and $ext -ne ".zip") { throw "Нужна папка, .exe или .zip" }
  $file = Join-Path $out ("$App-$Version" + $ext)
  Copy-Item $item.FullName $file -Force
}

# ---------- 2. хэш и размер
$sha  = (Get-FileHash $file -Algorithm SHA256).Hash
$size = (Get-Item $file).Length
Write-Host "SHA-256: $sha  ($([math]::Round($size / 1MB, 1)) МБ)"

# ---------- 3. GitHub Release
$tag = "$App-v$Version"
$name = Split-Path $file -Leaf
$notesText = if ($Notes.Count) { ($Notes | ForEach-Object { "- $_" }) -join "`n" } else { "$App $Version" }
$old = $ErrorActionPreference; $ErrorActionPreference = "Continue"
gh release view $tag --repo $Repo 2>&1 | Out-Null
$exists = ($LASTEXITCODE -eq 0)
$ErrorActionPreference = $old
if ($exists) {
  Write-Host "Релиз $tag уже есть — заменяю файл"
  $code = Run-Native { gh release upload $tag $file --repo $Repo --clobber }
} else {
  Write-Host "Создаю релиз $tag (загрузка может занять пару минут)…"
  $code = Run-Native { gh release create $tag $file --repo $Repo --title "$App $Version" --notes $notesText }
}
if ($code -ne 0) { throw "gh не смог загрузить релиз." }
$url = "https://github.com/$Repo/releases/download/$tag/$name"

# ---------- 4. apps.json
$data = Get-Content $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($App -eq "launcher") {
  $data.launcher.version = $Version
  $data.launcher.url = $url
  $data.launcher.sha256 = $sha
  if ($Notes.Count) { $data.launcher.notes = ($Notes -join " · ") }
} else {
  $entry = $data.apps | Where-Object { $_.id -eq $App }
  if (!$entry) { throw "Приложения '$App' нет в apps.json — добавь его блок вручную (скопируй блок nebula/Kursvik и поменяй поля)." }
  $set = { param($k, $v) if ($entry.PSObject.Properties[$k]) { $entry.$k = $v } else { $entry | Add-Member -NotePropertyName $k -NotePropertyValue $v } }
  & $set "version" $Version
  & $set "url" $url
  & $set "sha256" $sha
  & $set "size" $size
  & $set "status" "live"
  & $set "released" (Get-Date -Format "yyyy-MM-dd")
  if ($Notes.Count) { & $set "changelog" @($Notes) }
}
$json = $data | ConvertTo-Json -Depth 20
[IO.File]::WriteAllText($jsonPath, $json, (New-Object Text.UTF8Encoding $false))

Run-Native { git -C $root add apps.json } | Out-Null
Run-Native { git -C $root commit -m "$App $Version" } | Out-Null
$code = Run-Native { git -C $root push }
if ($code -ne 0) { throw "git push не прошёл." }
Write-Host "`nГотово: $App $Version в лаунчере. Ссылка: $url" -ForegroundColor Green

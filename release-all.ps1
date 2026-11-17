<#
  release-all.ps1 — собрать и выложить ВСЕ приложения nixtand в лаунчер и на сайт одной командой.
  (Сайт nixtand.dpdns.org и лаунчер читают один и тот же apps.json из этого репозитория.)

  Что делает:
    1) выкладывает сервер аккаунтов (C:\Dev\nixtand-accounts, npx wrangler deploy) — там оформление профиля для SoundPad 2.0;
    2) для каждого приложения: dotnet publish (Release, win-x64, self-contained) → publish.ps1
       (GitHub Release + новая версия, хэш и «что нового» в apps.json + git push).
  Если одно приложение не собралось — остальные всё равно выкладываются, в конце будет сводка.

  Запуск (PowerShell, из этой папки):
    .\release-all.ps1                     # всё
    .\release-all.ps1 -Only soundpad,nebula
    .\release-all.ps1 -SkipServer         # без выкладки сервера аккаунтов
  Нужно один раз: .NET 8 SDK, GitHub CLI (winget install GitHub.cli → gh auth login), Node.js (для wrangler).
#>
param(
  [string[]] $Only = @(),
  [switch]   $SkipServer,
  [switch]   $Server,          # выложить сервер аккаунтов даже вместе с -Only
  [string]   $Dev = "C:\Dev"
)
$ErrorActionPreference = "Stop"
# из .cmd (powershell -File) список приходит одной строкой «soundpad,aurora,launcher» — разбиваем сами
$Only = @($Only | ForEach-Object { $_ -split '[,;\s]+' } | Where-Object { $_ })
$root = $PSScriptRoot
$build = Join-Path $root "build"

function Run-Native([scriptblock]$cmd) {
  $old = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  try { & $cmd 2>&1 | ForEach-Object { "$_" } | Write-Host } finally { $ErrorActionPreference = $old }
  return $LASTEXITCODE
}

# ---------- что выкладываем
$apps = @(
  @{ Id = "nebula"; Version = "3.1.0"; Name = "Kursvik"
     Projects = @("$Dev\Kursvik\Kursvik\Kursvik.csproj")
     Notes = @("Nebula теперь Kursvik — скины, питомцы и аккаунт остались на месте",
               "Своя панель в трее: текущий скин, быстрые действия, последние скины",
               "Оформление профиля (рамка, фон, цвет ника) видят все, а не только ты",
               "Питомец не пропадает в играх на весь экран",
               "Обновления прямо в программе — кнопка «Обновить» сверху") },
  @{ Id = "soundpad"; Version = "2.0.2"; Name = "SoundPad"; Folder = $true
     Projects = @("$Dev\SoundPad-full\SoundPad\SoundPad.csproj")
     Notes = @("«Назвать по словам» (правый клик по звуку): вместо «0104» — первые слова из звука, можно сразу для всех",
               "Кнопку чата в игре можно выбрать самому — пока чат открыт, звуки на буквах молчат",
               "Новый вид как в Crosvik, всё в одном окне, меню сворачивается, цвет оформления на выбор",
               "Колесо звуков поверх игр (и полноэкранных) — свои звуки по местам",
               "Повтор: последние 30 секунд звука с компьютера одной клавишей",
               "Войс в игре зажимается сам, пока играет звук; режим печати — звуки молчат, пока пишешь",
               "Исправлено: выбор звуков колеса и панели больше не сбрасывается") },
  @{ Id = "crosvik"; Version = "4.0.1"; Name = "Crosvik"
     Projects = @("$Dev\Crosvik\Crosvik\Crosvik.csproj")
     Notes = @("Обновления прямо в программе — вышла новая версия, сверху появится кнопка «Обновить»") },
  @{ Id = "frostvik"; Version = "1.0.1"; Name = "Frostvik"
     Projects = @("$Dev\Snowvik\Frostvik\Frostvik.csproj")
     Notes = @("Обновления прямо в программе — вышла новая версия, сверху появится кнопка «Обновить»") },
  @{ Id = "kinetic"; Version = "1.0.0"; Name = "Kinetic"
     Projects = @("$Dev\Kinetic\Kinetic\Kinetic.csproj")
     Notes = @("Первый выпуск: оверлей клавиш и мыши для стримов",
               "Раскладки WASD, osu!, Minecraft PvP и 60%, свои раскладки",
               "8 тем, KPS/CPS, хромакей для OBS, клики сквозь оверлей",
               "Вход тем же аккаунтом nixtand") },
  @{ Id = "aurora"; Version = "1.0.1"; Name = "Aurora"; Folder = $true
     Projects = @("$Dev\Aurora\Aurora\src\Aurora.Engine\Aurora.Engine.csproj", "$Dev\Aurora\Aurora\src\Aurora.App\Aurora.App.csproj")
     Notes = @("Новый значок Aurora в стиле nixtand",
               "Живые обои под иконками рабочего стола: видео, GIF и интерактивные обои",
               "Импорт из Wallpaper Engine, плейлист, пауза в играх") },
  @{ Id = "launcher"; Version = "1.3.0"; Name = "Лаунчер nixtand"
     Projects = @("$Dev\nixtand-launcher\nixtand-launcher\NixLauncher\NixLauncher.csproj")
     Notes = @("Новая вкладка «Главная»: карусель, «Продолжить», лента обновлений", "8 тем оформления", "Живой фон и фильтры в магазине") }
)
if ($Only.Count) {
  $apps = @($apps | Where-Object { $Only -contains $_.Id })
  if (!$apps.Count) { throw "Ни одно приложение не подходит под -Only $($Only -join ', '). Есть: nebula, soundpad, crosvik, frostvik, kinetic, aurora, launcher." }
}

foreach ($tool in "dotnet", "gh", "git") {
  if (!(Get-Command $tool -ErrorAction SilentlyContinue)) { throw "Не найдено: $tool. Установи и запусти заново." }
}

# ---------- 0. каталог: берём свежий с GitHub (он — главный; publish.ps1 сам допишет новые версии и отправит)
foreach ($d in "rebase-merge", "rebase-apply") {
  if (Test-Path (Join-Path $root ".git\$d")) { Run-Native { git -C $root rebase --abort } | Out-Null }
}
if (Test-Path (Join-Path $root ".git\MERGE_HEAD")) { Run-Native { git -C $root merge --abort } | Out-Null }
if ((Run-Native { git -C $root fetch origin main }) -ne 0) { throw "git fetch не прошёл — проверь интернет и вход в GitHub (gh auth login)." }
Run-Native { git -C $root reset --hard origin/main } | Out-Null

# ---------- 1. сервер аккаунтов
if (!$SkipServer -and (!$Only.Count -or $Server)) {
  $acc = Join-Path $Dev "nixtand-accounts"
  if (Test-Path (Join-Path $acc "wrangler.jsonc")) {
    Write-Host "`n=== Сервер аккаунтов (оформление профиля) ===" -ForegroundColor Cyan
    Push-Location $acc
    try { if ((Run-Native { npx --yes wrangler deploy }) -ne 0) { Write-Warning "wrangler deploy не прошёл — выложи сервер вручную: cd $acc; npx wrangler deploy" } }
    finally { Pop-Location }
  }
}

# ---------- 2. приложения
$done = @(); $failed = @()
foreach ($a in $apps) {
  Write-Host "`n=== $($a.Name) $($a.Version) ===" -ForegroundColor Cyan
  try {
    $out = Join-Path $build $a.Id
    if (Test-Path $out) { Remove-Item $out -Recurse -Force }
    New-Item -ItemType Directory -Force $out | Out-Null

    foreach ($proj in $a.Projects) {
      if (!(Test-Path $proj)) { throw "нет проекта $proj" }
      $code = Run-Native { dotnet publish $proj -c Release -r win-x64 --self-contained true `
                            -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true `
                            -p:DebugType=none -p:Version=$($a.Version) -o $out }
      if ($code -ne 0) { throw "dotnet publish не собрал $(Split-Path $proj -Leaf)" }
    }
    Get-ChildItem $out -Recurse -Include *.pdb | Remove-Item -Force -ErrorAction SilentlyContinue

    # один exe — выкладываем его; несколько файлов (или так задано) — папку целиком в .zip
    $files = Get-ChildItem $out -Recurse -File
    $exe = $files | Where-Object { $_.Extension -eq ".exe" }
    $path = if (!$a.Folder -and $files.Count -eq 1 -and $exe.Count -eq 1) { $exe[0].FullName } else { $out }

    & (Join-Path $root "publish.ps1") -App $a.Id -Version $a.Version -Path $path -Notes $a.Notes
    $done += "$($a.Name) $($a.Version)"
  }
  catch {
    Write-Host "✗ $($a.Name): $($_.Exception.Message)" -ForegroundColor Red
    $failed += "$($a.Name): $($_.Exception.Message)"
  }
}

Write-Host "`n================ ИТОГ ================" -ForegroundColor Cyan
if ($done.Count)   { Write-Host ("Выложено:`n  " + ($done -join "`n  ")) -ForegroundColor Green }
if ($failed.Count) { Write-Host ("Не вышло:`n  " + ($failed -join "`n  ")) -ForegroundColor Red }
Write-Host "Сайт и лаунчеры увидят новые версии в течение ~15 минут (в лаунчере — сразу по «Проверить обновления»)."

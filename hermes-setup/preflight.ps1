#Requires -Version 5.1
<#
    Preflight-проверка Windows перед установкой Hermes Desktop
    и/или Claude Code.

    Скрипт НИЧЕГО не устанавливает и не изменяет — только читает систему
    и печатает отчёт с рекомендацией, каким способом ставить.

    Для Hermes это предварительная проверка: авторитетный ответ о путях
    даёт сам установщик командой
        powershell -File install.ps1 -ShowResolvedPaths

    Запуск (обычный пользователь, права администратора НЕ нужны):
        powershell -ExecutionPolicy Bypass -File .\preflight.ps1
#>

$ErrorActionPreference = 'Continue'

$Problems = New-Object System.Collections.ArrayList
$Warnings = New-Object System.Collections.ArrayList

function Write-Head([string]$Text) {
    Write-Host ''
    Write-Host $Text -ForegroundColor Cyan
    Write-Host ('-' * 62) -ForegroundColor DarkGray
}

function Write-Row([string]$Label, [string]$Value, [string]$Color = 'Gray') {
    Write-Host ('  {0,-22} ' -f ($Label + ':')) -NoNewline
    Write-Host $Value -ForegroundColor $Color
}

function Test-NonAscii([string]$Text) {
    if ([string]::IsNullOrEmpty($Text)) { return $false }
    return ($Text -match '[^\x20-\x7E]')
}

function Get-ShortPath([string]$Path) {
    try {
        $fso = New-Object -ComObject Scripting.FileSystemObject
        return $fso.GetFolder($Path).ShortPath
    } catch {
        return $null
    }
}

Write-Host ''
Write-Host '  Claude Code - проверка готовности системы' -ForegroundColor White
Write-Host ('  ' + (Get-Date -Format 'yyyy-MM-dd HH:mm')) -ForegroundColor DarkGray

# --------------------------------------------------------------------
Write-Head '1. Операционная система'

$os = Get-CimInstance Win32_OperatingSystem
$build = [int]$os.BuildNumber
Write-Row 'Версия' ("{0} (build {1})" -f $os.Caption.Trim(), $build)

if ($build -lt 17763) {
    Write-Row 'Требование' 'Windows 10 1809+ (build 17763) — НЕ выполнено' 'Red'
    [void]$Problems.Add('Версия Windows ниже минимально поддерживаемой (нужен build 17763+).')
} else {
    Write-Row 'Требование' 'Windows 10 1809+ — выполнено' 'Green'
}

$arch = $env:PROCESSOR_ARCHITECTURE
Write-Row 'Архитектура' $arch
if ($arch -notin @('AMD64', 'ARM64')) {
    [void]$Problems.Add("Архитектура $arch не поддерживается (нужна x64 или ARM64).")
}

$ramGb = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
Write-Row 'ОЗУ' ("$ramGb ГБ")
if ($ramGb -lt 4) { [void]$Warnings.Add("ОЗУ $ramGb ГБ — рекомендуется от 4 ГБ.") }

# --------------------------------------------------------------------
Write-Head '2. Кириллица в путях  <- ключевая проверка'

$profilePath = $env:USERPROFILE
$profileBad  = Test-NonAscii $profilePath
Write-Row 'Профиль' $profilePath $(if ($profileBad) { 'Red' } else { 'Green' })

$installBin   = Join-Path $profilePath '.local\bin'
$installShare = Join-Path $profilePath '.local\share\claude'
Write-Row 'Claude Code ->' $installBin $(if ($profileBad) { 'Red' } else { 'Green' })
Write-Row 'Данные ->'      $installShare $(if ($profileBad) { 'Red' } else { 'Green' })

$tempBad = Test-NonAscii $env:TEMP
Write-Row 'TEMP' $env:TEMP $(if ($tempBad) { 'Yellow' } else { 'Green' })

if ($profileBad) {
    Write-Host ''
    Write-Host '  !! В пути профиля есть НЕ-ASCII символы.' -ForegroundColor Red
    Write-Host '     Каталог установки задать нельзя — он всегда внутри профиля,' -ForegroundColor Red
    Write-Host '     так что кириллица попадёт в путь автоматически.' -ForegroundColor Red
    [void]$Problems.Add('Путь профиля содержит не-ASCII символы (кириллицу).')

    $short = Get-ShortPath $profilePath
    if ($short -and -not (Test-NonAscii $short)) {
        Write-Host ''
        Write-Row 'Короткое имя 8.3' $short 'Green'
        Write-Host '     Обходной путь есть: этот путь чистый ASCII.' -ForegroundColor Green
    } else {
        Write-Host ''
        Write-Row 'Короткое имя 8.3' 'недоступно' 'Red'
        Write-Host '     Генерация 8.3-имён, похоже, отключена — обходной путь' -ForegroundColor Yellow
        Write-Host '     через короткое имя работать не будет. Остаётся WSL.' -ForegroundColor Yellow
        [void]$Warnings.Add('8.3-имена недоступны, обход через короткий путь невозможен.')
    }
} else {
    Write-Host ''
    Write-Host '  OK: путь профиля — чистый ASCII, проблемы домашнего ПК не будет.' -ForegroundColor Green
}

if ($tempBad) {
    [void]$Warnings.Add('Путь TEMP содержит не-ASCII символы — возможны сбои распаковки installer''а.')
}

# --------------------------------------------------------------------
Write-Head '3. Кодировка консоли'

$cp = (chcp) -replace '[^\d]', ''
$cpName = switch ($cp) {
    '65001' { 'UTF-8' }
    '866'   { 'OEM кириллица (DOS)' }
    '1251'  { 'Windows кириллица' }
    default { 'кодовая страница ' + $cp }
}
Write-Row 'Кодовая страница' "$cp ($cpName)" $(if ($cp -eq '65001') { 'Green' } else { 'Yellow' })
if ($cp -ne '65001') {
    Write-Host '     Русский текст в выводе может отображаться кракозябрами.' -ForegroundColor Yellow
    Write-Host '     Лечится Windows Terminal или командой:  chcp 65001' -ForegroundColor Yellow
    [void]$Warnings.Add('Консоль не в UTF-8 — возможны кракозябры в русском выводе.')
}

$wtInstalled = $null -ne (Get-Command wt.exe -ErrorAction SilentlyContinue)
Write-Row 'Windows Terminal' $(if ($wtInstalled) { 'установлен' } else { 'не найден' }) `
    $(if ($wtInstalled) { 'Green' } else { 'Yellow' })
if (-not $wtInstalled) {
    [void]$Warnings.Add('Windows Terminal не найден — рекомендуется поставить (winget install Microsoft.WindowsTerminal).')
}

# --------------------------------------------------------------------
Write-Head '4. Сопутствующее ПО'

$gitBash = @(
    "$env:ProgramFiles\Git\bin\bash.exe",
    "${env:ProgramFiles(x86)}\Git\bin\bash.exe",
    "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($gitBash) {
    Write-Row 'Git for Windows' $gitBash 'Green'
} else {
    Write-Row 'Git for Windows' 'не найден (опционально)' 'Yellow'
    Write-Host '     Без него Claude Code использует PowerShell вместо Bash.' -ForegroundColor DarkGray
    [void]$Warnings.Add('Git for Windows не установлен — Bash-инструмент будет недоступен.')
}

$winget = $null -ne (Get-Command winget.exe -ErrorAction SilentlyContinue)
Write-Row 'winget' $(if ($winget) { 'доступен' } else { 'не найден' }) `
    $(if ($winget) { 'Green' } else { 'Yellow' })

$existing = Get-Command claude -ErrorAction SilentlyContinue
if ($existing) {
    Write-Row 'Claude Code' ('уже установлен: ' + $existing.Source) 'Yellow'
    [void]$Warnings.Add('Claude Code уже установлен — новая установка может конфликтовать со старой.')
} else {
    Write-Row 'Claude Code' 'не установлен' 'Gray'
}

# --------------------------------------------------------------------
Write-Head '5. Диск и сеть'

$sysDrive = (Get-PSDrive -Name ($env:SystemDrive -replace ':', '') -ErrorAction SilentlyContinue)
if ($sysDrive) {
    $freeGb = [math]::Round($sysDrive.Free / 1GB, 1)
    Write-Row 'Свободно' ("$freeGb ГБ на $env:SystemDrive") $(if ($freeGb -lt 2) { 'Red' } else { 'Green' })
    if ($freeGb -lt 2) { [void]$Problems.Add("Мало места на $env:SystemDrive ($freeGb ГБ).") }
}

foreach ($host_ in @('claude.ai', 'downloads.claude.ai')) {
    $ok = $false
    try { $ok = (Test-NetConnection -ComputerName $host_ -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue) } catch { }
    Write-Row $host_ $(if ($ok) { 'доступен (443)' } else { 'НЕДОСТУПЕН' }) $(if ($ok) { 'Green' } else { 'Red' })
    if (-not $ok) { [void]$Problems.Add("Нет доступа к $host_ по 443 — вероятно, блокирует корпоративный прокси или файрвол.") }
}

$proxy = $env:HTTPS_PROXY; if (-not $proxy) { $proxy = $env:HTTP_PROXY }
if ($proxy) { Write-Row 'Прокси (env)' $proxy 'Yellow' }

# --------------------------------------------------------------------
Write-Head 'ИТОГ'

if ($Problems.Count -eq 0 -and $Warnings.Count -eq 0) {
    Write-Host '  Всё чисто. Можно ставить обычным способом:' -ForegroundColor Green
} else {
    if ($Problems.Count -gt 0) {
        Write-Host '  Блокеры:' -ForegroundColor Red
        foreach ($p in $Problems) { Write-Host "    - $p" -ForegroundColor Red }
    }
    if ($Warnings.Count -gt 0) {
        Write-Host '  Предупреждения:' -ForegroundColor Yellow
        foreach ($w in $Warnings) { Write-Host "    - $w" -ForegroundColor Yellow }
    }
}

Write-Host ''
Write-Host '  Рекомендованный способ установки:' -ForegroundColor White
if ($profileBad) {
    Write-Host '    -> WSL 2. Домашний каталог внутри WSL (/home/<имя>) гарантированно' -ForegroundColor White
    Write-Host '       ASCII, кириллица профиля Windows на него не влияет вообще.' -ForegroundColor White
    Write-Host '       Подробности и запасной вариант — в README.md рядом со скриптом.' -ForegroundColor White
} else {
    Write-Host '    -> Нативная установка в PowerShell:' -ForegroundColor White
    Write-Host '       irm https://claude.ai/install.ps1 | iex' -ForegroundColor Green
}
Write-Host ''

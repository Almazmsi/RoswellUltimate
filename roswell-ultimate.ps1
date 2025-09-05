# ============================================================
# Roswell Ultimate v2.0.0 — MEGA ЖЫРНЫЙ инсталлер
# Автор: Almazmsi, с сакурой и любовью 🌸
# Лицензия: MIT
# Описание: Устанавливает PowerShell 7, Windows Terminal, Oh My Posh, Fastfetch, Git, VS Code, Bun, VC++ Redist, PsExec, шрифты, профиль, SakuraBot
# ============================================================

# =============== CONFIG ===============
$Version = "2.0.0"
$ScriptStart = Get-Date
$LogFile = Join-Path $env:TEMP "roswell-ultimate-2.0.log"
$ProfileBackupDir = Join-Path $env:TEMP "roswell-backups"
$ProfilePath = Join-Path $env:USERPROFILE "Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
$WTSettingsPaths = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
)

# Ensure log and backup directories exist
if (-not (Test-Path (Split-Path $LogFile))) { New-Item -ItemType Directory -Path (Split-Path $LogFile) -Force | Out-Null }
if (-not (Test-Path $ProfileBackupDir)) { New-Item -ItemType Directory -Path $ProfileBackupDir -Force | Out-Null }

# Логирование
function Log {
    param([string]$Message, [string]$Level = "INFO")
    $t = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    $line = "[$t] [$Level] $Message"
    switch ($Level) {
        "INFO" { Write-Host $line -ForegroundColor Cyan }
        "OK"   { Write-Host $line -ForegroundColor Green }
        "WARN" { Write-Warning $line }
        "ERR"  { Write-Host $line -ForegroundColor Red }
        default { Write-Host $line }
    }
    Add-Content -Path $LogFile -Value $line.Replace("`e[", "").Replace("`e[0m", "") -Encoding UTF8
}

# ASCII-арт лого
function Show-Logo {
    Write-Host -ForegroundColor Magenta @'
🌸🌸🌸 Roswell Ultimate v2.0.0🌸🌸🌸
       _____
      /     \   ____   ____ _____    ____ ___  ____ _____
     /_____/  / ___\ / ___|____ |  / ___|_  ||    |____ |
    |_______ / /___  \___ \   / / / /___ / //|  ||   / /
           |  \____|\____|\ / / | \____|/ / |  ||  / /
           |_______|     |_|/  \_______|_/  |__||_/ /
           |_______|                🌸 by Almazmsi 🌸
'@
    $Progress = "🌸"
    for ($i = 0; $i -lt 10; $i++) {
        Write-Host "`rLoading $Progress" -NoNewline -ForegroundColor Cyan
        $Progress += "🌸"
        [Console]::Beep(600, 100)
        Start-Sleep -Milliseconds 100
    }
    Write-Host "`rLoaded! 🚀            " -ForegroundColor Green
}

# Проверка админа
function Ensure-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Log "Нет прав администратора — перезапускаю через UAC..." "WARN"
        Start-Process -FilePath "pwsh.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit 0
    }
    Log "Запуск с правами администратора" "OK"
}

# Вопрос y/n
function Ask-YesNo($msg) {
    do {
        $r = Read-Host "$msg (y/n)"
    } while ($r -notmatch '^[yYnN]$')
    return $r -match '^[yY]$'
}

# Проверка и установка winget
function Ensure-Winget {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Log "winget найден" "OK"
        return $true
    }
    Log "winget не найден, пытаюсь установить..." "INFO"
    try {
        $WingetUrl = "https://github.com/microsoft/winget-cli/releases/download/v1.8.1911/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
        $TempFile = Join-Path $env:TEMP "winget.msixbundle"
        Invoke-WebRequest -Uri $WingetUrl -OutFile $TempFile -UseBasicParsing
        Add-AppxPackage -Path $TempFile
        Remove-Item -Path $TempFile -Force
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Log "winget установлен" "OK"
            return $true
        } else {
            Log "Ошибка установки winget" "ERR"
            return $false
        }
    } catch {
        Log "Ошибка установки winget: $($_.Exception.Message)" "ERR"
        return $false
    }
}

# Проверка и установка Chocolatey
function Ensure-Choco {
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Log "Chocolatey найден" "OK"
        return $true
    }
    Log "Chocolatey не найден, устанавливаю..." "INFO"
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-WebRequest -Uri "https://chocolatey.org/install.ps1" -UseBasicParsing | Invoke-Expression
        if (Get-Command choco -ErrorAction SilentlyContinue) {
            Log "Chocolatey установлен" "OK"
            return $true
        } else {
            Log "Ошибка установки Chocolatey" "ERR"
            return $false
        }
    } catch {
        Log "Ошибка установки Chocolatey: $($_.Exception.Message)" "ERR"
        return $false
    }
}

# Проверка и установка Scoop
function Ensure-Scoop {
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        Log "Scoop найден" "OK"
        return $true
    }
    Log "Scoop не найден, устанавливаю..." "INFO"
    try {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh')
        if (Get-Command scoop -ErrorAction SilentlyContinue) {
            Log "Scoop установлен" "OK"
            return $true
        } else {
            Log "Ошибка установки Scoop" "ERR"
            return $false
        }
    } catch {
        Log "Ошибка установки Scoop: $($_.Exception.Message)" "ERR"
        return $false
    }
}

# Выбор менеджера пакетов
function Select-PackageManager {
    Write-Host "Выберите менеджер пакетов для установки:" -ForegroundColor Cyan
    Write-Host "1. winget — системный менеджер Windows, быстрый, но требует Store" -ForegroundColor Green
    Write-Host "2. Chocolatey — мощный, но требует прав администратора" -ForegroundColor Green
    Write-Host "3. Scoop — лёгкий, портативный, без админских прав" -ForegroundColor Green
    Write-Host "4. Установить все менеджеры" -ForegroundColor Green
    $choice = Read-Host "Ваш выбор (1-4)"
    if ($choice -eq "4") {
        $wingetInstalled = Ensure-Winget
        $chocoInstalled = Ensure-Choco
        $scoopInstalled = Ensure-Scoop
        Log "Проверка менеджеров завершена: winget=$($wingetInstalled), Chocolatey=$($chocoInstalled), Scoop=$($scoopInstalled)" "INFO"
        Write-Host "Все менеджеры проверены. Выберите один для установки:" -ForegroundColor Cyan
        Write-Host "1. winget" -ForegroundColor Green
        Write-Host "2. Chocolatey" -ForegroundColor Green
        Write-Host "3. Scoop" -ForegroundColor Green
        $choice = Read-Host "Ваш выбор (1-3)"
    }
    switch ($choice) {
        "1" { return "winget" }
        "2" { return "choco" }
        "3" { return "scoop" }
        default { Log "Неверный выбор, использую Scoop по умолчанию" "WARN"; return "scoop" }
    }
}

# Проверка и установка PowerShell 7
function Ensure-PowerShell7 {
    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
        Log "PowerShell 7 найден" "OK"
        if ($PSVersionTable.PSVersion.Major -lt 7) {
            Log "Запускаю скрипт через PowerShell 7..." "INFO"
            Start-Process pwsh -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
            exit
        }
        return $true
    }
    Log "PowerShell 7 не найден, выбирайте менеджер для установки..." "INFO"
    $Manager = Select-PackageManager
    Log "Установка PowerShell 7 через $Manager..." "INFO"
    switch ($Manager) {
        "winget" {
            if (Ensure-Winget) {
                try {
                    & winget install --id Microsoft.PowerShell --silent --accept-package-agreements --accept-source-agreements | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        Log "PowerShell 7 установлен через winget" "OK"
                        Start-Process pwsh -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
                        exit
                    }
                } catch {
                    Log "Ошибка установки PowerShell 7 через winget: $($_.Exception.Message)" "ERR"
                }
            }
        }
        "choco" {
            if (Ensure-Choco) {
                try {
                    & choco install powershell-core -y | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        Log "PowerShell 7 установлен через Chocolatey" "OK"
                        Start-Process pwsh -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
                        exit
                    }
                } catch {
                    Log "Ошибка установки PowerShell 7 через Chocolatey: $($_.Exception.Message)" "ERR"
                }
            }
        }
        "scoop" {
            if (Ensure-Scoop) {
                try {
                    & scoop install pwsh | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        Log "PowerShell 7 установлен через Scoop" "OK"
                        Start-Process pwsh -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
                        exit
                    }
                } catch {
                    Log "Ошибка установки PowerShell 7 через Scoop: $($_.Exception.Message)" "ERR"
                }
            }
        }
    }
    Log "PowerShell 7 не установлен. Установите вручную: https://github.com/PowerShell/PowerShell/releases" "ERR"
    return $false
}

# Установка пакета
function Install-Package {
    param($PackageID, $ChocoID, $ScoopID, $Url, $InstallCommand, $Manager)
    Log "Устанавливаю ${PackageID} через $Manager..." "INFO"
    
    switch ($Manager) {
        "winget" {
            if (Ensure-Winget) {
                try {
                    & winget install --id "${PackageID}" --silent --accept-package-agreements --accept-source-agreements | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        Log "${PackageID} установлен через winget" "OK"
                        return
                    }
                } catch {
                    Log "Ошибка winget для ${PackageID}: $($_.Exception.Message)" "ERR"
                }
            }
        }
        "choco" {
            if (Ensure-Choco) {
                try {
                    & choco install "${ChocoID}" -y | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        Log "${PackageID} установлен через Chocolatey" "OK"
                        return
                    }
                } catch {
                    Log "Ошибка Chocolatey для ${PackageID}: $($_.Exception.Message)" "ERR"
                }
            }
        }
        "scoop" {
            if (Ensure-Scoop) {
                try {
                    & scoop install "${ScoopID}" | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        Log "${PackageID} установлен через Scoop" "OK"
                        return
                    }
                } catch {
                    Log "Ошибка Scoop для ${PackageID}: $($_.Exception.Message)" "ERR"
                }
            }
        }
    }
    
    # Прямое скачивание (fallback)
    if ($Url -and $InstallCommand) {
        try {
            $TempFile = Join-Path $env:TEMP "${PackageID}-installer"
            Invoke-WebRequest -Uri $Url -OutFile $TempFile -UseBasicParsing
            Invoke-Expression $InstallCommand
            Log "${PackageID} установлен через прямую загрузку" "OK"
            Remove-Item $TempFile -Force -ErrorAction SilentlyContinue
        } catch {
            Log "Ошибка прямой установки ${PackageID}: $($_.Exception.Message)" "ERR"
        }
    } else {
        Log "Нет прямого URL для ${PackageID}" "ERR"
    }
}

# Удаление пакета
function Remove-Package {
    param($PackageID, $ChocoID, $ScoopID, $Manager)
    Log "Удаляю ${PackageID} через $Manager..." "INFO"
    
    switch ($Manager) {
        "winget" {
            if (Ensure-Winget) {
                try {
                    & winget uninstall --id "${PackageID}" --silent | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        Log "${PackageID} удалён через winget" "OK"
                        return
                    }
                } catch {
                    Log "Ошибка удаления ${PackageID} через winget: $($_.Exception.Message)" "ERR"
                }
            }
        }
        "choco" {
            if (Ensure-Choco) {
                try {
                    & choco uninstall "${ChocoID}" -y | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        Log "${PackageID} удалён через Chocolatey" "OK"
                        return
                    }
                } catch {
                    Log "Ошибка удаления ${PackageID} через Chocolatey: $($_.Exception.Message)" "ERR"
                }
            }
        }
        "scoop" {
            if (Ensure-Scoop) {
                try {
                    & scoop uninstall "${ScoopID}" | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        Log "${PackageID} удалён через Scoop" "OK"
                        return
                    }
                } catch {
                    Log "Ошибка удаления ${PackageID} через Scoop: $($_.Exception.Message)" "ERR"
                }
            }
        }
    }
}

# Установка шрифтов
function Install-NerdFonts {
    Log "Скачиваю Nerd Fonts FiraCode..." "INFO"
    $FontUrl = "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/FiraCode.zip"
    $FontZip = "$env:TEMP\FiraCode.zip"
    try {
        Invoke-WebRequest -Uri $FontUrl -OutFile $FontZip -UseBasicParsing
        Expand-Archive -Path $FontZip -DestinationPath "$env:TEMP\FiraCode" -Force
        $Shell = New-Object -ComObject Shell.Application
        $FontsFolder = $Shell.Namespace(0x14)
        $Fonts = Get-ChildItem -Path "$env:TEMP\FiraCode" -Filter "*.ttf"
        foreach ($Font in $Fonts) {
            $FontPath = $Font.FullName
            $FontName = $Font.Name
            Copy-Item -Path $FontPath -Destination "C:\Windows\Fonts\$FontName" -Force -ErrorAction Stop
            $FontsFolder.CopyHere($FontPath, 0x10)
            Log "Установлен шрифт $FontName" "OK"
        }
        Remove-Item -Path "$env:TEMP\FiraCode" -Recurse -Force
        Remove-Item -Path $FontZip -Force
    } catch {
        Log "Ошибка установки шрифтов: $($_.Exception.Message)" "ERR"
    }
}

# Настройка Windows Terminal
function Set-WT-Config {
    $SettingsPath = $WTSettingsPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $SettingsPath) {
        Log "Файл настроек Windows Terminal не найден. Создаю..." "INFO"
        $SettingsPath = $WTSettingsPaths[0]
        $DefaultSettings = @'
{
    "$schema": "https://aka.ms/terminal-profiles-schema",
    "defaultProfile": "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}",
    "profiles": {
        "defaults": {
            "font": { "face": "FiraCode Nerd Font" },
            "opacity": 80,
            "useAcrylic": true
        },
        "list": [
            {
                "guid": "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}",
                "name": "PowerShell 7",
                "commandline": "pwsh.exe",
                "hidden": false
            }
        ]
    }
}
'@
        New-Item -ItemType Directory -Path (Split-Path $SettingsPath) -Force | Out-Null
        Set-Content -Path $SettingsPath -Value $DefaultSettings -Encoding UTF8
        Log "Настройки Windows Terminal созданы" "OK"
    }
}

# Установка SakuraBot
function Install-SakuraBot {
    param($Manager)
    Log "Установка SakuraBot для Telegram..." "INFO"
    Install-Package -PackageID "Bun.Bun" -ChocoID "bun" -ScoopID "bun" -Url "https://github.com/oven-sh/bun/releases/download/bun-v1.1.20/bun-windows-x64.zip" -InstallCommand "Expand-Archive -Path $TempFile -DestinationPath 'C:\Program Files\Bun'; [Environment]::SetEnvironmentVariable('Path', [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';C:\Program Files\Bun', 'Machine')" -Manager $Manager
    $BotDir = "C:\Users\$env:USERNAME\SakuraBot"
    New-Item -Path $BotDir -ItemType Directory -Force | Out-Null
    $PackageJson = @'
{
    "name": "sakurabot",
    "version": "1.0.0",
    "scripts": {
        "start": "bun run index.ts",
        "build": "bun build index.ts"
    },
    "dependencies": {
        "grammy": "^1.30.0",
        "dotenv": "^16.4.5"
    },
    "devDependencies": {
        "typescript": "^5.6.2"
    }
}
'@
    Set-Content -Path "$BotDir\package.json" -Value $PackageJson -Encoding UTF8
    $TsConfig = @'
{
    "compilerOptions": {
        "target": "ESNext",
        "module": "ESNext",
        "strict": true,
        "esModuleInterop": true,
        "skipLibCheck": true
    }
}
'@
    Set-Content -Path "$BotDir\tsconfig.json" -Value $TsConfig -Encoding UTF8
    $EnvFile = @'
TELEGRAM_TOKEN=your_token_here
CHAT_ID=personal
'@
    Set-Content -Path "$BotDir\.env" -Value $EnvFile -Encoding UTF8
    $BotCode = @'
import { Bot } from "grammy";
import * as dotenv from "dotenv";

dotenv.config();
const bot = new Bot(process.env.TELEGRAM_TOKEN || "");
bot.command("start", (ctx) => ctx.reply("Connected! 🌸"));
bot.command("elevate", (ctx) => ctx.reply("Elevating..."));
bot.command("sysinfo", (ctx) => ctx.reply("System info..."));
bot.command("hud", (ctx) => ctx.reply("HUD launched..."));
bot.command("update", async (ctx) => {
    ctx.reply("Checking updates...");
});
bot.command("config", (ctx) => ctx.reply("Configuring animation..."));
bot.start().catch((err) => console.error("Ошибка:", err));
'@
    Set-Content -Path "$BotDir\index.ts" -Value $BotCode -Encoding UTF8
    Set-Location -Path $BotDir
    try {
        & bun install
        Log "SakuraBot установлен. Настройте TELEGRAM_TOKEN в $BotDir\.env" "OK"
    } catch {
        Log "Ошибка установки зависимостей SakuraBot: $($_.Exception.Message)" "ERR"
    }
}

# Шаблоны профилей
function Get-ProfileV1-Template {
    return @'
# ====================================================
# Roswell Ultimate v1.0.0 — PowerShell profile
# ====================================================

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "Roswell Ultimate требует PowerShell 7 или выше. Запустите 'pwsh'." -ForegroundColor Red
    return
}

$PSDefaultParameterValues['Out-Default:Verbose'] = $false
$Version = "1.0.0"
$LogFile = Join-Path $env:TEMP "roswell-ultimate-1.0.log"

function Log {
    param([string]$Message, [string]$Level = "INFO")
    $t = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    $line = "[$t] [$Level] $Message"
    switch ($Level) {
        "INFO" { Write-Host $line -ForegroundColor Cyan }
        "OK"   { Write-Host $line -ForegroundColor Green }
        "WARN" { Write-Warning $line }
        "ERR"  { Write-Host $line -ForegroundColor Red }
        default { Write-Host $line }
    }
    if (-not (Test-Path (Split-Path $LogFile))) { New-Item -ItemType Directory -Path (Split-Path $LogFile) -Force | Out-Null }
    Add-Content -Path $LogFile -Value $line.Replace("`e[", "").Replace("`e[0m", "")
}

# Oh My Posh
try {
    oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\paradox.omp.json" | Invoke-Expression
}
catch { }

# posh-git
try { Import-Module posh-git -ErrorAction SilentlyContinue }
catch { }

# PSReadLine
try { Set-PSReadlineOption -PredictionSource History }
catch {}

# Алиасы
function whoami {
    try { [System.Security.Principal.WindowsIdentity]::GetCurrent().Name }
    catch { & whoami.exe }
}

function get-user-role {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($isAdmin) { "Administrator" }
    else { "User" }
}

function systemuac {
    param([string]$ScriptPath = $MyInvocation.MyCommand.Definition)
    Log "Запуск скрипта '$ScriptPath' как SYSTEM..." "INFO"
    $taskName = "Roswell_RunAsSystem_$([guid]::NewGuid().ToString())"
    try {
        $time = (Get-Date).AddSeconds(10).ToString("HH:mm")
        $cmd = "pwsh -NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
        schtasks /Create /SC ONCE /TN $taskName /TR "$cmd" /ST $time /RL HIGHEST /F /RU "SYSTEM" | Out-Null
        Log "Задача '$taskName' создана, запуск через 10 секунд" "INFO"
        schtasks /Run /TN $taskName | Out-Null
        Start-Sleep -Seconds 5
        $taskStatus = schtasks /Query /TN $taskName /FO CSV | ConvertFrom-Csv
        if ($taskStatus.Status -eq "Running") {
            Log "Задача '$taskName' успешно запущена" "OK"
        } else {
            Log "Задача '$taskName' не запустилась, статус: $($taskStatus.Status)" "ERR"
            throw "Задача не выполняется"
        }
        Start-Sleep -Seconds 5
        schtasks /Delete /TN $taskName /F | Out-Null
        Log "Задача '$taskName' удалена" "OK"
    }
    catch {
        Log "Ошибка запуска SYSTEM: $($_.Exception.Message)" "ERR"
        throw
    }
}

function trusteduac {
    param([string]$ScriptPath = $MyInvocation.MyCommand.Definition)
    Log "Попытка запуска скрипта '$ScriptPath' как TrustedInstaller..." "INFO"
    try {
        if (Get-Command psexec -ErrorAction SilentlyContinue) {
            Log "Найден PsExec, использую его для TrustedInstaller" "INFO"
            & psexec -s -accepteula pwsh -NoProfile -ExecutionPolicy Bypass -File $ScriptPath
            Log "Запуск через PsExec завершён" "OK"
            return
        }
        else {
            Log "PsExec не найден, невозможно запустить как TrustedInstaller" "ERR"
            throw "PsExec not found"
        }
    }
    catch {
        Log "Ошибка запуска TrustedInstaller: $($_.Exception.Message)" "ERR"
        throw
    }
}

function sysinfo {
    try {
        $fastfetchPath = "C:\Program Files\Fastfetch\fastfetch.exe"
        if (Test-Path $fastfetchPath) {
            & $fastfetchPath --logo windows --color blue --structure os:kernel:cpu:memory:disk:gpu
        }
        else {
            fastfetch --logo windows --color blue --structure os:kernel:cpu:memory:disk:gpu
        }
    }
    catch {
        Log "Fastfetch не доступен. Установите: Install-Package -PackageID Fastfetch-cli.Fastfetch" "ERR"
    }
}

function update-profile {
    Log "Проверка обновлений профиля..." "INFO"
    $ProfileUpdateURL = "https://raw.githubusercontent.com/Almazmsi/RoswellUltimate/main/roswell-v1.ps1"
    try {
        $remote = Invoke-WebRequest -Uri $ProfileUpdateURL -UseBasicParsing
        $remoteVersion = ($remote.Content | Select-String '\$Version = "([\d.]+)"').Matches.Groups[1].Value
        if ($remoteVersion -gt $Version) {
            Log "Найдено обновление профиля: v$remoteVersion" "INFO"
            $backup = Join-Path $ProfileBackupDir "profile_$(Get-Date -Format 'yyyyMMddHHmmss').ps1"
            Copy-Item -Path $ProfilePath -Destination $backup
            Log "Текущий профиль сохранён в $backup" "OK"
            Set-Content -Path $ProfilePath -Value $remote.Content -Encoding UTF8
            Log "Профиль обновлён до v$remoteVersion" "OK"
        }
        else {
            Log "Профиль на последней версии (v$Version)" "OK"
        }
    }
    catch {
        Log "Ошибка проверки обновлений: $($_.Exception.Message)" "ERR"
    }
}

function Get-GradientBar {
    param ([int]$percent, [string]$label, [switch]$animate)
    $barLength = 20
    $filled = [math]::Round($percent / 100 * $barLength)
    $empty = $barLength - $filled
    $bar = "█" * $filled + " " * $empty
    $color = if ($percent -lt 30) { "`e[31m" } elseif ($percent -lt 70) { "`e[33m" } else { "`e[32m" }
    $labelText = if ($label) { "$label " } else { "" }
    return "$labelText|$color$bar`e[0m| $percent%"
}

function Start-LiveHUD {
    while ($true) {
        Clear-Host
        $cpu = Get-CimInstance Win32_Processor | Select-Object -ExpandProperty LoadPercentage
        $mem = Get-CimInstance Win32_OperatingSystem
        $memPercent = [math]::Round(($mem.TotalVisibleMemorySize - $mem.FreePhysicalMemory) / $mem.TotalVisibleMemorySize * 100)
        Write-Host "CPU Usage: $(Get-GradientBar -percent $cpu -label "CPU")" -ForegroundColor Cyan
        Write-Host "Memory Usage: $(Get-GradientBar -percent $memPercent -label "RAM")" -ForegroundColor Cyan
        Start-Sleep -Seconds 2
    }
}

function Show-StartupAnimation {
    Write-Host "Запускаю анимацию Roswell Ultimate..." -ForegroundColor Yellow
    $text = "Loading Roswell Ultimate 1.0.0..."
    $max = 100
    Clear-Host
    Write-Host "`n"
    Write-Host "  ██████╗  ██████╗ ███████╗██████╗ ██╗    ██╗███████╗██╗     ██╗     " -ForegroundColor Cyan
    Write-Host "  ██╔══██╗██╔═══██╗██╔════╝██╔══██╗██║    ██║██╔════╝██║     ██║     " -ForegroundColor Cyan
    Write-Host "  ██████╔╝██║   ██║███████╗██████╔╝██║ █╗ ██║█████╗  ██║     ██║     " -ForegroundColor Cyan
    Write-Host "  ██╔══██╗██║   ██║╚════██║██╔══██╗██║███╗██║██╔══╝  ██║     ██║     " -ForegroundColor Cyan
    Write-Host "  ██║  ██║╚██████╔╝███████║██║  ██║╚███╔███╔╝███████╗███████╗███████╗" -ForegroundColor Cyan
    Write-Host "  ╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝ ╚══╝╚══╝ ╚══════╝╚══════╝╚══════╝" -ForegroundColor Cyan
    Write-Host "`n" -ForegroundColor Cyan
    for ($p = 0; $p -le $max; $p += 5) {
        $bar = Get-GradientBar -percent $p -label $text -animate
        Write-Host $bar
        Start-Sleep -Milliseconds 150
        if ($p -lt $max) {
            [Console]::SetCursorPosition(0, [Console]::CursorTop - 1)
        }
    }
    Write-Host "Roswell Ultimate 1.0.0 loaded! 🚀" -ForegroundColor Green
    [Console]::Beep(500, 200)
}

function enable-roswell-animation {
    Set-Content -Path "$env:TEMP\.roswell_animation_enabled" -Value "enabled"
    Write-Host "Анимация включена" -ForegroundColor Yellow
}

function disable-roswell-startup {
    Set-Content -Path "$env:TEMP\.roswell_disable_startup" -Value "disabled"
    Write-Host "Стартовый вывод отключён" -ForegroundColor Yellow
}

$flagFile = "$env:TEMP\.roswell_first_run"
$disableFile = "$env:TEMP\.roswell_disable_startup"
$animationFile = "$env:TEMP\.roswell_animation_enabled"
$author = "Автор: github.com/Almazmsi"
$repo = "Репозитория: github.com/Almazmsi/RoswellUltimate"

if (Test-Path $disableFile) {
    Start-LiveHUD
    Write-Host "`nRoswell Ultimate profile loaded (1.0.0)"
}
else {
    Write-Host "Загружаю профиль в PowerShell $PSVersionTable.PSVersion" -ForegroundColor Yellow
    if (-not (Test-Path $flagFile) -or (Test-Path $animationFile)) {
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            Show-StartupAnimation
        }
        else {
            Write-Host "Анимация отключена: требуется PowerShell 7" -ForegroundColor Red
        }
        if (-not (Test-Path $flagFile)) {
            Write-Host $author -ForegroundColor Magenta
            Write-Host $repo -ForegroundColor Magenta
            Set-Content -Path $flagFile -Value "first_run_complete"
        }
        Start-Sleep -Seconds 10
        Clear-Host
    }
    try {
        $fastfetchPath = "C:\Program Files\Fastfetch\fastfetch.exe"
        if (Test-Path $fastfetchPath) {
            & $fastfetchPath --logo windows --color blue --structure os:kernel:cpu:memory:disk:gpu
        }
        else {
            fastfetch --logo windows --color blue --structure os:kernel:cpu:memory:disk:gpu
        }
    }
    catch {
        Log "Fastfetch не доступен. Установите: Install-Package -PackageID Fastfetch-cli.Fastfetch" "ERR"
    }
    Write-Host "Roswell Ultimate 1.0.0 loaded! 🚀" -ForegroundColor Green
    Start-LiveHUD
    Write-Host "`nRoswell Ultimate profile loaded (1.0.0)"
}
'@
}

function Get-ProfileV2-Template {
    return @'
# ====================================================
# Roswell Ultimate v2.0.0 — ЖЫРНЫЙ PowerShell profile
# Автор: Almazmsi
# Описание: Полный профиль с HUD, анимациями, алиасами, SakuraBot
# ====================================================

$Version = "2.0.0"
$LogFile = Join-Path $env:TEMP "roswell-ultimate-2.0.log"
$AnimationEnabled = $false
$AnimationType = "sakura"

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "Roswell Ultimate v2 требует PowerShell 7 или выше. Запустите 'pwsh'." -ForegroundColor Red
    return
}

$PSDefaultParameterValues['Out-Default:Verbose'] = $false

function Log {
    param([string]$Message, [string]$Level = "INFO")
    $t = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    $line = "[$t] [$Level] $Message"
    switch ($Level) {
        "INFO" { Write-Host $line -ForegroundColor Cyan }
        "OK"   { Write-Host $line -ForegroundColor Green }
        "WARN" { Write-Warning $line }
        "ERR"  { Write-Host $line -ForegroundColor Red }
        default { Write-Host $line }
    }
    if (-not (Test-Path (Split-Path $LogFile))) { New-Item -ItemType Directory -Path (Split-Path $LogFile) -Force | Out-Null }
    Add-Content -Path $LogFile -Value $line.Replace("`e[", "").Replace("`e[0m", "") -Encoding UTF8
}

# Oh My Posh
try {
    oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\star.omp.json" | Invoke-Expression
}
catch { }

# posh-git
try { Import-Module posh-git -ErrorAction SilentlyContinue }
catch { }

# PSReadLine
try { Set-PSReadlineOption -PredictionSource History -PredictionViewStyle ListView }
catch {}

# Алиасы
Set-Alias -Name who -Value whoami
Set-Alias -Name role -Value get-user-role
Set-Alias -Name up -Value elevate
Set-Alias -Name sys -Value systemuac
Set-Alias -Name trust -Value trusteduac
Set-Alias -Name info -Value sysinfo
Set-Alias -Name monitor -Value hud
Set-Alias -Name update -Value update-profile
Set-Alias -Name config -Value roswell-config
Set-Alias -Name anim-on -Value enable-roswell-animation
Set-Alias -Name anim-off -Value disable-roswell-startup
Set-Alias -Name diag -Value roswell-diagnostic
Set-Alias -Name backup -Value roswell-backup
Set-Alias -Name restore -Value roswell-restore
Set-Alias -Name sakura -Value start-sakura
Set-Alias -Name stats -Value system-stats

# Команды
function whoami {
    try { [System.Security.Principal.WindowsIdentity]::GetCurrent().Name }
    catch { & whoami.exe }
}

function get-user-role {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($isAdmin) { "Administrator" } else { "User" }
}

function elevate {
    Start-Process pwsh -Verb RunAs
}

function systemuac {
    param([string]$ScriptPath = $MyInvocation.MyCommand.Definition)
    Log "Запуск скрипта '$ScriptPath' как SYSTEM..." "INFO"
    $taskName = "Roswell_RunAsSystem_$([guid]::NewGuid().ToString())"
    try {
        $time = (Get-Date).AddSeconds(10).ToString("HH:mm")
        $cmd = "pwsh -NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
        schtasks /Create /SC ONCE /TN $taskName /TR "$cmd" /ST $time /RL HIGHEST /F /RU "SYSTEM" | Out-Null
        Log "Задача '$taskName' создана, запуск через 10 секунд" "INFO"
        schtasks /Run /TN $taskName | Out-Null
        Start-Sleep -Seconds 5
        $taskStatus = schtasks /Query /TN $taskName /FO CSV | ConvertFrom-Csv
        if ($taskStatus.Status -eq "Running") {
            Log "Задача '$taskName' успешно запущена" "OK"
        } else {
            Log "Задача '$taskName' не запустилась, статус: $($taskStatus.Status)" "ERR"
            throw "Задача не выполняется"
        }
        Start-Sleep -Seconds 5
        schtasks /Delete /TN $taskName /F | Out-Null
        Log "Задача '$taskName' удалена" "OK"
    }
    catch {
        Log "Ошибка запуска SYSTEM: $($_.Exception.Message)" "ERR"
        throw
    }
}

function trusteduac {
    param([string]$ScriptPath = $MyInvocation.MyCommand.Definition)
    Log "Попытка запуска скрипта '$ScriptPath' как TrustedInstaller..." "INFO"
    try {
        if (Get-Command psexec -ErrorAction SilentlyContinue) {
            Log "Найден PsExec, использую его для TrustedInstaller" "INFO"
            & psexec -s -accepteula pwsh -NoProfile -ExecutionPolicy Bypass -File $ScriptPath
            Log "Запуск через PsExec завершён" "OK"
            return
        }
        else {
            Log "PsExec не найден, невозможно запустить как TrustedInstaller" "ERR"
            throw "PsExec not found"
        }
    }
    catch {
        Log "Ошибка запуска TrustedInstaller: $($_.Exception.Message)" "ERR"
        throw
    }
}

function sysinfo {
    try {
        $fastfetchPath = "C:\Program Files\Fastfetch\fastfetch.exe"
        if (Test-Path $fastfetchPath) {
            & $fastfetchPath --logo windows --color blue --structure os:kernel:cpu:memory:disk:gpu
        }
        else {
            fastfetch --logo windows --color blue --structure os:kernel:cpu:memory:disk:gpu
        }
    }
    catch {
        Log "Fastfetch не доступен. Установите: Install-Package -PackageID Fastfetch-cli.Fastfetch" "ERR"
    }
}

function hud {
    while ($true) {
        Clear-Host
        $cpu = Get-CimInstance Win32_Processor | Select-Object -ExpandProperty LoadPercentage
        $mem = Get-CimInstance Win32_OperatingSystem
        $memPercent = [math]::Round(($mem.TotalVisibleMemorySize - $mem.FreePhysicalMemory) / $mem.TotalVisibleMemorySize * 100)
        $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
        $diskPercent = [math]::Round(($disk.Size - $disk.FreeSpace) / $disk.Size * 100)
        Write-Host "CPU Usage: $(Get-GradientBar -percent $cpu -label "CPU")" -ForegroundColor Cyan
        Write-Host "Memory Usage: $(Get-GradientBar -percent $memPercent -label "RAM")" -ForegroundColor Cyan
        Write-Host "Disk C: Usage: $(Get-GradientBar -percent $diskPercent -label "Disk")" -ForegroundColor Cyan
        Start-Sleep -Seconds 2
    }
}

function system-stats {
    $cpu = Get-CimInstance Win32_Processor | Select-Object -ExpandProperty LoadPercentage
    $mem = Get-CimInstance Win32_OperatingSystem
    $memPercent = [math]::Round(($mem.TotalVisibleMemorySize - $mem.FreePhysicalMemory) / $mem.TotalVisibleMemorySize * 100)
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    $diskPercent = [math]::Round(($disk.Size - $disk.FreeSpace) / $disk.Size * 100)
    $gpu = Get-CimInstance Win32_VideoController
    Write-Host "System Stats:" -ForegroundColor Cyan
    Write-Host "CPU: $cpu%" -ForegroundColor Green
    Write-Host "RAM: $memPercent%" -ForegroundColor Green
    Write-Host "Disk C: $diskPercent%" -ForegroundColor Green
    Write-Host "GPU: $($gpu.Name)" -ForegroundColor Green
}

function start-sakura {
    $BotDir = "C:\Users\$env:USERNAME\SakuraBot"
    if (Test-Path "$BotDir\index.ts") {
        Set-Location -Path $BotDir
        & bun run index.ts
        Log "SakuraBot запущен" "OK"
    }
    else {
        Log "SakuraBot не найден в $BotDir" "ERR"
    }
}

function update-profile {
    Log "Проверка обновлений профиля..." "INFO"
    $ProfileUpdateURL = "https://raw.githubusercontent.com/Almazmsi/RoswellUltimate/main/roswell-v2.ps1"
    try {
        $remote = Invoke-WebRequest -Uri $ProfileUpdateURL -UseBasicParsing
        $remoteVersionMatch = $remote.Content | Select-String '\$Version = "([\d.]+)"'
        $remoteVersion = if ($remoteVersionMatch) { $remoteVersionMatch.Matches.Groups[1].Value } else { "0.0.0" }
        if ($remoteVersion -gt $Version) {
            Log "Найдено обновление профиля: v$remoteVersion" "INFO"
            $backup = Join-Path $ProfileBackupDir "profile_$(Get-Date -Format 'yyyyMMddHHmmss').ps1"
            Copy-Item -Path $ProfilePath -Destination $backup
            Log "Текущий профиль сохранён в $backup" "OK"
            Set-Content -Path $ProfilePath -Value $remote.Content -Encoding UTF8
            Log "Профиль обновлён до v$remoteVersion" "OK"
        }
        else {
            Log "Профиль на последней версии (v$Version)" "OK"
        }
    }
    catch {
        Log "Ошибка проверки обновлений: $($_.Exception.Message)" "ERR"
    }
}

function roswell-config {
    Add-Type -AssemblyName System.Windows.Forms
    $Form = New-Object Windows.Forms.Form
    $Form.Text = "Roswell Config v2.0.0"
    $Form.Size = New-Object Drawing.Size(300, 300)
    $Label = New-Object Windows.Forms.Label
    $Label.Text = "Выберите анимацию:"
    $Label.Location = New-Object Drawing.Point(10, 20)
    $ComboBox = New-Object Windows.Forms.ComboBox
    $ComboBox.Items.AddRange(@("sakura", "space", "anime"))
    $ComboBox.SelectedIndex = 0
    $ComboBox.Location = New-Object Drawing.Point(10, 50)
    $BotLabel = New-Object Windows.Forms.Label
    $BotLabel.Text = "Telegram Token:"
    $BotLabel.Location = New-Object Drawing.Point(10, 80)
    $BotToken = New-Object Windows.Forms.TextBox
    $BotToken.Location = New-Object Drawing.Point(10, 110)
    $BotToken.Width = 260
    $ChatLabel = New-Object Windows.Forms.Label
    $ChatLabel.Text = "Chat ID:"
    $ChatLabel.Location = New-Object Drawing.Point(10, 140)
    $ChatID = New-Object Windows.Forms.TextBox
    $ChatID.Location = New-Object Drawing.Point(10, 170)
    $ChatID.Width = 260
    $Button = New-Object Windows.Forms.Button
    $Button.Text = "Save"
    $Button.Location = New-Object Drawing.Point(100, 200)
    $Button.Add_Click({
        $script:AnimationType = $ComboBox.SelectedItem
        Log "Анимация установлена: $AnimationType" "OK"
        $BotDir = "C:\Users\$env:USERNAME\SakuraBot"
        $EnvFile = "$BotDir\.env"
        Set-Content -Path $EnvFile -Value "TELEGRAM_TOKEN=$($BotToken.Text)`nCHAT_ID=$($ChatID.Text)" -Encoding UTF8
        Log "SakuraBot настройки сохранены в $EnvFile" "OK"
        $Form.Close()
    })
    $Form.Controls.Add($Label)
    $Form.Controls.Add($ComboBox)
    $Form.Controls.Add($BotLabel)
    $Form.Controls.Add($BotToken)
    $Form.Controls.Add($ChatLabel)
    $Form.Controls.Add($ChatID)
    $Form.Controls.Add($Button)
    $Form.ShowDialog()
}

function enable-roswell-animation {
    $script:AnimationEnabled = $true
    Set-Content -Path "$env:TEMP\.roswell_animation_enabled" -Value "enabled"
    Write-Host "Анимация включена" -ForegroundColor Green
}

function disable-roswell-startup {
    $script:AnimationEnabled = $false
    Set-Content -Path "$env:TEMP\.roswell_disable_startup" -Value "disabled"
    Write-Host "Стартовый вывод отключён" -ForegroundColor Yellow
}

function roswell-diagnostic {
    Log "Диагностика системы..." "INFO"
    Write-Host "PowerShell: $($PSVersionTable.PSVersion)" -ForegroundColor Green
    Write-Host "Fastfetch: $(if (Get-Command fastfetch -ErrorAction SilentlyContinue) { 'OK' } else { 'Not found' })" -ForegroundColor Green
    Write-Host "Bun: $(if (Get-Command bun -ErrorAction SilentlyContinue) { 'OK' } else { 'Not found' })" -ForegroundColor Green
    Write-Host "PsExec: $(if (Get-Command psexec -ErrorAction SilentlyContinue) { 'OK' } else { 'Not found' })" -ForegroundColor Green
}

function roswell-backup {
    $backup = Join-Path $ProfileBackupDir "profile_$(Get-Date -Format 'yyyyMMddHHmmss').ps1"
    Copy-Item -Path $ProfilePath -Destination $backup
    Log "Профиль сохранён в $backup" "OK"
}

function roswell-restore {
    $backups = Get-ChildItem -Path $ProfileBackupDir -Filter "*.ps1"
    if ($backups) {
        Write-Host "Доступные бэкапы:" -ForegroundColor Cyan
        $backups | ForEach-Object { Write-Host $_.Name }
        $selected = Read-Host "Введите имя файла бэкапа для восстановления"
        $backupPath = Join-Path $ProfileBackupDir $selected
        if (Test-Path $backupPath) {
            Copy-Item -Path $backupPath -Destination $ProfilePath
            Log "Профиль восстановлен из $backupPath" "OK"
        }
        else {
            Log "Бэкап не найден: $backupPath" "ERR"
        }
    }
    else {
        Log "Бэкапы не найдены" "ERR"
    }
}

function Get-GradientBar {
    param ([int]$percent, [string]$label, [switch]$animate)
    $barLength = 20
    $filled = [math]::Round($percent / 100 * $barLength)
    $empty = $barLength - $filled
    $bar = "█" * $filled + " " * $empty
    $color = if ($percent -lt 30) { "`e[31m" } elseif ($percent -lt 70) { "`e[33m" } else { "`e[32m" }
    $labelText = if ($label) { "$label " } else { "" }
    return "$labelText|$color$bar`e[0m| $percent%"
}

function Show-StartupAnimation {
    if (-not $AnimationEnabled) { return }
    $text = "Loading Roswell Ultimate v2.0.0..."
    $max = 100
    Clear-Host
    switch ($AnimationType) {
        "sakura" {
            Write-Host @"
🌸🌸🌸 Sakura Animation 🌸🌸🌸
       _____
      /     \
     /_____/  Roswell Ultimate v2.0.0
"@ -ForegroundColor Magenta
        }
        "space" {
            Write-Host @"
🚀🚀🚀 Space Animation 🚀🚀🚀
   *   *   *   Roswell Ultimate v2.0.0
"@ -ForegroundColor Cyan
        }
        "anime" {
            Write-Host @"
🎌🎌🎌 Anime Animation 🎌🎌🎌
   ~   ~   ~   Roswell Ultimate v2.0.0
"@ -ForegroundColor Yellow
        }
    }
    for ($p = 0; $p -le $max; $p += 5) {
        $bar = Get-GradientBar -percent $p -label $text -animate
        Write-Host $bar
        Start-Sleep -Milliseconds 150
        if ($p -lt $max) {
            [Console]::SetCursorPosition(0, [Console]::CursorTop - 1)
        }
    }
    Write-Host "Roswell Ultimate v2.0.0 loaded! 🚀" -ForegroundColor Green
    [Console]::Beep(600, 200)
}

$flagFile = "$env:TEMP\.roswell_first_run"
$disableFile = "$env:TEMP\.roswell_disable_startup"
$animationFile = "$env:TEMP\.roswell_animation_enabled"
$author = "Автор: github.com/Almazmsi"
$repo = "Репозитория: github.com/Almazmsi/RoswellUltimate"

if (Test-Path $disableFile) {
    Write-Host "`nRoswell Ultimate profile loaded (v2.0.0)"
}
else {
    Write-Host "Загружаю профиль в PowerShell $PSVersionTable.PSVersion" -ForegroundColor Yellow
    if (-not (Test-Path $flagFile) -or (Test-Path $animationFile)) {
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            Show-StartupAnimation
        }
        else {
            Write-Host "Анимация отключена: требуется PowerShell 7" -ForegroundColor Red
        }
        if (-not (Test-Path $flagFile)) {
            Write-Host $author -ForegroundColor Magenta
            Write-Host $repo -ForegroundColor Magenta
            Set-Content -Path $flagFile -Value "first_run_complete"
        }
        Start-Sleep -Seconds 10
        Clear-Host
    }
    try {
        $fastfetchPath = "C:\Program Files\Fastfetch\fastfetch.exe"
        if (Test-Path $fastfetchPath) {
            & $fastfetchPath --logo windows --color blue --structure os:kernel:cpu:memory:disk:gpu
        }
        else {
            fastfetch --logo windows --color blue --structure os:kernel:cpu:memory:disk:gpu
        }
    }
    catch {
        Log "Fastfetch не доступен. Установите: Install-Package -PackageID Fastfetch-cli.Fastfetch" "ERR"
    }
    Write-Host "Roswell Ultimate v2.0.0 loaded! 🚀" -ForegroundColor Green
    Write-Host "`nRoswell Ultimate profile loaded (v2.0.0)"
}
'@
}

function Install-Profile {
    param($Version)
    $Template = if ($Version -eq "v1") { Get-ProfileV1-Template } else { Get-ProfileV2-Template }
    $Backup = Join-Path $ProfileBackupDir "profile_$(Get-Date -Format 'yyyyMMddHHmmss').ps1"
    if (Test-Path $ProfilePath) {
        Copy-Item -Path $ProfilePath -Destination $Backup
        Log "Текущий профиль сохранён в $Backup" "OK"
    }
    $ProfileDir = Split-Path $ProfilePath -Parent
    if (-not (Test-Path $ProfileDir)) {
        New-Item -ItemType Directory -Path $ProfileDir -Force | Out-Null
    }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    try {
        [System.IO.File]::WriteAllText($ProfilePath, $Template, $utf8NoBom)
        Log "Профиль roswell-$Version установлен в $ProfilePath" "OK"
    } catch {
        Log "Ошибка установки профиля: $($_.Exception.Message)" "ERR"
    }
}

# Старое меню
function Show-Menu {
    Write-Host "Добро пожаловать в Roswell Ultimate v2.0.0 Installer!" -ForegroundColor Magenta
    Write-Host "Выберите действия (можно несколько, через запятую, или 'all' для всех):" -ForegroundColor Cyan
    Write-Host "1. Очистка предыдущих установок" -ForegroundColor Green
    Write-Host "2. Установка пакетов (PowerShell, Terminal, fastfetch, VS Code, Node.js, VC++ Redist, PsExec)" -ForegroundColor Green
    Write-Host "3. Установка Nerd Fonts (FiraCode)" -ForegroundColor Green
    Write-Host "4. Настройка прозрачности Windows Terminal" -ForegroundColor Green
    Write-Host "5. Установка/обновление профиля PowerShell (выбор старый/новый, анимация, запуск)" -ForegroundColor Green
    Write-Host "6. Установка fastfetch" -ForegroundColor Green
    Write-Host "7. Настройка Windows Terminal на PowerShell 7" -ForegroundColor Green
    Write-Host "0. Выход" -ForegroundColor Yellow
    $choice = Read-Host "Ваш выбор (например, 1,3,5 или all)"
    return $choice
}

# Обработка старого меню
function Process-Menu {
    $Manager = Select-PackageManager
    $Choices = Show-Menu
    if ($Choices -eq "0") { return $false }
    $actions = if ($Choices -eq "all") { 1..7 } else { $Choices -split "," | ForEach-Object { [int]$_ } }
    if ($actions -contains 2 -or $actions -contains 1) {
        if (Ask-YesNo "Создать точку восстановления системы? (Рекомендуется)") {
            try {
                Enable-ComputerRestore -Drive "C:" -ErrorAction SilentlyContinue
                Checkpoint-Computer -Description "Before Roswell Ultimate v2.0.0" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
                Log "Точка восстановления создана" "OK"
            }
            catch {
                Log "Ошибка создания точки восстановления: $($_.Exception.Message)" "ERR"
            }
        }
    }
    foreach ($action in $actions) {
        switch ($action) {
            1 {
                Log "Запускаю очистку предыдущих установок..." "INFO"
                Remove-Package -PackageID "Microsoft.PowerShell" -ChocoID "powershell" -ScoopID "pwsh" -Manager $Manager
                Remove-Package -PackageID "Microsoft.WindowsTerminal" -ChocoID "windows-terminal" -ScoopID "windows-terminal" -Manager $Manager
                Remove-Package -PackageID "JanDeDobbeleer.OhMyPosh" -ChocoID "oh-my-posh" -ScoopID "oh-my-posh" -Manager $Manager
                Remove-Package -PackageID "Fastfetch-cli.Fastfetch" -ChocoID "fastfetch" -ScoopID "fastfetch" -Manager $Manager
                Remove-Package -PackageID "Git.Git" -ChocoID "git" -ScoopID "git" -Manager $Manager
                Remove-Package -PackageID "Microsoft.VisualStudioCode" -ChocoID "vscode" -ScoopID "vscode" -Manager $Manager
                Remove-Package -PackageID "Microsoft.VCRedist.2015+.x64" -ChocoID "vcredist2015" -ScoopID "vcredist2015" -Manager $Manager
                Remove-Package -PackageID "Sysinternals.PsExec" -ChocoID "sysinternals" -ScoopID "psexec" -Manager $Manager
                Remove-Package -PackageID "Bun.Bun" -ChocoID "bun" -ScoopID "bun" -Manager $Manager
                Remove-Item -Path "C:\Users\$env:USERNAME\SakuraBot" -Recurse -Force -ErrorAction SilentlyContinue
            }
            2 {
                Log "Установка пакетов..." "INFO"
                Install-Package -PackageID "Microsoft.PowerShell" -ChocoID "powershell" -ScoopID "pwsh" -Url "https://github.com/PowerShell/PowerShell/releases/download/v7.4.5/PowerShell-7.4.5-win-x64.msi" -InstallCommand "Start-Process msiexec.exe -ArgumentList '/i $TempFile /quiet /norestart' -Wait" -Manager $Manager
                Install-Package -PackageID "Microsoft.WindowsTerminal" -ChocoID "windows-terminal" -ScoopID "windows-terminal" -Url "https://github.com/microsoft/terminal/releases/download/v1.21.2361.0/Microsoft.WindowsTerminal_1.21.2361.0_x64.msix" -InstallCommand "Add-AppxPackage -Path $TempFile" -Manager $Manager
                Install-Package -PackageID "JanDeDobbeleer.OhMyPosh" -ChocoID "oh-my-posh" -ScoopID "oh-my-posh" -Url "https://github.com/JanDeDobbeleer/oh-my-posh/releases/download/v23.12.2/install-amd64.exe" -InstallCommand "Start-Process $TempFile -ArgumentList '/S' -Wait" -Manager $Manager
                if (-not (Get-Command fastfetch -ErrorAction SilentlyContinue)) {
                    Install-Package -PackageID "Fastfetch-cli.Fastfetch" -ChocoID "fastfetch" -ScoopID "fastfetch" -Url "https://github.com/fastfetch-cli/fastfetch/releases/download/2.20.0/fastfetch-2.20.0-Win64.zip" -InstallCommand "Expand-Archive -Path $TempFile -DestinationPath 'C:\Program Files\Fastfetch'; [Environment]::SetEnvironmentVariable('Path', [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';C:\Program Files\Fastfetch', 'Machine')" -Manager $Manager
                }
                Install-Package -PackageID "Git.Git" -ChocoID "git" -ScoopID "git" -Url "https://github.com/git-for-windows/git/releases/download/v2.46.0.windows.1/Git-2.46.0-64-bit.exe" -InstallCommand "Start-Process $TempFile -ArgumentList '/SILENT /NORESTART' -Wait" -Manager $Manager
                Install-Package -PackageID "Microsoft.VisualStudioCode" -ChocoID "vscode" -ScoopID "vscode" -Url "https://update.code.visualstudio.com/latest/win32-x64-user/stable" -InstallCommand "Start-Process $TempFile -ArgumentList '/SILENT /NORESTART /MERGETASKS=!runcode' -Wait" -Manager $Manager
                Install-Package -PackageID "Microsoft.VCRedist.2015+.x64" -ChocoID "vcredist2015" -ScoopID "vcredist2015" -Url "https://aka.ms/vs/17/release/vc_redist.x64.exe" -InstallCommand "Start-Process $TempFile -ArgumentList '/install /quiet /norestart' -Wait" -Manager $Manager
                Install-Package -PackageID "Sysinternals.PsExec" -ChocoID "sysinternals" -ScoopID "psexec" -Url "https://download.sysinternals.com/files/PSTools.zip" -InstallCommand "Expand-Archive -Path $TempFile -DestinationPath 'C:\Program Files\Sysinternals'; [Environment]::SetEnvironmentVariable('Path', [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';C:\Program Files\Sysinternals', 'Machine')" -Manager $Manager
                Install-SakuraBot -Manager $Manager
            }
            3 { Install-NerdFonts }
            4 { Set-WT-Config }
            5 {
                Write-Host "Выберите профиль (1 - roswell-v1, 2 - roswell-v2):" -ForegroundColor Cyan
                $ProfileChoice = Read-Host "Ваш выбор (1 или 2)"
                Install-Profile -Version $(if ($ProfileChoice -eq "1") { "v1" } else { "v2" })
            }
            6 {
                if (-not (Get-Command fastfetch -ErrorAction SilentlyContinue)) {
                    Install-Package -PackageID "Fastfetch-cli.Fastfetch" -ChocoID "fastfetch" -ScoopID "fastfetch" -Url "https://github.com/fastfetch-cli/fastfetch/releases/download/2.20.0/fastfetch-2.20.0-Win64.zip" -InstallCommand "Expand-Archive -Path $TempFile -DestinationPath 'C:\Program Files\Fastfetch'; [Environment]::SetEnvironmentVariable('Path', [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';C:\Program Files\Fastfetch', 'Machine')" -Manager $Manager
                }
            }
            7 { Set-WT-Config }
            default { Log "Неверный выбор: $action" "WARN" }
        }
    }
    return $true
}

# Обновление
function Update-Profile {
    Log "Проверка обновлений..." "INFO"
    $UpdateDir = Join-Path $env:TEMP "RoswellUpdate"
    New-Item -Path $UpdateDir -ItemType Directory -Force | Out-Null
    $ScriptUrl = "https://raw.githubusercontent.com/Almazmsi/RoswellUltimate/main/roswell-ultimate.ps1"
    $V1Url = "https://raw.githubusercontent.com/Almazmsi/RoswellUltimate/main/roswell-v1.ps1"
    $V2Url = "https://raw.githubusercontent.com/Almazmsi/RoswellUltimate/main/roswell-v2.ps1"
    
    # Проверка инсталлера
    try {
        $RemoteScript = Invoke-WebRequest -Uri $ScriptUrl -UseBasicParsing
        $RemoteVersionMatch = $RemoteScript.Content | Select-String '\$Version = "([\d.]+)"'
        $RemoteVersion = if ($RemoteVersionMatch) { $RemoteVersionMatch.Matches.Groups[1].Value } else { "0.0.0" }
        if ($RemoteVersion -gt $Version) {
            Log "Найдено обновление инсталлера: v$RemoteVersion" "INFO"
            Set-Content -Path "$UpdateDir\roswell-ultimate.ps1" -Value $RemoteScript.Content -Encoding UTF8
        } else {
            Log "Инсталлер на последней версии (v$Version)" "OK"
        }
    }
    catch {
        Log "Ошибка проверки инсталлера: $($_.Exception.Message)" "ERR"
    }

    # Проверка профилей
    Write-Host "Выберите профиль для проверки (1 - roswell-v1, 2 - roswell-v2):" -ForegroundColor Cyan
    $ProfileChoice = Read-Host "Ваш выбор (1 или 2)"
    $ProfileUrl = if ($ProfileChoice -eq "1") { $V1Url } else { $V2Url }
    $ProfileVersion = if ($ProfileChoice -eq "1") { "1.0.0" } else { "2.0.0" }
    $ProfileFile = if ($ProfileChoice -eq "1") { "roswell-v1.ps1" } else { "roswell-v2.ps1" }
    try {
        $RemoteProfile = Invoke-WebRequest -Uri $ProfileUrl -UseBasicParsing
        $RemoteVersionMatch = $RemoteProfile.Content | Select-String '\$Version = "([\d.]+)"'
        $RemoteVersion = if ($RemoteVersionMatch) { $RemoteVersionMatch.Matches.Groups[1].Value } else { "0.0.0" }
        if ($RemoteVersion -gt $ProfileVersion) {
            Log "Найдено обновление профиля: v$RemoteVersion" "INFO"
            Set-Content -Path "$UpdateDir\$ProfileFile" -Value $RemoteProfile.Content -Encoding UTF8
        } else {
            Log "Профиль на последней версии" "OK"
        }
    }
    catch {
        Log "Ошибка проверки профиля: $($_.Exception.Message)" "ERR"
    }

    $Instructions = @"
Обновления скачаны в $UpdateDir
1. Замените roswell-ultimate.ps1 для обновления инсталлера.
2. Замените $ProfilePath на roswell-v1.ps1 или roswell-v2.ps1 для обновления профиля.
Запустить автозамену? (y/n):
"@
    Set-Content -Path "$UpdateDir\INSTRUCTIONS.txt" -Value $Instructions -Encoding UTF8
    Write-Host $Instructions -ForegroundColor Cyan
    $AutoReplace = Read-Host
    if ($AutoReplace -eq "y") {
        if (Test-Path "$UpdateDir\roswell-ultimate.ps1") {
            Copy-Item -Path "$UpdateDir\roswell-ultimate.ps1" -Destination $PSCommandPath -Force
            Log "Инсталлер обновлён" "OK"
        }
        if (Test-Path "$UpdateDir\$ProfileFile") {
            Install-Profile -Version $(if ($ProfileChoice -eq "1") { "v1" } else { "v2" })
        }
    }
}

# Очистка
function Cleanup-All {
    $Manager = Select-PackageManager
    Log "Запускаю очистку..." "INFO"
    Remove-Package -PackageID "Microsoft.PowerShell" -ChocoID "powershell" -ScoopID "pwsh" -Manager $Manager
    Remove-Package -PackageID "Microsoft.WindowsTerminal" -ChocoID "windows-terminal" -ScoopID "windows-terminal" -Manager $Manager
    Remove-Package -PackageID "JanDeDobbeleer.OhMyPosh" -ChocoID "oh-my-posh" -ScoopID "oh-my-posh" -Manager $Manager
    Remove-Package -PackageID "Fastfetch-cli.Fastfetch" -ChocoID "fastfetch" -ScoopID "fastfetch" -Manager $Manager
    Remove-Package -PackageID "Git.Git" -ChocoID "git" -ScoopID "git" -Manager $Manager
    Remove-Package -PackageID "Microsoft.VisualStudioCode" -ChocoID "vscode" -ScoopID "vscode" -Manager $Manager
    Remove-Package -PackageID "Microsoft.VCRedist.2015+.x64" -ChocoID "vcredist2015" -ScoopID "vcredist2015" -Manager $Manager
    Remove-Package -PackageID "Sysinternals.PsExec" -ChocoID "sysinternals" -ScoopID "psexec" -Manager $Manager
    Remove-Package -PackageID "Bun.Bun" -ChocoID "bun" -ScoopID "bun" -Manager $Manager
    Remove-Item -Path "C:\Users\$env:USERNAME\SakuraBot" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "C:\Users\$env:USERNAME\RoswellPortable" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $ProfilePath -Force -ErrorAction SilentlyContinue
    Log "Все пакеты и профиль удалены" "OK"
    if (Ask-YesNo "Создать откат системы? (y/n)") {
        try {
            Enable-ComputerRestore -Drive "C:" -ErrorAction SilentlyContinue
            Checkpoint-Computer -Description "Roswell Ultimate Cleanup v2.0.0" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
            Log "Точка восстановления создана" "OK"
        }
        catch {
            Log "Ошибка создания точки восстановления: $($_.Exception.Message)" "ERR"
        }
    }
}

# Портативный режим
function Install-Portable {
    Log "Установка портативного режима..." "INFO"
    $PortableDir = "C:\Users\$env:USERNAME\RoswellPortable"
    New-Item -Path $PortableDir -ItemType Directory -Force | Out-Null
    Copy-Item -Path $PSCommandPath -Destination "$PortableDir\roswell-ultimate.ps1"
    Copy-Item -Path "C:\Users\$env:USERNAME\SakuraBot" -Destination "$PortableDir\SakuraBot" -Recurse -Force -ErrorAction SilentlyContinue
    Install-Profile -Version "v2"
    Copy-Item -Path $ProfilePath -Destination "$PortableDir\profile.ps1"
    Log "Портативная версия установлена в $PortableDir" "OK"
    $Shell = New-Object -ComObject WScript.Shell
    $Shortcut = $Shell.CreateShortcut("C:\Users\$env:USERNAME\Desktop\RoswellPortable.lnk")
    $Shortcut.TargetPath = "pwsh.exe"
    $Shortcut.Arguments = "-File $PortableDir\roswell-ultimate.ps1"
    $Shortcut.Save()
    Log "Ярлык создан на рабочем столе" "OK"
}

# Главное меню
function Show-New-Menu {
    Show-Logo
    Write-Host "🌸🌸🌸 Roswell Ultimate v2.0.0🌸🌸🌸" -ForegroundColor Magenta
    Write-Host "Выбери судьбу:" -ForegroundColor Cyan
    Write-Host "1. Первая установка (без портативного режима)" -ForegroundColor Green
    Write-Host "2. Обновление — проверяем есть ли обновление V1 и V2 профиля" -ForegroundColor Green
    Write-Host "3. Очистка — сносим всё и откатываем систему" -ForegroundColor Green
    Write-Host "4. Портативный вариант" -ForegroundColor Green
    Write-Host "0. Выход" -ForegroundColor Yellow
    $choice = Read-Host "Ваш выбор (1-4 или 0)"
    return $choice
}

# Основной запуск
function Main {
    Ensure-Admin
    if (-not (Ensure-PowerShell7)) {
        Write-Host "Не удалось установить PowerShell 7. Завершаю работу." -ForegroundColor Red
        exit 1
    }
    $choice = Show-New-Menu
    switch ($choice) {
        "1" {
            Log "Запускаю первую установку..." "INFO"
            Process-Menu
        }
        "2" {
            Log "Запускаю обновление..." "INFO"
            Update-Profile
        }
        "3" {
            Log "Запускаю очистку..." "INFO"
            Cleanup-All
        }
        "4" {
            Log "Запускаю портативную установку..." "INFO"
            Install-Portable
        }
        "0" {
            Log "Выход" "INFO"
            exit 0
        }
        default {
            Log "Неверный выбор: $choice" "WARN"
            exit 1
        }
    }
    $ScriptEnd = Get-Date
    $Duration = ($ScriptEnd - $ScriptStart).TotalSeconds
    Log "Скрипт завершён за $Duration секунд" "OK"
}

# Запуск
Main
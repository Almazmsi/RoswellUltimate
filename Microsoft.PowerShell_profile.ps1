# ====================================================
# Roswell Ultimate 1.0.0 — PowerShell profile (auto-generated)
# ====================================================

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "Roswell Ultimate требует PowerShell 7 или выше. Запустите 'pwsh' для корректной работы." -ForegroundColor Red
    return
}

$PSDefaultParameterValues['Out-Default:Verbose'] = $false
$Version = "1.0.0"

# -- Oh My Posh init (if installed) --
try {
    oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\paradox.omp.json" | Invoke-Expression
}
catch { }

# -- posh-git --
try { Import-Module posh-git -ErrorAction SilentlyContinue }
catch { }

# -- PSReadLine --
try { Set-PSReadlineOption -PredictionSource History }
catch {}

# === Aliases & Escalation helpers ===
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
    Write-Host "Запуск текущего скрипта как SYSTEM... (создаётся временная Scheduled Task)" -ForegroundColor Yellow
    $taskName = "Roswell_RunAsSystem_$([guid]::NewGuid().ToString())"
    try {
        $time = (Get-Date).AddSeconds(30).ToString("HH:mm")
        schtasks /Create /SC ONCE /TN $taskName /TR "powershell -NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Definition)`"" /ST $time /RL HIGHEST /F /RU "SYSTEM" | Out-Null
        schtasks /Run /TN $taskName | Out-Null
        Start-Sleep -Seconds 3
        schtasks /Delete /TN $taskName /F | Out-Null
        Write-Host "Задача ${taskName} запущена и удалена" -ForegroundColor Green
    }
    catch {
        Write-Host "Не удалось запустить как SYSTEM: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function trusteduac {
    Write-Host "Попытка запуска как TrustedInstaller (best-effort)..." -ForegroundColor Yellow
    try {
        if (Get-Command psexec -ErrorAction SilentlyContinue) {
            & psexec -s -accepteula powershell -NoProfile -ExecutionPolicy Bypass -File $MyInvocation.MyCommand.Definition
            Write-Host "Запущено через psexec -s" -ForegroundColor Green
            return
        }
        systemuac
        Write-Host "Запуск через SYSTEM завершён. Для TrustedInstaller используйте psexec или PowerRun." -ForegroundColor Yellow
    }
    catch {
        Write-Host "Ошибка при попытке запуска TrustedInstaller: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function update-profile {
    try {
        $url = "https://raw.githubusercontent.com/Almazmsi/RoswellUltimate/refs/heads/main/Microsoft.PowerShell_profile.ps1"
        $lastCheck = "$env:USERPROFILE\.roswell_last_update"
        if (-not (Test-Path $lastCheck) -or ((Get-Date) - (Get-Item $lastCheck).LastWriteTime).TotalDays -gt 1) {
            $newProfile = Invoke-WebRequest -Uri $url -UseBasicParsing | Select-Object -ExpandProperty Content
            if ($newProfile -match '\$Version\s*=\s*"([\d\.]+)"') {
                $newVersion = $matches[1]
                if ([version]$newVersion -gt [version]$Version) {
                    Write-Host "Обнаружена новая версия $newVersion. Обновляем..." -ForegroundColor Green
                    $newProfile | Set-Content -Path $PROFILE -Encoding UTF8
                    . $PROFILE
                    Set-Content -Path $lastCheck -Value (Get-Date).ToString()
                }
                else {
                    Write-Host "Профиль уже актуален (версия $Version)" -ForegroundColor Cyan
                    Set-Content -Path $lastCheck -Value (Get-Date).ToString()
                }
            }
            else {
                Write-Host "Не удалось определить версию в новом профиле" -ForegroundColor Red
            }
        }
    }
    catch {
        Write-Host "Ошибка обновления профиля: $($_.Exception.Message)" -ForegroundColor Red
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
        Write-Host "Fastfetch не доступен. Убедитесь, что он установлен (winget install Fastfetch-cli.Fastfetch)" -ForegroundColor Red
    }
}

# === HUD: CPU / RAM / Disks / GPU bars with animation ===
function Get-GradientBar {
    param([int]$percent, [string]$label, [switch]$animate)
    try {
        if ($Host.UI.RawUI -and $Host.UI.RawUI.WindowSize.Width -gt 0) {
            $blocks = [math]::Max(10, [math]::Floor($Host.UI.RawUI.WindowSize.Width / 4))
        }
        else {
            $blocks = 20
        }
    }
    catch { $blocks = 20 }
    $filled = [math]::Round($percent / 100 * $blocks)
    $bar = ""
    $symbols = @("▏", "▎", "▍", "▌", "▋", "▊", "▉", "█")
    for ($i = 0; $i -lt $blocks; $i++) {
        if ($i -lt $filled) {
            $color = switch ($percent) {
                { $_ -lt 30 } { 34 }
                { $_ -lt 50 } { 46 }
                { $_ -lt 80 } { 226 }
                default { 196 }
            }
            if ($animate -and $i -eq ($filled - 1)) {
                $index = ([math]::Floor((Get-Date).Millisecond / 125) % 8)
                $bar += "`e[38;5;${color}m$($symbols[$index])`e[0m"
            }
            else {
                $bar += "`e[38;5;${color}m█`e[0m"
            }
        }
        else {
            $bar += " "
        }
    }
    return "${label}: $bar $percent%"
}

function Get-SystemBars {
    try { $cpu = [math]::Round((Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples[0].CookedValue) }
    catch { $cpu = 0 }
    $cpuBar = Get-GradientBar -percent $cpu -label "💻 CPU" -animate
    try {
        $mem = [math]::Round((Get-CimInstance Win32_OperatingSystem | ForEach-Object {
            ($_.TotalVisibleMemorySize - $_.FreePhysicalMemory) / $_.TotalVisibleMemorySize * 100
        }))
    }
    catch { $mem = 0 }
    $memBar = Get-GradientBar -percent $mem -label "🧠 RAM" -animate
    $diskBars = ""
    try {
        Get-PSDrive -PSProvider FileSystem | ForEach-Object {
            if ($_.Used -and $_.Free) {
                $diskPercent = [math]::Round(($_.Used / ($_.Used + $_.Free)) * 100)
                $diskBars += "`n" + (Get-GradientBar -percent $diskPercent -label "💿 $($_.Name)" -animate)
            }
        }
    }
    catch { $diskBars = "`n💿 Disks: N/A" }
    return "$cpuBar  $memBar$diskBars"
}

function Start-LiveHUD {
    try {
        $global:HUDTimer = New-Object System.Timers.Timer
        $global:HUDTimer.Interval = 1000
        $global:HUDTimer.AutoReset = $true
        Register-ObjectEvent -InputObject $global:HUDTimer -EventName Elapsed -Action {
            try {
                $cursor = $host.UI.RawUI.CursorPosition
                $bottom = $host.UI.RawUI.WindowSize.Height - 5
                $host.UI.RawUI.CursorPosition = @{ X = 0; Y = $bottom }
                Write-Host (' ' * ($host.UI.RawUI.WindowSize.Width)) -NoNewline
                $sysBars = Get-SystemBars
                Write-Host "$sysBars" -NoNewline
                $host.UI.RawUI.CursorPosition = $cursor
            }
            catch { }
        } | Out-Null
        $global:HUDTimer.Start()
        Register-EngineEvent PowerShell.Exiting -Action {
            if ($global:HUDTimer) {
                $global:HUDTimer.Stop()
                $global:HUDTimer.Dispose()
            }
        } -SupportEvent
    }
    catch { }
}

# === Prompt ===
function prompt {
    $time = Get-Date -Format "HH:mm:ss"
    $who = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).Name
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $flag = if ($isAdmin) { "⚡" } else { "" }
    $branch = ""
    try { $branch = (git rev-parse --abbrev-ref HEAD 2>$null).Trim() }
    catch { }
    $gitPart = if ($branch) { "  $branch" } else { "" }
    "$flag [$time]$gitPart `n📂 $(Get-Location)> "
}

# === Startup Animation ===
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

# === Startup Logic ===
$flagFile = "$env:USERPROFILE\.roswell_first_run"
$disableFile = "$env:USERPROFILE\.roswell_disable_startup"
$animationFile = "$env:USERPROFILE\.roswell_animation_enabled"
$author = "Автор: github.com/Almazmsi"
$repo = "Репозитория: github.com/Almazmsi/RoswellUltimate"

function enable-roswell-animation {
    Set-Content -Path $animationFile -Value "enabled"
    Write-Host "Анимация включена для следующего запуска" -ForegroundColor Yellow
}

function disable-roswell-startup {
    Set-Content -Path $disableFile -Value "disabled"
    Write-Host "Стартовый вывод отключён. Чтобы включить, удалите файл $disableFile" -ForegroundColor Yellow
}

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
            Write-Host "Анимация отключена: требуется PowerShell 7 для поддержки UTF-8 и ANSI" -ForegroundColor Red
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
        Write-Host "Fastfetch не доступен. Убедитесь, что он установлен (winget install Fastfetch-cli.Fastfetch)" -ForegroundColor Red
    }
    Write-Host "Roswell Ultimate 1.0.0 loaded! 🚀" -ForegroundColor Green
    Start-LiveHUD
    Write-Host "`nRoswell Ultimate profile loaded (1.0.0)"
}
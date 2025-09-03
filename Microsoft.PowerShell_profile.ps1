# ====================================================
# Roswell Ultimate 1.0.0 — PowerShell profile (auto-generated)
# ====================================================

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "Roswell Ultimate требует PowerShell 7 или выше. Запустите 'pwsh' для корректной работы." -ForegroundColor Red
    return
}

$PSDefaultParameterValues['Out-Default:Verbose'] = $false
$Version = "1.0.0"
$LogFile = Join-Path $env:USERPROFILE "roswell-ultimate-1.0.log"

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
        $tool = $null
        if (Get-Command psexec -ErrorAction SilentlyContinue) {
            $tool = "psexec"
            Log "Найден PsExec, использую его для TrustedInstaller" "INFO"
            & psexec -s -accepteula pwsh -NoProfile -ExecutionPolicy Bypass -File $ScriptPath
            Log "Запуск через PsExec завершён" "OK"
            return
        }
        elseif (Get-Command PowerRun -ErrorAction SilentlyContinue) {
            $tool = "PowerRun"
            Log "Найден PowerRun, использую его для TrustedInstaller" "INFO"
            & PowerRun /SW:0 pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $ScriptPath
            Log "Запуск через PowerRun завершён" "OK"
            return
        }
        else {
            Log "PsExec или PowerRun не найдены, пробую запуск как SYSTEM" "WARN"
            systemuac -ScriptPath $ScriptPath
            Log "Запуск через SYSTEM завершён. Для TrustedInstaller установите PsExec или PowerRun." "WARN"
        }
    }
    catch {
        Log "Ошибка запуска TrustedInstaller: $($_.Exception.Message)" "ERR"
        throw
    }
}

function elevate {
    param(
        [Parameter(ParameterSetName="Admin")]
        [switch]$AsAdmin,
        [Parameter(ParameterSetName="System")]
        [switch]$AsSystem,
        [Parameter(ParameterSetName="TrustedInstaller")]
        [switch]$AsTrustedInstaller,
        [string]$ScriptPath = $MyInvocation.MyCommand.Definition
    )
    Log "Запуск elevate для '$ScriptPath'..." "INFO"
    $currentRole = get-user-role
    Log "Текущая роль: $currentRole" "INFO"
    
    if ($AsAdmin) {
        Log "Запрашиваю права администратора..." "INFO"
        try {
            $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
            if ($isAdmin) {
                Log "Уже администратор, запуск не требуется" "OK"
                return
            }
            Log "Запускаю PowerShell с UAC..." "INFO"
            Start-Process -FilePath "pwsh.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`"" -Verb RunAs
            Log "Запрос UAC отправлен, проверьте окно" "OK"
        }
        catch {
            Log "Ошибка при запросе админ-прав: $($_.Exception.Message)" "ERR"
            throw
        }
    }
    elseif ($AsSystem) {
        Log "Передаю управление в функцию systemuac..." "INFO"
        systemuac -ScriptPath $ScriptPath
    }
    elseif ($AsTrustedInstaller) {
        Log "Передаю управление в функцию trusteduac..." "INFO"
        trusteduac -ScriptPath $ScriptPath
    }
    else {
        Log "Не указан режим повышения прав. Используйте -AsAdmin, -AsSystem или -AsTrustedInstaller" "ERR"
        throw "Не указан режим повышения прав"
    }
}

function update-profile {
    try {
        $url = "https://raw.githubusercontent.com/Almazmsi/RoswellUltimate/main/Microsoft.PowerShell_profile.ps1"
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

# === HUD: CPU / RAM / Disks / GPU bars with animation (manual trigger) ===
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
        Log "Live HUD запущен" "OK"
    }
    catch {
        Log "Ошибка запуска Live HUD: $($_.Exception.Message)" "ERR"
    }
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
# ============================================================
# Roswell Ultimate — MEGA installer (big, verbose, sexy, with animations and extended HUD)
# - проверка прав, точка восстановления (с подтверждением)
# - winget (fallback -> choco), установка приложений (PowerShell 7, fastfetch, neofetch)
# - установка Nerd Fonts (FiraCode)
# - включение прозрачности Windows Terminal (backup config)
# - создание богатого профиля PowerShell: HUD с анимацией, fastfetch/neofetch, алиасы
# - алиасы: whoami, systemuac, trusteduac, update-profile, sysinfo
# - расширенный HUD: CPU, RAM, диски, GPU
# - стартовая анимация с ASCII-арт
# - интерактивное меню с fastfetch и настройкой Terminal
# - улучшенное логирование (ISO 8601, без ANSI в файле)
# ============================================================

# =============== CONFIG ===============
$ScriptStart = Get-Date
$LogFile = Join-Path $env:USERPROFILE "roswell-ultimate-5.1.log"
$ProfileBackupDir = Join-Path $env:USERPROFILE "roswell-backups"
$ProfilePath = $PROFILE
$WTSettingsPaths = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
)
$ProfileUpdateURL = "https://raw.githubusercontent.com/almazmsi/RoswellUltimate/main/profile.ps1"
$Version = "5.1.2"

# ensure log dir exists
if (-not (Test-Path (Split-Path $LogFile))) { New-Item -ItemType Directory -Path (Split-Path $LogFile) -Force | Out-Null }
if (-not (Test-Path $ProfileBackupDir)) { New-Item -ItemType Directory -Path $ProfileBackupDir -Force | Out-Null }

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
    Add-Content -Path $LogFile -Value $line.Replace("`e[", "").Replace("`e[0m", "")
}

# --------------------------- 
# 0) Interactive Menu for Actions
# ---------------------------
function Show-Menu {
    Write-Host "Добро пожаловать в Roswell Ultimate Installer!" -ForegroundColor Magenta
    Write-Host "Выберите действия (можно несколько, через запятую, или 'all' для всех):"
    Write-Host "1. Очистка предыдущих установок"
    Write-Host "2. Установка пакетов (PowerShell, Terminal, fastfetch, etc.)"
    Write-Host "3. Установка Nerd Fonts (FiraCode)"
    Write-Host "4. Настройка прозрачности Windows Terminal"
    Write-Host "5. Установка/обновление профиля PowerShell"
    Write-Host "6. Установка fastfetch"
    Write-Host "7. Настройка Windows Terminal по умолчанию на PowerShell"
    Write-Host "0. Выход"
    $choice = Read-Host "Ваш выбор (например, 1,3,5 или all)"
    return $choice
}

$menuChoice = Show-Menu
if ($menuChoice -eq "0") { Log "Пользователь выбрал выход" "INFO"; Exit 0 }
$actions = if ($menuChoice -eq "all") { 1..7 } else { $menuChoice -split "," | ForEach-Object { [int]$_ } }

# --------------------------- 
# 1) Ensure run as Administrator (UAC restart if needed)
# ---------------------------
function Ensure-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Log "Нет прав администратора — перезапускаю через UAC..." "WARN"
        $arg = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" 
        Start-Process -FilePath "powershell.exe" -ArgumentList $arg -Verb RunAs
        exit 0
    } else {
        Log "Запуск с правами администратора" "OK"
    }
}
Ensure-Admin

# --------------------------- 
# 2) Create restore point (with confirmation)
# ---------------------------
function Ask-YesNo($msg) {
    do {
        $r = Read-Host "$msg (y/n)"
    } while ($r -notmatch '^[yYnN]$')
    return $r -match '^[yY]$'
}

if ($actions -contains 2 -or $actions -contains 1) {
    if (Ask-YesNo "Создать точку восстановления системы? (Рекомендуется для безопасности)") {
        function Create-RestorePoint {
            try {
                Enable-ComputerRestore -Drive "C:" -ErrorAction SilentlyContinue
                Checkpoint-Computer -Description "Before Roswell Ultimate" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
                Log "Точка восстановления создана" "OK"
            } catch {
                Log "Не удалось создать точку восстановления: $($_.Exception.Message)" "WARN"
            }
        }
        Create-RestorePoint
    } else {
        Log "Пользователь отказался от создания точки восстановления" "INFO"
    }
}

# --------------------------- 
# 3) Cleanup previous installs and profiles (if selected)
# ---------------------------
if ($actions -contains 1) {
    Log "Запускаю чистку предыдущих установок..." "INFO"
    if (Ask-YesNo "Удалять старые установки (winget apps, шрифты, профиль)?") {
        $appsToRemove = @("Microsoft.PowerShell","Microsoft.WindowsTerminal","JanDeDobbeleer.OhMyPosh","nepnep.neofetch-win","Fastfetch-cli.Fastfetch")
        foreach ($app in $appsToRemove) {
            try {
                $installed = $null
                try { $installed = winget list --id $app -q 2>$null } catch {}
                if ($installed) {
                    Log "Удаляю ${app}..." "INFO"
                    try { winget uninstall --id ${app} -e --silent | Out-Null; Log "Удалён ${app}" "OK" } catch { Log "Не удалось удалить ${app}: $($_.Exception.Message)" "WARN" }
                } else { Log "Не обнаружен ${app}, пропускаю" "INFO" }
            } catch { Log "Ошибка при обработке удаления ${app}: $($_.Exception.Message)" "WARN" }
        }
        try {
            $fontDir = "$env:WINDIR\Fonts"
            $fira = Get-ChildItem -Path $fontDir -Filter "*FiraCode*.ttf" -ErrorAction SilentlyContinue
            if ($fira) {
                foreach ($f in $fira) {
                    try { Remove-Item -Path $f.FullName -Force -ErrorAction Stop; Log "Удалён шрифт ${($f.Name)}" "OK" } catch { Log "Не удалось удалить шрифт ${($f.Name)}: $($_.Exception.Message)" "WARN" }
                }
            } else { Log "Старые FiraCode шрифты не найдены" "INFO" }
        } catch { Log "Ошибка удаления шрифтов: $($_.Exception.Message)" "WARN" }
        try {
            if (Test-Path $PROFILE) {
                $bak = Join-Path $ProfileBackupDir ("Microsoft.PowerShell_profile.ps1.bak." + (Get-Date -Format "yyyyMMddHHmmss"))
                Copy-Item -Path $PROFILE -Destination $bak -Force -ErrorAction SilentlyContinue
                Remove-Item -Path $PROFILE -Force -ErrorAction SilentlyContinue
                Log "Старый профиль забэкаплен в ${bak} и удалён" "OK"
            } else {
                Log "Профиль не найден — пропускаем" "INFO"
            }
        } catch { Log "Ошибка при обработке профиля: $($_.Exception.Message)" "WARN" }
    } else {
        Log "Пользователь отменил удаление старых установок" "INFO"
    }
}

# --------------------------- 
# 4) Ensure winget or fallbacks (choco)
# ---------------------------
function Ensure-Winget-Or-Choco {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Log "winget доступен" "OK"
        return "winget"
    }
    Log "winget не найден — попробую установить Microsoft App Installer (MSIX)" "WARN"
    try {
        $msix = Join-Path $env:TEMP "Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
        Invoke-WebRequest -Uri "https://aka.ms/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" -OutFile $msix -UseBasicParsing -ErrorAction Stop
        Add-AppxPackage -Path $msix -ErrorAction Stop
        Start-Sleep -Seconds 2
    } catch {
        Log "Не удалось поставить MSIX App Installer: $($_.Exception.Message)" "WARN"
    }
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Log "winget успешно установлен через MSIX" "OK"
        return "winget"
    }
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Log "choco найден" "OK"
        return "choco"
    }
    Log "choco не найден — попытаюсь установить choco (bootstrap)" "INFO"
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        $chocoScript = 'https://community.chocolatey.org/install.ps1'
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString($chocoScript))
        Start-Sleep -Seconds 2
    } catch {
        Log "Не удалось установить choco автоматически: $($_.Exception.Message)" "ERR"
    }
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Log "choco успешно установлен" "OK"
        return "choco"
    }
    Log "Ни winget, ни choco не доступны. Скрипт не может продолжить автоматическую установку." "ERR"
    throw "Нет инструмента установки пакетов"
}

$pkgManager = Ensure-Winget-Or-Choco

# --------------------------- 
# 5) Install common apps (if selected)
# ---------------------------
if ($actions -contains 2) {
    function Install-Package-By-Manager {
        param([string]$pkgId, [string]$chocoName = $null)
        if ($pkgManager -eq "winget") {
            try {
                Log "winget: устанавливаю ${pkgId}..." "INFO"
                winget install --id $pkgId -e --silent --accept-source-agreements --accept-package-agreements | Out-Null
                Log "winget: ${pkgId} установлен (или уже был)" "OK"
                $cmdName = ($pkgId -split "\.")[-1].ToLower()
                if ($cmdName -eq "fastfetch" -or $cmdName -eq "neofetch") {
                    if (Get-Command $cmdName -ErrorAction SilentlyContinue) {
                        Log "$cmdName доступен в PATH" "OK"
                    } else {
                        Log "$cmdName не найден в PATH. Проверяю..." "WARN"
                        $possiblePaths = @(
                            "C:\Program Files\Fastfetch\fastfetch.exe",
                            "C:\ProgramData\chocolatey\bin\$cmdName.exe",
                            "C:\Program Files\$cmdName\$cmdName.exe"
                        )
                        foreach ($path in $possiblePaths) {
                            if (Test-Path $path) {
                                $env:Path += ";$(Split-Path $path)"
                                Log "$cmdName добавлен в PATH из $path" "OK"
                                break
                            }
                        }
                        if (-not (Get-Command $cmdName -ErrorAction SilentlyContinue)) {
                            Log "$cmdName не установлен или не найден" "ERR"
                        }
                    }
                }
                return
            } catch {
                Log "winget не смог установить ${pkgId}: $($_.Exception.Message)" "WARN"
            }
        }
        if ($pkgManager -eq "choco") {
            if (-not $chocoName) { $chocoName = $pkgId }
            try {
                Log "choco: устанавливаю ${chocoName}..." "INFO"
                choco install $chocoName -y --no-progress | Out-Null
                Log "choco: ${chocoName} установлен (или уже был)" "OK"
                return
            } catch {
                Log "choco не смог установить ${chocoName}: $($_.Exception.Message)" "WARN"
            }
        }
        Log "Не удалось установить ${pkgId} через доступный менеджер" "ERR"
    }
    $DesiredPackages = @(
        @{ id="Microsoft.PowerShell"; choco="powershell-core" },
        @{ id="Microsoft.WindowsTerminal"; choco="microsoft-windows-terminal" },
        @{ id="JanDeDobbeleer.OhMyPosh"; choco="oh-my-posh" },
        @{ id="nepnep.neofetch-win"; choco="neofetch" },
        @{ id="Fastfetch-cli.Fastfetch"; choco="fastfetch" },
        @{ id="Git.Git"; choco="git" }
    )
    foreach ($p in $DesiredPackages) {
        Install-Package-By-Manager -pkgId $p.id -chocoName $p.choco
    }
    try {
        $pwshVer = & pwsh --version
        Log "PowerShell версия: $pwshVer" "OK"
    } catch {
        Log "PowerShell 7 не установлен или не найден: $($_.Exception.Message)" "ERR"
    }
}

# --------------------------- 
# 6) Install fastfetch (if selected)
# ---------------------------
if ($actions -contains 6) {
    Install-Package-By-Manager -pkgId "Fastfetch-cli.Fastfetch" -chocoName "fastfetch"
}

# --------------------------- 
# 7) Install Nerd Fonts (FiraCode) (if selected)
# ---------------------------
if ($actions -contains 3) {
    function Install-NerdFonts-FiraCode {
        try {
            $zip = Join-Path $env:TEMP "FiraCode.zip"
            $url = "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/FiraCode.zip"
            Log "Скачиваю Nerd Fonts FiraCode..." "INFO"
            Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing -ErrorAction Stop
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $extract = Join-Path $env:TEMP "FiraCode"
            if (Test-Path $extract) { Remove-Item $extract -Recurse -Force -ErrorAction SilentlyContinue }
            [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $extract)
            $fontDir = "$env:WINDIR\Fonts"
            Get-ChildItem -Path $extract -Filter *.ttf | ForEach-Object {
                try { Copy-Item -Path $_.FullName -Destination $fontDir -Force; Log "Установлен шрифт $($_.Name)" "OK" } catch { Log "Ошибка копирования шрифта $($_.Name): $($_.Exception.Message)" "WARN" }
            }
        } catch {
            Log "Ошибка установки Nerd Fonts: $($_.Exception.Message)" "WARN"
        }
    }
    Install-NerdFonts-FiraCode
}

# --------------------------- 
# 8) Enable transparency in Windows Terminal (if selected)
# ---------------------------
if ($actions -contains 4) {
    function Enable-WT-Transparency {
        try {
            $settingsPath = $null
            foreach ($path in $WTSettingsPaths) {
                if (Test-Path $path) {
                    $settingsPath = $path
                    Log "Найден файл настроек Windows Terminal: $settingsPath" "INFO"
                    break
                }
            }
            if (-not $settingsPath) {
                Log "Файл настроек Windows Terminal не найден. Убедитесь, что Windows Terminal установлен." "ERR"
                return
            }
            $bak = "${settingsPath}.roswell.bak.$((Get-Date).ToString('yyyyMMddHHmmss'))"
            Copy-Item -Path $settingsPath -Destination $bak -Force
            $json = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json
            if (-not $json.profiles) { $json | Add-Member -MemberType NoteProperty -Name profiles -Value ([pscustomobject]@{}) }
            if (-not $json.profiles.defaults) { $json.profiles | Add-Member -MemberType NoteProperty -Name defaults -Value ([pscustomobject]@{}) }
            $json.profiles.defaults.useAcrylic = $true
            $json.profiles.defaults.acrylicOpacity = 0.85
            $json | ConvertTo-Json -Depth 100 | Set-Content -Path $settingsPath -Encoding UTF8
            Log "Прозрачность Windows Terminal включена (backup: ${bak})" "OK"
        } catch {
            Log "Ошибка при включении прозрачности: $($_.Exception.Message)" "ERR"
        }
    }
    Enable-WT-Transparency
}

# --------------------------- 
# 9) Configure Windows Terminal default profile (if selected)
# ---------------------------
if ($actions -contains 7) {
    function Set-WT-DefaultProfile {
        try {
            $settingsPath = $null
            foreach ($path in $WTSettingsPaths) {
                if (Test-Path $path) {
                    $settingsPath = $path
                    Log "Найден файл настроек Windows Terminal: $settingsPath" "INFO"
                    break
                }
            }
            if (-not $settingsPath) {
                Log "Файл настроек Windows Terminal не найден. Убедитесь, что Windows Terminal установлен." "ERR"
                return
            }
            $bak = "${settingsPath}.roswell.bak.$((Get-Date).ToString('yyyyMMddHHmmss'))"
            Copy-Item -Path $settingsPath -Destination $bak -Force
            $json = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json
            $json.defaultProfile = "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}" # PowerShell 7 GUID
            $json | ConvertTo-Json -Depth 100 | Set-Content -Path $settingsPath -Encoding UTF8
            Log "Windows Terminal настроен на PowerShell 7 по умолчанию (backup: ${bak})" "OK"
        } catch {
            Log "Ошибка настройки профиля по умолчанию: $($_.Exception.Message)" "WARN"
        }
    }
    Set-WT-DefaultProfile
}

# --------------------------- 
# 10) Functions for alias escalation
# ---------------------------
function Run-As-System {
    param([string]$ScriptPath = $PSCommandPath)
    $taskName = "Roswell_RunAsSystem_$([guid]::NewGuid().ToString())"
    try {
        $time = (Get-Date).AddSeconds(30).ToString("HH:mm")
        $create = schtasks /Create /SC ONCE /TN $taskName /TR "powershell -NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`"" /ST $time /RL HIGHEST /F /RU "SYSTEM"
        Log "Создана временная задача ${taskName} для запуска как SYSTEM (через schtasks)" "INFO"
        schtasks /Run /TN $taskName | Out-Null
        Start-Sleep -Seconds 3
        schtasks /Delete /TN $taskName /F | Out-Null
        Log "Задача ${taskName} запущена и удалена" "OK"
    } catch {
        Log "Не удалось запустить как SYSTEM через schtasks: $($_.Exception.Message)" "WARN"
    }
}

function Run-As-TrustedInstaller {
    param([string]$ScriptPath = $PSCommandPath)
    Log "Попытка запустить как TrustedInstaller (best-effort)..." "INFO"
    try {
        if (Get-Command psexec -ErrorAction SilentlyContinue) {
            & psexec -s -accepteula powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath
            Log "Запущено через psexec -s (если psexec доступен)" "OK"
            return
        }
        Run-As-System -ScriptPath $ScriptPath
        Log "Запуск через SYSTEM завершён. Если нужен TrustedInstaller, используйте специализированные инструменты (psexec, PowerRun и др.)" "WARN"
    } catch {
        Log "Ошибка при попытке запуска TrustedInstaller: $($_.Exception.Message)" "WARN"
    }
}

# --------------------------- 
# 11) Build the PowerShell profile content
# ---------------------------
function Get-Profile-Template {
@'
# ====================================================
# Roswell Ultimate — PowerShell profile (auto-generated)
# ====================================================

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "Roswell Ultimate требует PowerShell 7 или выше. Запустите 'pwsh' для корректной работы." -ForegroundColor Red
    return
}

$PSDefaultParameterValues['Out-Default:Verbose'] = $false
$Version = "5.1.2"

# -- Oh My Posh init (if installed) --
try {
    oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\paradox.omp.json" | Invoke-Expression
} catch { }

# -- posh-git --
try { Import-Module posh-git -ErrorAction SilentlyContinue } catch { }

# -- PSReadLine --
try { Set-PSReadlineOption -PredictionSource History } catch {}

# === Aliases & Escalation helpers ===
function whoami {
    try { [System.Security.Principal.WindowsIdentity]::GetCurrent().Name } catch { & whoami.exe }
}
function get-user-role {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($isAdmin) { "Administrator" } else { "User" }
}
function systemuac {
    Write-Host "Запуск текущего скрипта как SYSTEM... (создаётся временная Scheduled Task)" -ForegroundColor Yellow
    Run-As-System -ScriptPath $MyInvocation.MyCommand.Definition
}
function trusteduac {
    Write-Host "Попытка запуска как TrustedInstaller (best-effort)..." -ForegroundColor Yellow
    Run-As-TrustedInstaller -ScriptPath $MyInvocation.MyCommand.Definition
}
function update-profile {
    try {
        $url = "https://raw.githubusercontent.com/almazmsi/RoswellUltimate/main/profile.ps1"
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
                } else {
                    Write-Host "Профиль уже актуален (версия $Version)" -ForegroundColor Cyan
                    Set-Content -Path $lastCheck -Value (Get-Date).ToString()
                }
            } else {
                Write-Host "Не удалось определить версию в новом профиле" -ForegroundColor Red
            }
        }
    } catch {
        Write-Host "Ошибка обновления профиля: $($_.Exception.Message)" -ForegroundColor Red
    }
}
function sysinfo {
    try {
        $fastfetchPath = "C:\Program Files\Fastfetch\fastfetch.exe"
        if (Test-Path $fastfetchPath) {
            & $fastfetchPath --logo windows --color blue --structure os:kernel:cpu:memory:disk:gpu
        } else {
            fastfetch --logo windows --color blue --structure os:kernel:cpu:memory:disk:gpu
        }
    } catch {
        try { neofetch } catch { Write-Host "Fastfetch/neofetch не доступен..." }
    }
}
Set-Alias neofetch sysinfo -ErrorAction SilentlyContinue

# === HUD: CPU / RAM / Disks / GPU bars with animation ===
function Get-GradientBar {
    param([int]$percent, [string]$label, [switch]$animate)
    try {
        if ($Host.UI.RawUI -and $Host.UI.RawUI.WindowSize.Width -gt 0) {
            $blocks = [math]::Max(10, [math]::Floor($Host.UI.RawUI.WindowSize.Width / 4))
        } else {
            $blocks = 20
        }
    } catch { $blocks = 20 }
    $filled = [math]::Round($percent / 100 * $blocks)
    $bar = ""
    $symbols = @("▏", "▎", "▍", "▌", "▋", "▊", "▉", "█")
    for ($i = 0; $i -lt $blocks; $i++) {
        if ($i -lt $filled) {
            $color = switch ($percent) { { $_ -lt 30 } { 34 } { $_ -lt 50 } { 46 } { $_ -lt 80 } { 226 } default { 196 } }
            if ($animate -and $i -eq ($filled - 1)) {
                $index = ([math]::Floor((Get-Date).Millisecond / 125) % 8)
                $bar += "`e[38;5;${color}m$($symbols[$index])`e[0m"
            } else {
                $bar += "`e[38;5;${color}m█`e[0m"
            }
        } else {
            $bar += " "
        }
    }
    return "${label}: $bar $percent%"
}

function Get-SystemBars {
    try { $cpu = [math]::Round((Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples[0].CookedValue) } catch { $cpu = 0 }
    $cpuBar = Get-GradientBar -percent $cpu -label "💻 CPU" -animate
    try {
        $mem = [math]::Round((Get-CimInstance Win32_OperatingSystem | ForEach-Object {
            ($_.TotalVisibleMemorySize - $_.FreePhysicalMemory) / $_.TotalVisibleMemorySize * 100
        }))
    } catch { $mem = 0 }
    $memBar = Get-GradientBar -percent $mem -label "🧠 RAM" -animate
    $diskBars = ""
    try {
        Get-PSDrive -PSProvider FileSystem | ForEach-Object {
            if ($_.Used -and $_.Free) {
                $diskPercent = [math]::Round(($_.Used / ($_.Used + $_.Free)) * 100)
                $diskBars += "`n" + (Get-GradientBar -percent $diskPercent -label "💿 $($_.Name)" -animate)
            }
        }
    } catch { $diskBars = "`n💿 Disks: N/A" }
    return "$cpuBar  $memBar$diskBars"
}

function Start-LiveHUD {
    try {
        $global:HUDTimer = New-Object System.Timers.Timer
        $global:HUDTimer.Interval = 1000
        $global:HUDTimer.AutoReset = $true
        $global:HUDTimer.Add_Elapsed({
            try {
                $cursor = $host.UI.RawUI.CursorPosition
                $bottom = $host.UI.RawUI.WindowSize.Height - 5
                $host.UI.RawUI.CursorPosition = @{ X = 0; Y = $bottom }
                Write-Host (' ' * ($host.UI.RawUI.WindowSize.Width)) -NoNewline
                $sysBars = Get-SystemBars
                Write-Host "$sysBars" -NoNewline
                $host.UI.RawUI.CursorPosition = $cursor
            } catch { }
        })
        $global:HUDTimer.Start()
        Register-EngineEvent PowerShell.Exiting -Action { if ($global:HUDTimer) { $global:HUDTimer.Stop(); $global:HUDTimer.Dispose() } } -SupportEvent
    } catch { }
}

# === Prompt ===
function prompt {
    $time = Get-Date -Format "HH:mm:ss"
    $who = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).Name
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $flag = if ($isAdmin) { "⚡" } else { "" }
    $branch = ""
    try { $branch = (git rev-parse --abbrev-ref HEAD 2>$null).Trim() } catch { }
    $gitPart = if ($branch) { "  $branch" } else { "" }
    "$flag [$time]$gitPart `n📂 $(Get-Location)> "
}

# === Startup Animation ===
function Show-StartupAnimation {
    Write-Host "Запускаю анимацию Roswell Ultimate..." -ForegroundColor Yellow
    $text = "Loading Roswell Ultimate..."
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
        Start-Sleep -Milliseconds 100
        if ($p -lt $max) {
            [Console]::SetCursorPosition(0, [Console]::CursorTop - 1)
        }
    }
    Write-Host "Roswell Ultimate loaded! 🚀" -ForegroundColor Green
    [Console]::Beep(500, 200)
}

# === Startup Logic ===
$flagFile = "$env:USERPROFILE\.roswell_first_run"
$disableFile = "$env:USERPROFILE\.roswell_disable_startup"
$animationFile = "$env:USERPROFILE\.roswell_animation_enabled"
$author = "Автор: github.com/almazmsi"
$repo = "Репозитория: github.com/almazmsi/RoswellUltimate"

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
    Write-Host "`nRoswell Ultimate profile loaded (5.1.2)"
} else {
    Write-Host "Загружаю профиль в PowerShell $PSVersionTable.PSVersion" -ForegroundColor Yellow
    if (-not (Test-Path $flagFile) -or (Test-Path $animationFile)) {
        Show-StartupAnimation
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
        } else {
            fastfetch --logo windows --color blue --structure os:kernel:cpu:memory:disk:gpu
        }
    } catch {
        try { neofetch } catch { Write-Host "Fastfetch/neofetch не доступен..." }
    }
    Write-Host "Roswell Ultimate loaded! 🚀" -ForegroundColor Green
    Start-LiveHUD
    Write-Host "`nRoswell Ultimate profile loaded"
}
'@
}

# --------------------------- 
# 12) Install profile (if selected)
# ---------------------------
if ($actions -contains 5) {
    $installProfile = Ask-YesNo "Установить/обновить стандартный профиль Roswell Ultimate сейчас?"
    if ($installProfile) {
        try {
            $tpl = Get-Profile-Template
            $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllText($PROFILE, $tpl, $utf8NoBom)
            Log "Профиль успешно записан в $PROFILE" "OK"
            try {
                if ($PSVersionTable.PSVersion.Major -ge 7) {
                    . $PROFILE
                    Log "Профиль успешно загружен" "OK"
                } else {
                    Log "Профиль не загружен: требуется PowerShell 7 или выше" "WARN"
                }
            } catch {
                Log "Ошибка загрузки профиля: $($_.Exception.Message)" "ERR"
            }
        } catch {
            Log "Ошибка записи профиля: $($_.Exception.Message)" "ERR"
        }
    } else {
        $templatePath = Join-Path $ProfileBackupDir "roswell-profile-template.ps1"
        try {
            $tpl = Get-Profile-Template
            [System.IO.File]::WriteAllText($templatePath, $tpl, (New-Object System.Text.UTF8Encoding($false)))
            Log "Профиль не установлен. Шаблон сохранён в ${templatePath}" "WARN"
            Write-Host "Если захотите, откройте шаблон: notepad $templatePath"
        } catch {
            Log "Ошибка при сохранении шаблона: $($_.Exception.Message)" "WARN"
        }
    }
}

# --------------------------- 
# 13) Ensure Execution Policy
# ---------------------------
try {
    if ((Get-ExecutionPolicy -Scope CurrentUser) -eq "Restricted") {
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
        Log "ExecutionPolicy установлен в RemoteSigned" "OK"
    }
} catch {
    Log "Ошибка настройки ExecutionPolicy: $($_.Exception.Message)" "WARN"
}

# --------------------------- 
# 14) Ensure PowerShell 7 profile path
# ---------------------------
try {
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Log "Скрипт запущен в Windows PowerShell. Рекомендуется использовать PowerShell 7 (pwsh)." "WARN"
    }
    $ps7Profile = "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
    if ($PROFILE -ne $ps7Profile -and $actions -contains 5) {
        Log "Обновляю путь профиля для PowerShell 7: $ps7Profile" "INFO"
        $global:ProfilePath = $ps7Profile
        if (-not (Test-Path (Split-Path $ps7Profile))) {
            New-Item -ItemType Directory -Path (Split-Path $ps7Profile) -Force | Out-Null
        }
        $tpl = Get-Profile-Template
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($ps7Profile, $tpl, $utf8NoBom)
        Log "Профиль для PowerShell 7 успешно записан в $ps7Profile" "OK"
    }
} catch {
    Log "Ошибка настройки профиля PowerShell 7: $($_.Exception.Message)" "ERR"
}

# --------------------------- 
# 15) Final message and exit
# ---------------------------
$elapsed = (Get-Date) - $ScriptStart
Log "Roswell Ultimate завершён. Время: $($elapsed.ToString())" "OK"
Write-Host ""
Write-Host "🎉 Установка завершена. Запустите 'pwsh' или перезапустите Windows Terminal. Скрипт закроется через 10 секунд..." -ForegroundColor Green
Start-Sleep -Seconds 10
Exit 0
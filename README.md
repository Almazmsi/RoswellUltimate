# Roswell Ultimate

**Roswell Ultimate** — это мощный инсталлер и профиль для PowerShell, который превращает твой терминал в космический корабль с анимацией, HUD (информацией о системе) и поддержкой `fastfetch`. Это версия 1.0.0, готовая к использованию на Windows 10/11 с PowerShell 7+.

## Что это такое?

Roswell Ultimate автоматизирует настройку крутого терминала:
- **Анимация при запуске**: ASCII-арт с прогресс-баром.
- **HUD**: Показывает загрузку CPU, RAM, дисков и GPU в реальном времени.
- **Fastfetch**: Быстрый вывод системной информации (OS, ядро, CPU, память, диски, GPU).
- **Алиасы**: Удобные команды вроде `sysinfo`, `whoami`, `systemuac`, `trusteduac`, `update-profile`.
- **Прозрачность**: Настройка Windows Terminal с эффектом акрила.
- **Шрифты**: Установка Nerd Fonts (FiraCode) для красивого отображения.

## Системные требования

- Windows 10 или 11.
- PowerShell 7.5.2 или выше (устанавливается автоматически).
- Windows Terminal (рекомендуется).
- `winget` (Windows Package Manager) или `choco` (Chocolatey) для установки пакетов.
- Права администратора для установки.

## Установка

1. **Скачай скрипт**:
   - Загрузи `roswell-ultimate.ps1` из [репозитория](https://github.com/Almazmsi/RoswellUltimate).
   - Или клонируй репо:
     ```bash
     git clone https://github.com/Almazmsi/RoswellUltimate.git
     cd RoswellUltimate
     ```

2. **Запусти инсталлер**:
   - Открой PowerShell 7 (`pwsh`) с правами администратора.
   - Выполни:
     ```powershell
     Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
     .\roswell-ultimate.ps1
     ```
   - Следуй меню: выбери "all" для полной установки или конкретные опции (например, 2 для пакетов, 5 для профиля).

3. **Что будет установлено**:
   - PowerShell 7, Windows Terminal, Oh My Posh, `fastfetch`, Git.
   - Шрифт FiraCode Nerd Font.
   - Профиль PowerShell (`$PROFILE`) с анимацией, HUD и алиасами.
   - Прозрачность в Windows Terminal.

4. **Перезапусти терминал**:
   - Запусти `pwsh` или открой Windows Terminal.
   - При первом запуске увидишь анимацию и вывод `fastfetch`.

## Использование

После установки профиль автоматически загружается в PowerShell 7. Доступны команды:
- `sysinfo`: Показывает системную информацию через `fastfetch`.
- `whoami`: Выводит имя текущего пользователя.
- `get-user-role`: Показывает, админ ты или нет.
- `systemuac`: Запускает скрипт с правами SYSTEM.
- `trusteduac`: Пытается запустить с правами TrustedInstaller (нужен `psexec`).
- `update-profile`: Проверяет и обновляет профиль с GitHub.
- `enable-roswell-animation`: Включает анимацию при запуске.
- `disable-roswell-startup`: Отключает стартовый вывод (анимация, `fastfetch`, HUD).

HUD (CPU, RAM, диски, GPU) отображается внизу терминала и обновляется каждую секунду.

## Настройка

- **Отключение HUD**:
  ```powershell
  disable-roswell-startup
  ```
  Восстановить:
  ```powershell
  Remove-Item -Path "$env:USERPROFILE\.roswell_disable_startup" -Force
  ```

- **Включение анимации**:
  ```powershell
  enable-roswell-animation
  ```

- **Смена темы Oh My Posh**:
  Измени путь к теме в профиле (`$env:POSH_THEMES_PATH\<тема>.omp.json`).

- **Проверка fastfetch**:
  Если `sysinfo` не работает, установи `fastfetch`:
  ```powershell
  winget install Fastfetch-cli.Fastfetch
  ```

## Устранение неполадок

- **Анимация не отображается**:
  - Убедись, что используешь PowerShell 7 (`pwsh --version`).
  - Удали файл `~/.roswell_first_run`:
    ```powershell
    Remove-Item -Path "$env:USERPROFILE\.roswell_first_run" -Force
    ```
  - Проверь, включена ли анимация: `enable-roswell-animation`.

- **Fastfetch не работает**:
  - Убедись, что `fastfetch` в PATH:
    ```powershell
    echo $env:Path
    ```
  - Переустанови:
    ```powershell
    winget install Fastfetch-cli.Fastfetch
    ```

- **Ошибки в профиле**:
  - Проверь лог: `C:\Users\<твой_юзер>\roswell-ultimate-5.1.log`.
  - Переустанови профиль:
    ```powershell
    .\roswell-ultimate.ps1
    # Выбери опцию 5
    ```

- **Прозрачность Windows Terminal не работает**:
  - Проверь, установлен ли Windows Terminal:
    ```powershell
    winget install Microsoft.WindowsTerminal
    ```
  - Проверь настройки: `C:\Users\<твой_юзер>\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json`.

## Лицензия

MIT License. Смотри [LICENSE](LICENSE) в репозитории.

## Автор

- **Almazmsi**: [github.com/Almazmsi](https://github.com/Almazmsi)

## Контакты

Если что-то не работает или есть идеи, пиши в [Issues](https://github.com/Almazmsi/RoswellUltimate/issues)

---

**Roswell Ultimate 1.0.0** — твой терминал теперь космический! 🚀
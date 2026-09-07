# Установка Claude Code на рабочий ПК (Windows)

Нужна, чтобы Claude мог работать на самой машине, а не в облачном контейнере.
На домашнем ПК этот механизм уже поднят — сессия «Hermes обновление» с
`environment_kind: bridge` и тегом `remote-control-sdk` — это Claude Code CLI,
подключённый через Remote Control.

## Отличие от Hermes: каталог выбрать нельзя

У Hermes путь установки задаётся через `HERMES_HOME`. У Claude Code — нет:

| Что | Куда |
|---|---|
| Исполняемый файл | `%USERPROFILE%\.local\bin\claude.exe` |
| Версии и данные | `%USERPROFILE%\.local\share\claude` |
| Настройки | `%USERPROFILE%\.claude\`, `%USERPROFILE%\.claude.json` |

Если профиль называется `C:\Users\Александр`, кириллица попадёт в путь
автоматически. Проверьте `preflight.ps1` перед установкой.

## Профиль латиницей

```powershell
irm https://claude.ai/install.ps1 | iex
```

Либо `winget install Anthropic.ClaudeCode` — но winget не обновляется сам,
нужен периодический `winget upgrade Anthropic.ClaudeCode`.

Рекомендуется [Git for Windows](https://git-scm.com/downloads/win): без него
Claude Code выполняет команды через PowerShell вместо Bash.

## Профиль с кириллицей

**WSL 2** — предпочтительно. Домашний каталог внутри WSL (`/home/<имя>`)
гарантированно ASCII, кириллица профиля Windows на него не влияет.

```powershell
wsl --install -d Ubuntu
```

Перезагрузка, затем внутри Ubuntu:

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

Учтите: файлы Windows видны как `/mnt/c/...`, поиск по ним медленный.

**Короткое имя 8.3** — запасной вариант, если WSL запрещён политикой:

```powershell
$fso = New-Object -ComObject Scripting.FileSystemObject
setx HOME $fso.GetFolder($env:USERPROFILE).ShortPath
```

Затем закрыть и открыть терминал заново (`setx` действует на новые процессы)
и ставить нативно.

Переименовывать профиль не нужно — путь прописан в реестре и в путях
приложений, на рабочей машине это ведёт к сломанному профилю.

## Кодировка консоли

Консоль Windows по умолчанию в 866 или 1251, Claude Code выводит UTF-8 —
русский текст будет кракозябрами. Решение: Windows Terminal
(`winget install Microsoft.WindowsTerminal`). Разово: `chcp 65001`.

## Проверка и вход

```powershell
claude --version
claude doctor
claude
```

Нужна подписка Pro, Max, Team, Enterprise или аккаунт Console — бесплатный
план доступа к Claude Code не даёт.

## Корпоративный прокси

Если `preflight.ps1` показал недоступность `claude.ai` по 443 — это
фильтрация трафика. Требования к сети: https://code.claude.com/docs/en/network-config

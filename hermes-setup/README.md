# Установка Hermes Desktop на рабочий ПК (Windows)

Runbook по исходникам `NousResearch/hermes-agent` (HEAD 2026-09-07, 0.21.0)
и по итогам ремонта на домашнем ПК
(`Strategic_Center/wiki/AI/Outbox/hermes_windows_repair_handoff_2026-08-04.md`).

Профиль рабочего ПК — `C:\Users\Админ` — **кириллический**, как и домашний.
Всё, что ниже про пути, обязательно к исполнению.

---

## 1. Инсталлятор и выбор каталога

`Hermes-Setup` в `Downloads` — это сборка electron-builder. Конфигурация
(`apps/desktop/package.json`):

```json
"win": { "target": ["nsis", "msi"] },
"nsis": {
  "oneClick": false,
  "allowToChangeInstallationDirectory": true,
  "perMachine": false
}
```

`allowToChangeInstallationDirectory: true` — **вот откуда дома взялся диалог
выбора каталога**. Установка per-user, права администратора не нужны.

**В диалоге указать ASCII-путь.** Например `D:\Hermes\Desktop` или
`C:\Hermes\Desktop`. Не оставлять предложенный по умолчанию путь внутри
`C:\Users\Админ\...`.

## 2. Задать HERMES_HOME ДО запуска инсталлятора

Это отдельный от GUI каталог — там живёт runtime агента, venv, состояние.
Инсталлятор ставит только оболочку; onboarding-мастер внутри Desktop затем
вызывает стадии `install.ps1`, а тот читает переменную окружения:

```powershell
[string]$HermesHome = $(if ($env:HERMES_HOME) { $env:HERMES_HOME } else { "$env:LOCALAPPDATA\hermes" })
```

Без переменной runtime уедет в `C:\Users\Админ\AppData\Local\hermes` — ровно
та конфигурация, которую дома пришлось чинить VBS-лаунчером. Поэтому **перед
запуском инсталлятора**:

```powershell
[Environment]::SetEnvironmentVariable('HERMES_HOME', 'D:\Hermes', 'User')
```

Затем перелогиниться или перезапустить проводник, чтобы переменную увидели
новые процессы.

## 3. Проверка путей

```powershell
powershell -File install.ps1 -ShowResolvedPaths
```

Печатает вычисленные пути в JSON и ничего не трогает. На профилях с
8.3-алиасом то, что видно в проводнике, и то, что получает установщик, —
разные строки; это авторитетная проверка.

Дополнительно `preflight.ps1` из этого каталога — общая проверка машины
(не-ASCII в путях, 8.3-имена, кодовая страница, Git, winget, сеть).

---

## 4. Отдельный профиль для рабочей машины

Hermes поддерживает изолированные инстансы:
`"""Profile management for multiple isolated Hermes instances."""`

Каждый профиль получает собственные `memories`, `sessions`, `skills`,
`skins`, `logs`, `plans`, `workspace`, `cron`, `home`. Живут в
`%HERMES_HOME%\profiles\<имя>`.

### Имя профиля

Регекс из `hermes_cli/profiles.py`:

```python
_PROFILE_ID_RE = re.compile(r"^[a-z0-9][a-z0-9_-]{0,63}$")
```

Только строчная латиница, цифры, `_` и `-`. `work`, `work-pc`, `office` —
годятся. `Work`, `Работа` — нет.

### Создание

```powershell
hermes profile create work --clone --description "Рабочий ПК, офисный контур"
hermes profile use work        # залипающий выбор по умолчанию
hermes profile alias work      # wrapper-скрипт, запуск командой work
```

- `--clone` копирует `config.yaml`, `.env`, `SOUL.md`, навыки и
  `memories/MEMORY.md`, `memories/USER.md` из активного профиля.
- `--clone-all` — полная копия состояния, но без истории (`state.db`,
  `sessions`, `backups`, `checkpoints` исключаются намеренно).
- `--no-skills` — пустой профиль, отписан от синхронизации навыков при
  `hermes update`.

### Перенос настроек с домашнего ПК

```powershell
# на домашней машине
hermes profile export default -o home.tar.gz

# на рабочей
hermes profile import home.tar.gz --name work
```

### Проверка, где вы находитесь

```powershell
hermes profile          # активный профиль и его каталог
hermes profile list     # все профили
hermes profile show work
```

---

## 5. Конфликт двух машин: gateway

Профили изолируют состояние **в пределах одной машины**. Между машинами они
не синхронизируются и от коллизий не защищают.

Критично: блокировка gateway — машинно-локальная.

```python
def _get_lock_dir() -> Path:
    """Machine-local dir for token-scoped gateway locks; ``HERMES_GATEWAY_LOCK_DIR`` overrides."""
```

Домашний gateway не увидит рабочий и наоборот. Проверка
`Another gateway instance is already running` (`gateway/run.py:4800`)
сработает только внутри одной машины.

**Следствие:** если `--clone` или `import` перенесёт `.env` с тем же токеном
Telegram-бота, обе машины начнут забирать одни и те же сообщения. Дома
gateway подключён к Telegram с heartbeat и шестью cron-задачами.

Варианты:

1. **Не поднимать gateway на рабочем ПК** — самый простой. Desktop и CLI
   работают без него.
2. **Отдельный бот** — свой токен в `.env` рабочего профиля.
3. Если gateway всё же нужен с тем же ботом — разносить по времени, но это
   хрупко и не рекомендуется.

Проверить после установки:

```powershell
hermes cron list      # не должно подхватиться домашних заданий
```

---

## 6. Что перенести с домашнего ПК

`Strategic_Center/scripts/`:

- **`hermes_gateway_ascii_fallback.vbs`** — обход проблем Windows Script Host
  с не-ASCII путями. При ASCII-пути установки не нужен, но
  `PYTHONIOENCODING=utf-8` из него стоит выставить в любом случае.
- **`hermes_webui_isolated_start.ps1`** — изолированный launcher WebUI.
  Нужен только если на рабочем ПК будет и WebUI.

## 7. Порядок обновления (проверено дома)

1. Не запускать update из активной сессии Desktop — updater может закрыть
   Desktop и gateway до возврата результата.
2. Запускать из отдельного терминала.
3. WebUI (если есть) должен работать из своего `.venv`, а не из
   `hermes-agent/venv`, иначе updater видит живой процесс внутри
   обновляемой installation и отменяет обновление с
   `another Hermes process is using this installation`.
4. Если updater жалуется на активный процесс — смотреть полную командную
   строку указанного PID, не считать автоматически виноватым gateway.

## 8. Известные баги против текущего апстрима

| Проблема с домашнего ПК | Состояние на 2026-09-07 |
|---|---|
| Sharing violation / `WinError 32` | Закрыто широко: `update_cmd.py`, `dashboard_procs.py`, `browser_connect.py`, флаг `--force` |
| 8.3-алиасы, не-ASCII пути | Закрыто: `ConvertTo-LongPath` + три резолвера |
| cp1251 при чтении вывода `uv` | Явного декодирования вывода `uv` не найдено; только `[Console]::OutputEncoding = UTF8` (install.ps1:101) |

---

## Ограничение этой сессии

Веб-сессия работает в облачном контейнере и до вашего ПК не дотягивается.
Чтобы установку выполнял я, нужен Claude Code с Remote Control на рабочей
машине — тот же мост, что работает дома. Порядок в `CLAUDE_CODE.md`.

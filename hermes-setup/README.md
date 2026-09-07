# Установка Hermes Desktop на рабочий ПК (Windows)

Runbook составлен по исходникам апстрима `NousResearch/hermes-agent`
(HEAD 2026-09-07, версия 0.21.0) и по итогам ремонта на домашнем ПК
(`Strategic_Center/wiki/AI/Outbox/hermes_windows_repair_handoff_2026-08-04.md`).

## Главное: Desktop не скачивается, а собирается

Готового инсталлятора «Hermes Desktop» в репозитории нет. Desktop — это
Electron-приложение, которое собирает установщик из исходников:

```
apps/desktop/release/win-unpacked/Hermes.exe
```

Сборка Desktop — **опциональная стадия**, по умолчанию выключена. Включается
флагом `-IncludeDesktop` (параметр `install.ps1`, строки 60-75). Ровно этот
путь и использовался дома.

## Кириллица: здесь каталог выбрать МОЖНО

Это отличие от Claude Code, где путь жёстко зашит в профиль. У Hermes каталог
установки — параметр:

```powershell
[string]$HermesHome = $(if ($env:HERMES_HOME) { $env:HERMES_HOME } else { "$env:LOCALAPPDATA\hermes" })
[string]$InstallDir = $(if ($env:HERMES_HOME) { "$env:HERMES_HOME\hermes-agent" } else { "$env:LOCALAPPDATA\hermes\hermes-agent" })
```

Дома установка легла в `C:/Users/Александр/AppData/Local/hermes/hermes-agent`
— с кириллицей в пути, со всеми вытекающими. **На рабочем ПК так не делаем:**
задаём `HERMES_HOME` на ASCII-путь заранее, и весь класс проблем исчезает.

Апстрим, справедливости ради, научился обходить 8.3-алиасы сам
(`ConvertTo-LongPath`, `kernel32!GetLongPathNameW`, `Scripting.FileSystemObject`
— строки 107-140). Но полагаться на обходной механизм там, где можно просто
не создавать проблему, незачем.

---

## Шаг 1. Проверка машины

`preflight.ps1` из этого каталога — общая проверка Windows: не-ASCII в
`%USERPROFILE%` и `%TEMP%`, доступность 8.3-имён, кодовая страница консоли,
Git, winget, место на диске, доступность сети.

```powershell
powershell -ExecutionPolicy Bypass -File .\preflight.ps1
```

## Шаг 2. Сухой прогон установщика

У `install.ps1` есть режим, который печатает вычисленные пути в JSON и
**ничего не трогает**:

```powershell
powershell -File install.ps1 -ShowResolvedPaths
```

Комментарий в исходнике объясняет, зачем он: на профилях, которые Windows
показывает через 8.3-алиас, то, что видит пользователь в проводнике, и то,
что получает установщик, — разные строки. Это авторитетная проверка, в
отличие от эвристик `preflight.ps1`.

## Шаг 3. Задать ASCII-путь и установить

```powershell
# ASCII-путь вне профиля пользователя
[Environment]::SetEnvironmentVariable('HERMES_HOME', 'D:\Hermes', 'User')
$env:HERMES_HOME = 'D:\Hermes'

# Установка вместе с Desktop
irm https://hermes-agent.nousresearch.com/install.ps1 -OutFile install.ps1
powershell -File install.ps1 -IncludeDesktop
```

Канонический однострочник апстрима — `iex (irm https://hermes-agent.nousresearch.com/install.ps1)`,
но он не даёт передать `-IncludeDesktop`, поэтому скачиваем файл и запускаем
с параметром.

Установка склонирует репозиторий в `%HERMES_HOME%\hermes-agent`, поднимет
Python-окружение через managed `uv`, соберёт Desktop.

---

## Что перенести с домашнего ПК

Два рабочих артефакта уже лежат в `Strategic_Center/scripts/`:

**`hermes_gateway_ascii_fallback.vbs`** — запуск gateway в обход проблем
Windows Script Host с не-ASCII путями. Ключевое в нём:

```vbs
hermesHome = sh.ExpandEnvironmentStrings("%LOCALAPPDATA%\hermes")   ' без хардкода пути
env.Item("PYTHONIOENCODING") = "utf-8"                              ' против cp1251
```

При ASCII-пути установки он, скорее всего, не понадобится — но `PYTHONIOENCODING=utf-8`
стоит выставить в любом случае.

**`hermes_webui_isolated_start.ps1`** — изолированный launcher WebUI. Нужен
только если на рабочем ПК будет разворачиваться и WebUI.

## Порядок обновления (проверено дома)

1. Не запускать update из активной сессии Hermes Desktop — updater может
   закрыть Desktop и gateway до возврата результата.
2. Запускать update из отдельного терминала.
3. Убедиться, что WebUI (если есть) работает из собственного `.venv`, а не
   из `hermes-agent/venv` — иначе updater видит живой процесс внутри
   обновляемой installation и отменяет обновление с
   `another Hermes process is using this installation`.
4. Если updater всё равно жалуется на активный процесс — смотреть полную
   командную строку указанного PID, не считать автоматически, что виноват
   gateway.

## Статус известных багов в апстриме

| Проблема с домашнего ПК | Состояние в апстриме на 2026-09-07 |
|---|---|
| Sharing violation / `WinError 32` | Обрабатывается широко: `update_cmd.py`, `dashboard_procs.py`, `browser_connect.py`, `profiles.py`, флаг `--force` |
| 8.3-алиасы и не-ASCII пути | Закрыто: `ConvertTo-LongPath` + три резолвера |
| cp1251 при чтении вывода `uv` | Явного декодирования вывода `uv` не найдено; в `install.ps1` есть только `[Console]::OutputEncoding = UTF8` (строка 101) |

Третья строка — повод проверить на рабочей машине отдельно, если установка
будет падать на стадии `uv`.

---

## Ограничение этой сессии

Веб-сессия Claude Code работает в облачном контейнере и до вашего ПК не
дотягивается. Чтобы установку выполнял я, а не вы руками, на рабочем ПК
нужен Claude Code с Remote Control — тот же механизм, что уже работает на
домашней машине (сессия «Hermes обновление», `environment_kind: bridge`).
Порядок установки самого Claude Code — в `CLAUDE_CODE.md` рядом.

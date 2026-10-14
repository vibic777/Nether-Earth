# Сборка Nether Earth Reloaded

Контрибьютор: vibic777

Один проект Godot 4.7 на GDScript даёт три сборки:

| Пресет | Файл |
| --- | --- |
| Windows Desktop | `build/windows/NetherEarthReloaded.exe` |
| Linux | `build/linux/NetherEarthReloaded.x86_64` |
| Android | `build/android/NetherEarthReloaded.apk` |

С Windows можно собрать все три. Linux-бинарник и APK кросс-компилируются шаблонами экспорта, отдельная машина не нужна.

## 1. Редактор

Скачать **Godot 4.7.2 stable**, обычную сборку, не .NET:

https://godotengine.org/download/archive/4.7.2-stable/

Windows: `Godot_v4.7.2-stable_win64.exe`. Положить куда удобно и один раз указать путь:

```powershell
$env:GODOT = "C:\Path\Godot_v4.7.2-stable_win64.exe"
```

Открыть папку проекта этим редактором. Главная сцена: `scenes/main.tscn`. Рендерер уже стоит GL Compatibility, ориентация телефона — ландшафт.

## 2. Шаблоны экспорта

В редакторе: **Editor → Manage Export Templates → Download and Install**. Версия шаблонов должна совпасть с редактором, 4.7.2.

Без шаблонов команда экспорта завершится ошибкой.

## 3. Android SDK

Нужен только для APK.

1. Установить OpenJDK 17.
2. Установить Android SDK. В каталоге SDK должен быть `platform-tools/adb`.
3. В редакторе: **Editor → Editor Settings → Export → Android**.
   * Java SDK Path — каталог JDK 17.
   * Android SDK Path — каталог SDK.

Пакет приложения: `com.vibic777.netherearth`. В APK входит архитектура `arm64-v8a`.

Отладочный APK подписывается встроенным debug-ключом Godot. Для релиза в магазин нужен свой keystore. Пароли не класть в репозиторий. Godot читает их из окружения:

```powershell
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = "C:\Path\release.keystore"
$env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = "upload"
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = "..."
```

Файл `.godot/export_credentials.cfg` в git не входит.

## 4. Команды

Из корня проекта, если `godot` есть в PATH или задан `$env:GODOT`:

```powershell
.\tools\export.ps1
```

Одна платформа:

```powershell
.\tools\export.ps1 -Target windows
.\tools\export.ps1 -Target linux
.\tools\export.ps1 -Target android
```

Те же пресеты вручную:

```text
godot --headless --path . --export-release "Windows Desktop" build/windows/NetherEarthReloaded.exe
godot --headless --path . --export-release "Linux" build/linux/NetherEarthReloaded.x86_64
godot --headless --path . --export-release "Android" build/android/NetherEarthReloaded.apk
```

Каталог `build/` в git не входит.

На Linux-машине тот же экспорт: `tools/export.sh`.

## Проверки

Сцена при старте прогоняет маршруты, сеть, оружие, склад, бой, ИИ и исход матча. С аргументом `--test` процесс завершается сам: код 0, если всё сошлось, иначе 1.

```powershell
.\tools\test.ps1
```

На Linux: `tools/test.sh`. Редактор при этом не нужен, хватает консольной сборки Godot 4.7.2.


## Тестовая сборка Windows (быстро)

Godot 4.7.2 стоит в `%LOCALAPPDATA%\Programs\Godot`, шаблоны экспорта в `%APPDATA%\Godot\export_templates\4.7.2.stable`, переменная `GODOT` задана.

```powershell
powershell -ExecutionPolicy Bypass -File tools\export.ps1 -Target windows
```

Запуск: `build\windows\NetherEarthReloaded.exe` (один файл, pck встроен). Лог: `%APPDATA%\Godot\app_userdata\Nether Earth Reloaded\logs\godot.log`.
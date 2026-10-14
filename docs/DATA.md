# Данные игры: data/game.json

Все названия, русские описания и числа юнитов, оружия, способностей, зданий и
ландшафта, а также статьи справочника лежат в одном файле **`data/game.json`**
(в репозитории: `V:\Projects\Nether Earth\data\game.json`). Справочник (Shift+F1)
и подсказки F1 берут текст оттуда.

## Где игра ищет файл (первый найденный побеждает)
1. `data/game.json` рядом с exe (`build\windows\data\game.json`): только в собранной игре. Папку `data` создайте сами и скопируйте туда файл из репозитория. Без неё используется копия, вшитая в exe.
2. `user://game.json` (`%APPDATA%\Godot\app_userdata\Nether Earth Reloaded\game.json`).
3. Встроенный `res://data/game.json`.

Если поля нет или файл повреждён, берётся значение по умолчанию из кода (функции `_d_*`), так что игра не упадёт.
Ошибка разбора JSON пишется в лог. Правки применяются при следующем запуске.

## Правила
- Ключи-идентификаторы (`WALKER`, `BULLET`, `PLAIN`, `HQ`…) и имена полей не переименовывать. Значения менять можно.
- Числа — обычные JSON-числа, цвета — строки `"#rrggbb"`, текст — UTF-8. В статьях `help` допустим BBCode (`[b]…[/b]`).

## Разделы
### units.<КЛЮЧ>: WALKER, UAV, ROTOR, TRACK, BIKE, TROOPER, ENGINEER
| поле | смысл |
|---|---|
| name, description | название и описание |
| hull | броня (HP) |
| speed, turn_deg, align | скорость (клеток/с), поворот (°/с), выравнивание по склону 0..1 |
| cost | `[металл, чипы, энергия]` |
| build_seconds | время постройки |
| sight | обзор в клетках (туман войны) |
| max_tier | макс. ступень оружия (1–3) |
| modes | 3 режима (Z/X/C): `title`, `kind` (`"MAIN"` = основное оружие или ключ оружия), `dmg`, `cd`, `range` (множители), `splash`, `charge`, `deploy` (с), `lob`, `icon` |
| ability | способность T: `title`, `cooldown`… или `{}` |

### weapons.<КЛЮЧ>: BULLET, LASER, ROCKET, SHELL, PLASMA, FLAME, ION, BOMB…
`name`, `description`, `power` (урон за ступень), `damage_scale`, `min_tier`, `color`, `range`, `cooldown`, `splash`, `stun`, `chains`, `speed` (снаряда).

### buildings.<КЛЮЧ>: HQ, RELAY, FACTORY, EXTRACTOR, AIR, ROBOT
`name`, `description`; у HQ ещё есть `hull`.

### terrain.<КЛЮЧ>: PLAIN, STONE, TREE, MOUNTAIN, WATER, BUILDING, LINK
`name`, `description`, `lift` (высота), `rough` (сопротивление проходу).

### help.<id>
`{"title": "...", "text": "..."}`: статьи об интерфейсе и управлении (controls, cursors,
ui_panel, ui_minimap, ui_groups, ui_selection, ui_orders, ui_weapons, ui_camera,
ui_story, ui_resources, ui_difficulty, fog, ui_cheats, ui_settings). Статьи о юнитах,
оружии, зданиях и ландшафте собираются автоматически из разделов выше вместе с характеристиками.
Элементы HUD связаны со статьями через meta `"help"`.

# Настройки: user://settings.cfg
Хранятся в `%APPDATA%\Godot\app_userdata\Nether Earth Reloaded\settings.cfg` (ConfigFile). Секции:
graphics, display, ui (`text_scale`, `menu_scale`, `tooltip_seconds` 0–30, 0 = F1 сразу открывает статью),
audio, controls, keys. Чтобы сбросить настройки, удалите файл или нажмите «По умолчанию».

# Раскладка и отступы (Layout, Spacing)

> Разделы «В приложении → Расхождения» описывают состояние на 16.09.2026, до порта компонентов. Исправлено с тех пор: эталонная статичная схема и системные роли Android 14+, emphasized-веса по токенам, opsz и grade иконок, state layer, цвета tooltip, чипов и app bar при прокрутке, scrim 32%, выдуманные альфы, размеры шрифта и радиусы (карточка пары и метки удалены), пустое состояние из `MaterialShapes`, пружины кнопок, листов и снекбара, смена дня — lateral. Остаётся: breakpoints и navigation rail для окон шире 600dp (приложение для телефона), часть отступов вне токенов в старом коде.

## Источники

- m3.material.io → `.m3-guidelines/`:
  - https://m3.material.io/foundations/layout/layout-overview → `foundations__layout__layout-overview.md`
  - https://m3.material.io/foundations/layout/breakpoints → `foundations__layout__breakpoints.md`
  - https://m3.material.io/foundations/layout/grids-spacing → `foundations__layout__grids-spacing.md`
  - https://m3.material.io/foundations/layout/scaffold → `foundations__layout__scaffold.md`; canonical examples → `foundations__layout__canonical-examples.md`; RTL → `foundations__layout__bidirectionality-rtl.md`
  - https://m3.material.io/styles/spacing → `styles__spacing.md`; значения `md.sys.measurement.space*` — из базы токенов сайта (`.m3-guidelines/raw/tokens-*.json`)
  - зоны нажатия: `styles__icons.md`, `foundations__interaction__states.md`, `components__chips.md`, `components__icon-buttons.md`, `components__button-groups.md`
- Compose Material3: `InteractiveComponentSize.kt` (`Modifier.minimumInteractiveComponentSize()`, `LocalMinimumInteractiveComponentSize`, 48.dp)
- Flutter: `MaterialTapTargetSize.padded` (`ThemeData.materialTapTargetSize`), `MediaQuery.sizeOf`

## Правила

### Breakpoints (бывшие window size classes)

| Breakpoint | Ширина | Устройства | Панели | Навигация (таблица компонентов) | Поля / промежуток между панелями |
|---|---|---|---|---|---|
| Compact | < 600dp | телефон портрет | 1 | navigation bar, модальный expanded rail | **16dp** |
| Medium | 600–839dp | планшет/складной портрет | 1 (рекомендуется) или 2 | navigation bar, модальный expanded rail | 24dp / 24dp |
| Expanded | 840–1199dp | телефон ландшафт, планшет ландшафт, складной ландшафт, desktop | 1 или 2 (рекомендуется) | модальный или стандартный expanded rail | 24dp / 24dp; фиксированная панель 360dp |
| Large | 1200–1599dp | desktop | 1 или 2 (рекомендуется) | модальный или стандартный expanded rail | 24dp / 24dp; фиксированная панель 412dp |
| Extra-large | ≥ 1600dp | desktop, ultra-wide | 1–3 (рекомендуется) | модальный или стандартный expanded rail | 24dp / 24dp; фиксированная панель 412dp |

- Приложение должно автоматически адаптироваться к breakpoint (складной телефон разворачивается, экран поворачивается). Таблица «Common swappable components»: navigation bar (compact) ↔ collapsed navigation rail (medium, expanded); modal expanded rail (compact, medium) ↔ standard expanded rail (expanded); basic/full-screen dialog ↔ basic dialog; bottom sheet (compact) ↔ menu (medium, expanded) для дополнительного выбора. Высотные breakpoints есть на Android, но нужны редко.
- Навигацию в compact ставить у нижнего края. Текст — 40–60 символов в строке на любых breakpoint.

### Отступы

- Система на шкале **8dp** (`space100` = 8dp). Токены `md.sys.measurement.space*`: 0 = 0, 25 = 2, 50 = 4, 75 = 6, 100 = 8, 125 = 10, 150 = 12, 175 = 14, 200 = 16, 250 = 20, 300 = 24, 400 = 32, 500 = 40, 600 = 48, 800 = 64, 900 = 72dp. Своё значение — по формуле множителя (пример гайдлайна: `space225` = 18dp), оформляя как расширение системы.
- Три вида: **padding** (внутри), **gap** (между элементами), **margin** (снаружи). «Use padding & gaps before using margins»; margins — в основном для раскладки.
- Группировка: явная (обводки, разделители, тени) и неявная (близость и пустое пространство). Ритм — одинаковые промежутки между связанными элементами; похожие элементы — одинаковые отступы и размеры; ведущие элементы (иконки, аватары) выравниваются.
- Выразительность: «Give the most important content… visual prominence with generous spacing and the brightest surfaces».
- При масштабировании текста до 200% отступы сохраняются.
- Плотность: по умолчанию цель ≥ 48×48; повышение плотности обычно уменьшает вертикальные отступы/высоту на 4dp; не повышать плотность там, где нужен сфокусированный выбор (меню).
- Rulers: margin, bar/safety (статус-бар, жестовая навигация), title, content — для выравнивания.

### Зоны нажатия

- Минимум **48×48dp**, даже если элемент меньше (иконка 24dp → цель 48dp; кнопка 36/40dp → цель 48dp). State layer — 40dp при цели 48dp.
- Между чипами минимум 8dp; зона вторичного действия чипа — 48dp.
- Compose: `minimumInteractiveComponentSize()` резервирует 48.dp у всех интерактивных компонентов.

### RTL

- Зеркалить раскладку, свайпы и predictive back; графики у некоторых языков остаются LTR.

## Как устроено в Compose

- `Modifier.minimumInteractiveComponentSize()` (48.dp, настраивается `LocalMinimumInteractiveComponentSize`).
- Адаптивность — пакеты `material3-adaptive` / canonical layouts, rulers (`androidx.compose.ui.layout.Ruler`) — ссылки на m3.material.io; в клоне `material3` их нет.

## В приложении

### Как сейчас

- `lib/features/home/home_shell.dart` — всегда `NavigationBar`, без учёта ширины окна; `SafeArea` вокруг тела.
- Горизонтальные поля экранов: заголовки 22dp (`absences_screen.dart:39`, `notes_screen.dart:33`, `profile_screen.dart:29`, `schedule_screen.dart:464`), секции 26dp (`absences_screen.dart:72`, `profile_screen.dart:53,272`, `schedule_screen.dart:589`), контейнеры 16dp (`absences_screen.dart`, `profile_screen.dart`, баннер ошибки в `schedule_screen.dart`), 20dp (`certificate_sheet.dart:51`, `notes_screen.dart:49`).
- Зоны нажатия: `connected_button_group.dart` — `SizedBox(height: 48)` вокруг кнопки 40dp; `notes_screen.dart` — `Checkbox` с `materialTapTargetSize` по умолчанию (48dp); `app_button_styles.dart` — icon button 40dp + padded target; `day_selector.dart` — элемент ≥ 56dp в ширину.

### Расхождения

| # | Сейчас | Должно быть | Источник |
|---|---|---|---|
| 1 | Поля экранов 22 / 26 / 20dp — **придуманы** и различаются между экранами | Compact — 16dp от краёв окна, одинаково на всех экранах | `foundations__layout__breakpoints.md` (Compact: «Margins are 16dp») |
| 2 | Отступы **вне системы токенов**: 5 (`absences_screen.dart:231`), 7 (`absences_screen.dart:55`, `lesson_card.dart:495`), 9 (`absences_screen.dart:166`, `lesson_card.dart:213`), 18 (`absences_screen.dart:69,208`, `certificate_sheet.dart:67`, `notes_screen.dart:102`, `profile_screen.dart:35,131`, `lesson_details_page.dart:219`, `schedule_screen.dart:589`, `lesson_card.dart:254`), 22 (`lesson_card.dart:156`, `absences_screen.dart:101`), 26 (`absences_screen.dart:72,101`, `boot_screen.dart:24`, `certificate_sheet.dart:51`, `profile_screen.dart:53,272`) | Значения `md.sys.measurement.space*` (2, 4, 6, 8, 10, 12, 14, 16, 20, 24, 32, 40, 48, 64, 72) | `styles__spacing.md`, база токенов сайта |
| 3 | Нет адаптации к breakpoints: на ширине ≥ 600dp (складной, планшет, ландшафт ≥ 840dp) остаётся navigation bar и одна панель на всю ширину | Medium и expanded — поля 24dp, navigation bar заменяется collapsed navigation rail (таблица «Common swappable components»); expanded+ — рекомендуется вторая панель (расписание + подробности пары); bottom sheet дополнительного выбора → menu | `foundations__layout__breakpoints.md` |
| 4 | Карточка текущей пары: `EdgeInsets.all(isNow ? 22 : 20)` — внутренний отступ меняется вместе с состоянием | Постоянный padding из токенов; акцент — цветом/формой | `styles__spacing.md` |

Что совпадает: зоны нажатия 48dp у кнопок, чекбоксов, icon button; `SafeArea` для системных панелей; RTL учтён в shared axis (`app_transitions.dart`).

### Что сделать во Flutter

1. Завести `AppSpacing` с токенами `space25…space900` и заменить числа в `EdgeInsets` / `SizedBox`; `screenMargin` = 16 (compact) / 24 (medium+).
2. Завести `AppBreakpoints` (600 / 840 / 1200 / 1600) по `MediaQuery.sizeOf(context).width`; в `HomeShell` переключать `NavigationBar` ↔ `NavigationRail`.
3. Для expanded+ — list-detail для расписания и подробностей пары (canonical layout).
4. Для любых новых интерактивных элементов меньше 48dp — внешняя зона 48dp (`ConstrainedBox`/`SizedBox` или `MaterialTapTargetSize.padded`).

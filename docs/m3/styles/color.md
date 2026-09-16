# Цвет (Color)

> Разделы «В приложении → Расхождения» описывают состояние на 16.09.2026, до порта компонентов. Исправлено с тех пор: эталонная статичная схема и системные роли Android 14+, emphasized-веса по токенам, opsz и grade иконок, state layer, цвета tooltip, чипов и app bar при прокрутке, scrim 32%, выдуманные альфы, размеры шрифта и радиусы (карточка пары и метки удалены), пустое состояние из `MaterialShapes`, пружины кнопок, листов и снекбара, смена дня — lateral. Остаётся: breakpoints и navigation rail для окон шире 600dp (приложение для телефона), часть отступов вне токенов в старом коде.

## Источники

- m3.material.io → `.m3-guidelines/`:
  - https://m3.material.io/styles/color/system (overview, how the system works) → `styles__color__system.md`
  - https://m3.material.io/styles/color/roles → `styles__color__roles.md`
  - https://m3.material.io/styles/color/choosing-a-scheme → `styles__color__choosing-a-scheme.md`
  - https://m3.material.io/styles/color/static → `styles__color__static.md`; https://m3.material.io/styles/color/dynamic → `styles__color__dynamic.md`
  - https://m3.material.io/styles/color/advanced → `styles__color__advanced.md`
  - https://m3.material.io/blog/building-with-m3-expressive → `building-with-m3-expressive.md`
  - токены компонентов: `components__navigation-bar.md`, `components__tooltips.md`, `components__chips.md`, `components__cards.md`, `components__progress-indicators.md`, `components__snackbar.md`, `components__bottom-sheets.md`
- Compose Material3: `ColorScheme.kt` (`lightColorScheme`, `darkColorScheme`, `expressiveLightColorScheme`), `MaterialTheme.kt` (`MaterialExpressiveTheme`), `tokens/ColorLightTokens.kt` / `ColorDarkTokens.kt` (v0_210), `tokens/PaletteTokens.kt`, `tokens/ScrimTokens.kt`, `tokens/AppBarTokens.kt`, `tokens/NavigationBarTokens.kt`, `tokens/SheetBottomTokens.kt`, `tokens/SearchBarTokens.kt`, `tokens/MenuTokens.kt`, `tokens/DialogTokens.kt`, `tokens/PlainTooltipTokens.kt`, `tokens/SnackbarTokens.kt`, `tokens/FilterChipTokens.kt`, `tokens/*CardTokens.kt`. `dynamicLightColorScheme(context)` лежит в `androidMain` — в клоне его нет, не проверял.
- MDC-Android: `docs/theming/Color.md` (таблица ролей baseline / dynamic 31–33 / dynamic 34+, Custom Colors, Color Harmonization, `ColorRoles`, Contrast Control), `docs/theming/Dark.md`
- Flutter: `material/color_scheme.dart` (`ColorScheme.fromSeed`, `DynamicSchemeVariant`, `contrastLevel`), `material/theme_data.dart` (`_colorSchemeLightM3`/`_colorSchemeDarkM3`); `dynamic_color` 1.9.0 (`lib/src/corepalette_to_colorscheme.dart`, `dynamic_color_builder.dart`); `material_color_utilities` 0.13.0 (`scheme/scheme_expressive.dart`, `scheme/scheme.dart`, `CHANGELOG.md`)

## Правила

### Роли

- 26 стандартных ролей в 6 группах (primary, secondary, tertiary, error, surface, outline) плюс add-on роли; на схеме «all 45 color roles». Роли стоят в доступных парах с контрастом не ниже 3:1 — **использовать только задуманные пары и порядок наложения**, иначе контраст ломается (особенно при пользовательском контрасте).
- **Container** — заливки; «should not be used for text or icons». **On** — текст и иконки поверх парного цвета. **Variant** — менее акцентная версия.
- **Primary** — самое важное: FAB, акцентные кнопки, активные состояния. **Secondary** — менее заметное: filter chips, выбранный пункт навигации, тональные кнопки. **Tertiary** — контрастные акценты (badge, поле ввода), на усмотрение дизайнера. **Error** — статичная роль даже в динамической схеме.
- **Surface**: `surface` — фон; `onSurface` / `onSurfaceVariant` — текст и иконки на любых surface-ролях. Пять контейнеров: `surfaceContainerLowest` / `Low` / (default) `surfaceContainer` / `High` / `Highest`. Частая пара: `surface` — тело экрана, `surfaceContainer` — навигация. Подпись к примеру на roles: Low — elevated button и card; default — top и bottom bar; High — FAB и basic dialog; Highest — input label и выключенный switch. Перекрывающиеся области должны иметь **разные** роли (`styles__elevation.md`).
- **Inverse**: `inverseSurface`, `onInverseSurface`, `inversePrimary` (snackbar и его текстовая кнопка).
- **Outline** — важные границы (text field); **outline variant** — декоративное (dividers, cards). DON'T: `outline` для dividers и карточек; DON'T: `outlineVariant` как граница целей (chips) — только если содержимое даёт 4.5:1.
- **Fixed / fixed dim / on fixed (variant)** — не меняются между светлой и тёмной темой; «avoid using them where contrast is necessary». **Surface dim / bright** — сохраняют относительную яркость в обеих темах.
- Текст по умолчанию — `onSurface`, альтернатива — `onSurfaceVariant`; ссылки — `primary` (или `tertiary`) и подчёркивание (`styles__typography.md`).
- Scrim — роль `scrim` с непрозрачностью 32%. Surface tint устарел (`styles__elevation.md`).

### Схемы

- **Static baseline** — «hand-picked source color»; для тех, кто не готов к dynamic, мигрирует с M2, делает enterprise или iOS. **Dynamic** — из обоев (user-generated) или контента (content-based); проектировать ролями, а не hex.
- Схема генерируется так: источник → 5 ключевых цветов (primary, secondary, tertiary, neutral, neutral variant) → тональные палитры (0…100: шаг 10 плюс 95, 98, 99) → тона ролям (например, primary40 → primary, primary100 → onPrimary).
- **Три уровня контраста**: standard (по умолчанию), medium (минимум 3:1), high (7:1). Собственные компоненты поддерживают контраст, если используют роли (`primaryContainer` + `onPrimaryContainer`).
- Обновления: февраль 2023 — светлый `surface` тон 98 вместо 99, chroma нейтральной палитры 4 → 6, тональные surface-роли вместо наложений по elevation; август 2024 — `onPrimaryContainer` / `onSecondaryContainer` / `onTertiaryContainer` / `onErrorContainer` в светлой теме «more colorful»; май 2025 — токенизированы три уровня контраста.
- **Что M3 Expressive говорит о выборе схемы.** Страница «Choosing a scheme» различает только static и dynamic; варианты генерации (tonal spot, vibrant, expressive, …) в гайдлайнах по имени **не упоминаются** — не нашёл в источниках рекомендации выбирать вариант `expressive`. Блог M3 Expressive: «Vibrant color schemes… Rich visual styles support personalization and dynamic colors»; тактика «Apply rich and nuanced colors» — иерархия за счёт контраста primary / secondary / tertiary и тонов surface. В `advanced` сказано, что собственный вариант схемы можно определить через Material Color Utilities.
- **Дополнительные цвета** (например, success): задать опорный цвет — Material вернёт 4 роли (цвет, on, container, on container) по тем же правилам, что и акцентные; можно гармонизировать с primary; значения должны реагировать на уровень контраста (MDC `Color.md` → Contrast Control – Custom Colors).

## Как устроено в Compose

- `lightColorScheme()` = `ColorLightTokens` (baseline; `Primary` = `PaletteTokens.Primary40` = `#6750A4`, `OnPrimaryContainer` = Primary10).
- `expressiveLightColorScheme()` = `lightColorScheme(onPrimaryContainer = Primary30, onSecondaryContainer = Secondary30, onTertiaryContainer = Tertiary30, onErrorContainer = Error30)` — это обновление августа 2024. `MaterialExpressiveTheme` берёт её по умолчанию.
- Роли у компонентов (токены Compose / m3.material.io):

| Компонент | Роли |
|---|---|
| Navigation bar | контейнер `surfaceContainer`; индикатор `secondaryContainer`; подпись активного `secondary` |
| Top app bar | `surface`; при прокрутке — `surfaceContainer` (анимация цвета DefaultEffects) |
| Bottom sheet | `surfaceContainerLow` |
| Search bar / search view, dialog | `surfaceContainerHigh` |
| Menu, rich tooltip | `surfaceContainer` |
| Plain tooltip | `inverseSurface` / `inverseOnSurface` |
| Snackbar | `inverseSurface` / `inverseOnSurface` / действие `inversePrimary` |
| Filled / elevated / outlined card | `surfaceContainerHighest` / `surfaceContainerLow` / `surface` + обводка `outlineVariant` |
| Filter chip (flat) | выбранный `secondaryContainer`; обводка невыбранного `outlineVariant` |
| Tonal button | `secondaryContainer` |
| Progress indicator | активная часть `primary`; трек `secondaryContainer` |
| Divider | `outlineVariant` |
| Scrim | `scrim` × 0.32 (`ScrimTokens.ContainerOpacity`) |

- MDC: на Android 12–13 (API 31–33) роли берутся из `system_accent*_NNN`, на Android 14+ (API 34+) — из готовых ролей `system_primary_light`, `system_surface_container_light` и т. д.; «You will get contrast control for free if you already use dynamic colors» (только Android 14+).

## В приложении

### Как сейчас

- `lib/theme/app_color_schemes.dart`: `AppPalette` — 4 сида из макета; `variant = DynamicSchemeVariant.expressive`; `resolve()`: dynamic выключен → `fromSeed(baselineSeed #6750A4, expressive)`; включён → схема устройства (`DynamicColorBuilder`), иначе сид-акцент устройства, иначе сид палитры.
- `lib/app.dart` `buildTheme`: nav bar `surfaceContainer` + `secondaryContainer` + подпись `secondary`; search `surfaceContainerHigh`; filter chip — `secondaryContainer`, обводка невыбранного **`outline`**; card `surface` + `outlineVariant`; FAB `primaryContainer`; bottom sheet `surfaceContainerLow`; tooltip **`primary` / `onPrimary`**; snackbar `inverseSurface`; divider `outlineVariant`; app bar `surface` с `scrolledUnderElevation: 0`.
- `lib/theme/status_colors.dart` — `StatusColors` (pending / approved / rejected) из hex макета, отдельно для светлой и тёмной темы.
- `lib/theme/app_typography.dart` — цвет текста `0xFF1C1B20` / `0xFFE8E1EC` (перекрывается `.apply(bodyColor: onSurface)` в `buildTheme`).
- Виджеты: `lesson_card.dart`, `day_selector.dart`, `status_badge.dart`, `absence_donut.dart` — роли с изменённой прозрачностью.

### Расхождения

| # | Сейчас | Должно быть | Источник |
|---|---|---|---|
| 1 | «Baseline» при выключенном dynamic = `ColorScheme.fromSeed(#6750A4, expressive)` → primary **`#006B5A`** (бирюзовый; расчёт MCU 0.13.0 `SchemeExpressive`) | Baseline — статичная hand-picked схема: primary `#6750A4`, on*Container = тон 30 (`expressiveLightColorScheme`). Во Flutter это встроенная `ThemeData(brightness: …).colorScheme` (`_colorSchemeLightM3`: primary `0xFF6750A4`, onPrimaryContainer `0xFF4F378B`) | `styles__color__system.md`, `ColorScheme.kt`, `tokens/ColorLightTokens.kt`, `material/theme_data.dart` |
| 2 | `DynamicSchemeVariant.expressive` выбран как «вариант M3 Expressive» | Гайдлайны о вариантах генерации молчат; вариант MCU `expressive` описан во Flutter как «primary palette's hue is different from the seed color» — это алгоритм, а не «M3 Expressive». Compose Expressive использует baseline или системную dynamic-схему | `material/color_scheme.dart`, `MaterialTheme.kt`, `styles__color__choosing-a-scheme.md` |
| 3 | Логика `resolve()`: на Android 12+ с включённым dynamic выбранная палитра не применяется никогда, с выключенным — тоже (baseline). Палитра `violet` (`#6B3FD4`, hue 299) даёт практически ту же схему, что и `baselineSeed` (hue 299): primary `#006B5A` и secondary `#79536A` у обеих | Выбор палитры — отдельный режим static-схемы; dynamic — отдельный | `styles__color__choosing-a-scheme.md` |
| 4 | Dynamic color через `dynamic_color` 1.9.0: `CorePalette.toColorScheme()` строит роли легаси-классом `Scheme.lightFromCorePalette` (surface = neutral **99**, onPrimaryContainer = primary **10**), а surface-контейнеры — из `ColorScheme.fromSeed(primary)` | Роли Android 14+ — системные `system_*` (MDC `Color.md`); светлый surface — тон 98 (февраль 2023); on*Container — тон 30 (август 2024) | `dynamic_color/lib/src/corepalette_to_colorscheme.dart`, `material_color_utilities/lib/scheme/scheme.dart`, `styles__color__system.md` |
| 5 | Нет поддержки уровней контраста (`contrastLevel` не передаётся, системный контраст не читается) | Standard / medium / high; с dynamic на Android 14+ — из системы | `styles__color__system.md`, MDC `Color.md` (Contrast Control) |
| 6 | `status_colors.dart`: hex из макета — **придуманы**; `rejected` дублирует роль error | Статичные дополнительные цвета: опорный цвет → 4 роли по правилам MCU (+ гармонизация с primary, + реакция на контраст); отклонено — `errorContainer` / `onErrorContainer` | `styles__color__advanced.md`, MDC `Color.md` (Custom Colors, Harmonization, `ColorRoles`) |
| 7 | `status_badge.dart`: тип пары «практика» окрашен `status.approved` (зелёный «одобрено») | Семантический цвет не для категорий; для типов пар — акцентные контейнеры (`primary`/`secondary`/`tertiaryContainer`) | `styles__color__roles.md` |
| 8 | Роли с изменённой прозрачностью — **придуманы**: `onPrimary` α 0.82 (`day_selector.dart:129`), 0.86 / 0.78 / 0.14 / 0.22 / 0.85 / 0.32 (`lesson_card.dart:148,181,287,293,398,507,518,659`), 0.22 (`status_badge.dart:32`); `onSurfaceVariant` α 0.7 (`absence_donut.dart:88`) | Прозрачность в M3 — только state layers (8/10/16%), disabled (10% контейнер / 38% контент), scrim 32%. Остальное — роли в задуманных парах; трек прогресса — `secondaryContainer` | `styles__color__roles.md` (Pairing and layering), `foundations__interaction__states.md`, `components__progress-indicators.md`, `tokens/FilledButtonTokens.kt` |
| 9 | Tooltip (`app.dart`) — `primary` / `onPrimary` | `inverseSurface` / `inverseOnSurface` | `components__tooltips.md`, `tokens/PlainTooltipTokens.kt` |
| 10 | Filter chip: обводка невыбранного — `outline` | `outlineVariant` (`md.comp.filter-chip.flat.unselected.outline.color`) | `components__chips.md`, `tokens/FilterChipTokens.kt` |
| 11 | App bar не меняет цвет при прокрутке (`scrolledUnderElevation: 0`, `backgroundColor: surface`) | При прокрутке — `surfaceContainer` (анимация DefaultEffects) | `tokens/AppBarTokens.kt` (`OnScrollContainerColor`), `AppBar.kt` |
| 12 | Scrim bottom sheet и `OpenContainer` — `Colors.black54` | `scheme.scrim` × 0.32 | `styles__elevation.md`, `tokens/ScrimTokens.kt` |
| 13 | `app_typography.dart` — hex цвета текста; `absence_donut.dart` трек `surfaceContainerHigh`; полосы `surfaceContainerHigh/Low` в `certificate_sheet.dart` | `onSurface`; трек `secondaryContainer`; полосатую заливку в источниках не нашёл | `styles__typography.md`, `components__progress-indicators.md` |

Что совпадает: navigation bar, search, bottom sheet, snackbar, divider, outlined card, FAB (`primaryContainer`), баннер ошибки (`errorContainer` / `onErrorContainer`), вложенные контейнеры `surfaceContainer` на `surface` с внутренними плитками `surface`.

### Что сделать во Flutter

1. Static baseline: `ThemeData(brightness: b).colorScheme` (или копия `ColorLightTokens`), без `fromSeed`.
2. Палитры: либо честная static-схема `ColorScheme.fromSeed(seedColor, dynamicSchemeVariant: tonalSpot/fidelity)` с понятным названием, либо убрать; решение и вариант записать в «Сознательные отступления».
3. Dynamic на Android 14+: читать системные роли (`android.R.color.system_*`) через платформенный канал или обновлённый пакет; до этого — `ColorScheme.fromSeed(seedColor: corePalette primary, contrastLevel: …)`, а не легаси `Scheme`.
4. Контраст: получать системный уровень контраста через платформенный канал (Android API в источниках не проверял) и передавать `contrastLevel` в `fromSeed`.
5. `StatusColors` генерировать из опорных цветов через `material_color_utilities` — тона как у акцентов в `ColorLightTokens` (цвет 40, on 100, container 90, on container 30), гармонизировать `Blend.harmonize` или `Color.harmonizeWith(primary)` из `dynamic_color`; rejected → error-роли.
6. Убрать все `withValues(alpha: …)` на ролях вне state layer / disabled / scrim; tooltip → inverse; chip outline → `outlineVariant`; app bar — `surfaceContainer` при прокрутке; scrim 32%.

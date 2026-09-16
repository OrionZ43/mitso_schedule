# Состояния взаимодействия (Interaction states)

> Разделы «В приложении → Расхождения» описывают состояние на 16.09.2026, до порта компонентов. Исправлено с тех пор: эталонная статичная схема и системные роли Android 14+, emphasized-веса по токенам, opsz и grade иконок, state layer, цвета tooltip, чипов и app bar при прокрутке, scrim 32%, выдуманные альфы, размеры шрифта и радиусы (карточка пары и метки удалены), пустое состояние из `MaterialShapes`, пружины кнопок, листов и снекбара, смена дня — lateral. Остаётся: breakpoints и navigation rail для окон шире 600dp (приложение для телефона), часть отступов вне токенов в старом коде.

## Источники

- m3.material.io → `.m3-guidelines/`:
  - https://m3.material.io/foundations/interaction/states (Overview, State layers, Applying states) → `foundations__interaction__states.md`
  - https://m3.material.io/foundations/interaction/selection → `foundations__interaction__selection.md`
  - https://m3.material.io/foundations/interaction/gestures → `foundations__interaction__gestures.md`; inputs → `foundations__interaction__inputs.md`
  - база токенов сайта (`raw/tokens-*.json`): `md.sys.state.{hover,focus,pressed,dragged}.state-layer-opacity`, `md.sys.state.focus-indicator.{thickness,outer-offset,inner-offset}`
  - токены компонентов: `components__buttons.md` (disabled, focus indicator, формы при нажатии), `components__button-groups.md`, `components__icon-buttons.md`
- Compose Material3: `tokens/StateTokens.kt` (v0_210), `Ripple.kt` (`ripple()`, `RippleDefaults.RippleAlpha`, `RippleDefaults.ThemeConfiguration`, `InsetFocusRingThemeConfiguration`, `LocalRippleThemeConfiguration`), `Button.kt` (`shapeByInteraction`), `ToggleButton.kt`, `ButtonGroup.kt`, `tokens/ButtonSmallTokens.kt` и др., `tokens/FilledButtonTokens.kt` (disabled), `InteractiveComponentSize.kt`
- Flutter: `material/ink_well.dart` (`getHighlightColorForType`, длительности подсветки), `material/theme_data.dart` (дефолтные `highlightColor`, `splashColor`, `hoverColor`, `focusColor`, `splashFactory`), `material/ink_sparkle.dart`, `material/list_tile.dart`, `material/filled_button.dart`, `material/outlined_button.dart`

## Правила

### Состояния

- Enabled, disabled, hover, focused, pressed, dragged (+ selected/activated). У состояния два визуальных признака; состояния комбинируются (например, selected + hover). В раскладке одновременно — не больше одного hover, одного focus, одного pressed, одного dragged.
- **State layer** — полупрозрачное наложение **цветом контента** (обычно on-роль контейнера): контейнер `secondaryContainer` → слой `onSecondaryContainer`; контейнер `surface` с контентом `primary` → слой `primary`. Порядок: контейнер → state layer → контент. Одновременно применяется один слой.
- Непрозрачность слоя: **hover 8%, focus 10%, pressed 10%, dragged 16%** (сайт и `StateTokens`).
- Размер state layer — 40dp при зоне нажатия 48dp (для круглых слоёв поверх части компонента).
- **Disabled**: не фокусируется, не нажимается, не реагирует на hover; не обязан соответствовать контрасту. Кнопки: контейнер `onSurface` × **0.1**, текст/иконка `onSurface` × **0.38**, обводка outlined — `outlineVariant`. Disabled наследуют кнопки, карточки, чекбоксы, чипы, list items, radio, switch, text fields; не наследуют app bars, badges, dialogs, FAB (недоступный FAB не показывать), menus, навигация, sheets, tabs, tooltips.
- **Hover** — низкая акцентность, «animated fade»; наследуют кнопки, карточки, чекбокс, чипы, пикеры, list items, slider, switch, text fields; не наследуют app bars, badges, dialogs, menus, навигация, sheets, tabs.
- **Focused** — высокая акцентность; для клавиатуры — кольцо **keyboard focus indicator**: толщина **3dp**, внешний отступ **2dp**, внутренний **−3dp**; цвет у компонентов — `secondary` (`md.comp.*.focus.indicator.color`).
- **Pressed** — высокая акцентность, **ripple**; кнопки и карточки могут подниматься по elevation. Нажатие мышью/стилусом даёт ту же обратную связь, что и касание.
- **Dragged** — низкая акцентность (16%), list items / chips / cards могут подниматься; кнопки и навигация не перетаскиваются.
- **Selection**: галочка, чекбокс, смена цвета поверхности или их сочетание; navigation bar / drawer / rail и tabs — active indicator, выбран только один пункт. Вход в режим выбора — long press или ярлык (тап по аватару).

### Expressive: форма как признак состояния

- «Use shape morph to better communicate interaction states, like when a button is selected» (`styles__shape.md`).
- Кнопки: в покое full, при нажатии — small (XS, S), medium (M), large (L, XL); выбранная toggle-кнопка из round становится square — medium (XS, S), large (M), extra-large (L, XL) (`ToggleButton.kt`, `SelectedContainerShapeSquare`).
- Standard button group: нажатая кнопка расширяется за счёт соседних (Compose `ButtonGroup`, FastSpatial).

## Как устроено в Compose

- `ripple()` рисует слой с `RippleDefaults.RippleAlpha` = pressed 0.1, focused 0.1, dragged 0.16, hovered 0.08 (`StateTokens`). Цвет — `LocalContentColor`.
- Фокус по умолчанию — **opacity** (`RippleDefaults.ThemeConfiguration = OpacityFocusThemeConfiguration`). Альтернатива — `InsetFocusRingThemeConfiguration`: внешняя обводка 2dp (inset 0), внутренняя 3dp (inset 1dp); появление — FastSpatial, исчезновение — FastEffects.
- Морф формы при нажатии: `shapeByInteraction(shapes, pressed, spec)` → `rememberAnimatedShape`; spec — DefaultEffects у `Button`/`IconButton`, FastSpatial у `ToggleButton` и selectable chips (`Chip.kt`, `SelectableChip` с `shapes`).
- Disabled-контейнер кнопки: `FilledButtonTokens.DisabledContainerOpacity` = 0.1, `DisabledLabelTextOpacity` = 0.38.
- `Modifier.minimumInteractiveComponentSize()` — цель 48dp.

## В приложении

### Как сейчас

- Стандартные виджеты Flutter M3 (`FilledButton`, `IconButton`, `NavigationBar`, `FilterChip`, `Checkbox`) — свои `overlayColor` c 8 / 10 / 10%.
- Кастомные элементы на голом `InkWell` без `overlayColor`: `widgets/day_selector.dart:155`, `widgets/connected_button_group.dart:133`, `widgets/lesson_card.dart:90`; `ListTile(onTap)` в `schedule_screen.dart:537`, `lesson_details_page.dart:170`, `group_picker_sheet.dart:292` — цвета из `ThemeData`.
- `lib/app.dart` не задаёт `splashColor`, `highlightColor`, `hoverColor`, `focusColor`, `splashFactory` → дефолты `theme_data.dart`: highlight `0x66BCBCBC` (светлая) / `0x40CCCCCC` (тёмная), splash `0x66C8C8C8` / `0x40CCCCCC`, hover чёрный/белый 4%, focus чёрный/белый 12%; на Android — `InkSparkle`.
- Морф формы при нажатии — `app_button_styles.dart` (`_morphingShape`), `connected_button_group.dart` (внутренние углы 8 → 4 при нажатии, 50% у выбранной); смена формы при выборе дня — `day_selector.dart` (16 → 28).

### Расхождения

| # | Сейчас | Должно быть | Источник |
|---|---|---|---|
| 1 | `InkWell` / `ListTile` без `overlayColor`: нажатие = серая подсветка `0x66BCBCBC` (40% серого) + sparkle; hover 4% и focus 12% чёрного — **не M3** | Слой цветом контента: pressed 10%, focus 10%, hover 8% (на `primary`-дне — `onPrimary`; на `surfaceContainer` — цвет его контента, на карточке текущей пары — `onPrimary`) | `foundations__interaction__states.md`, `tokens/StateTokens.kt`, `material/theme_data.dart:467–502`, `material/ink_well.dart` |
| 2 | Keyboard focus в кастомных элементах — только серый слой 12% | Слой 10% цветом контента; при необходимости кольца — 3dp, отступ 2dp, `secondary` | база токенов сайта (`md.sys.state.focus-indicator.*`), `components__buttons.md` |
| 3 | Disabled у кнопок — дефолты Flutter: контейнер filled `onSurface` × 0.12, обводка outlined `onSurface` × 0.12 (`certificate_sheet.dart` блокирует кнопки при отправке) | Контейнер `onSurface` × 0.1; обводка outlined — `outlineVariant`; текст × 0.38 | `components__buttons.md` (`md.comp.button.*.disabled.*`), `tokens/FilledButtonTokens.kt`, `material/filled_button.dart:550`, `material/outlined_button.dart:556` |
| 4 | `splashFactory` = `InkSparkle` (дефолт Flutter на Android) | Гайдлайн требует ripple; какой именно рисунок у Compose `ripple()` — модуля `material-ripple` в клоне нет, не проверял. Решение (InkSparkle или `InkRipple`) записать в отступления | `foundations__interaction__states.md` (Pressed), `material/theme_data.dart:415–420` |
| 5 | Морф кнопок при нажатии анимируется кривой `Curves.fastOutSlowIn` (см. `motion.md`), в `connected_button_group.dart` нет расширения нажатой кнопки | DefaultEffects для `Button`; расширение нажатой кнопки в standard button group — FastSpatial | `Button.kt`, `ButtonGroup.kt`, `components__button-groups.md` |
| 6 | Длительности появления подсветки у `InkWell` — 200 мс (pressed), 50 мс (hover/focus) — дефолт Flutter | Значений для state layer в гайдлайнах не нашёл; hover — «low-emphasis animated fade» | `material/ink_well.dart:997–1001`, `foundations__interaction__states.md` |

Что совпадает: слои 8 / 10 / 10% у стандартных виджетов Flutter; формы кнопок при нажатии; `Semantics(selected: …)` у дней и сегментов; зоны нажатия 48dp.

### Что сделать во Flutter

1. Завести `AppStateLayer.overlay(Color content)` → `WidgetStateProperty` (pressed/focused 0.10, hovered 0.08, dragged 0.16) и передавать в каждый `InkWell.overlayColor`; для `ListTile` — `ListTileThemeData`/параметры `splashColor`, `hoverColor`, `focusColor` плюс `highlightColor` у `ThemeData`.
2. В `buildTheme` задать запасные значения для всего, что без `overlayColor`: `splashColor` и `highlightColor` — `onSurface` × 0.10, `hoverColor` — `onSurface` × 0.08, `focusColor` — `onSurface` × 0.10 (цвет контента по умолчанию на surface-ролях — `onSurface`).
3. В `AppButtonStyles` переопределить disabled: `backgroundColor` → `onSurface` × 0.1; `side` outlined disabled → `outlineVariant`.
4. Решить и задокументировать `splashFactory`.
5. Морф при нажатии — на пружинах (`motion.md`), для группы кнопок — расширение нажатой кнопки.

# Material 3 Expressive в приложении — справочник

Рабочий справочник для разработки. У каждого компонента и стиля свой файл:
ссылки на гайдлайны m3.material.io, Compose Material3 и MDC-Android, ключевые
токены, поведение и движение, доступность, а также как это сделано в
приложении и какие расхождения остались. Правила работы — в
[`CLAUDE.md`](../../CLAUDE.md).

Текст гайдлайнов целиком (с Do/Don't и таблицами токенов) выгружается
скриптом `python tool/m3_guidelines.py` в `.m3-guidelines/`.

## Порядок источников

1. **m3.material.io** — что и когда использовать, токены, доступность.
2. **Compose Material3** (`androidx/compose/material3`) — эталонная реализация
   Expressive: точные значения, какой токен `MotionScheme` что анимирует,
   взаимодействия.
3. **MDC-Android** — когда первых двух не хватает.

Если источники расходятся, в файле компонента записано, что выбрано и почему.

## Стили

| Тема | Файл |
|---|---|
| Движение: пружины, переходы | [styles/motion.md](styles/motion.md) |
| Форма: шкала скруглений, MaterialShapes, морфинг | [styles/shape.md](styles/shape.md) |
| Цвет: роли, динамические цвета, дополнительные цвета | [styles/color.md](styles/color.md) |
| Типографика: шкала, emphasized, шрифт | [styles/typography.md](styles/typography.md) |
| Высота и scrim | [styles/elevation.md](styles/elevation.md) |
| Иконки: Material Symbols, оси, размеры | [styles/icons.md](styles/icons.md) |
| Раскладка, отступы, breakpoints | [styles/layout.md](styles/layout.md) |
| Состояния взаимодействия, state layer | [styles/interaction-states.md](styles/interaction-states.md) |
| Доступность | [styles/accessibility.md](styles/accessibility.md) |

## Компоненты

Статус — в первой строке каждого файла (✅ соответствует, ⚠️ частично,
❌ не соответствует, — не используется).

| Группа | Компоненты |
|---|---|
| Кнопки | [выбор кнопки](components/all-buttons.md), [кнопки](components/buttons.md), [icon buttons](components/icon-buttons.md), [группы кнопок](components/button-groups.md), [FAB](components/floating-action-button.md), [extended FAB](components/extended-fab.md), [FAB menu](components/fab-menu.md), [split button](components/split-button.md), [segmented button](components/segmented-buttons.md) (устарел) |
| Выбор и ввод | [переключатель](components/switch.md), [чекбокс](components/checkbox.md), [радиокнопка](components/radio-button.md), [чипы](components/chips.md), [поиск](components/search.md), [текстовые поля](components/text-fields.md), [меню](components/menus.md), [слайдеры](components/sliders.md) |
| Навигация и контейнеры | [navigation bar](components/navigation-bar.md), [app bars](components/app-bars.md), [toolbars](components/toolbars.md), [tabs](components/tabs.md), [нижний лист](components/bottom-sheets.md), [диалоги](components/dialogs.md), [карточки](components/cards.md), [списки](components/lists.md), [разделитель](components/divider.md), [карусель](components/carousel.md), [navigation rail](components/navigation-rail.md), [navigation drawer](components/navigation-drawer.md), [side sheets](components/side-sheets.md) |
| Индикаторы и обратная связь | [индикатор загрузки](components/loading-indicator.md), [индикаторы прогресса](components/progress-indicators.md), [pull-to-refresh](components/pull-to-refresh.md), [badges](components/badges.md), [снекбар](components/snackbar.md), [подсказки](components/tooltips.md) |

## Реализация во Flutter

Flutter 3.44 не поставляет большинство Expressive-компонентов и `MotionScheme`,
поэтому они портированы с Compose в `lib/widgets/` и `lib/theme/`:

| Что | Где |
|---|---|
| Пружины `MotionScheme`, `springTo`, уменьшение движения | `lib/theme/app_motion.dart` |
| Переходы fade through / shared axis | `lib/theme/app_transitions.dart` |
| Pager (lateral) | `lib/widgets/m3_pager.dart` |
| State layer | `lib/theme/app_state_layer.dart` |
| Отступы | `lib/theme/app_spacing.dart` |
| Динамические цвета Android 14+ | `lib/theme/system_color_roles.dart`, `MainActivity.kt` |
| Статусные цвета (custom colors) | `lib/theme/status_colors.dart` |
| Снекбар | `lib/widgets/m3_snackbar.dart` |
| Остальные компоненты | `lib/widgets/m3_*.dart` — см. раздел «Реализация во Flutter» в файле компонента |

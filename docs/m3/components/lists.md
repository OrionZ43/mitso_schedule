# Списки (Lists)

Статус в приложении: ✅ соответствует — задачи, справки, профиль, результаты поиска и выбор группы на `M3ListItem` (пары с 17.09.2026 — карточки, см. `cards.md`)

> Разделы «В приложении → Расхождения» ниже описывают состояние до порта (16.09.2026); что сделано и что осталось — в «Реализация во Flutter» и в README.

Segmented-список собран верно: зазор 2dp, крайние углы 16dp, внутренние 4dp. Но пункты
статичные. Нет морфинга формы при нажатии и выделения выбранного пункта, внутренние отступы —
дефолты Flutter `ListTile` (baseline), а не токены expressive-списка.

## Источники
- Guidelines / Specs / Accessibility: https://m3.material.io/components/lists/guidelines,
  https://m3.material.io/components/lists/specs, https://m3.material.io/components/lists/accessibility
  (выгрузка: `.m3-guidelines/components__lists.md`, обновление December 2025)
- Compose API: https://developer.android.com/reference/kotlin/androidx/compose/material3/package-summary —
  `ListItem(...)` (стандартный), `SegmentedListItem(shapes, ...)` / `SegmentedListItem(onClick, shapes, ...)` /
  перегрузки с `selected` и `checked`, `ListItemDefaults.segmentedShapes(index, count, defaultShapes)`,
  `ListItemDefaults.shapes(shape, selectedShape, pressedShape, focusedShape, hoveredShape, draggedShape)`,
  `ListItemDefaults.colors()` / `segmentedColors()`, `ListItemDefaults.SegmentedGap`, `ListItemDefaults.ContentPadding`,
  `ListItemDefaults.verticalAlignment()`
- Compose исходник: `ListItem.kt` (`SegmentedListItem`, `InteractiveListItem` — анимации формы, цвета и
  elevation, `InteractiveListStartPadding` / `EndPadding` / `InternalSpacing`, `InteractiveListVerticalAlignmentBreakpoint`),
  `ListItemDefaults.kt` (`segmentedShapes`, `defaultListItemShapes`, `defaultSegmentedListItemColors`), токены
  `tokens/ListTokens.kt`, `tokens/ReorderListTokens.kt`, примеры `samples/ListSamples.kt` (`SegmentedListItems`,
  `SingleSelectionSegmentedListItemSample`, `MultiSelectionSegmentedListItemSample`, `SegmentedListItemWithExpansionSample`)
- MDC: https://github.com/material-components/material-components-android/blob/master/docs/components/List.md
  (раздел «M3 Expressive»: `ListItemLayout` с состояниями `state_first` / `state_middle` / `state_last` /
  `state_single`, `ListItemCardView` меняет углы по состоянию, стиль `listItemCardViewSegmentedStyle`,
  swipe-to-reveal `ListItemRevealLayout`)
- Flutter: `ListTile`, `SwitchListTile`, `CheckboxListTile`, `RadioListTile`, `ListTileThemeData`
  (`packages/flutter/lib/src/material/list_tile.dart`).
  - Есть: высоты 56/72/88, `contentPadding`, `minVerticalPadding`, `horizontalTitleGap`,
    `shape`, `tileColor`, `selected` и `selectedTileColor`, `titleAlignment`.
  - M3-дефолты (`_LisTileDefaultsM3`) — **baseline**: отступы 16 в начале и 24 в конце,
    `minVerticalPadding` 8, `horizontalTitleGap` 16, выбранный пункт окрашивает текст в `primary`.
  - Нет: segmented-варианта, формы по состоянию (нажат, выбран, в фокусе), анимации формы и цвета
    контейнера.

## Когда использовать
- Список помогает найти пункт и выполнить с ним действие. Пункты упорядочены логично, короткие,
  одного формата (Overview).
- **Expressive** список рекомендован для новых дизайнов, baseline — «Not recommended»
  (Specs → Variants). Стили **standard** и **segmented** — чисто визуальный выбор.
- Режимы — у списка только один одновременно: single-action (весь пункт — одно действие, например
  переход), multi-action, single-select (radio), multi-select (checkbox или switch),
  non-interactive (Guidelines → List selection modes).
- **Разделение:** в «контейнерных» списках — зазоры, разделители только в неконтейнерных или
  сложных (Guidelines → Gaps & dividers).
- На compact экранах список растянут от края до края, выбор пункта открывает детали
  (Adaptive → Compact).

## Варианты и анатомия
- Анатомия: контейнер и подпись обязательны. Необязательные элементы: overline, supporting text,
  trailing text, leading и trailing icon, leading avatar, image или video, selection control, divider.
- Слоты: leading, content (самый широкий), trailing. Кастомные слоты не должны ломать
  доступность: стандартные отступы, зоны нажатия от 48dp.
- Выравнивание: по центру. Если пункт выше 88dp или в нём от трёх строк — по верху. В Compose
  порог — середина между 72 и 88dp за вычетом вертикальных отступов
  (`InteractiveListVerticalAlignmentBreakpoint`).

## Размеры, формы, цвета
| Элемент | Значение | Источник |
|---|---|---|
| Высота | 56 / 72 / 88dp (1 / 2 / 3 строки) | `md.comp.list.list-item.*-line.container.height` |
| Отступы пункта | 16dp в начале и в конце, 10dp сверху и снизу, **12dp** между слотами | `md.comp.list.list-item.leading-space` / `trailing-space` = space200, `top-space` / `bottom-space` = space125, `between-space` = space150; `ListTokens.ItemLeadingSpace` / `ItemTopSpace` / `ItemBetweenSpace` |
| Зазор segmented | 2dp | `md.comp.list.segmented.gap` = space25; `ListItemDefaults.SegmentedGap` |
| Форма пункта (expressive) | 4dp (`corner.extra-small`); у крайних пунктов segmented наружные углы 16dp (`ListTokens.ContainerShape` = `corner.large`) | `ItemContainerExpressiveShape`; `ListItemDefaults.segmentedShapes` |
| Форма при нажатии / выборе / фокусе | 16dp со всех сторон (`corner.large`) | `ItemPressedContainerExpressiveShape`, `ItemSelectedContainerExpressiveShape`, `ItemFocusedContainerExpressiveShape`; Specs → Shape morphing |
| Форма при наведении / перетаскивании | 12dp (`corner.medium`) / 16dp | `ItemHoveredContainerExpressiveShape`; `ReorderListTokens.ItemShape` |
| Контейнер | `surface` (standard и segmented); выбранный — `secondaryContainer` | `md.comp.list.list-item.segmented.container.color`, `selected.container.color` |
| Текст | label `bodyLarge` `onSurface`; supporting `bodyMedium` `onSurfaceVariant`; overline и trailing text `labelSmall` `onSurfaceVariant`; у выбранного всё `onSecondaryContainer` | `ListTokens.ItemLabelTextFont` и др. |
| Иконки | leading и trailing `onSurfaceVariant`; 24dp baseline, 20dp expressive-токен (Compose его не применяет автоматически) | `ItemLeadingIconColor`, `ItemLeadingIconExpressiveSize` |
| Avatar | 40dp, `primaryContainer` / `onPrimaryContainer`, label `titleMedium` | `ItemLeadingAvatar*` |
| State layer | `onSurface`, hover 8%, pressed 10% | `md.comp.list.list-item.*.state-layer.*` |
| Dragged | elevation level4 (8dp) | `ListTokens.ItemDraggedContainerElevation` |

В примерах Compose (`SegmentedListItems`, `SingleSelectionSegmentedListItemSample`) у segmented-пунктов
`containerColor = MaterialTheme.colorScheme.surfaceContainer`: на фоне `surface` пункты отделяются
от фона.

## Состояния и движение
`InteractiveListItem` (`ListItem.kt`):
- **Форма:** `shapes.shapeForInteraction(selected, pressed, focused, hovered, dragged, animationSpec)`
  с `shapeAnimationSpec = MotionSchemeKeyTokens.FastSpatial` (800 / 0.6, заметный перелёт).
  Нажатие скругляет все углы пункта до 16dp. При отпускании форма возвращается к позиционной:
  4dp внутри и 16dp снаружи. Выбранный пункт держит 16dp.
- **Цвета** контейнера, текста, leading, trailing, overline и supporting — `updateTransition` +
  `animateColor(MotionSchemeKeyTokens.DefaultEffects)`.
- **Elevation** при перетаскивании — `animateDpAsState(MotionSchemeKeyTokens.FastSpatial)`,
  перетаскиваемый пункт уходит на верхний `zIndex`.
- **Ripple:** `ripple(focusRingShape = shape)`, контейнер обрезается текущей формой.
- **Раскрытие пункта** (expand) — container transform (Guidelines → Expand & collapse).
- **Swipe-to-reveal** есть только в Android Views (MDC `ListItemRevealLayout`).

## Доступность
- Выбор нельзя показывать только цветом: нужен второй признак — radio или checkbox, иконка или
  стиль текста (Accessibility → Indicate selection with more than color).
- Метка пункта — label + supporting text. В Compose роль у всего пункта: single-select — Radio
  button, multi-select — Checkbox, для неинтерактивного пункта роли нет.
- Клавиатура: Tab переводит фокус на первый или выбранный пункт, стрелки перемещают с переходом
  по кругу, Space или Enter активируют.
- Swipe-действия дублируются одиночным действием, например кнопкой «ещё».

## В приложении

### Реализация во Flutter

`lib/widgets/segmented_list.dart` переписан. Экраны пока передают в `SegmentedList` старые
`ListTile` / `SwitchListTile`: они по-прежнему лежат в статичном контейнере 16/4, поэтому
«Где используется» и расхождения ниже описывают экраны до перевода на `M3ListItem`.

- API:
  - `M3ListItem({required Widget headline, Widget? leading, Widget? overline, Widget? supporting, Widget? trailing, VoidCallback? onTap, VoidCallback? onLongPress, bool selected = false, bool enabled = true, Color? containerColor, String? semanticsLabel})`;
  - `SegmentedList({required List<Widget> children})` — зазор 2dp, позицию каждому ребёнку отдаёт
    `SegmentedListPosition(index, count)` (его же можно поставить вручную в `ListView.builder`);
    `SegmentedList.shapeFor(index, count)` — `segmentedShapes`.
- Точно по Compose:
  - раскладка — свой `RenderBox`, порт `InteractiveListItemMeasurePolicy`: поля 16/16/10/10, 12dp
    между слотами, минимальная высота 56/72/88 по `ListItemType`, выравнивание по центру, по верху —
    от 60dp внутренней высоты (`InteractiveListVerticalAlignmentBreakpoint`);
  - стили и цвета слотов по `ListTokens`: `bodyLarge` `onSurface`, `bodyMedium` / `labelSmall`
    `onSurfaceVariant`, иконки `onSurfaceVariant`, текст в leading — `titleMedium`; selected — всё
    `onSecondaryContainer` на `secondaryContainer`; disabled — `onSurface` 38%;
  - форма: позиционная `segmentedShapes` (одиночный 16, первый 16/4, средние 4, последний 4/16),
    без позиции — 4dp (`ListItemDefaults.shapes()`); по состояниям `shapeForInteraction`:
    pressed → selected → focused — 16dp, hovered — 12dp; морфинг — порт `AnimatedShapeState`
    (разворот с сохранением скорости, от видимой формы к новой цели) на пружине FastSpatial;
    смена позиции применяется без морфинга, как `key(shapes)` в Compose;
  - цвета — пружина DefaultEffects;
  - ripple обрезан текущей формой (`clipBehavior` контейнера), state layer — `AppStateLayer`
    цветом содержимого;
  - производительность: на кадрах морфинга перестраивается только контейнер (`Material` с
    `animationDuration: Duration.zero` — без собственного твина формы поверх пружины), содержимое
    и `InkWell` передаются в него готовыми; при смене цветов перестраивается содержимое;
  - leading image — справки на «Пропусках»: 56×56dp, форма `corner.small`
    (`md.comp.list.list-item.leading-image` и `.expressive.shape`);
  - семантика: `MergeSemantics`, button у нажимаемого пункта, флаг selected, enabled;
    `semanticsLabel` заменяет текст слотов.
- Отступления:
  1. Многострочный supporting определяется эвристикой Compose из intrinsic-замера (выше 30sp с
     учётом масштаба шрифта): `RenderBox` отдаёт только первую базовую линию, а Compose сравнивает
     первую и последнюю.
  2. Цвета интерполируются в sRGB (`Color.lerp`), в Compose — в Oklab.
  3. Нет dragged-состояния (перетаскивание не используется) и ролей radio / checkbox у выбираемых
     пунктов: второй признак выбора (иконка, radio) и роль добавляет экран.
  4. Disabled-контейнер — заданный `containerColor`. В Compose при переопределении `containerColor`
     disabled-контейнер остаётся `surface`, и отключённый пункт выпадал бы из списка.
  5. Контейнер по умолчанию `surfaceContainer`, как в примерах Compose (README, отступление 14).
  6. Compose уменьшает `LocalMinimumInteractiveComponentSize` для контролов в слотах; во Flutter
     зона нажатия контролов в слотах не меняется.
  7. `M3ListItem` должен быть прямым ребёнком `SegmentedList`: обёртка вокруг него получит
     статичный контейнер, и морфинг спрячется под ним.

- Где используется:
  - `lib/widgets/segmented_list.dart` → `SegmentedList`: `Material` на каждый пункт,
    `surfaceContainer`, углы 16/4, зазор 2dp, внутри `ListTile` / `SwitchListTile`;
  - `lib/features/profile/profile_screen.dart` → «Настройки»: 3 × `SwitchListTile` в `SegmentedList`
    (multi-select на переключателях);
  - `lib/features/group_picker/group_picker_sheet.dart` → варианты шага: `ListTile` + chevron,
    текущая группа отмечена иконкой `check`;
  - `lib/features/schedule/lesson_details_page.dart`:
    - «Преподаватель и аудитория» — неинтерактивные пункты;
    - «Дальше по предмету» — single-action с chevron;
  - `lib/features/schedule/schedule_screen.dart` → результаты поиска: `ListTile` с
    `shape: AppShapes.rounded(AppShapes.largeIncreased)` (20dp);
  - `lib/widgets/lesson_card.dart` → `_SubgroupRows`: мини-segmented внутри карточки
    (16/4, зазор 2dp), не список;
  - `lib/app.dart` → `listTileTheme`: `bodyLarge`, `bodyMedium` `onSurfaceVariant`, иконки `onSurfaceVariant`.
- Уже соответствует:
  - segmented-геометрия в покое: зазор 2dp, наружные углы 16dp, внутренние 4dp, одиночный пункт
    16dp со всех сторон;
  - цвет пунктов `surfaceContainer` — как в примерах Compose;
  - типографика и цвета текста;
  - высоты 56/72/88;
  - разделение зазорами, без разделителей;
  - неинтерактивные пункты без ripple.
- Расхождения:
  1. **Морфинг формы при нажатии.** Сейчас форма статична. Должно: при нажатии и фокусе все углы
     16dp, при наведении 12dp, пружина FastSpatial, возврат к позиционной форме. Источник:
     `ListTokens.ItemPressedContainerExpressiveShape` / `ItemFocusedContainerExpressiveShape` /
     `ItemHoveredContainerExpressiveShape`; `InteractiveListItem` → `shapeAnimationSpec`;
     Specs → Shape morphing.
  2. **Отступы.** Сейчас дефолты baseline `ListTile`: 16 в начале, **24** в конце, минимум **8**
     сверху и снизу, **16** между иконкой и текстом. Должно: 16 / 16 / 10 / 12. Источник:
     `md.comp.list.list-item.*-space`; `ListItemDefaults.ContentPadding`,
     `InteractiveListInternalSpacing`.
  3. **Текущая группа в листе выбора.** Сейчас отмечена только иконкой `check`, контейнер обычный.
     Должно: selected-состояние — `secondaryContainer`, текст и иконки `onSecondaryContainer`,
     углы 16dp со всех сторон, иконка `check` как второй признак. Смена цвета — DefaultEffects,
     формы — FastSpatial. Источник: `md.comp.list.list-item.selected.*`; Accessibility → Indicate
     selection; `SingleSelectionSegmentedListItemSample`.
  4. **Форма результатов поиска.** Сейчас 20dp (`AppShapes.largeIncreased`) у каждого пункта. Такой
     формы у пункта списка нет. Должно: standard expressive — 4dp в покое и 16dp при нажатии, или
     segmented. Источник: `ListTokens.ItemContainerExpressiveShape`, `segmentedShapes`.
  5. **Заголовки секций** («Настройки», «Палитра», «Подгруппы», «Дальше по предмету»). В профиле
     `bodyMedium` w500 с отступом 26dp, на странице пары `titleSmall` `onSurfaceVariant` с
     отступом 8dp. Токена заголовка секции в спецификации списков нет. Должно: один стиль на всё
     приложение, решение записать в README. Источник: нет, это пробел спецификации.
  6. **Роль выбираемого пункта.** Сейчас у пунктов листа выбора группы нет `selected` в семантике.
     Должно: `Semantics(selected: true)` у текущей группы. Источник: Accessibility →
     Platform-specific labels.
- Что сделать во Flutter:
  1. Переписать `SegmentedList` на порт `SegmentedListItem`: свой виджет пункта вместо обёртки
     `Material` вокруг `ListTile`.
     - `WidgetStatesController` + `InkWell(statesController: ...)` на всю площадь.
     - Форма: `RoundedRectangleBorder` с четырьмя радиусами, анимируемыми одной пружиной.
       `AnimationController.unbounded`, `animateWith(AppMotion.fastSpatial.simulate(...))`, прогресс
       0 → позиционная форма, 1 → 16dp со всех сторон. Для hover цель 12dp. Selected держит 1.
     - Цвет контейнера: `surfaceContainer` → `secondaryContainer` при `selected` через
       `TweenAnimationBuilder<Color?>` с `AppMotion.defaultEffects.duration` / `.curve`. Так же
       цвета текста и иконок → `onSecondaryContainer`.
     - `Material(shape: animatedShape, clipBehavior: Clip.antiAlias)`, чтобы ripple обрезался текущей
       формой.
     - Раскладка: `Padding(EdgeInsetsDirectional.fromSTEB(16, 10, 16, 10))`, leading → 12dp →
       content (`Expanded`) → 12dp → trailing, минимальные высоты 56/72/88, выравнивание по центру
       или по верху по порогу.
  2. Пока порта нет, хотя бы выставить токенные отступы в `listTileTheme`:
     `contentPadding: EdgeInsetsDirectional.symmetric(horizontal: 16)`, `minVerticalPadding: 10`,
     `horizontalTitleGap: 12`, `minLeadingWidth: 24`.
  3. `group_picker_sheet.dart`: у текущей группы `selected: true` (цвет и форма из пункта 1) и
     `Semantics(selected: true)`.
  4. `schedule_screen.dart`: у результатов поиска убрать `shape: AppShapes.rounded(AppShapes.largeIncreased)`
     и использовать пункт из пункта 1 (standard: 4dp и 16dp при нажатии) или `SegmentedList`.

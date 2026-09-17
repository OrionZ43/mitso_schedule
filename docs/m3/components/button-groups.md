# Группы кнопок (Button groups)

Статус в приложении: ✅ соответствует — лента дней на `M3ButtonGroup`, фильтры и настройки на `ConnectedButtonGroup` (отступления — README, п. 3, 15)

> Разделы «В приложении → Расхождения» ниже описывают состояние до порта (16.09.2026); что сделано и что осталось — в «Реализация во Flutter» и в README.

## Источники
- Guidelines / Specs / Accessibility: https://m3.material.io/components/button-groups/guidelines (и /specs, /accessibility); дамп `.m3-guidelines/components__button-groups.md`
- Compose API: https://developer.android.com/reference/kotlin/androidx/compose/material3/package-summary —
  `ButtonGroup(overflowIndicator, modifier, expandedRatio, horizontalArrangement, verticalAlignment, content)`,
  `ButtonGroupScope.clickableItem(…)`, `toggleableItem(…)`, `customItem(…)`,
  `Modifier.animateWidth(interactionSource)`, `Modifier.animateWidth(interactionSource, compressionLimit)`, `Modifier.weight`,
  `ButtonGroupDefaults.ExpandedRatio`, `.HorizontalArrangement`, `.ConnectedSpaceBetween`,
  `.connectedLeadingButtonShapes()`, `.connectedMiddleButtonShapes()`, `.connectedTrailingButtonShapes()`, `.connectedButtonCheckedShape`, `.OverflowIndicator`,
  `ToggleButton(checked, onCheckedChange, shapes, …)`
- Compose исходник: `ButtonGroup.kt` (`ButtonGroup`, `ButtonGroupMeasurePolicy.measure` — расчёт ширин; `EnlargeOnPressNode.launchCollectionJob` — анимация нажатия; `ButtonGroupParentData`; `ToggleableButtonGroupItem`), `ToggleButton.kt` (`shapeByInteraction`); токены `ButtonGroupSmallTokens.kt`, `ConnectedButtonGroupSmallTokens.kt`, `ExpressiveMotionTokens.kt`; примеры `ButtonGroupSamples.kt` (`ButtonGroupSample`, `ButtonGroupWithCustomItemSample`, `SingleSelectConnectedButtonGroupSample`, `MultiSelectConnectedButtonGroupSample`, `VerticalButtonGroupSample`)
- MDC: https://github.com/material-components/material-components-android/blob/master/docs/components/ButtonGroup.md. Стили `Widget.Material3Expressive.MaterialButtonGroup` и `.Connected`; `android:spacing` 12dp; `app:childSizeChange` 15% в pressed; `app:overflowMode` none/menu/wrap. Реализация — `MaterialButtonGroup.java` (`onButtonWidthChanged`), `MaterialButton.java` (`maybeAnimateSize`, `SpringAnimation` на `motionSpringFastSpatial`).
- Flutter: **виджета нет**. `SegmentedButton` — устаревший baseline-компонент, `ToggleButtons` — M2. Поведение (расширение нажатой кнопки, сжатие соседей, морф toggle-формы) нужно портировать из Compose.

## Когда использовать
- **Standard button group** — связанные действия, которые реагируют друг на друга: нажатая или выбранная кнопка меняет форму и ширину, соседние временно сужаются, выбранная toggle-кнопка меняет цвет. Пример из спеки — кнопки видеозвонка, калькулятор.
- **Connected button group** — выбор вариантов, переключение вида, сортировка; только с toggle-кнопками (single- или multi-select). Заменяет segmented button. На соседей не влияет.
- По умолчанию все кнопки группы одного размера и формы. Разные размеры — только для «hero moments». Другая форма — только у выбранной кнопки или ради смысла.
- Группа идёт **одной строкой и не переносится**. На узких экранах крайние кнопки могут уходить в overflow-меню в конце группы. Но MDC прямо запрещает menu-overflow для toggle-групп: «toggle button group should demonstrate all available options and the current selection». Прокрутка группы в гайдлайнах **не описана** (у chips описана).
- Connected group растягивается на ширину страницы или поверхности; на больших окнах — с максимальной шириной. Standard group обнимает свои кнопки по ширине.
- Не смешивать цветовые стили в connected group. Не использовать standard icon buttons и text buttons — у них нет контейнера.

## Варианты и анатомия
- Варианты: standard, connected. Размеры XS, S, M, L, XL (по размеру кнопок). Форма по умолчанию round или square. Выбор: single-select, multi-select, selection-required.
- Анатомия: невидимый контейнер, который задаёт промежутки и меняет формы кнопок. Кнопок по умолчанию в нём нет.

## Размеры, формы, цвета
| Токен | XS | S | M | L | XL |
|---|---|---|---|---|---|
| Высота (обе группы) | 32dp | 40dp | 56dp | 96dp | 136dp |
| Промежуток standard (`standard.*.between-space`) | 18dp | 12dp | 8dp | 8dp | 8dp |
| Промежуток connected (`connected.*.between-space`) | 2dp | 2dp | 2dp | 2dp | 2dp |
| Внутренние углы connected | 8dp по токену (`connected.xsmall.inner-corner` = `corner-value.small`), 4dp на схеме Measurements | 8dp | 8dp | 16dp | 20dp |
| Внутренние углы connected, pressed | 4dp | 4dp | 4dp | 12dp | 16dp |
| Внутренние углы connected, selected | 50% | 50% | 50% | 50% | 50% |
| Pressed: множитель ширины standard | 15% | 15% | 15% | 15% | 15% |
| Pressed: пружина ширины standard | fast.spatial | fast.spatial | fast.spatial | fast.spatial | fast.spatial |

- Внешние углы connected — `corner.full`. У square-группы внешние углы равны внутренним из таблицы.
- Compose берёт только Small: `ButtonGroupSmallTokens.BetweenSpace = 12dp`, `ConnectedButtonGroupSmallTokens.BetweenSpace = 2dp`, `InnerCornerCornerSize = CornerValueSmall` (8dp), `PressedInnerCornerCornerSize = CornerValueExtraSmall` (4dp), `SelectedInnerCornerCornerSizePercent = 50`.
- Формы connected в Compose (`ButtonGroupDefaults`): leading — full слева и 8dp справа, pressed 4dp справа; middle — `ShapeDefaults.Small` (8dp все углы), pressed 4dp; trailing — зеркально leading; checked у всех — `ShapeTokens.CornerFull`.
- Цвета: у группы своих нет, берутся из стилей кнопок / toggle-кнопок (filled, tonal, outlined, elevated). Filled toggle: невыбранная — surfaceContainer / onSurfaceVariant, выбранная — primary / onPrimary (`FilledButtonTokens.UnselectedContainerColor`, `SelectedContainerColor`).

## Состояния и движение
### Нажатие в standard group — расширение нажатой и сжатие соседей
Точная реализация Compose (`ButtonGroup.kt`):

1. **Прогресс нажатия.** У каждой кнопки с `Modifier.animateWidth(...)` свой `Animatable(0f)` (`EnlargeOnPressNode.pressedAnimatable`). Узел слушает `interactionSource`: пока есть активный `PressInteraction.Press`, запускает `animateTo(1f, spec)`. Когда нажатий не осталось (Release/Cancel), сначала `waitUntil { pressedAnimatable.value > 0.75f }` (не дольше `MAX_WAIT_TIME_MILLIS = 1000`), потом `animateTo(0f, spec)`. Поэтому даже короткий тап доводит расширение минимум до 75%. `collectLatest` отменяет возврат, если кнопку снова нажали.
2. **Пружина.** `spec = MotionSchemeKeyTokens.FastSpatial` (задаётся в `ButtonGroup(...)` и передаётся всем элементам через `ButtonGroupScopeImpl`). В Expressive это stiffness 800, damping 0.6 (`ExpressiveMotionTokens.SpringFastSpatial*`). На m3.material.io то же: `md.comp.button-group.standard.*.pressed.item.width.motion.spring` = `fast.spatial`. Прогресс не ограничен [0, 1], поэтому перелёт пружины (damping 0.6) виден и на ширине.
3. **Коэффициент.** `ButtonGroupDefaults.ExpandedRatio = 0.15f` (токен `pressed.item.width.multiplier` = 15%). `expandedRatio = 0` отключает эффект, `1f` даёт до 200% ширины (в `ButtonGroupWithCustomItemSample` передан `1f`).
4. **Предел сжатия соседа** `compressionLimit` (`ButtonGroupParentData`): явный из `animateWidth(interactionSource, compressionLimit)`, иначе `ButtonDefaults.ContentPadding.calculateEndPadding(layoutDirection)` = **24dp** (`BaselineButtonTokens.TrailingSpace`). `clickableItem`/`toggleableItem` передают end-отступ `ContentPadding` или `ButtonWithIconContentPadding` (тоже 24dp). Смысл: сосед сжимается не больше своего внутреннего отступа, текст не обрезается.
5. **Расчёт ширины** (`ButtonGroupMeasurePolicy.measure`). Сначала каждая кнопка получает обычную ширину `w` (intrinsic или по `weight`). Затем для каждой кнопки с прогрессом `p ≠ 0`:
   - **первая:** `g = round(p · min(0.15·w₀, limit₁))`; сосед справа `w₁ -= min(g, w₁)`; сама `w₀ +=` снятое;
   - **последняя:** зеркально, за счёт левого соседа;
   - **средняя:** `g = round(p · min(0.15·wᵢ/2, limitᵢ₋₁, limitᵢ₊₁))`; каждый сосед теряет `min(g, w)`; сама получает сумму (до `2g`).
   Промежутки не меняются, **общая ширина группы постоянна**: соседи отдают ровно столько, сколько получила нажатая. Лейаут вокруг не двигается («animate without affecting their surroundings»). Потом каждая кнопка измеряется с жёсткой шириной, содержимое центрируется (`Row(horizontalArrangement = Center)`). Текст в DSL-элементах — `maxLines = 1, softWrap = false, overflow = Visible`.
6. **MDC** делает то же иначе: `MaterialButton.maybeAnimateSize` → `SpringAnimation` на `motionSpringFastSpatial`, прирост = `min(childSizeChange 15% от ширины, widthChangeMax)`. Предел — сумма `allowedWidthDecrease` соседей (ширина минус текст и иконка, то есть оба внутренних отступа). У средней кнопки прирост делится между соседями пополам (`MaterialButtonGroup.onButtonWidthChanged`).

### Выбор toggle-кнопки
- Форма (`ToggleButton.kt`, `shapeByInteraction`): pressed > checked > shape, морф `rememberAnimatedShape` на `MotionSchemeKeyTokens.FastSpatial`. Round (невыбранная) → square (выбранная); если по умолчанию square — выбранная round.
- `ToggleButtonDefaults.shapesFor(height)`: shape всегда full; pressed/checked по корзине высоты — ≤36dp XS: 8/12dp; ≤48dp S: 6/12dp (pressed 6dp — `RoundedCornerShape(6.dp)` в Compose, в спеке S pressed 8dp); ≤76dp M: 12/16dp; ≤116dp L: 16/28dp; больше — XL: 16/28dp.
- Цвет: в Compose `ToggleButton` цвет контейнера и текста **меняется без анимации** (`colors.containerColor(enabled, checked)` → `Surface`). Анимируются только форма, толщина обводки (`FastSpatial`) и цвет обводки (`DefaultEffects`).
- **Connected group**: меняется только форма нажатой/выбранной кнопки, соседи не двигаются. В сэмплах Compose connected group — это `FlowRow` с `Arrangement.spacedBy(ButtonGroupDefaults.ConnectedSpaceBetween)` и `ToggleButton` без `animateWidth`.

## Доступность
- У каждой кнопки зона нажатия ≥ 48×48dp. У XS и S увеличенные промежутки ради этого — не уменьшать. У XS/S connected минимальная ширина 48dp.
- Контейнер группы не фокусируется и не озвучивается; фокус начинается на первой кнопке. Tab — следующая, Space/Enter — нажатие/выбор.
- Каждую кнопку подписывать по правилам кнопок и icon buttons; выбранное состояние должно считываться. Compose-сэмплы single-select ставят `Modifier.semantics { role = Role.RadioButton }`. Во Flutter аналог — `Semantics(selected:, inMutuallyExclusiveGroup: true)`, так делает `SegmentedButton`.

## В приложении
- Где используется:
  - `lib/widgets/day_selector.dart` — горизонтальная прокручиваемая лента дней (`_DayChip`), по смыслу single-select, selection-required.
  - `lib/widgets/connected_button_group.dart` — `ConnectedButtonGroup<T>`; используется в `lib/features/notes/notes_screen.dart` (фильтр «Активные / Выполненные») и `lib/features/profile/profile_screen.dart` (подгруппа «Обе / 1-я / 2-я»).

### Селектор дней (`day_selector.dart`) — ❌
Какой это компонент по гайдлайнам. Выбор одного дня из связанного набора, соседи должны реагировать на нажатие — это **standard button group из toggle-кнопок** (single-select, selection-required). Только у standard group есть взаимодействие между соседями. Connected group его явно не имеет. Segmented button устарел и ограничен 5 пунктами. У chips есть прокрутка, но нет взаимодействия.

Расхождения (сейчас → должно быть → источник):
1. Нажатие не влияет на соседей и на ширину → нажатая кнопка расширяется на 15% за счёт соседей (предел — отступ соседа), пружина FastSpatial, возврат после ≥75% → Specs «Selection & activation», токены `pressed.item.width.*`, `ButtonGroup.kt` (выше).
2. Формы не морфятся при нажатии; при выборе радиус 16 → 28dp (`AppShapes.dayUnselected` → `extraLarge`) — таких значений в токенах нет → pressed-форма и выбранная форма по размеру кнопки. Для «плитки» ~75dp (корзина M в `ToggleButtonDefaults.shapesFor`): при square по умолчанию — 16dp (`md.comp.button.medium.container.shape.square`), выбранная — full (`medium.selected.container.shape.square`), pressed — 12dp (`medium.pressed.container.shape`). При round по умолчанию — full, выбранная 16dp, pressed 12dp.
3. Промежуток 10dp → 12dp (S) или 8dp (M) → `standard.*.between-space`.
4. Цвет числа onSurface, названия дня onSurfaceVariant; у выбранной — onPrimary с альфой 0.82 → у filled toggle один цвет содержимого: onSurfaceVariant (невыбрана) / onPrimary (выбрана) → `md.comp.button.filled.unselected.label-text.color`, `selected.label-text.color`; «Icons and labels now share the same color».
5. Цвет контейнера и текста анимируется `DefaultEffects` → в Compose `ToggleButton` цвет меняется мгновенно → `ToggleButton.kt`. Оставить можно только как записанное отступление.
6. Подпись в две строки (день + число) → у кнопки подпись в одну строку, без переноса → Buttons Guidelines, «Label text»: «Don't truncate or wrap label text».
7. Лента прокручивается и содержит все дни двух недель → группа одной строкой без переноса; прокрутки в спеке нет; menu-overflow для toggle-группы MDC запрещает. Строго по спеке — группа на неделю (листать недели); иначе прокрутку записать как сознательное отступление. Расширение/сжатие не меняет общую ширину, поэтому с прокруткой оно работает.
8. Семантика `button + selected` → добавить `inMutuallyExclusiveGroup: true` (single-select, как в `SegmentedButton`).

Что сделать во Flutter (порт Compose, без выдумок):
1. **Прогресс нажатия** на каждую кнопку: `AnimationController.unbounded`. На tap down (`InkWell.onTapDown` или `onHighlightChanged(true)`) — `animateWith(AppMotion.fastSpatial.simulate(from: value, to: 1, velocity: velocity))`. На up/cancel — дождаться `value > 0.75` (не дольше 1000 мс), затем `animateWith(AppMotion.fastSpatial.simulate(from: value, to: 0, velocity: velocity))`. Повторное нажатие отменяет ожидание.
2. **Лейаут** — свой `MultiChildRenderObjectWidget` (например, `ButtonGroupLayout`) с parent data `{Animation<double> press, double compressionLimit}`. В `performLayout`: ширины детей по `getMaxIntrinsicWidth(height)` (или по `flex`), затем алгоритм из п. 5 «Состояния и движение» с `expandedRatio = 0.15`, `compressionLimit = 24` (или фактический end-отступ кнопки), `layout(BoxConstraints.tightFor(width: w))`, расстановка с постоянным `spacing`. Подписка на `press` → `markNeedsLayout()`. Общая ширина не меняется, `SingleChildScrollView` (если прокрутку оставить) не прыгает.
3. **Кнопка дня** = filled toggle: контейнер surfaceContainer ↔ primary, содержимое onSurfaceVariant ↔ onPrimary. Цвет переключать без анимации (как Compose) или записать отступление. Содержимое по центру, `Text(maxLines: 1, softWrap: false, overflow: TextOverflow.visible)`.
4. **Форма**: радиус из `AnimationController`, который `animateWith(AppMotion.fastSpatial.simulate(...))` к цели pressed > selected > default (п. 2 расхождений). Рисовать `Material(shape: RoundedRectangleBorder(...))` с `animationDuration: Duration.zero`.
5. **Промежуток** — токен размера (12 или 8dp). Зона нажатия ≥ 48dp. `Semantics(button: true, selected:, inMutuallyExclusiveGroup: true, label: …)`.
6. Решить и записать в `docs/m3/README.md` («Сознательные отступления»): прокрутка всех дней или по неделе; одна или две строки в кнопке.

### Connected group (`connected_button_group.dart`) — ⚠️
Совпадает: промежуток 2dp, высота 40dp, внешние углы full, внутренние 8dp → pressed 4dp → selected 50%, морф на `fastSpatial` (как `ToggleButton`), цвета filled toggle (surfaceContainer/onSurfaceVariant ↔ primary/onPrimary), labelLarge и отступ 16dp, растяжение на ширину (`Expanded`), без влияния на соседей, семантика `selected + inMutuallyExclusiveGroup`. Использование в «Заметках» и «Профиле» — выбор между связанными вариантами — соответствует гайдлайнам.

Расхождения:
1. Зона нажатия: сейчас `SizedBox(height: 48)` вокруг кнопки 40dp, но `InkWell` только на 40dp — касания в полосах по 4dp сверху и снизу не попадают → hit-area 48dp → Accessibility: «Extra small and small connected button groups have 48dp target areas». Flutter решает это `_InputPadding`/`_RenderInputPadding` в `button_style_button.dart`: расширяет hit test и перенаправляет касание в центр ребёнка.
2. Нажатие выбранной кнопки: форма остаётся full → pressed-форма (внутренние 4dp), у Compose pressed приоритетнее checked → `ToggleButton.kt` `shapeByInteraction`.
3. Цвет контейнера и текста анимируется `DefaultEffects` → в Compose меняется мгновенно → `ToggleButton.kt`. Либо убрать анимацию, либо записать отступление.
4. `TextOverflow.ellipsis` → подпись не обрезается → Buttons Guidelines «Label text». Короткие подписи сейчас помещаются, риск — при 200% шрифте.

Что сделать во Flutter:
1. Обернуть кнопку в render-обёртку по образцу `_RenderInputPadding` (минимум 48dp по высоте, `hitTest` → центр ребёнка) вместо простого `SizedBox`.
2. В `_ConnectedButtonState.build` считать внутренний радиус так: `_pressed ? pressedInnerCorner : (selected ? full : innerCorner)`.
3. Цвет: `TweenAnimationBuilder<Color?>` заменить прямым значением (как Compose) — или оставить с записью в README.

### Реализация во Flutter
**Standard button group** — `M3ButtonGroup` + `M3ButtonGroupItem` (`lib/widgets/m3_button_group.dart`).
- `RenderM3ButtonGroup` повторяет `ButtonGroupMeasurePolicy.measure`: ширины детей без веса — `maxIntrinsicWidth`, с весом (`M3ButtonGroupItem.weight`) — делят остаток; затем цикл расширения нажатых (`M3ButtonGroup.expandPressed`: первый / средний / последний, `expandedRatio` 0.15, пределы `compressionLimit`), дети измеряются с жёсткой шириной, промежуток постоянный (`Arrangement.spacedBy`, с учётом RTL), выравнивание по вертикали — сверху. Общая ширина не меняется. Parent data: прогресс `Animation<double>`, `compressionLimit` (у элемента по умолчанию 24dp, у ребёнка без элемента 0 — как `ButtonGroupParentData`), вес.
- `M3ButtonGroupItem` — порт `EnlargeOnPressNode`: слушает `WidgetStatesController` кнопки (аналог `interactionSource`), при нажатии пружина FastSpatial к 1; когда нажатий нет — покадровое ожидание `value > 0.75` не дольше 1000 мс, затем пружина к 0; новое нажатие отменяет ожидание. Прогресс не ограничен [0, 1] — перелёт виден на ширине.
- Промежутки: `M3ButtonGroupDefaults.spacingFor(size)` — 18 / 12 / 8 / 8 / 8dp.
- Отступления: (1) прирост не округляется до целых пикселей (в Compose `roundToInt` — артефакт целочисленной раскладки); (2) overflow-меню не портировано (для toggle-групп MDC его запрещает); (3) при «Удалить анимации» расширение отключено — оно не передаёт состояние, только движение.

**Connected group** — `ConnectedButtonGroup<T>` (`lib/widgets/connected_button_group.dart`), API прежний. Теперь строка `M3ToggleButton` размера S с формами `ConnectedButtonGroup.shapesFor(index, count)` = `connected{Leading,Middle,Trailing}ButtonShapes()` (средняя — 8dp на всех углах, pressed 4dp, checked full). Закрыты расхождения 1–4 списка выше: зона нажатия 48dp по всей высоте (`M3TouchTarget`, касание в полях уходит в кнопку); pressed важнее checked; цвет без анимации; подпись одной строкой без многоточия. Семантика — `selected` + `inMutuallyExclusiveGroup`.

**Выбор недели** (с 17.09.2026) — `WeekSwitcher` (`lib/features/schedule/week_switcher.dart`): connected button group «Эта неделя / Следующая» (или даты недели) на всю ширину, под ней даты выбранной недели. Выбор недели открывает сегодняшний день, если он в ней, иначе тот же день недели, иначе первый. Лента дней пальцем больше не листается — неделю переключает группа, а при выборе дня другой недели (свайп пар с субботы на понедельник, поиск) лента переезжает сама.

**Селектор дней** — `DaySelector` (`lib/widgets/day_selector.dart`), конструктор прежний. Реализовано решение «группа на неделю»: дни делятся на календарные недели с понедельника (`DaySelector.weeksOf`), каждая неделя — страница `PageView` (lateral: едет за пальцем, без затухания) с `M3ButtonGroup` на всю ширину (поля 16dp, кнопки с равным весом, одной строкой). Кнопка дня — filled `M3ToggleButton`: surfaceContainer / onSurfaceVariant ↔ primary / onPrimary без анимации; формы `M3ToggleButtonDefaults.shapesFor(высота)` (60dp → корзина M: full, pressed 12dp, выбранная 16dp; при 200% шрифта 104dp → L: 16 / 28dp), промежуток по той же корзине (8dp); нажатие расширяет кнопку за счёт соседей. Когда `selectedIndex` уходит в другую неделю, страница листается сама; при «Удалить анимации» — прыжком. Семантика: `button`, `selected`, `inMutuallyExclusiveGroup`, метка — полная дата («Среда, 16 сентября»). Высота растёт с масштабом шрифта. Закрыты расхождения 1–5 и 7–8 списка выше.

Осознанные отступления селектора:
1. **Подпись в две строки** (день недели над числом) — против «Don't truncate or wrap label text». Одной строкой («Ср 16») подпись не помещается в кнопку недели на компактном экране: 6–7 кнопок делят ширину окна без полей 16dp, это 40–56dp на кнопку, а при 200% шрифта двухбуквенный день уже занимает ~35dp. Две короткие строки не переносятся и не обрезаются.
2. Шрифты строк — `label-text` размеров S (`labelLarge`, день) и M (`titleMedium`, число); вертикальный отступ 8dp — `ButtonDefaults.ContentPadding` (`ButtonVerticalPadding`). Токенов для двухстрочной подписи нет. Итоговая высота 60dp ≥ M 56dp.
3. Программная смена недели — переход Emphasized, 500 мс (`motion.md`, «Переходы»: начало и конец на экране), а не пружина: у pager в M3 своего токена нет.
4. `compressionLimit` кнопок дня — значение Compose по умолчанию (24dp); при кнопках 40–56dp рост раньше упирается в 15% ширины.
5. При 7 днях в неделе (с воскресеньем) на экране 360dp ширина кнопки ~40dp < 48dp — зона нажатия по ширине ограничена самой кнопкой (промежуток 8dp касаний не ловит).

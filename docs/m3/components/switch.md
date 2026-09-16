# Переключатель (Switch)

Статус в приложении: ⚠️ частично

Размеры и цвета совпадают с токенами: Flutter-виджет `Switch` сгенерирован по ним.
Не совпадают движение ручки (Flutter делает анимацию M3 baseline, а не пружину Expressive),
нет иконки в ручке. Кроме того, два из трёх тумблеров в профиле нарушают правила
применения переключателей.

## Источники
- Guidelines / Specs / Accessibility: https://m3.material.io/components/switch/guidelines,
  https://m3.material.io/components/switch/specs, https://m3.material.io/components/switch/accessibility
  (выгрузка: `.m3-guidelines/components__switch.md`)
- Compose API: https://developer.android.com/reference/kotlin/androidx/compose/material3/package-summary —
  `Switch(checked, onCheckedChange, modifier, thumbContent, enabled, colors, interactionSource)`,
  `SwitchDefaults.colors()`, `SwitchDefaults.IconSize`
- Compose исходник: `Switch.kt` (`SwitchImpl`, `ThumbElement`, `ThumbNode.measure`, `SwitchColors`),
  токены `tokens/SwitchTokens.kt`, пример `samples/SwitchSamples.kt` (`SwitchSample`,
  `SwitchWithThumbIconSample`)
- MDC: https://github.com/material-components/material-components-android/blob/master/docs/components/Switch.md
  (`MaterialSwitch`, стиль `Widget.Material3.CompoundButton.MaterialSwitch`; анимация —
  `materialswitch/res/drawable/mtrl_switch_thumb*.xml`)
- Flutter: `Switch` / `SwitchListTile` (`packages/flutter/lib/src/material/switch.dart`,
  `switch_list_tile.dart`). Есть: трек 52×32, ручка 16/24/28dp, `thumbIcon` (с иконкой ручка
  24dp), цвета по токенам (`_SwitchDefaultsM3`), перетаскивание ручки. Нет: пружинной анимации
  Expressive, настройки длительности и кривой переключения (в `_SwitchConfigM3` жёстко заданы
  `toggleDuration` = 300 мс и `transitionalThumbSize` = 34×22).

## Когда использовать
- Только для **бинарной** настройки «вкл/выкл», которая **срабатывает сразу**, без сохранения
  (Guidelines → Usage).
- Не для взаимоисключающих вариантов вроде «список / карта»: для них connected button group
  (Guidelines → Usage, DO/DON'T).
- Не вместо кнопки действия. Для множественного выбора с сохранением нужны чекбоксы, для одного
  варианта из списка — радиокнопки (Guidelines → Alternate selection controls).
- Всегда с подписью рядом. Подпись описывает, что происходит во включённом состоянии.
  Текст «Вкл/Выкл» внутрь переключателя не пишут (Guidelines → Label text).

## Варианты и анатомия
- Анатомия: трек, ручка (раньше thumb), иконка (необязательная).
- Конфигурации (Specs → Configurations): без иконок; иконка только во включённом состоянии; иконки
  в обоих состояниях.
- Иконка должна однозначно показывать состояние: галочка и крестик. Луна, карандаш и подобные
  иконки не подходят (Guidelines → Icon, DO/DON'T).
- В разделе «Differences from M2» переключатель M3 показан с галочкой в ручке. В Compose это
  пример `SwitchWithThumbIconSample`: `Icons.Filled.Check` размером `SwitchDefaults.IconSize`
  (16dp) и только при `checked`.

## Размеры, формы, цвета

| Элемент | Значение | Источник |
|---|---|---|
| Трек | 52×32dp, `corner.full`, обводка 2dp | `SwitchTokens.TrackWidth/TrackHeight/TrackOutlineWidth` |
| Ручка выключенного | 16dp, без иконки | `UnselectedHandleWidth` |
| Ручка включённого или с иконкой | 24dp | `SelectedHandleWidth`, `IconHandleWidth` |
| Ручка при нажатии | 28dp | `PressedHandleWidth` |
| Иконка | 16dp | `SelectedIconSize`, `SwitchDefaults.IconSize` |
| State layer | 40dp, круг; зона нажатия 48dp | `StateLayerSize`; Specs → Measurements |
| Трек выкл. / вкл. | `surfaceContainerHighest` / `primary` | `UnselectedTrackColor` / `SelectedTrackColor` |
| Обводка трека выкл. / вкл. | `outline` / прозрачная | `SwitchDefaults.colors()` |
| Ручка выкл. / вкл. | `outline` / `onPrimary` | `UnselectedHandleColor` / `SelectedHandleColor` |
| Ручка при нажатии, наведении, фокусе | выкл. `onSurfaceVariant`, вкл. `primaryContainer` | `*Pressed/Hover/FocusHandleColor` |
| Иконка выкл. / вкл. | `surfaceContainerHighest` / `onPrimaryContainer` | `UnselectedIconColor` / `SelectedIconColor` |
| Выключенный элемент (disabled) | трек `onSurface` 12%, ручка вкл. `surface`, ручка выкл. `onSurface` 38% | `Disabled*` |
| Подпись / поясняющий текст | `onSurface` / `onSurfaceVariant` | Specs → Adjacent text label color |

Расхождение источников по цвету иконки включённого переключателя. В таблице токенов на сайте
указано `md.sys.color.primary`. Compose (`SwitchTokens.SelectedIconColor`), MDC (`thumbIconTint`)
и Flutter (`_SwitchConfigM3.iconColor`) используют `onPrimaryContainer`, и в списке цветовых ролей
на той же странице тоже есть «On primary container». Берём `onPrimaryContainer`.

## Состояния и движение
Compose (`Switch.kt`, `ThumbNode.measure`):
- Размер и положение ручки анимируются пружиной `MotionSchemeKeyTokens.FastSpatial`
  (Expressive: stiffness 800, damping 0.6, в приложении `AppMotion.fastSpatial`). Ручка
  растягивается как единое целое, промежуточной «сплющенной» формы нет.
- При нажатии ручка **мгновенно** (`SnapSpec`) становится 28dp и смещается к краю на толщину
  обводки (2dp), поэтому центр остаётся на месте. После отпускания размер и положение возвращаются
  той же пружиной `FastSpatial`.
- Цвета трека, ручки и иконки в `SwitchImpl` берутся из `SwitchColors` без анимации и
  переключаются сразу.
- Ripple: неограниченный, радиус `StateLayerSize / 2` = 20dp, центр в ручке.

Flutter (`switch.dart`), что есть сейчас:
- Позиция ручки: 300 мс, `Curves.easeOutBack`.
- На полпути ручка растягивается до 34×22dp (`transitionalThumbSize`, `TweenSequence` с
  кубическими кривыми). Это анимация MDC baseline (`mtrl_switch_thumb_unchecked_checked.xml`,
  морфинг пути с `m3_sys_motion_easing_emphasized`), а не Expressive.
- Цвета плавно меняются вместе с позицией (`Curves.easeOut` / `easeIn`).
- Нажатие увеличивает ручку за `kRadialReactionDuration` = 100 мс.

Специфика (Guidelines → Behavior, Accessibility → Interaction & style): при переключении ручка
переезжает на другую сторону и меняет размер. При касании или перетаскивании ручка растёт.

## Доступность
- Зона нажатия не меньше 48×48dp, плотность по умолчанию не уменьшать.
- Фокус попадает на ручку. **Space** и **Enter** переключают.
- Доступное имя берётся из подписи рядом. Если подпись неоднозначна, нужна более подробная
  метка («Доступ к фотоальбому» вместо «Фотоальбом»).
- Иконка в ручке не фокусируется, и `contentDescription` у неё нет (`SwitchWithThumbIconSample`).
- Вкл/выкл должно быть видно с первого взгляда (Overview). Галочка помогает различать состояния
  без опоры на цвет.

## В приложении
- Где используется: `lib/features/profile/profile_screen.dart`, три `SwitchListTile` внутри
  `SegmentedList` («Тёмная тема», «Динамические цвета», «Напоминать о паре»). `switchTheme` в
  `lib/app.dart` не задан, поэтому работают значения Flutter по умолчанию.

### Реализация во Flutter
Виджет `M3Switch` (`lib/widgets/m3_switch.dart`), тесты `test/m3_switch_test.dart`. В экраны
пока не подключён, расхождения ниже относятся к текущим `SwitchListTile`.

```dart
M3Switch({required bool value, required ValueChanged<bool>? onChanged,
  M3SwitchIcons icons = M3SwitchIcons.selectedOnly, FocusNode? focusNode, bool autofocus = false})
```

**Решение по иконке:** конфигурация «иконка только во включённом» (`M3SwitchIcons.selectedOnly`,
`Symbols.check` 16dp). Так переключатель M3 показан в «Differences from M2», так же сделан
`SwitchWithThumbIconSample` в Compose. `M3SwitchIcons.both` (галочка и крестик) и `none` оставлены
в API, по умолчанию не используются.

Совпадает с Compose / токенами:
- раскладка 52×48 (трек 52×32, обводка 2dp; зона нажатия 48dp, как `minimumInteractiveComponentSize`);
- ручка 16 / 24 / 28dp, с иконкой 24dp (`ThumbNode.measure`: `hasContent`), положение `minBound` /
  `maxBound`, при нажатии сдвиг на толщину обводки — центр на месте;
- размер и положение — две пружины `FastSpatial` с сохранением скорости; при нажатии мгновенный
  переход к 28dp (`SnapSpec`). Цели пересчитываются в начале кадра, как в `measure`: касание,
  нажатое и отпущенное в одном кадре, 28dp не показывает;
- цвета по `SwitchDefaults.colors()` без интерполяции, disabled-цвета сведены на `surface`
  (`compositeOver`); иконка `min(16dp, размер ручки)`;
- state layer — круг радиусом 20dp с центром в ручке, поверх трека и ручки; цвет —
  `primary` / `onSurface` (`*.state-layer.color`) с непрозрачностью `AppStateLayer`;
- `Semantics(toggled)`, фокус, Space и Enter (`ActivateIntent`), RTL.

Осознанные отличия:
1. **Цвет ручки при нажатии, наведении и фокусе** — `primaryContainer` / `onSurfaceVariant` по
   токенам `*.pressed/hover/focus.handle.color` (так же MDC и Flutter). `SwitchColors` в Compose
   эти состояния не различает; m3.material.io — первоисточник выше Compose.
2. **Перетаскивание ручки.** В Compose его нет (`TODO: Add Swipeable modifier b/223797571`), но
   спека требует, чтобы ручка росла «when tapped or dragged». Поведение как у Flutter `Switch`:
   ручка 28dp идёт за пальцем между крайними положениями нажатой ручки, по отпусканию решает
   половина хода, дальше пружина `FastSpatial`.
3. **Рисунок ripple.** Compose на Android использует платформенный `RippleDrawable`. Здесь ink
   Flutter, как у всех `InkWell` приложения: splash из `Theme.splashFactory` (на Android
   `InkSparkle`), обрезанный кругом 40dp, и `InkHighlight` с длительностями `InkResponse`
   (нажатие 200 мс, наведение и фокус 50 мс). Общий код — `lib/widgets/m3_radial_ink.dart`.
4. **Уменьшение движения** (`MediaQuery.disableAnimations`): ручка меняет размер и положение без
   пружины.
5. Округление размера и смещения до целых пикселей (`toInt()` в `ThumbNode`) не повторяется.

### Расхождения
1. **Движение ручки.** Сейчас: 300 мс `easeOutBack`, растягивание ручки до 34×22, плавная смена
   цвета. Должно быть: пружина `FastSpatial` на размер и позицию, мгновенное увеличение до 28dp
   при нажатии, цвета без анимации. Источник: `Switch.kt` → `ThumbElement(animationSpec =
   MotionSchemeKeyTokens.FastSpatial.value())`, `ThumbNode.measure`.
2. **Нет иконки в ручке.** Сейчас `thumbIcon` не задан. Иконка по спеке необязательна, но
   переключатель M3 на странице и в примере Compose показан с галочкой во включённом состоянии.
   Решение нужно принять явно и записать. Рекомендация: конфигурация «иконка только во
   включённом», `Symbols.check` 16dp. Источник: Specs → Configurations, `SwitchSamples.kt`.
3. **«Тёмная тема» — это три состояния, а не два.** В `Settings.darkOverride` три значения
   (`null` — как в системе, `true`, `false`), а тумблер умеет только два. После первого нажатия
   вернуться к «Следовать системной» из интерфейса нельзя: `followSystemTheme()` нигде не
   вызывается. Гайдлайн: переключатель только для бинарного выбора, для взаимоисключающих
   вариантов — connected button group (уже есть `lib/widgets/connected_button_group.dart`) или
   радиокнопки. Источник: Guidelines → Usage.
4. **«Напоминать о паре» ни на что не влияет.** `lessonReminder` только сохраняется в
   `settings_controller.dart`, уведомлений нет. Гайдлайн: «The effects of a switch should start
   immediately». Нужно либо реализовать напоминания, либо убрать пункт.
5. Горизонтальный отступ самого виджета во Flutter 4dp (`_SwitchDefaultsM3.padding`), в Compose
   ограничивающий прямоугольник 52×48. На вид не влияет, но выравнивание края в `ListTile`
   отличается на 4dp. Геометрию строки сверять по спеке lists.

### Что сделать во Flutter
1. Цвета и размеры не трогать: значения `_SwitchDefaultsM3` и `_SwitchConfigM3` совпадают с
   `SwitchTokens`. Цвет иконки уже `onPrimaryContainer`.
2. Иконка (если принято решение):
   `thumbIcon: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? const Icon(Symbols.check, size: 16) : null)`
   в `SwitchThemeData` внутри `buildTheme`. С иконкой только у включённого ручка выключенного
   остаётся 16dp (`switch.dart`: `effectiveInactiveIcon == null && widget.inactiveThumbImage == null ? inactiveThumbRadius : thumbRadiusWithIcon`).
3. Движение: во Flutter его не настроить, поэтому нужен свой виджет `M3Switch` — **сделан**
   (см. «Реализация во Flutter»), осталось подключить. Исходный план:
   - `LeafRenderObjectWidget` или `CustomPainter`: трек 52×32 с обводкой 2dp, ручка — круг,
     внутри иконка;
   - два `AnimationController.unbounded`: `offset` и `size`, изменения через
     `animateWith(AppMotion.fastSpatial.simulate(from, to, velocity))`;
   - `onTapDown`: `size.value = 28`, offset на 2dp от края, без анимации (`SnapSpec`);
     `onTapUp` и `onTapCancel`: пружина к 24 или 16 (с иконкой всегда 24);
   - цвета по состоянию из токенов без интерполяции; ripple через `InkResponse` радиусом 20;
   - `Semantics(toggled: value)`, `FocusableActionDetector` (Space и Enter);
   - перетаскивание, как в Flutter `Switch`, желательно сохранить: по спеке ручка растёт и при
     перетаскивании. В Compose перетаскивания нет, там `TODO b/223797571`.
   `SwitchListTile` заменить на `ListTile(trailing: M3Switch(...), onTap: toggle)` и объединить
   семантику через `MergeSemantics`.
4. «Тёмная тема» → группа кнопок «Системная / Светлая / Тёмная» или радиокнопки.
5. «Напоминать о паре»: реализовать или убрать.

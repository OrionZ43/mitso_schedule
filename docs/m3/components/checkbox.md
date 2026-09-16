# Чекбокс (Checkbox)

Статус в приложении: ✅ соответствует — `M3Checkbox` в пунктах списка задач, строка нажимается целиком

> Разделы «В приложении → Расхождения» ниже описывают состояние до порта (16.09.2026); что сделано и что осталось — в «Реализация во Flutter» и в README.

## Источники
- Guidelines / Specs / Accessibility: https://m3.material.io/components/checkbox/guidelines,
  https://m3.material.io/components/checkbox/specs, https://m3.material.io/components/checkbox/accessibility
  (выгрузка: `.m3-guidelines/components__checkbox.md`)
- Compose API: https://developer.android.com/reference/kotlin/androidx/compose/material3/package-summary —
  `Checkbox(checked, onCheckedChange, …)`, `TriStateCheckbox`, `CheckboxDefaults.colors()`,
  `CheckboxDefaults.StrokeWidth`
- Compose исходник: `Checkbox.kt` (`CheckboxImpl`, `colorAnimationSpecForState`,
  `SnapAnimationDelay`), токены `tokens/CheckboxTokens.kt`, пример `samples/CheckboxSamples.kt`
- MDC: https://github.com/material-components/material-components-android/blob/master/docs/components/Checkbox.md
- Flutter: `Checkbox`, `CheckboxListTile` (`checkbox.dart`, `checkbox_list_tile.dart`,
  анимация в `widgets/toggleable.dart`). Цвета и размеры по токенам (`_CheckboxDefaultsM3`),
  есть tristate и `isError`. Переключение — `_kToggleDuration` = 200 мс,
  `Curves.easeIn`/`easeOut`, реакция на нажатие `kRadialReactionDuration` = 100 мс. Пружин нет, и
  настроить анимацию нельзя.

## Когда использовать
- Выбор нескольких связанных вариантов из списка, подвыборы (родительский чекбокс с
  неопределённым состоянием), включение пункта на десктопе. Если чекбокс что-то включает,
  действие выполняется сразу (Guidelines → Usage, Behavior).
- Для одного варианта из списка — радиокнопки. Для отдельной настройки — переключатель.

## Варианты и анатомия
- Контейнер и иконка (галочка или черта для неопределённого состояния).
- Состояния значения: не выбран, выбран, неопределённый, у каждого есть error-вариант.
- В списке чекбокс стоит в ведущем слоте list item («Leading checkbox», `components__lists.md`).

## Размеры, формы, цвета

| Элемент | Значение | Источник |
|---|---|---|
| Контейнер | 18dp, углы 2dp | `md.comp.checkbox.container.size/shape`; `CheckboxTokens.ContainerSize/ContainerShape` |
| Обводка невыбранного | 2dp `onSurfaceVariant`; при нажатии, наведении, фокусе `onSurface` | `unselected.outline.color`, `unselected.pressed/hover/focus.outline.color` |
| Выбранный | фон `primary`, галочка `onPrimary`, обводка 0 | `selected.container.color`, `selected.icon.color` |
| Ошибка | обводка или фон `error`, галочка `onError` | `*.error.*` |
| Отключённый | выбранный фон `onSurface` 38%, галочка `surface`; обводка невыбранного `onSurface` 38% | `selected.disabled.*`, `unselected.disabled.*` |
| State layer / зона нажатия | 40dp круг / 48dp | `state-layer.size`; Measurements |
| Подпись рядом | `onSurface`, цвет не зависит от выбора | Specs → Adjacent text label color |

## Состояния и движение
Compose (`Checkbox.kt`, `CheckboxImpl`):
- Прорисовка галочки (`checkDrawFraction`) при включении — пружина
  `MotionSchemeKeyTokens.DefaultSpatial`. При выключении галочка исчезает мгновенно (`snap`) с
  задержкой 100 мс (`SnapAnimationDelay`).
- Переход «галочка ↔ черта» (`checkCenterGravitationShiftFraction`) — `DefaultSpatial`.
- Цвета фона, обводки и галочки (`colorAnimationSpecForState`): заливка при включении
  `DefaultEffects`, сброс при выключении `FastEffects`. Для отключённого элемента цвета
  переключаются без анимации.
- Ripple ограничен state layer 40dp.

## Доступность
- Выбрать пункт можно нажатием и на чекбокс, и на подпись (Accessibility → Interaction & style).
- Доступное имя = подпись рядом, роль checkbox.
- Зона нажатия ≥ 48dp, плотность по умолчанию не уменьшать.

## В приложении
- `lib/features/notes/notes_screen.dart` → `_TaskCard`: `Checkbox` в outlined-карточке, сдвинут
  `Transform.translate(offset: Offset(-12, -11))`; `semanticLabel: task.text`. При выполнении
  карточка затухает (`AnimatedOpacity` до 0.6), текст зачёркивается.
- `lib/app.dart` → `checkboxTheme`: `shape: AppShapes.rounded(2)`,
  `side: BorderSide(color: scheme.onSurfaceVariant, width: 2)`.

### Реализация во Flutter
Виджет `M3Checkbox` (`lib/widgets/m3_checkbox.dart`), тесты `test/m3_checkbox_test.dart`. В экраны
пока не подключён, расхождения ниже относятся к текущему `Checkbox` в заметках.

```dart
M3Checkbox({required bool? value, required ValueChanged<bool?>? onChanged,
  bool tristate = false, bool isError = false, FocusNode? focusNode, bool autofocus = false})
```

Совпадает с Compose / токенами:
- контейнер 18dp, углы 2dp, обводка и галочка `floor(2dp в пикселях)`, зона нажатия 48dp;
- `drawBox` (заливка целиком, если цвета фона и обводки совпали; иначе внутренняя заливка и
  обводка) и `drawCheck`: путь (0.25, 0.5) → (0.4, 0.65) → (0.75, 0.3), доля длины через
  `PathMetric.extractPath`, `StrokeCap.square`, сдвиг к черте по `crossCenterGravitation`;
- `checkDrawFraction`: из снятого — пружина `DefaultSpatial`; к снятому — мгновенно через 100 мс
  (`SnapAnimationDelay`); между выбранным и неопределённым — `DefaultSpatial`.
  `checkCenterGravitationShiftFraction`: из снятого — сразу, к снятому — через 100 мс, иначе
  `DefaultSpatial`. Спецификация выбирается по `Transition.currentState`, который меняется, только
  когда анимации перехода закончились;
- цвета фона, обводки и галочки — пружины `DefaultEffects` (к выбранному) и `FastEffects`
  (к снятому) в Oklab, отдельно по каналам и с сохранением скорости, как `animateColorAsState`
  с `Color.VectorConverter`; у недоступного фон и обводка без анимации;
- disabled: фон и обводка выбранного `onSurface` 38%, галочка `surface`; невыбранный — обводка
  `onSurface` 38%;
- `Semantics(checked, mixed)`, фокус, Space и Enter.

Осознанные отличия:
1. **Геометрия M3.** По умолчанию `Checkbox` в Compose ещё рисуется в M2-размерах (20dp с полями
   2dp); 18dp и новая галочка включаются флагом `ComposeMaterial3Flags.isCheckboxStylingFixEnabled`
   («Material Design 3 styling»). Берём ветку с флагом — она совпадает с токенами сайта.
2. **Обводка невыбранного при нажатии, наведении и фокусе — `onSurface`**
   (`unselected.{pressed|hover|focus}.outline.color`); в `CheckboxColors` Compose этих состояний нет.
3. **Цвет state layer по токенам** `*.state-layer.color`: нажатие невыбранного — `primary`,
   выбранного — `onSurface`; наведение и фокус наоборот; ошибка — `error`. В Compose с флагом
   ripple берёт цвет фона (у невыбранного он прозрачный).
4. **`isError`** — из токенов `*.error.*`; в Compose `Checkbox` такого параметра нет.
5. **Цикл tristate** по Guidelines → Behavior («Checking an indeterminate checkbox checks all child
   items»): `null` → `true`, `false` → `true`, `true` → `false`. У Flutter `Checkbox` цикл
   `false` → `true` → `null` → `false`; в Compose `TriStateCheckbox` решает вызывающий код.
6. Ripple — как у `M3Switch` (`m3_radial_ink.dart`): `Theme.splashFactory` в круге 40dp +
   `InkHighlight`, а не платформенный `RippleDrawable`.
7. Уменьшение движения: галочка и черта появляются без пружины; цвета анимируются.

### Расхождения
1. **`checkboxTheme.side` задан обычным `BorderSide`.** По документации Flutter
   (`checkbox.dart`, `side`) такой `side` применяется во **всех** невыбранных состояниях. Из-за
   этого теряются `onSurface` при нажатии, наведении и фокусе и `onSurface` 38% у отключённого.
   Умолчания `_CheckboxDefaultsM3` уже совпадают с токенами (`onSurfaceVariant` 2dp и `onSurface`
   в интерактивных состояниях). `shape` 2dp тоже совпадает с умолчанием.
2. **Подпись не нажимается.** Сейчас переключает только сам чекбокс, текст задачи — нет.
   Должно переключать и то и другое (Accessibility → Interaction & style).
3. **Цвет подписи меняется при выборе.** Сейчас карточка целиком уходит в прозрачность 0.6 и
   текст зачёркивается. По Specs → Adjacent text label color цвет подписи не зависит от выбора.
   Зачёркивания и затухания в спеке нет. Если они нужны, записать как осознанное отступление.
4. **Движение.** Сейчас 200 мс `easeIn`/`easeOut`. Должно быть: галочка `DefaultSpatial`, цвета
   `DefaultEffects`/`FastEffects`, при снятии галочка исчезает с задержкой 100 мс.
5. **Сдвиг `Transform.translate(-12, -11)`** переносит отрисовку, но не раскладку: зона нажатия
   остаётся на месте, а визуально чекбокс уезжает к краю. Для списка задач штатная раскладка —
   list item с ведущим чекбоксом (раздел lists).

### Что сделать во Flutter
1. Удалить `checkboxTheme` из `buildTheme` или оставить в нём только то, что действительно
   отличается от умолчаний.
2. Сделать всю строку задачи нажимаемой: `InkWell`/`ListTile(leading: Checkbox, onTap: toggle)` +
   `MergeSemantics`; у `Checkbox` оставить `onChanged` и убрать `semanticLabel`, так как имя
   берётся из объединённой семантики. Вместо `Transform.translate` — штатные отступы list item.
3. Затухание и зачёркивание убрать или записать в «Сознательные отступления» README.
4. **Сделано** — `M3Checkbox` (см. «Реализация во Flutter»), осталось подключить в заметках.
   Исходный план: свой `M3Checkbox` на `CustomPainter`, путь галочки как в
   `Checkbox.kt` (`drawCheck`, `CheckDrawingCache`); `checkDrawFraction` через
   `AnimationController.animateWith(AppMotion.defaultSpatial.simulate(...))`; цвета через
   `ColorTween` на контроллере с `AppMotion.defaultEffects` (вкл) / `fastEffects` (выкл);
   при выключении `Future.delayed(100ms)` и мгновенный сброс.

# Всплывающая подсказка (Tooltips)

Статус в приложении: ❌ не соответствует

`tooltipTheme` в `lib/app.dart` скопирован со стиля MDC `Widget.Material3.Tooltip`. Это не
plain tooltip, а родительский стиль **метки значения слайдера**
(`Widget.Material3.Slider.Label`). Из-за этого цвет `primary` вместо `inverseSurface`, другие
поля и минимальный размер. Позиция и анимация — умолчания Flutter, а не M3.

## Источники
- Guidelines / Specs / Accessibility: https://m3.material.io/components/tooltips/guidelines,
  https://m3.material.io/components/tooltips/specs, https://m3.material.io/components/tooltips/accessibility
  (выгрузка: `.m3-guidelines/components__tooltips.md`)
- Compose API: https://developer.android.com/reference/kotlin/androidx/compose/material3/package-summary —
  `TooltipBox(positionProvider, tooltip, state, modifier, onDismissRequest, focusable, enableUserInput, hasAction, content)`,
  `TooltipScope.PlainTooltip(modifier, caretShape, maxWidth, shape, contentColor, containerColor, tonalElevation, shadowElevation, content)`,
  `TooltipScope.RichTooltip(…)`, `TooltipDefaults.rememberTooltipPositionProvider(positioning: TooltipAnchorPosition, spacingBetweenTooltipAndAnchor)`,
  `rememberTooltipState(initialIsVisible, isPersistent, mutatorMutex)`
- Compose исходник: `Tooltip.kt` (`TooltipBox`: `scaleSpec`/`alphaSpec`; константы
  `SpacingBetweenTooltipAndAnchor`, `TooltipMinHeight`, `TooltipMinWidth`,
  `PlainTooltipContentPadding`, `TooltipDefaults.plainTooltipMaxWidth`/`richTooltipMaxWidth`),
  `internal/BasicTooltip.kt` (`handleGestures`, `anchorSemantics`, `keyboardBehavior`,
  `BasicTooltipDefaults.TooltipDuration = 1500L`, `GlobalMutatorMutex`). Токены:
  `tokens/PlainTooltipTokens.kt`, `tokens/RichTooltipTokens.kt`. Пример: `samples/TooltipSamples.kt`
- MDC: https://github.com/material-components/material-components-android/blob/master/docs/components/Tooltip.md —
  компонент «yet to be completed». Стиль `Widget.Material3.Tooltip` в
  `tooltip/res/values/styles.xml` (`backgroundTint ?attr/colorPrimary`, `textColor ?attr/colorOnPrimary`,
  padding 4dp, min 28dp, форма `Corner.Full`) — родитель `Widget.Material3.Slider.Label` в
  `slider/res/values/styles.xml`. Для plain tooltip он не источник.
- Flutter: `Tooltip`, `TooltipThemeData`, `RawTooltip` (`material/tooltip.dart`,
  `widgets/raw_tooltip.dart`). Умолчания **не M3**: фон `Colors.grey[700]` 90 % (светлая тема) /
  белый 90 % (тёмная), `bodyMedium` 14sp, высота 32dp и поля 16×4dp на Android, радиус 4.
  Показ под элементом (`preferBelow: true`) со смещением `verticalOffset` 24dp от центра цели.
  Затухание 150 / 75 мс `fastOutSlowIn`. Скрытие через 1500 мс после long press
  (`showDuration`), при уходе курсора через 100 мс (`exitDuration`). Есть `positionDelegate`.
  У `RawTooltip` есть `tooltipBuilder(context, animation)` для своего перехода. Rich tooltip
  нет.

## Когда использовать
- **Plain tooltip** — кратко подписать элемент **без текста**, например иконку-кнопку. Если у
  элемента уже есть подпись, подсказка не нужна (DON'T) (Guidelines → Usage).
- **Rich tooltip** — пояснение или описание новой функции: необязательный подзаголовок, текст,
  до двух текстовых кнопок. Критичную информацию в подсказку не прячут, для неё нужен диалог.
- Plain tooltip — одна короткая строка, без переносов и нескольких фактов (CAUTION).
- Одновременно видна только одна подсказка (Guidelines → Behavior).

## Варианты и анатомия
- Plain: container и supporting text.
- Rich: subhead (необязательно), container, supporting text, текстовые кнопки (до двух,
  необязательно). Конфигурации — Specs → Rich tooltip configurations.
- Compose рисует необязательный «хвостик» (`caretShape`, `TooltipDefaults.caretShape()`), в
  гайде его нет.

## Размеры, формы, цвета

| Параметр | Значение | Источник |
|---|---|---|
| Plain: контейнер | `inverse-surface` | `md.comp.plain-tooltip.container.color`; `PlainTooltipTokens.ContainerColor` |
| Plain: форма | `corner.extra-small` (4dp) | `…container.shape`; `ContainerShape` |
| Plain: текст | `body-small`, `inverse-on-surface` | `…supporting-text.*`; `SupportingTextFont/Color` |
| Plain: высота / поле | 24dp / 8dp | Specs → Plain tooltip measurements |
| Plain в Compose | min 40×24dp, max ширина 200dp, поля 8dp по горизонтали и 4dp по вертикали | `TooltipMinWidth`, `TooltipMinHeight`, `plainTooltipMaxWidth`, `PlainTooltipContentPadding` |
| Rich: контейнер | `surface-container`, `elevation.level2`, `corner.medium` (12dp) | `md.comp.rich-tooltip.container.*`; `RichTooltipTokens` |
| Rich: подзаголовок / текст / действие | `title-small` `on-surface-variant` / `body-medium` `on-surface-variant` / `label-large` `primary` | `md.comp.rich-tooltip.*` |
| Rich: поля | сверху 12dp, снизу 8dp, по бокам 16dp; в Compose max ширина 320dp | Specs; `richTooltipMaxWidth` |
| Расстояние до элемента | 4dp (у элемента есть граница) / 8dp (нет границы, например базовая линия текста) | Guidelines → Placement; `SpacingBetweenTooltipAndAnchor` = 4dp |

## Состояния и движение
- **Размещение (гайд):** plain — **над** элементом. Если элемент в **app bar** — под ним на том
  же расстоянии. Rich — справа снизу, сдвигается шагами по 8dp, чтобы не уйти за экран, и не
  закрывает элемент.
- **Размещение (Compose):** `rememberTooltipPositionProvider` центрирует по горизонтали и
  прижимает к краю экрана при выходе за него. По вертикали — над элементом, а если не
  помещается, под ним. Есть явный `TooltipAnchorPosition`.
- **Показ на телефоне:** долгое нажатие. Compose (`handleGestures`) после
  `longPressTimeoutMillis` вызывает `state.show(MutatePriority.PreventUserInput)`. У
  неперсистентной подсказки это `withTimeout(TooltipDuration = 1500 мс)`, после чего она
  скрывается. Общий `GlobalMutatorMutex` закрывает предыдущую подсказку, когда появляется новая.
  В гайде: подсказка исчезает через 1,5 с.
- **Анимация (Compose `TooltipBox`):** масштаб 0.8 ↔ 1 — `MotionSchemeKeyTokens.FastSpatial`
  (Expressive: ratio 0.6, stiffness 800), прозрачность 0 ↔ 1 — `FastEffects` (1.0, 3800).
- **Клавиатура:** подсказка появляется при фокусе и исчезает при его потере (`keyboardBehavior`).

## Доступность
- Роль **Tooltip**. Элементы rich tooltip подписываются по своим правилам. Фокус не
  удерживается, порядок — сверху вниз (Accessibility).
- Подсказка должна показываться с клавиатуры или switch-управления и держаться достаточно
  долго.
- Compose: `anchorSemantics` добавляет элементу действие `onLongClick` с подписью
  `tooltip_label`.
- Flutter: `RawTooltip(semanticsTooltip: message)` пишет текст в `Semantics.tooltip` элемента.
  Роль `SemanticsRole.tooltip` явно не задавать: её проверка в `semantics.dart` не реализована
  (`_unimplemented`, в debug-режиме это ошибка «Missing checks for role»).

## В приложении
**Где используется**
- `lib/app.dart` → `tooltipTheme`: фон `primary`, текст `bodySmall` / `onPrimary`, `padding` 4dp,
  `constraints` min 28×28, радиус `AppShapes.extraSmall`.
- Подсказки иконок-кнопок (все без текстовой подписи — по гайду допустимо):
  - `lib/features/schedule/schedule_screen.dart` — «Выбрать / Сменить группу»
    (`IconButton.filledTonal` в `SliverAppBar`);
  - `lib/features/schedule/lesson_details_page.dart` — «Назад» в `AppBar`;
  - `lib/features/group_picker/group_picker_sheet.dart` — «Назад» в заголовке шита (не app bar);
  - `lib/features/notes/notes_screen.dart` — FAB «Добавить задачу».

**Реализация во Flutter**

Виджет `M3PlainTooltip` (`lib/widgets/m3_tooltip.dart`), тесты `test/m3_tooltip_test.dart`. В экраны
пока не подключён, расхождения ниже относятся к текущим `tooltip:` у кнопок.

```dart
M3PlainTooltip({required String message, required Widget child, bool preferBelow = false,
  EdgeInsetsGeometry anchorPadding = EdgeInsets.zero})
// Для IconButton: anchorPadding: M3PlainTooltip.iconButtonPadding (контейнер 40dp в зоне 48dp).
```

Построен на `RawTooltip` (Flutter 3.44): долгое нажатие, оверлей, `Semantics(tooltip)`, закрытие при
касании в другом месте, одна подсказка за раз.

Совпадает с Compose / токенами:
- `inverseSurface`, углы 4dp, `bodySmall` / `onInverseSurface`, поля 8×4dp, мин. 40×24dp, макс.
  ширина 200dp; текст прижат к началу, как в `Box` у `PlainTooltip`;
- позиция `abovePositioning`: по центру элемента, над ним с зазором 4dp; если не помещается —
  под ним; по обеим осям в пределах окна. `preferBelow` — `belowPositioning` (для app bar);
- появление и скрытие: масштаб 0.8 ↔ 1 (от центра) пружиной `FastSpatial`, прозрачность 0 ↔ 1
  `FastEffects`; при смене направления пружины сохраняют скорость; оверлей убирается, когда
  успокоилась более долгая пружина (`FastSpatial`, ≈416 мс);
- без тактильного отклика (в `handleGestures` его нет); клавиатура: видна, пока элемент в фокусе,
  Escape закрывает (`keyboardBehavior`).

Осознанные отличия:
1. **Когда скрывается.** По гайду «disappear 1.5 seconds after navigating away from the target
   region» — через 1,5 с после того, как палец отпущен (так же `RawTooltip.touchDelay`). В Compose
   неперсистентная подсказка живёт `TooltipDuration` = 1,5 с от показа или до отпускания, если оно
   позже. Уход курсора — тоже 1,5 с (в Compose сразу).
2. **Зазор от видимой границы.** Compose берёт границы якоря вместе с `minimumInteractiveComponentSize`,
   поэтому у `IconButton` визуальный зазор 8dp. Гайд требует 4dp от видимой границы — это
   `anchorPadding`. Видимую границу автоматически не определить, её передаёт вызывающий код.
3. **Порог долгого нажатия** — `kLongPressTimeout` Flutter (500 мс); в Compose —
   `ViewConfiguration.longPressTimeoutMillis` Android (400 мс по умолчанию).
4. **Семантика.** Текст подсказки сливается с узлом кнопки (`MergeSemantics`). Действие
   `onLongClick` с подписью, которое добавляет `anchorSemantics` в Compose, не добавляется;
   роль `SemanticsRole.tooltip` не задаётся (см. «Доступность»).
5. Уменьшение движения: без масштаба, только прозрачность.

**Расхождения**

| # | Сейчас | Должно быть | Источник |
|---|---|---|---|
| 1 | Фон `primary`, текст `onPrimary` (стиль метки слайдера MDC) | Фон `inverseSurface`, текст `onInverseSurface` | `PlainTooltipTokens`; Specs |
| 2 | `padding` 4dp со всех сторон | 8dp по горизонтали, 4dp по вертикали | Specs (поле 8dp); `PlainTooltipContentPadding` |
| 3 | min 28×28, без максимальной ширины | min ширина 40, min высота 24, max ширина 200dp | Specs (высота 24dp); `TooltipMinWidth/MinHeight`, `plainTooltipMaxWidth` |
| 4 | Позиция по умолчанию Flutter: **под** элементом, 24dp от центра цели. У 40-dp кнопки это случайно даёт зазор 4dp. У FAB 56dp подсказка **заходит на кнопку на 4dp** и уходит вниз к навигации | Над элементом с зазором 4dp от визуальной границы. Под элементом — только у кнопок в app bar | Guidelines → Placement; `rememberTooltipPositionProvider` |
| 5 | Затухание 150 / 75 мс `fastOutSlowIn`, без масштаба | Масштаб 0.8 → 1 `FastSpatial` и прозрачность `FastEffects` | `TooltipBox` |

**Что сделать во Flutter**
1. `tooltipTheme` в `buildTheme`:
   - `decoration: BoxDecoration(color: scheme.inverseSurface, borderRadius: AppShapes.all(AppShapes.extraSmall))`;
   - `textStyle: textTheme.bodySmall!.copyWith(color: scheme.onInverseSurface)`;
   - `padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)`;
   - `constraints: BoxConstraints(minWidth: 40, minHeight: 24, maxWidth: 200)`.

   Комментарий про `Widget.Material3.Tooltip` исправить.
2. Пункты 2 и 3 **сделаны** в `M3PlainTooltip` (см. «Реализация во Flutter»); осталось заменить
   `tooltip:` у icon buttons и FAB обёрткой (у кнопок в app bar — `preferBelow: true`, у
   `IconButton` — `anchorPadding: M3PlainTooltip.iconButtonPadding`).
   Позиция. Задать `positionDelegate` (есть у `Tooltip` во Flutter 3.44): `TooltipPositionContext`
   даёт `target`, `targetSize` и `tooltipSize`. Подсказку ставить над визуальной границей
   элемента с зазором 4dp, а если не помещается — под ней. Учесть, что цель `IconButton` — это
   область касания 48dp, а визуальная граница — 40dp. Для кнопок в `AppBar` / `SliverAppBar`
   ставить `preferBelow` под элементом с тем же зазором.
3. Анимация. Материальный `Tooltip` жёстко использует `FadeTransition`. Для перехода Compose
   нужна своя обёртка над `RawTooltip`: `tooltipBuilder` с
   `ScaleTransition(0.8 → 1)` + `FadeTransition`. Длительности и кривые брать из
   `AppMotion.fastSpatial` и `AppMotion.fastEffects` (`animationStyle`). Все `tooltip:` у
   `IconButton` и FAB тогда заменить этой обёрткой.
4. После изменений снять скриншоты подсказок у FAB и у кнопок в app bar и проверить, что
   подсказка не перекрывает элемент.

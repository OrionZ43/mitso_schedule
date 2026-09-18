# Форма (Shape)

> Разделы «В приложении → Расхождения» описывают состояние на 16.09.2026, до порта компонентов. Исправлено с тех пор: эталонная статичная схема и системные роли Android 14+, emphasized-веса по токенам, opsz и grade иконок, state layer, цвета tooltip, чипов и app bar при прокрутке, scrim 32%, выдуманные альфы, размеры шрифта и радиусы (карточка пары и метки удалены), пустое состояние из `MaterialShapes`, пружины кнопок, листов и снекбара, смена дня — lateral. Остаётся: breakpoints и navigation rail для окон шире 600dp (приложение для телефона), часть отступов вне токенов в старом коде.

## Источники

- m3.material.io: https://m3.material.io/styles/shape (вкладки Overview & principles, Corner radius scale, Shape morph) → `.m3-guidelines/styles__shape.md`; блог https://m3.material.io/blog/building-with-m3-expressive → `building-with-m3-expressive.md`
- Compose Material3:
  - `Shapes.kt` — класс `Shapes` (`extraSmall` … `extraExtraLarge`), `ShapeDefaults`, `CornerFull = CornerSize(100)`, `Shapes.fromToken`
  - `tokens/ShapeTokens.kt`, `tokens/ShapeKeyTokens.kt`
  - `MaterialShapes.kt` — 35 форм (`RoundedPolygon`), `RoundedPolygon.toShape()`, `Morph.toPath()`
  - `LoadingIndicator.kt` — `LoadingIndicatorDefaults.IndeterminateIndicatorPolygons` / `DeterminateIndicatorPolygons`
  - `Button.kt` (`shapeByInteraction`), `tokens/Button{XSmall,Small,Medium,Large,XLarge}Tokens.kt`, `tokens/FilledCardTokens.kt`, `tokens/OutlinedCardTokens.kt`, `tokens/SheetBottomTokens.kt`, `tokens/ListTokens.kt`, `tokens/CheckboxTokens.kt`, `tokens/FabBaselineTokens.kt`, `tokens/PlainTooltipTokens.kt`, `tokens/SnackbarTokens.kt`
- MDC-Android: `docs/theming/Shape.md` (`ShapeAppearance.Material3.Corner.*`, `shapeCornerSize*`)
- Flutter: `material_new_shapes` 1.0.0 (Dart-порт `androidx.graphics.shapes` + `MaterialShapes`)

## Правила

### Шкала скруглений (10 ступеней)

| Токен | Значение | Compose | MDC |
|---|---|---|---|
| none | 0dp | `CornerNone` | `Corner.None` |
| extra-small | 4dp | `CornerExtraSmall` | `Corner.ExtraSmall` |
| small | 8dp | `CornerSmall` | `Corner.Small` |
| medium | 12dp | `CornerMedium` | `Corner.Medium` |
| large | 16dp | `CornerLarge` | `Corner.Large` |
| **large-increased** (Expressive) | 20dp | `CornerLargeIncreased` | `Corner.LargeIncreased` |
| extra-large | 28dp | `CornerExtraLarge` | `Corner.ExtraLarge` |
| **extra-large-increased** (Expressive) | 32dp | `CornerExtraLargeIncreased` | `Corner.ExtraLargeIncreased` |
| **extra-extra-large** (Expressive) | 48dp | `CornerExtraExtraLarge` | `Corner.ExtraExtraLarge` |
| full | полностью скруглено | `CircleShape` / `CornerSize(100)` | `Corner.Full` = 50% |

- Expressive-обновление (май 2025): добавлены large-increased, extra-large-increased, extra-extra-large; «fully rounded» теперь токен **full** (раньше — 50% размера компонента).
- Есть и односторонние токены: `CornerExtraLargeTop` (28 сверху), `CornerExtraSmallTop`, `CornerLargeTop/Start/End`.
- Асимметричные формы используют ту же шкалу; «inner corners» (menus, split buttons, группы) маппятся на токены отдельных углов.
- Кастомизация — на уровне стиля (изменить значение `medium` для всех) или компонента (перемапить компонент на другую ступень). Значения вне шкалы гайдлайн не описывает.
- CAUTION: «Be careful not to apply large or full corners to information-dense components, such as cards».
- **Оптическая скруглённость** вложенных форм: `внешний радиус − отступ = внутренний радиус` (пример: 48 − 14 = 34dp). Одинаковые радиусы у вложенных объектов — DON'T.

### Библиотека форм (35 форм) и морфинг

- `MaterialShapes`: Circle, Square, Slanted, Arch, Fan, Arrow, SemiCircle, Oval, Pill, Triangle, Diamond, ClamShell, Pentagon, Gem, Sunny, VerySunny, Cookie4Sided, Cookie6Sided, Cookie7Sided, Cookie9Sided, Cookie12Sided, Ghostish, Clover4Leaf, Clover8Leaf, Burst, SoftBurst, Boom, SoftBoom, Flower, Puffy, PuffyDiamond, PixelCircle, PixelTriangle, Bun, Heart.
- Где применять (по гайдлайну): декоративные элементы и изображения — «image crops and avatars», «photography cropping, personalized avatar masking, and other non-interactive elements»; контейнеры в карусели — для «moments of delight». Абстрактные формы — «sparingly»; не на текстонасыщенных контейнерах; форма «versatile, not semantic» (не закреплять смысл за конкретной формой).
- Морфинг — для состояний взаимодействия (например, выбранная кнопка), действий в процессе (загрузка), изменений окружения. Компоненты с морфингом: standard button group и loading indicator. Морф по умолчанию использует expressive motion scheme.
- Loading indicator (Compose): неопределённый — SoftBurst → Cookie9Sided → Pentagon → Pill → Sunny → Cookie4Sided → Oval; определённый — Circle → SoftBurst.
- «Tension»: сочетать круглые и квадратные формы, «Break from the surrounding shape style to draw attention».
- В приложении: номер аудитории на карточке пары
  (Cookie9Sided из правого верхнего угла, выбор заказчика 17.09.2026). Гайд советует абстрактные
  формы для декора, а не для текстовых контейнеров; здесь форма несёт короткий номер и
  обрезана краем карточки — записано в README, п. 21.
- Пустое состояние (`lib/widgets/empty_state.dart`): три слоя, каждый морфится по своему циклу
  форм и медленно вращается. Основания в гайде: «Emphasize aesthetic moments with shape»
  (декоративные, неинтерактивные места), «Shape is versatile, not semantic — **Progress could
  just as easily be shown using rotating shapes or shape morph**», «Shape can be 2.5D — **apply
  motion and shape differently on each layer to give it the illusion of depth**», «Shape
  morphing uses the expressive motion scheme by default». Циклы: `circle → cookie9Sided → oval →
  clover4Leaf`, `square → slanted → gem → diamond`, `triangle → arrow → pentagon →
  pixelTriangle` — круглые и угловатые вперемешку («tension»). Числа и отступления — в
  `motion.md` и README, п. 23.
- Морф во Flutter — `Morph(start.normalized(), end.normalized()).toPath(progress:, path:)` из
  `material_new_shapes`; `Morph` создаётся один раз (сопоставление кривых в конструкторе), путь
  пишется в переиспользуемый буфер.

### Формы компонентов (для сверки)

| Компонент | Токен |
|---|---|
| Кнопки XS/S/M/L/XL в покое (round) | full |
| Нажатие: XS и S / M / L и XL | small / medium / large |
| Square-вариант: XS и S / M / L и XL | medium / large / extra-large |
| Card (filled, outlined) | medium |
| Bottom sheet | extra-large-top |
| FAB (baseline 56dp) | large |
| List item (expressive) | extra-small; hover — medium; focus/drag — large; контейнер списка — large |
| Checkbox | 2dp (`CheckboxTokens.ContainerShape`) |
| Plain tooltip, Snackbar | extra-small |

## Как устроено в Compose

- `MaterialTheme.shapes: Shapes` (8 ступеней, `none` и `full` — отдельно). Компоненты берут `ShapeKeyTokens.X.value` → `Shapes.fromToken`.
- `ShapeDefaults.CornerFull = CornerSize(100)` — процентное скругление, форма остаётся «таблеткой» при любом размере.
- Морф прямоугольных форм кнопок: `shapeByInteraction(shapes, pressed, animationSpec)` → `rememberAnimatedShape(RoundedCornerShape, spec)`; spec у `Button` — DefaultEffects, у `ToggleButton` и selectable chips (`Chip.kt`) — FastSpatial.
- Полигоны: `MaterialShapes.Cookie9Sided.toShape()` для `Modifier.clip`, `Morph(start, end).toPath(progress)` для анимации.

## В приложении

### Как сейчас

- `lib/theme/app_shapes.dart` — шкала 0/4/8/12/16/20/28/32/48 совпадает с токенами; `fullRadius = Radius.circular(9999)`, `stadium`; семантические алиасы `card = extraLarge` (помечено как согласованное отступление), `cardEmphasized = extraLargeIncreased`, `bottomSheet = extraLarge`, `chip = small`, `fab = large`, `dayUnselected = large`.
- `lib/app.dart` — card 28dp, chip 8dp, FAB 16dp, bottom sheet 28dp сверху, tooltip/snackbar 4dp, checkbox 2dp, search bar stadium.
- `lib/theme/app_button_styles.dart` — full в покое, small/medium при нажатии.
- `lib/widgets/m3_loading_indicator.dart` — `MaterialShapes` из `material_new_shapes`, порядок как в Compose.
- Кастомные контейнеры: `absences_screen.dart` и `profile_screen.dart` (32dp), `schedule_screen.dart` (баннер ошибки 16dp; результаты поиска `ListTile` 20dp), `lesson_card.dart` (строки подгрупп 16/4), `segmented_list.dart` (16/4), `day_selector.dart` (16 → 28 морф).

### Расхождения

| # | Сейчас | Должно быть | Источник |
|---|---|---|---|
| 1 | `features/absences/widgets/certificate_sheet.dart:127,132` — радиус `AppShapes.large + 8` = **24dp — нет на шкале**; пунктир 7/5, толщина 2 и полосатый градиент — **придуманы** | Ступень шкалы (large-increased 20 или extra-large 28); пунктир/градиент в источниках не нашёл | `styles__shape.md` (Corner radius scale) |
| 2 | `widgets/empty_state.dart:116` — `BorderRadius.circular(square * 0.34)`, поворот 14°, самодельный `_TriangleClipper`, кружки `BoxShape.circle` — **придуманные** декоративные формы | Декор — формами библиотеки (`MaterialShapes.circle`, `.triangle`/`.pixelTriangle`, `.cookie*`, `.sunny` и т. п. из `material_new_shapes`) | `styles__shape.md` («Use abstract shapes on imagery and decorative UI»), `MaterialShapes.kt` |
| 3 | `features/schedule/schedule_screen.dart:536` — результаты поиска `ListTile(shape: largeIncreased)` (20dp) | List item expressive — extra-small; hover — medium; focus/drag — large | `tokens/ListTokens.kt` |
| 4 | Вложенные контейнеры с тем же или бóльшим радиусом: `absences_screen.dart` — контейнер 32dp, отступ 20 → плитки легенды 20dp; `lesson_card.dart` — карточка 28dp (32 у текущей), отступ 20 (22) → строки подгрупп 16dp | По формуле оптической скруглённости: 32 − 20 = 12 (medium); 28 − 20 = 8 (small); 32 − 22 = 10 — нет на шкале, подобрать отступ | `styles__shape.md` (Adjust for optical roundness) |
| 5 | `AppShapes.card = 28dp` для текстонасыщенных карточек пар/справок/задач | Card — medium 12dp; гайдлайн предостерегает от large/full на информационно-плотных карточках. Отступление согласовано — держать в «Сознательных отступлениях» | `tokens/FilledCardTokens.kt`, `tokens/OutlinedCardTokens.kt`, `styles__shape.md` (CAUTION) |
| 6 | `AppShapes.fullRadius = Radius.circular(9999)` (в `lib/` сейчас не используется; `connected_button_group.dart` берёт половину высоты, кнопки — `StadiumBorder`) | Full = 100%/50% размера. Если понадобится в анимации — не лерпить от 9999: видимое изменение сожмётся в последние доли процента анимации | `Shapes.kt` (`CornerFull = CornerSize(100)`), `docs/theming/Shape.md` |
| 7 | Аватар профиля (`profile_screen.dart`) — круг 72dp с иконкой | Не нарушение. Гайдлайн прямо предлагает формы библиотеки для «avatar masking» — вариант для выразительности | `styles__shape.md`, `building-with-m3-expressive.md` |

Что совпадает: значения шкалы; формы кнопок (full → small/medium при нажатии); FAB, bottom sheet, tooltip, snackbar, checkbox; сегментированный список 16/4 (`ListTokens`: контейнер large, элемент extra-small); последовательность форм `M3LoadingIndicator`.

### Что сделать во Flutter

1. Удалить `AppShapes.large + 8` и любые радиусы вне шкалы; добавить в `AppShapes` проверку (например, `assert` в `AppShapes.all`), что радиус — ступень шкалы.
2. Декор пустого состояния собрать из `MaterialShapes` (`material_new_shapes`), рисуя `RoundedPolygon` через `CustomPainter`/`ClipPath`.
3. Для вложенных контейнеров считать радиус по формуле «внешний − отступ» и подбирать отступ так, чтобы результат попадал на шкалу.
4. `ListTile` в поиске — extra-small (или стандартный список без формы).
5. Full выражать `StadiumBorder`, а в анимируемых `BorderRadius` — через половину фактической высоты, а не 9999; неиспользуемый `fullRadius` удалить.

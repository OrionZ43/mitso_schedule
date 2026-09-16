# Индикатор загрузки (Loading indicator)

Статус в приложении: ⚠️ частично

`M3LoadingIndicator` честно перенесён, но с **MDC-Android (Views)**, а не с Compose. Из-за этого
отличаются размер форм и характер морфинга. Кроме того, по умолчанию включён контейнер, нет
определённого (determinate) варианта для pull-to-refresh, нет роли progress bar, а в кнопке
отправки справки индикатор теряет контраст.

## Источники
- Guidelines / Specs / Accessibility: https://m3.material.io/components/loading-indicator/guidelines,
  https://m3.material.io/components/loading-indicator/specs,
  https://m3.material.io/components/loading-indicator/accessibility
  (выгрузка: `.m3-guidelines/components__loading-indicator.md`)
- Compose API: https://developer.android.com/reference/kotlin/androidx/compose/material3/package-summary —
  `LoadingIndicator(modifier, color, polygons)`, `LoadingIndicator(progress, modifier, color, polygons)`,
  `ContainedLoadingIndicator(modifier, containerColor, indicatorColor, containerShape, polygons)`,
  `ContainedLoadingIndicator(progress, …)`, `LoadingIndicatorDefaults`
  (`IndeterminateIndicatorPolygons`, `DeterminateIndicatorPolygons`, `ContainerWidth/Height`,
  `IndicatorSize`, `containedContainerColor`, `containedIndicatorColor`)
- Compose исходник: `LoadingIndicator.kt`: два `LoadingIndicatorImpl` (indeterminate и
  determinate), `morphSequence`, `calculateScaleFactor`, `processPath`, константы
  `GlobalRotationDurationMillis = 4666` и `MorphIntervalMillis = 650`. Токены:
  `tokens/LoadingIndicatorTokens.kt`. Примеры: `samples/LoadingIndicatorSamples.kt`
  (`LoadingIndicatorSample`, `ContainedLoadingIndicatorSample`, `DeterminateLoadingIndicatorSample`,
  `DeterminateContainedLoadingIndicatorSample`, `LoadingIndicatorPullToRefreshSample`)
- MDC: https://github.com/material-components/material-components-android/blob/master/docs/components/LoadingIndicator.md,
  исходники `loadingindicator/LoadingIndicatorDrawingDelegate.java`,
  `LoadingIndicatorAnimatorDelegate.java`, `res/values/styles.xml`
- Flutter: в SDK 3.44 компонента нет (`material/progress_indicator.dart` содержит только
  `LinearProgressIndicator` и `CircularProgressIndicator`). В приложении свой порт
  `lib/widgets/m3_loading_indicator.dart`. Формы и морфинг берутся из пакета
  `material_new_shapes` (Dart-порт `androidx.graphics.shapes`: `MaterialShapes`, `Morph`,
  `RoundedPolygon.normalized/calculateBounds/calculateMaxBounds`).

## Когда использовать
- Для коротких ожиданий **от 200 мс до 5 с**. До 200 мс индикатор не нужен, дольше 5 с нужен
  progress indicator (таблица в Guidelines → Usage). Заменяет большинство неопределённых
  круговых progress indicator.
- Только для реального процесса, не для украшения (Overview).
- Если процесс может стать определённым (стало известно, сколько осталось), нужны progress
  indicators. **Loading indicator в progress indicator не превращают** (Guidelines → Usage,
  DON'T).
- Размещение: по центру загружаемой страницы или контейнера. При дозагрузке — в пустом месте,
  где появится контент, не поверх существующего (Guidelines → Placement). Можно в кнопке или
  вместо иконки вкладки.
- **Контейнер** нужен, когда индикатор лежит поверх другого контента, и обязателен в
  pull-to-refresh. Когда индикатор стоит прямо на поверхности, контейнер не нужен
  (Guidelines → Container).

## Варианты и анатомия
- Анатомия: active indicator (зацикленный морф семи форм) и container (необязательный круг).
- Конфигурации: Default (без контейнера) и Contained (Specs → Configurations).
- В Compose четыре функции: `LoadingIndicator` и `ContainedLoadingIndicator`, каждая в
  неопределённом варианте и в варианте с `progress`.
  - Неопределённый: `IndeterminateIndicatorPolygons` = `SoftBurst`, `Cookie9Sided`, `Pentagon`,
    `Pill`, `Sunny`, `Cookie4Sided`, `Oval`, по кругу: после последней формы снова первая
    (`morphSequence(circularSequence = true)`).
  - Определённый: `DeterminateIndicatorPolygons` = `Circle`, повёрнутый на 360/20 = 18°, →
    `SoftBurst`, без замыкания. Этот вариант используется в pull-to-refresh, пока тянут палец
    (см. `pull-to-refresh.md`).
  - `polygons` можно передать свои, минимум две формы (`require(size > 1)`).

## Размеры, формы, цвета

| Токен | Значение | Compose |
|---|---|---|
| `md.comp.loading-indicator.container.width/height` | 48dp | `LoadingIndicatorTokens.ContainerWidth/Height` |
| `md.comp.loading-indicator.active-indicator.size` | 38dp | `LoadingIndicatorTokens.ActiveSize` → `IndicatorSize` |
| `md.comp.loading-indicator.container.shape` | `corner.full` | `ContainerShape` |
| `md.comp.loading-indicator.active-indicator.color` (без контейнера) | `primary` | `ActiveIndicatorColor` |
| `md.comp.loading-indicator.contained.container.color` | `primary-container` | `ContainedContainerColor` |
| `md.comp.loading-indicator.contained.active-indicator.color` | `on-primary-container` | `ContainedActiveColor` |

- В выгрузке есть ещё `md.comp.loading-indicator.container.color = secondary-container`, и
  подпись к картинке «container is secondary container». Ни Compose, ни MDC этот токен не
  используют: у варианта без контейнера фон прозрачный (`Color.Unspecified` / `transparent`),
  у контейнерного — `primaryContainer`.
- Размер гибкий, **от 24 до 240dp**. Соотношение контейнера и формы при масштабировании не
  меняется (Guidelines → Responsive layout). В Compose форма рисуется от фактического размера
  (`Spacer.aspectRatio(1)` внутри `Box`).
- **Как Compose вписывает формы.** Все формы нормализуются по своим границам (`normalized()`).
  Затем берётся **один общий** коэффициент для всей последовательности:
  `calculateScaleFactor` = min по формам от max(bounds.w/maxBounds.w, bounds.h/maxBounds.h),
  умноженный на `ActiveIndicatorScale` = 38/48. Для стандартного набора коэффициент ≈ 0,866
  (посчитано тем же алгоритмом на `material_new_shapes` 1.0.0). Значит, у каждой формы границы
  ≈ 32,9dp, а самая «широкая при вращении» форма (`Oval`) заметает ровно 38dp.
- **Как это делает MDC (и приложение).** Стиль `Widget.Material3.LoadingIndicator` задаёт
  `indicatorSize` = 34dp, хотя таблица в `LoadingIndicator.md` пишет 38dp. Каждая форма
  **отдельно** нормализуется по `calculateMaxBounds` в квадрат 34dp.

| Форма | Границы формы в Compose | Границы формы в приложении (MDC) |
|---|---|---|
| SoftBurst | 32,9dp | 34,6dp |
| Cookie9Sided | 32,9dp | 34,9dp |
| Pentagon | 32,9dp | 32,8dp |
| Pill | 32,9dp | 32,2dp |
| Sunny | 32,9dp | 34,4dp |
| Cookie4Sided | 32,9dp | 32,4dp |
| Oval | 32,9dp | **29,4dp** |

## Состояния и движение
**Неопределённый вариант, Compose (`LoadingIndicator.kt`, `LoadingIndicatorImpl` без `progress`):**
- Морф. `Animatable morphProgress` анимируется 0 → 1 пружиной
  `spring(dampingRatio = 0.6f, stiffness = 200f, visibilityThreshold = 0.1f)`. Порог в 10 раз
  выше стандартного, чтобы пружина уложилась в 650 мс (комментарий в коде). Цикл: `async`-анимация,
  затем `delay(MorphIntervalMillis = 650)`, затем `await`. Когда анимация завершилась
  (`AnimationEndReason.Finished`), выполняется `currentMorphIndex = (i + 1) % 7`,
  `snapTo(0f)` и `morphRotationTargetAngle += 90°`. Начальное значение угла 90°.
- Общее вращение `globalRotation` идёт 0 → 360° за `GlobalRotationDurationMillis = 4666` мс
  (`LinearEasing`, `infiniteRepeatable`, `RepeatMode.Restart`).
- Угол отрисовки = `morphProgress × 90 + morphRotationTargetAngle + globalRotation`, по часовой.
  В `Morph.toPath` передаётся `morphProgress.value` без ограничения, хотя комментарий говорит
  «coerced».
- Если установлен `InfiniteAnimationPolicy` (тесты), бесконечная анимация проходит через него.

**Определённый вариант, Compose (`LoadingIndicatorImpl(progress, …)`):**
- Своей анимации нет, прогресс анимирует вызывающий код. Номер морфа =
  `floor(morphSequence.size × progress)`, прогресс внутри морфа =
  `(progress × size) % 1` (при `progress == 1` на последнем морфе берётся 1).
- Поворот `-progress × 180°`, **против часовой**.
- В `DeterminateLoadingIndicatorSample` прогресс сглажен пружиной
  `spring(DampingRatioNoBouncy, StiffnessVeryLow, visibilityThreshold = 1/1000)`.

**MDC и приложение (`LoadingIndicatorAnimatorDelegate`):**
- Линейный аниматор длительностью 650 мс повторяется бесконечно. На каждом повторе
  (`onAnimationRepeat`) пружину `SpringForce(stiffness 200, dampingRatio 0.6)`, порог 0.01,
  перенацеливают на `++morphFactorTarget` с сохранением текущей скорости.
- Угол = 140°×base + 50°×t + 90°×(morphFactor − base); холст заранее повёрнут на −90°.

**Итог сравнения.** Постоянное вращение почти одинаковое: 360/4666 × 650 ≈ 50,15° на шаг в
Compose против 50° в MDC. Плюс 90° на морф есть в обоих. Различия:
1. В Compose каждый морф начинается с нуля и с нулевой скоростью, быстро завершается
   (порог 0.1) и держит форму до конца 650 мс. В MDC пружина перенацеливается на лету и переносит
   скорость в следующий морф.
2. Начальная ориентация отличается на 180°: +90° в Compose, −90° в MDC.

## Доступность
- Форма (active indicator) должна иметь контраст **≥ 3:1** с фоном. К контейнеру требование не
  относится. Внутри другого компонента, например кнопки, нужно ≥ 3:1 к этому компоненту
  (Accessibility → Interaction & style).
- Нужна подпись о назначении, например «refreshing page», и роль **progress bar**
  (Accessibility → Labeling elements).
- Pull-to-refresh должен дублироваться обычной кнопкой (см. `pull-to-refresh.md`).
- В Compose неопределённый вариант задаёт `Modifier.progressSemantics()`, определённый —
  `semantics(mergeDescendants = true) { progressBarRangeInfo = … }`. Подписи по умолчанию нет,
  её задаёт вызывающий код. В MDC `contentDescription` по умолчанию берётся из
  `@string/m3_loading_indicator_content_description`.
- Во Flutter похоже устроен `ProgressIndicator._buildSemanticsWrapper`
  (`progress_indicator.dart`): `Semantics(label, role: SemanticsRole.loadingSpinner)`, а для
  определённого варианта `role: SemanticsRole.progressBar`, `minValue`, `maxValue`, `value`.

## В приложении
### Реализация во Flutter
`lib/widgets/m3_loading_indicator.dart` переписан с MDC на Compose `LoadingIndicator.kt`.
Строки таблицы «Расхождения» ниже с номерами 1–8 и 11 закрыты. Строки 9 (контраст в
кнопке «Отправить») и 10 (задержка 200 мс на загрузочном экране) касаются экранов и остаются
открытыми.

**Совпадает с Compose**
- API: `M3LoadingIndicator(contained, size, color, containerColor, polygons, semanticsLabel)`
  и `M3LoadingIndicator.determinate(progress: …)`. По умолчанию `contained: false`, цвет
  `primary`. С контейнером: круг `primaryContainer`, форма `onPrimaryContainer`. Сторона по
  умолчанию 48dp, допустимо от 24 до 240dp (assert). Форма рисуется от фактического размера.
- Формы. `IndeterminateIndicatorPolygons` и `DeterminateIndicatorPolygons` (круг, повёрнутый
  на 18°, и SoftBurst). Каждая форма проходит `normalized()` в `morphSequence`. Коэффициент
  один на всю последовательность: `calculateScaleFactor × 38/48` (для стандартного набора
  ≈ 0,866). Путь масштабируется и центрируется по `getBounds()`, как в `processPath`, затем
  поворачивается вокруг центра.
- Неопределённый вариант (`LoadingIndicatorMotion.frameAt`). Каждые 650 мс запускается новая
  пружина 0 → 1: 0.6 / 200, порог 0.1. Когда она завершается, `snapTo(0)`, индекс +1, цель
  угла +90° (по модулю 360°), начальный угол 90°. Общее вращение линейное, 360° за 4666 мс.
  Угол = `morph × 90 + цель + общее вращение`.
- Момент завершения пружины считается как в Compose: `estimateAnimationDurationMillis`, порт в
  `lib/theme/compose_spring.dart`. Для 0 → 1 это 297 мс, то есть меньше интервала.
- Определённый вариант: номер морфа = `floor(n × p)`, доля = `(p × n) % 1`, при `p == 1`
  берётся 1, поворот `−p × 180°`. Своей анимации нет.
- Семантика как у Flutter `ProgressIndicator`: неопределённый — `SemanticsRole.loadingSpinner`,
  определённый — `progressBar` с `minValue`/`maxValue`/`value`. Live region нет.

**Уменьшение движения** (`reduceMotionOf`, «Удалить анимации»). Поведение взято из Compose при
`MotionDurationScale = 0` (`SuspendAnimation.kt`, `doAnimationFrameWithScale`): анимации
заканчиваются в первом кадре, а `delay(650)` работает как обычно. Раз в 650 мс форма
сменяется следующей без морфа и поворачивается на 90°, общего вращения нет. Между шагами кадры
не перерисовываются. Это же требует правило «Follows accessibility settings» из
`styles/motion/transitions`: без shape morphing.

**Отступления**
- Если сменить набор `polygons`, цикл начинается заново: индекс 0, угол 90°. В Compose
  `morphProgress`, угол и общее вращение хранятся в `remember` без ключа и продолжаются с
  текущих значений. В приложении набор форм не меняется.
- Интервал 650 мс отсчитывается от первого кадра тикера. В Compose `delay` не привязан к
  кадрам, поэтому возможна разница в один кадр.

**Где используется**
- `lib/widgets/m3_loading_indicator.dart` — `M3LoadingIndicator`, `LoadingIndicatorMotion`,
  `LoadingIndicatorShapes`.
- `lib/features/boot/boot_screen.dart` — по центру экрана, с контейнером, 48dp.
- `lib/features/schedule/schedule_screen.dart` — первая загрузка без кеша
  (`SliverFillRemaining` + `Center`), с контейнером.
- `lib/features/group_picker/group_picker_sheet.dart` — загрузка списка в шите, с контейнером.
- `lib/features/absences/widgets/certificate_sheet.dart` — внутри `FilledButton` «Отправить»:
  `contained: false`, 24dp, цвет `onPrimary`.
- `lib/widgets/m3_pull_to_refresh.dart` — с контейнером (см. `pull-to-refresh.md`).
- `test/indicators_geometry_test.dart` проверяет **константы MDC**: 650 мс, 50°/90°, пружина
  200/0.6, 48/34dp. Ещё проверяются 7 форм, сцепка морфов и то, что индикатор анимируется.

**Расхождения**

| # | Сейчас | Должно быть | Источник |
|---|---|---|---|
| 1 | Каждая форма отдельно вписана по max bounds в 34dp: Oval 29,4dp, SoftBurst 34,6dp и т. д. | Токен 38dp и общий коэффициент: границы всех форм ≈ 32,9dp, Oval при вращении заметает 38dp | `LoadingIndicatorTokens.ActiveSize`, `calculateScaleFactor`, `processPath` |
| 2 | Пружина MDC перенацеливается каждые 650 мс с переносом скорости | Каждые 650 мс новая пружина 0 → 1 (0.6 / 200, порог 0.1), по завершении `snapTo(0)`, индекс +1, угол +90° | `LoadingIndicatorImpl` (indeterminate) |
| 3 | Постоянный поворот 50° за шаг внутри формулы | Отдельное линейное вращение 360° за 4666 мс | `GlobalRotationDurationMillis` |
| 4 | Начальный поворот −90° (холст MDC) | Начальный угол 90° | `morphRotationTargetAngle = QuarterRotation` |
| 5 | По умолчанию `contained: true`: контейнер на загрузочном экране, в расписании и в шите выбора группы, хотя везде индикатор стоит прямо на поверхности | Без контейнера (`primary`). Контейнер — только поверх контента и в pull-to-refresh | Guidelines → Container. В Compose и MDC по умолчанию вариант без контейнера |
| 6 | Нет определённого варианта | `LoadingIndicator(progress)`: Circle(18°) → SoftBurst, поворот −180°×progress | `DeterminateIndicatorPolygons`, `LoadingIndicatorImpl(progress)` |
| 7 | Набор форм нельзя передать | Параметр `polygons` (≥ 2 формы) | Compose API |
| 8 | `Semantics(label, liveRegion: true)`, без роли | Роль progress bar / loading spinner, без live region (в Compose его нет) | Accessibility → Labeling; `progressSemantics()` |
| 9 | В кнопке «Отправить» цвет `onPrimary`, но кнопка на время отправки отключена (`onPressed: null`). Фон отключённой `FilledButton` — `onSurface` 12 % (`_FilledButtonDefaultsM3`). Контраст белой формы к нему по оценке ~1,4:1 в светлой теме | ≥ 3:1 к кнопке, цвет как у подписи кнопки | Accessibility → Interaction & style; Progress indicators → «Progress indicators in buttons» |
| 10 | `BootScreen` показывает индикатор сразу. Если запуск короче 200 мс, индикатор мелькнёт | До 200 мс индикатор не показывают | Guidelines → Usage (таблица). В MDC для этого есть `app:showDelay` |
| 11 | Комментарий в коде объясняет 34dp стилем MDC | Эталон — Compose (`CLAUDE.md`), там 38dp | — |

**Что сделать во Flutter**
1. `LoadingIndicatorShapes`: нормализовать формы через `normalized()`, как `morphSequence`.
   Посчитать один коэффициент `k` как в `calculateScaleFactor` (`calculateBounds` и
   `calculateMaxBounds` уже есть в `material_new_shapes`). Путь морфа масштабировать на
   `side × 38/48 × k` и центрировать по его `getBounds().center`, как `processPath`.
   Стартовый поворот холста −90° убрать.
2. `LoadingIndicatorMotion` переписать на модель Compose:
   - вращение `globalDeg = (elapsed % 4666 мс) / 4666 × 360`;
   - морф: в начале каждого 650-мс интервала `SpringSimulation(mass 1, stiffness 200, ratio 0.6)`
     от 0 до 1 со скоростью 0. Когда пружина «готова», сделать snap к 0, индекс +1 и угол +90°.
     Порог Compose `visibilityThreshold = 0.1` — это оценка длительности, а не `Tolerance`
     Flutter. Подобрать `Tolerance(distance: 0.1)` и тестом проверить, что морф укладывается в
     650 мс.
   - угол = `morph × 90 + targetAngle(старт 90) + globalDeg`.
3. Добавить `M3LoadingIndicator.determinate({required double progress})`: формы
   `[circle, повёрнутый на 18°; softBurst]` без замыкания, выбор морфа и поворот `-progress × 180`
   как в `LoadingIndicatorImpl(progress)`.
4. По умолчанию `contained: false`. В `boot_screen.dart`, `schedule_screen.dart` и
   `group_picker_sheet.dart` оставить вариант без контейнера. Контейнер — только в
   `M3PullToRefresh`.
5. Семантика: `Semantics(label: …, role: SemanticsRole.loadingSpinner)`, для определённого
   варианта — `role: SemanticsRole.progressBar` с `minValue: '0'`, `maxValue: '100'`, `value`.
   `liveRegion` убрать.
6. `certificate_sheet.dart`: цвет формы должен давать ≥ 3:1 к фактическому фону кнопки. Есть
   два варианта:
   - не отключать кнопку визуально на время отправки и блокировать повторное нажатие иначе.
     Тогда `onPrimary` на `primary` корректен;
   - использовать цвет подписи отключённой кнопки и измерить контраст. У `onSurface` 38 % на
     `onSurface` 12 % он, скорее всего, тоже ниже 3:1.
7. `BootScreen`: не показывать индикатор первые 200 мс, например через `FutureBuilder` или
   `AnimatedSwitcher` с задержкой. Норма — таблица ожиданий из Guidelines.
8. Необязательно: параметр `polygons`.
9. Тесты в `test/indicators_geometry_test.dart` перевести на константы Compose: 38dp и
   коэффициент `k`, 4666 мс, 650 мс, +90°, пружина 0.6/200/порог, старт 90°. Добавить тест
   определённого варианта.

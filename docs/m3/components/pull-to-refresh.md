# Обновление потягиванием (Pull-to-refresh)

Статус в приложении: ⚠️ частично

Отдельной страницы на m3.material.io нет. Правила — в разделе Behavior и Accessibility
loading indicator, эталон — `PullToRefresh.kt` из Compose. Что уже правильно: в
`M3PullToRefresh` используется loading indicator с контейнером, контент не сдвигается. Что
расходится: нет альтернативной кнопки обновления (обязательна по Accessibility), другие порог
и сопротивление жесту, пока тянут палец, крутится неопределённый индикатор вместо
определённого, есть своё масштабирование, другие позиция и пружины.

## Источники
- Guidelines / Accessibility: https://m3.material.io/components/loading-indicator/guidelines
  (Behavior → Pull-to-refresh, Threshold requirements),
  https://m3.material.io/components/loading-indicator/accessibility
  (выгрузка: `.m3-guidelines/components__loading-indicator.md`). Гайд ссылается на
  https://developer.android.com/develop/ui/compose/components/pull-to-refresh. В остальных
  выгруженных страницах (`components__*`, `foundations__*`, `styles__*`) pull-to-refresh не
  упоминается.
- Compose API: https://developer.android.com/reference/kotlin/androidx/compose/material3/package-summary —
  `PullToRefreshBox(isRefreshing, onRefresh, modifier, state, contentAlignment, indicator, enabled, threshold, content)`,
  `Modifier.pullToRefresh(isRefreshing, state, enabled, threshold, onRefresh)`,
  `rememberPullToRefreshState()`, `PullToRefreshState.distanceFraction`,
  `PullToRefreshDefaults.LoadingIndicator(state, isRefreshing, modifier, containerColor, color, elevation, maxDistance)`,
  `PullToRefreshDefaults.IndicatorBox(…)`, `PullToRefreshDefaults.PositionalThreshold`
- Compose исходник: `pulltorefresh/PullToRefresh.kt`: `PullToRefreshModifierNode` (`onPreScroll`,
  `onPostScroll`, `onPreFling`/`onRelease`, `calculateVerticalOffset`, `animateToThreshold`,
  `animateToHidden`), `PullToRefreshDefaults`, `PullToRefreshStateImpl`, константы
  `DragMultiplier`, `LoaderIndicatorWidth/Height`. Индикатор — `LoadingIndicator.kt`
  (`ContainedLoadingIndicator` в обоих вариантах). Примеры: `samples/PullToRefreshSamples.kt`
  (`PullToRefreshWithLoadingIndicatorSample`), `samples/LoadingIndicatorSamples.kt`
  (`LoadingIndicatorPullToRefreshSample` — вариант с масштабом)
- MDC: отдельного компонента в `docs/components` не нашлось (Android Views используют
  `SwipeRefreshLayout` из AndroidX). Не проверялось подробно.
- Flutter: `RefreshIndicator` (`material/refresh_indicator.dart`) рисует свой
  `RefreshProgressIndicator` (круговой спиннер M2/M3): `displacement` 40, `elevation` 2, зона
  протяжки 25 % высоты (`_kDragContainerExtentPercentage`), предел 1,5×
  (`_kDragSizeFactorLimit`), фиксированные длительности 150 и 200 мс.
  `RefreshIndicator.noSpinner(onStatusChange)` отдаёт только статусы
  (`drag`/`armed`/`snap`/`refresh`/`done`/`canceled`), **без доли протяжки**. Определённый
  loading indicator от него не построить, поэтому в приложении свой виджет
  `lib/widgets/m3_pull_to_refresh.dart`.

## Когда использовать
- В начале списков, сеток и наборов карточек, где сверху появляется свежий контент. Лучше всего
  подходит для часто меняющегося контента (Behavior → Pull-to-refresh).
- Индикатор может быть поверх контента или рядом с ним.
- **Порог:** обновление запускается, только если жест прошёл порог. Если вернуть палец назад
  за порог, обновление отменяется (Threshold requirements).
- Индикатор виден, пока обновление не закончится и новый контент не появится (или пока
  пользователь не уйдёт). **Индикатор не должен уезжать вместе с прокруткой** (DON'T).
- Для pull-to-refresh используется **loading indicator с контейнером** (Guidelines → Container).
- **Обязательна альтернатива жесту:** кнопка обновления в меню или app bar (Accessibility →
  Interaction & style). Во всех примерах Compose в `TopAppBar` есть
  `IconButton(onClick = onRefresh) { Icon(Icons.Filled.Refresh, "Trigger Refresh") }` с
  комментарием «Provide an accessible alternative to trigger refresh».

## Варианты и анатомия
- `PullToRefreshDefaults.LoadingIndicator` — это `IndicatorBox` (48×48dp, `CircleShape`,
  обрезка по форме, тень `LoadingIndicatorElevation`) и `Crossfade` между двумя
  `ContainedLoadingIndicator`:
  - пока тянут палец (`isRefreshing = false`) — **определённый**,
    `progress = { state.distanceFraction }`: Circle → SoftBurst, поворот −180°×progress;
  - во время обновления — **неопределённый** (зацикленный морф семи форм).
- `PullToRefreshBox` по умолчанию берёт `PullToRefreshDefaults.Indicator` (круговая стрелка и
  `CircularProgressIndicator`, контейнер `surfaceContainerHigh`, тень `Level2`). Вариант с
  loading indicator помечен `@material3expressive`, и гайд loading indicator называет именно
  его индикатором pull-to-refresh.

## Размеры, формы, цвета

| Параметр | Значение | Источник |
|---|---|---|
| Порог | 80dp | `PullToRefreshDefaults.PositionalThreshold` |
| Макс. дистанция индикатора | 80dp (= порог) | `IndicatorMaxDistance` |
| Множитель протяжки | 0,5 (палец 160dp → порог) | `DragMultiplier` |
| Контейнер | 48×48dp, круг | `LoaderIndicatorWidth/Height` = `LoadingIndicatorDefaults.ContainerWidth/Height`; `indicatorShape` |
| Цвет контейнера / формы | `primaryContainer` / `onPrimaryContainer` | `loadingIndicatorContainerColor` / `loadingIndicatorColor` → `LoadingIndicatorTokens.Contained*` |
| Тень | `Level0` (нет) | `LoadingIndicatorElevation` |
| Смещение индикатора | `translationY = distanceFraction × 80dp − 48dp`; при обновлении (fraction = 1) верх на 32dp | `IndicatorBox` |
| Обрезка | `clipRect(top = 0)`: индикатор выезжает из-под верхней кромки контейнера | `IndicatorBox` |

## Состояния и движение
**Жест (`PullToRefreshModifierNode`):**
- `onPostScroll` (источник `UserInput`, тянут вниз у верхнего края): `distancePulled += dy`,
  `adjusted = distancePulled × 0.5`, затем `state.snapTo(verticalOffset / threshold)`.
- `calculateVerticalOffset`: пока `adjusted ≤ threshold`, смещение = `adjusted`. Дальше
  `t = clamp(adjusted/threshold − 1, 0, 2)`, смещение = `threshold × (1 + t − t²/4)`, то есть
  «упругое» и не больше 2× порога.
- `onPreScroll` (тянут вверх): сначала уменьшается протяжка, и только потом прокручивается
  список.
- Во время обновления протяжка не принимается (`consumeAvailableOffset` возвращает 0).
- `onPreFling`/`onRelease`: если `adjusted > threshold`, вызывается `onRefresh()`. Бросок
  поглощается, только если индикатор был вытянут и бросок направлен вниз. Затем
  `animateToHidden()`. Пока приложение не выставит `isRefreshing = true`, после чего
  `update()` вызывает `animateToThreshold()`.
- `animateToThreshold` / `animateToHidden` — это `Animatable.animateTo(1f / 0f)` со
  спецификацией по умолчанию: `spring()` = `DampingRatioNoBouncy` (1.0), `StiffnessMedium`
  (1500). Значения констант — из compose animation-core, в клон не входит.

**Индикатор (`PullToRefreshDefaults.LoadingIndicator`):**
- `Crossfade(targetState = isRefreshing, animationSpec = MotionSchemeKeyTokens.DefaultEffects)`
  (Expressive: ratio 1.0, stiffness 1600).
- Пока тянут палец: определённый `ContainedLoadingIndicator(progress = distanceFraction)`,
  форма идёт Circle(18°) → SoftBurst, поворот `-progress × 180°`. При `distanceFraction > 1`
  весь индикатор дополнительно поворачивается на `-(progress − 1) × 180°`.
- Во время обновления: неопределённый `ContainedLoadingIndicator` (движение описано в
  `loading-indicator.md`).
- По умолчанию **масштаба нет**: индикатор выезжает и обрезается сверху. Масштабирование есть
  только в примере `LoadingIndicatorPullToRefreshSample`: `scale = LinearOutSlowInEasing`
  (0, 0, 0.2, 1) от `distanceFraction`, ограниченный 0..1, и 1 во время обновления. Во Flutter
  эта кривая — `Easing.legacyDecelerate`.

## Доступность
- Альтернативный способ обновить одним нажатием — обязателен (Accessibility → Interaction & style).
- Подпись индикатора описывает действие, например «refreshing page», роль progress bar
  (Accessibility → Labeling elements).
- Compose: определённый `ContainedLoadingIndicator` отдаёт `progressBarRangeInfo` с долей
  протяжки, неопределённый — `progressSemantics()`.

## В приложении
**Где используется**
- `lib/widgets/m3_pull_to_refresh.dart` — `M3PullToRefresh`: слушает `ScrollNotification`,
  копит overscroll у верхнего края, `triggerDistance` = 96, `displacement` = 24. Индикатор —
  `M3LoadingIndicator` (с контейнером) с `scale: Curves.easeOut.transform(fraction)`, откат —
  пружина `AppMotion.defaultEffects`.
- `lib/features/schedule/schedule_screen.dart` — оборачивает `CustomScrollView` целиком, вместе с
  `_ScheduleAppBar` (`SliverAppBar`); `onRefresh` = `scheduleController.refresh`. Кнопки
  «Обновить» в app bar нет. «Повторить» есть только в `_RefreshErrorBanner`, когда обновление
  уже упало.

**Расхождения**

| # | Сейчас | Должно быть | Источник |
|---|---|---|---|
| 1 | Обновить можно только жестом | Кнопка обновления в app bar или меню, тот же `onRefresh`, индикатор виден и при запуске кнопкой (`isRefreshing` снаружи) | Accessibility → Interaction & style; все `PullToRefreshSamples.kt` |
| 2 | Порог 96dp | 80dp | `PositionalThreshold` |
| 3 | Палец и протяжка 1:1 | Множитель 0,5 | `DragMultiplier` |
| 4 | После порога `fraction` зажат в 1, индикатор стоит; протяжка ограничена 1,5× | Упругое продолжение до 2× порога (`t − t²/4`) и поворот `-(p − 1) × 180°` | `calculateVerticalOffset`; `PullToRefreshDefaults.LoadingIndicator` |
| 5 | Пока тянут, крутится **неопределённый** морф | **Определённый** `ContainedLoadingIndicator(progress)`: Circle → SoftBurst, −180°×p; при обновлении `Crossfade` (`DefaultEffects`) на неопределённый | `PullToRefreshDefaults.LoadingIndicator` |
| 6 | Масштаб `Curves.easeOut` (0, 0, 0.58, 1) от доли протяжки | По умолчанию без масштаба. В примере масштабирования `LinearOutSlowInEasing` (0, 0, 0.2, 1) | `IndicatorBox`; `LoadingIndicatorPullToRefreshSample` |
| 7 | `top = lerp(−48, 24, fraction)`, без обрезки, поверх развёрнутого `SliverAppBar` | `fraction × 80 − 48`, при обновлении 32dp, с обрезкой по верхней кромке области контента. В примерах Compose бокс стоит под `TopAppBar` | `IndicatorBox`; `PullToRefreshWithLoadingIndicatorSample` |
| 8 | После отпускания за порогом `_dragOffset` сразу ставится на порог | Анимация к порогу `spring()` (1.0 / 1500) | `animateToThreshold` |
| 9 | Скрытие: `AppMotion.defaultEffects` (1.0 / 1600) двигает и позицию, и масштаб | Позиция — `spring()` (1.0 / 1500), без масштаба. `DefaultEffects` — только кросс-фейд содержимого | `PullToRefreshStateImpl.animateToHidden`; `Crossfade` |
| 10 | Обновление при `>= triggerDistance` в `ScrollEndNotification` | При `adjusted > threshold` в момент отпускания (`onPreFling`) | `onRelease` |
| 11 | Когда тянут обратно вверх, протяжка уменьшается по `scrollDelta`, но прокрутку не забирает. Вероятно, список прокручивается одновременно — проверить на устройстве | Сначала уменьшается протяжка, потом прокрутка (`onPreScroll` её поглощает) | `onPreScroll` |
| 12 | Семантика: подпись «Обновление расписания», без роли | Роль progress bar: с диапазоном при протяжке, спиннер во время обновления | Accessibility → Labeling; `progressBarRangeInfo` |

**Что сделать во Flutter**
1. В `_ScheduleAppBar` (`schedule_screen.dart`) добавить `IconButton` «Обновить» (иконка
   `Symbols.refresh`, `tooltip`), вызывающий тот же `refresh`. Добавить в `M3PullToRefresh`
   параметр `isRefreshing` (как в `PullToRefreshBox`), чтобы при запуске кнопкой индикатор
   выезжал к порогу и показывал неопределённый морф.
2. Модель состояния как в `PullToRefreshModifierNode`: `distancePulled`, `adjusted = × 0.5`,
   порог 80, `calculateVerticalOffset` с упругостью до 2×, `distanceFraction = offset / 80`
   без зажима сверху.
3. Анимации к порогу и к скрытию — `SpringDescription.withDampingRatio(mass: 1, stiffness: 1500, ratio: 1)`
   через `AnimationController.unbounded` + `animateWith(SpringSimulation…)`.
4. Индикатор: при `!isRefreshing` — `M3LoadingIndicator.determinate(progress: fraction.clamp(0, 1))`
   (см. `loading-indicator.md`) в `Transform.rotate(-(fraction − 1) × π)` при `fraction > 1`.
   При `isRefreshing` — неопределённый. Переход — `AnimatedSwitcher` с кросс-фейдом на
   `AppMotion.defaultEffects`. Масштаб убрать. Если он нужен, взять `Easing.legacyDecelerate`,
   как в примере, и записать это как выбор.
5. Позиция: `translateY = fraction × 80 − 48` от верхней кромки области контента, `ClipRect`
   сверху. При `SliverAppBar` кромка — низ app bar (аналог `RefreshIndicator.edgeOffset`).
6. Запуск по отпусканию: `ScrollEndNotification` / `dragDetails == null` и условие
   `adjusted > threshold`.
7. Проверить на Pixel 7, прокручивается ли список, когда палец идёт обратно. Если да, нужно
   поглощать прокрутку, пока протяжка > 0. На уведомлениях этого не сделать, нужен свой
   `ScrollPhysics` или обработка жеста. Либо записать отступление.
8. Семантика: во время протяжки `Semantics(role: SemanticsRole.progressBar, minValue, maxValue, value)`,
   во время обновления `role: SemanticsRole.loadingSpinner`, подпись «Обновление расписания».
9. Тесты: порог 80, множитель 0,5, функция упругости, запуск только при `> threshold`,
   индикатор определённый при протяжке и неопределённый при обновлении.

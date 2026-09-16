# Индикаторы прогресса (Progress indicators)

Статус в приложении: ✅ соответствует — порт `LinearWavyProgressIndicator` (отступления — README, п. 9)

> Разделы «В приложении → Расхождения» ниже описывают состояние до порта (16.09.2026); что сделано и что осталось — в «Реализация во Flutter» и в README.

Используется только волнистый линейный определённый индикатор (`M3WavyLinearProgress`) —
прогресс текущей пары. Размеры и цвета по токенам совпадают. Поведение перенесено с MDC, а в
Compose по умолчанию волна бежит, иначе выбраны пороги амплитуды, а сам прогресс
рекомендуется анимировать. Роли progress bar в семантике нет. Кольцевая диаграмма пропусков
progress indicator не является.

## Источники
- Guidelines / Specs / Accessibility: https://m3.material.io/components/progress-indicators/guidelines,
  https://m3.material.io/components/progress-indicators/specs,
  https://m3.material.io/components/progress-indicators/accessibility
  (выгрузка: `.m3-guidelines/components__progress-indicators.md`)
- Compose API: https://developer.android.com/reference/kotlin/androidx/compose/material3/package-summary —
  `LinearWavyProgressIndicator(progress, modifier, color, trackColor, stroke, trackStroke, gapSize, stopSize, amplitude, wavelength, waveSpeed)`,
  неопределённый `LinearWavyProgressIndicator(modifier, …, amplitude, wavelength, waveSpeed)`,
  `CircularWavyProgressIndicator(…)`, `LinearProgressIndicator(progress, modifier, color, trackColor, strokeCap, gapSize, drawStopIndicator)`,
  `CircularProgressIndicator(…)`, `WavyProgressIndicatorDefaults`, `ProgressIndicatorDefaults`
- Compose исходник: `WavyProgressIndicator.kt` (`WavyProgressIndicatorDefaults.indicatorAmplitude`,
  `IncreasingAmplitudeAnimationSpec`, `DecreasingAmplitudeAnimationSpec`),
  `internal/LinearWavyProgressModifiers.kt` (`DeterminateLinearWavyProgressNode`,
  `BaseLinearWavyProgressNode.updateOffsetAnimation`, `LinearProgressDrawingCache.updateFullPaths` /
  `updateDrawPaths`, `drawStopIndicator`), `internal/CircularWavyProgressModifiers.kt`,
  `ProgressIndicator.kt` (`ProgressIndicatorDefaults`, анимации неопределённых вариантов). Токены:
  `tokens/ProgressIndicatorTokens.kt`, `tokens/LinearProgressIndicatorTokens.kt`,
  `tokens/CircularProgressIndicatorTokens.kt`. Примеры: `samples/ProgressIndicatorSamples.kt`
  (`LinearWavyProgressIndicatorSample`, `LinearThickWavyProgressIndicatorSample`, …)
- MDC: https://github.com/material-components/material-components-android/blob/master/docs/components/ProgressIndicator.md
  (стиль `Widget.Material3Expressive.LinearProgressIndicator.Wavy`, атрибуты `waveSpeed`,
  `waveAmplitudeRampProgressMin/Max`)
- Flutter: `LinearProgressIndicator` / `CircularProgressIndicator` (`material/progress_indicator.dart`).
  С `year2023: false` дают оформление M3 2024: трек `secondaryContainer`, зазор 4dp, stop
  indicator радиусом 2dp, скругление 2dp, круговой 40dp (`_LinearProgressIndicatorDefaultsM3`,
  `_CircularProgressIndicatorDefaultsM3`). Волны, настраиваемой толщины Expressive и анимации
  амплитуды нет. Семантика есть: `role: SemanticsRole.progressBar` / `loadingSpinner`,
  `minValue`, `maxValue`, `value`. Волнистый вариант в приложении — свой порт
  `lib/widgets/m3_wavy_linear_progress.dart`.

## Когда использовать
- Для **долгих процессов (> 5 с)** и процессов с измеримым прогрессом: загрузка, отправка формы,
  сохранение. Для 200 мс – 5 с нужен loading indicator (Guidelines → Usage, таблица).
- Для группы элементов — один индикатор на всю группу, а не по индикатору на каждый
  (DO/DON'T).
- Один и тот же процесс везде показывается одним вариантом: линейным или круговым.
- Линейный лучше на краю контейнера (или посередине), круговой — по центру элемента
  (Guidelines → Placement).
- Определённый индикатор должен **точно** отражать прогресс. Неопределённый переходит в
  определённый, как только прогресс становится известен.
- Волна подходит, чтобы длинный процесс выглядел живее, и там, где уместен выразительный стиль.
  В очень маленьких элементах, например кнопках, берут плоский вариант (Guidelines → Active
  indicator; «Progress indicators in buttons»).
- Линейный индикатор не ставят в элементы уже 40dp. Отступ с концов — минимум 4dp
  (Guidelines → Large screens).

## Варианты и анатомия
- Варианты: линейный и круговой. Конфигурации: определённый / неопределённый; толщина 4dp или
  настраиваемая (Expressive); форма плоская / волнистая (Expressive) (Specs → Configurations).
- Анатомия: active indicator, track, stop indicator. **Stop indicator** — круг 4dp в конце трека,
  **только у линейного определённого** индикатора. Он обязателен, если контраст трека к
  контейнеру или фону за ним ниже 3:1 (Guidelines → Stop indicator).
- При маленьком прогрессе active indicator показывается точкой (Guidelines → Active indicator).

## Размеры, формы, цвета

| Токен | Значение | Compose |
|---|---|---|
| `linear.height` (плоский) | 4dp | `LinearProgressIndicatorTokens.Height` |
| `linear.with-wave.height` | 10dp | `WaveHeight` → `LinearContainerHeight` |
| `linear.active-indicator.thickness` / `track.thickness` | 4dp / 4dp | `ActiveThickness` / `TrackThickness`, `StrokeCap.Round` |
| `linear.track-active-indicator-space` | `space50` = 4dp | `TrackActiveSpace` → `LinearIndicatorTrackGapSize` |
| `linear.stop-indicator.size` / `trailing-space` | 4dp / 0dp | `StopSize` / `StopTrailingSpace` |
| `linear.active-indicator.wave.amplitude` | 3dp | `ActiveWaveAmplitude` |
| `linear.active-indicator.wave.wavelength` | 40dp; неопределённый 20dp | `ActiveWaveWavelength` / `IndeterminateActiveWaveWavelength` |
| `circular.size` / `with-wave.size` | 40dp / 48dp | `CircularProgressIndicatorTokens.Size` / `WaveSize` |
| `circular.*.thickness`, `track-active-indicator-space` | 4dp, 4dp | — |
| `circular.active-indicator.wave.amplitude` / `wavelength` | 1,6dp / 15dp | — |
| `active-indicator.color` / `stop-indicator.color` | `primary` | `ProgressIndicatorTokens.ActiveIndicatorColor` / `StopColor` |
| `track.color` | `secondary-container` | `TrackColor` |
| Формы active, track, stop | `corner.full` | `ActiveShape`, `TrackShape`, `StopShape` |

- Ширина по умолчанию в Compose — `LinearContainerWidth` = 240dp. В гайде линейный индикатор
  тянется на ширину элемента.
- Толстый вариант — только пример из `LinearThickWavyProgressIndicatorSample`: штрих 8dp,
  высота 14dp. Токены `*.thick.*` в выгрузке помечены как deprecated.
- Круговой индикатор может быть от 24 до 240dp. Волна масштабируется вместе с размером.

## Состояния и движение
**Определённый волнистый линейный, Compose (`LinearWavyProgressModifiers.kt`):**
- **Амплитуда от прогресса.** `indicatorAmplitude` возвращает 0 при `progress <= 0.1` или
  `progress >= 0.95`, иначе 1. Смена значения анимируется:
  - нарастание — `IncreasingAmplitudeAnimationSpec` = tween 500 мс (`DurationLong2`),
    `EasingStandardCubicBezier` (0.2, 0, 0, 1);
  - затухание — `DecreasingAmplitudeAnimationSpec` = tween 500 мс,
    `EasingEmphasizedAccelerateCubicBezier` (0.3, 0, 0.8, 0.15).
- **Бег волны.** По умолчанию `waveSpeed = wavelength`, то есть одна волна в секунду
  (40dp/с). Смещение крутится бесконечным линейным tween длительностью
  `wavelength / waveSpeed × 1000` мс, но не короче 50 мс (`MinAnimationDuration`). Пока амплитуда
  равна 0, смещение не применяется.
- **Геометрия волны.** Полная волна строится квадратичными кривыми Безье с высотой контрольной
  точки `height − stroke` (пик (10 − 4)/2 = 3dp). Нужный отрезок вырезается `PathMeasure`, а по Y
  путь сжимается на долю амплитуды.
- **Активная часть и зазор.** Голова `barHead = progress × width` зажата в
  `[cap, width − cap]`. Зазор = `min(barHead − cap, gapSize)`, у самого начала он плавно
  уменьшается. Трек начинается с `head + gap + 2×cap`.
- **Stop indicator.** Размер `min(trackStroke.width, stopSize)`, прижат к правому краю. Когда
  голова подходит к нему, он уменьшается.
- **RTL.** Рисунок поворачивается на 180°.
- **Смена прогресса.** Внутренней анимации нет. Документация `LinearWavyProgressIndicator`
  советует `WavyProgressIndicatorDefaults.ProgressAnimationSpec` = tween 500 мс,
  `EasingLinearCubicBezier`. Примеры в `ProgressIndicatorSamples.kt` используют
  `ProgressIndicatorDefaults.ProgressAnimationSpec` =
  `SpringSpec(DampingRatioNoBouncy, StiffnessVeryLow, visibilityThreshold = 1/1000)`.

**Неопределённый линейный, Compose (`ProgressIndicator.kt`):** цикл 1750 мс, две линии.
Задержки головы и хвоста 0 / 250 / 650 / 900 мс, длительности 1000 / 1000 / 850 / 850 мс,
`EasingEmphasizedAccelerateCubicBezier`. В приложении не используется.

**MDC (порт в приложении):** `waveSpeed` = 0 (волна стоит), нарастание амплитуды в диапазоне
`waveAmplitudeRampProgressMin/Max` = 0.1 / 0.9.

## Доступность
- Active и stop indicator — контраст **≥ 3:1** к фону. Внутри компонента (кнопки) — цвет
  подписи или иконки компонента, трек убирается (Accessibility → Interaction & style).
- Убирать stop indicator можно, только если у трека контраст ≥ 3:1 со всеми соседними
  контейнерами и поверхностями.
- Роль **progress bar**. Подпись называет процесс и объект, например «Loading news article»
  (Accessibility → Labeling elements).
- Compose: `semantics(mergeDescendants = true) { progressBarRangeInfo = ProgressBarRangeInfo(p, 0f..1f) }`
  и `IncreaseVerticalSemanticsBounds` (увеличенная зона фокуса по вертикали).

## В приложении
### Реализация во Flutter
`lib/widgets/m3_wavy_linear_progress.dart` перенесён на Compose `LinearWavyProgressIndicator`
(определённый) и `LinearProgressDrawingCache`. Строки таблицы «Расхождения» ниже с номерами
1–8 закрыты. Строки 9–11 касаются экранов и остаются открытыми.

**Совпадает с Compose**
- Токены: толщина 4/4dp, зазор 4dp, stop indicator 4dp, высота 10dp, длина волны 40dp.
  Цвета по умолчанию: `primary`, трек — `secondaryContainer`.
- Амплитуда `indicatorAmplitude` включена только при `0.1 < p < 0.95`. Переход длится 500 мс:
  нарастание — `Easing.standard`, затухание — `Easing.emphasizedAccelerate`. Новая анимация
  стартует, только если цель изменилась и предыдущая уже закончилась, как в
  `updateAmplitudeAnimation`.
- Бег волны: `waveSpeed` по умолчанию равен длине волны (одна волна в секунду), цикл не короче
  50 мс, смещение применяется только при амплитуде > 0. Тикер работает, лишь пока амплитуда
  больше нуля; вне экрана его глушит `TickerMode`.
- Геометрия:
  - голова `p × width` зажата в `[cap, width − cap]`;
  - зазор `min(head − cap, 4)`;
  - трек начинается с `head + gap + 2·cap`;
  - stop indicator уменьшается, когда голова его догоняет (`drawStopIndicator`);
  - волна строится квадратичными Безье от `x = 0`, контрольная точка на высоте
    `height − stroke`, отрезок вырезается `PathMetric.extractPath` со сдвигом фазы и сжимается
    по Y до амплитуды;
  - в RTL рисунок поворачивается на 180°.
  Числовая часть вынесена в `LinearWavyProgressGeometry` и покрыта тестами.
- Семантика: `SemanticsRole.progressBar`, `minValue` 0, `maxValue` 100, `value` в процентах.
- `showTrack: false` убирает трек. Это правило Accessibility для индикатора внутри компонента.
  Stop indicator остаётся, как в Compose с прозрачным `trackColor`.

**Уменьшение движения.** Как в Compose при `MotionDurationScale = 0`: значение и амплитуда
меняются сразу, волна не бежит.

**Отступления**
- `value` анимируется внутри виджета: tween 500 мс, linear
  (`WavyProgressIndicatorDefaults.ProgressAnimationSpec`). В Compose это делает вызывающий код.
  Семантика отдаёт целевое значение, а не промежуточное.
- Ширина. По умолчанию шкала занимает всю ширину родителя (Guidelines → Placement), 240dp
  (`LinearContainerWidth`) — только при неограниченной ширине. В Compose 240dp берутся, если
  родитель не задал ширину.
- Нет `IncreaseVerticalSemanticsBounds`: область фокуса TalkBack не расширяется до 48dp по
  вертикали. У Flutter `LinearProgressIndicator` её тоже нет.

**Где используется**
- `lib/widgets/m3_wavy_linear_progress.dart` — `M3WavyLinearProgress`, только определённый
  линейный волнистый.
- `lib/widgets/lesson_card.dart` → `_NowSection`: шкала на карточке текущей пары, которая
  залита `primary`. Цвета переопределены: `onPrimary`, трек `onPrimary` 32 %. Рядом
  `_PulsingDot` и текст «осталось N мин».
- `lib/features/schedule/lesson_details_page.dart` → `_NowPanel`: шкала на `surfaceContainer` с
  цветами по умолчанию.
- `lib/features/absences/widgets/absence_donut.dart` — кольцевая диаграмма. Это **не**
  progress indicator, см. ниже.
- `test/indicators_geometry_test.dart` проверяет токены (4/4/4/3/40, высота 10), пороги MDC
  0.1–0.9, сход зазора и затухание амплитуды за 500 мс.

**Расхождения**

| # | Сейчас | Должно быть | Источник |
|---|---|---|---|
| 1 | Волна включена при `0.1 <= value <= 0.9` | Включена при `0.1 < value < 0.95` | `WavyProgressIndicatorDefaults.indicatorAmplitude` (у MDC 0.1/0.9) |
| 2 | `waveSpeed = 0`: волна стоит (умолчание MDC) | По умолчанию волна бежит со скоростью `wavelength` в секунду (40dp/с) | `LinearWavyProgressIndicator(waveSpeed = wavelength)` |
| 3 | Прогресс прыгает раз в 30 с (`nowProvider`, `Timer.periodic(30 s)`) без анимации | Анимировать смену значения: tween 500 мс linear (или пружина из примеров) | `WavyProgressIndicatorDefaults.ProgressAnimationSpec` |
| 4 | `Semantics(label, value: 'N%')` без роли | Роль progress bar с диапазоном | Accessibility → Labeling; `progressBarRangeInfo`; Flutter `ProgressIndicator` |
| 5 | Голова `cap + value × (width − 2cap)`, зазор уменьшается по `value / 0.01` (MDC) | Голова `progress × width`, зажатая в `[cap, width − cap]`; зазор `min(head − cap, 4dp)` | `LinearProgressDrawingCache.updateDrawPaths` |
| 6 | Stop indicator всегда полного размера | Уменьшается, когда голова его догоняет | `drawStopIndicator` в `LinearWavyProgressModifiers.kt` |
| 7 | Синусоида ломаной с шагом 1dp, фаза от `x = cap` | Квадратичные Безье от `x = 0` (визуально почти то же, низкий приоритет) | `updateFullPaths` |
| 8 | Нет зеркалирования для RTL | Поворот 180° при RTL (приложение только на русском — низкий приоритет) | Guidelines → RTL; `rotate(180f)` |
| 9 | На карточке «сейчас» трек `onPrimary` 32 % — такого токена нет | Цвет индикатора как у контента на `primary` (`onPrimary`) обоснован правилом 3:1. Альфа трека 0,32 не из спеки — записать как осознанное отступление. Stop indicator при низком контрасте трека обязателен, и он есть | Accessibility → Interaction & style; Guidelines → Stop indicator |
| 10 | `_PulsingDot`: прозрачность 1 → 0,3, 800 мс, `Curves.easeInOut`, бесконечно | Такого элемента в спеке нет, длительность и кривая не из токенов. Решение взято из макета: убрать или оформить как отступление | `CLAUDE.md` («ничего не придумывать») |
| 11 | `AbsenceDonut` назван «инфографикой, а не компонентом прогресса» | Верно: progress indicators показывают **ход процесса**. Доля пропущенных часов — статистика, а не процесс. У индикатора один active indicator, а в диаграмме две дуги (всего / без справки). Заменять на `CircularProgressIndicator` не нужно. Но элемент не из M3 — записать как свой | Guidelines → Usage, Anatomy |

**Что сделать во Flutter**
1. `M3WavyLinearProgress.hasFullAmplitude`: `value > 0.1 && value < 0.95`. Обновить тест
   «полная амплитуда только в диапазоне».
2. Скорость волны: по умолчанию `waveSpeed = wavelength` (40), как в Compose. Тикер запускать,
   только пока амплитуда > 0 (в Compose смещение при нулевой амплитуде не применяется).
   Экраны вне дерева тикер не крутят благодаря `TickerMode`. Если волна должна стоять (MDC),
   явно записать это отступление в `docs/m3/`.
3. Анимировать `value`: внутри виджета `TweenAnimationBuilder<double>` или
   `AnimationController` на 500 мс с `Curves.linear` (`ProgressAnimationSpec`).
4. Семантика: `Semantics(label: semanticsLabel, role: SemanticsRole.progressBar, minValue: '0', maxValue: '100', value: '${(value * 100).round()}')`.
5. По желанию перенести геометрию из `LinearProgressDrawingCache`: зажатие головы, зазор
   `min(head − cap, gap)`, уменьшение stop indicator, квадратичную волну, RTL.
6. `lesson_card.dart`: оставить `onPrimary` для индикатора, про трек 32 % и `_PulsingDot`
   принять решение и записать в «Сознательные отступления» README.
7. `absence_donut.dart`: оставить как есть, в `docs/m3/` пометить как элемент не из M3
   (визуализация данных).

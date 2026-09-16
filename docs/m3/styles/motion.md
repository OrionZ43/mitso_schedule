# Движение (Motion)

> Разделы «В приложении → Расхождения» описывают состояние на 16.09.2026, до порта компонентов. Исправлено с тех пор: эталонная статичная схема и системные роли Android 14+, emphasized-веса по токенам, opsz и grade иконок, state layer, цвета tooltip, чипов и app bar при прокрутке, scrim 32%, выдуманные альфы, размеры шрифта и радиусы (карточка пары и метки удалены), пустое состояние из `MaterialShapes`, пружины кнопок, листов и снекбара, смена дня — lateral. Остаётся: breakpoints и navigation rail для окон шире 600dp (приложение для телефона), часть отступов вне токенов в старом коде.

## Источники

- m3.material.io
  - https://m3.material.io/styles/motion/overview/how-it-works и `/specs` → `.m3-guidelines/styles__motion__overview.md`
  - https://m3.material.io/styles/motion/easing-and-duration → `styles__motion__easing-and-duration.md`
  - https://m3.material.io/styles/motion/transitions → `styles__motion__transitions.md`
  - https://m3.material.io/m3-expressive-motion-theming → `m3-expressive-motion-theming.md`
  - https://m3.material.io/blog/building-with-m3-expressive → `building-with-m3-expressive.md`
- Compose Material3 (`androidx/compose/material3/`)
  - `MotionScheme.kt` — интерфейс `MotionScheme`, `MotionScheme.standard()` / `expressive()`, `fromToken()`
  - `tokens/ExpressiveMotionTokens.kt`, `tokens/StandardMotionTokens.kt` (v0_14_0), `tokens/MotionTokens.kt` (легаси easing/duration), `tokens/MotionSchemeKeyTokens.kt`
  - `MaterialTheme.kt` — `MaterialExpressiveTheme(motionScheme = MotionScheme.expressive())`
  - потребители токенов: `Button.kt`, `IconButton.kt`, `ToggleButton.kt`, `ButtonGroup.kt`, `NavigationBar.kt`, `NavigationItem.kt`, `BottomSheet.kt`, `ModalBottomSheet.kt`, `Chip.kt`, `Checkbox.kt`, `RadioButton.kt`, `Switch.kt`, `TabRow.kt`, `ListItem.kt`, `Menu.kt`, `Tooltip.kt`, `SnackbarHost.kt`, `SearchBar.kt`, `AppBar.kt`, `pulltorefresh/PullToRefresh.kt`, `Ripple.kt`, `LoadingIndicator.kt`, `WavyProgressIndicator.kt`
- MDC-Android: `docs/theming/Motion.md`; `lib/java/com/google/android/material/transition/` (`MaterialSharedAxis`, `MaterialFadeThrough`, `MaterialContainerTransform`, `MaterialFade`, `FadeThroughProvider`); `themes_base.xml` (`Base.Theme.Material3Expressive.*`)
- Flutter SDK: `material/motion.dart` (`Durations`, `Easing`), `animation/curves.dart`, `physics/spring_simulation.dart`, `physics/tolerance.dart`, `material/material.dart`, `material/bottom_sheet.dart`; пакет `animations` 2.2.0 (`open_container.dart`)

## Правила

### Система физики (M3 Expressive, май 2025)

- Движение компонентов описывается **пружинами** (stiffness, damping, initial velocity), а не парой «кривая + длительность». Система easing/duration «no longer maintained», но **ещё используется для переходов** (transitions).
- В таблице доступности на m3.material.io для Flutter стоит **Unavailable** — во Flutter систему нужно портировать вручную.
- Две предустановленные схемы: **expressive** (рекомендуется «for most situations, particularly hero moments and key interactions», с перелётом) и **standard** (утилитарные продукты, минимальный перелёт). Схема выбирается на уровне продукта; имя схемы не входит в токен: `md.sys.motion.spring.{fast|default|slow}.{spatial|effects}`.
- **Spatial** — позиция x/y, поворот, размер, скругление углов (есть перелёт). **Effects** — цвет и прозрачность (перелёта быть не должно).
- **Скорость**: default — большинство движений и то, что частично закрывает экран (bottom sheet, раскрытый navigation rail); fast — маленькие компоненты (switch, кнопки), цвет ручки switch; slow — полноэкранные анимации и обновление полноэкранного контента.
- Подпись к видео на overview: «All component motion is driven by two tokens: expressive fast spatial and expressive fast effects».
- Уровни кастомизации: 1 — стандартная схема; 2 — своя `MotionScheme`; 3 — подмена схемы для отдельного элемента.

### Значения пружин

| Токен | Expressive (damping / stiffness) | Standard (damping / stiffness) | Web-эквивалент Expressive (specs) |
|---|---|---|---|
| fast spatial | 0.6 / 800 | 0.9 / 1400 | cubic(0.42, 1.67, 0.21, 0.90), 350 мс |
| default spatial | 0.8 / 380 | 0.9 / 700 | cubic(0.38, 1.21, 0.22, 1.00), 500 мс |
| slow spatial | 0.8 / 200 | 0.9 / 300 | cubic(0.39, 1.29, 0.35, 0.98), 650 мс |
| fast effects | 1.0 / 3800 | 1.0 / 3800 | cubic(0.31, 0.94, 0.34, 1.00), 150 мс |
| default effects | 1.0 / 1600 | 1.0 / 1600 | cubic(0.34, 0.80, 0.34, 1.00), 200 мс |
| slow effects | 1.0 / 800 | 1.0 / 800 | cubic(0.34, 0.88, 0.34, 1.00), 300 мс |

Standard в web-таблице: spatial — cubic(0.27, 1.06, 0.18, 1.00) с 350 / 500 / 750 мс; effects — как у expressive. Кривые — «for animations without interruptions or gestures»; где возможно — пружины.

### Переходы (всё ещё easing + duration)

- «M3 transitions use the legacy easing and duration system». «Common transitions should not use overt style effects like bouncy springs».
- Пары по умолчанию: Emphasized 500 мс — начало и конец на экране; Emphasized decelerate 400 мс — вход; Emphasized accelerate 200 мс — выход; Standard 300 мс; Standard decelerate 250 мс; Standard accelerate 200 мс.
- Кривые: emphasized — path `M 0,0 C 0.05,0 0.133333,0.06 0.166666,0.4 C 0.208333,0.82 0.25,1 1,1` (Flutter: `Curves.easeInOutCubicEmphasized`); emphasized decelerate `Cubic(0.05, 0.7, 0.1, 1.0)`; emphasized accelerate `Cubic(0.3, 0.0, 0.8, 0.15)`; standard `Cubic(0.2, 0.0, 0, 1.0)`; standard decelerate `Cubic(0, 0, 0, 1)`; standard accelerate `Cubic(0.3, 0, 1, 1)`.
- Длительности: short1–4 = 50/100/150/200; medium1–4 = 250/300/350/400; long1–4 = 450/500/550/600; extra-long1–4 = 700/800/900/1000 мс.
- Шесть паттернов:
  1. **Container transform** — элемент раскрывается в подробности (карточка → страница). Для hero-моментов и неглубоких иерархий; не для глубоких утилитарных иерархий.
  2. **Forward and backward** — соседние уровни иерархии; на Android — сдвиг с затуханием; использовать платформенный переход по умолчанию.
  3. **Lateral** — равноправный контент одного уровня (вкладки, карусели, фото): элементы **едут вместе, без fade**; «CAUTION: Fading content as it slides makes the peer relationship and swipe gesture less obvious».
  4. **Top level** — пункты navigation bar/rail/drawer: уходящий экран быстро гаснет, затем проявляется новый; lateral здесь не использовать.
  5. **Enter and exit** — на Android компоненты раскрываются/сворачиваются по оси x или y; масштаб и z-ось избегать; направление — от ближнего края экрана.
  6. **Skeleton loaders** — пульсация сверху-слева вниз-вправо; загруженный контент «quickly fades in».
- Качество: учитывать системную настройку уменьшения движения (заменять сдвиги/масштаб лёгким fade, отключать parallax и shape morph); «clean fades» — сначала полностью скрыть старое, потом показать новое; bottom sheet не проявлять медленным fade.

## Как устроено в Compose

- `interface MotionScheme` — шесть `FiniteAnimationSpec`: `defaultSpatialSpec`, `fastSpatialSpec`, `slowSpatialSpec`, `defaultEffectsSpec`, `fastEffectsSpec`, `slowEffectsSpec`. Реализации — `spring(dampingRatio, stiffness)` из `ExpressiveMotionTokens` / `StandardMotionTokens`.
- `MaterialExpressiveTheme` по умолчанию подставляет `MotionScheme.expressive()`; свои компоненты берут `MaterialTheme.motionScheme.defaultSpatialSpec<T>()` и т. п. (пример в m3-expressive-motion-theming: scale → spatial, color → effects).
- Компоненты берут токен через `MotionSchemeKeyTokens.X.value()`:

| Компонент / свойство | Токен |
|---|---|
| `Button`, `IconButton`, `SplitButton`: морф формы при нажатии | DefaultEffects («intentional here to prevent any bounce») |
| `ToggleButton`: форма; ширина обводки / цвет обводки | FastSpatial; FastSpatial / DefaultEffects |
| `ButtonGroup`: расширение нажатой кнопки | FastSpatial |
| `NavigationBar` / `NavigationRail`: прозрачность индикатора / размер индикатора / цвета | DefaultEffects / FastSpatial / DefaultEffects |
| `NavigationItem`: смена позиции иконки | DefaultSpatial |
| `BottomSheet`: показ / скрытие / перетаскивание | DefaultSpatial / FastEffects / DefaultSpatial |
| `ModalBottomSheet`: прозрачность scrim | DefaultEffects |
| `NavigationDrawer`: открытие / закрытие | DefaultSpatial / FastEffects |
| FAB: размер / прозрачность; FAB menu: ширина / alpha / stagger | FastSpatial / FastEffects; FastSpatial / FastEffects / SlowEffects |
| `SelectableChip` (filter/input chips): иконка fadeIn / fadeOut / expand / shrink; перегрузка с `shapes` — морф формы, fade, expand/shrink | SlowEffects / FastEffects / FastSpatial / DefaultEffects; FastSpatial, DefaultEffects, FastSpatial |
| `Checkbox`: прорисовка галочки / цвет | DefaultSpatial / FastEffects (off), DefaultEffects |
| `RadioButton`: точка / цвет; `Switch`: ручка | FastSpatial / DefaultEffects; FastSpatial |
| `TabRow`: индикатор и прокрутка | DefaultSpatial |
| `ListItem`: цвет / форма / elevation | DefaultEffects / FastSpatial / FastSpatial |
| `Menu`: морф / масштаб / alpha / цвет | FastSpatial / FastSpatial / FastEffects / FastEffects |
| `Tooltip`, `Snackbar`: масштаб / alpha | FastSpatial / FastEffects |
| `TextField`: метка / цвета / толщина индикатора | FastSpatial / FastEffects / FastSpatial |
| `SearchBar` (развёрнутый): раскрытие / сворачивание | SlowSpatial / DefaultSpatial |
| `TopAppBar`: цвет контейнера при прокрутке | DefaultEffects |
| `PullToRefresh`: возврат индикатора, crossfade | DefaultEffects |
| Ripple, inset focus ring: появление / исчезновение | FastSpatial / FastEffects |
| `LoadingIndicator` | свой `spring(0.6, 200, visibilityThreshold = 0.1)`, морф раз в 650 мс, поворот 4666 мс linear |
| `WavyProgressIndicator`: амплитуда вкл / выкл | `tween(DurationLong2 = 500, EasingStandard)` / `tween(500, EasingEmphasizedAccelerate)` |

- MDC-Android: атрибуты `motionSpring*` по умолчанию — Standard (0.9/1400 и т. д., `Motion.md`), а `Base.Theme.Material3Expressive` подставляет `Motion.Material3.Spring.Expressive.*`. Переходы MDC: `MaterialSharedAxis` и `MaterialFadeThrough` — `motionDurationLong1` (450) + emphasized; `MaterialContainerTransform` — вход `motionDurationLong2` (500), возврат `motionDurationMedium4` (400), emphasized; `MaterialFade` — вход `motionDurationMedium4` (400) emphasized decelerate, выход `motionDurationShort3` (150) emphasized accelerate. Таблицы в `Motion.md` (300/250 мс) устарели относительно исходников.

## В приложении

### Как сейчас

- `lib/theme/app_motion.dart` — `AppMotion.{fast,default,slow}{Spatial,Effects}` = точные значения `ExpressiveMotionTokens`. `M3Spring.duration` — время успокоения `SpringSimulation` с `Tolerance.defaultTolerance` (1e-3): по расчёту ≈416 / 528 / 723 мс (spatial) и ≈222 / 330 / 453 мс (effects). `M3Spring.curve` — `SpringCurve` для неявных анимаций.
- `lib/theme/app_transitions.dart` — порты `MaterialSharedAxis` и `MaterialFadeThrough` (450 мс, `Curves.easeInOutCubicEmphasized`, порог 0.35, масштаб 0.92, сдвиг 30dp); `containerTransformDuration` = 500 мс.
- Использование: `lib/app.dart` (загрузка → главный: fade through), `features/home/home_shell.dart` (вкладки: fade through), `features/schedule/schedule_screen.dart` `_DaySwitcher` (смена дня: shared axis X), `features/group_picker/group_picker_sheet.dart` (шаги: shared axis X; загрузка → список: fade through), `widgets/lesson_card.dart` (`OpenContainer`), `widgets/day_selector.dart` и `widgets/connected_button_group.dart` (форма — FastSpatial, цвет — DefaultEffects), `features/notes/notes_screen.dart` (прозрачность — DefaultEffects), `theme/app_button_styles.dart` (`animationDuration` = DefaultEffects), `widgets/m3_pull_to_refresh.dart` (возврат — DefaultEffects).

### Расхождения

| # | Сейчас | Должно быть | Источник |
|---|---|---|---|
| 1 | `widgets/lesson_card.dart` `_PulsingDot`: `Duration(milliseconds: 800)`, `Curves.easeInOut`, прозрачность 1 → 0.3, бесконечный повтор — **придумано** | Паттерна «пульсирующей точки» в источниках не нашёл. Если оставлять — effects-токен/легаси-токены (`Durations.*`, `Easing.*`), отключение при reduced motion, запись в «Сознательные отступления». `Curves.easeInOut` не входит в набор M3 | `styles__motion__easing-and-duration.md` |
| 2 | `widgets/m3_pull_to_refresh.dart:150` масштаб индикатора `Curves.easeOut.transform(fraction)` — **придумано** | В Compose индикатор не масштабируется по easeOut: `ContainedLoadingIndicator(progress = { distanceFraction })`, после 1 — поворот `-(progress - 1) * 180`; crossfade — DefaultEffects | `pulltorefresh/PullToRefresh.kt` |
| 3 | Смена дня (`schedule_screen.dart` `_DaySwitcher`) — shared axis X с затуханием (паттерн forward/backward) | Дни — равноправный контент одного уровня → **lateral**: контент едет целиком, без fade, желательно за пальцем | `styles__motion__transitions.md` (Lateral, CAUTION про fade) |
| 4 | `lesson_card.dart` `OpenContainer` (package:animations): кривая `Curves.fastOutSlowIn` (= легаси 0.4, 0, 0.2, 1), одна длительность 500 мс в обе стороны, scrim `Colors.black54` | Emphasized; вход 500 мс, возврат 400 мс; scrim — роль `scrim` с непрозрачностью 32% | `MaterialContainerTransform.java` (`motionDurationLong2` / `motionDurationMedium4`), `styles__elevation.md` (Scrims), `tokens/ScrimTokens.kt` |
| 5 | `theme/app_button_styles.dart`: морф формы — `animationDuration` ≈330 мс, но форму анимирует `Material` с `Curves.fastOutSlowIn` (`material/material.dart`, `_MaterialInterior`) — это не пружина DefaultEffects | Пружина DefaultEffects (1.0 / 1600) или её web-эквивалент cubic(0.34, 0.80, 0.34, 1.00) за 200 мс | `Button.kt`, `styles__motion__overview.md` (specs) |
| 6 | Bottom sheet (`certificate_sheet.dart`, `group_picker_sheet.dart`) — дефолт Flutter: вход 250 мс, выход 200 мс, `Easing.legacyDecelerate`; scrim `Colors.black54` | Показ — DefaultSpatial, скрытие — FastEffects, scrim — DefaultEffects, цвет scrim 32% | `BottomSheet.kt`, `ModalBottomSheet.kt`, `material/bottom_sheet.dart` |
| 7 | Нет учёта уменьшения движения (в `lib/` нет `MediaQuery.disableAnimations`) | При reduced motion — лёгкие fade вместо сдвигов/масштаба, без shape morph | `styles__motion__transitions.md` (Follows accessibility settings) |
| 8 | Пружины в неявных анимациях (`TweenAnimationBuilder` + `SpringCurve` в `day_selector.dart`, `connected_button_group.dart`): при смене цели во время анимации скорость теряется, кривая стартует заново. Сама форма движения верна (кривая — симуляция пружины до допуска 1e-3, поэтому `M3Spring.duration` 416/528/723 и 222/330/453 мс длиннее web-приближений 350/500/650 и 150/200/300 мс — это не ошибка), но там, где `duration` используется без `SpringCurve` (кнопки, п. 5), длительность не совпадает с приближением спеки | Для spatial-свойств — `AnimationController.animateWith(SpringSimulation(spring, from, to, velocity))` с текущей скоростью | `m3-expressive-motion-theming.md` («Why use motion springs?»), `styles__motion__overview.md` |
| 9 | Загрузка → список в `group_picker_sheet.dart` — fade through 450 мс с масштабом 0.92 | Для загрузки гайдлайн описывает skeleton loader и «content quickly fades in»; точной длительности нет — не нашёл в источниках | `styles__motion__transitions.md` (Skeleton loaders) |

Что совпадает: значения пружин (`app_motion.dart`); выбор токенов в `day_selector.dart` / `connected_button_group.dart` (форма FastSpatial, цвет DefaultEffects — как `ToggleButton.kt`, `NavigationBar.kt`); fade through для вкладок (Top level); `M3LoadingIndicator` (650 мс, пружина 0.6/200 — как `LoadingIndicator.kt`); амплитуда `M3WavyLinearProgress` (500 мс, standard / emphasized accelerate — как `WavyProgressIndicator.kt`).

### Что сделать во Flutter

1. Добавить в `AppMotion` явное API для spatial-анимаций с сохранением скорости (контроллер + `SpringSimulation`), оставить `SpringCurve` только для effects.
2. Удалить `Curves.easeOut` из pull-to-refresh: вести `M3LoadingIndicator` по `distanceFraction`, как Compose.
3. Перевести смену дня на lateral (`PageView` или сдвиг без прозрачности).
4. Заменить `OpenContainer` своим container transform с emphasized, 500/400 мс и scrim 32% (или задокументировать отступление).
5. Для кнопок написать морф формы на пружине DefaultEffects (свой `AnimatedShape` вместо `ButtonStyle.animationDuration`).
6. Для bottom sheet передавать `sheetAnimationStyle` (`AnimationStyle` с длительностями/кривыми web-эквивалентов DefaultSpatial/FastEffects) и `barrierColor: scheme.scrim.withValues(alpha: 0.32)`.
7. Везде, где есть сдвиг/масштаб/морф, проверять `MediaQuery.disableAnimationsOf(context)`.
8. `_PulsingDot` — убрать или оформить как отступление с токенами.

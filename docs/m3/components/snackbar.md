# Снекбар (Snackbar)

Статус в приложении: ✅ соответствует — `M3SnackbarHost` (отступления — README, п. 17)

> Разделы «В приложении → Расхождения» ниже описывают состояние до порта (16.09.2026); что сделано и что осталось — в «Реализация во Flutter» и в README.

Цвета, форма, типографика, длительность и размещение над навигацией совпадают с токенами и
гайдом. Не совпадает анимация появления: Flutter раскрывает снекбар по высоте с затуханием, а
Compose делает масштаб и прозрачность пружинами. Внешние отступы тоже другие.

## Источники
- Guidelines / Specs / Accessibility: https://m3.material.io/components/snackbar/guidelines,
  https://m3.material.io/components/snackbar/specs, https://m3.material.io/components/snackbar/accessibility
  (выгрузка: `.m3-guidelines/components__snackbar.md`)
- Compose API: https://developer.android.com/reference/kotlin/androidx/compose/material3/package-summary —
  `Snackbar(snackbarData, modifier, actionOnNewLine, shape, containerColor, contentColor, actionColor, actionContentColor, dismissActionContentColor)`,
  `SnackbarHost(hostState, modifier, snackbar)`,
  `SnackbarHostState.showSnackbar(message, actionLabel, withDismissAction, duration)`, `SnackbarDefaults`
- Compose исходник: `Snackbar.kt` (раскладка одной или двух строк и кнопки на новой строке,
  константы `ContainerMaxWidth`, `HorizontalSpacing`, `HorizontalSpacingButtonSide`),
  `SnackbarHost.kt` (`FadeInFadeOutWithScale`, `animatedOpacity`, `animatedScale`,
  `SnackbarDuration.toMillis`), `Scaffold.kt` (`snackbarOffsetFromBottom`). Токены:
  `tokens/SnackbarTokens.kt`. Примеры: `samples/ScaffoldSamples.kt` (`ScaffoldWithSimpleSnackbar`,
  `ScaffoldWithIndefiniteSnackbar`, `ScaffoldWithMultilineSnackbar`)
- MDC: https://github.com/material-components/material-components-android/blob/master/docs/components/Snackbar.md
  (фон `colorSurfaceInverse`, текст `colorOnSurfaceInverse`, `textAppearanceBodyMedium`, действие
  `colorPrimaryInverse`, форма `shapeAppearanceCornerExtraSmall`, `layout_margin` 8dp,
  `elevation` 6dp, `animationMode` fade)
- Flutter: `SnackBar` + `ScaffoldMessenger.showSnackBar` (`material/snack_bar.dart`,
  `scaffold.dart`). Умолчания `_SnackbarDefaultsM3`: `inverseSurface`, действие
  `inversePrimary`, `bodyMedium` / `onInverseSurface`, `elevation` 6, радиус 4, `behavior: fixed`,
  `insetPadding` (15, 5, 15, 10). Показ 4000 мс, `persist` по умолчанию = `action != null`,
  переход 250 мс. У M3 floating появление — `FadeTransition` (`Interval(0.4, 0.6, easeInCirc)`)
  и раскрытие по высоте (`Curves.easeInOutQuart`). Кривую и сам тип перехода не настроить:
  `ScaffoldMessenger(snackBarAnimationStyle)` меняет только длительности. Показывается только
  в **корневом** `Scaffold` из вложенных (`_isRoot`).

## Когда использовать
- Короткое сообщение о процессе, который приложение выполнило или выполнит. Не прерывает
  работу. Сообщения высокой важности — в диалог (Guidelines → Usage, таблица с Dialog).
- **Одно сообщение за раз**. Новое, более актуальное, может сразу заменить старое. Снекбары не
  складывают стопкой и не ставят рядом.
- Максимум **одно** действие, текстовой кнопкой. «Dismiss» не нужен, снекбар исчезает сам.
  Снекбар не должен быть единственным путём к важной функции.
- Текст — одна строка, на телефоне до двух. Без иконок (CAUTION), без выделения и ссылок
  (DON'T).
- Размещение: внизу, поверх контента, **над FAB**, не поверх навигации. Во всю ширину — только
  если нет постоянной навигации. Вместе со снекбаром другие компоненты, например FAB, не
  анимируют (DON'T).
- Без действия исчезает через **4–10 с**. С действием остаётся, пока пользователь не нажмёт
  или не закроет (Guidelines → Behavior).

## Варианты и анатомия
- Анатомия: container, supporting text, action (необязательно), close icon (необязательно).
- Конфигурации: одна строка, одна строка с действием, две строки, две строки с действием, две
  строки с длинным действием (действие на отдельной строке) (Specs → Configurations).

## Размеры, формы, цвета

| Токен | Значение | Compose / Flutter |
|---|---|---|
| `container.color` | `inverse-surface` | `SnackbarTokens.ContainerColor`; Flutter по умолчанию |
| `container.elevation` | `level3` (6dp) | `ContainerElevation`; Flutter `elevation` 6 |
| `container.shape` | `corner.extra-small` (4dp) | `ContainerShape`; Flutter радиус 4 (floating) |
| `with-single-line.container.height` / `with-two-lines` | 48dp / 68dp | `SingleLineContainerHeight` / `TwoLinesContainerHeight` |
| `supporting-text` | `body-medium`, `inverse-on-surface` | `SupportingTextFont/Color` |
| `action.label-text` | `label-large`, `inverse-primary` (во всех состояниях) | `ActionLabelTextFont/Color` |
| `icon` | 24dp, `inverse-on-surface` | `IconSize`, `IconColor` |

- В тексте Guidelines → Responsive layout: «от 48dp до 64dp» для компактных экранов, а токен двух
  строк — 68dp. Compose следует токену 68dp.
- Compose: максимальная ширина 600dp (`ContainerMaxWidth`), отступ текста 16dp, у кнопки 8dp.
  Стандартный `Snackbar(snackbarData)` в `SnackbarHost` окружён полем **12dp**. У MDC поле 8dp.
- На широких экранах снекбар растёт по горизонтали (строка 40–60 символов), выравнивание по
  левому краю или по центру.

## Состояния и движение
- **Compose (`SnackbarHost.kt`, `FadeInFadeOutWithScale`):**
  - прозрачность 0 ↔ 1 — `MotionSchemeKeyTokens.FastEffects` (Expressive: пружина, ratio 1.0,
    stiffness 3800);
  - масштаб 0.8 ↔ 1 — `FastSpatial` (ratio 0.6, stiffness 800);
  - сдвига и раскрытия по высоте нет, старый снекбар затухает, новый проявляется.
- **Длительность (`SnackbarDuration.toMillis`):** Short 4000 мс, Long 10000 мс, Indefinite.
  Значение пропускается через `AccessibilityManager.calculateRecommendedTimeoutMillis`: учитывает
  настройку «время на действие» и `containsControls` при наличии действия. У `showSnackbar` по
  умолчанию Short без действия и Indefinite с действием.
- **Место (`Scaffold.kt`):** снекбар стоит над FAB, если он есть, иначе над bottom bar.
- **Flutter:** см. «Источники». Масштаба и пружин нет. При `MediaQuery.accessibleNavigation`
  анимация отключается.
- **MDC:** `animationMode` = fade.

## Доступность
- Появление объявляется, фокус не переносится и не удерживается. На Android — live region
  **polite** (Accessibility → Focus, Labeling).
- Снекбар с действием не исчезает сам. Без действия висит достаточно долго (4–10 с).
- Compose: `liveRegion = LiveRegionMode.Polite`, действие `dismiss`, `paneTitle`.
- Flutter: `Semantics(container: true, liveRegion: true, onDismiss: …)` и `Dismissible` свайпом.

## В приложении
**Где используется**
- `lib/app.dart` → `snackBarTheme`: `behavior: floating`, фон `inverseSurface`, текст
  `bodyMedium` / `onInverseSurface`, форма `AppShapes.extraSmall` (4dp). Цвет действия и
  `elevation` берутся из умолчаний M3 (`inversePrimary`, 6) — совпадают с токенами.
- `lib/features/absences/widgets/certificate_sheet.dart` → после отправки справки
  `SnackBar(content: Text('Справка отправлена куратору'))`: без действия, 4 с, показывается в
  корневом `Scaffold` из `home_shell.dart` над `NavigationBar`.

**Расхождения**

| # | Сейчас | Должно быть | Источник |
|---|---|---|---|
| 1 | Появление Flutter M3 floating: затухание `Interval(0.4, 0.6, easeInCirc)` + раскрытие по высоте `easeInOutQuart`, 250 мс | Прозрачность `FastEffects`, масштаб 0.8 → 1 `FastSpatial`, без раскрытия | `FadeInFadeOutWithScale` |
| 2 | Поле вокруг floating-снекбара (15, 5, 15, 10) — `insetPadding` Flutter | 12dp со всех сторон (Compose `SnackbarHost`). У MDC 8dp, в выгрузке m3 числа нет (только картинка) | `Snackbar(snackbarData)`: `modifier.padding(12.dp)` |
| 3 | Длительность фиксирована, 4000 мс | Базовые 4000 мс, скорректированные по системной настройке «время на действие» | `SnackbarDuration.toMillis` → `calculateRecommendedTimeoutMillis` |
| 4 | Снекбар показывается только в корневом `Scaffold` (`home_shell.dart`). FAB «Заметок» живёт во вложенном `Scaffold` (`notes_screen.dart`), корневой о нём не знает | Снекбар над FAB, не поверх него. Сейчас риск низкий: снекбар вызывается только с экрана пропусков, но если перейти на «Заметки» в течение 4 с, он может перекрыть FAB | Guidelines → Placement («Snackbars and FABs»); `Scaffold.kt` |
| 5 | Высоты 48 / 68dp в приложении не проверялись | Сверить скриншотом (`test/screenshot_generator.dart`) | `SnackbarTokens` |

**Что сделать во Flutter**
1. `snackBarTheme`: `insetPadding: EdgeInsets.all(12)`, как у Compose `SnackbarHost`.
2. Анимация. `SnackBar` не даёт заменить переход, поэтому варианта два:
   - принять переход Flutter и записать отступление;
   - сделать свой хост: `OverlayEntry` или слой в `HomeShell` над `NavigationBar` с
     `FadeTransition` на `AppMotion.fastEffects` и `ScaleTransition` 0.8 → 1 на
     `AppMotion.fastSpatial`. Тогда очередь, таймер (`persist` при действии), `liveRegion`,
     свайп-закрытие и место над FAB придётся повторить самостоятельно.
3. FAB во вложенном `Scaffold`: показывать снекбары, которые могут совпасть с экраном заметок,
   через `ScaffoldMessenger`, обёрнутый вокруг вложенного `Scaffold`. Или поднять FAB в корневой
   `Scaffold`.
4. Длительность «по системной настройке» во Flutter напрямую недоступна (нужен платформенный
   вызов `AccessibilityManager.getRecommendedTimeoutMillis`). Либо реализовать, либо записать
   отступление.

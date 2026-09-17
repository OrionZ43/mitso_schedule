# Панели инструментов (Toolbars)

Статус в приложении: — не используется

## Источники
- Guidelines / Specs / Accessibility: https://m3.material.io/components/toolbars/guidelines,
  https://m3.material.io/components/toolbars/specs, https://m3.material.io/components/toolbars/accessibility
  (выгрузка: `.m3-guidelines/components__toolbars.md`; таблица токенов в выгрузке пустая, числа — из Compose)
- Compose API: https://developer.android.com/reference/kotlin/androidx/compose/material3/package-summary —
  `HorizontalFloatingToolbar(expanded, modifier, colors, contentPadding, scrollBehavior, shape, leadingContent, trailingContent, expandedShadowElevation, collapsedShadowElevation, content)`
  и перегрузка с `floatingActionButton`, `VerticalFloatingToolbar`, `FloatingToolbarDefaults.standardFloatingToolbarColors()` /
  `vibrantFloatingToolbarColors()`, `FloatingToolbarDefaults.exitAlwaysScrollBehavior(exitDirection)`,
  `FlexibleBottomAppBar` (docked toolbar)
- Compose исходник: `FloatingToolbar.kt` (`FloatingToolbarDefaults.animationSpec()` = `MotionSchemeKeyTokens.FastSpatial`,
  `exitAlwaysScrollBehavior(snapAnimationSpec = DefaultEffects)`), `AppBar.kt` (`FlexibleBottomAppBar`,
  `BottomAppBarDefaults.FlexibleContentPadding`, `snapAnimationSpec` = `FastSpatial`), токены
  `tokens/FloatingToolbarTokens.kt`, `tokens/DockedToolbarTokens.kt`, пример `samples/FloatingToolbarSamples.kt`
- MDC: https://github.com/material-components/material-components-android/blob/master/docs/components/DockedToolbar.md,
  https://github.com/material-components/material-components-android/blob/master/docs/components/FloatingToolbar.md
  (скрытие — `HideViewOnScrollBehavior`)
- Flutter: готового виджета нет. `BottomAppBar` — это baseline bottom app bar, он не рекомендуется.
  Toolbar собирается вручную.

## Когда использовать
- Действия текущей страницы, часто больше двух. **Docked** — глобальные действия во всю ширину
  внизу, заменяет bottom app bar. **Floating** — контекстные действия над контентом, можно в паре
  с FAB (Guidelines → Usage).
- **Не показывать одновременно с navigation bar:** nav bar — на главных страницах, toolbar — на
  вложенных. Docked toolbar нельзя ставить, если внизу уже есть другой элемент, например nav bar
  (Toolbars & navigation bars, Position).
- Цвета: standard (`surfaceContainer`) — акцент на контенте; vibrant (`primaryContainer`) — акцент
  на действиях или временный режим, например редактирование.
- Выделяется только одно действие: filled-кнопка **или** FAB, не оба сразу.

## Варианты и анатомия
- Docked и floating (horizontal или vertical). Контейнер со слотами: icon buttons, кнопки, поля ввода.
- Квадратные icon buttons внутри floating toolbar не использовать: они спорят с полностью
  скруглённым контейнером.

## Размеры, формы, цвета
| Элемент | Docked | Floating | Источник |
|---|---|---|---|
| Высота | 64dp | 64dp | `DockedToolbarTokens.ContainerHeight`, `FloatingToolbarTokens.ContainerHeight` |
| Форма | `corner.none` | `corner.full` | `ContainerShape` |
| Цвет (standard / vibrant) | `surfaceContainer` | `surfaceContainer` / `primaryContainer` | `DockedToolbarTokens.ContainerColor`, `FloatingToolbarTokens.StandardContainerColor` / `VibrantContainerColor` |
| Внутренние отступы | 16dp по краям, между элементами 4–32dp | 8dp по краям, 4dp между элементами | `ContainerLeadingSpace` / `MinSpacing` / `MaxSpacing`; `FloatingToolbarTokens.ContainerLeadingSpace` / `ContainerBetweenSpace` |
| Отступ от края окна | — | не меньше 16dp (vertical — не меньше 24dp) | `FloatingToolbarTokens.ContainerExternalPadding`; Guidelines → Position |
| Тень | нет | в покое 0; с FAB — level1 | `FloatingToolbarDefaults.ContainerExpandedElevation` / `ContainerExpandedElevationWithFab` |

## Состояния и движение
- Раскрытие и сворачивание floating toolbar — `FloatingToolbarDefaults.animationSpec()` = `FastSpatial`.
- Скрытие при прокрутке — `exitAlwaysScrollBehavior`, доводка `DefaultEffects`. У docked
  (`FlexibleBottomAppBar`) доводка `FastSpatial`.
- Floating toolbar можно свернуть в одно действие при прокрутке, но нельзя одновременно
  сворачивать и уводить за экран.

## Доступность
- Все элементы от 48×48dp. Tab или стрелки переходят между элементами, Space или Enter активируют.
  На мобильных контейнер может быть без роли.

## В приложении
- Не используется. На вкладках стоит navigation bar, поэтому docked toolbar там запрещён.
  Действия «Добавить задачу» и «Зарегистрировать пропуск» сделаны FAB. Floating toolbar имеет смысл
  только на вложенной странице без nav bar (например, `LessonDetailsPage`) и только если там
  появятся несколько действий.

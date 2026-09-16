# Кнопки-иконки (Icon buttons)

Статус в приложении: ⚠️ частично

## Источники
- Guidelines / Specs / Accessibility: https://m3.material.io/components/icon-buttons/guidelines (и /specs, /accessibility); дамп `.m3-guidelines/components__icon-buttons.md`
- Compose API: https://developer.android.com/reference/kotlin/androidx/compose/material3/package-summary — `IconButton(onClick, shapes, …)`, `FilledIconButton`, `FilledTonalIconButton`, `OutlinedIconButton`, `IconToggleButton`, `FilledTonalIconToggleButton` и др., `IconButtonDefaults.shapes()`, `IconButtonDefaults.toggleableShapes()`, `IconButtonDefaults.smallContainerSize(widthOption)`, `IconButtonDefaults.IconButtonWidthOption.Narrow/Uniform/Wide`, `IconButtonDefaults.filledTonalIconButtonColors()`
- Compose исходник: `IconButton.kt` (`IconButtonImpl`, `shapeForInteraction`, `shapeByInteraction`), `IconButtonDefaults.kt` (формы, размеры, цвета); токены `XSmallIconButtonTokens.kt`, `SmallIconButtonTokens.kt`, `MediumIconButtonTokens.kt`, `LargeIconButtonTokens.kt`, `XLargeIconButtonTokens.kt`, `IconButtonTokens.kt` (standard), `FilledIconButtonTokens.kt`, `FilledTonalIconButtonTokens.kt`, `OutlinedIconButtonTokens.kt`; пример `IconButtonSamples.kt`
- MDC: https://github.com/material-components/material-components-android/blob/master/docs/components/IconButton.md (`SizeOverlay.Material3Expressive.Button.IconButton.{Xsmall…Xlarge}`, ширины narrow/uniform/wide)
- Flutter: `IconButton`, `IconButton.filled`, `.filledTonal`, `.outlined` (M3 реализован через `ButtonStyleButton` в `icon_button.dart`). Умеет: 40×40dp, отступ 8dp, иконку 24dp, зону нажатия 48dp, `isSelected` + `selectedIcon`, `IconButtonThemeData.style` для всех вариантов. Не умеет: пружинный морф (форма анимируется `Curves.fastOutSlowIn`), размеры XS/M/L/XL и ширины narrow/wide из коробки, Expressive-цвета toggle.

## Когда использовать
- Частые понятные действия с однозначной системной иконкой. **Default** открывает что-то (меню, поиск). **Toggle** — бинарное состояние (избранное, закладка).
- Цвета по убыванию акцента: filled → tonal → outlined → standard. Tonal — вторичные действия рядом с главным. Standard — низкий акцент или цветной фон.
- Кнопки одинаковой важности — одного размера. Несколько icon buttons можно положить в standard button group.
- Default-кнопка использует **filled**-иконку. Toggle — outlined в невыбранном состоянии, filled в выбранном (если filled нет — semibold).

## Варианты и анатомия
- Варианты: default и toggle.
- Конфигурации: размер (XS, S — по умолчанию, M, L, XL), форма (round — по умолчанию, square), ширина (narrow, default, wide), цвет (filled — по умолчанию, tonal, outlined, standard).
- Анатомия: иконка, контейнер.

## Размеры, формы, цвета
| Размер | Высота | Иконка | Отступы narrow / default / wide | Square | Pressed | Selected (у round) |
|---|---|---|---|---|---|---|
| XS | 32dp | 20dp | 4 / 6 / 10dp | 12dp | 8dp | 12dp |
| S | 40dp | 24dp | 4 / 8 / 14dp | 12dp | 8dp | 12dp |
| M | 56dp | 24dp | 12 / 16 / 24dp | 16dp | 12dp | 16dp |
| L | 96dp | 32dp | 16 / 32 / 48dp | 28dp | 16dp | 28dp |
| XL | 136dp | 40dp | 32 / 48 / 72dp | 28dp | 16dp | 28dp |

Значения — из `*IconButtonTokens.kt` (Compose) и `md.comp.icon-button.small.*` (m3); радиусы совпадают с таблицей «Button corner radius» на Specs. Ширина = иконка + отступы: у S default это 24 + 2×8 = 40dp (`IconButtonDefaults.smallContainerSize`). Обводка outlined: 1dp (XS–M), 2dp (L), 3dp (XL).

| Стиль | Default | Toggle unselected | Toggle selected |
|---|---|---|---|
| Filled | primary / onPrimary | surfaceContainer / onSurfaceVariant | primary / onPrimary |
| Tonal | secondaryContainer / onSecondaryContainer | secondaryContainer / onSecondaryContainer | secondary / onSecondary |
| Outlined | обводка outlineVariant, иконка onSurfaceVariant | то же | inverseSurface / inverseOnSurface |
| Standard | иконка onSurfaceVariant | onSurfaceVariant | primary |

Disabled: иконка onSurface 38%, контейнер onSurface 10%. State layer: hover 8%, focus 10%, pressed 10%.

## Состояния и движение
- **Нажатие**: форма морфится к pressed-радиусу; round и square приходят к одному радиусу. Токен m3: `md.comp.icon-button.pressed.container.corner-size.motion.spring` = `fast.spatial`. Compose (`IconButton.kt`, `shapeForInteraction`): `MotionSchemeKeyTokens.DefaultEffects` с комментарием «intentional here to prevent any bounce», морф через `rememberAnimatedShape`. Морф есть только в перегрузках с `shapes: IconButtonShapes`. `IconButtonDefaults.shapes()` = round → `SmallIconButtonTokens.PressedContainerShape` (8dp). Старые перегрузки со `shape` статичны.
- **Toggle**: приоритет формы pressed > checked > shape, та же пружина `DefaultEffects`. По умолчанию при выборе round → square, square → round.
- В standard button group соседние icon buttons реагируют на нажатие (см. `button-groups.md`).

## Доступность
- Зона нажатия ≥ 48×48dp у XS и S, в том числе внутри других компонентов. Compose — `Modifier.minimumInteractiveComponentSize()`.
- Контраст иконки с фоном ≥ 3:1.
- Метка доступности описывает действие («Добавить в избранное»), а не название иконки. Tooltip с той же меткой (на вебе — при наведении).
- Не применять плотность по умолчанию.
- Compose: `Role.Button`, у toggle — `Role.Checkbox`.

## В приложении
- Где используется:
  - Тема: `lib/app.dart` → `iconButtonTheme: IconButtonThemeData(style: AppButtonStyles.iconSmall())` (`lib/theme/app_button_styles.dart`): 40×40dp, иконка 24dp, StadiumBorder → 8dp при нажатии, длительность `AppMotion.defaultEffects`.
  - `lib/features/schedule/schedule_screen.dart`: `IconButton.filledTonal(icon: Icon(Symbols.groups), tooltip: …)` в `SliverAppBar.actions`.
  - `lib/features/schedule/lesson_details_page.dart`, `lib/features/group_picker/group_picker_sheet.dart`: standard `IconButton` «Назад».
- Совпадает: размер S, иконка 24dp, round → pressed 8dp, цвета tonal (дефолт Flutter), standard — onSurfaceVariant, tooltip-метки, зона нажатия 48dp (`MaterialTapTargetSize.padded`).
- Расхождения:
  1. Кривая морфа: сейчас `Curves.fastOutSlowIn` на длительности пружины → должна быть пружина `DefaultEffects` (Compose) / `FastSpatial` (токен m3) → `IconButton.kt` `shapeForInteraction`. Та же причина, что у кнопок: `ButtonStyle` не принимает кривую.
  2. Иконка default-кнопки: сейчас `Symbols.groups` без `fill` (outlined) → для default icon button filled-иконка (`fill: 1`) → Guidelines, «Icon»: «Default icon buttons should use filled icons».
- Что сделать во Flutter:
  1. В `schedule_screen.dart` передать `Icon(Symbols.groups, fill: 1)`.
  2. Морф пружиной: тот же подход, что в `buttons.md` — обёртка со `WidgetStatesController` и радиусом из `AnimationController.animateWith(AppMotion.defaultEffects.simulate(...))`, `animationDuration: Duration.zero`.
  3. Если понадобятся toggle icon buttons: `IconButton(isSelected:, icon: outlined, selectedIcon: filled)` + цвета из таблицы + selected-форма 12dp (S). Дефолты Flutter не подходят: у `filledTonal` выбранная — secondaryContainer / onSecondaryContainer, невыбранная — surfaceContainerHighest / onSurfaceVariant (`_FilledTonalIconButtonDefaultsM3` в `icon_button.dart`), а по токенам selected — secondary / onSecondary, unselected — secondaryContainer / onSecondaryContainer.

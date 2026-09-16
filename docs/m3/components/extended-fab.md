# Расширенная плавающая кнопка (Extended FAB)

Статус в приложении: ⚠️ частично

## Источники
- Guidelines / Specs / Accessibility: https://m3.material.io/components/extended-fab/guidelines (и /specs, /accessibility); дамп `.m3-guidelines/components__extended-fab.md`
- Compose API: https://developer.android.com/reference/kotlin/androidx/compose/material3/package-summary — `SmallExtendedFloatingActionButton(text, icon, onClick, modifier, expanded, …)`, `MediumExtendedFloatingActionButton`, `LargeExtendedFloatingActionButton`, baseline `ExtendedFloatingActionButton` (не рекомендуется), `FloatingActionButtonDefaults.smallExtendedFabShape/mediumExtendedFabShape/largeExtendedFabShape`
- Compose исходник: `FloatingActionButton.kt`. Приватный `ExtendedFloatingActionButton(text, icon, onClick, textStyle, minWidth, minHeight, startPadding, endPadding, iconPadding, …)` — анимация `expanded`; `extendedFabExpandAnimation` / `extendedFabCollapseAnimation` — baseline; константы `SmallExtendedFab*`, `MediumExtendedFab*`, `LargeExtendedFab*`. Токены `ExtendedFabSmallTokens.kt`, `ExtendedFabMediumTokens.kt`, `ExtendedFabLargeTokens.kt`, `ExtendedFabPrimaryTokens.kt`, `FabPrimaryContainerTokens.kt`. Пример `FloatingActionButtonSamples.kt`.
- MDC: https://github.com/material-components/material-components-android/blob/master/docs/components/ExtendedFloatingActionButton.md (`?attr/extendedFloatingActionButtonSmallStyle` и др.)
- Flutter: `FloatingActionButton.extended(icon, label, isExtended)` в `floating_action_button.dart`. Дефолты `_FABDefaultsM3` — baseline: высота 56, форма 16dp, `labelLarge`, отступы 16 (с иконкой) / 20dp, иконка↔текст 8dp. Размеры задаются через `FloatingActionButtonThemeData.extended*`. Нет medium/large extended FAB и анимации `expanded`, как в Compose (`isExtended` переключается без анимации ширины).

## Когда использовать
- Главное действие на длинных прокручиваемых экранах, где к нему нужен постоянный доступ, и когда подпись помогает понять действие.
- Один extended FAB на экран; не как один из набора вариантов (там filled button).
- Размеры: в компактных окнах с одним заметным действием уместен large; на больших окнах — medium или large. Baseline extended FAB (56dp, labelLarge) **не рекомендуется** — заменять на small (56dp, titleMedium, меньшие отступы).
- Место: внизу по центру или у trailing-края, над остальным UI. Не в верхней половине, не на тулбаре, не внутри карточек/диалогов. Не рядом с floating toolbar.
- Иконка необязательна, но кнопка без подписи не бывает. Подпись 1–2 слова, без переноса и обрезки.

## Варианты и анатомия
- Варианты: small, medium, large (+ baseline, не рекомендуется).
- Цвета — как у FAB: primary container (по умолчанию), secondary/tertiary container, primary, secondary, tertiary. Surface не рекомендуется.
- Анатомия: контейнер (обнимает содержимое), подпись, иконка (необязательна).

## Размеры, формы, цвета
| Вариант | Высота | Форма | Иконка | Отступы | Иконка↔текст | Шрифт |
|---|---|---|---|---|---|---|
| Small | 56dp | `corner.large` 16dp | 24dp | 16dp | 8dp (`space100`) | titleMedium |
| Medium | 80dp | `corner.large-increased` 20dp | 28dp | 26dp | 12dp (`space150`) | titleLarge |
| Large | 96dp | `corner.extra-large` 28dp | 36dp (m3) / 32dp (`ExtendedFabLargeTokens`) | 28dp | 16dp (`space200`) | headlineSmall |
| Baseline (не рекоменд.) | 56dp | 16dp | 24dp | 16dp | 12dp | labelLarge |

- Иконка↔текст у medium/large: в m3 `space150`/`space200`; Compose использует 12dp/16dp с TODO «ExtendedFab…Tokens.IconLabelSpace is incorrect» (в токенах 16/20dp).
- Минимальная ширина в Compose = высота варианта (`SmallExtendedFabMinimumWidth = ExtendedFabSmallTokens.ContainerHeight`); у baseline — 80dp.
- Отступ от краёв экрана 16dp.
- Primary-стиль: `md.comp.extended-fab.primary.container.color` = primary, `icon.color`/`label-text.color` = onPrimary, state layer (hovered/focused/pressed) = **onPrimary**.
- Тень: level3, hover level4 (как у FAB).

## Состояния и движение
- Нажатие: форма не морфится, state layer 10%, тень `animateElevation`.
- **Появление**: поверхность разворачивается паттерном enter/exit.
- **Сворачивание в FAB при прокрутке** (необязательно): при прокрутке вниз сворачивается, вверх — разворачивается. При раскрытии меняется форма, иконка уезжает влево, подпись проявляется. В Compose (`expanded`) у Small/Medium/Large: ширина — `updateTransition` + `animateFloat` на `MotionSchemeKeyTokens.FastSpatial` (lerp от `minWidth` до intrinsic-ширины), прозрачность подписи — `FastEffects`. У baseline `ExtendedFloatingActionButton` — `AnimatedVisibility`: раскрытие `fadeIn(DefaultEffects) + expandHorizontally(FastSpatial)`, сворачивание `fadeOut(FastEffects) + shrinkHorizontally(DefaultSpatial)`.
- **Раскрытие в поверхность** — container transform.
- Смена вкладок — как у FAB: исчезает и появляется отдельно от контента (см. `floating-action-button.md`).

## Доступность
- Иконка и подпись — один фокусируемый элемент; tooltip не нужен (подпись видна).
- Метка доступности начинается с того же слова, что видимая подпись.
- Высокий приоритет в порядке фокуса; не перекрывать другие интерактивные элементы.
- Клавиатура: Tab — фокус, Space/Enter — действие.

## В приложении
- Где используется:
  - `lib/features/absences/absences_screen.dart`: `FloatingActionButton.extended(backgroundColor: colors.primary, foregroundColor: colors.onPrimary, icon: Icon(Symbols.document_scanner, fill: 1), label: Text('Оправдать пропуск'))`.
  - Тема `lib/app.dart` → `floatingActionButtonTheme`: `extendedTextStyle: titleMedium`, `extendedSizeConstraints: tightFor(height: 56)`, `extendedPadding: horizontal 16`, `extendedIconLabelSpacing: 8`, `shape: 16dp`, `elevation: 6`.
- Совпадает: small extended FAB (56dp, 16dp, titleMedium, отступы 16dp, промежуток 8dp, иконка 24dp), цветовой стиль primary / onPrimary (разрешён спекой), filled-иконка, один на экран, внизу у trailing-края, длинный список справок — подходящий сценарий.
- Расхождения:
  1. State layer: сейчас onPrimaryContainer (`_FABDefaultsM3.splashColor/hoverColor/focusColor` не зависят от переданного `foregroundColor`) → onPrimary → `md.comp.extended-fab.primary.*.state-layer.color`, Specs «States»: «make sure the state layer color is the same as the icon color».
  2. Смена вкладок: FAB анимируется вместе с контентом вкладки (fade through в `home_shell.dart`) → отдельное скрытие/показ → Guidelines FAB «Moving across tabs» (подробности и шаги в `floating-action-button.md`).
  3. Подпись «Оправдать пропуск» — 2 слова, в рамках правила «1–2 слова». Проверить, что при 200% шрифта не переносится/не обрезается.
- Что сделать во Flutter:
  1. В `absences_screen.dart` передать `splashColor: colors.onPrimary.withValues(alpha: 0.1)`, `focusColor: colors.onPrimary.withValues(alpha: 0.1)`, `hoverColor: colors.onPrimary.withValues(alpha: 0.08)`. Либо завести в теме стиль «primary FAB», чтобы цвета не задавались по месту.
  2. Порт показа/скрытия при смене вкладок — общий с FAB (`floating-action-button.md`, п. 2).
  3. Если понадобится сворачивание при прокрутке: анимировать ширину от 56dp до intrinsic на `AppMotion.fastSpatial`, прозрачность подписи на `AppMotion.fastEffects` (как приватный `ExtendedFloatingActionButton` в Compose). У Flutter `isExtended` без анимации ширины.

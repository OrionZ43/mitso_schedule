# Кнопки (Buttons)

Статус в приложении: ⚠️ частично

## Источники
- Guidelines / Specs / Accessibility: https://m3.material.io/components/buttons/guidelines (и /specs, /accessibility); дамп `.m3-guidelines/components__buttons.md`
- Compose API: https://developer.android.com/reference/kotlin/androidx/compose/material3/package-summary — `Button(onClick, shapes, …)` (Expressive-перегрузка с морфом), `FilledTonalButton`, `OutlinedButton`, `TextButton`, `ElevatedButton`, `ToggleButton`, `ButtonDefaults.shapes()`, `ButtonDefaults.shapesFor(height)`, `ButtonDefaults.contentPaddingFor(height)`, `ButtonDefaults.textStyleFor(height)`, `ToggleButtonDefaults.shapesFor(height)`
- Compose исходник: `Button.kt` (`Button`, `shapeByInteraction`, `ButtonDefaults`), `ToggleButton.kt` (`ToggleButton`, `shapeByInteraction`, `ToggleButtonDefaults.defaultToggleButtonShapes`), `internal/AnimatedShape.kt` (`rememberAnimatedShape`); токены `ButtonXSmallTokens.kt`, `ButtonSmallTokens.kt`, `ButtonMediumTokens.kt`, `ButtonLargeTokens.kt`, `ButtonXLargeTokens.kt`, `BaselineButtonTokens.kt`, `FilledButtonTokens.kt`, `TonalButtonTokens.kt`, `OutlinedButtonTokens.kt`, `TextButtonTokens.kt`, `ElevatedButtonTokens.kt`; примеры `ButtonSamples.kt`, `ToggleButtonSamples.kt`
- MDC: https://github.com/material-components/material-components-android/blob/master/docs/components/CommonButton.md (размеры через `SizeOverlay.Material3Expressive.Button.*`, toggle — `android:checkable`)
- Flutter: `FilledButton` (+`.tonal`, `.icon`, `.tonalIcon`), `OutlinedButton`, `TextButton`, `ElevatedButton` на базе `ButtonStyleButton` (`button_style_button.dart`). Умеет: форму по `WidgetState` через `ButtonStyle.shape`, размер/отступы/типографику. Не умеет: пружинный морф формы (форму анимирует `_MaterialInterior` в `material.dart` кривой `Curves.fastOutSlowIn` за `animationDuration`), toggle-кнопку Expressive (нет `selected`-формы/цветов по умолчанию), размеры XS/M/L/XL (только настраиваются вручную). Дефолты Flutter — baseline M3, не Expressive.

## Когда использовать
- Для дискретных действий в диалогах, формах, карточках, тулбарах; не перегружать экран кнопками.
- **Filled** — самое заметное после FAB, для финальных действий (Save, Confirm); в идеале одна на странице.
- **Tonal** — промежуточный акцент (Next в онбординге), вторичная палитра.
- **Outlined** — важное, но не главное; хорошая пара к filled, «передумать/выйти».
- **Text** — наименьший приоритет, в карточках, диалогах, снекбарах.
- **Elevated** — только когда нужна отделённость от яркого фона.
- **Toggle button** — бинарный выбор (Save, Favorite); не бывает text-стиля.
- Подпись 1–3 слова, sentence case, в одну строку, без обрезки; иконка — только ведущая, одна.

## Варианты и анатомия
- Варианты: default и toggle (selection).
- Конфигурации: цвет (elevated, filled — по умолчанию, tonal, outlined, text), размер (XS, S — по умолчанию, M, L, XL), форма (round — по умолчанию, square), отступы small: 16dp (рекомендовано) или 24dp (больше не рекомендуется).
- Анатомия: контейнер, подпись, иконка (необязательна, ведущая).

## Размеры, формы, цвета
Размеры (токены `md.comp.button.<size>.*`, в Compose `Button<Size>Tokens.kt`):

| Размер | Высота | Отступы | Иконка | Иконка↔текст | Шрифт | Square | Pressed |
|---|---|---|---|---|---|---|---|
| XS | 32dp | 12dp | 20dp | 4dp (`space50`) | labelLarge | 12dp (medium) | 8dp (small) |
| S | 40dp | 16dp | 20dp | 8dp | labelLarge | 12dp (medium) | 8dp (small) |
| M | 56dp | 24dp | 24dp | 8dp | titleMedium | 16dp (large) | 12dp (medium) |
| L | 96dp | 48dp | 32dp | 12dp | headlineSmall | 28dp (extra-large) | 16dp (large) |
| XL | 136dp | 64dp | 40dp | 16dp | headlineLarge | 28dp (extra-large) | 16dp (large) |

- Round у всех размеров — `corner.full`. Toggle: у round-кнопки выбранная форма = square-значение размера (`md.comp.button.small.selected.container.shape.round` = `corner.medium`), у square — full.
- Шрифты L/XL — из `ButtonDefaults.textStyleFor` (Compose); для XS/S/M есть токены `label-text`.
- Обводка outlined: 1dp (XS–M), 2dp (L), 3dp (XL).
- Compose: `ButtonDefaults.MinWidth = 58.dp`, `MinHeight = 40.dp`. На m3.material.io минимальной ширины нет.

Цвета (default / toggle unselected / toggle selected):

| Стиль | Default | Toggle unselected | Toggle selected |
|---|---|---|---|
| Elevated | surfaceContainerLow / primary, тень level1 | surfaceContainerLow / primary | primary / onPrimary |
| Filled | primary / onPrimary | surfaceContainer / onSurfaceVariant | primary / onPrimary |
| Tonal | secondaryContainer / onSecondaryContainer | secondaryContainer / onSecondaryContainer | secondary / onSecondary |
| Outlined | обводка outlineVariant, текст **onSurfaceVariant** | то же | inverseSurface / inverseOnSurface |
| Text | текст primary | — | — |

- Disabled: контейнер onSurface 10%, текст и иконка onSurface 38% (`md.comp.button.disabled.*`).
- State layer: hover 8%, focus 10%, pressed 10%.
- Иконка и текст всегда одного цвета.

## Состояния и движение
- **Нажатие**: форма морфится к pressed-радиусу (таблица выше), и round, и square приходят к одному pressed-радиусу. Токен m3: `md.comp.button.<size>.pressed.container.corner-size.motion.spring` = `fast.spatial`. **Compose** (`Button.kt`, `Button(onClick, shapes, …)`) сознательно использует `MotionSchemeKeyTokens.DefaultEffects` (1600/1.0) с комментарием «intentional here to prevent any bounce in this component». Морф — `shapeByInteraction` → `rememberAnimatedShape`. Старая перегрузка `Button(onClick, shape = …)` форму не морфит.
- **Toggle** (`ToggleButton.kt`): приоритет формы pressed > checked > shape. Морф на `MotionSchemeKeyTokens.FastSpatial` (800/0.6), толщина обводки на `FastSpatial`, цвет обводки на `DefaultEffects`. Цвет контейнера и текста **не анимируется**: `ToggleButtonColors.containerColor(enabled, checked)` отдаётся в `Surface` напрямую. Дефолты small: shape full, checked `ButtonSmallTokens.SelectedContainerShapeSquare` (12dp), pressed `RoundedCornerShape(6.dp)`. На m3.material.io pressed у S = 8dp, то есть Compose тут отличается от спеки. `ToggleButtonDefaults.shapesFor(height)` подбирает набор по высоте: ≤36 → XS, ≤48 → S, ≤76 → M, ≤116 → L, иначе XL.
- **Тень**: у filled/tonal level0, hover level1; у elevated level1, hover level2. Анимируется `animateElevation`.
- Toggle: иконка outlined → filled при выборе; если filled-версии нет — semibold.

## Доступность
- Контраст включённой кнопки с фоном ≥ 3:1: у elevated/filled/tonal считается по контейнеру, у outlined/text — по тексту.
- При 200% шрифта подпись должна помещаться в 2 строки.
- XS и S — зона нажатия ≥ 48×48dp.
- Клавиатура: Tab — фокус, Space/Enter — нажатие. Метка доступности совпадает с видимой подписью.
- Compose: `Role.Button`, у toggle — `Role.Checkbox`.

## В приложении
- Где используется:
  - Тема: `lib/app.dart` (`filledButtonTheme`, `outlinedButtonTheme`, `textButtonTheme` → `AppButtonStyles.small`), `lib/theme/app_button_styles.dart`.
  - `lib/features/schedule/schedule_screen.dart`: `FilledButton` «Выбрать группу», `FilledButton.tonal` «Повторить», `TextButton` «Повторить» в `_RefreshErrorBanner` (цвет onErrorContainer).
  - `lib/features/absences/widgets/certificate_sheet.dart`: `OutlinedButton` «Отмена» + `FilledButton` «Отправить», оба `AppButtonStyles.medium`.
  - `lib/features/profile/profile_screen.dart`: `FilledButton.tonalIcon` «Сменить группу».
  - `lib/features/group_picker/group_picker_sheet.dart`: `FilledButton.tonal` «Повторить». `lib/widgets/empty_state.dart` — слот `action`.
- Совпадает: S — 40dp, отступы 16dp, labelLarge, иконка 20dp, pressed 8dp; M — 56dp, 24dp, titleMedium, иконка 24dp, pressed 12dp; round = `StadiumBorder`; обводка outlined — outlineVariant; tonal — secondaryContainer; text — primary; иерархия на экранах.
- Расхождения:
  1. Цвет текста outlined-кнопки: сейчас primary (дефолт Flutter `_OutlinedButtonDefaultsM3.foregroundColor` в `outlined_button.dart`) → должно быть onSurfaceVariant → `md.comp.button.outlined.label-text.color`, `OutlinedButtonTokens.LabelTextColor`. Касается «Отмена» в `certificate_sheet.dart`.
  2. Кривая морфа при нажатии: сейчас `Curves.fastOutSlowIn` на длительности `AppMotion.defaultEffects.duration` (Flutter берёт из `ButtonStyle` только длительность) → должна быть пружина `DefaultEffects` (Compose) или `FastSpatial` (токен m3) → `Button.kt` / `md.comp.button.*.pressed.container.corner-size.motion.spring`. Выбор Compose (без перелёта) уже описан в `app_button_styles.dart`, но сама кривая не пружинная.
  3. Disabled-контейнер: сейчас onSurface 12% (дефолт Flutter `filled_button.dart`) → onSurface 10% → `md.comp.button.disabled.container.opacity`.
  4. Индикатор загрузки в «Отправить» (`certificate_sheet.dart`): кнопка на время отправки disabled, а индикатор окрашен `onPrimary` поверх disabled-контейнера (onSurface ~10%). Цвет содержимого disabled-кнопки по токенам — onSurface 38% (`md.comp.button.filled.disabled.label-text.*`). Сейчас светлый индикатор на светлом фоне почти не виден. Сам сценарий «загрузка внутри кнопки» спецификация кнопок не описывает.
  5. Минимальная ширина: сейчас 48dp (`AppButtonStyles._style`) → Compose `ButtonDefaults.MinWidth = 58.dp`. На m3.material.io минимальной ширины нет — низкий приоритет, достаточно отметить.
  6. Toggle-кнопок Expressive во Flutter нет. Самодельные toggle — селектор дней и connected group — см. `button-groups.md`.
- Что сделать во Flutter:
  1. В `buildTheme` (`lib/app.dart`) для `outlinedButtonTheme` добавить `foregroundColor` и `iconColor`: onSurfaceVariant для enabled, onSurface 38% для disabled.
  2. Во всех стилях `AppButtonStyles` задать `backgroundColor` с disabled = `onSurface.withValues(alpha: 0.1)` (для filled/tonal/elevated), `foregroundColor` disabled = onSurface 38%.
  3. Пружинный морф: сделать обёртку (например, `SpringShapeButton`), которая слушает `WidgetStatesController` кнопки, гонит `AnimationController.animateWith(AppMotion.defaultEffects.simulate(...))` и отдаёт в `style.shape` `RoundedRectangleBorder` с текущим радиусом (full = height/2 → pressed). При этом `animationDuration: Duration.zero`, чтобы `_MaterialInterior` не накладывал свою кривую.
  4. Индикатор в disabled-кнопке окрашивать цветом disabled-содержимого (onSurface 38%) или взять его из `IconTheme`/`DefaultTextStyle` кнопки, а не задавать `onPrimary` жёстко.

### Реализация во Flutter
- Виджеты: `M3Button` (`lib/widgets/m3_buttons.dart`) — стили elevated / filled / tonal / outlined / text, размеры XS–XL (`M3ButtonSize`), форма round / square (`M3ButtonShape`), ведущая иконка. Toggle — `M3ToggleButton` (`lib/widgets/m3_toggle_button.dart`) со стилями elevated / filled / tonal / outlined и `M3ToggleButtonDefaults.shapesFor(height)`. Оба построены на общем ядре `M3ButtonContainer`: форма `M3CornerShape` (углы в dp или % от меньшей стороны, как `CornerSize`), морф `M3ShapeMorph` (порт `AnimatedShapeState`), тень, state layer `AppStateLayer.overlay(contentColor)`, зона нажатия `M3TouchTarget` (порт `_InputPadding`). `ButtonStyleButton` не используется: `Material` получает `animationDuration: Duration.zero`, радиусы ведёт свой `AnimationController`.
- Точно как в Compose / m3: высоты, отступы (вертикальные — `ButtonDefaults.contentPaddingFor`), иконки, промежутки иконка↔текст, шрифты — по таблице выше; round → pressed и square → pressed по токенам; морф `Button` — пружина DefaultEffects, `ToggleButton` — FastSpatial, с текущей скоростью и разворотом `1 - p`, если цель вернулась к началу; приоритет формы pressed > checked > shape; новый набор форм — без анимации (`key(shapes)`); цвета контейнера и содержимого меняются мгновенно; обводка toggle — толщина FastSpatial, цвет DefaultEffects; outlined — подпись onSurfaceVariant, обводка outlineVariant; disabled — контейнер onSurface 10%, содержимое onSurface 38%; тень — `animateElevation` (к взаимодействию 120 мс FastOutSlowIn, обратно 150 мс / после hover 120 мс `Cubic(0.4, 0, 0.6, 1)`); `ButtonDefaults.MinWidth` 58dp; содержимое обрезается по форме; подпись в одну строку без переноса и многоточия; зона нажатия ≥ 48dp; семантика `Role.Button`, у toggle — checked (`Role.Checkbox`).
- Отступления (осознанные):
  1. Toggle S pressed = 8dp (токен `md.comp.button.small.pressed.container.shape`), а не `RoundedCornerShape(6.dp)` из `ToggleButtonDefaults` — m3 главнее, у самого Compose `ButtonDefaults.pressedShape` тоже 8dp.
  2. Disabled-содержимое onSurface × 0.38 и обводка outlineVariant без прозрачности — токены m3; в Compose (`FilledButtonTokens` и др.) содержимое OnSurfaceVariant × 0.38, обводка `OutlineColor × 0.1`.
  3. Толщина обводки outlined по размеру (1 / 1 / 1 / 2 / 3dp, токены m3); Compose `outlinedButtonBorder` всегда 1dp.
  4. Цвет обводки toggle интерполируется `Color.lerp` (sRGB), в Compose `animateColorAsState` — в Oklab. Пружины завершаются по допуску Flutter (1e-3), в Compose — `visibilityThreshold` 0.01; конечное значение точное (`snapToEnd`).
  5. Рисунок ripple — `splashFactory` темы (InkSparkle), см. `interaction-states.md`.
- Экраны пока на `FilledButton` / `OutlinedButton` / `TextButton` с `AppButtonStyles`; расхождения 1–3 из списка выше закрываются переводом на `M3Button` (интеграция — отдельный шаг).

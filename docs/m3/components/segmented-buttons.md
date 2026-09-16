# Сегментированные кнопки (Segmented buttons)

Статус в приложении: — не используется (и не должен)

## Источники
- Guidelines / Specs / Accessibility: https://m3.material.io/components/segmented-buttons/guidelines (и /specs, /accessibility); дамп `.m3-guidelines/components__segmented-buttons.md`
- Compose API: https://developer.android.com/reference/kotlin/androidx/compose/material3/package-summary — `SingleChoiceSegmentedButtonRow`, `MultiChoiceSegmentedButtonRow`, `SegmentedButton`, `SegmentedButtonDefaults`
- Compose исходник: `SegmentedButton.kt` (раскладка содержимого `SegmentedButtonContentMeasurePolicy` на `FastSpatial`; галочка появляется через `fadeIn(DefaultEffects) + scaleIn(FastSpatial)`), токены `OutlinedSegmentedButtonTokens.kt`, пример `SegmentedButtonSamples.kt`
- MDC: отдельной страницы `SegmentedButton.md` нет (404). В `ButtonGroup.md` сказано, что segmented button устарел и его заменяет connected button group (`Widget.Material3Expressive.MaterialButtonGroup.Connected`).
- Flutter: `SegmentedButton` (`segmented_button.dart`) — baseline M3: outlined-сегменты, галочка у выбранного. В Expressive не использовать.

## Когда использовать
В M3 Expressive — **не рекомендуется** (обновление мая 2025). Вместо него — connected button group «с почти той же функциональностью». Раньше: выбор из 2–5 вариантов, single-/multi-select; при большем числе вариантов — chips; сегменты не переносятся на новую строку.

## В приложении
Не используется: фильтр в `notes_screen.dart` и выбор подгруппы в `profile_screen.dart` уже сделаны на `ConnectedButtonGroup` (`lib/widgets/connected_button_group.dart`), как требует Expressive. Возвращать `SegmentedButton` не нужно; замечания к connected group — в `button-groups.md`.

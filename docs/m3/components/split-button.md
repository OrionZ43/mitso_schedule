# Кнопка с меню (Split button)

Статус в приложении: — не используется

## Источники
- Guidelines / Specs / Accessibility: https://m3.material.io/components/split-button/guidelines (и /specs, /accessibility); дамп `.m3-guidelines/components__split-button.md`
- Compose API: https://developer.android.com/reference/kotlin/androidx/compose/material3/package-summary — `SplitButtonLayout(leadingButton, trailingButton, modifier, spacing)`, `SplitButtonDefaults.LeadingButton`, `.TrailingButton`, `.TonalLeadingButton`/`.TonalTrailingButton`, `.OutlinedLeadingButton`/`.OutlinedTrailingButton`, `.ElevatedLeadingButton`/`.ElevatedTrailingButton`
- Compose исходник: `SplitButton.kt` (морф форм на `MotionSchemeKeyTokens.DefaultEffects`), токены `SplitButtonXSmallTokens.kt` … `SplitButtonXLargeTokens.kt`. Small: высота 40dp, промежуток 2dp, внутренние углы 4dp, pressed/hovered 12dp, у выбранной trailing — 50%, отступы leading 16/12dp, trailing 13/13dp, иконка 22dp. Пример `SplitButtonSamples.kt`.
- MDC: https://github.com/material-components/material-components-android/blob/master/docs/components/SplitButton.md (`MaterialSplitButton`, `Widget.Material3.SplitButton.*`)
- Flutter: виджета нет. Собирается из двух кнопок с асимметричными формами + `MenuAnchor`.

## Когда использовать
Главное действие плюс меню связанных действий в одной кнопке: leading-кнопка с подписью (1–2 слова) и иконкой, trailing-кнопка с иконкой раскрытия. Иконка trailing поворачивается на 180° внутрь при открытии; поворот — **standard** motion scheme, не expressive. Меню выравнивается по trailing-кнопке, отступ 4dp. Размеры XS–XL, стили elevated, filled, tonal, outlined.

## В приложении
Не используется: ни на одном экране нет пары «главное действие + меню вариантов». Добавлять не нужно. Если появится (например, «Отправить справку» с вариантами), брать размеры из `SplitButton*Tokens.kt`.

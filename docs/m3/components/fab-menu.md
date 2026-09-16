# Меню FAB (FAB menu)

Статус в приложении: — не используется

## Источники
- Guidelines / Specs / Accessibility: https://m3.material.io/components/fab-menu/guidelines (и /specs, /accessibility); дамп `.m3-guidelines/components__fab-menu.md`
- Compose API: https://developer.android.com/reference/kotlin/androidx/compose/material3/package-summary — `FloatingActionButtonMenu(expanded, button, modifier, horizontalAlignment, content)`, `FloatingActionButtonMenuScope.FloatingActionButtonMenuItem(onClick, text, icon, …)`, `ToggleFloatingActionButton(checked, onCheckedChange, …)`, `ToggleFloatingActionButtonDefaults`
- Compose исходник: `FloatingActionButtonMenu.kt`. Появление пунктов по очереди — `SlowEffects`; ширина пункта — `FastSpatial`, прозрачность — `FastEffects`; морф FAB → кнопка закрытия (`ToggleFloatingActionButton`) — `FastSpatial`. Токены `FabMenuBaselineTokens.kt`: пункт 56dp, форма full, отступы 24dp, иконка 24dp, иконка↔текст 8dp, между пунктами 4dp; кнопка закрытия 56dp full, иконка 20dp, отступ до пунктов 8dp; тень level3. Пример `FloatingActionButtonMenuSamples.kt`.
- MDC: https://github.com/material-components/material-components-android/blob/master/docs/components/FloatingActionButtonMenu.md (ссылается на Compose API)
- Flutter: виджета нет.

## Когда использовать
Открывается из FAB (не из extended FAB) и показывает 2–6 тесно связанных действий. FAB превращается в кнопку закрытия, пункты появляются паттерном enter/exit от верхнего trailing-угла FAB. Цветовые наборы primary/secondary/tertiary под цвет FAB. Заменяет speed dial и стопки маленьких FAB. Не использовать рядом с floating toolbar или navigation rail.

## В приложении
Не используется: FAB в «Заметках» (`notes_screen.dart`) выполняет одно действие «Добавить задачу», на «Пропусках» — extended FAB, из которого меню открывать нельзя. Не нужен, пока у FAB не появится 2–6 связанных действий.

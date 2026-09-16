# Боковой лист (Side sheets)

Статус в приложении: — не используется

## Источники
- Guidelines / Specs / Accessibility: https://m3.material.io/components/side-sheets/guidelines,
  https://m3.material.io/components/side-sheets/specs, https://m3.material.io/components/side-sheets/accessibility
  (выгрузка: `.m3-guidelines/components__side-sheets.md`)
- Compose API: в Compose Material3 (`commonMain`) отдельного компонента side sheet нет.
- MDC: https://github.com/material-components/material-components-android/blob/master/docs/components/SideSheet.md
  (`SideSheetBehavior`, `SideSheetDialog`)
- Flutter: готового виджета нет. Модальный вариант собирается из `Drawer` или `showGeneralDialog`.

## Когда использовать
- Дополнительный контент и действия, не прерывающие основной. **Standard** — в основном в medium и
  expanded окнах. **Modal** предпочтителен в compact окнах. На больших экранах side sheet может
  заменить bottom sheet (bottom-sheets → Responsive layout).

## Размеры, формы, цвета
| Элемент | Значение | Источник |
|---|---|---|
| Ширина | 256dp, высота 100% | `md.comp.sheet.side.docked.container.width` / `height` |
| Standard | `surface`, level0, углы 0 | `md.comp.sheet.side.docked.standard.*` |
| Modal | `surfaceContainerLow`, level1, углы `corner.large` (16dp) со стороны контента; detached — `corner.large` | `md.comp.sheet.side.docked.modal.*`, `detached.container.shape` |
| Заголовок и разделитель | заголовок `onSurfaceVariant`, разделитель `outline` | `md.comp.sheet.side.docked.headline.color`, `divider.color` |

## В приложении
- Не используется. Вспомогательные сценарии (выбор группы, отправка справки) на телефоне сделаны
  модальными bottom sheets. Это верный выбор для compact окон (`bottom-sheets.md`).

# Разделитель (Divider)

Статус в приложении: ⚠️ частично

Тема разделителя совпадает с токенами: `outlineVariant`, 1dp. В приложении он один — в поиске.
Боковые отступы 18dp вместо 16dp, и он стоит рядом с разделителем, который Flutter уже рисует
под строкой поиска.

## Источники
- Guidelines / Specs / Accessibility: https://m3.material.io/components/divider/guidelines,
  https://m3.material.io/components/divider/specs, https://m3.material.io/components/divider/accessibility
  (выгрузка: `.m3-guidelines/components__divider.md`)
- Compose API: https://developer.android.com/reference/kotlin/androidx/compose/material3/package-summary —
  `HorizontalDivider(modifier, thickness, color)`, `VerticalDivider(modifier, thickness, color)`,
  `DividerDefaults.Thickness` / `DividerDefaults.color` (`Divider` устарел)
- Compose исходник: `Divider.kt` (`HorizontalDivider`, `VerticalDivider`), токены `tokens/DividerTokens.kt`
- MDC: https://github.com/material-components/material-components-android/blob/master/docs/components/Divider.md
  (`MaterialDivider`, `MaterialDividerItemDecoration`, full-width и inset)
- Flutter: `Divider`, `VerticalDivider`, `DividerThemeData` (`packages/flutter/lib/src/material/divider.dart`).
  Есть: `thickness`, `color`, `indent` / `endIndent`, `height` (высота места под разделитель). Всё
  нужное по спецификации поддерживается.

## Когда использовать
- Разделитель группирует элементы, а не отделяет каждый пункт. Его ставят, только если элементы
  нельзя сгруппировать пустым пространством. Он должен быть заметным, но не жирным (Overview).
- **Full-width** разделяет крупные несвязанные разделы, а также интерактивную и неинтерактивную
  области в карточке. **Inset** разделяет связанный контент внутри раздела. Если на экране есть
  оба типа, они подчёркивают иерархию.
- Списки с повторяющимся форматом могут обойтись без разделителей, только отступами. Для
  expressive-списков нужны зазоры, а не разделители (lists → Gaps & dividers).
- Вертикальный разделитель — для больших экранов (текст рядом с медиа).

## Варианты и анатомия
- Full-width, inset, middle-inset, vertical. Анатомия — одна линия.

## Размеры, формы, цвета
| Элемент | Значение | Источник |
|---|---|---|
| Толщина | 1dp | `md.comp.divider.thickness`; `DividerTokens.Thickness` |
| Цвет | `outlineVariant` | `md.comp.divider.color`; `DividerTokens.Color` |
| Inset | 16dp слева, 0 справа | Specs → Measurements |
| Middle-inset | 16dp слева и справа | Specs → Measurements |
| Отступ до supporting text | 4dp | Specs → Measurements |
| Отступ справа и снизу (в макете спецификации) | 8dp | Specs → Measurements |

Особые случаи. У разделителя в списке (`md.comp.list.divider.color`) цвет `outline` и отступы по
16dp. У разделителя search view (`md.comp.search-view.divider.color`) тоже `outline`.

## Состояния и движение
- Состояний и анимаций нет.

## Доступность
- Разделитель декоративный: минимального контраста нет, для screen reader он не нужен.

## В приложении
- Где используется:
  - `lib/app.dart` → `dividerTheme`: `outlineVariant`, `thickness: 1`, `space: 1`;
  - `lib/features/schedule/schedule_screen.dart` → `_ScheduleSearchBar._suggestions`:
    `Divider(indent: 18, endIndent: 18, height: 22)` между фильтр-чипами и результатами поиска.
- Уже соответствует:
  - цвет и толщина в теме;
  - в списках разделителей нет, вместо них зазоры.
- Расхождения:
  1. **Боковые отступы.** Сейчас 18dp. Должно: 16dp у middle-inset. Источник: Specs → Measurements.
  2. **Второй разделитель подряд.** Flutter `SearchAnchor` в полноэкранном виде уже рисует
     `Divider(height: 1)` под строкой поиска (`search_anchor.dart`, `viewDivider`, цвет
     `SearchViewThemeData.dividerColor`). Ниже идут чипы и ещё один разделитель. По гайдлайну
     разделитель нужен, только если нельзя обойтись отступом. Должно: проверить на экране. Если
     чипы уже отделены от результатов отступом, второй разделитель убрать. Если оставить —
     middle-inset 16dp. Источник: Overview «Only use dividers if items can't be grouped with open space».
- Что сделать во Flutter:
  1. `Divider(indent: 16, endIndent: 16)`; высоту места задавать отступами соседних элементов, а
     не `height: 22`. Токен задаёт отступ до supporting text 4dp и нижний 8dp.
  2. Цвет разделителя search view в `searchViewTheme` (`dividerColor`) сверить с разделом
     `search.md`: по токену там `outline`.

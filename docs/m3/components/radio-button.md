# Радиокнопка (Radio button)

Статус в приложении: — не используется

## Источники
- Guidelines / Specs / Accessibility: https://m3.material.io/components/radio-button/guidelines,
  https://m3.material.io/components/radio-button/specs, https://m3.material.io/components/radio-button/accessibility
  (выгрузка: `.m3-guidelines/components__radio-button.md`)
- Compose API: https://developer.android.com/reference/kotlin/androidx/compose/material3/package-summary —
  `RadioButton(selected, onClick, …)`, `RadioButtonDefaults.colors()`
- Compose исходник: `RadioButton.kt`, токены `tokens/RadioButtonTokens.kt`, пример
  `samples/RadioButtonSamples.kt` (`RadioButtonSample`, `RadioGroupSample`)
- MDC: https://github.com/material-components/material-components-android/blob/master/docs/components/RadioButton.md
- Flutter: `Radio`, `RadioListTile`, `RadioGroup` (`radio.dart`, `radio_list_tile.dart`),
  M3-умолчания в `_RadioDefaultsM3`.

## Когда использовать
Выбор **одного** варианта из набора, когда все варианты должны быть видны. Каждая радиокнопка с
подписью. Радиокнопки не вкладывают друг в друга и не используют для множественного выбора
(Guidelines → Usage).

## Варианты и анатомия
Одна иконка: кольцо и точка при выборе.

## Размеры, формы, цвета

| Элемент | Значение | Источник |
|---|---|---|
| Иконка | 20dp | `RadioButtonTokens.IconSize` |
| State layer / зона нажатия | 40dp / 48dp | `StateLayerSize`; Specs → Measurements |
| Выбранная / невыбранная | `primary` / `onSurfaceVariant` | `SelectedIconColor` / `UnselectedIconColor` |
| Отключённая | `onSurface` 38% | `Disabled*IconOpacity` |
| Подпись | `onSurface`, цвет не зависит от выбора | Specs → Adjacent text label color |

## Состояния и движение
Compose (`RadioButton.kt`): радиус точки — `MotionSchemeKeyTokens.FastSpatial`, цвет —
`DefaultEffects`.

## Доступность
- Выбирать можно нажатием и на подпись, и на кнопку. Зона нажатия 48dp, плотность по умолчанию не
  уменьшать.
- Снять выбор со всей группы нельзя. Если нужен отказ от выбора, добавить вариант «Не
  применимо» или отдельное «Сбросить выбор».
- Клавиатура: Tab ведёт к выбранной кнопке группы (или к первой), стрелки перемещают фокус и
  выбор с переходом по кругу, Space выбирает.
- Доступное имя группы = её заголовок, роль Radio group; имя кнопки = её подпись. Во Flutter
  группа объединяется через `RadioGroup` (`widgets/radio_group.dart`).

## В приложении
Не используется. Кандидат: настройка «Тёмная тема» в `lib/features/profile/profile_screen.dart`.
По сути это выбор одного из трёх (как в системе / светлая / тёмная), а сейчас он сделан
переключателем (см. `switch.md`, расхождение 3). Подойдут радиокнопки или connected button group.

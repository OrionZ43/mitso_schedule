# Все кнопки — выбор кнопки (All buttons)

Статус в приложении: ⚠️ частично

## Источники
- Guidelines: https://m3.material.io/components/all-buttons (дамп `.m3-guidelines/components__all-buttons.md`). Отдельных Specs/Accessibility у страницы нет — они у каждого компонента.
- Compose API: https://developer.android.com/reference/kotlin/androidx/compose/material3/package-summary — `Button`, `ToggleButton`, `IconButton`/`IconToggleButton`, `SplitButtonLayout`, `ButtonGroup`, `FloatingActionButton`, `ExtendedFloatingActionButton`, `FloatingActionButtonMenu`
- Compose исходник: `Button.kt`, `ToggleButton.kt`, `IconButton.kt`, `SplitButton.kt`, `ButtonGroup.kt`, `FloatingActionButton.kt`, `FloatingActionButtonMenu.kt`
- MDC: https://github.com/material-components/material-components-android/blob/master/docs/components/Button.md (индекс со ссылками на CommonButton.md, IconButton.md, ButtonGroup.md, SplitButton.md, FloatingActionButton.md, ExtendedFloatingActionButton.md, FloatingActionButtonMenu.md)
- Flutter: есть `FilledButton`, `OutlinedButton`, `TextButton`, `ElevatedButton`, `IconButton`, `FloatingActionButton` (+`.extended`, `.small`, `.large`), устаревший `SegmentedButton`. **Нет**: toggle button (Expressive), button group, split button, FAB menu, medium FAB и `MotionScheme`.

## Когда использовать
Страница помогает выбрать кнопку по уровню акцента:

| Акцент | Компонент | Для чего |
|---|---|---|
| Высокий | FAB, extended FAB, FAB menu | главное действие экрана (Create, Compose) |
| Высокий | Filled button | финальное/разблокирующее действие (Save, Confirm) |
| Высокий | Split button | ключевое действие с вариантами |
| Высокий | Standard button group | несколько ключевых действий (Back, Pause, Next) |
| Средний | Tonal, elevated, outlined button | важные, но не главные; outlined — «передумать/выйти» |
| Низкий | Connected button group | переключение видимого контента (Walk, Bike, Drive) |
| Низкий | Text button, icon button | необязательные действия |

Правила иерархии: на экране **одна** кнопка высокого акцента; рядом с filled можно ставить outlined или text; не ставить кнопку под кнопкой, если помещаются рядом.

## Варианты и анатомия
10 типов: button, toggle button, icon button, toggle icon button, split button, standard button group, connected button group, FAB, extended FAB, FAB menu. Подробности — в файлах компонентов рядом.

## Размеры, формы, цвета
См. `buttons.md`, `icon-buttons.md`, `button-groups.md`, `floating-action-button.md`, `extended-fab.md`.

## Состояния и движение
См. файлы компонентов. Общее для Expressive: при нажатии форма морфится, у toggle-кнопок меняется форма при выборе, в standard button group нажатая кнопка раздвигает соседние.

## Доступность
См. файлы компонентов. Общее: зона нажатия ≥ 48×48dp, контраст контейнера (или текста у outlined/text) ≥ 3:1.

## В приложении
- Где используется:
  - Расписание (`lib/features/schedule/schedule_screen.dart`): `IconButton.filledTonal` в app bar, `FilledButton` / `FilledButton.tonal` в пустых состояниях, `TextButton` в баннере ошибки, селектор дней `lib/widgets/day_selector.dart`.
  - Пропуски (`lib/features/absences/absences_screen.dart`): `FloatingActionButton.extended`. Шит справки (`widgets/certificate_sheet.dart`): `OutlinedButton` + `FilledButton` размера Medium.
  - Заметки (`lib/features/notes/notes_screen.dart`): `FloatingActionButton` + `ConnectedButtonGroup` (фильтр).
  - Профиль (`lib/features/profile/profile_screen.dart`): `FilledButton.tonalIcon`, `ConnectedButtonGroup` (подгруппа).
- Расхождения:
  - Иерархия по экранам соблюдена: одно действие высокого акцента на экран (extended FAB / FAB / filled в пустом состоянии), outlined «Отмена» рядом с filled «Отправить».
  - Селектор дней не соответствует ни одному типу из списка: сейчас это самодельные «плитки» → должен быть button group из toggle-кнопок → см. `button-groups.md`.
- Что сделать во Flutter: см. разделы «В приложении» в файлах компонентов.

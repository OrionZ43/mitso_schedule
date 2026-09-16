# Доступность (Accessibility)

> Разделы «В приложении → Расхождения» описывают состояние на 16.09.2026, до порта компонентов. Исправлено с тех пор: эталонная статичная схема и системные роли Android 14+, emphasized-веса по токенам, opsz и grade иконок, state layer, цвета tooltip, чипов и app bar при прокрутке, scrim 32%, выдуманные альфы, размеры шрифта и радиусы (карточка пары и метки удалены), пустое состояние из `MaterialShapes`, пружины кнопок, листов и снекбара, смена дня — lateral. Остаётся: breakpoints и navigation rail для окон шире 600dp (приложение для телефона), часть отступов вне токенов в старом коде.

## Источники

- m3.material.io → `.m3-guidelines/`:
  - https://m3.material.io/foundations/building-for-all → `foundations__building-for-all.md`
  - вкладки Accessibility компонентов: `components__buttons.md`, `components__cards.md`, `components__chips.md`, `components__checkbox.md`, `components__lists.md`, `components__bottom-sheets.md`, `components__navigation-bar.md`, `components__loading-indicator.md`, `components__progress-indicators.md`, `components__segmented-buttons.md`, `components__icon-buttons.md`, `components__dialogs.md`, `components__carousel.md`, `components__search.md`
  - стили и основы: `styles__color__system.md` (уровни контраста), `styles__color__roles.md`, `styles__typography.md` (Accessibility), `styles__icons.md` (Accessibility), `styles__motion__transitions.md` (Follows accessibility settings), `styles__spacing.md`, `foundations__layout__grids-spacing.md` (Density), `foundations__layout__bidirectionality-rtl.md`, `foundations__interaction__states.md`
- Compose Material3: `InteractiveComponentSize.kt` (48.dp), `Ripple.kt` (фокус)
- MDC-Android: `docs/theming/Color.md` (Contrast Control)
- Flutter: `widgets/basic.dart` (`Semantics`, параметр `role`), `dart:ui` `SemanticsRole.progressBar`, `widgets/media_query.dart` (`disableAnimationsOf`)

## Правила

### Подход (Building for all)

- Учитывать «dimensions of experience»: возраст, культура, инвалидность, образование и грамотность, этничность, гендер, география, физические особенности, раса, религия, ориентация, социально-экономический статус, владение технологиями. Привлекать людей из недопредставленных сообществ к исследованию и тестированию (co-design) — на ранних этапах и постоянно.

### Зрение и контраст

- Пары цветовых ролей дают минимум 3:1; использовать роли только в задуманных парах.
- Текст: **4.5:1** для мелкого, **3:1** для крупного. Кнопки: 3:1 контейнера к фону (filled, tonal, elevated) или подписи к фону (outlined, text). Подпись чипа — 3:1 к фону. Обводки сгруппированных кнопок — 3:1. Индикаторы прогресса и загрузки — активная часть 3:1 к фону.
- Индикатор прогресса внутри другого компонента: цвет активной части = цвет подписи/иконки, **трек убрать**; у линейного индикатора stop indicator обязателен, если трек < 3:1 к контейнеру/поверхности.
- Уровни контраста: standard, medium (3:1), high (7:1) — поддерживаются, если собственные компоненты используют роли.
- Не передавать выбор только цветом: чекбокс/радио, иконка, подчёркивание (lists); у сегментов — галочка + цвет.
- Disabled-элементы не обязаны соответствовать контрасту.

### Моторика и ввод

- Зона нажатия ≥ **48×48dp** (иконка 24dp → 48dp; вложенные icon buttons тоже); плотность не применять по умолчанию.
- Любое действие перетаскиванием или свайпом — с альтернативой одним указателем (меню, кнопка, тап, long press). **Pull-to-refresh**: «can't be accessible by just swiping» — нужна кнопка обновления рядом с контентом или в меню.
- Чекбокс переключается нажатием и на него, и на текстовую подпись.
- Bottom sheet: верхние 48dp интерактивны при изменяемом размере; drag handle фокусируется, имеет роль button и переключает высоты.
- Карточка — либо сама действие (без вложенных кнопок), либо неинтерактивный контейнер с кнопками; декоративные изображения скрыть от screen reader.

### Screen reader и клавиатура

- Подпись кнопки для доступности = видимый текст (можно дополнить контекстом); icon button без текста — описание действия.
- Индикатор загрузки/прогресса — роль **progress bar** и подпись с процессом и объектом («Loading news article»).
- Navigation bar: выбранный пункт — filled-иконка + bold label, невыбранный — outlined + medium label; подписи видны полностью до 2× размера текста; начальный фокус — первый пункт.
- Изменения контента (результаты поиска) объявлять screen reader (`components__search.md`).
- Порядок элементов, включая кнопки, одинаков на маленьких и больших экранах (`components__buttons.md`). RTL — зеркальная раскладка и жесты.

### Текст и движение

- При 200% шрифта: отступы сохраняются; подписи кнопок — не больше 2 строк; заголовки диалогов — не больше 4; иначе дать доступ к полному тексту одним нажатием.
- Иконки меньше 20dp (сложные или ключевые) — с подписью; навигационные пункты — всегда с подписью.
- Ссылки — подчёркнуты.
- Системная настройка уменьшения движения: лёгкие fade вместо сдвигов/масштаба, без parallax и shape morph (карусель — без расширения элементов).

## Как устроено в Compose

- `Modifier.minimumInteractiveComponentSize()` у всех интерактивных компонентов (48.dp).
- Семантика встроена в компоненты: `Role.Button` (`Button.kt`), `progressBarRangeInfo` у индикаторов (`LoadingIndicator.kt`, `ProgressIndicator.kt`, `WavyProgressIndicator.kt`).
- Контраст с dynamic color на Android 14+ приходит из системы (MDC `Color.md`: «You will get contrast control for free if you already use dynamic colors»).

## В приложении

### Как сейчас

- Зоны нажатия 48dp: `connected_button_group.dart`, `notes_screen.dart` (`Checkbox`), `app_button_styles.dart` (icon button 40dp + padded).
- Семантика: `day_selector.dart` (`button`, `selected`, полная дата в подписи), `connected_button_group.dart` (`inMutuallyExclusiveGroup`), `lesson_card.dart` (подписи подгрупп и «Текущая пара»), `M3LoadingIndicator` и `M3WavyLinearProgress` (`label`, у загрузки `liveRegion`), tooltips у icon buttons и FAB.
- Масштаб текста учитывается (`TextScaler` в `schedule_screen.dart`, `day_selector.dart`; бейджи растут вместе с текстом).
- `test/status_contrast_test.dart` проверяет контраст статусов ≥ 4.5:1.

### Расхождения

| # | Сейчас | Должно быть | Источник |
|---|---|---|---|
| 1 | Обновление расписания — только жест pull-to-refresh (`schedule_screen.dart:85`); кнопка «повторить» есть лишь в баннере ошибки | Отдельная кнопка/пункт меню «Обновить» | `components__loading-indicator.md` (Accessibility) |
| 2 | Прогресс в карточке текущей пары (`lesson_card.dart:516–518`): `trackColor: onPrimary × 0.32` | Внутри другого компонента: активная часть цветом подписи (`onPrimary` — уже так), **трек убрать**; иначе stop indicator при треке < 3:1 | `components__progress-indicators.md` (Accessibility) |
| 3 | `M3LoadingIndicator`, `M3WavyLinearProgress` — `Semantics(label)` без роли | `Semantics(role: SemanticsRole.progressBar, label: …)` (у определённого — значение прогресса) | `components__progress-indicators.md`, `components__loading-indicator.md` (Labeling), `dart:ui` `SemanticsRole` |
| 4 | Нет реакции на уменьшение движения (`MediaQuery.disableAnimations` в `lib/` не используется) | Fade вместо сдвигов/масштаба, без shape morph (день, кнопки, индикатор) | `styles__motion__transitions.md` |
| 5 | Нет поддержки уровней контраста (`contrastLevel` не передаётся; dynamic через легаси `Scheme`) | Standard / medium / high | `styles__color__system.md`, MDC `Color.md` |
| 6 | Заметки (`notes_screen.dart`): текст задачи не переключает чекбокс | Нажатие на подпись тоже переключает (например, `CheckboxListTile` или общий `InkWell` + `MergeSemantics`) | `components__checkbox.md` (Accessibility) |
| 7 | Navigation bar: выбранная подпись отличается только цветом | Bold label у выбранного, medium — у остальных | `components__navigation-bar.md` (Visual indicators) |
| 8 | Полупрозрачный текст на `primary` (`onPrimary` α 0.78–0.86 в `lesson_card.dart`, α 0.82 в `day_selector.dart`) и `onSurfaceVariant` α 0.7 в `absence_donut.dart` — контраст не гарантирован ролями и не проверяется тестом | Роли в задуманных парах без изменения альфы; если отступление — тест контраста ≥ 4.5:1 в обеих темах и на всех уровнях контраста | `styles__color__roles.md`, `styles__typography.md` |
| 9 | Мелкие иконки 16–18dp рядом с текстом (`absences_screen.dart`, `lesson_card.dart`) | Допустимо только для простых символов с подписью — сейчас подпись есть; размеры привести к шкале (см. `icons.md`) | `styles__icons.md` (Small icons) |
| 10 | Смена дня свайпом (`schedule_screen.dart` `_DaySwitcher`) | Альтернатива одним указателем есть — тапы по `DaySelector`; сохранить | `components__cards.md`, `components__lists.md` (single-pointer alternative) |

### Что сделать во Flutter

1. Добавить в app bar расписания icon button «Обновить» (с tooltip) — тот же `refresh()`.
2. Убрать трек у `M3WavyLinearProgress` на карточке текущей пары или добавить stop indicator.
3. Проставить `role: SemanticsRole.progressBar` индикаторам; у определённого прогресса — `value`.
4. Ввести `AppMotion.reduced(context)` на `MediaQuery.disableAnimationsOf` и использовать во всех переходах и морфах.
5. Поддержать уровни контраста (см. `color.md`), расширить `status_contrast_test.dart` на все пары текст/фон, включая виджеты с альфой, либо убрать альфу.
6. Сделать строку задачи целиком переключаемой; подпись выбранного пункта навигации — bold.

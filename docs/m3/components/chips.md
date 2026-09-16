# Чипы (Chips)

Статус в приложении: ⚠️ частично

Настоящие чипы (`FilterChip` в поиске, `ChoiceChip` палитры) близки к спеке, но у них неверная
обводка и нештатное отключение. Пять «чипов-меток» (`_InfoChip`, `_TaskChip`,
`LessonTypeBadge`, `SubgroupBadge`, `CertificateStatusBadge`) не являются компонентом M3:
выглядят как чипы, но неинтерактивны и не совпадают с их размерами.

## Источники
- Guidelines / Specs / Accessibility: https://m3.material.io/components/chips/guidelines,
  https://m3.material.io/components/chips/specs, https://m3.material.io/components/chips/accessibility
  (выгрузка: `.m3-guidelines/components__chips.md`)
- Compose API: https://developer.android.com/reference/kotlin/androidx/compose/material3/package-summary —
  `AssistChip`, `ElevatedAssistChip`, `FilterChip` (в том числе перегрузка с `shapes: ChipShapes`),
  `ElevatedFilterChip`, `InputChip`, `SuggestionChip`, `FilterChipDefaults.filterChipColors()`,
  `tonalFilterChipColors()`, `filterChipBorder()`, `FilterChipDefaults.shapes()`, `IconSize`
- Compose исходник: `Chip.kt` (`SelectableChip`, `AnimatingChipContent`, `shapeByInteraction`,
  `HorizontalElementsPadding`), токены `tokens/FilterChipTokens.kt`, `AssistChipTokens.kt`,
  `SuggestionChipTokens.kt`, `InputChipTokens.kt`, `ChipsTokens.kt`, пример
  `samples/ChipSamples.kt` (`FilterChipSample`, `FilterChipWithCornerMorphingSample`,
  `FilterChipWithLeadingIconSample`)
- MDC: https://github.com/material-components/material-components-android/blob/master/docs/components/Chip.md
  (`Widget.Material3.Chip.Filter/Assist/Input/Suggestion`, `ChipGroup`)
- Flutter: `FilterChip`, `ChoiceChip`, `ActionChip`, `InputChip`, `ChipTheme`
  (`chip.dart`, `filter_chip.dart`, `choice_chip.dart`). M3-умолчания сгенерированы по токенам:
  32dp, 8dp, `labelLarge`, обводка `outlineVariant`, выбранный `secondaryContainer`. Анимация
  своя, с фиксированной длительностью: выбор 195 мс, галочка 150 мс, «выдвижение» аватара 150 мс,
  `Curves.fastOutSlowIn` (`_kSelectDuration`, `_kCheckmarkDuration`, `_kDrawerDuration` в
  `chip.dart`). Пружины и морфинга формы нет.

## Когда использовать
- Чипы — **интерактивные** элементы. Они помогают вводить данные, выбирать, фильтровать или
  запускать действие в текущем контексте (Guidelines → Usage). Всегда группой, не по одному.
  Нельзя заменять ими основные действия (Save/Cancel), для этого кнопки.
- Какой вариант выбрать (Guidelines → Variants):
  - **Assist** — умное или контекстное действие («Добавить в календарь»), текст начинается с
    глагола;
  - **Filter** — фильтр коллекции или результатов; можно выбрать один или несколько. Одиночный
    выбор заменяет segmented buttons, радиокнопки или меню;
  - **Input** — информация, которую ввёл пользователь (контакт в поле «Кому»);
  - **Suggestion** — сгенерированные подсказки (быстрые ответы, поисковые запросы).
- На одной странице все наборы чипов либо с одиночным, либо с множественным выбором, не
  вперемешку.
- Filter chips под полем поиска — штатный паттерн.

## Варианты и анатомия
- Контейнер; подпись (≤ 20 символов, типографика как у кнопок); ведущая иконка или изображение
  (необязательно); замыкающая иконка (обязательна у input, необязательна у filter).
- При выборе filter chip к подписи слева добавляется галочка.
- Ведущая иконка невыбранного чипа по умолчанию `primary`, допустим `onSurfaceVariant`.
  Аватар (24dp) крупнее иконки (18dp).
- Приподнятый (elevated) чип — только на картинке или сложном фоне; на обычном фоне обводка.

## Размеры, формы, цвета

| Элемент | Значение | Источник |
|---|---|---|
| Высота | 32dp (зона нажатия ≥ 48dp) | `md.comp.filter-chip.container.height`; Guidelines → Placement |
| Форма | 8dp (`corner.small`) | `md.comp.*-chip.container.shape`; `FilterChipTokens.ContainerShape` = `CornerSmall` |
| Поля слева/справа | 16dp; с иконкой 8dp; между элементами 8dp | Specs → Filter chip measurements; `FilterChipDefaults.ContentPadding` = 8dp по горизонтали, `HorizontalElementsPadding` = 8dp |
| Иконка / аватар | 18dp / 24dp (форма аватара 12dp у input chip) | `with-icon.icon.size`; Input chip measurements |
| Подпись | `labelLarge` | `label-text.font` |
| Filter: невыбранный | фон прозрачный, обводка 1dp `outlineVariant`, подпись `onSurfaceVariant` | `flat.unselected.outline.color`, `unselected.label-text.color` |
| Filter: выбранный | фон `secondaryContainer`, обводки нет, подпись и иконки `onSecondaryContainer` | `flat.selected.container.color`, `selected.outline.width` = 0 |
| Assist | подпись `onSurface`, иконка `primary`, обводка `outlineVariant` | `assist-chip.*` |
| Suggestion | подпись `onSurfaceVariant`, обводка `outlineVariant` (в списке ролей на сайте — «Outline») | `suggestion-chip.flat.outline.color` |
| Отключённый | подпись `onSurface` 38%, обводка `onSurface` 12%, выбранный фон `onSurface` 12% | `disabled.*` |
| Расстояние между чипами | ≥ 8dp | Guidelines → Placement |

Обновление Aug 2024: цвет обводки сменили с `outline` на `outlineVariant`. Для доступности
(Accessibility → Showing chip interactivity) `outline` допустим как один из способов показать,
что чип интерактивный. Другие способы — подпись перед группой («Выберите …») или ведущая иконка.

Morph формы: в Compose есть необязательная перегрузка `FilterChip(shapes = FilterChipDefaults.shapes())`
с токенами `ChipsTokens`: невыбранный `CornerMedium` (12dp), выбранный `CornerFull`, нажатый
`CornerSmall`, морфинг `FastSpatial`. На m3.material.io этого нет (там 8dp), а `FilterChip` по
умолчанию остаётся 8dp, поэтому по гайду **не применять**.

## Состояния и движение
Compose (`Chip.kt`):
- `SelectableChip` (filter и input без `shapes`): ведущая и замыкающая иконки появляются через
  `AnimatedVisibility`. Выдвижение `expandHorizontally` — `FastSpatial`, скрытие
  `shrinkHorizontally` — `DefaultEffects`, проявление `fadeIn` — `SlowEffects`, исчезновение
  `fadeOut` — `FastEffects`.
- Вариант с `shapes`: морфинг углов `FastSpatial`, иконки `FastSpatial` и `DefaultEffects`
  (с пометкой `TODO: Replace with correct animation tokens`).
- Цвет контейнера и подписи в `SelectableChip` берётся из `SelectableChipColors` без анимации.
- Состояния: enabled, disabled, hovered, focused, pressed (ripple), dragged (elevation level4).
  Нажатие не показывать приподнятием, только ripple (Guidelines → Shadows & elevation, DON'T).

## Доступность
- Контраст подписи с фоном ≥ 3:1.
- Роли: чип с одним действием — button; выбираемый — checkbox (Compose `Role.Checkbox`) или
  radio button (MDC). Доступное имя = текст подписи, иконка скрыта от озвучки.
- Зона нажатия ≥ 48dp, плотность по умолчанию не уменьшать.
- Клавиатура: Tab к чипу или группе, Space/Enter выбирает, стрелки двигают между чипами.
- Интерактивность надо показать дополнительным признаком: подписью перед группой, контекстом
  («Фильтр результатов»), обводкой `outline` или ведущей иконкой.

## В приложении
- `lib/features/profile/profile_screen.dart` → `_PalettePicker`: `ChoiceChip` с `CircleAvatar`
  (радиус 8), обёрнут в `Opacity(enabled ? 1 : 0.4)`.
- `lib/features/schedule/schedule_screen.dart` → `_ScheduleSearchBar._suggestions`: `FilterChip`
  «предмет / преподаватель / аудитория» (одиночный выбор).
- `lib/app.dart` → `chipTheme`: форма 8dp, `labelLarge`, выбранный `secondaryContainer` /
  `onSecondaryContainer`, невыбранный прозрачный, **обводка `scheme.outline`**, `showCheckmark: true`.
- Неинтерактивные «чипы-метки»:
  - `profile_screen.dart` → `_InfoChip` (курс, факультет, форма обучения): minHeight 32,
    поля 14, `bodyMedium` w500, фон `primaryContainer`/`surface`;
  - `lib/features/notes/notes_screen.dart` → `_TaskChip` (предмет, срок): minHeight 26, поля 10,
    `labelMedium`, фон `primaryContainer`/`errorContainer`/`surfaceContainerHigh`;
  - `lib/widgets/status_badge.dart` → `LessonTypeBadge`, `CertificateStatusBadge`: `labelSmall`
    без минимальной высоты или 28dp с `labelMedium`, поля 10/12; на карточке текущей пары фон
    `onPrimary` с прозрачностью 0.22;
  - `lib/widgets/lesson_card.dart` → `SubgroupBadge`: `labelSmall`, фон `surfaceContainerHigh`.

### Расхождения
1. **Обводка невыбранного чипа.** Сейчас `BorderSide(color: scheme.outline)` в `chipTheme`.
   По токену `outlineVariant`; Flutter по умолчанию уже так делает (`_FilterChipDefaultsM3.side`).
   Если `outline` оставляют ради доступности, это нужно записать как осознанное отступление.
   Над обоими наборами чипов уже есть поясняющий контекст (заголовок «Палитра», строка поиска),
   поэтому достаточно `outlineVariant`.
2. **Отключённая палитра.** Сейчас `Opacity(0.4)` поверх группы. По токенам: подпись и иконка
   `onSurface` 38%, обводка `onSurface` 12%, выбранный фон `onSurface` 12%. Flutter делает это
   сам при `onSelected: null`. Прозрачность 0.4 в спеке не встречается.
3. **Размер образца цвета.** Сейчас `CircleAvatar(radius: 8)` = 16dp. Ведущая иконка filter
   chip — 18dp (`with-icon.icon.size`). У filter chip нет аватара, аватар 24dp только у input chip.
4. **Галочка.** Flutter `ChoiceChip` рисует галочку поверх аватара; в спеке галочка
   добавляется ведущей иконкой. В Compose `FilterChipSample` при выборе выдвигает
   `Icons.Filled.Done` (`FastSpatial`), а `FilterChipWithLeadingIconSample` меняет ведущую
   иконку `Home` на `Done`. Для палитры образец
   цвета — смысловой признак, его заменять галочкой нельзя. Допустимо оставить галочку на образце
   и записать решение; подходящего примера в источниках нет.
5. **Движение.** Сейчас у Flutter-чипов фиксированные 150–195 мс `fastOutSlowIn`. В Compose
   выдвижение иконки `FastSpatial`, проявление `SlowEffects`, скрытие `DefaultEffects` и
   `FastEffects`.
6. **Чипы-метки не являются компонентом M3.** В M3 нет неинтерактивного «тега» или «лейбла».
   Все четыре варианта чипов интерактивны (роль button или checkbox). Badge — только счётчик или
   точка на иконке навигации цвета `error`, до 4 символов (`components__badges.md`). Сейчас
   метки выглядят как чипы (контейнер 8dp), но не нажимаются, а высота (26/28/32/без минимума),
   шрифт (`labelSmall`, `labelMedium`, `bodyMedium`) и поля (10/12/14) не совпадают ни с чипами,
   ни друг с другом. Это противоречит «Showing chip interactivity»: пользователь ожидает, что чип
   нажимается. Решение по `status_badge.dart` и остальным — см. ниже.
7. **Одиночный выбор в поиске.** `FilterChip` «предмет / преподаватель / аудитория» с
   одиночным выбором разрешён, но в той же группе не должно быть множественного выбора
   (правило соблюдено). Проблема с обновлением чипов в `suggestionsBuilder` описана в `search.md`.

### Решение для `status_badge.dart` (тип пары, подгруппа, статус справки)
В M3 нет подходящего компонента:
- **assist/suggestion chip** не подходят: это действие или подсказка, 32dp, обводка, роль button;
- **badge** не подходит: только на иконках навигации, цвет `error`, до 4 символов.

По гайду остаются два варианта:
- **Текст** (рекомендуется): тип пары как overline или поясняющий текст элемента — токен
  списка `md.comp.list.list-item.overline` (`labelSmall`, `onSurfaceVariant`,
  `components__lists.md`). Цвет можно передавать иконкой рядом, но не заливкой-«чипом».
- **Осознанное отступление**: оставить цветные метки как свой элемент, но не похожий на чип
  (другая форма, без обводки и ripple, одинаковая типографика), и записать это в `docs/m3/` и в
  раздел «Сознательные отступления» README. Цвета `StatusColors` — пользовательские роли, их
  проверяет раздел color.

### Что сделать во Flutter
1. `chipTheme` в `buildTheme`: убрать `side`, `color`, `labelStyle` и `checkmarkColor`, так как
   умолчания `_FilterChipDefaultsM3` / `_ChoiceChipDefaultsM3` совпадают с токенами. Оставить
   только то, что расходится, или удалить `chipTheme` целиком.
2. `_PalettePicker`: убрать `Opacity`, отключать через `onSelected: null`. Образец цвета —
   `avatar: SizedBox.square(dimension: 18, child: DecoratedBox(shape: circle))`. Для отключённого
   состояния цвет образца умножить на 0.38 (`disabled.leading-icon.opacity`).
3. Если нужно движение Compose: свой `M3FilterChip` на `Material` + `InkWell` + `Row`, где ведущая
   иконка в `AnimatedSize`/`SizeTransition` с контроллером `AppMotion.fastSpatial` (выдвижение)
   и `AppMotion.defaultEffects` (скрытие), прозрачность `slowEffects` (вход) и `fastEffects`
   (выход); цвета без анимации. `Semantics(checked: selected)`.
4. `_InfoChip`, `_TaskChip`, `LessonTypeBadge`, `SubgroupBadge`, `CertificateStatusBadge`:
   выбрать вариант из решения выше. Если нужна интерактивность (например, срок задачи открывает
   выбор даты), использовать настоящий `AssistChip`/`ActionChip` 32dp с `labelLarge`.

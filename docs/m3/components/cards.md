# Карточки (Cards)

Статус в приложении: ⚠️ с отступлениями — пары снова карточками (решение заказчика 17.09.2026, README п. 21), сводка пропусков в filled card, справки — списком

> Разделы «В приложении → Расхождения» ниже описывают состояние до порта (16.09.2026); что сделано и что осталось — в «Реализация во Flutter» и в README.

Обычная карточка пары, справка и задача сделаны как outlined card: `surface` и `outlineVariant`
1dp. Радиус 28dp — записанное отступление. Остальное не по спецификации:
- внутренние отступы и зазоры между карточками больше токенов;
- у текущей и прошедшей пары и у сводных блоков цвета не совпадают ни с одним из трёх вариантов;
- `cardTheme` задан, но виджет `Card` нигде не используется.

## Источники
- Guidelines / Specs / Accessibility: https://m3.material.io/components/cards/guidelines,
  https://m3.material.io/components/cards/specs, https://m3.material.io/components/cards/accessibility
  (выгрузка: `.m3-guidelines/components__cards.md`)
- Compose API: https://developer.android.com/reference/kotlin/androidx/compose/material3/package-summary —
  `Card(onClick?, modifier, enabled, shape, colors, elevation, border, interactionSource, content)`,
  `ElevatedCard`, `OutlinedCard`, `CardDefaults.cardColors()` / `elevatedCardColors()` / `outlinedCardColors()`,
  `CardDefaults.cardElevation()` / `elevatedCardElevation()` / `outlinedCardElevation()`, `CardDefaults.outlinedCardBorder()`,
  `CardDefaults.shape` / `elevatedShape` / `outlinedShape`
- Compose исходник: `Card.kt` (`Card`, `ElevatedCard`, `OutlinedCard`, `CardElevation.animateElevation` — смена
  elevation по интеракциям через `Animatable`, не через `MotionScheme`), токены `tokens/FilledCardTokens.kt`,
  `tokens/ElevatedCardTokens.kt`, `tokens/OutlinedCardTokens.kt`, пример `samples/CardSamples.kt`
- MDC: https://github.com/material-components/material-components-android/blob/master/docs/components/Card.md
  (`MaterialCardView`, форма `?attr/shapeAppearanceCornerMedium`, состояния checked / dragged)
- Flutter: `Card`, `Card.filled`, `Card.outlined`, `CardThemeData` (`packages/flutter/lib/src/material/card.dart`).
  Три варианта с M3-дефолтами из токенов: elevated `surfaceContainerLow` + 1dp, filled `surfaceContainerHighest`,
  outlined `surface` + `outlineVariant`, радиус 12dp. Нет: смены elevation при нажатии, наведении и
  перетаскивании, состояний checked и dragged. Кликабельная карточка — `Card` с `InkWell` внутри
  (`clipBehavior: Clip.antiAlias`). Container transform — `OpenContainer` из `package:animations`.

## Когда использовать
- Карточка объединяет содержимое и действия на одну тему. Карточки выводят сеткой, вертикальным
  списком или каруселью (Guidelines → Usage).
- Не загонять контент в карточки, если отступы, заголовки или разделители дадут более простую
  иерархию (Usage, DON'T). На compact экранах стоит рассмотреть замену карточек списком
  (Adaptive design → Small screens).
- Карточка либо сама целиком действие (ripple, роль button/link), либо некликабельный контейнер
  с кнопками внутри. Кнопки на кликабельной карточке не размещают (Accessibility → Interaction & style).

## Варианты и анатомия
- **Elevated** — тень, отделена от фона сильнее filled. **Filled** — тонкое отделение, наименьший
  акцент. **Outlined** — обводка, наибольший акцент. Варианты отличаются только стилем.
- Анатомия: контейнер (обязателен), медиа, headline, subhead, supporting text, кнопки. Внутри
  можно размещать разделители, чипы, слайдеры, чекбоксы.
- В коллекции карточки лежат в одной плоскости с одинаковой высотой, пока их не подняли или не
  перетаскивают.

## Размеры, формы, цвета
| Элемент | Elevated | Filled | Outlined | Источник |
|---|---|---|---|---|
| Контейнер | `surfaceContainerLow` | `surfaceContainerHighest` | `surface` | `md.comp.*-card.container.color`; `*CardTokens.ContainerColor` |
| Elevation (покой / hover / pressed / dragged) | 1 / 3 / 1 / 8dp (level1 / level2 / level1 / level4) | 0 / 1 / 0 / 6dp (level0 / level1 / level0 / level3) | 0 / 1 / 0 / 6dp | `*CardTokens.*ContainerElevation` |
| Обводка | — | — | 1dp `outlineVariant` (disabled — `outline` 12%) | `OutlinedCardTokens.OutlineWidth` / `OutlineColor` |
| Форма | 12dp (`corner.medium`) | 12dp | 12dp | `*CardTokens.ContainerShape`; Specs → Measurements |
| Иконка | 24dp `primary` | 24dp `primary` | 24dp `primary` | `*CardTokens.IconColor` / `IconSize` |
| State layer pressed | `onSurface`, 10% | то же | то же | `md.comp.*-card.pressed.state-layer.*` |
| Отступы | 16dp слева и справа внутри; **не больше 8dp** между карточками | | | Specs → Measurements |

## Состояния и движение
- Состояния: hovered, focused, pressed, dragged, disabled. Elevation меняется по таблице выше:
  `CardElevation.animateElevation` в `Card.kt` анимирует `Animatable`. Пружин `MotionScheme` для
  формы или цвета у карточек в Compose нет.
- **Раскрытие:** container transform в полноэкранную страницу, «reserve this pattern for hero
  moments». Прокручивать содержимое внутри карточки нельзя (Behavior → Expanding).
- **Навигация:** можно использовать forward/backward transition — более простой вариант
  (Behavior → Navigation).
- **Жесты:** один свайп на карточку. Поднятая карточка поднимается над остальными и не
  расталкивает их. У перетаскивания должна быть альтернатива одним касанием.

## Доступность
- У кликабельной карточки ripple и hover-состояние, это tab stop с ролью button или link.
  Некликабельная карточка — просто контейнер без роли; tab stops — кнопки внутри.
- Декоративные изображения скрывают от screen reader.
- Порядок чтения: заголовок, изображение, текст, кнопки.

## В приложении
- Где используется:
  - `lib/widgets/lesson_card.dart` → `LessonCard`:
    - будущая пара — outlined: `surface` + `outlineVariant`, радиус 28dp;
    - текущая — залита `primary`, радиус 32dp, `closedElevation: 3`;
    - прошедшая — `surfaceContainerLow` без обводки;
    - нажатие открывает детали через `OpenContainer` (container transform);
  - `lib/features/absences/absences_screen.dart` → `_CertificateCard`: `Container` с outlined-стилем,
    радиус 28, отступы 20/18. `_SummaryCard`: `Container` `surfaceContainer`, радиус 32;
  - `lib/features/notes/notes_screen.dart` → `_TaskCard`: `Container` с outlined-стилем, радиус 28,
    отступ 18, выполненная задача с прозрачностью 0.6;
  - `lib/features/profile/profile_screen.dart` → `_GroupHeader`: `Container` `surfaceContainer`, радиус 32;
  - `lib/app.dart` → `cardTheme` (outlined, радиус 28) — `Card` нигде не используется;
  - `lib/theme/app_shapes.dart` → `AppShapes.card` = 28, `cardEmphasized` = 32, с комментарием
    об отступлении.
- Уже соответствует:
  - будущая пара, справка и задача — цвета и обводка outlined card;
  - кликабельная карточка пары не содержит кнопок и даёт ripple (`InkWell`);
  - раскрытие через container transform допускается гайдлайном.
- Расхождения:
  1. **Радиус.** Сейчас 28dp, у текущей пары 32dp. По спецификации 12dp (`corner.medium`). Источник:
     `*CardTokens.ContainerShape`, Specs → Measurements. Отступление уже записано в `AppShapes.card`,
     его нужно продублировать в README «Сознательные отступления».
  2. **Цвет текущей пары.** Сейчас заливка `primary` и тень 3dp (level2). Такого варианта нет:
     elevated — `surfaceContainerLow` + 1dp, filled — `surfaceContainerHighest` + 0dp. Источник:
     Specs → Tokens. Если выделение `primary` остаётся — это осознанное отступление. Тень в покое
     3dp в любом случае выше токенов: у elevated 1dp.
  3. **Прошедшая пара.** Сейчас `surfaceContainerLow` без тени и обводки: цвет elevated, но без его
     тени. Должно: один из трёх вариантов. Ближе всего filled (`surfaceContainerHighest`, 0dp) или
     elevated с тенью 1dp. Источник: Specs → Tokens.
  4. **`_SummaryCard` и `_GroupHeader`.** Сейчас `surfaceContainer`, радиус 32. Для filled card
     цвет `surfaceContainerHighest`, радиус 12dp. Источник: `FilledCardTokens`.
  5. **Внутренние отступы.** Сейчас 20dp у пары, 22dp у текущей, 20/18dp у справки, 18dp у
     задачи, 20/26dp у сводки. Должно: 16dp слева и справа. Источник: Specs → Measurements
     «Left/right padding 16dp».
  6. **Зазор между карточками.** Сейчас 12dp: у пар 6 + 6, у справок и задач по 12. Должно: не
     больше 8dp. Источник: Specs → Measurements «Padding between cards 8dp max».
  7. **Роль кликабельной карточки.** Сейчас `Semantics(container: true)` + `InkWell`: TalkBack не
     объявляет кнопку. Должно: роль button, так как карточка открывает детали. Источник:
     Accessibility → Labeling elements.
  8. **Карточки на `Container`.** Сейчас `_CertificateCard` и `_TaskCard` — `Container` с
     `BoxDecoration`, а `cardTheme` не работает. Должно: `Card.outlined` / `Card.filled`, чтобы
     цвета и форма шли из одной темы. Источник: Flutter `Card`; Compose `OutlinedCard`.
  9. **Выполненная задача с прозрачностью 0.6.** Такого состояния в спецификации карточек нет:
     disabled — это 0.38, и оно означает «неактивна». Это решение макета, его нужно записать в README.
- Что сделать во Flutter:
  1. В `cardTheme`: `margin: EdgeInsets.zero`, форма — пока радиус из `AppShapes.card` (отступление).
     Цвета не задавать: у `Card`, `Card.filled` и `Card.outlined` верные M3-дефолты. Для
     outlined обводку задать через `shape.side` или оставить дефолт `Card.outlined`.
  2. `_CertificateCard` и `_TaskCard` перевести на `Card.outlined(child: Padding(padding: EdgeInsets.all(16), ...))`.
     `_SummaryCard` и `_GroupHeader` — на `Card.filled`.
  3. `LessonCard`:
     - `closedColor` и `closedShape` оставить, но цвета взять из вариантов: будущая — outlined,
       прошедшая — filled или elevated. Текущая — отступление или elevated;
     - `closedElevation`: 0 для outlined и filled, 1 для elevated;
     - внутренний отступ `EdgeInsets.all(16)`;
     - `Semantics(button: true)` на корне.
  4. В списке пар и других списках карточек зазор 8dp: `Padding(vertical: 4)` или
     `SizedBox(height: 8)`.
  5. Если нужна реакция elevation на нажатие (elevated: hover 3dp, dragged 8dp) — `AnimatedPhysicalModel`
     или `Material(elevation:)` по состоянию `WidgetStatesController`. Для текущего набора
     outlined и filled при нажатии elevation не меняется.

### Реализация во Flutter

**Карточка пары** — `LessonCard` (`lib/features/schedule/lesson_card.dart`). Список пар в
segmented list (16.09.2026) заказчик вернул к карточкам из макета: гайд cards → Adaptive
советует список на compact-экранах, но карточки читаются лучше. Что сделано:

- будущая — outlined (`surface`, обводка `outlineVariant`), прошедшая — `surfaceContainerLow`
  без обводки, идущая — `primary` с тенью 3dp, радиусы 28 / 32dp (отступление, README п. 21);
- метки типа занятия и «N подгруппа» — не чипы: неинтерактивные подписи на контейнерных ролях;
- аудитория — крупный номер (`displaySmall`, 700) в форме `MaterialShapes.cookie9Sided`,
  выходящей из правого верхнего угла; у подгрупп — плашка в конце строки, при крупном шрифте
  переносится под преподавателя;
- у идущей пары метка «Сейчас идёт» с пульсирующей точкой (`FadeTransition`, при уменьшении
  движения не пульсирует) и волнистая шкала во всю ширину;
- нажатие — `InkWell`, подробности — платформенный переход forward/backward;
- производительность: карточка и её содержимое — в своих слоях (`RepaintBoundary`), рябь не
  перерисовывает текст и соседние карточки; `Material` без неявного твина формы.

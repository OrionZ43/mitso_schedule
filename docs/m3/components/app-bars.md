# Верхняя панель приложения (App bars)

Статус в приложении: ⚠️ частично

На «Расписании» стоит medium flexible app bar, собранный из `SliverAppBar`. Типографика верная.
Не совпадают высота с подзаголовком, заливка при прокрутке, анимация сворачивания и доводка.
На «Пропусках», «Заметках» и «Профиле» app bar нет: заголовок — обычный `Text` в начале списка,
без поведения app bar. У страницы пары размер заголовка small app bar не по токену, и заливка
при прокрутке выключена темой.

## Источники
- Guidelines / Specs / Accessibility: https://m3.material.io/components/app-bars/guidelines,
  https://m3.material.io/components/app-bars/specs, https://m3.material.io/components/app-bars/accessibility
  (выгрузка: `.m3-guidelines/components__app-bars.md`)
- Compose API: https://developer.android.com/reference/kotlin/androidx/compose/material3/package-summary —
  `TopAppBar(title, subtitle, modifier, navigationIcon, actions, titleHorizontalAlignment, expandedHeight, windowInsets, colors, scrollBehavior, contentPadding)`,
  `MediumFlexibleTopAppBar(title, modifier, subtitle, navigationIcon, actions, titleHorizontalAlignment, collapsedHeight, expandedHeight, windowInsets, colors, scrollBehavior)`,
  `LargeFlexibleTopAppBar`, `AppBarWithSearch` (`SearchBar.kt`), `TopAppBarDefaults.exitUntilCollapsedScrollBehavior()`,
  `.enterAlwaysScrollBehavior()`, `.pinnedScrollBehavior()`, `TopAppBarDefaults.topAppBarColors(containerColor, scrolledContainerColor, ...)`.
  `MediumTopAppBar` / `LargeTopAppBar` не рекомендуются.
- Compose исходник: `AppBar.kt`:
  - `SingleRowTopAppBar`, `TwoRowsTopAppBar`, `TopAppBarLayout`, `TopAppBarMeasurePolicy.placeTopAppBar`;
  - `settleAppBar`, `ExitUntilCollapsedScrollBehavior`;
  - `TopAppBarColors.containerColor(fraction)`, `TopAppBarDefaults.snapAnimationSpec`;
  - константы `MediumTitleBottomPadding` = 24dp, `LargeTitleBottomPadding` = 28dp,
    `TopAppBarHorizontalPadding` = 4dp, `TopAppBarTitleInset` = 12dp,
    `TopTitleAlphaEasing` = `CubicBezierEasing(.8f, 0f, .8f, .15f)`.

  Токены: `tokens/AppBarTokens.kt`, `tokens/AppBarSmallTokens.kt`, `tokens/AppBarMediumFlexibleTokens.kt`,
  `tokens/AppBarLargeFlexibleTokens.kt`. Примеры в `samples/AppBarSamples.kt`:
  `SimpleTopAppBarWithSubtitle`, `ExitUntilCollapsedMediumFlexibleTopAppBar`,
  `ExitUntilCollapsedLargeFlexibleTopAppBar`, `EnterAlwaysTopAppBar`.
- MDC: https://github.com/material-components/material-components-android/blob/master/docs/components/TopAppBar.md
  (medium и large объявлены устаревшими, `AppBarLayout` → `app:liftOnScrollColor` = `?attr/colorSurfaceContainer`)
- Flutter: `AppBar`, `SliverAppBar`, `SliverAppBar.medium` / `.large` (`packages/flutter/lib/src/material/app_bar.dart`).
  Есть:
  - только baseline medium (112dp) и large (152dp), заголовок появляется через `AnimatedOpacity`
    500 мс;
  - заливка при прокрутке через `WidgetState.scrolledUnder`. По умолчанию цвет берётся из
    `colorScheme.surfaceContainer`, но **только** если `backgroundColor` не задан или задан как
    `WidgetStateColor`. Смена цвета — через `Material` за 200 мс (`kThemeChangeDuration`), линейно.

  Нет: подзаголовка, flexible-вариантов, доводки pinned-бара к свёрнутому или развёрнутому
  состоянию, перекрёстного затухания двух рядов. Отступ действий `actionsPadding` по умолчанию 0.
  Заголовок после leading стоит на 72dp (56 + `kMiddleSpacing` 16).

## Когда использовать
- App bar описывает текущую страницу и даёт 1–2 главных действия. Остальные действия уходят в
  toolbar. Overflow-меню в app bar по возможности не ставят (Guidelines → Usage).
- Варианты (Guidelines → Usage):
  - **search app bar** — на главной, если поиск ключевой;
  - **small** — плотные макеты или состояние после прокрутки;
  - **medium flexible** — крупный заголовок, при прокрутке сворачивается в small;
  - **large flexible** — подчёркнутый заголовок.
- Medium и large (baseline) не рекомендуются, заменяются flexible.
- Одну trailing-кнопку можно сделать filled или tonal, в том числе wide. Несколько filled или
  tonal кнопок ставить нельзя.
- Не уменьшать высоту ниже дефолтной, не скруглять контейнер, всегда растягивать на всю ширину
  окна (Anatomy → Container, DO/DON'T).
- Заголовок не усекать. Small app bar — одна строка, flexible-варианты — до двух.

## Варианты и анатомия
- Анатомия: контейнер, leading button (назад или меню), headline, subtitle, trailing icon buttons
  (до двух). Можно добавить логотип или изображение.
- Выравнивание текста — по началу строки (по умолчанию) или по центру.
- Medium и large flexible подстраиваются под текст: с подзаголовком они выше.
- При прокрутке medium и large flexible превращаются в small и остаются small до возврата к
  началу страницы. Превращать их в search app bar нельзя (Behavior → Scrolling).

## Размеры, формы, цвета
| Вариант / элемент | Значение | Источник |
|---|---|---|
| Small | 64dp; title `titleLarge`, subtitle `labelMedium` | `md.comp.app-bar.small.*`; `AppBarSmallTokens` |
| Medium flexible | 112dp без подзаголовка, **136dp с подзаголовком**; title `headlineMedium`, subtitle `labelLarge`; в свёрнутом виде — small 64dp | `md.comp.app-bar.medium-flexible.*`; `AppBarMediumFlexibleTokens.ContainerHeight` / `LargeContainerHeight`; `TopAppBarDefaults.MediumAppBarCollapsedHeight` |
| Large flexible | 120dp / 152dp с подзаголовком; title `displaySmall`, subtitle `titleMedium` | `AppBarLargeFlexibleTokens` |
| Search app bar | поле 56dp, `corner.full`, `surfaceContainer` (при прокрутке `surfaceContainerHighest`), текст `bodyLarge` `onSurfaceVariant` | `md.comp.app-bar.small.search.*`, `md.comp.app-bar.search.*` |
| Контейнер | `surface`, при прокрутке `surfaceContainer`; углы `corner.none`; без тени | `md.comp.app-bar.container.color`, `on-scroll.container.color`; `AppBarTokens` |
| Цвета текста и иконок | title `onSurface`, subtitle `onSurfaceVariant`, leading `onSurface`, trailing `onSurfaceVariant` | `md.comp.app-bar.*.color` |
| Отступы по краям | 4dp до кнопок (`leading-space` / `trailing-space` = space50); между кнопками 0 | `TopAppBarHorizontalPadding`; `md.comp.app-bar.icon-button-space` |
| Начало заголовка | 16dp без leading (12 + 4); с leading — сразу после кнопки: 4 + 48, затем 4, итого 56dp | `TopAppBarMeasurePolicy.placeTopAppBar`: `max(TopAppBarTitleInset, navigationIcon.width)` + padding 4dp |
| Нижний отступ крупного заголовка | medium flexible — 24dp от **последней базовой линии** блока «заголовок + подзаголовок»; large flexible — 28dp | `MediumTitleBottomPadding`, `LargeTitleBottomPadding`, `Arrangement.Bottom` в `placeTopAppBar` |
| Иконки, аватар | 24dp, 32dp | `md.comp.app-bar.icon.size`, `avatar.size` |

## Состояния и движение
- **Small app bar** (`SingleRowTopAppBar`): как только содержимое уходит под бар
  (`overlappedFraction > 0.01`), цвет контейнера меняется с `containerColor` на
  `scrolledContainerColor` через `animateColorAsState(MotionSchemeKeyTokens.DefaultEffects)`.
- **Medium и large flexible** (`TwoRowsTopAppBar`):
  - Цвет контейнера = `lerp(containerColor, scrolledContainerColor, FastOutLinearInEasing(collapsedFraction))`.
    Он повторяет прокрутку без собственной анимации. `FastOutLinearInEasing` = `Cubic(0.4, 0, 1, 1)`,
    во Flutter это `Easing.legacyAccelerate`.
  - Верхний ряд (64dp) содержит leading, actions и **маленькие** title и subtitle. Их прозрачность
    равна `TopTitleAlphaEasing.transform(collapsedFraction)`.
  - Нижний ряд содержит **крупные** title и subtitle без кнопок. Прозрачность `1 − collapsedFraction`,
    ряд обрезается (`clipToBounds`) по мере уменьшения высоты.
  - Размер шрифта **не интерполируется**: это два отдельных текста с перекрёстным затуханием.
  - Для доступности верхний заголовок скрыт, пока `collapsedFraction < 0.5`, нижний — после этого
    порога (`hideTitleSemantics`).
- **Поведение при прокрутке** (`TopAppBarDefaults`):
  - `exitUntilCollapsed` — свернуть до small и держать до возврата к началу. Для medium и large
    flexible это описано в Guidelines;
  - `enterAlways` — скрыть и показать;
  - `pinned` — бар не двигается.
- **Доводка** (`settleAppBar`): когда палец отпущен или бросок закончился, остаток скорости
  гасится `rememberSplineBasedDecay()`. Если бар остался между состояниями, он доводится к
  ближайшему: при `collapsedFraction < 0.5` разворачивается, иначе сворачивается. Пружина —
  `TopAppBarDefaults.snapAnimationSpec` = `MotionSchemeKeyTokens.DefaultEffects`. Сам бар тоже
  можно тянуть (`Modifier.draggable`).
- Вариант из Guidelines (Behavior → Scrolling, видео): контейнер при прокрутке остаётся прозрачным,
  а кнопки внутри получают заливку. Тогда у icon buttons обязательно должен быть контейнер.

## Доступность
- Заголовку назначается роль заголовка (Accessibility → Labeling elements: «Title»). Метка
  совпадает с текстом, при необходимости дополняется контекстом.
- Первый фокус — на leading button. Tab переходит по кнопкам, Space и Enter активируют.
- У icon buttons есть подписи (tooltip или semanticLabel).
- Действия app bar должны оставаться доступными, когда содержимое прокручено.
- У search app bar контраст текста и поля не ниже 3:1.

## В приложении
- Где используется:
  - `lib/features/schedule/schedule_screen.dart` → `_ScheduleAppBar`: medium flexible на
    `SliverAppBar(pinned: true)` + `flexibleSpace` с `LayoutBuilder`;
  - `lib/features/schedule/lesson_details_page.dart` → `AppBar` с кнопкой «Назад» и датой в заголовке;
  - `lib/app.dart` → `appBarTheme` (`backgroundColor: scheme.surface`, `scrolledUnderElevation: 0`);
  - `lib/features/home/home_shell.dart` → `SafeArea(bottom: false)` вокруг всех вкладок;
  - без app bar: `lib/features/absences/absences_screen.dart`, `lib/features/notes/notes_screen.dart`,
    `lib/features/profile/profile_screen.dart`. В них `Text` `headlineMedium.emphasized` в
    начале `ListView`, отступ 22dp, под ним строка статуса.
- Уже соответствует (`_ScheduleAppBar`):
  - типографика: в развёрнутом виде `headlineMedium` + `labelLarge` `onSurfaceVariant`, в свёрнутом
    `titleLarge` + `labelMedium`;
  - в свёрнутом виде 64dp, заголовок начинается на 16dp;
  - сворачивается и остаётся small до возврата наверх (pinned);
  - одна tonal icon button с tooltip — это разрешено;
  - `Semantics(header: true)`.
- Расхождения:
  1. **Высота с подзаголовком.** Сейчас 112dp. Должно быть 136dp. Источник:
     `md.comp.app-bar.medium-flexible.with-subtitle.container.height`;
     `TopAppBarDefaults.MediumFlexibleAppBarWithSubtitleExpandedHeight`.
  2. **Заливка при прокрутке.** Сейчас всегда `surface`: `backgroundColor: colors.surface` в баре,
     в теме `backgroundColor: scheme.surface`. Во Flutter обычный цвет отключает `scrolledUnder`.
     Должно: `surface` → `surfaceContainer` по `legacyAccelerate(collapsedFraction)`. Источник:
     Overview «On scroll, apply a fill color»; `TwoRowsTopAppBar`.
  3. **Анимация сворачивания.** Сейчас `TextStyle.lerp` меняет размер шрифта и положение.
     Должно: перекрёстное затухание двух рядов. Маленький заголовок в верхнем ряду — прозрачность
     `Cubic(0.8, 0, 0.8, 0.15)`(fraction). Крупный в нижнем ряду — `1 − fraction` с обрезкой.
     Источник: `TwoRowsTopAppBar`, `TopTitleAlphaEasing`.
  4. **Нет доводки.** Сейчас бар может остановиться полусвёрнутым. Должно: после окончания
     прокрутки довести к ближайшему состоянию пружиной DefaultEffects. Источник: `settleAppBar`,
     `TopAppBarDefaults.snapAnimationSpec`.
  5. **Нижний отступ крупного заголовка.** Сейчас 16dp от низа блока. Должно: 24dp от базовой
     линии подзаголовка. Источник: `MediumTitleBottomPadding`, `placeTopAppBar`.
  6. **Ширина крупного заголовка.** Сейчас `end: 72` и в развёрнутом виде. Должно: во втором ряду
     кнопок нет, справа только 4dp. Место под кнопку резервируется лишь в верхнем ряду. Источник:
     `TwoRowsTopAppBar` → второй `TopAppBarLayout` с `actions = {}`.
  7. **Отступ trailing-кнопки.** Сейчас `SizedBox(width: 12)`, до края около 16dp. Должно: 4dp.
     Источник: `md.comp.app-bar.trailing-space` = space50; `TopAppBarHorizontalPadding`.
  8. **Зона статус-бара.** Сейчас `SafeArea` в `HomeShell` оставляет её цветом фона, и заливка
     бара под неё не заходит. Должно: фон бара рисуется и под `windowInsets`. Источник:
     `TopAppBarDefaults.windowInsets`, `TopAppBarLayout(Modifier.windowInsetsPadding)` внутри фона.
  9. **Начертание заголовка.** Сейчас `emphasized` (w700). Токены: `medium-flexible.title.font` =
     `headline-medium`, `small.title.font` = `title-large`, обычное начертание
     (`AppBarMediumFlexibleTokens.TitleFont`). Если emphasized остаётся — записать как осознанное
     отступление.
  10. **Три вкладки без app bar** («Пропуски», «Заметки», «Профиль»). Заголовок страницы и
      подзаголовок — элементы app bar (Anatomy). Medium flexible — «Use to display a larger
      headline», а при прокрутке нужна заливка (Overview). Сейчас:
      - крупный заголовок уезжает вместе с контентом;
      - нет свёрнутого small-состояния и заливки;
      - отступ 22dp вместо 16dp;
      - нет роли заголовка (у `Text` нет `Semantics(header: true)`);
      - вкладки оформлены по-разному, у «Расписания» app bar есть.

      Должно: тот же medium flexible app bar. «Пропуски» — subtitle со статусом синхронизации
      (текстом, `labelLarge`), 136dp. «Заметки» — subtitle со сводкой, 136dp. «Профиль» — без
      subtitle, 112dp. Всё с `exitUntilCollapsed`.
  11. **Страница пары** (`LessonDetailsPage`):
      - заголовок `titleMedium`, должен быть `titleLarge` (`md.comp.app-bar.small.title.font`);
      - заливка при прокрутке выключена темой, должна быть `surfaceContainer` с анимацией DefaultEffects;
      - заголовок после кнопки «Назад» стоит на 72dp, в Compose на 56dp (`placeTopAppBar`);
      - дату можно перенести в subtitle small app bar (`labelMedium`), это вариант Expressive,
        не обязательно.
- Что сделать во Flutter:
  1. В теме: убрать `backgroundColor: scheme.surface`. Цвет задавать как
     `WidgetStateColor.resolveWith((s) => s.contains(WidgetState.scrolledUnder) ? scheme.surfaceContainer : scheme.surface)`,
     `scrolledUnderElevation: 0` оставить (тени в M3 нет). Добавить `titleTextStyle: textTheme.titleLarge`
     (`onSurface`) и `actionsPadding: EdgeInsetsDirectional.only(end: 4)`. Для баров с leading —
     `titleSpacing: 0`, тогда заголовок встаёт на 56dp. Линейные 200 мс `Material` заменить на
     DefaultEffects можно только своим контейнером: прозрачный `AppBar` плюс
     `AnimatedContainer(duration: AppMotion.defaultEffects.duration, curve: AppMotion.defaultEffects.curve)`,
     цвет переключается по `ScrollNotification`.
  2. Вынести medium flexible в общий виджет (например, `lib/widgets/m3_flexible_app_bar.dart`):
     - `SliverPersistentHeader(pinned: true)` со своим делегатом: `minExtent` = 64 + верхний
       inset, `maxExtent` = 112 или 136 (с subtitle) + верхний inset;
     - `fraction = (shrinkOffset / (maxExtent - minExtent)).clamp(0, 1)`;
     - фон `Color.lerp(surface, surfaceContainer, Easing.legacyAccelerate.transform(fraction))`,
       растянут под статус-бар;
     - верхний ряд 64dp: leading (отступ 4) + маленькие title и subtitle
       (`Opacity(Cubic(0.8, 0, 0.8, 0.15).transform(fraction))`) + actions (отступ 4);
     - нижний ряд: `ClipRect` + `Align(bottomStart)`, крупные title и subtitle,
       `Opacity(1 - fraction)`, отступ 16dp слева и 4dp справа, 24dp от последней базовой линии
       (через `Baseline` или `TextPainter.computeDistanceToActualBaseline`);
     - `ExcludeSemantics` на невидимой копии заголовка по порогу 0.5.
  3. Доводка: `NotificationListener<ScrollEndNotification>` на `CustomScrollView`. Если
     `0 < fraction < 1` — вызвать `controller.animateTo(fraction < 0.5 ? 0 : maxExtent - minExtent,`
     `duration: AppMotion.defaultEffects.duration, curve: AppMotion.defaultEffects.curve)`.
  4. В `HomeShell` убрать `SafeArea` сверху. Верхний inset учитывает сам заголовок.
  5. Перевести «Пропуски», «Заметки» и «Профиль» на `CustomScrollView` с этим app bar вместо
     `Text` в `ListView`.

### Реализация во Flutter

Виджеты готовы, на экраны пока не подключены (расхождения 1–11 закрываются подключением).
Файл `lib/widgets/m3_flexible_app_bar.dart`, тесты `test/m3_flexible_app_bar_test.dart`.

- **`SliverMediumFlexibleAppBar({required String title, String? subtitle, Widget? leading, List<Widget> actions = const []})`**
  — pinned-сливер, порт `MediumFlexibleTopAppBar` → `TwoRowsTopAppBar` с `exitUntilCollapsed`.
  - Свой `RenderSliver` вместо `SliverPersistentHeader`. Экстенты берутся из раскладки рядов, как в
    `TopAppBarMeasurePolicy`: верхний ряд `max(64, маленький блок)`, нижний `max(48 | 72, крупный блок)`.
    Без подзаголовка 112dp, с ним 136dp, свёрнутый 64dp, всё плюс верхний inset. При шрифте 2× ряды
    растут, текст не обрезается. Прокрутка не перестраивает виджеты: цвет, прозрачность и семантика
    меняются при раскладке и отрисовке.
  - `fraction` = прокрутка / высота нижнего ряда (`collapsedFraction`). Фон
    `lerp(surface, surfaceContainer, legacyAccelerate(fraction))` рисуется и под статус-баром. Маленькие
    title/subtitle (`titleLarge`/`labelMedium`, по одной строке) — прозрачность `Cubic(0.8, 0, 0.8, 0.15)`.
    Крупные (`headlineMedium` до двух строк / `labelLarge` `onSurfaceVariant`) — `1 − fraction`, ряд обрезается.
    Веса обычные, по токенам.
  - Верхний ряд: leading с отступом 4dp (цвет `onSurface`), заголовок с `max(12, ширина leading) + 4` —
    56dp после кнопки 48dp, 16dp без неё; actions с отступом 4dp (`onSurfaceVariant`). Нижний ряд: заголовок
    на 16dp, справа 8dp (пустые слоты по 4dp + 4dp отступа блока).
  - Нижний отступ — точный `Arrangement.Bottom`: `24 − (высота блока − последняя базовая линия)`, уменьшается,
    если блок не помещается. Последняя базовая линия = высота блока − descent последней строки (у `RenderBox`
    Flutter только первая базовая линия, descent считается `TextPainter` тем же стилем). **Важно:** с
    токенами 112/136dp это правило всегда срабатывает. Крупный блок стоит вплотную к верху нижнего ряда,
    базовая линия ≈20dp от низа, а не 24dp. Так же в Compose.
  - Роль заголовка (`Semantics(header: true)`) только у видимой копии: у нижней при `fraction < 0.5`, иначе
    у верхней (`hideTitleSemantics`). Бар не пропускает нажатия к содержимому под ним.
- **`M3AppBarSettle({required Widget child})`** — оборачивает `CustomScrollView` или `NestedScrollView`.
  Бары внутри регистрируются сами через `InheritedWidget`. По `ScrollEndNotification` (вертикаль, палец
  отпущен, бросок отыгран) порт `settleAppBar`: если `0.01 ≤ fraction < 1`, `ScrollPosition.animateTo`
  разворачивает бар при `fraction < 0.5`, иначе сворачивает. Кривая —
  `AppMotion.defaultEffects.curve` за `duration`: это пружина DefaultEffects из покоя, как
  `AnimationState(...).animateTo(snapAnimationSpec)`. Новое касание прерывает доводку. При «Удалить
  анимации» — `jumpTo`.
- **`M3SmallAppBar({required String title, String? subtitle, Widget? leading, List<Widget> actions = const []})`**
  (`PreferredSizeWidget`) — порт `TopAppBar` → `SingleRowTopAppBar` с `pinnedScrollBehavior`. 64dp плюс
  статус-бар, та же раскладка ряда, title `titleLarge` и subtitle `labelMedium` в одну строку. Слушает
  `ScrollNotificationObserver` (его даёт `Scaffold`). Когда `extentBefore > 0.64dp` (`overlappedFraction > 0.01`),
  цвет `surface` → `surfaceContainer` меняется пружиной `AppMotion.defaultEffects` с сохранением скорости,
  обратно так же.
- Цвета интерполируются в Oklab, как `lerp(Color, Color)` и `animateColorAsState` в Compose, а не в sRGB, как
  `Color.lerp`. Статические `containerColorFor` у обоих баров отдают эту функцию.
- Отступления:
  1. **Доводка — отдельный виджет.** В Compose её включает `scrollBehavior`, во Flutter нужен
     `NotificationListener`, поэтому список оборачивают в `M3AppBarSettle`. Без него бар не доводится.
  2. **Инерция не гасится отдельно.** Сворачивание — часть прокрутки, бросок отыгрывает физика списка, поэтому
     `flingAnimationSpec` из `settleAppBar` не нужен.
  3. **Бар тянется вместе со списком.** В Compose перетаскивание самого бара (`Modifier.draggable`) меняет
     только его высоту. Во Flutter бар — часть `CustomScrollView`, жест прокручивает весь список. Если
     содержимое короче экрана, бар не свернётся полностью, и цель доводки ограничена `maxScrollExtent`.
  4. **Число строк.** В Compose `maxLines` задаёт вызывающий код. Здесь по Guidelines → Headline: в small
     одна строка с многоточием («Don't wrap text in a small app bar»), крупный заголовок до двух строк.
  5. **Стиль статус-бара.** Как `AppBar` Flutter, бары кладут `SystemUiOverlayStyle` по яркости фона
     (прозрачный статус-бар, иконки контрастные). В Compose это делает `enableEdgeToEdge` активности.
  6. **Высота small в `Scaffold.appBar`.** `Scaffold` ограничивает бар `preferredSize` = 64dp. При крупном
     шрифте с подзаголовком (от ≈1.46×: 28 + 16dp на масштаб > 64dp) нужна обёртка `PreferredSize` с
     `M3SmallAppBar.preferredHeightOf(context, withSubtitle: true)`.
  7. **Заголовок с ролью header.** В Compose `TopAppBar` роль не ставит. Здесь она по Accessibility → Labeling
     elements («Title»), как `AppBar` Flutter (без `namesRoute`).
  8. Оставшиеся пункты «Что сделать» (1, 4, 5) и расхождения 1–11 закрываются при подключении виджетов к
     экранам. `.emphasized` в заголовках не используется.

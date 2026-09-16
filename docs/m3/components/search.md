# Поиск (Search)

Статус в приложении: ❌ не соответствует

Размещение и сама строка поиска в целом соответствуют гайду. Открытый поиск (focused search)
сделан в стиле **divided (baseline)**, а в M3 Expressive он помечен «Not recommended. Use
contained.».

## Источники
- Guidelines / Specs / Accessibility: https://m3.material.io/components/search/guidelines,
  https://m3.material.io/components/search/specs, https://m3.material.io/components/search/accessibility
  (выгрузка: `.m3-guidelines/components__search.md`)
- Compose API: https://developer.android.com/reference/kotlin/androidx/compose/material3/package-summary —
  `SearchBar(state, inputField, …)`, `AppBarWithSearch` (ранее `TopSearchBar`, помечен
  `@Deprecated`), `ExpandedFullScreenContainedSearchBar`, `ExpandedFullScreenSearchBar`,
  `ExpandedDockedSearchBar`, `ExpandedDockedSearchBarWithGap`, `rememberContainedSearchBarState`,
  `rememberSearchBarState`, `rememberSearchBarWithGapState`, `SearchBarDefaults.InputField`,
  `SearchBarDefaults.containedColors(state)`, `SearchBarDefaults.enterAlwaysSearchBarScrollBehavior`.
  Старые `SearchBar(query, onQueryChange, …)` и `DockedSearchBar(...)` помечены `@Deprecated`.
- Compose исходник: `SearchBar.kt` (`FullScreenSearchBarLayout`, `ExpandedFullScreenSearchBarImpl`,
  `SearchBarDefaults`, константы в конце файла), токены `tokens/SearchBarTokens.kt`,
  `tokens/SearchViewTokens.kt`, примеры `samples/SearchBarSamples.kt` (`SimpleSearchBarSample`,
  `FullScreenSearchBarScaffoldSample`, `DockedSearchBarScaffoldSample`)
- MDC: https://github.com/material-components/material-components-android/blob/master/docs/components/Search.md
  (раздел «M3 Expressive»: `Widget.Material3Expressive.SearchBar`,
  `Widget.Material3Expressive.SearchView.AppBarWithSearch` — contained style)
- Flutter: `SearchAnchor` / `SearchAnchor.bar` / `SearchBar` / `SearchController`
  (`packages/flutter/lib/src/material/search_anchor.dart`). Есть: строка 56dp в форме таблетки,
  полноэкранный или docked view, подсказки через `suggestionsBuilder`, свой контент через
  `viewBuilder`. Нет: contained style. View всегда рисует шапку с прозрачным `SearchBar`,
  разделителем и морфингом прямоугольника за 600 мс `Curves.easeInOutCubicEmphasized`
  (`_kOpenViewDuration`, `_SearchViewRoute`). Нет пружин, нет расширения строки на месте, нет
  predictive back для поиска (в исходнике `search_anchor.dart` поддержку не нашёл; на устройстве
  не проверялось).

## Когда использовать
- Точка входа зависит от роли поиска (Guidelines → Different ways to search):
  - **Search bar под заголовком** — поиск по содержимому конкретного экрана («Search your
    messages»). Это наш случай: поиск по загруженному расписанию.
  - **Search app bar** (`AppBarWithSearch`) — поиск как главная глобальная функция приложения.
  - **Search icon button** — поиск как второстепенное действие.
- При фокусе открывается focused search: подсказки можно показывать до ввода, результаты —
  по мере ввода или после Enter.
- Фильтр-чипы для сужения результатов прямо разрешены (Guidelines → Search suggestions &
  results).

## Варианты и анатомия
- Стили: **contained** (рекомендован в Expressive: строка остаётся таблеткой, под ней заливка
  без разделителя) и **divided** (baseline: разделитель между строкой и результатами, для
  Expressive «Not recommended»).
- Раскладки: **full-screen** (по умолчанию на compact) и **docked** (для medium и expanded;
  список под строкой, основной контент под scrim).
- Анатомия: контейнер строки; ведущая иконка (нефункциональная иконка поиска **или**
  навигационная кнопка); подсказка (supporting text); 1–2 замыкающие иконки или аватар;
  введённый текст; контейнер подсказок и результатов (список).
- В фокусе ведущая иконка становится кнопкой «Назад», которая снимает фокус и сворачивает
  поиск (Guidelines → Behavior; `SampleLeadingIcon` в `SearchBarSamples.kt`). Можно добавить
  кнопку очистки «×».
- Результаты оформляются как list items. Группы разделяются **gaps**, не разделителями
  (Guidelines → Gaps).

## Размеры, формы, цвета

| Элемент | Значение | Источник |
|---|---|---|
| Строка: высота, форма | 56dp, `corner.full` | `md.comp.search-bar.container.height/shape`, `SearchBarTokens` |
| Строка: ширина | min 360dp, max 720dp | Specs → Measurements; `SearchBarMinWidth/MaxWidth` |
| Строка: внешние поля (contained) | без фокуса 24dp, в фокусе 12dp | `md.comp.search-bar.contained.leading-margin` = space300; `md.comp.search-view.contained.leading-margin` = space150; Guidelines → Search bar container |
| Внутренний отступ без кнопок | 16dp | `md.comp.search-bar.contained.no-actions.leading-space` = space200 |
| Отступ иконка–текст (от зоны нажатия) | 4dp | `md.comp.search-bar.contained.icon-label.gap` = space50 |
| Строка: цвет | `surfaceContainerHigh` | `SearchBarTokens.ContainerColor` |
| Подложка full-screen contained | `surfaceContainerLow` | `md.comp.search-view.contained.background.color`; `SearchBarDefaults.fullScreenContainedSearchBarColor` |
| Docked contained: зазор строка–результаты / форма результатов | 2dp / `corner.medium` (12dp) | `md.comp.search-view.contained.docked.bar-results.gap`, `…docked.results.shape`; `dockedDropdownGapSize`, `dockedDropdownShape` |
| Текст ввода / подсказка | `bodyLarge`, `onSurface` / `onSurfaceVariant` | `SearchBarTokens.InputTextFont/InputTextColor/SupportingTextColor` |
| Ведущая / замыкающая иконка | `onSurface` / `onSurfaceVariant`, 24dp | `LeadingIconColor` / `TrailingIconColor` |
| Divided: шапка full-screen, разделитель | 72dp, `outline` | `SearchViewTokens.FullScreenHeaderContainerHeight`, `DividerColor` |
| Тень | 0 | `SearchBarDefaults.TonalElevation/ShadowElevation` = Level0 |

Замечания по источникам:
- В таблице токенов на сайте `container.elevation` = level3, а Compose по умолчанию даёт 0, и
  раздел «Differences from M2» говорит «no shadow by default». Берём 0.
- Поле ввода в раскрытом contained-поиске Compose отодвигает от краёв на
  `FullScreenExpandedHorizontalPadding` = 8dp (плюс системные отступы), а токен и гайд говорят
  12dp. Берём 12dp по токену.
- Не ставить строку `surfaceContainerHigh` на фон `surfaceContainer`: контраст слишком мал
  (Guidelines → Container color, CAUTION).

## Состояния и движение
Compose, contained full-screen (`SearchBar.kt`):
- Раскрытие и сворачивание — пружина `MotionSchemeKeyTokens.FastSpatial` в обе стороны
  (`rememberContainedSearchBarState`). Токен сайта `md.comp.search-bar.contained.motion.spring`
  = `md.sys.motion.spring.fast.spatial`.
- В `FullScreenSearchBarLayout` при `isContained = true`:
  - подложка на весь экран, прозрачность = `state.progress`;
  - поле ввода сохраняет форму таблетки (`clip(collapsedShape)`); ширина переходит от свёрнутой к
    ширине экрана минус боковые поля; центр по X сдвигается к центру экрана;
  - сверху поле опускается на `insets.top + 4dp` (`AppBarWithSearchVerticalPadding`), снизу до
    контента 8dp (`SearchBarVerticalPadding`).
- Контент появляется отдельно (`contentProgress`): fade-in 100 мс (`DurationShort2`) с
  задержкой 50 мс (`DurationShort1`), `EasingStandardAccelerate`; fade-out 100 мс,
  `EasingStandardDecelerate` (`AnimationForContentFadeInSpec/OutSpec`).
- Иконки app bar вокруг строки при раскрытии уезжают за край: вход `motionScheme.fastSpatialSpec()`,
  выход `tween(150)` (`SampleNavigationIcon`, `SampleActions`). В MDC это `startSiblingViewId` и
  `endSiblingViewId`.
- Цвет контейнера поля при фокусе меняется с `FastEffects` (`InputField`).
- Со scroll behavior цвет app bar анимируется `DefaultEffects` (`AppBarWithSearchImpl`),
  доводка прокрутки — `DefaultEffects` (`enterAlwaysSearchBarScrollBehavior`).
- Для сравнения: `rememberSearchBarState` (divided) раскрывается `SlowSpatial` и сворачивается
  `DefaultSpatial`; `rememberSearchBarWithGapState` (docked) — `DefaultSpatial` / `FastSpatial`.
- Predictive back: поиск уменьшается до 90% (`SearchBarPredictiveBackMinScale`), отходит от краёв
  на 8dp и смещается по Y максимум на 24dp.
- Сворачивание скрывает клавиатуру (`ExpandedFullScreenSearchBarImpl`), при раскрытии поле сразу
  получает фокус.
- Нажатие Enter вызывает `onSearch` (`ImeAction.Search`). Введённый текст после поиска остаётся
  виден (Guidelines → Search results).

## Доступность
- Доступное имя поля = текст подсказки. Роль на Android: Text field. Сама подсказка из дерева
  доступности убрана (`Modifier.clearAndSetSemantics {}` в примерах), в Compose у поля
  `contentDescription` = «Search».
- Появление подсказок и результатов озвучивается. Compose при раскрытии ставит
  `stateDescription` = `Strings.SuggestionsAvailable`.
- Нужен явный признак, что идёт поиск: иконка поиска или заголовок «Результаты» (Guidelines →
  Search results).
- Клавиатура: Tab между элементами, Space/Enter активирует поле, стрелки двигают по результатам.
  В Compose стрелка вниз из поля переводит фокус в список.
- Кнопки «Назад» и «Очистить» подписываются как icon buttons (тултип и описание).

## В приложении
- Где используется: `lib/features/schedule/schedule_screen.dart` → `_ScheduleSearchBar`
  (`SearchAnchor.bar` в `SliverToBoxAdapter` под medium flexible app bar, `FilterChip` «предмет /
  преподаватель / аудитория» и `ListTile`-результаты в `suggestionsBuilder`, `_SearchHint`).
  Тема: `searchBarTheme` и `searchViewTheme` в `lib/app.dart`.

### Реализация во Flutter

Виджет `lib/widgets/m3_search.dart` готов; экран расписания на него ещё не переведён, поэтому
«Где используется» и расхождения ниже описывают текущий `SearchAnchor.bar`.

- API:
  - `M3SearchBar({required String hintText, required Widget Function(BuildContext, String query) contentBuilder, TextEditingController? controller, ValueChanged<String>? onSearch})`;
  - изнутри контента `M3SearchScope.of(context)`: `query`, `close()`, `setQuery(String)`,
    `announce(String)` (→ `SemanticsService.sendAnnouncement`);
  - `contentBuilder` — обычный builder: вызывается при каждом изменении запроса и при
    перестройке `M3SearchBar`, `ConsumerWidget` внутри обновляются сами (расхождение 7 уходит).
- Точно по Compose:
  - свёрнутая строка: 56dp, `surfaceContainerHigh`, `StadiumBorder`, без тени, ширина 360..720dp;
    иконка поиска `onSurface` в 16dp от края, текст в 52dp (зона 48dp + `SearchBarIconOffsetX`);
    подсказка `bodyLarge` `onSurfaceVariant`, запрос `onSurface`; введённый текст остаётся в
    строке после закрытия;
  - открытый поиск — свой `PopupRoute` в корневом навигаторе (аналог `BasicEdgeToEdgeDialog`),
    раскладка — порт `FullScreenSearchBarLayout(isContained = true)`: подложка
    `surfaceContainerLow` с прозрачностью `progress`; ширина и центр поля — по неограниченному
    прогрессу (перелёт FastSpatial виден), верх и прозрачность — по ограниченному; поле на
    `inset.top + 4dp`, контент на 8dp ниже; скругление подложки `28dp × max(1 − progress, back)`;
  - пружина `FastSpatial` в обе стороны с сохранением скорости; контент — пауза 50 мс, затем
    100 мс `Easing.standardAccelerate`; скрытие 100 мс `Easing.standardDecelerate`;
  - поиск убирается, как только прогресс ≤ 0.02 (`SearchBarState.currentValue`); пока он
    сворачивается, свёрнутая строка скрыта (`isVisible` в `AppBarWithSearch`);
  - ведущая иконка сразу становится `IconButton` «Назад» (`SampleLeadingIcon`), «Очистить» — пока
    запрос не пуст; фокус при открытии, закрытие снимает фокус и прячет клавиатуру;
    `TextInputAction.search`;
  - системный «назад» — через `PopScope`; `Navigator.pop` из контента тоже сворачивает с анимацией;
  - predictive back — `WidgetsBindingObserver.handleStartBackGesture` / `Update…` / `Commit…` /
    `Cancel…`: подложка до 90%, 8dp от края со стороны жеста (не дальше свёрнутой строки), сдвиг
    по Y до 24dp, кривая `PredictiveBack.transform` = `Cubic(0.1, 0.1, 0, 1)`; после commit
    геометрия жеста сохраняется на время сворачивания. Проверено тестом через канал
    `flutter/backgesture`;
  - доступность: свёрнутая строка — `Semantics(textField, label: подсказка, value: запрос)`, у поля
    в открытом поиске подсказка — `hintText`.
- Отступления:
  1. Поля строки в фокусе 12dp по токену `md.comp.search-view.contained.leading-margin`; Compose
     берёт 8dp (`FullScreenExpandedHorizontalPadding`).
  2. Compose ставит полю `contentDescription` «Строка поиска» и `stateDescription` «Подсказки
     показаны ниже». Здесь доступное имя — подсказка (Search → Accessibility), а появление
     результатов озвучивает контент через `M3SearchScope.announce`: гайд этого требует, Compose
     сам не делает.
  3. Прямоугольник свёрнутой строки обновляется на тике анимации, а не в раскладке, как
     `collapsedBounds`: Flutter не даёт читать чужой размер во время layout. Если строка под
     поиском сдвинется, отставание — один кадр.
  4. Кнопка «Поиск» на клавиатуре только прячет клавиатуру и вызывает `onSearch`; в примере Compose
     она сворачивает поиск, но у нас результаты живут в открытом поиске.
  5. Predictive back не дойдёт до приложения, пока в `android/app/src/main/AndroidManifest.xml` нет
     `android:enableOnBackInvokedCallback="true"`: без флага Android шлёт обычный «назад», и поиск
     сворачивается без жестовой анимации.
  6. Поля свёрнутой строки 24dp задаёт экран, в который её вставляют.

### Расхождения
1. **Стиль открытого поиска.** Сейчас: Flutter `SearchView` в стиле divided. Шапка 72dp с
   прозрачной строкой, разделитель `outline` от Flutter и ещё один свой
   `Divider(indent: 18, endIndent: 18)` после чипов, фон `surfaceContainerHigh`
   (`searchViewTheme.backgroundColor`), морфинг прямоугольника 600 мс `easeInOutCubicEmphasized`.
   Должно быть: contained full-screen. Строка-таблетка `surfaceContainerHigh` 56dp остаётся
   видимой и расширяется до полей 12dp, подложка `surfaceContainerLow` проявляется, разделителей
   нет, пружина `FastSpatial`, контент проявляется с задержкой 50 мс. Источник: Specs →
   Configurations; `ExpandedFullScreenContainedSearchBar`, `rememberContainedSearchBarState`.
2. **Ведущая иконка в фокусе.** Сейчас Flutter подставляет `BackButton` в шапку view; иконка
   поиска в строке исчезает вместе со строкой. Должно быть: в той же таблетке иконка поиска
   сменяется кнопкой «Назад» с тултипом. Источник: `SampleLeadingIcon`.
3. **Подсказка слишком длинная** и обрезается: «Поиск предмета, препода, аудито…» (скриншот
   `docs/screenshots/1-schedule-light.png`). Гайд: короткое описание вроде «Search your
   messages». Поля «предмет / преподаватель / аудитория» уже выбираются чипами, поэтому подсказку
   можно сократить до «Поиск по расписанию».
4. **Боковые поля строки** 22dp (`EdgeInsets.fromLTRB(22, 6, 22, 10)`), по токену 24dp.
5. **`searchBarTheme.constraints` = `BoxConstraints(minHeight: 56)`** убирает min 360 и max
   720dp. На телефоне это незаметно, на планшете строка растянется шире 720dp.
6. **Результаты.** Сейчас `ListTile` с формой `largeIncreased` (20dp) и группы через `Divider`.
   Должно быть: list items по спеке lists (в примере Compose `ListItem` с прозрачным контейнером,
   поля 16/4dp), группы через gaps. Форма 20dp у строки результата в источниках не найдена.
7. **Фильтр-чипы в `suggestionsBuilder` не обновляются при нажатии (по коду; на устройстве
   проверить).** `_ViewContent` в `search_anchor.dart` вызывает `suggestionsBuilder` только при
   изменении текста контроллера (`_controller.addListener(updateSuggestions)`) и в
   `didChangeDependencies`. Нажатие на чип меняет `searchFieldProvider`, но список не
   перестраивается, пока не изменится текст. К тому же `ref.watch` вызывается вне `build`.
8. **Озвучивание результатов.** Сейчас нет. Должно быть: объявлять появление результатов
   (`SemanticsService.sendAnnouncement` или live region) и добавить видимый заголовок
   результатов.
9. Predictive back для открытого поиска отсутствует (спека: поиск отрывается от краёв и
   уменьшается по жесту).

### Что сделать во Flutter
`SearchAnchor` contained style не поддерживает, поэтому паттерн нужно портировать с Compose.
Размещение (строка под заголовком экрана) менять не нужно, `AppBarWithSearch` здесь не нужен:
поиск не глобальный.
1. Виджет `M3SearchBar` (`lib/widgets/`): `Material` цвета `surfaceContainerHigh`,
   `StadiumBorder`, высота 56, иконка поиска 24dp `onSurface`, отступ 16dp, подсказка
   `bodyLarge` `onSurfaceVariant`. Поля от краёв экрана 24dp. Прямоугольник строки запоминается
   через `GlobalKey`.
2. Открытие — свой `PopupRoute` (`opaque: false`, без barrier) или `OverlayEntry`:
   - `AnimationController` с `animateWith(AppMotion.fastSpatial.simulate(...))` в обе стороны
     (`progress`, без ограничения 0..1 из-за перелёта; для прозрачности и цвета брать
     `clamp(0, 1)`);
   - подложка: `ColoredBox(surfaceContainerLow)` с `Opacity(progress)`;
   - строка: ширина `lerp(collapsedWidth, screenWidth - 2*12, progress)`, центр X
     `lerp(collapsedCenterX, screenCenterX, progress)`, верх
     `lerp(collapsedTop, padding.top + 4, progress)`; форма всегда таблетка, цвет
     `surfaceContainerHigh`; внутри настоящий `TextField` (`autofocus`,
     `textInputAction: TextInputAction.search`);
   - иконка: `AnimatedSwitcher` поиск ↔ `IconButton(Symbols.arrow_back, tooltip: 'Назад')`;
     справа при непустом вводе `IconButton(Symbols.close, tooltip: 'Очистить')`;
   - контент ниже строки с отступом 8dp: отдельный контроллер прозрачности, 100 мс с задержкой
     50 мс, `Easing.standardAccelerate` на вход и 100 мс `Easing.standardDecelerate` на выход;
   - закрытие: `FocusScope.unfocus()`, затем обратная пружина `fastSpatial`, `pop`;
     `PopScope` + `onPopInvokedWithResult` для кнопки «Назад». Predictive back — через
     `WidgetsBindingObserver.handleStartBackGesture/handleUpdateBackGestureProgress`
     (`widgets/binding.dart`, `PredictiveBackEvent`; так сделан
     `predictive_back_page_transitions_builder.dart`), с масштабом 0.9 и полями 8dp по
     `SearchBar.kt`.
3. Контент открытого поиска — обычный виджет с Riverpod, а не `suggestionsBuilder`. Сверху ряд
   `FilterChip`, ниже результаты как list items, группы через gap. Чипы и список перестраиваются
   от `searchFieldProvider`, то есть пункт 7 исправляется сам.
4. Убрать `searchViewTheme` и лишние `Divider`; строке вернуть min 360 / max 720
   (`ConstrainedBox`).
5. Сократить подсказку, при появлении результатов объявлять «Найдено N».

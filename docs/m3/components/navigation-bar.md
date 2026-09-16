# Панель навигации (Navigation bar)

Статус в приложении: ⚠️ частично

Размеры и цвета совпадают с flexible navigation bar из M3 Expressive: 64dp, индикатор 56×32.
Индикатор 56dp получен обходным путём через `NavigationIndicatorBorder`. Не совпадает движение
индикатора: во Flutter это M3 baseline (масштаб + кривая), а в Expressive — пружина. Панель не
растёт при крупном шрифте. Повторное нажатие на активный пункт ничего не делает.

## Источники
- Guidelines / Specs / Accessibility: https://m3.material.io/components/navigation-bar/guidelines,
  https://m3.material.io/components/navigation-bar/specs,
  https://m3.material.io/components/navigation-bar/accessibility
  (выгрузка: `.m3-guidelines/components__navigation-bar.md`)
- Compose API: https://developer.android.com/reference/kotlin/androidx/compose/material3/package-summary —
  `ShortNavigationBar(modifier, containerColor, contentColor, windowInsets, arrangement, content)`,
  `ShortNavigationBarItem(selected, onClick, icon, label, modifier, enabled, iconPosition, colors, interactionSource)`,
  `ShortNavigationBarArrangement.EqualWeight` / `.Centered`, `NavigationItemIconPosition.Top` / `.Start`,
  `ShortNavigationBarDefaults`, `ShortNavigationBarItemDefaults.colors()`.
  Baseline `NavigationBar` / `NavigationBarItem` (80dp) не рекомендуется.
- Compose исходник: `ShortNavigationBar.kt` (`ShortNavigationBar`, `EqualWeightContentMeasurePolicy`,
  `CenteredContentMeasurePolicy`, константы `TopIconItemVerticalPadding`, `TopIconIndicatorToLabelPadding`),
  `NavigationItem.kt` (`NavigationItem`, `TopIconOrIconOnlyMeasurePolicy`, `animateIndicatorProgressAsState`,
  `Indicator`, `IndicatorRipple`, `StyledLabel`), токены `tokens/NavigationBarTokens.kt`,
  `tokens/NavigationBarVerticalItemTokens.kt`, `tokens/NavigationBarHorizontalItemTokens.kt`,
  пример `samples/NavigationBarSamples.kt` (`ShortNavigationBarSample`,
  `ShortNavigationBarWithHorizontalItemsSample`)
- MDC: https://github.com/material-components/material-components-android/blob/master/docs/components/BottomNavigation.md
  (раздел «M3 Expressive styles», стиль `Widget.Material3Expressive.BottomNavigationView`)
- Flutter: `NavigationBar` + `NavigationDestination` (`packages/flutter/lib/src/material/navigation_bar.dart`).
  Есть: высота, цвета, форма индикатора, `labelBehavior`, `animationDuration`, ripple только по индикатору
  (`_IndicatorInkWell`), роли `SemanticsRole.tabBar` / `tab`. Нет:
  - ширины индикатора: рамка `_kIndicatorWidth` = 64 задана жёстко;
  - горизонтальных пунктов (иконка слева от подписи);
  - пружинной анимации: в `NavigationIndicator` зашиты scaleX 0.4→1 по `Curves.easeInOutCubicEmphasized`
    и отдельный fade 100 мс;
  - роста высоты при крупном шрифте: `height` фиксирована, масштаб подписи ограничен
    `_kMaxLabelTextScaleFactor` = 1.3;
  - отдельного обработчика повторного выбора.

## Когда использовать
- От 3 до 5 равнозначных разделов верхнего уровня, в compact и medium окнах. Панель всегда внизу,
  на всю ширину окна (Guidelines → Usage, Anatomy → Container).
- Пунктов не меньше трёх (для двух берут tabs) и не больше пяти. Подпись обязательна: 1–2 слова,
  без переноса, усечения и уменьшения шрифта (Guidelines → Label text, DON'T).
- Не для отдельных задач («просмотр одного письма»). Не показывать одновременно с toolbar
  (toolbars → Toolbars & navigation bars).
- Baseline navigation bar (80dp) не рекомендуется. Его заменяет **flexible** navigation bar,
  в Compose это `ShortNavigationBar` (Overview → M3 Expressive update).
- Свайп между разделами не поддерживается (Behavior → Don't swipe between destinations).

## Варианты и анатомия
- Flexible navigation bar:
  - **vertical items**: иконка над подписью, для compact окон. Compose:
    `NavigationItemIconPosition.Top`, `ShortNavigationBarArrangement.EqualWeight`;
  - **horizontal items**: иконка слева от подписи внутри индикатора, для medium окон. Compose:
    `.Start` и `.Centered`. В MDC — при ширине окна от 600dp.
- Анатомия: контейнер, иконка, подпись, active indicator, small и large badge (необязательные).
- Активный пункт — filled-иконка, неактивные — outlined. Если у иконки нет filled-версии,
  активную делают semibold (Anatomy → Icons).

## Размеры, формы, цвета
| Элемент | Значение | Источник |
|---|---|---|
| Высота контейнера | 64dp, минимальная: растёт вместе с содержимым | `NavigationBarTokens.ContainerHeight`, `md.comp.nav-bar.container.height`; `ShortNavigationBar` → `defaultMinSize(minHeight)` |
| Контейнер | `surfaceContainer`, углы `corner.none`, без тени | `NavigationBarTokens.ContainerColor`, `NavShape`; Overview → Differences from M2: «No shadow» |
| Индикатор (vertical) | 56×32dp, `corner.full`, `secondaryContainer` | `NavigationBarVerticalItemTokens.ActiveIndicatorWidth` / `Height`, `NavigationBarTokens.ItemActiveIndicatorShape` / `Color` |
| Индикатор (horizontal) | высота 40dp, по 16dp слева и справа, 4dp между иконкой и подписью | `NavigationBarHorizontalItemTokens`, `NavigationBarTokens.ItemActiveIndicatorIconLabelSpace` |
| Иконка | 24dp; активная `onSecondaryContainer`, неактивная `onSurfaceVariant` | `NavigationBarVerticalItemTokens.IconSize`, `ItemActiveIconColor` / `ItemInactiveIconColor` |
| Подпись | `labelMedium`; активная `secondary` (у horizontal в Compose — `onSecondaryContainer`), неактивная `onSurfaceVariant` | `NavigationBarTokens.LabelTextFont`, `ItemActiveLabelTextColor`; `ShortNavigationBarItemDefaults.colors` |
| Отступы пункта (vertical) | 6dp сверху и снизу, 4dp от индикатора до подписи | `NavigationBarVerticalItemTokens.ContainerBetweenSpace`, `TopIconIndicatorToLabelPadding` |
| State layer | hover 8%, focus и pressed 10%, цвет `onSecondaryContainer` | Specs → States; `md.comp.nav-bar.item.*.state-layer.color` |
| Ripple | только в пределах индикатора | `NavigationItem.kt` → `IndicatorRipple` + `MappedInteractionSource` |

Про жирность активной подписи источники расходятся:
- Accessibility → Visual indicators: «filled icon with a bold label». Токен
  `md.comp.navigation-bar.active.label-text.weight` = `label-medium.weight.prominent` относится
  к baseline-набору.
- MDC (M3 Expressive styles): «Label text is no longer bolded when selected».
- Compose `ShortNavigationBarItem` берёт `NavigationBarTokens.LabelTextFont` для обоих состояний.

Для flexible navigation bar вес подписи не меняется.

## Состояния и движение
- **Индикатор выбора.** `animateIndicatorProgressAsState(selected)` → `animateFloatAsState(...,
  MotionSchemeKeyTokens.DefaultSpatial)` (`NavigationItem.kt`). Прогресс управляет двумя свойствами:
  - шириной: `animatedIndicatorWidth = totalIndicatorWidth * progress` в
    `TopIconOrIconOnlyMeasurePolicy`. Индикатор растёт от центра иконки только по оси X, высота
    32dp постоянна;
  - прозрачностью: `Indicator` → `graphicsLayer { alpha = progress }`.

  DefaultSpatial — пружина со stiffness 380 и damping 0.8, поэтому ширина слегка перелетает.
  Снятие выбора идёт той же пружиной назад. Guidelines → Behavior → Selection: индикатор
  «expands from the center of the icon», анимация «only on one axis».
- **Иконка** в Compose меняется без анимации. Цвет подписи у vertical-пунктов тоже не
  анимируется: `StyledLabel(animateColor = false)`. У `AnimatedNavigationItem` (wide rail) цвет
  анимируется с `DefaultEffects`.
- **Ripple** рисуется отдельным слоем, потому что анимация ширины индикатора мешает таймингу
  ripple (комментарий в `NavigationItemLayout`).
- **Смена раздела** — паттерн top level, то есть fade through (styles/motion/transitions →
  Top level; MDC `docs/theming/Motion.md` → Fade through).
- **Повторное нажатие** на активный пункт возвращает экран к началу прокрутки (Behavior → Navigation).
- **Состояние раздела** можно сохранять (preserve) или сбрасывать (reset). Приложениям с частым
  переключением рекомендуется сохранять.
- **Скрытие при прокрутке** допустимо: прокрутка вниз прячет панель, вверх — показывает. При
  включённом screen reader панель скрывать нельзя (Behavior → Scrolling). Готового поведения у
  `ShortNavigationBar` в Compose нет. Ближайший аналог в исходниках —
  `BottomAppBarDefaults.exitAlwaysScrollBehavior` с доводкой `MotionSchemeKeyTokens.FastSpatial`
  (`AppBar.kt`, `BottomAppBarDefaults.snapAnimationSpec`).
- **Flutter сейчас:** индикатор масштабируется по X от 0.4 до 1 по `easeInOutCubicEmphasized` за
  `animationDuration` (по умолчанию 500 мс), плюс отдельный fade 100 мс. При снятии выбора
  индикатор гаснет за 100 мс.

## Доступность
- Активная и неактивные иконки — контраст не ниже 3:1 с контейнером.
- При крупном шрифте панель растёт по вертикали, отступы сохраняются. До масштаба 2× подпись
  видна целиком, перенос на вторую строку допустим. После 2× подпись можно усекать (Accessibility →
  Text scaling and truncation). В Compose `EqualWeightContentMeasurePolicy` берёт высоту по
  `maxIntrinsicHeight` пунктов.
- Роль пункта: в Compose `selectable(role = Role.Tab)` внутри `selectableGroup()`, во Flutter —
  `SemanticsRole.tab`. Метка доступности совпадает с подписью. Если подпись неоднозначна,
  метку делают подробнее.
- Клавиатура: Tab переходит между пунктами, Space и Enter выбирают. Первый фокус — на первом пункте.
- Минимальная зона нажатия 48dp (`LocalMinimumInteractiveComponentSize`).

## В приложении
- Где используется:
  - `lib/features/home/home_shell.dart` — `HomeShell`: `NavigationBar` + `NavigationDestination`,
    переключение разделов через `FadeThroughStack`;
  - `lib/app.dart` — `buildTheme` → `navigationBarTheme`;
  - `lib/theme/app_shapes.dart` — `NavigationIndicatorBorder`, пилюля 56dp внутри рамки 64dp.
- Уже соответствует:
  - 4 раздела, подписи из одного слова;
  - высота 64dp, контейнер `surfaceContainer`;
  - индикатор 56×32, `secondaryContainer`;
  - иконки 24dp `onSecondaryContainer` / `onSurfaceVariant`, у активного пункта filled-иконка
    (`fill: 1`);
  - подпись `labelMedium`, активная — `secondary`, вес не меняется;
  - смена разделов через fade through, состояние разделов сохраняется;
  - ripple ограничен индикатором.
- Расхождения:
  1. **Анимация индикатора.** Сейчас дефолт Flutter: scaleX 0.4→1, `easeInOutCubicEmphasized`,
     500 мс + fade 100 мс. Должно быть: ширина 0→56dp и прозрачность 0→1 одной пружиной
     `DefaultSpatial` (380 / 0.8), назад той же пружиной. Источник: `NavigationItem.kt` →
     `animateIndicatorProgressAsState`, `Indicator`, `TopIconOrIconOnlyMeasurePolicy`; Guidelines →
     Behavior → Selection.
  2. **Повторное нажатие на активный раздел.** Сейчас ничего не происходит (`setState` с тем же
     индексом). Должно: прокрутить раздел к началу. Источник: Guidelines → Behavior → Navigation.
  3. **Крупный шрифт.** Сейчас высота фиксирована 64dp, подпись ограничена 1.3×. Должно: панель
     растёт, подпись видна целиком до 2×, перенос допустим. Источник: Accessibility → Text scaling
     and truncation; `ShortNavigationBar.kt` → `EqualWeightContentMeasurePolicy`.
  4. **Medium окно** (например, телефон в ландшафте шире 600dp). Сейчас пункты всегда vertical.
     Должно: horizontal items (иконка слева, индикатор высотой 40dp), пункты по центру. Источник:
     Specs → Configurations; MDC «greater than or equal to 600dp»;
     `ShortNavigationBarWithHorizontalItemsSample`. Приоритет низкий: приложение для телефона.
- Что сделать во Flutter. Стандартный `NavigationBar` не даёт ни пружины, ни роста высоты,
  поэтому нужен порт `ShortNavigationBar` + `NavigationItem` своим виджетом (например,
  `lib/widgets/m3_navigation_bar.dart`):
  1. Контейнер: `Material(color: surfaceContainer)` → `SafeArea(top: false)` →
     `ConstrainedBox(minHeight: 64)` → `IntrinsicHeight` → `Row` из `Expanded` пунктов. Это
     EqualWeight: у всех пунктов одинаковые ширина и высота. Обернуть в
     `Semantics(role: SemanticsRole.tabBar)`.
  2. Пункт: `Semantics(role: SemanticsRole.tab, selected: ...)`, нажатие на всю площадь пункта,
     минимум 48×48. Ripple — только в прямоугольнике индикатора 56×32 с формой `StadiumBorder`:
     например, `InkResponse(containedInkWell: true, customBorder: StadiumBorder())` поверх индикатора.
  3. Индикатор: `AnimationController.unbounded` в `State` пункта. При смене `selected` вызывать
     `controller.animateWith(AppMotion.defaultSpatial.simulate(from: controller.value, to: selected ? 1 : 0, velocity: controller.velocity))`.
     Ширина = `56 * value.clamp(0, double.infinity)`, прозрачность = `value.clamp(0, 1)`, высота 32,
     центр совпадает с центром иконки. Так индикатор сохраняет перелёт, как в Compose.
  4. Вертикальная раскладка: 6dp сверху, индикатор 32dp с иконкой 24dp в центре, 4dp, подпись,
     6dp снизу.
  5. Иконка: `Icon(fill: selected ? 1 : 0)` без анимации, цвет `onSecondaryContainer` /
     `onSurfaceVariant`.
  6. Подпись: `labelMedium`, цвет `secondary` / `onSurfaceVariant`,
     `MediaQuery.withClampedTextScaling(maxScaleFactor: 2)`, перенос разрешён.
  7. Добавить колбэк `onReselected(int)`. В `HomeShell` у каждого раздела хранить
     `ScrollController` и при повторном выборе прокручивать к 0. Длительность и кривую прокрутки
     источники не задают: решение зафиксировать в README «Сознательные отступления».
  8. После перехода на свой виджет удалить `navigationBarTheme` и `NavigationIndicatorBorder`.

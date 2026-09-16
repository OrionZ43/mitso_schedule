# Вкладки (Tabs)

Статус в приложении: — не используется

## Источники
- Guidelines / Specs / Accessibility: https://m3.material.io/components/tabs/guidelines,
  https://m3.material.io/components/tabs/specs, https://m3.material.io/components/tabs/accessibility
  (выгрузка: `.m3-guidelines/components__tabs.md`; в выгрузке есть таблица размеров, но нет значений токенов)
- Compose API: https://developer.android.com/reference/kotlin/androidx/compose/material3/package-summary —
  `PrimaryTabRow`, `SecondaryTabRow`, `PrimaryScrollableTabRow`, `SecondaryScrollableTabRow`, `Tab`,
  `LeadingIconTab`, `TabRowDefaults.PrimaryIndicator` / `SecondaryIndicator`, `Modifier.tabIndicatorOffset`,
  `TabRowDefaults.ScrollableTabRowEdgeStartPadding` (`TabRow` и `ScrollableTabRow` устарели)
- Compose исходник: `TabRow.kt` (анимация индикатора `tabIndicatorAnimationSpec` и прокрутки
  `scrollAnimationSpec` = `MotionSchemeKeyTokens.DefaultSpatial`), `Tab.kt` (`TabTransition`: цвет содержимого —
  появление `DefaultEffects`, исчезновение `FastEffects`), токены `tokens/PrimaryNavigationTabTokens.kt`,
  `tokens/SecondaryNavigationTabTokens.kt`, пример `samples/TabSamples.kt`
- MDC: https://github.com/material-components/material-components-android/blob/master/docs/components/Tabs.md
- Flutter: `TabBar`, `TabBar.secondary`, `Tab`, `TabController`, `TabBarView`
  (`packages/flutter/lib/src/material/tabs.dart`). Анимация индикатора — `TabIndicatorAnimation.linear` /
  `.elastic` за `kTabScrollDuration` = 300 мс. Пружин `MotionScheme` нет.

## Когда использовать
- Группы связанного контента одного уровня иерархии. **Primary** — под app bar, основные разделы
  страницы. **Secondary** — внутри контента, второй уровень, всегда под primary.
- Не для последовательного контента, который читают по порядку (DON'T: «Chapter 1, 2, 3»).
- Не больше четырёх фиксированных вкладок. Если не помещаются — прокручиваемые, первая с отступом
  52dp от края.
- Свайп по контенту переключает фиксированные вкладки, поэтому свайпаемых элементов в контенте
  лучше избегать.
- Для 2 разделов верхнего уровня вместо navigation bar берут tabs (navigation-bar → DON'T).

## Варианты и анатомия
- Primary (иконка и/или текст, индикатор под содержимым). Secondary (только текст, тонкий
  индикатор на всю ширину вкладки).
- Анатомия: контейнер, иконка (необязательна), badge (необязательен), подпись, разделитель, индикатор.

## Размеры, формы, цвета
| Элемент | Значение | Источник |
|---|---|---|
| Высота | 48dp (текст), 64dp (иконка и текст) | Specs → Measurements; `PrimaryNavigationTabTokens.ContainerHeight` / `IconAndLabelTextContainerHeight` |
| Контейнер | `surface`, elevation 0 | `PrimaryNavigationTabTokens.ContainerColor` |
| Индикатор primary | 3dp, `primary`, углы 3/3/0/0, отступ 2dp с каждой стороны, минимальная длина 24dp | Specs → Measurements; `ActiveIndicatorHeight` / `ActiveIndicatorShape` |
| Индикатор secondary | 2dp, `primary` | Specs → Measurements |
| Подпись | `titleSmall`; primary: активная `primary`, неактивная `onSurfaceVariant`; secondary: активная `onSurface` | `PrimaryNavigationTabTokens.LabelTextFont` / `ActiveLabelTextColor`; `SecondaryNavigationTabTokens.ActiveLabelTextColor` |
| Иконка | 24dp, цвета как у подписи | `IconSize` |
| Разделитель | 1dp; в Specs роль `outlineVariant`, в `SecondaryNavigationTabTokens.DividerColor` — `surfaceVariant` | Specs → Color; токены Compose |
| Отступы | иконка и текст в строку — 8dp, текст и badge — 4dp | Specs → Measurements |

## Состояния и движение
- Индикатор переезжает и меняет ширину пружиной `DefaultSpatial`. Прокрутка ряда к выбранной
  вкладке — тоже `DefaultSpatial` (`TabRow.kt`).
- Цвет содержимого вкладки при выборе появляется с `DefaultEffects`, при снятии выбора гаснет с
  `FastEffects` (`Tab.kt` → `TabTransition`).

## Доступность
- Стрелки или Tab перемещают фокус, Space или Enter выбирают. Бесконечно зацикленный ряд вкладок
  не рекомендуется. Плотность по умолчанию не уменьшать: зоны нажатия от 48dp.

## В приложении
- Не используется. Разделы верхнего уровня — navigation bar (4 пункта). Фильтр задач
  (`notes_screen.dart`) и подгруппа (`profile_screen.dart`) сделаны `ConnectedButtonGroup`, это выбор
  значения — см. `button-groups.md`. Смена дня в расписании — последовательный контент, для него
  tabs запрещены (DON'T «sequential content»).

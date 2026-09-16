# Навигационное меню (Navigation drawer)

Статус в приложении: — не используется

## Источники
- Guidelines / Specs / Accessibility: https://m3.material.io/components/navigation-drawer/guidelines,
  https://m3.material.io/components/navigation-drawer/specs, https://m3.material.io/components/navigation-drawer/accessibility
  (выгрузка: `.m3-guidelines/components__navigation-drawer.md`)
- Compose API: https://developer.android.com/reference/kotlin/androidx/compose/material3/package-summary —
  `ModalNavigationDrawer`, `DismissibleNavigationDrawer`, `PermanentNavigationDrawer`, `ModalDrawerSheet`,
  `NavigationDrawerItem`
- Compose исходник: `NavigationDrawer.kt` (`DrawerState`, `anchoredDraggableMotionSpec`), токены
  `tokens/NavigationDrawerTokens.kt`
- MDC: https://github.com/material-components/material-components-android/blob/master/docs/components/NavigationDrawer.md
- Flutter: `NavigationDrawer`, `NavigationDrawerDestination`, `Drawer`

## Когда использовать
- **В M3 Expressive navigation drawer больше не рекомендуется** (Overview, May 2025). Вместо него —
  expanded navigation rail, модальный или немодальный.
- Раньше: standard — в expanded окнах и шире, modal — в compact и medium.

## Размеры, формы, цвета (для справки)
| Элемент | Значение | Источник |
|---|---|---|
| Ширина | 360dp | `NavigationDrawerTokens.ContainerWidth` |
| Контейнер | standard `surface` level0; modal `surfaceContainerLow` level1; форма `corner.large` со стороны края | `NavigationDrawerTokens` |
| Индикатор | 336×56dp, `corner.full`, `secondaryContainer`; подпись `labelLarge` | `ActiveIndicatorWidth` / `Height`, `LabelTextFont` |

## В приложении
- Не используется и не должен появляться. Для навигации в compact окне — navigation bar. Если нужна
  расширенная навигация — модальный expanded rail (`navigation-rail.md`).

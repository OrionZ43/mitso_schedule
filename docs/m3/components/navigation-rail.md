# Навигационная рейка (Navigation rail)

Статус в приложении: — не используется

## Источники
- Guidelines / Specs / Accessibility: https://m3.material.io/components/navigation-rail/guidelines,
  https://m3.material.io/components/navigation-rail/specs, https://m3.material.io/components/navigation-rail/accessibility
  (выгрузка: `.m3-guidelines/components__navigation-rail.md`)
- Compose API: https://developer.android.com/reference/kotlin/androidx/compose/material3/package-summary —
  `WideNavigationRail`, `ModalWideNavigationRail`, `WideNavigationRailItem`, `rememberWideNavigationRailState`
  (baseline `NavigationRail` не рекомендуется)
- Compose исходник: `WideNavigationRail.kt` (ширина при раскрытии и сворачивании — `DefaultSpatial`, у модальной —
  `FastSpatial`), `NavigationItem.kt` (`AnimatedNavigationItem`: смена положения иконки — `DefaultSpatial`, цвет
  подписи — `DefaultEffects`), токены `tokens/NavigationRailCollapsedTokens.kt`, `NavigationRailExpandedTokens.kt`,
  `NavigationRailColorTokens.kt`, пример `samples/NavigationRailSamples.kt`
- MDC: https://github.com/material-components/material-components-android/blob/master/docs/components/NavigationRail.md
- Flutter: `NavigationRail` — только baseline. Collapsed и expanded Expressive-вариантов нет.

## Когда использовать
- Medium, expanded, large и extra-large окна. 3–7 разделов плюс необязательный FAB.
- **Collapsed** rail (96dp, narrow — 80dp) заменяет baseline rail. **Expanded** rail (220–360dp)
  заменяет navigation drawer. Модальный expanded rail можно открыть и в compact окне из кнопки
  меню app bar.
- **Compact окна — всегда navigation bar**, стандартную рейку не использовать (Adaptive design → Compact).

## Размеры, формы, цвета
| Элемент | Значение | Источник |
|---|---|---|
| Ширина collapsed | 96dp (narrow 80dp), `surface` | `NavigationRailCollapsedTokens` |
| Ширина expanded | 220–360dp, `surface`; модальная `surfaceContainer`, level2, `corner.large` | `NavigationRailExpandedTokens` |
| Индикатор | vertical 56×32dp, horizontal высота 56dp, `secondaryContainer` | `md.comp.nav-rail.item.*.active-indicator.*` |
| Цвета пункта | иконка `onSecondaryContainer` / `onSurfaceVariant`; подпись `secondary` / `onSurfaceVariant` | `NavigationRailColorTokens` |

## В приложении
- Не используется: приложение для телефона, в compact окнах по гайдлайну нужен navigation bar.
  Если понадобится поддержка планшетов (medium и шире), решение — medium окно: navigation bar с
  horizontal items или collapsed rail (navigation-bar → Adaptive design).

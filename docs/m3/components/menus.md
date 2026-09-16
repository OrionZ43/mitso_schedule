# Меню (Menus)

Статус в приложении: — не используется

В `lib/` нет `MenuAnchor`, `PopupMenuButton` и `DropdownMenu`.

## Источники
- Guidelines / Specs / Accessibility: https://m3.material.io/components/menus/guidelines,
  https://m3.material.io/components/menus/specs, https://m3.material.io/components/menus/accessibility
  (выгрузка: `.m3-guidelines/components__menus.md`)
- Compose API: https://developer.android.com/reference/kotlin/androidx/compose/material3/package-summary —
  `DropdownMenu`, `DropdownMenuPopup`, `DropdownMenuGroup`, `DropdownMenuItem` (перегрузки с
  `@ExperimentalMaterial3ExpressiveApi`), `MenuDefaults.groupShape/itemShape/itemShapes`,
  `ExposedDropdownMenuBox`
- Compose исходник: `Menu.kt`, `MenuDefaults.kt`, `ExposedDropdownMenu.kt`; токены
  `tokens/MenuTokens.kt` (baseline), `tokens/StandardMenuTokens.kt`, `tokens/VibrantMenuTokens.kt`;
  пример `samples/MenuSamples.kt` (`MenuSample`, `GroupedMenuSample`,
  `MenuWithCascadingMenusSample`)
- MDC: https://github.com/material-components/material-components-android/blob/master/docs/components/Menu.md
- Flutter: `MenuAnchor`, `PopupMenuButton`, `DropdownMenu` (`menu_anchor.dart`,
  `popup_menu.dart`, `dropdown_menu.dart`). Это только **baseline**: `_MenuDefaultsM3` — углы
  4dp, `surfaceContainer`, elevation 3. Vertical menus Expressive (скругления, группы с зазорами,
  vibrant-цвета, выбранное состояние формой) не поддерживаются.

## Когда использовать
Временный набор действий или вариантов, который открывается от кнопки, split button, поля или
контекстно. Для действий, которые нужны на экране постоянно, — toolbar. В M3 Expressive (ноябрь
2025) для новых дизайнов рекомендованы **vertical menus**; baseline остаётся, но без новых форм,
цветов и движения.

## Варианты и анатомия
Vertical menu: standard или grouped (группы разделены зазором), цвета standard или vibrant
(на основе tertiary), пункты с иконками, поясняющим текстом, выбранным состоянием, подменю.
Baseline menu: прямоугольник с углами 4dp.

## Размеры, формы, цвета (ключевое)

| Элемент | Vertical menu (Expressive) | Baseline |
|---|---|---|
| Контейнер | `md.comp.menus.container.shape` = `corner.large` | `md.comp.menu.container.shape` = `corner.extra-small`, `surfaceContainer`, level2 |
| Группа | форма `corner.small`, padding 2dp, зазор между группами 2dp | — |
| Пункт | высота 44dp, форма `corner.extra-small`, крайние пункты `corner.medium`, выбранный `corner.medium` | высота 48dp |
| Цвет standard | контейнер и пункт `surfaceContainerLow`, выбранный `tertiaryContainer` (`StandardMenuTokens`) | — |

Источник: `md.comp.menus.*` в выгрузке; `tokens/StandardMenuTokens.kt`.

## Состояния и движение
Compose (`Menu.kt`):
- `DropdownMenuContent` и `DropdownMenuPopupContent`: масштаб — `FastSpatial`, прозрачность —
  `FastEffects`;
- `DropdownMenuGroup`: морфинг формы группы при наведении — `FastSpatial`;
- `DropdownMenuItemContent`: изменение размера — `FastSpatial`, появление и исчезновение —
  `FastEffects`, морфинг формы выбранного пункта — `FastSpatial`, цвет контейнера — `FastEffects`.

## Доступность
- Выбранный пункт отличается формой и цветом (контраст 3:1). Рекомендован ещё один признак,
  например галочка.
- В пункт меню не добавлять кнопки, переключатели и другие отдельные действия. Зона нажатия
  ≥ 48dp.
- При открытии фокус на первом пункте. Закрытие: выбор пункта, Escape, нажатие снаружи,
  системная кнопка «Назад».

## В приложении
Не используется. Если понадобится, во Flutter придётся портировать vertical menu из
`Menu.kt`/`MenuDefaults.kt`: `MenuAnchor` с `MenuStyle(shape: RoundedRectangleBorder(16),
backgroundColor: surfaceContainerLow)` даёт только форму и цвет, а группы, формы пунктов и
движение нужно делать самим.

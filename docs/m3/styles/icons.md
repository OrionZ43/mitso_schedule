# Иконки (Icons / Material Symbols)

> Разделы «В приложении → Расхождения» описывают состояние на 16.09.2026, до порта компонентов. Исправлено с тех пор: эталонная статичная схема и системные роли Android 14+, emphasized-веса по токенам, opsz и grade иконок, state layer, цвета tooltip, чипов и app bar при прокрутке, scrim 32%, выдуманные альфы, размеры шрифта и радиусы (карточка пары и метки удалены), пустое состояние из `MaterialShapes`, пружины кнопок, листов и снекбара, смена дня — lateral. Остаётся: breakpoints и navigation rail для окон шире 600dp (приложение для телефона), часть отступов вне токенов в старом коде.

## Источники

- m3.material.io: https://m3.material.io/styles/icons (Overview, Designing icons, Applying icons) → `.m3-guidelines/styles__icons.md`
- Компоненты: `components__navigation-bar.md` (Guidelines, Accessibility → Visual indicators), `components__floating-action-button.md` (Accessibility), `components__icon-buttons.md` (toggle), `components__extended-fab.md` (размеры иконок)
- Compose Material3: `Icon.kt`; токены размеров в компонентах (`tokens/SmallIconButtonTokens.kt`, `tokens/FabBaselineTokens.kt`, `tokens/AppBarTokens.kt` — `IconSize` = 24dp)
- Flutter: `widgets/icon.dart` (`fill`, `weight`, `grade`, `opticalSize` → `FontVariation('FILL' | 'wght' | 'GRAD' | 'opsz')`), `widgets/icon_theme_data.dart`; пакет `material_symbols_icons` 4.2960.0 (`README.md`: шрифт 2.960, значения осей по умолчанию)

## Правила

### Стиль и оси

- Material Symbols — новый стандарт, три стиля: **outlined, rounded, sharp**. Один стиль на весь набор («Avoid mixing styles»). Legacy Material Icons не имеют вариативных осей.
- Четыре оси:
  - **Weight** 100–700; рекомендуемая толщина — 2dp, то есть regular **400**; для 24dp минимум 200; вес применять одинаково (не смешивать в одной навигации).
  - **Fill** 0–1; используется для передачи перехода состояния (невыбрано → выбрано).
  - **Grade** — тонкая регулировка толщины: **0** для тёмной иконки на светлом фоне, **−25** для светлой иконки на тёмном (компенсация «visual bleed»); положительный grade — для акцента, например активного состояния; grade иконок можно согласовать с grade текста.
  - **Optical size** 20–48dp — толщина штриха подстраивается под размер, чтобы иконка выглядела одинаково.

### Размеры и сетка

- Стандарт — **24×24dp** (живая область 20×20, поля 2dp). Дополнительные оптические размеры — **20dp** (desktop, плотные раскладки), **40dp и 48dp** (рядом с display/headline и на больших экранах). Компонентные токены задают и другие размеры (extended FAB medium — 28dp, large — 36dp; иконки в кнопках — по токенам кнопки).
- Радиус углов в символах — 2dp; иконки не наклонять, не поворачивать и не делать объёмными.
- Рядом с текстом: тот же размер и оптический вес, что у текста; базовая линия символа смещена вниз примерно на **11.5%** размера текста.

### Выбранное состояние

- Navigation bar: активный пункт — **заполненная иконка** (и «bold label»), неактивные — outlined с medium label; если заполненной версии нет — более толстый вес. DON'T: outlined-иконка у выбранного пункта. При выборе «the icon becomes filled and the active indicator expands from the center of the icon».
- Icon button (toggle): outlined — не выбрано, filled — выбрано.
- FAB: «Use a filled icon instead of an outlined icon».

### Доступность

- Иконке 24dp нужна зона нажатия **48dp**; при мыши/клавиатуре 20dp-иконке допустимо 40dp.
- Сложные и ключевые иконки меньше 20dp сопровождать подписью; навигационные пункты — всегда с подписью.

## Как устроено в Compose

- `Icon(imageVector | painter, contentDescription, tint)` — размер по умолчанию `SmallIconButtonTokens.IconSize` = 24dp (`Icon.kt`, `DefaultIconSizeModifier`); оси шрифта Compose не задаёт (Material Symbols в Compose обычно подключают векторами с уже выбранными fill/weight/grade/opsz).
- Размеры иконок берутся из токенов компонента (`IconSize`), цвет — из `LocalContentColor`.

## В приложении

### Как сейчас

- Пакет `material_symbols_icons`, стиль outlined (`Symbols.*`) везде — единообразно.
- `lib/features/home/home_shell.dart`: `selectedIcon: Icon(destination.icon, fill: 1)`; размер 24 и цвета — `navigationBarTheme.iconTheme` в `lib/app.dart`.
- `absences_screen.dart:32` — extended FAB `Icon(Symbols.document_scanner, fill: 1)`; `notes_screen.dart:27` — FAB `Icon(Symbols.add)`.
- `opticalSize`, `grade`, `weight` нигде не задаются; глобального `IconThemeData` с осями нет. По `README.md` пакета значения осей по умолчанию: weight 400, **optical size 48**, grade 0, fill 0.
- Размеры: 16 (`absences_screen.dart:52,248`), 18 (`lesson_card.dart:403,425,449`), 20 (`lesson_details_page.dart:255`), 24 (по умолчанию), 28 (`certificate_sheet.dart:151`), 32 (`group_picker_sheet.dart:337`), 36 (`profile_screen.dart:129`).

### Расхождения

| # | Сейчас | Должно быть | Источник |
|---|---|---|---|
| 1 | Optical size не задан → шрифт рисует все иконки с opsz 48 (значение по умолчанию пакета), в том числе 16–24dp | `opticalSize` = фактический размер иконки в пределах 20–48 | `styles__icons.md` (Optical sizes), `material_symbols_icons/README.md` |
| 2 | Grade не зависит от темы | 0 в светлой теме, −25 в тёмной (светлые иконки на тёмном фоне) | `styles__icons.md` (Grade) |
| 3 | Размеры 16 / 18 / 32 / 36dp у отдельных иконок — **не из набора** 20 / 24 / 40 / 48 и не из токенов компонента; иконки 16 и 18dp рядом с `labelMedium` (12sp) / `labelLarge` / `bodyMedium` (14sp) | Стандартный или оптический размер; рядом с текстом — размер и вес под текст со смещением базовой линии ≈11.5%. Иконки меньше 20dp — только простые символы и с подписью | `styles__icons.md` (Icon sizes, Using Material Symbols with typography, Small icons) |
| 4 | Navigation bar: подпись выбранного пункта отличается только цветом (`labelMedium` для обоих состояний) | «Use a filled icon with a bold label for selected destinations… outlined icon with a medium label» | `components__navigation-bar.md` (Accessibility → Visual indicators) |
| 5 | FAB в `notes_screen.dart` — `Symbols.add` без `fill: 1` | Filled-иконка в FAB (у `add` визуально может не отличаться — проверить глиф) | `components__floating-action-button.md` |
| 6 | Заливка иконки в навигации переключается мгновенно | Гайдлайн описывает переход outlined → filled одновременно с раскрытием индикатора; анимация fill как effects — длительность в источниках не указана (не нашёл) | `components__navigation-bar.md`, `styles__icons.md` (Fill) |

Что совпадает: единый стиль outlined; filled-иконка у выбранного пункта навигации и у extended FAB; weight 400 (значение по умолчанию); зоны нажатия icon button 48dp (40dp кнопка + `MaterialTapTargetSize.padded`).

### Что сделать во Flutter

1. В `ThemeData.iconTheme` задать `IconThemeData(size: 24, opticalSize: 24, weight: 400, grade: isLight ? 0 : -25, fill: 0)`; то же для `navigationBarTheme.iconTheme`.
2. В точках с нестандартным размером передавать `opticalSize: size` (с ограничением 20–48) и привести размеры к 20 / 24 / 40 / 48 или токену компонента.
3. Сделать виджет «иконка + текст», который берёт размер из `TextStyle.fontSize` и смещает иконку вниз на 11.5%.
4. Подпись выбранного пункта navigation bar — emphasized `labelMedium` (w700), иконка — `fill: 1`; переход fill можно анимировать effects-пружиной.

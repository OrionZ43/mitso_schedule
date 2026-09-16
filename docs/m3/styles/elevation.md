# Высота (Elevation)

> Разделы «В приложении → Расхождения» описывают состояние на 16.09.2026, до порта компонентов. Исправлено с тех пор: эталонная статичная схема и системные роли Android 14+, emphasized-веса по токенам, opsz и grade иконок, state layer, цвета tooltip, чипов и app bar при прокрутке, scrim 32%, выдуманные альфы, размеры шрифта и радиусы (карточка пары и метки удалены), пустое состояние из `MaterialShapes`, пружины кнопок, листов и снекбара, смена дня — lateral. Остаётся: breakpoints и navigation rail для окон шире 600dp (приложение для телефона), часть отступов вне токенов в старом коде.

## Источники

- m3.material.io: https://m3.material.io/styles/elevation (Overview, Applying elevation, Tokens) → `.m3-guidelines/styles__elevation.md`; роли surface → `styles__color__roles.md`
- Compose Material3: `tokens/ElevationTokens.kt` (Level0–Level5), `tokens/ScrimTokens.kt`, `tokens/AppBarTokens.kt`, `tokens/NavigationBarTokens.kt`, `tokens/SheetBottomTokens.kt`, `tokens/SearchBarTokens.kt`, `tokens/MenuTokens.kt`, `tokens/DialogTokens.kt`, `tokens/{Filled,Elevated,Outlined}CardTokens.kt`, `tokens/FilterChipTokens.kt`; `SearchBar.kt` (`SearchBarDefaults.TonalElevation` / `ShadowElevation` = Level0), `NavigationBar.kt` (`NavigationBarDefaults.Elevation` = Level0), `SheetDefaults.kt` (`BottomSheetDefaults.Elevation`), `Card.kt`, `ModalBottomSheet.kt` (scrim)
- MDC-Android: `docs/theming/Color.md` (Using Surface Colors — тональные surface-роли вместо elevation overlay), `docs/theming/Dark.md` (Elevation overlays — «replaced»)
- Flutter: `material/app_bar.dart` (`WidgetState.scrolledUnder`), `material/navigation_bar.dart` (`_NavigationBarDefaultsM3`), `material/floating_action_button.dart` (`_FABDefaultsM3`), `material/bottom_sheet.dart`; пакет `animations` 2.2.0 `open_container.dart`

## Правила

- Elevation — расстояние по оси z в dp. Токены **не содержат тени и цвета**; платформа решает, как показать уровень: тональной разницей поверхностей, тенью или scrim.
- Шесть уровней: **0 = 0dp, 1 = 1dp, 2 = 3dp, 3 = 6dp, 4 = 8dp, 5 = 12dp**. В покое компоненты находятся на уровнях 0–3; уровни 4 и 5 — только для взаимодействия (hover, drag).
- «Avoid changing the default elevation of Material 3 components»; использовать мало уровней.
- При взаимодействии уровень растёт на один шаг (пример: hover FAB — с 3 на 4; все кнопки +1 при hover). Изменение должно быть одинаковым для похожих элементов.
- По умолчанию M3 разделяет поверхности **тональной разницей** (surface-роли), тени — «only when required»: защита элементов на пёстром фоне и поощрение взаимодействия (временный подъём при фокусе/свайпе).
- Перекрывающиеся области должны иметь разные цветовые роли.
- **Scrim** — роль `scrim` с непрозрачностью 32% (под модальными элементами и развёрнутой навигацией).
- **Surface tint deprecated** — вместо него уровни elevation (0–5).
- Уровни компонентов в покое (таблица Tokens):

| Уровень | Компоненты |
|---|---|
| 3 (6dp) | date/time pickers, модальные dialogs, extended FAB, FAB, кнопка закрытия FAB menu, search |
| 2 (3dp) | app bar при прокрутке, menu, navigation bar, rich tooltip, toolbar |
| 1 (1dp) | banner, модальный bottom sheet, elevated button, elevated card, elevated chips, модальный navigation drawer, модальный side sheet |
| 0 | app bar без прокрутки, filled/tonal/outlined buttons, button groups, filled/outlined cards, carousel, chips, full-screen dialog, FAB и extended FAB внутри navigation rail, пункты FAB menu, icon buttons, list, navigation rail, segmented button, docked side sheet, slider, split button, tabs |

## Как устроено в Compose

- `ElevationTokens.Level0..Level5` = 0 / 1 / 3 / 6 / 8 / 12dp.
- Компоненты: outlined card — Level0 (hover Level1, dragged Level3); elevated card — Level1 (hover Level2, dragged Level4); filled card — Level0; filter chip — Level0 (elevated-вариант Level1); menu — Level2; dialog — Level3; модальный bottom sheet — `SheetBottomTokens.DockedModalContainerElevation` = Level1; app bar — Level0, при прокрутке — `OnScrollContainerElevation` = Level2 + цвет `surfaceContainer`.
- У `SearchBar` и `NavigationBar` в Compose дефолтная тональная и теневая высота — Level0: разделение делает цвет (`surfaceContainerHigh` / `surfaceContainer`).
- Scrim модального шита: `ScrimTokens.ContainerColor` (`scrim`) × `ContainerOpacity` 0.32, прозрачность анимируется DefaultEffects.

## В приложении

### Как сейчас

- `lib/app.dart`: app bar — `surface`, `surfaceTintColor: transparent`, `scrolledUnderElevation: 0`; navigation bar — дефолт Flutter M3 (`elevation: 3`, `shadowColor` и `surfaceTintColor` прозрачные → визуально 0); search bar/view — elevation 0 на `surfaceContainerHigh`; outlined cards — elevation 0; FAB — 6 (дефолты Flutter: focus 6, hover 8, highlight 6); bottom sheet — дефолт Flutter M3 (1), tint прозрачный.
- `lib/widgets/lesson_card.dart`: `OpenContainer(closedElevation: isNow ? 3 : 0, openElevation: 0)`.
- Кастомные контейнеры (`absences_screen.dart`, `profile_screen.dart`, `lesson_card.dart`, `segmented_list.dart`) — без теней, разделение цветом.
- Scrim шитов и `OpenContainer` — `Colors.black54`.

### Расхождения

| # | Сейчас | Должно быть | Источник |
|---|---|---|---|
| 1 | `lesson_card.dart`: карточка текущей пары `closedElevation: 3` — **придумано** (3dp = уровень 2, у карточек такого покоя нет) | Outlined/filled card — 0, elevated card — 1; выделение текущей пары уже сделано цветом `primary` | `styles__elevation.md` (Component elevation), `tokens/*CardTokens.kt` |
| 2 | App bar не реагирует на прокрутку (`scrolledUnderElevation: 0`, цвет всегда `surface`) | При прокрутке — уровень 2 и `surfaceContainer` (тенью не обязательно — достаточно цвета) | `styles__elevation.md`, `tokens/AppBarTokens.kt` |
| 3 | Scrim — `Colors.black54` (54% чёрного) | `scheme.scrim` с альфой 0.32 | `styles__elevation.md` (Scrims), `tokens/ScrimTokens.kt` |

Что совпадает: FAB (уровень 3 = 6dp, hover 8), модальный bottom sheet (уровень 1) без tint, outlined cards (0), navigation bar и search без теней с разделением тоном — как дефолты Compose; surface tint отключён.

### Что сделать во Flutter

1. Убрать `closedElevation: 3` в `OpenContainer` (или перейти на elevated card с уровнем 1 — и оформить).
2. App bar: `backgroundColor: WidgetStateColor.resolveWith((s) => s.contains(WidgetState.scrolledUnder) ? scheme.surfaceContainer : scheme.surface)`, анимация цвета — DefaultEffects (см. `motion.md`).
3. `bottomSheetTheme.modalBarrierColor` и scrim собственного container transform — `scheme.scrim.withValues(alpha: 0.32)`.
4. Новые уровни брать только из набора 0 / 1 / 3 / 6 / 8 / 12dp и только для компонентов из таблицы.

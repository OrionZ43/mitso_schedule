# Типографика (Typography)

## Источники

- m3.material.io: https://m3.material.io/styles/typography (Overview, Fonts, Type scale & tokens, Applying type, Editorial treatments) → `.m3-guidelines/styles__typography.md`; блог M3 Expressive → `building-with-m3-expressive.md`; база токенов сайта (`.m3-guidelines/raw/tokens-*.json`: `md.ref.typeface.*`, `md.sys.typescale.*` с контекстами `3P`, `1P Baseline`, `Variable`)
- Compose Material3: `Typography.kt` (15 baseline + 15 `*Emphasized`), `tokens/TypeScaleTokens.kt` (v0_103), `tokens/TypographyTokens.kt`, `tokens/TypefaceTokens.kt` (`Brand` = `Plain` = `FontFamily.SansSerif`; Regular / Medium / Bold), `MaterialTheme.kt` (`MaterialExpressiveTheme` → `Typography()`, «TODO: replace with calls to Expressive typography default»)
- MDC-Android: `docs/theming/Typography.md` (Baseline scale, Emphasized scale, Downloadable fonts)
- Flutter: `material/typography.dart` (`Typography.material2021`, `englishLike2021`), `material/theme_data.dart` (слияние `textTheme`), `dart:ui` `FontVariation`

## Правила

### Шкала

- 30 стилей: 15 **baseline** + 15 **emphasized** (май 2025). Пять ролей (display, headline, title, body, label) × три размера. Emphasized «have a higher weight and other minor adjustments»; рекомендованы для выбора, действий, заголовков и editorial-treatments. **Компоненты Material по умолчанию emphasized не используют** — нужно заменить токен `md.sys.typescale.X` на `md.sys.typescale.emphasized.X`.
- Где emphasized уместны: badges, кнопки основных действий, extended FAB, выбранные пункты списка и меню; текст, который уже выделен весом; выделение состояния (выбрано, непрочитано).
- Baseline (размер / межстрочный / вес; tracking — Compose `TypeScaleTokens` → контекст `3P` базы токенов сайта):

| Стиль | Размер/строка | Вес | Tracking (Compose / сайт 3P) |
|---|---|---|---|
| displayLarge | 57/64 | 400 | −0.2 / −0.25 |
| displayMedium | 45/52 | 400 | 0 |
| displaySmall | 36/44 | 400 | 0 |
| headlineLarge | 32/40 | 400 | 0 |
| headlineMedium | 28/36 | 400 | 0 |
| headlineSmall | 24/32 | 400 | 0 |
| titleLarge | 22/28 | 400 | 0 |
| titleMedium | 16/24 | 500 | 0.2 / 0.15 |
| titleSmall | 14/20 | 500 | 0.1 |
| bodyLarge | 16/24 | 400 | 0.5 |
| bodyMedium | 14/20 | 400 | 0.2 / 0.25 |
| bodySmall | 12/16 | 400 | 0.4 |
| labelLarge | 14/20 | 500 | 0.1 |
| labelMedium | 12/16 | 500 | 0.5 |
| labelSmall | 11/16 | 500 | 0.5 |

- Emphasized: размер и строка те же; **вес Medium (500)** — display*, headline*, titleLarge, body*; **вес Bold (700)** — titleMedium, titleSmall, label*. Tracking отличается: display*/headline*/titleLarge — 0; titleMedium — 0.15; bodyLarge — 0.15; bodyMedium — 0.25; bodySmall — 0.4; titleSmall и label* — как baseline (`TypeScaleTokens.kt`; веса совпадают с MDC `Typography.md`).
- Для контекста `Variable` (Roboto Flex / Google Sans Flex) tracking в базе токенов сайта — 0.

### Шрифты

- «Static fonts like Roboto are currently applied by default to all Material 3 components. Variable fonts like Roboto Flex … aren't yet part of the M3 typescale».
- Токены `md.ref.typeface.brand` / `plain` в базе сайта по контекстам: `3P` → **Roboto**; `3P + Variable` → **Roboto Flex**; `1P Baseline + Variable` → **Google Sans Flex**; без контекста → Google Sans / Google Sans Text. Сторонние (3P) приложения — Roboto или Roboto Flex; Google Sans Flex описан для 1P. Лицензию и пакет Google Sans Flex для сторонних Android-приложений в источниках не нашёл (на сайте только ссылка на статью design.google о том, что шрифт стал open-source).
- Веса: regular 400, medium 500, bold 700 (`md.ref.typeface.weight-*`).
- Brand-гарнитура — крупные стили (display, headline), plain — мелкие (body, label). По умолчанию обе — Roboto.
- Оси Roboto Flex: slant, width, weight, grade, optical size + продвинутые (XOPQ, YOPQ, XTRA, YTUC, YTLC, YTAS, YTDE, YTFI). Fallback: Roboto Flex → Roboto → Noto Sans.
- Высота письменности: кириллица — **small (base)**; medium ≈ +7%, large ≈ +30%, extra large ≈ +100%.

### Применение

- «Avoid changing the type size; this can affect how components render and reflow». Кастомизация — через гарнитуру, line height, letter spacing; для emphasized держать единый характер.
- Своя шкала допускается (Major Second, 1.125, база 14), но без мелких различий между размерами; editorial treatments — осознанные «hero»-моменты.
- Line height: крупные стили ≈1.2 × размер, body/label ≈1.5 × размер (токены уже оптимизированы).
- Tabular figures — «where values may change often, such as clocks».
- Контраст текста: 3:1 для крупного, 4.5:1 для мелкого; цвет по умолчанию `onSurface`, альтернатива `onSurfaceVariant`; ссылки — `primary` + подчёркивание.
- При 200% шрифта: заголовки диалогов — не больше 4 строк (`components__dialogs.md`), подписи кнопок — не больше 2 (`components__buttons.md`); отступы при масштабировании сохраняются (`styles__spacing.md`).
- Иконки рядом с текстом — того же размера и оптического веса, базовая линия символа смещена вниз примерно на 11.5% размера текста (`styles__icons.md`).

## Как устроено в Compose

- `MaterialTheme.typography.bodyLargeEmphasized` и т. д. — отдельные `TextStyle` из `TypographyTokens`. Компоненты используют baseline; emphasized подставляет разработчик.
- `TypefaceTokens.Brand` / `Plain` = `FontFamily.SansSerif` — системный sans-serif, ничего не бандлится.
- `MaterialExpressiveTheme` пока передаёт обычный `Typography()`.
- MDC-Android: атрибуты `textAppearance*Emphasized`; шрифты Google Fonts — через Downloadable Fonts (Android O+).

## В приложении

### Как сейчас

- `lib/theme/app_typography.dart`: `fontFamily: 'Roboto'`; размеры, строки и веса = baseline; tracking = контекст `3P` сайта (−0.25 / 0.25 / 0.15), не Compose (−0.2 / 0.2 / 0.2). `TextStyleEmphasis.emphasized` → `copyWith(fontWeight: FontWeight.w700)` для любого стиля. Цвета `0xFF1C1B20` / `0xFFE8E1EC` (перекрываются в `buildTheme`).
- Использование `.emphasized`: заголовки экранов `headlineMedium` (`absences_screen.dart`, `notes_screen.dart`, `profile_screen.dart`, `schedule_screen.dart`, `boot_screen.dart`), `headlineSmall` (шиты, `lesson_details_page.dart`), `titleLarge` (`profile_screen.dart`, `schedule_screen.dart`, `empty_state.dart`), `displaySmall` (`absence_donut.dart`), `titleMedium`/`titleSmall`/`labelLarge`/`labelMedium` (карточки, бейджи, день недели).

### Расхождения

| # | Сейчас | Должно быть | Источник |
|---|---|---|---|
| 1 | `.emphasized` = w700 для всех стилей | display*/headline*/titleLarge/body* → **w500**; titleMedium/titleSmall/label* → w700. Плюс tracking emphasized (display/headline/titleLarge 0; titleMedium 0.15; bodyLarge 0.15; bodyMedium 0.25) | `tokens/TypeScaleTokens.kt`, MDC `Typography.md` |
| 2 | Размеры шрифта **придуманы**: `absences_screen.dart:174` `fontSize: 15`; `absence_donut.dart:70–72` `fontSize: 48, height: 1, letterSpacing: -1`; `boot_screen.dart:28` `fontSize: 30`; `day_selector.dart:182` `fontSize: 18`; `empty_state.dart:47` `fontSize: 20` | Токен шкалы без изменения размера («Avoid changing the type size»). Если нужен editorial-момент (цифра на диаграмме) — размер из шкалы (45 / 57) и запись в отступлениях | `styles__typography.md` |
| 3 | Межстрочный **придуман**: `absences_screen.dart:228` `height: 1.3` у titleMedium (20.8 вместо 24); `profile_screen.dart:139` `height: 1.25` у titleLarge (27.5 вместо 28); `notes_screen.dart:131` `height: 1.5` (= токену, лишнее) | Line height из токена | `tokens/TypeScaleTokens.kt` |
| 4 | Ad hoc `bodyMedium.copyWith(fontWeight: w500)` (`absences_screen.dart:76`, `profile_screen.dart:209,275`, `lesson_card.dart:342`) | Это фактически `bodyMediumEmphasized` (500, tracking 0.25) — оформить именованным токеном | `tokens/TypeScaleTokens.kt` |
| 5 | Числа, которые меняются (осталось N мин в `lesson_card.dart`, часы в `absence_donut.dart`) — пропорциональные цифры (`FontFeature` в `lib/` нет) | `FontFeature.tabularFigures()` | `styles__typography.md` (Tabular numbers) |
| 6 | Цвета текста в `app_typography.dart` — hex | `onSurface` из схемы | `styles__typography.md` (Color & contrast) |
| 7 | Шрифт — системный Roboto; tracking по контексту `3P` | Соответствует контексту `3P`. Если перейти на Roboto Flex (`3P + Variable`) — tracking 0 и настройка осей; решение записать | база токенов сайта, `styles__typography.md` |

### Что сделать во Flutter

1. Заменить `TextStyleEmphasis.emphasized` на полноценный набор из 15 emphasized-стилей (например, `ThemeExtension<EmphasizedTextTheme>`) со значениями из `TypeScaleTokens.kt`.
2. Удалить все `fontSize` / `height` / `letterSpacing` в `copyWith` поверх токенов; для hero-чисел выбрать стиль шкалы и оформить отступление.
3. Для изменяющихся чисел добавить `fontFeatures: [FontFeature.tabularFigures()]`.
4. Цвет текста брать только из `ColorScheme`.
5. Если нужен вариативный шрифт: подключить Roboto Flex ассетом, оси задавать через `TextStyle.fontVariations` (`FontVariation('wght', 500)` и т. д.), fallback — Roboto → Noto Sans.

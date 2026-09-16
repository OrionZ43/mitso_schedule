# Промт для Claude Code: приложение «Расписание» на Flutter (Material 3 Expressive)

> Скопируй весь этот файл целиком в Claude Code как первое сообщение.

---

## 0. Импорт макета

```
Use the claude_design MCP (https://api.anthropic.com/v1/design/mcp, auth via /design-login) to import this project:
https://claude.ai/design/p/0b625def-bf17-439c-95aa-d77ef2c7e563?file=%D0%A0%D0%B0%D1%81%D0%BF%D0%B8%D1%81%D0%B0%D0%BD%D0%B8%D0%B5+-+Material+3+Expressive.dc.html

Focus on these files (the whole project is readable):
- `Расписание - Material 3 Expressive.dc.html`
- `support.js`

Implement: the selected files
```

Импортируй макет **до** начала работы и разбери его: в нём лежат готовые цветовые палитры (4 схемы × light/dark), типографика, радиусы, spring-токены движения, все моковые данные (расписание на 6 дней, справки, задачи, профиль) и вся логика переключения состояний. HTML-макет — источник истины по контенту и композиции; Google-гайдлайны — источник истины по геометрии, типографике и движению. **Если макет и гайдлайн противоречат друг другу — выигрывает гайдлайн**, кроме явно указанных ниже исключений.

---

## 1. Задача

Собрать Android-приложение на **Flutter** (открывается и запускается в **Android Studio**), реализующее макет расписания для студентов университета в стиле **Material 3 Expressive**. Весь UI — на русском языке, данные моковые, без бэкенда.

Целевые версии: Flutter stable (≥ 3.35), Dart 3.x, `compileSdk 36`, `minSdk 24`, Material 3 (`useMaterial3: true`).

---

## 2. Обязательное чтение перед кодом

Прочитай эти страницы через WebFetch и следуй числам из них (dp, sp, токены, длительности). Не выдумывай значения — если значение не нашлось на странице, открой соседнюю вкладку **Specs** того же компонента.

**M3 Expressive, общее**
- https://m3.material.io/blog/building-with-m3-expressive
- https://m3.material.io/blog/m3-expressive-motion-theming
- https://m3.material.io/develop/flutter
- https://m3.material.io/components

**Стили и токены**
- Цвет: https://m3.material.io/styles/color/system/overview
- Цветовые роли: https://m3.material.io/styles/color/roles
- Динамический цвет: https://m3.material.io/styles/color/dynamic/choosing-a-source
- Типографика: https://m3.material.io/styles/typography/overview
- Токены типошкалы: https://m3.material.io/styles/typography/type-scale-tokens
- Emphasized-начертания: https://m3.material.io/styles/typography/applying-type
- Форма: https://m3.material.io/styles/shape/overview
- Шкала радиусов: https://m3.material.io/styles/shape/corner-radius-scale
- Морфинг форм: https://m3.material.io/styles/shape/shape-morph
- Движение: https://m3.material.io/styles/motion/overview
- Spring-токены и спеки движения: https://m3.material.io/styles/motion/overview/specs
- Easing и длительности: https://m3.material.io/styles/motion/easing-and-duration/tokens-specs
- Высоты (elevation): https://m3.material.io/styles/elevation/overview
- Иконки: https://m3.material.io/styles/icons/overview

**Компоненты (overview + guidelines + specs каждой ссылки)**
- Loading indicator: https://m3.material.io/components/loading-indicator/overview · https://m3.material.io/components/loading-indicator/guidelines · https://m3.material.io/components/loading-indicator/specs
- Progress indicators: https://m3.material.io/components/progress-indicators/overview · https://m3.material.io/components/progress-indicators/guidelines · https://m3.material.io/components/progress-indicators/specs
- Navigation bar: https://m3.material.io/components/navigation-bar/overview · https://m3.material.io/components/navigation-bar/specs
- Search: https://m3.material.io/components/search/overview · https://m3.material.io/components/search/guidelines
- Chips: https://m3.material.io/components/chips/overview · https://m3.material.io/components/chips/specs
- Cards: https://m3.material.io/components/cards/overview · https://m3.material.io/components/cards/specs
- Lists: https://m3.material.io/components/lists/overview · https://m3.material.io/components/lists/specs
- Extended FAB: https://m3.material.io/components/extended-fab/overview · https://m3.material.io/components/extended-fab/specs
- FAB: https://m3.material.io/components/floating-action-button/overview
- FAB menu: https://m3.material.io/components/fab-menu/overview
- Bottom sheets: https://m3.material.io/components/bottom-sheets/overview · https://m3.material.io/components/bottom-sheets/specs
- Switch: https://m3.material.io/components/switch/overview · https://m3.material.io/components/switch/specs
- Checkbox: https://m3.material.io/components/checkbox/overview · https://m3.material.io/components/checkbox/specs
- Segmented buttons: https://m3.material.io/components/segmented-buttons/overview · https://m3.material.io/components/segmented-buttons/specs
- Buttons: https://m3.material.io/components/buttons/overview · https://m3.material.io/components/buttons/specs
- Button groups: https://m3.material.io/components/button-groups/overview
- Top app bar: https://m3.material.io/components/top-app-bar/overview · https://m3.material.io/components/top-app-bar/specs
- Badges: https://m3.material.io/components/badges/overview
- Dividers: https://m3.material.io/components/divider/overview
- Snackbar: https://m3.material.io/components/snackbar/overview

**Доступность**
- https://m3.material.io/foundations/accessible-design/overview
- https://m3.material.io/foundations/accessible-design/patterns

**Flutter**
- https://docs.flutter.dev/ui/design/material
- https://docs.flutter.dev/release/breaking-changes (проверь актуальность M3-виджетов)
- https://api.flutter.dev/flutter/material/ThemeData-class.html
- https://api.flutter.dev/flutter/material/ColorScheme-class.html
- https://api.flutter.dev/flutter/material/TextTheme-class.html
- https://api.flutter.dev/flutter/material/NavigationBar-class.html
- https://api.flutter.dev/flutter/material/SearchAnchor-class.html
- https://api.flutter.dev/flutter/material/SearchBar-class.html
- https://api.flutter.dev/flutter/material/FilterChip-class.html
- https://api.flutter.dev/flutter/material/SegmentedButton-class.html
- https://api.flutter.dev/flutter/material/LinearProgressIndicator-class.html
- https://api.flutter.dev/flutter/material/CircularProgressIndicator-class.html
- https://api.flutter.dev/flutter/material/showModalBottomSheet.html
- https://api.flutter.dev/flutter/material/FloatingActionButton/FloatingActionButton.extended.html
- https://api.flutter.dev/flutter/physics/SpringDescription-class.html
- https://api.flutter.dev/flutter/physics/SpringSimulation-class.html
- https://api.flutter.dev/flutter/widgets/AnimatedContainer-class.html
- https://api.flutter.dev/flutter/animation/CurvedAnimation-class.html

**Пакеты**
- https://pub.dev/packages/dynamic_color
- https://pub.dev/packages/material_color_utilities
- https://pub.dev/packages/google_fonts
- https://pub.dev/packages/material_symbols_icons
- https://pub.dev/packages/flutter_riverpod
- https://pub.dev/packages/shared_preferences
- https://pub.dev/packages/intl

---

## 3. Стек и структура проекта

Зависимости (`pubspec.yaml`): `flutter_riverpod`, `dynamic_color`, `google_fonts`, `material_symbols_icons`, `shared_preferences`, `intl`, dev: `flutter_lints`, `flutter_test`, `golden_toolkit` (по желанию).

```
lib/
  main.dart                     // runApp + ProviderScope + DynamicColorBuilder
  app.dart                      // MaterialApp, темы, локаль ru_RU, роутинг табов
  theme/
    app_color_schemes.dart      // 4 палитры (violet/blue/green/coral) × light/dark
    app_typography.dart         // TextTheme на Roboto + emphasized-начертания
    app_shapes.dart             // corner-радиусы по шкале M3
    app_motion.dart             // spring-токены M3 Expressive
  data/
    models/                     // Lesson, Certificate, TaskItem, StudentProfile
    mock_data.dart              // данные один-в-один из HTML-макета
  state/
    settings_controller.dart    // тема, динамические цвета, уведомления (shared_preferences)
    schedule_controller.dart
    absences_controller.dart
    tasks_controller.dart
  features/
    boot/boot_screen.dart       // экран загрузки (loading indicator)
    schedule/                   // вкладка 1
    absences/                   // вкладка 2
    notes/                      // вкладка 3
    profile/                    // вкладка 4
  widgets/
    m3_loading_indicator.dart   // морфящийся индикатор загрузки
    m3_wavy_linear_progress.dart
    day_selector.dart
    lesson_card.dart
    status_badge.dart
    empty_state.dart
```

Состояние — Riverpod (`StateNotifier`/`Notifier`). Никаких глобальных синглтонов, никакого `setState` выше уровня отдельного виджета.

---

## 4. Тема

### 4.1 Цвет

- База — `ColorScheme.fromSeed(seedColor: …, brightness: …, dynamicSchemeVariant: DynamicSchemeVariant.expressive)` (варианты: см. `material_color_utilities`).
- Четыре seed-палитры из макета: **violet `#6B3FD4`** (по умолчанию), **blue `#1F5FD0`**, **green `#1E6B4E`**, **coral `#A93B4F`**.
- Тумблер «Динамические цвета (Material You)» в профиле:
  - **включён** → `DynamicColorBuilder` + `corePalette`/`accentColor` с устройства (Android 12+), fallback на seed-палитру;
  - **выключен** → baseline-схема M3 (`#6750A4`).
- Тумблер «Тёмная тема» переключает `ThemeMode` и сохраняется в `shared_preferences`.
- Статусные цвета справок (в M3 нет ролей warning/success) заведи как `ThemeExtension<StatusColors>` с полями `pending/approved/rejected` + их `on*`-цвета; значения — из макета, контраст текста ≥ 4.5:1 в обеих темах.
- Никаких хардкод-цветов в виджетах: только `Theme.of(context).colorScheme.*` и расширение темы.

### 4.2 Типографика

- `google_fonts` → Roboto (при наличии — Roboto Flex для emphasized-начертаний через `variations`).
- Полная `TextTheme` по токенам типошкалы M3 (display/headline/title/body/label × large/medium/small).
- Крупные заголовки экранов — `headlineMedium` в emphasized-начертании (вес 700), НЕ кастомные размеры.
- Метрики из макета, которые нужно сохранить: заголовок экрана 28sp/700, заголовок карточки пары `titleMedium` 16sp/700, метаданные `bodyMedium` 14sp, бейджи `labelSmall` 11sp/500, подписи навбара `labelMedium` 12sp/500.

### 4.3 Формы

- Шкала радиусов M3: 4 / 8 / 12 / 16 / 20 / 28 / 32 / 48 / full.
- Карточки — 28dp, выделенная карточка текущей пары — 32dp, боттом-шит — 28dp сверху, чипы — 8dp, FAB — 16dp, индикатор навбара — full.
- Исключение из спеки, согласованное с заказчиком: карточки крупнее стандартных 12dp (24–32dp) — это осознанное expressive-решение, сохранить.

### 4.4 Движение (обязательно spring, не кривые)

Реализуй `app_motion.dart` с официальными spring-токенами M3 Expressive (`SpringDescription(mass: 1, stiffness: k, ratio: ζ)`):

| Токен | stiffness | damping ratio | применение |
|---|---|---|---|
| fastSpatial | 800 | 0.6 | быстрые деформации, переключение чипов/дней |
| defaultSpatial | 380 | 0.8 | стандартные перемещения, шит, морфинг карточки |
| slowSpatial | 200 | 0.8 | крупные перестроения |
| fastEffects | 3800 | 1.0 | быстрые цвет/прозрачность |
| defaultEffects | 1600 | 1.0 | цвет, прозрачность, ripple |
| slowEffects | 800 | 1.0 | медленные затухания |

Правило: **позиция/размер/форма → spatial (с перелётом), цвет/прозрачность → effects (без перелёта)**. Проверь по https://m3.material.io/styles/motion/overview/specs — если Flutter-версия уже даёт `MotionScheme`/`MotionTheme` из коробки, используй его вместо ручных `SpringDescription`.

---

## 5. Экран загрузки — по гайдлайнам loading indicator

Текущая реализация в HTML-макете **не соответствует** https://m3.material.io/components/loading-indicator/guidelines — это известный дефект, исправить при переносе.

Сделай так:
1. Прочитай guidelines + specs страницы loading indicator и возьми оттуда: размеры **contained** (контейнер и активный индикатор) и **uncontained** вариантов, официальную последовательность форм, угол поворота на шаг морфинга и длительность полного цикла.
2. Реализуй виджет `M3LoadingIndicator` (`CustomPainter` + `AnimationController`), который морфится по официальной последовательности форм (soft burst, cookie 9-sided, pentagon, pill, sunny, cookie 4-sided, oval — сверь по спеке) и одновременно вращается. Морфинг — интерполяцией между путями с одинаковым числом опорных точек (см. https://m3.material.io/styles/shape/shape-morph).
3. Используй contained-вариант: активный индикатор `colorScheme.primary` на контейнере `colorScheme.primaryContainer`.
4. Loading indicator по гайдлайну применяется для **коротких ожиданий и pull-to-refresh**, а не как брендовый сплэш на 3 секунды. Поэтому:
   - splash-экран приложения делай штатным Android-сплэшем (`flutter_native_splash` или `android:windowSplashScreen*` API 31+);
   - `M3LoadingIndicator` показывай на `BootScreen` только пока реально грузятся данные/настройки (моки — с искусственной задержкой ≤ 1.2 с), плюс переиспользуй его в pull-to-refresh на вкладке «Расписание» и при отправке справки.
5. Переход с BootScreen на главный экран — `fadeThrough`/shared axis по https://m3.material.io/styles/motion/transitions/transition-patterns.

---

## 6. Полоса прогресса — wavy linear progress

Для текущей пары нужна **волнистая линейная шкала** (см. https://m3.material.io/components/progress-indicators/overview и specs):

- Сначала проверь, поддерживает ли установленная версия Flutter волнистый вариант штатно (`LinearProgressIndicator` с `year2023: false`, `stopIndicatorColor`, `trackGap`, wave-параметры). Если да — используй штатный виджет.
- Если нет — реализуй `M3WavyLinearProgress` на `CustomPainter`: активная часть — синусоида с длиной волны и амплитудой из спеки (в макете: длина волны 40dp, амплитуда 3dp, толщина 4dp), зазор 4dp между активной частью и треком, точка-ограничитель (stop indicator) 4dp на конце, скругления концов — round. Волна анимируется бегущей фазой; при `determinate` амплитуда должна плавно уходить в ноль на 100%.
- Цвета: активная часть `onPrimary` на карточке-primary, трек — `onPrimary` с прозрачностью из спеки.
- Круговая диаграмма пропусков на вкладке 2 — это **не** progress indicator, а инфографика: отдельный `CustomPainter` (две дуги + трек), не переиспользуй компонент прогресса.

---

## 7. Экраны

Все тексты, ФИО, номера аудиторий, даты и статусы бери **дословно** из макета (`mock_data.dart`). Ничего не переписывай и не «улучшай».

### 7.1 Расписание (главная)
- Large top app bar: дата `Среда, 16 сентября` (labelLarge, onSurfaceVariant) + заголовок `Расписание` + аватар-инициалы 40dp справа.
- `SearchAnchor.bar()` с подсказкой `Поиск группы, препода, аудитории`, ведущая иконка `search`, ведомая `mic`, высота 56dp, радиус full. В раскрытом виде: `arrow_back`, поле ввода, три `FilterChip` — `Группы`, `Преподаватели`, `Аудитории` (высота 32dp, радиус 8dp, выбранный — с ведущим `check`), ниже — недавние запросы с иконкой `history`.
- Горизонтальный селектор дней Пн–Сб (56dp ширина, дата + день недели). Активный — залитый `primary`, радиус морфится 16dp → 28dp пружиной `defaultSpatial`.
- Список пар: карточки (outlined, 28dp) — время начала/конца, бейдж типа (`Лекция` = primaryContainer, `Практика` = success-container, `Лаб` = tertiaryContainer), название, преподаватель, аудитория.
- **Текущая пара**: залитая карточка `primary`, радиус 32dp, метка `СЕЙЧАС ИДЁТ` с пульсирующей точкой, `осталось 32 мин`, волнистая шкала прогресса (см. §6).
- Суббота — пустое состояние: геометрическая иллюстрация + «Занятий нет. Отдыхай!».
- Pull-to-refresh с `M3LoadingIndicator`.

### 7.2 Пропуски
- Заголовок + строка синхронизации «Синхронизировано с ботом · 2 мин назад» с иконкой `sync`.
- Кольцевая диаграмма: 14 часов пропущено, лимит 40 ч, две дуги (8 ч оправдано — primaryContainer, 6 ч без справки — primary), в центре `48sp/700` число. Легенда двумя карточками.
- Список справок с бейджами статуса: `В обработке` (жёлтый), `Одобрено` (зелёный), `Отклонено` (красный), под каждой — иконка и пояснение.
- `FloatingActionButton.extended` «Оправдать пропуск» с иконкой `document_scanner`, высота 56dp, радиус 16dp, elevation 3.
- Нажатие → `showModalBottomSheet` (drag handle, радиус 28dp, заголовок `Оправдать пропуск`, зона загрузки фото пунктиром, кнопки `Отмена` / `Отправить`). Отправка добавляет справку со статусом «В обработке» в начало списка + `SnackBar`.

### 7.3 Заметки (дедлайны)
- `SegmentedButton` `Активные` / `Выполненные` (высота 40dp, радиус full, разделитель, галочка у выбранного).
- Карточки задач: чекбокс M3 (18dp, радиус 2dp, зона нажатия 48dp), текст задачи, чип предмета, чип дедлайна (просроченный/срочный — errorContainer). Отметка выполнения — зачёркивание + затухание, анимация `defaultEffects`.
- Пустое состояние: минималистичная иллюстрация из геометрических фигур + «Дедлайнов пока нет, можно отдыхать!» и подпись про бота.
- Small FAB `add` (56dp, радиус 16dp) добавляет задачу.

### 7.4 Профиль
- Шапка: аватар 72dp с инициалами, имя `Артём Кузнецов` (titleLarge/700), чипы `2423 УИР` и `3 курс · ИКТиУ`.
- Секция LMS Moodle: логин `000000`, пароль скрыт (`••••••••••`) с кнопкой-глазом и кнопками «Копировать» (`Clipboard.setData`, после нажатия на 1.6 с состояние «Скопировано»).
- Секция настроек: три `SwitchListTile` — «Тёмная тема», «Динамические цвета (Material You)», «Напоминать о паре». Все три реально работают и переживают перезапуск (`shared_preferences`).

### 7.5 Навигация
`NavigationBar` M3: высота 80dp, 4 пункта (`Расписание`, `Пропуски`, `Заметки`, `Профиль`), индикатор-таблетка 64×32dp, иконки 24dp — filled у активного, outlined у неактивных (`material_symbols_icons`), подписи `labelMedium`. Переключение вкладок — `IndexedStack` + fadeThrough-переход.

---

## 8. Качество

- Доступность: минимальная зона нажатия 48×48dp, контраст текста ≥ 4.5:1 (заголовки ≥ 3:1), `Semantics` для иконок-кнопок, поддержка масштабирования шрифта до 200% без обрезки (проверь `MediaQuery.textScaler`).
- Локализация: `flutter_localizations`, `Locale('ru','RU')`, даты через `intl` (`DateFormat.MMMMd('ru')`), никакой латиницы в UI, кроме `LMS Moodle` и `Material You`.
- Тёмная тема проверена на всех четырёх экранах и во всех четырёх палитрах.
- `flutter analyze` — без предупреждений; `dart format` применён.
- Виджет-тесты: переключение вкладок, отметка задачи, отправка справки, переключение темы. Golden-тест на карточку текущей пары (опционально).
- README.md: как открыть в Android Studio, как запустить на эмуляторе Pixel 8 (API 35), список реализованных гайдлайнов и список сознательных отступлений от спеки (крупные радиусы карточек, кастомные статусные цвета).

---

## 9. Порядок работы

1. Импортируй макет через claude_design MCP, прочитай `.dc.html` и выпиши из него данные и токены.
2. Прочитай страницы из §2 (минимум: motion specs, loading indicator guidelines + specs, progress indicators specs, navigation bar specs, type scale tokens, corner radius scale).
3. Создай проект, настрой тему (§4) — сначала цвет/типографика/формы/движение, потом экраны.
4. Реализуй `M3LoadingIndicator` и `M3WavyLinearProgress` как отдельные переиспользуемые виджеты с юнит-проверкой геометрии.
5. Собери экраны в порядке: Расписание → Пропуски → Заметки → Профиль → навигация → BootScreen.
6. Прогони `flutter analyze`, тесты, запусти на эмуляторе, покажи скриншоты всех четырёх вкладок в светлой и тёмной теме.
7. В конце — короткий отчёт: что сделано по спеке, где пришлось отойти и почему.

Работай итеративно, коммить по шагам, не пиши весь проект одним файлом.

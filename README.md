# Расписание — Material 3 Expressive

Android-приложение расписания для студента МИТСО (гр. 2423 УИР, 3 курс ИКТиУ) на Flutter.
Весь интерфейс на русском, данные моковые, бэкенда нет.

Макет-источник: `docs/Расписание - Material 3 Expressive.dc.html`.

---

## Запуск

### Android Studio

1. **File → Open** → выбрать папку `mitso_schedule`.
2. Дождаться `Pub get` (или выполнить `flutter pub get` в терминале).
3. В списке устройств выбрать эмулятор и нажать **Run** (`Shift+F10`).

### Эмулятор из командной строки

```bash
flutter emulators --launch Medium_Phone_API_36.0   # или свой AVD
flutter run -d emulator-5554
```

Проект проверен на эмуляторе Android 16 (API 36). Заявленный минимум — `minSdk 24`,
сборка — `compileSdk 36`.

### Проверки

```bash
flutter analyze   # без предупреждений
flutter test      # 18 тестов
dart format lib test
```

---

## Что сделано по гайдлайнам

| Область | Реализация |
|---|---|
| [Цвет](https://m3.material.io/styles/color/system/overview) | `ColorScheme.fromSeed` с `DynamicSchemeVariant.expressive`, 4 сид-палитры (violet / blue / green / coral), baseline `#6750A4` при выключенных динамических цветах |
| [Динамический цвет](https://m3.material.io/styles/color/dynamic/choosing-a-source) | `DynamicColorBuilder`, схема с устройства на Android 12+, фолбэк на сид-палитру |
| [Типографика](https://m3.material.io/styles/typography/type-scale-tokens) | Полная `TextTheme` по токенам типошкалы на Roboto, emphasized-начертание через `TextStyle.emphasized` |
| [Форма](https://m3.material.io/styles/shape/corner-radius-scale) | `AppShapes` — вся шкала радиусов M3, никаких «магических» чисел в виджетах |
| [Движение](https://m3.material.io/styles/motion/overview/specs) | `AppMotion` — шесть пружинных токенов M3 Expressive; позиция/форма идут по *spatial*, цвет/прозрачность — по *effects* |
| [Loading indicator](https://m3.material.io/components/loading-indicator/guidelines) | `M3LoadingIndicator`: морфинг по официальной последовательности из 7 форм (36 опорных точек каждая) + вращение 45° за шаг |
| [Progress indicators](https://m3.material.io/components/progress-indicators/overview) | `M3WavyLinearProgress`: синусоида 40dp × 3dp, толщина 4dp, зазор 4dp, stop indicator 4dp, амплитуда гаснет к 100% |
| [Navigation bar](https://m3.material.io/components/navigation-bar/specs) | `NavigationBar` 80dp, индикатор-таблетка, filled-иконки у активного пункта |
| [Search](https://m3.material.io/components/search/overview) | `SearchAnchor.bar` с фильтр-чипами и недавними запросами |
| [Bottom sheets](https://m3.material.io/components/bottom-sheets/specs) | `showModalBottomSheet` с drag handle и скруглением 28dp сверху |
| [Переходы](https://m3.material.io/styles/motion/transitions/transition-patterns) | fade through между вкладками и с экрана загрузки |
| [Доступность](https://m3.material.io/foundations/accessible-design/patterns) | `Semantics` на иконках-кнопках и диаграмме, зона нажатия ≥ 48dp, контраст статусов проверяется тестом |

Состояние — Riverpod (`Notifier`), настройки переживают перезапуск через `shared_preferences`.

---

## Сознательные отступления от спеки

1. **Радиусы карточек 28dp / 32dp вместо `medium` (12dp).**
   Согласовано как expressive-решение; закреплено в `AppShapes.card` и `AppShapes.cardEmphasized`.

2. **Статусные цвета справок — `ThemeExtension<StatusColors>`.**
   В M3 нет ролей `warning` / `success`. Значения взяты из макета; контраст текста к контейнеру
   ≥ 4.5:1 в обеих темах — проверяется в `test/status_contrast_test.dart`.

3. **Три компонента написаны вручную, потому что Flutter 3.44 их не поставляет.**
   Проверено по исходникам SDK:
   - `LoadingIndicator` в `packages/flutter/lib/src/material/` отсутствует → `M3LoadingIndicator`;
   - `LinearProgressIndicator` умеет `year2023: false`, `trackGap`, `stopIndicator*`, но не волнистый
     вариант → `M3WavyLinearProgress`;
   - `RefreshIndicator` рисует собственную шкалу и не даёт её заменить → `M3PullToRefresh`.

4. **Пружины заданы вручную.**
   `MotionScheme` / `MotionTheme` в 3.44 ещё нет (`motion.dart` содержит только `Durations` и
   `Easing`), поэтому `AppMotion` строит `SpringDescription.withDampingRatio` и оборачивает
   симуляцию в `SpringCurve`, чтобы пружины работали и в неявных анимациях.

5. **Числа для loading indicator взяты из реализации Compose Material3.**
   Страницы `specs` на m3.material.io отдаются как SPA и машинно не читаются. Значения
   (контейнер 48dp, активный индикатор 38dp, шаг морфинга 650 мс, поворот 45° за шаг) вынесены
   в константы `M3LoadingIndicator` и покрыты тестом, так что правятся в одном месте.
   Сами формы взяты из макета — это официальная последовательность M3.

6. **Вращение индикатора: полный оборот за 8 шагов (5200 мс) при цикле морфинга в 7 форм (4550 мс).**
   Так скорость поворота ровно 45° за шаг морфинга, и при этом оба цикла замыкаются без рывка.

7. **Emphasized-начертание — вес w700 обычного Roboto.**
   `google_fonts` не даёт управлять осями Roboto Flex через `variations`.

8. **Тумблер «Тёмная тема» трёхсостоянчатый внутри.**
   `null` — следовать системной (подпись из макета «Следовать системной»), иначе явный выбор
   пользователя. Иначе подпись макета противоречила бы поведению.

9. **Выбор палитры добавлен на вкладку «Профиль».**
   В макете палитра — параметр design-time. Без переключателя три из четырёх палитр в приложении
   недостижимы и непроверяемы.

10. **Строка поиска прокручивается вместе с контентом**, а не залипает вверху, как в макете.

11. **`dynamic_color` закреплён на 1.8.x.**
    Версия 2.1.0 собрана против пакета `material_ui`, её `ColorScheme` и `Widget` — другие типы,
    несовместимые с `package:flutter/material.dart`.

---

## Структура

```
lib/
  main.dart                  ProviderScope, SharedPreferences, intl
  app.dart                   MaterialApp, темы, локаль ru_RU, экран загрузки
  theme/                     цвет, типографика, формы, движение, статусные цвета
  data/                      модели и моковые данные из макета
  state/                     Riverpod-контроллеры
  features/                  boot, home, schedule, absences, notes, profile
  widgets/                   M3LoadingIndicator, M3WavyLinearProgress,
                             M3PullToRefresh, DaySelector, LessonCard, …
test/
  app_test.dart              вкладки, отметка задачи, отправка справки, тема
  indicators_geometry_test.dart  геометрия форм и волнистой шкалы
  status_contrast_test.dart  контраст статусных цветов
```

`lib/widgets/m3_loading_shapes.dart` сгенерирован из `@keyframes m3morph` макета.

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

Заявленный минимум — `minSdk 24`, сборка — `compileSdk 36`.

Приложение проверено на Pixel 7 (Android 17): запускается, в logcat нет ошибок.

> **Если Google Maven недоступен.** Из некоторых сетей `dl.google.com` отдаёт 404 на любой
> артефакт, и первая сборка падает на `Plugin 'com.android.application' ... was not found`.
> Обход — зеркала Google Maven в глобальном init-скрипте Gradle
> (`~/.gradle/init.d/google-maven-mirror.gradle`), проект при этом не меняется.
> Скрипт должен добавлять зеркала и в `pluginManagement`, и в `dependencyResolutionManagement`,
> явно возвращать `gradlePluginPortal()` и не добавлять репозитории на уровне проектов в сборки
> с `FAIL_ON_PROJECT_REPOS` — так настроена включённая сборка `flutter_tools/gradle`.
>
> В `gradle-wrapper.properties` задан `distributionSha256Sum`: если дистрибутив Gradle
> скачается не полностью, сборка сразу упадёт на проверке суммы, а не на битом архиве
> (`zip END header not found`).

### Проверки

```bash
flutter analyze   # без предупреждений
flutter test      # 26 тестов
dart format lib test
```

### Скриншоты

```bash
flutter test test/screenshot_generator.dart
```

Кладёт PNG всех четырёх вкладок в светлой и тёмной теме, пустой субботы и шита
отправки справки в `docs/screenshots/`. Генератор рендерит настоящим движком
Flutter и сам подгружает Roboto и Material Symbols через `FontLoader` — иначе
тестовая среда рисует текст и иконки прямоугольниками.

| | |
|---|---|
| ![Расписание](docs/screenshots/1-schedule-light.png) | ![Пропуски](docs/screenshots/2-absences-light.png) |
| ![Заметки](docs/screenshots/3-notes-light.png) | ![Профиль](docs/screenshots/4-profile-light.png) |

---

## Что сделано по гайдлайнам

Компоненты сверены с документацией и токенами
[material-components-android](https://github.com/material-components/material-components-android/tree/master/docs/components)
(`docs/components/*.md` и `lib/.../res/values/*tokens.xml`).

| Компонент | Реализация |
|---|---|
| Цвет | `ColorScheme.fromSeed` с `DynamicSchemeVariant.expressive`, 4 сид-палитры, baseline `#6750A4` при выключенных динамических цветах, `DynamicColorBuilder` на Android 12+ |
| Типографика, форма, движение | Полная `TextTheme` по токенам, шкала радиусов M3, шесть пружинных токенов Expressive (*spatial* для формы, *effects* для цвета) |
| [Loading indicator](https://github.com/material-components/material-components-android/blob/master/docs/components/LoadingIndicator.md) | Порт MDC: `MaterialShapes` и `Morph` из `material_new_shapes`, пружина 200 / 0.6, поворот 50° + 90° за шаг 650 мс, contained — `onPrimaryContainer` на `primaryContainer` |
| [Progress indicator](https://github.com/material-components/material-components-android/blob/master/docs/components/ProgressIndicator.md) | Волнистый determinate: 4dp, амплитуда 3dp, волна 40dp, зазор 4dp, stop indicator 4dp; волна неподвижна, полная амплитуда только при 0.1–0.9 |
| [Navigation bar](https://github.com/material-components/material-components-android/blob/master/docs/components/BottomNavigation.md) | Expressive: высота 64dp, индикатор 56×32 `secondaryContainer`, активная подпись `secondary` |
| [App bar](https://github.com/material-components/material-components-android/blob/master/docs/components/TopAppBar.md) | Medium flexible: 112 / 64dp, заголовок `headlineMedium` → `titleLarge`, подзаголовок-дата под заголовком |
| [Search](https://github.com/material-components/material-components-android/blob/master/docs/components/Search.md) | `SearchAnchor.bar` 56dp, форма full, `surfaceContainerHigh` |
| [Button group](https://github.com/material-components/material-components-android/blob/master/docs/components/ButtonGroup.md) | Connected button group вместо устаревшего segmented button: зазор 2dp, внутренние углы 8 / 4 / 50% |
| [Buttons](https://github.com/material-components/material-components-android/blob/master/docs/components/CommonButton.md), [icon buttons](https://github.com/material-components/material-components-android/blob/master/docs/components/IconButton.md) | Размеры Small (40dp, `labelLarge`, отступы 16) и Medium (56dp, `titleMedium`, 24); форма full морфится в скруглённый прямоугольник при нажатии |
| [FAB](https://github.com/material-components/material-components-android/blob/master/docs/components/FloatingActionButton.md), [extended FAB](https://github.com/material-components/material-components-android/blob/master/docs/components/ExtendedFloatingActionButton.md) | `primaryContainer` по умолчанию, тень 6dp, small extended — `titleMedium`, отступы 16 / 8 / 16 |
| [Lists](https://github.com/material-components/material-components-android/blob/master/docs/components/List.md) | Segmented-список в профиле: углы 16 / 4dp, зазор 2dp, без разделителей |
| [Chips](https://github.com/material-components/material-components-android/blob/master/docs/components/Chip.md) | Filter chip 32dp, выбранный — `secondaryContainer` без обводки, невыбранный — обводка `outline` |
| [Cards](https://github.com/material-components/material-components-android/blob/master/docs/components/Card.md), [bottom sheet](https://github.com/material-components/material-components-android/blob/master/docs/components/BottomSheet.md) | Outlined card на `surface`; шит `surfaceContainerLow`, ручка `onSurfaceVariant` 32×4 |
| [Switch](https://github.com/material-components/material-components-android/blob/master/docs/components/Switch.md), [checkbox](https://github.com/material-components/material-components-android/blob/master/docs/components/Checkbox.md), [snackbar](https://github.com/material-components/material-components-android/blob/master/docs/components/Snackbar.md), [divider](https://github.com/material-components/material-components-android/blob/master/docs/components/Divider.md) | Совпадают с токенами MDC |
| [Tooltip](https://github.com/material-components/material-components-android/blob/master/docs/components/Tooltip.md) | По `Widget.Material3.Tooltip`: `primary` / `onPrimary`, `bodySmall`, минимум 28dp |
| Доступность | `Semantics`, зона нажатия ≥ 48dp, шрифт до 200% без переполнений, контраст статусов проверяется тестом |

Состояние — Riverpod (`Notifier`), настройки переживают перезапуск через `shared_preferences`.

---

## Сознательные отступления от спеки

1. **`DynamicSchemeVariant.expressive` заметно поворачивает оттенок сида.**
   Фактические значения: violet `#6B3FD4` → primary `#006B5A`, blue `#1F5FD0` → `#306A39`,
   green `#1E6B4E` → `#914C24`, coral `#A93B4F` → `#286294`. Вариант оставлен по §4.1,
   поэтому палитры подписаны по итоговому цвету («Бирюзовая», «Зелёная», «Терракотовая»,
   «Синяя»), а кружок в выборе палитры показывает итоговый `primary`, а не сид.
   Имена элементов `AppPalette` при этом остались как в макете. Переключается одной
   константой `AppColorSchemes.variant`.

2. **Радиусы карточек 28dp / 32dp вместо `medium` (12dp).**
   Согласовано как expressive-решение; закреплено в `AppShapes.card` и `AppShapes.cardEmphasized`.

3. **Статусные цвета справок — `ThemeExtension<StatusColors>`.**
   В M3 нет ролей `warning` / `success`. Значения взяты из макета; контраст текста к контейнеру
   ≥ 4.5:1 в обеих темах — проверяется в `test/status_contrast_test.dart`.

4. **Три компонента написаны вручную, потому что Flutter 3.44 их не поставляет.**
   Проверено по исходникам SDK:
   - `LoadingIndicator` в `packages/flutter/lib/src/material/` отсутствует → `M3LoadingIndicator`;
   - `LinearProgressIndicator` умеет `year2023: false`, `trackGap`, `stopIndicator*`, но не волнистый
     вариант → `M3WavyLinearProgress`;
   - `RefreshIndicator` рисует собственную шкалу и не даёт её заменить → `M3PullToRefresh`.

5. **Пружины заданы вручную.**
   `MotionScheme` / `MotionTheme` в 3.44 ещё нет (`motion.dart` содержит только `Durations` и
   `Easing`), поэтому `AppMotion` строит `SpringDescription.withDampingRatio` и оборачивает
   симуляцию в `SpringCurve`, чтобы пружины работали и в неявных анимациях.

6. **Размер формы индикатора — 34dp, а не 38dp из таблицы в документации MDC.**
   Таблица берёт `dimens.xml`, но стиль `Widget.Material3.LoadingIndicator`, от которого
   наследуются оба варианта, задаёт 34dp — взято фактическое значение из кода.

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

12. **Navigation bar и фильтр задач отличаются от §7.3 / §7.5 промта.**
    Промт описывал baseline M3 (навбар 80dp с индикатором 64×32, segmented button). По
    документации MDC Expressive навбар стал 64dp с индикатором 56×32, а segmented button
    устарел и заменён connected button group.

13. **Индикатор navigation bar сужен формой, а не шириной.**
    Flutter рисует индикатор в фиксированной рамке 64×32 (`_kIndicatorWidth`) и ширину не
    настраивает. `NavigationIndicatorBorder` сужает таблетку до 56dp внутри рамки — фон и
    ripple рисуются по этой форме, стандартная доступность `NavigationBar` сохраняется.

14. **Контейнер segmented-списка — `surfaceContainer`, а не `surface`.**
    По токену пункт `surface`, а в каталоге MDC список лежит на подложке
    `surfaceContainerHigh`. Фон вкладок здесь сам `surface`, поэтому пункт на тон темнее —
    иначе сегменты сливались бы с фоном.

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
  pull_to_refresh_test.dart  протяжка, обновление и откат индикатора покадрово
  screenshot_generator.dart  генератор PNG в docs/screenshots (не тест)
```



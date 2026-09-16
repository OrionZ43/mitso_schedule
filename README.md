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
flutter test      # 49 тестов
dart format lib test
```

### Скриншоты

```bash
flutter test test/screenshot_generator.dart
```

Кладёт PNG всех четырёх вкладок в светлой и тёмной теме, субботы, шита
отправки справки, пары подгрупп и страницы подробностей в `docs/screenshots/`.
Генератор рендерит настоящим движком Flutter и сам подгружает Roboto и Material
Symbols через `FontLoader` — иначе тестовая среда рисует текст и иконки
прямоугольниками. Тени включены (`debugDisableShadows = false`): по умолчанию
тесты рисуют их сплошными чёрными блоками.

| | |
|---|---|
| ![Расписание](docs/screenshots/1-schedule-light.png) | ![Пропуски](docs/screenshots/2-absences-light.png) |
| ![Заметки](docs/screenshots/3-notes-light.png) | ![Профиль](docs/screenshots/4-profile-light.png) |
| ![Подгруппы](docs/screenshots/7-subgroups-light.png) | ![Подробности пары](docs/screenshots/8-lesson-details-light.png) |

### Проверки с сетью

Обычные тесты в сеть не ходят: сайт подменён сохранённой страницей 2423 УИР
(`test/fixtures`). С живым сайтом:

```bash
flutter test test/live/mitso_live_check.dart                  # на компьютере
flutter test integration_test/mitso_tls_test.dart -d <телефон>  # на Android
```

Второй тест проверяет на устройстве, что без вложенных сертификатов соединение
падает, а с ними расписание загружается. Экран телефона должен быть включён и
разблокирован: Android 15+ закрывает сеть приложениям не на переднем плане, и
тест упадёт с `Failed host lookup`.

> **После integration-теста пересоберите приложение.** `flutter test integration_test/…`
> собирает `app-debug.apk` с тестом вместо `lib/main.dart`, а `flutter install` ставит
> последний собранный APK. Запущенная из лаунчера тестовая сборка ждёт команд от компьютера
> и не рисует ни одного кадра — приложение висит на сплэше. Перед установкой:
> `flutter build apk --debug -t lib/main.dart` (или просто `flutter run`).

---

## Источник данных: apps.mitso.by

Расписание открытое, вход не нужен.

- **Сайт на Yii2.** POST-запросы защищены CSRF-токеном, привязанным к сессии:
  сначала GET страницы формы даёт cookie и `<meta name="csrf-token">`.
- **Выбор группы** — цепочка виджета Krajee DepDrop:
  `schedule/education` → `schedule/course` → `schedule/group`, ответы JSON
  `{"output":[{"id","name"}]}`. Факультеты лежат прямо в разметке формы.
  Идентификаторы — транслит: ``E`konomicheskij``, `Dnevnaya`, `3 kurs`, `2423 UIR`.
- **Расписание** — один POST на `schedule/group-schedule` возвращает сразу
  текущую и следующую неделю. Параметр недели сервер проверяет только на
  непустоту.
- **Разметка**: `div.weekly-schedule` по неделям, в них `h2` «Понедельник,
  14 сентября» и таблица «Время | Дисциплина и преподаватель | Аудитория».
  Пара — `Название(тип) Фамилия И. О.`, подгруппы — строки `1. …` / `2. …`
  в одно время, пустой слот — `(нет занятий)`. Даты без года.
- **Сертификат**: сервер отдаёт только `*.mitso.by` без промежуточного
  «GlobalSign GCC R46 AlphaSSL CA 2025». Браузеры и Windows докачивают его сами,
  Android — нет. Промежуточный и корень GlobalSign Root R46 лежат в
  `assets/certs` и добавляются к системным; проверка сертификата не отключается.
- Ещё на сайте есть расписание преподавателей, дисциплин и архив прошлых
  недель — пока не используются.
- `student.mitso.by` — лицевой счёт с балансом оплаты (вход по номеру счёта).
  Пропусков и справок там нет, поэтому вкладка «Пропуски» пока на демо-данных.

В приложении расписание кэшируется: сохранённое показывается сразу, свежее
подтягивается в фоне, при ошибке сети остаётся сохранённое с пометкой.
Автоповтор упавших запросов отключён, чтобы не нагружать сайт.

Строки подгрупп в одно время объединяются в одну пару (`ScheduleDay.slots`):
одна карточка, внутри — преподаватель и аудитория каждой подгруппы. В профиле
можно выбрать свою подгруппу — строки другой скрываются.

---

## Что сделано по гайдлайнам

Компоненты сверены с документацией и токенами
[material-components-android](https://github.com/material-components/material-components-android/tree/master/docs/components)
(`docs/components/*.md` и `lib/.../res/values/*tokens.xml`).

| Компонент | Реализация |
|---|---|
| Цвет | `ColorScheme.fromSeed` с `DynamicSchemeVariant.expressive`, 4 сид-палитры, baseline `#6750A4` при выключенных динамических цветах, `DynamicColorBuilder` на Android 12+ |
| Типографика, форма | Полная `TextTheme` по токенам на системном Roboto (ничего не скачивается), шкала радиусов M3 |
| Движение компонентов | Шесть пружинных токенов Expressive; какой токен у какого свойства — как в Compose Material3 (см. «Движение» ниже) |
| [Переходы](https://m3.material.io/styles/motion/transitions/transition-patterns) | Fade through — вкладки, загрузка → главный экран, загрузка → список; shared axis X — смена дня и шаги выбора группы; container transform — карточка пары → подробности |
| [Loading indicator](https://github.com/material-components/material-components-android/blob/master/docs/components/LoadingIndicator.md) | Порт MDC: `MaterialShapes` и `Morph` из `material_new_shapes`, пружина 200 / 0.6, поворот 50° + 90° за шаг 650 мс, contained — `onPrimaryContainer` на `primaryContainer` |
| [Progress indicator](https://github.com/material-components/material-components-android/blob/master/docs/components/ProgressIndicator.md) | Волнистый determinate: 4dp, амплитуда 3dp, волна 40dp, зазор 4dp, stop indicator 4dp; волна неподвижна, полная амплитуда только при 0.1–0.9 |
| [Navigation bar](https://github.com/material-components/material-components-android/blob/master/docs/components/BottomNavigation.md) | Expressive: высота 64dp, индикатор 56×32 `secondaryContainer`, активная подпись `secondary` |
| [App bar](https://github.com/material-components/material-components-android/blob/master/docs/components/TopAppBar.md) | Medium flexible: 112 / 64dp, заголовок `headlineMedium` → `titleLarge`, подзаголовок (группа и курс) под заголовком |
| [Search](https://github.com/material-components/material-components-android/blob/master/docs/components/Search.md) | `SearchAnchor.bar` 56dp, форма full, `surfaceContainerHigh` |
| [Button group](https://github.com/material-components/material-components-android/blob/master/docs/components/ButtonGroup.md) | Connected button group вместо устаревшего segmented button: зазор 2dp, внутренние углы 8 / 4 / 50% |
| [Buttons](https://github.com/material-components/material-components-android/blob/master/docs/components/CommonButton.md), [icon buttons](https://github.com/material-components/material-components-android/blob/master/docs/components/IconButton.md) | Размеры Small (40dp, `labelLarge`, отступы 16) и Medium (56dp, `titleMedium`, 24); форма full морфится в скруглённый прямоугольник при нажатии |
| [FAB](https://github.com/material-components/material-components-android/blob/master/docs/components/FloatingActionButton.md), [extended FAB](https://github.com/material-components/material-components-android/blob/master/docs/components/ExtendedFloatingActionButton.md) | `primaryContainer` по умолчанию, тень 6dp, small extended — `titleMedium`, отступы 16 / 8 / 16 |
| [Lists](https://github.com/material-components/material-components-android/blob/master/docs/components/List.md) | Segmented-список в профиле, выборе группы, подробностях пары и строках подгрупп: углы 16 / 4dp, зазор 2dp, без разделителей |
| [Chips](https://github.com/material-components/material-components-android/blob/master/docs/components/Chip.md) | Filter chip 32dp, выбранный — `secondaryContainer` без обводки, невыбранный — обводка `outline` |
| [Cards](https://github.com/material-components/material-components-android/blob/master/docs/components/Card.md), [bottom sheet](https://github.com/material-components/material-components-android/blob/master/docs/components/BottomSheet.md) | Предстоящая пара — outlined card на `surface`, идущая — `primary`, прошедшая — тональная `surfaceContainerLow`; шит `surfaceContainerLow`, ручка `onSurfaceVariant` 32×4 |
| [Switch](https://github.com/material-components/material-components-android/blob/master/docs/components/Switch.md), [checkbox](https://github.com/material-components/material-components-android/blob/master/docs/components/Checkbox.md), [snackbar](https://github.com/material-components/material-components-android/blob/master/docs/components/Snackbar.md), [divider](https://github.com/material-components/material-components-android/blob/master/docs/components/Divider.md) | Совпадают с токенами MDC |
| [Tooltip](https://github.com/material-components/material-components-android/blob/master/docs/components/Tooltip.md) | По `Widget.Material3.Tooltip`: `primary` / `onPrimary`, `bodySmall`, минимум 28dp |
| Доступность | `Semantics`, зона нажатия ≥ 48dp, шрифт до 200% без переполнений, контраст статусов проверяется тестом |

Состояние — Riverpod (`Notifier`), настройки переживают перезапуск через `shared_preferences`.

### Движение

Ничего не подбиралось на глаз — источники:

- **Пружины** (`AppMotion`) — значения `ExpressiveMotionTokens.kt` из Compose Material3:
  FastSpatial 800 / 0.6, DefaultSpatial 380 / 0.8, SlowSpatial 200 / 0.8, FastEffects 3800 / 1,
  DefaultEffects 1600 / 1, SlowEffects 800 / 1.
- **Какой токен где** — как у аналогичного компонента в исходниках Compose Material3:

  | Где | Свойство | Токен | Образец |
  |---|---|---|---|
  | День в ленте | форма | FastSpatial | `ToggleButton.kt` — форма при выборе |
  | День в ленте | цвет | DefaultEffects | `ToggleButton.kt` — цвет обводки |
  | Connected button group | ширина и форма / цвет | FastSpatial / DefaultEffects | `ButtonGroup.kt`, `ToggleButton.kt` |
  | Кнопки, icon buttons | форма при нажатии | DefaultEffects — намеренно без отскока | `Button.kt`, `IconButton.kt` |
  | Pull-to-refresh | откат, прозрачность | DefaultEffects | `PullToRefresh.kt` |

- **Переходы** — паттерны из MDC `docs/theming/Motion.md`, числа из исходников
  `com.google.android.material.transition` и M3-темы (таблицы в самом Motion.md остались от M2):

  | Паттерн | Где | Параметры |
  |---|---|---|
  | Fade through (`MaterialFadeThrough`) | вкладки navigation bar, загрузка → главный экран, загрузка → список | 450 мс (`motionDurationLong1`), emphasized; уход до 35% прогресса, появление после, масштаб 92% → 100% |
  | Shared axis X (`MaterialSharedAxis`) | смена дня (кнопкой, свайпом, из поиска), шаги выбора группы | 450 мс, emphasized, сдвиг 30dp, прозрачность как у fade through; назад — зеркально |
  | Container transform (`MaterialContainerTransform`) | карточка пары → подробности | 500 мс (`motionDurationLong2`), `OpenContainer` из `package:animations` |

  Fade through и shared axis портированы в `lib/theme/app_transitions.dart`, переключением
  детей управляет `PageTransitionSwitcher` из `package:animations`.

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

7. **Emphasized-начертание — вес w700 системного Roboto.**
   Шрифт не скачивается и не лежит в ассетах, поэтому осей Roboto Flex нет — остаётся вес.

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

15. **Container transform — на кривой M2 и с одной длительностью.**
    `OpenContainer` внутри использует `Curves.fastOutSlowIn` и одну `transitionDuration` на оба
    направления; в MDC M3 — emphasized, 500 мс на открытие и 400 мс на возврат. Взята
    длительность открытия.

16. **`package:animations` закреплён на 2.x.**
    3.0.0 собран на `material_ui` вместо `package:flutter/material.dart` (как `dynamic_color` 2.x):
    с Flutter 3.44 он не компилируется, а его `Material` не видел бы тему приложения.

17. **Пульсирующая точка «Сейчас идёт» — элемент макета, а не спеки.**
    Для бесконечной пульсации токена движения нет; анимируется только прозрачность, без перелёта.

---

## Структура

```
lib/
  main.dart                  ProviderScope, SharedPreferences, intl
  app.dart                   MaterialApp, темы, локаль ru_RU, экран загрузки
  theme/                     цвет, типографика, формы, движение, статусные цвета
  data/                      модели, клиент и разбор apps.mitso.by, демо-данные пропусков
  state/                     Riverpod-контроллеры
  features/                  boot, home, schedule (+ подробности пары), group_picker,
                             absences, notes, profile
  widgets/                   M3LoadingIndicator, M3WavyLinearProgress,
                             M3PullToRefresh, DaySelector, LessonCard, …
test/
  app_test.dart              вкладки, подгруппы, свайп дня, подробности пары,
                             выбор группы, задачи, справки, тема, шрифт 200%
  indicators_geometry_test.dart  геометрия форм и волнистой шкалы
  status_contrast_test.dart  контраст статусных цветов
  pull_to_refresh_test.dart  протяжка, обновление и откат индикатора покадрово
  screenshot_generator.dart  генератор PNG в docs/screenshots (не тест)
```



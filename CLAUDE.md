# Расписание МИТСО — правила работы

Flutter-приложение для Android: расписание студентов МИТСО с apps.mitso.by.
Интерфейс на русском, дизайн — **Material 3 Expressive строго по гайдлайнам Google**.

## Главное правило дизайна

Ни один элемент интерфейса, анимация или взаимодействие не придумываются «на
глаз». Прежде чем добавить или поменять компонент:

1. Открыть его раздел в [`docs/m3/`](docs/m3/README.md) — там ссылки, ключевые
   токены, поведение, текущее состояние в приложении и известные расхождения.
2. Сверить с первоисточниками (порядок — от главного):
   - **m3.material.io** — Guidelines / Specs / Accessibility компонента. Сайт
     рендерится скриптом, поэтому текст выгружается скриптом:
     `python tool/m3_guidelines.py` (всё) или
     `python tool/m3_guidelines.py components/switch` (страница) →
     `.m3-guidelines/<slug>.md` с правилами Do/Don't и таблицами токенов.
   - **Compose Material3** — эталонная реализация Expressive: размеры, формы,
     какой токен `MotionScheme` что анимирует, взаимодействия (например,
     расширение нажатой кнопки в группе). API:
     https://developer.android.com/reference/kotlin/androidx/compose/material3/package-summary
     Исходники (частичный клон, ~2 минуты):
     ```bash
     git clone --filter=blob:none --no-checkout https://github.com/androidx/androidx.git ax
     cd ax && git config core.longpaths true
     git sparse-checkout set --no-cone compose/material3/material3/src/commonMain compose/material3/material3/samples
     git checkout
     ```
     Компоненты — `compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/*.kt`,
     токены — `.../material3/tokens/*.kt`, примеры — `compose/material3/material3/samples`.
   - **MDC-Android** — https://github.com/material-components/material-components-android/tree/master/docs
     (`docs/components/*.md`, `docs/theming/Motion.md`) и исходники
     `lib/java/com/google/android/material/**` для значений, которых нет выше.
3. Если Flutter-виджет расходится с Compose (размеры, анимации, состояния) —
   портировать поведение Compose, а не мириться с дефолтом Flutter.
4. Каждое отступление от спеки — осознанное: записать причину в `docs/m3/`
   и в раздел «Сознательные отступления» README.
5. После изменения компонента обновить его раздел в `docs/m3/`.

## Движение

- Пружины `AppMotion` (`lib/theme/app_motion.dart`) = `ExpressiveMotionTokens` из
  Compose. Какой токен у какого свойства — смотреть в исходнике аналогичного
  компонента Compose (`MotionSchemeKeyTokens.*`), не выбирать самому.
- Переходы между экранами/состояниями — паттерны из `lib/theme/app_transitions.dart`
  (порт `com.google.android.material.transition`).

## Проверки перед коммитом

```bash
dart format lib test
flutter analyze
flutter test
flutter test test/screenshot_generator.dart      # PNG в docs/screenshots — посмотреть глазами
flutter build apk --release -t lib/main.dart     # -t обязателен, см. README
C:/android/sdk/platform-tools/adb.exe install -r build/app/outputs/flutter-apk/app-release.apk
```

На телефон ставить release: debug-сборка тормозит сама по себе, по ней о плавности не судить.
После изменений анимаций и списков — `flutter test test/perf_probe.dart` (перестройки и
отрисовки за кадр, см. README → «Производительность»).

## Ограничения

- apps.mitso.by: без автоповторов и массовых запросов; проверку TLS не отключать
  (недостающий промежуточный сертификат лежит в `assets/certs`).
- student.mitso.by (лицевой счёт) — только с согласия и данными пользователя.
- Пакеты на `material_ui` (`dynamic_color` 2.x, `animations` 3.x) не подходят:
  не компилируются с Flutter 3.44 и не видят тему `package:flutter/material.dart`.
- Коммиты — по-русски, в конце без строки
  `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`.

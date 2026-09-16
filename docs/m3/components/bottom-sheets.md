# Нижний лист (Bottom sheets)

Статус в приложении: ⚠️ частично

Тема листа совпадает с токенами: `surfaceContainerLow`, верхние углы 28dp, ручка 32×4,
максимальная ширина 640dp. Не совпадают движение (во Flutter 250/200 мс по кривой, в Compose —
пружины), цвет scrim и предиктивный «назад». Лист выбора группы открывается сразу высоким,
а не на половину экрана.

## Источники
- Guidelines / Specs / Accessibility: https://m3.material.io/components/bottom-sheets/guidelines,
  https://m3.material.io/components/bottom-sheets/specs, https://m3.material.io/components/bottom-sheets/accessibility
  (выгрузка: `.m3-guidelines/components__bottom-sheets.md`)
- Compose API: https://developer.android.com/reference/kotlin/androidx/compose/material3/package-summary —
  `ModalBottomSheet(onDismissRequest, modifier, sheetState, sheetMaxWidth, sheetGesturesEnabled, shape, containerColor, contentColor, tonalElevation, scrimColor, dragHandle, contentWindowInsets, properties, content)`,
  `rememberModalBottomSheetState(skipPartiallyExpanded)`, `BottomSheetDefaults.DragHandle()`,
  `BottomSheetDefaults.ExpandedShape` / `ContainerColor` / `Elevation` / `ScrimColor` / `SheetMaxWidth`
- Compose исходник:
  - `ModalBottomSheet.kt`: `ModalBottomSheet`, анимация scrim с `DefaultEffects`;
  - `BottomSheet.kt`: `BottomSheet` — пружины показа, скрытия и доводки, `PredictiveBackHandler`;
    `BottomSheetImpl` — якоря `Hidden` / `PartiallyExpanded` / `Expanded`, гашение скорости у низа;
  - `SheetDefaults.kt`: `SheetState`, `BottomSheetDefaults`, `DragHandleVerticalPadding` = 22dp,
    `PositionalThreshold` = 56dp, `VelocityThreshold` = 125dp, `BoundaryDampeningZone` = 125dp.

  Токены: `tokens/SheetBottomTokens.kt`, `tokens/ScrimTokens.kt`. Пример:
  `samples/BottomSheetSamples.kt`.
- MDC: https://github.com/material-components/material-components-android/blob/master/docs/components/BottomSheet.md
  (`backgroundTint` = `?attr/colorSurfaceContainerLow`, elevation 1dp, `maxWidth` 640dp,
  `behavior_halfExpandedRatio` 0.5, `BottomSheetDragHandleView` 48dp, predictive back; цвет ручки
  `m3_comp_sheet_bottom_docked_drag_handle_color` = `?attr/colorOnSurfaceVariant`)
- Flutter: `showModalBottomSheet`, `BottomSheet`, `BottomSheetThemeData`,
  `DraggableScrollableSheet` (`packages/flutter/lib/src/material/bottom_sheet.dart`).
  - Есть M3-дефолты `_BottomSheetDefaultsM3`: фон `surfaceContainerLow`, elevation 1,
    `maxWidth` 640, ручка 32×4 `onSurfaceVariant` в зоне 48×48 со смысловым действием «закрыть».
    Параметры `sheetAnimationStyle` (длительность и кривая), `barrierColor`, `useSafeArea`.
  - По умолчанию: вход 250 мс, выход 200 мс, кривая `Easing.legacyDecelerate`, scrim
    `Colors.black54`, без `isScrollControlled` высота не больше 9/16 экрана.
  - Нет: пружин, частично раскрытого состояния у модального листа (только через
    `DraggableScrollableSheet`), предиктивного «назад» для листа.

## Когда использовать
- Compact и medium окна. Содержимое — дополнительное, не основное.
- **Standard** существует вместе с основным UI (например, плеер). **Modal** блокирует
  приложение, пока его не закроют. Modal — альтернатива меню и простым диалогам на телефоне,
  особенно для длинных списков действий (Guidelines → Modal bottom sheets).
- В expanded окнах лист можно заменить side sheet.

## Варианты и анатомия
- Standard и modal. Spec у них одинаковый, у modal дополнительно есть scrim.
- Анатомия: контейнер (обязателен), drag handle (необязателен), scrim (только modal). Внутри —
  списки, разделители, медиа.
- Способы закрыть modal: действие внутри, нажатие на scrim, свайп вниз, кнопка закрытия в app bar
  листа. На полноэкранном листе кнопка закрытия обязательна.

## Размеры, формы, цвета
| Элемент | Значение | Источник |
|---|---|---|
| Контейнер | `surfaceContainerLow`, elevation level1 | `md.comp.sheet.bottom.docked.container.color`, `modal.container.elevation`; `SheetBottomTokens` |
| Форма | верхние углы 28dp (`corner.extra-large.top`), в свёрнутом состоянии `corner.none` | `md.comp.sheet.bottom.docked.container.shape`, `minimized.container.shape` |
| Ширина | на всё окно, максимум 640dp. Если окно шире 640dp — поля 56dp сверху и по бокам | Specs → Measurements; `BottomSheetDefaults.SheetMaxWidth` |
| Верхнее поле | 72dp (в окне шире 640dp — 56dp) | Specs → Measurements |
| Ручка | 32×4dp, по центру, 22dp сверху и снизу, `onSurfaceVariant` | `md.comp.sheet.bottom.docked.drag-handle.*`; `SheetBottomTokens.DockedDragHandleWidth` / `Height` / `Color`; `DragHandleVerticalPadding` |
| Scrim (Compose) | `scrim` с непрозрачностью 0.32 | `ScrimTokens.ContainerColor` / `ContainerOpacity`; `BottomSheetDefaults.ScrimColor` |

Прозрачность ручки в источниках расходится:
- в таблице токенов m3.material.io есть `md.comp.sheet.bottom.docked.drag-handle.opacity` = 0.4;
- в `SheetBottomTokens` (Compose) и `bottomsheet/res/values/tokens.xml` (MDC) цвет
  `onSurfaceVariant` без прозрачности.

Для Android-реализаций следуем Compose и MDC. Про scrim Specs → Color оговаривает: «On Android
platforms, the scrim color and opacity is automatically handled by the system UI».

## Состояния и движение
- **Показ** (`BottomSheet.kt`): `showMotionSpec = motionScheme.defaultSpatialSpec()`, то есть
  DefaultSpatial с stiffness 380 и damping 0.8, с перелётом.
- **Скрытие:** `hideMotionSpec = motionScheme.fastEffectsSpec()`, FastEffects с stiffness 3800 и
  damping 1.
- **Доводка после перетаскивания** к якорю: `anchoredDraggableMotionSpec` и fling-поведение —
  `defaultSpatialSpec()`. Пороги: смещение 56dp или скорость 125dp/с. У нижней границы скорость
  затухает квадратично в зоне 125dp, чтобы пружина не «пробивала» низ (`BoundaryDampeningZone`).
- **Scrim:** прозрачность анимируется через `animateFloatAsState(MotionSchemeKeyTokens.DefaultEffects)`
  (`ModalBottomSheet.kt`).
- **Высоты:** если содержимое выше половины экрана и `skipPartiallyExpanded = false`, лист
  открывается частично (`PartiallyExpanded`), а дальше его тянут до полного. Guidelines →
  Visibility: начальная позиция modal — не выше 50% высоты экрана, дальше лист тянется на весь
  экран с внутренней прокруткой.
- **Предиктивный «назад»:** `PredictiveBackHandler` масштабирует лист по прогрессу жеста
  (`PredictiveBack.transform`). При отпускании лист частично сворачивается или закрывается
  (`settleToDismiss`). Guidelines → Back: лист отходит от краёв экрана и открывает превью.
- **Ручка:** перетаскивание меняет высоту. Нажатие переключает предустановленные высоты или
  закрывает лист. Нажатие на scrim всегда закрывает лист.

## Доступность
- Когда доступно изменение размера и есть ручка, верхние 48dp листа интерактивны.
- Ручка фокусируется с клавиатуры: Tab ставит фокус, Space или Enter переключают высоты. Роль
  ручки — button, подписывается только она.
- Для каждого действия перетаскиванием нужна альтернатива одним касанием.

## В приложении
- Где используется:
  - `lib/app.dart` → `bottomSheetTheme`: `surfaceContainerLow`, углы 28dp сверху, ручка
    `onSurfaceVariant` 32×4, `showDragHandle: true`;
  - `lib/theme/app_shapes.dart` → `AppShapes.bottomSheetShape`;
  - `lib/features/group_picker/group_picker_sheet.dart` → `showGroupPicker`: `isScrollControlled`,
    `useSafeArea`, `maxHeight` 85% экрана, шаги внутри сменяются через shared axis X, есть кнопка
    «Назад»;
  - `lib/features/absences/widgets/certificate_sheet.dart` → `showCertificateSheet`: форма с
    фото, «Отмена» и «Отправить».
- Уже соответствует:
  - цвет, форма и ручка (по Compose и MDC);
  - elevation 1 и ширина до 640dp — дефолты Flutter M3;
  - ручка 22dp сверху и снизу за счёт зоны 48×48;
  - закрытие по scrim и свайпом;
  - в листе справки отменяющее действие слева от подтверждающего.
- Расхождения:
  1. **Движение показа и скрытия.** Сейчас дефолт Flutter: 250 мс вход и 200 мс выход,
     `legacyDecelerate`. Должно: показ пружиной DefaultSpatial (380 / 0.8), скрытие FastEffects
     (3800 / 1), доводка DefaultSpatial. Источник: `BottomSheet.kt` → `showMotionSpec`,
     `hideMotionSpec`, `anchoredDraggableMotionSpec`.
  2. **Scrim.** Сейчас `Colors.black54` без привязки к схеме, линейное появление по анимации
     маршрута. Должно: `colorScheme.scrim` с альфой 0.32, прозрачность пружиной DefaultEffects.
     Источник: `ScrimTokens`, `ModalBottomSheet.kt`.
  3. **Начальная высота листа выбора группы.** Сейчас лист открывается по высоте содержимого до
     85% экрана. Должно: не выше 50% экрана, затем тянется на весь экран с внутренней прокруткой,
     верхнее поле 72dp. Источник: Guidelines → Visibility; Specs → Measurements; `SheetState`
     (`PartiallyExpanded`).
  4. **Предиктивный «назад».** Сейчас нет: системный «назад» просто закрывает лист. Должно: лист
     уменьшается по прогрессу жеста и закрывается по завершении. Источник: Guidelines → Back;
     `BottomSheet.kt` → `PredictiveBackHandler`.
  5. **Смысловая метка ручки.** Во Flutter у ручки `modalBarrierDismissLabel` и действие
     «закрыть». По Accessibility у ручки роль button, а нажатие переключает высоты. Пока у листов
     нет промежуточных высот, закрытие допустимо. После пункта 3 ручка должна переключать 50% и
     полную высоту.
- Что сделать во Flutter:
  1. Единая функция `showM3ModalBottomSheet` в `lib/widgets/`, обёртка над `showModalBottomSheet`:
     - `barrierColor: scheme.scrim.withValues(alpha: 0.32)`;
     - `sheetAnimationStyle: AnimationStyle(duration: AppMotion.defaultSpatial.duration, curve: AppMotion.defaultSpatial.curve, reverseDuration: AppMotion.fastEffects.duration, reverseCurve: AppMotion.fastEffects.curve)`.

     `SpringCurve` из `app_motion.dart` воспроизводит перелёт пружины. Кривая scrim во Flutter
     привязана к анимации маршрута, поэтому отдельная пружина DefaultEffects для scrim —
     допустимое упрощение: записать в README.
  2. Лист выбора группы: `isScrollControlled: true`, содержимое внутри
     `DraggableScrollableSheet(initialChildSize: 0.5, minChildSize: 0.5, maxChildSize: 1.0, snap: true, snapSizes: [0.5, 1.0], expand: false)`.
     Прокрутка списка идёт через переданный `scrollController`. `maxHeight` 85% убрать, сверху
     оставить поле 72dp от верха окна.
  3. Доводку `DraggableScrollableSheet` к 0.5 или 1.0 пружиной DefaultSpatial делать через
     `DraggableScrollableController.animateTo(size, duration: AppMotion.defaultSpatial.duration, curve: AppMotion.defaultSpatial.curve)`
     в обработчике окончания жеста. У встроенного snap своя физика.
  4. Предиктивный «назад». Во Flutter `TransitionRoute` реализует `PredictiveBackRoute`
     (`handleStartBackGesture` / `handleUpdateBackGestureProgress` / `handleCommitBackGesture` в
     `widgets/routes.dart`), но жест подключается через page transitions
     (`predictive_back_page_transitions_builder.dart`). Работу с маршрутом листа нужно проверить
     на устройстве. Цель — масштабировать лист по прогрессу жеста, как в `PredictiveBack.transform`
     (Compose). Если без своего маршрута не получается, записать это как отступление.
  5. Ручку оставить из темы. После пункта 2 дать ей `Semantics(button: true, label: 'Изменить высоту листа')`
     и по нажатию переключать 0.5 ↔ 1.0.

# Плавающая кнопка действия (Floating action button, FAB)

Статус в приложении: ⚠️ частично

## Источники
- Guidelines / Specs / Accessibility: https://m3.material.io/components/floating-action-button/guidelines (и /specs, /accessibility); дамп `.m3-guidelines/components__floating-action-button.md`
- Compose API: https://developer.android.com/reference/kotlin/androidx/compose/material3/package-summary — `FloatingActionButton`, `MediumFloatingActionButton`, `LargeFloatingActionButton`, `SmallFloatingActionButton` (не рекомендуется), `FloatingActionButtonDefaults.shape/mediumShape/largeShape/containerColor/elevation()/loweredElevation()/MediumIconSize/LargeIconSize`, `Modifier.animateFloatingActionButton(visible, alignment, targetScale, scaleAnimationSpec, alphaAnimationSpec)`
- Compose исходник: `FloatingActionButton.kt` (`FloatingActionButton` → `Surface`; `FloatingActionButtonElevation.animateElevation`; `FabVisibleModifier`/`FabVisibleNode` — показ и скрытие); токены `FabBaselineTokens.kt`, `FabMediumTokens.kt`, `FabLargeTokens.kt`, `FabSmallTokens.kt`, `FabPrimaryContainerTokens.kt`, `FabSecondaryContainerTokens.kt`; пример `FloatingActionButtonSamples.kt` (`AnimatedFloatingActionButtonSample`)
- MDC: https://github.com/material-components/material-components-android/blob/master/docs/components/FloatingActionButton.md (цвета через `ThemeOverlay.Material3Expressive.FloatingActionButton.{Primary, Secondary, Tertiary, PrimaryContainer, …}`)
- Flutter: `FloatingActionButton` (+`.small`, `.large`) в `floating_action_button.dart`; дефолты `_FABDefaultsM3`: 56dp / 16dp, small 40dp / 12dp, large 96dp / 28dp, иконка 24/24/36dp, тень 6 (hover 8), primaryContainer. **Нет** medium FAB (80dp) и анимации показа/скрытия как `animateFloatingActionButton`.

## Когда использовать
- Самое важное конструктивное действие экрана: создать, в избранное, поделиться, запустить процесс. Не для второстепенных и деструктивных действий (архив, удаление, ошибки, громкость).
- Один FAB на экран; на некоторых экранах FAB не нужен.
- Размеры: **FAB** — самый маленький, для компактных окон, где на экране есть другие действия; **medium FAB** — «most recommended», для большинства случаев, компактных и средних окон («Use a medium FAB for mobile layouts»); **large FAB** — когда действие должно быть очень заметным, лучше на больших окнах. **Small FAB больше не рекомендуется**.
- Иконка — понятная и **filled** (не outlined). На FAB нельзя ставить бейджи.
- Место: в компактных и средних окнах — правый нижний угол; в expanded — вверху слева (в navigation rail).
- Если нужно несколько связанных действий — FAB menu; если нужна подпись — extended FAB.

## Варианты и анатомия
- Варианты: FAB, medium FAB, large FAB (small — baseline, не рекомендуется).
- Цвета (Expressive): primary container (по умолчанию), secondary container, tertiary container, а также primary, secondary, tertiary. Surface-FAB не рекомендуется.
- Анатомия: контейнер, иконка.

## Размеры, формы, цвета
| Вариант | Контейнер | Форма | Иконка |
|---|---|---|---|
| FAB | 56×56dp | `corner.large` 16dp | 24dp |
| Medium FAB | 80×80dp | `corner.large-increased` 20dp | 28dp |
| Large FAB | 96×96dp | `corner.extra-large` 28dp | 36dp (m3 `md.comp.fab.large.icon.size`; в Compose `LargeIconSize = 36.dp` с TODO про неверный `FabLargeTokens.IconSize` = 32dp) |
| Small FAB (не рекоменд.) | 40×40dp | `corner.medium` 12dp | 24dp |

| Цветовой стиль | Контейнер / иконка | State layer |
|---|---|---|
| Primary container (по умолчанию) | primaryContainer / onPrimaryContainer | onPrimaryContainer |
| Secondary container | secondaryContainer / onSecondaryContainer | onSecondaryContainer |
| Primary | primary / onPrimary | onPrimary |

- Тень: level3 (6dp) в покое, в pressed и focused; level4 (8dp) при hover. Lowered-вариант: level1 / hover level2 (`FloatingActionButtonDefaults.loweredElevation`).
- State layer: hover 8%, focus 10%, pressed 10%. Цвет state layer = цвету иконки («make sure the state layer color is the same as the icon color»).

## Состояния и движение
- Нажатие: форма **не морфится** (в `FloatingActionButton.kt` статичный `shape`); меняется state layer, тень анимируется `animateElevation`.
- **Появление**: FAB разворачивается из центральной точки, иконку тоже можно анимировать. Compose — `Modifier.animateFloatingActionButton`: масштаб от `ShowHideTargetScale = 0.2f` до 1 с опорной точкой по `alignment`, пружина `motionScheme.fastSpatialSpec()`; прозрачность — `fastEffectsSpec()`. Пока `alpha == 0`, узел занимает 0×0.
- **Вкладки**: при смене вкладки FAB коротко исчезает и появляется, когда новый контент встал на место; **не анимировать FAB вместе с контентом**.
- **Прокрутка**: FAB остаётся на месте.
- **Раскрытие**: FAB может превратиться в поверхность паттерном container transform или раскрыться в FAB menu.

## Доступность
- Не делать FAB disabled: если действие недоступно, FAB не показывать.
- Контраст иконки с контейнером ≥ 3:1.
- В порядке фокуса FAB — приоритетный элемент (после app bar и navigation bar).
- Метка доступности описывает действие («Написать сообщение»). На вебе при фокусе/наведении — tooltip.
- Клавиатура: Tab — фокус, Space/Enter — действие.

## В приложении
- Где используется:
  - `lib/features/notes/notes_screen.dart`: `FloatingActionButton(onPressed: …add, tooltip: 'Добавить задачу', child: Icon(Symbols.add))` в `Scaffold` вкладки.
  - Тема: `lib/app.dart` → `floatingActionButtonTheme`: `elevation: 6`, primaryContainer / onPrimaryContainer, `shape: 16dp` (`AppShapes.fab`).
- Совпадает: 56dp, 16dp, иконка 24dp, primary container, тень level3 / hover level4 (дефолты Flutter), правый нижний угол с отступом 16dp, единственный FAB на экране, метка действия, конструктивное действие «добавить».
- Расхождения:
  1. Размер: сейчас FAB 56dp → для мобильного макета рекомендован medium FAB 80dp / 20dp / иконка 28dp → Guidelines «Usage» и «Adaptive design». 56dp допустим («компактные окна с другими действиями»), поэтому это рекомендация, а не ошибка. Решение записать.
  2. Смена вкладок: сейчас FAB живёт внутри `Scaffold` вкладки, которая целиком проходит fade through (`FadeThroughStack` в `lib/features/home/home_shell.dart`, входящая вкладка масштабируется от `AppTransitions.fadeThroughStartScale = 0.92`) — FAB анимируется вместе с контентом → FAB отдельно скрывается и показывается → Guidelines «Moving across tabs»: «Don't animate the FAB with body content»; Compose `Modifier.animateFloatingActionButton`.
  3. Тема задаёт `shape: 16dp` для всех FAB, включая `FloatingActionButton.large`, которому нужно 28dp. Сейчас large не используется — отметить на будущее.
- Что сделать во Flutter:
  1. Если выбрать medium FAB: `FloatingActionButton` с `FloatingActionButtonThemeData(sizeConstraints: BoxConstraints.tightFor(width: 80, height: 80), iconSize: 28, shape: AppShapes.rounded(AppShapes.largeIncreased))` — локально через `Theme` или в теме, если FAB в приложении только такой.
  2. Вынести FAB из вкладок в `Scaffold` `HomeShell` (`floatingActionButton` по `_index`) и порт `animateFloatingActionButton`: при смене вкладки старый FAB — `scale 1 → 0.2` (опорная точка — `Alignment.bottomRight`, `AppMotion.fastSpatial.simulate`) и `opacity 1 → 0` (`AppMotion.fastEffects`), затем новый — обратно. Пока прозрачность 0, FAB не занимает место и не принимает касания.
  3. В теме задавать форму по варианту (или не задавать глобально), чтобы large получал 28dp.

### Реализация во Flutter
- Виджеты (`lib/widgets/m3_fab.dart`): `M3Fab` — размеры `M3FabSize.standard` (56dp / 16dp / иконка 24dp), `medium` (80dp / 20dp / 28dp), `large` (96dp / 28dp / 36dp); цвета `M3FabColor` primaryContainer (по умолчанию) / secondaryContainer / tertiaryContainer / primary / secondary / tertiary, содержимое и state layer — on-роль. `M3AnimatedFabVisibility` — порт `Modifier.animateFloatingActionButton`.
- Точно: форма статичная; тень level3 (6dp) в покое / при нажатии / фокусе, level4 (8dp) при hover, анимация `animateElevation` (как у кнопок); размер — минимальный (`sizeIn`), иконка по центру; FAB не бывает disabled (`onPressed` обязателен). Показ/скрытие: масштаб `lerp(0.2, 1, p)` вокруг `alignment`, пружина FastSpatial; прозрачность — FastEffects; при прозрачности ровно 0 узел 0×0, не рисуется и не принимает касаний; первый кадр без анимации; «Удалить анимации» — мгновенно.
- Отступления: (1) у скрытого FAB исключена и семантика (в Compose узел 0×0 остаётся в дереве); (2) слой без запаса 16dp под тень — во Flutter `Transform`/`Opacity` тень не обрезают; (3) small FAB не портирован (не рекомендуется); (4) `tooltip` — обычный Flutter `Tooltip`.
- Экран «Заметки» пока на `FloatingActionButton`; перевод на `M3Fab` + `M3AnimatedFabVisibility` в `HomeShell` — отдельный шаг (пп. 1–3 «Что сделать во Flutter»).

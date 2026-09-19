# Бейдж (Badges)

Статус в приложении: — small badge (точка) на пункте «Профиль» и на значке настроек

Точка горит, пока есть найденное и ещё не показанное обновление приложения. Счётчиков
(large badge) в приложении нет. Виджеты с «Badge» в названии (`LessonTypeBadge`,
`CertificateStatusBadge`, `SubgroupBadge`) — цветные текстовые метки на карточках. По
спецификации это **не бейджи**, решение по ним описано в `chips.md`.

## Источники
- Guidelines / Specs / Accessibility: https://m3.material.io/components/badges/guidelines,
  https://m3.material.io/components/badges/specs, https://m3.material.io/components/badges/accessibility
  (выгрузка: `.m3-guidelines/components__badges.md`)
- Compose API: https://developer.android.com/reference/kotlin/androidx/compose/material3/package-summary —
  `Badge(modifier, containerColor, contentColor, content)`, `BadgedBox(badge, modifier, content)`,
  `BadgeDefaults.containerColor`
- Compose исходник: `Badge.kt` (`BadgedBox` — размещение; константы `BadgeOffset`,
  `BadgeWithContentHorizontalOffset`, `BadgeWithContentVerticalOffset`,
  `BadgeWithContentHorizontalPadding`), токены `tokens/BadgeTokens.kt`, пример
  `samples/BadgeSamples.kt` (`NavigationBarItemWithBadge`)
- MDC: https://github.com/material-components/material-components-android/blob/master/docs/components/BadgeDrawable.md
  (`BadgeDrawable`, `BadgeUtils.attachBadgeDrawable`; файла `Badge.md` нет)
- Flutter: `Badge`, `Badge.count(count, maxCount = 999)` (`material/badge.dart`). Умолчания
  `_BadgeDefaultsM3`: `smallSize` 6, `largeSize` 16, `padding` 4dp по горизонтали, `error` /
  `onError`, `labelSmall`, `alignment: topEnd`. Смещение считается иначе, чем в Compose:
  `Offset(4, -4)` + `(0, 8)` от угла. Совпадение с 6×6 / 14×12 из спеки не проверялось.

## Когда использовать
- Уведомление, количество или другая информация **о пункте навигации**. Ставится на конечный
  край иконки внутри навигационной панели, rail, app bar или вкладок (Guidelines → Usage).
- **Small badge** — точка непрочитанного. **Large badge** — число или короткий статус,
  **не больше 4 символов вместе с «+»**, например «999+» (Guidelines → Label text).
- В тесных местах (app bar) — small badge. Если за иконкой идёт текст — large badge на
  конечном крае (Guidelines → Placement).
- В навигационной панели бейдж скрывают, когда пункт выбран (Guidelines → With other components;
  Accessibility).
- Цвета по умолчанию не меняют, позицию произвольно не двигают. Для RTL бейдж зеркалится.

## Варианты и анатомия
- Small badge: круг без текста.
- Large badge: контейнер и подпись. Ширина растёт с числом символов, высота и позиция не
  меняются.

## Размеры, формы, цвета

| Параметр | Значение | Источник |
|---|---|---|
| Small: размер / форма / цвет | 6dp / `corner.full` (3dp) / `error` | `md.comp.badge.size`, `.shape`, `.color`; `BadgeTokens.Size/Shape/Color` |
| Large: высота / форма / цвет | 16dp / `corner.full` (8dp) / `error` | `md.comp.badge.large.*`; `BadgeTokens.LargeSize/LargeShape/LargeColor` |
| Large: максимум | 16×34dp (4 символа) | Specs → Measurements |
| Подпись | `label-small`, `on-error` | `md.comp.badge.large.label-text.*`; `LargeLabelTextFont/Color` |
| Отступ текста | 4dp | Specs → Measurements; `BadgeWithContentHorizontalPadding` |
| Положение small | 6×6dp от верхнего конечного угла иконки до нижнего начального угла бейджа | Specs; `BadgeOffset` = 6dp |
| Положение large | 14×12dp (В×Ш) от того же угла | Specs; `BadgeWithContentVerticalOffset` = 14dp, `…HorizontalOffset` = 12dp |

## Состояния и движение
- Состояний нет. В разделе Accessibility есть видео: бейдж исчезает после нажатия на пункт.
- В Compose `Badge` и `BadgedBox` ничего не анимируют: бейдж просто появляется или исчезает в
  композиции. Токенов движения для бейджа в источниках нет.

## Доступность
- Контраст бейджа ≥ 3:1. Нужны цвета по умолчанию, а если свои роли — всё равно проверить 3:1
  (Accessibility → Visual indicators).
- Бейдж озвучивается после названия пункта. Числовой бейдж читает число, бейдж без числа —
  «New notification» (Accessibility → Labeling).
- В Compose подпись задаёт вызывающий код: в `BadgeSamples.kt` —
  `Modifier.semantics { contentDescription = "$badgeNumber new notifications" }` и
  `"New notification"`.

## В приложении
**Где используется**
- `lib/widgets/m3_navigation_bar.dart` → `M3NavigationDestination.badgeLabel`: точка на иконке
  пункта, когда `badgeLabel != null`. На выбранном пункте бейдж скрыт (Guidelines → With other
  components), текст `badgeLabel` идёт отдельным `Semantics` после названия пункта
  (Accessibility → Labeling). Сейчас точку зажигает `updateBadgeProvider` — «Доступно
  обновление» на пункте «Профиль» (`lib/features/home/home_shell.dart`).
- `lib/features/profile/profile_screen.dart` → точка на значке настроек в app bar (Guidelines →
  Placement: «в тесных местах — small badge»); tooltip меняется на «Настройки, доступно
  обновление», чтобы screen reader сказал то же самое.
- Положение проверено: у `Badge` без подписи `offset` равен нулю, а `alignment` —
  `topEnd`, поэтому точка 6dp встаёт вплотную к верхнему конечному углу иконки, то есть её
  нижний начальный угол отстоит от этого угла ровно на 6×6dp — как в Specs → Measurements.
  Это верно, только если `Badge` обёрнута вокруг самой иконки 24dp, а не вокруг зоны нажатия
  48dp, — так и сделано в обоих местах.
- Не бейджи, хотя так названы:
  - `lib/widgets/status_badge.dart` → `LessonTypeBadge` («Лекция», «Лаб», «Практика»…) и
    `CertificateStatusBadge` («В обработке» и т. п.);
  - `lib/widgets/lesson_card.dart` → `SubgroupBadge` («1 подгруппа»).

**Расхождения**

| # | Сейчас | Должно быть | Источник |
|---|---|---|---|
| 1 | Метки называются `*Badge`, хотя это текстовые плашки на карточках: не у иконки, не `error`, текст длиннее 4 символов, углы 8dp | Badge — только точка или счётчик у иконки навигации. Для неинтерактивной метки в M3 компонента нет. Варианты (текст или осознанное отступление) — в `chips.md`, раздел «Решение для `status_badge.dart`» | Guidelines → Usage, Label text; `chips.md` |
| 2 | `StatusColors` — фиксированные hex-значения из макета, а в приложении включён динамический цвет | Статусные цвета как **static colors** Material: 4 роли (цвет, on-, container, on-container) из исходного цвета, по желанию гармонизированные с primary схемы | `styles__color__advanced.md` → «Define static colors» |
| 3 | `LessonTypeBadge` на карточке текущей пары: фон `onPrimary` 22 % — альфа не из токенов | Записать как отступление вместе с решением п. 1 | — |

**Что сделать во Flutter**
1. Переименовать метки, чтобы не путать с Badge (например, `LessonTypeLabel`,
   `CertificateStatusLabel`), и выбрать вариант из `chips.md`.
2. Статусные цвета строить из исходного цвета по схеме static colors: четыре роли, как в
   `ColorScheme`. Гармонизировать с динамической схемой через уже подключённый пакет
   `dynamic_color` (`Color.harmonizeWith`). Контраст текста проверяет существующий
   `test/status_contrast_test.dart`.
3. Если понадобится счётчик (например, число задач на вкладке «Заметки»), взять
   `Badge.count(maxCount: 999)` — у него подпись, а значит `offset` уже не нулевой:
   положение нужно сверить с 14×12dp отдельно, у Flutter смещение считается иначе
   (`Offset(4, -4) + Offset(0, 8)`), чем в Compose.

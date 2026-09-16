# Текстовые поля (Text fields)

Статус в приложении: — не используется

Отдельных текстовых полей в приложении нет. `lib/features/absences/widgets/certificate_sheet.dart`
содержит только зону загрузки фото (`_PhotoDropZone`) и кнопки. Единственный ввод текста — поле
внутри поиска (`SearchAnchor.bar`), оно описано в `search.md`: в поиске действуют токены
`md.comp.search-bar.*`, а не токены text field.

## Источники
- Guidelines / Specs / Accessibility: https://m3.material.io/components/text-fields/guidelines,
  https://m3.material.io/components/text-fields/specs, https://m3.material.io/components/text-fields/accessibility
  (выгрузка: `.m3-guidelines/components__text-fields.md`)
- Compose API: https://developer.android.com/reference/kotlin/androidx/compose/material3/package-summary —
  `TextField`, `OutlinedTextField`, `SecureTextField`, `TextFieldDefaults`,
  `OutlinedTextFieldDefaults`, `TextFieldLabelPosition`
- Compose исходник: `TextField.kt`, `OutlinedTextField.kt`, `TextFieldDefaults.kt`,
  `internal/TextFieldImpl.kt`; токены `tokens/FilledTextFieldTokens.kt`,
  `tokens/OutlinedTextFieldTokens.kt`; пример `samples/TextFieldSamples.kt`
- MDC: https://github.com/material-components/material-components-android/blob/master/docs/components/TextField.md
- Flutter: `TextField` / `TextFormField` + `InputDecoration` (`text_field.dart`,
  `input_decorator.dart`); filled (`filled: true`) и outlined (`OutlineInputBorder`).

## Когда использовать
Формы и диалоги, где пользователь вводит текст. Поле должно выглядеть интерактивным, а его
состояние (пустое, заполненное, ошибка) должно быть видно сразу. Подписи и сообщения об ошибках
короткие.

## Варианты и анатомия
Filled и outlined. Анатомия filled: контейнер, ведущая иконка, подпись (в пустом и заполненном
поле), замыкающая иконка, активный индикатор, каретка, введённый текст, поясняющий текст.

## Размеры, формы, цвета

| Элемент | Filled | Outlined |
|---|---|---|
| Высота | 56dp | 56dp |
| Форма | `corner.extra-small.top` | `corner.extra-small` |
| Контейнер | `surfaceContainerHighest` | — |
| Индикатор / обводка | 1dp `onSurfaceVariant`, в фокусе 2dp `primary` | 1dp `outline`, в фокусе 3dp `primary` |
| Подпись | `onSurfaceVariant` | `onSurfaceVariant` |

Источник: `md.comp.filled-text-field.*`, `md.comp.outlined-text-field.*`.

В Compose есть стиль, помеченный в KDoc как «Expressive»: `TextFieldDefaults.roundedShape`
(`CornerMedium`, с пометкой `TODO(b/448727879)`), `TextFieldDefaults.tonalColors()` и
`TextFieldLabelPosition.Inside()`. Примеры `ExpressiveTextFieldSample` и
`ExpressiveConnectedTextFieldsSample` есть только как `@Preview`. На m3.material.io этого нет,
поэтому до появления в гайдлайне не применять.

## Состояния и движение
Compose (`internal/TextFieldImpl.kt`, `TextField.kt`): подпись переходит между позициями с
`FastSpatial`; прозрачность подписи и плейсхолдера — `FastEffects` и `SlowEffects`; цвет
индикатора — `FastEffects`; толщина индикатора — `FastSpatial`.

## Доступность
- Доступное имя = подпись поля, роль textbox. У обязательного поля звёздочка в подписи входит и
  в доступное имя.
- У нажимаемой замыкающей иконки имя описывает действие («Показать пароль» / «Скрыть пароль»).
- Ошибка озвучивается с ролью alert. Если есть и поясняющий текст, сначала читается он, потом
  ошибка. В Compose-примерах используется `semantics { error(...) }`.
- Обводка outlined-поля должна иметь контраст с фоном не ниже 3:1.

## В приложении
Не используется. Если поле понадобится (например, текст новой задачи в `notes_screen.dart`),
начать с filled `TextField` на значениях Flutter по умолчанию, сверить с таблицей выше и
обновить этот файл.

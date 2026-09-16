# Диалоги (Dialogs)

Статус в приложении: — не используется

Диалогов в приложении нет. Отправка справки и выбор группы сделаны модальными bottom sheets —
на телефоне это допустимая замена простому диалогу (bottom-sheets → Modal bottom sheets).

## Источники
- Guidelines / Specs / Accessibility: https://m3.material.io/components/dialogs/guidelines,
  https://m3.material.io/components/dialogs/specs, https://m3.material.io/components/dialogs/accessibility
  (выгрузка: `.m3-guidelines/components__dialogs.md`)
- Compose API: https://developer.android.com/reference/kotlin/androidx/compose/material3/package-summary —
  `AlertDialog(onDismissRequest, confirmButton, modifier, dismissButton, icon, title, text, shape, containerColor, ...)`,
  `BasicAlertDialog`, `AlertDialogDefaults`
- Compose исходник: `AlertDialog.kt` (`AlertDialog`, `AlertDialogContent`, `DialogMinWidth` / `DialogMaxWidth`,
  `IconPadding` / `TitlePadding` = 16dp снизу, `ButtonsMainAxisSpacing`), токены `tokens/DialogTokens.kt`,
  пример `samples/AlertDialogSamples.kt`
- MDC: https://github.com/material-components/material-components-android/blob/master/docs/components/Dialog.md
  (`MaterialAlertDialogBuilder`, basic и full-screen)
- Flutter: `showDialog`, `AlertDialog`, `Dialog`, `Dialog.fullscreen`, `DialogThemeData`
  (`packages/flutter/lib/src/material/dialog.dart`). M3-дефолты: `surfaceContainerHigh`, elevation 6,
  иконка `secondary`, минимальная ширина 280dp. Вход и выход — `FadeTransition` 150 мс
  (`_buildMaterialDialogTransitions`).

## Когда использовать
- Критичная информация или решение, которое блокирует работу: подтверждение рискованного действия.
  Для низкого и среднего приоритета — snackbar (Guidelines → Usage, DON'T).
- **Basic** — одна задача. **Full-screen** — задача из нескольких шагов, только на compact
  экранах. Переход FAB → full-screen dialog делается через container transform.
- Две кнопки: подтверждающая справа, отменяющая слева. Отменяющая кнопка всегда активна.
  Одна кнопка допустима только для «ОК».
- Заголовок — конкретный вопрос, не «Вы уверены?».

## Варианты и анатомия
- Basic: контейнер, иконка (необязательна), заголовок (необязателен), supporting text, разделитель
  (необязателен), кнопки, scrim.
- Full-screen: контейнер, header 56dp с кнопкой закрытия X, заголовок, текстовая кнопка
  подтверждения, разделитель.

## Размеры, формы, цвета
| Элемент | Значение | Источник |
|---|---|---|
| Контейнер basic | `surfaceContainerHigh`, 28dp (`corner.extra-large`), elevation level3 | `md.comp.dialog.container.*`; `DialogTokens` |
| Ширина basic | 280–560dp | Specs → Basic dialog measurements |
| Отступы basic | 24dp по краям; 16dp между заголовком и текстом и между иконкой и заголовком; 24dp до кнопок; 8dp между кнопками | Specs → Basic dialog measurements |
| Текст | заголовок `headlineSmall` `onSurface`; текст `onSurfaceVariant`; кнопки `labelLarge` `primary`; иконка 24dp `secondary` | `md.comp.dialog.*` |
| Выравнивание | с иконкой — по центру, без иконки — по началу строки | Specs |
| Full-screen | `surface`, углы 0, header 56dp с заголовком `titleLarge`; при прокрутке header `surfaceContainer` | `md.comp.full-screen-dialog.*` |

## Состояния и движение
- Появление и исчезновение — паттерн enter and exit (Guidelines → Motion). Отдельного
  `MotionSchemeKeyTokens` в `AlertDialog.kt` нет: анимацию окна задаёт платформенный `Dialog`.

## Доступность
- Фокус переходит в диалог. Scrim закрывает фон. Действия доступны с клавиатуры.

## В приложении
- Не используется. Если понадобится подтверждение (например, удаление задачи), взять `AlertDialog`
  с M3-дефолтами Flutter и проверить отступы 24/16/24 и порядок кнопок по таблице выше.

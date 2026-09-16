# Слайдеры (Sliders)

Статус в приложении: — не используется

## Источники
- Guidelines / Specs / Accessibility: https://m3.material.io/components/sliders/guidelines,
  https://m3.material.io/components/sliders/specs, https://m3.material.io/components/sliders/accessibility
  (выгрузка: `.m3-guidelines/components__sliders.md`)
- Compose API: https://developer.android.com/reference/kotlin/androidx/compose/material3/package-summary —
  `Slider`, `RangeSlider`, `VerticalSlider`, `SliderDefaults`
- Compose исходник: `Slider.kt`, токены `tokens/SliderTokens.kt`, пример `samples/SliderSamples.kt`
  (`SliderSample`, `CenteredSliderSample`, `VerticalSliderSample`, `SliderWithTrackIconsSample`)
- MDC: https://github.com/material-components/material-components-android/blob/master/docs/components/Slider.md
  (стили `Widget.Material3Expressive.Slider.Xsmall` … `.Xlarge`)
- Flutter: `Slider`, `RangeSlider` (`slider.dart`, `range_slider.dart`). При `year2023: false`
  используется оформление 2024 года: трек 16dp, ручка-палочка (`_SliderDefaultsM3`). Размеров S–XL,
  вертикальной ориентации и inset-иконки в `slider.dart` нет.

## Когда использовать
Выбор значения из диапазона, изменение применяется сразу. Слайдер должен показывать весь
диапазон. Варианты: standard, centered, range; конфигурация stops (раньше discrete).

## Варианты и анатомия
Трек (активный и неактивный), ручка, индикаторы остановок, метка значения, inset-иконка (только
standard и толщина трека не меньше 40dp). Ориентация горизонтальная или вертикальная.

## Размеры, формы, цвета (ключевое)

| Размер | Толщина трека | Высота ручки |
|---|---|---|
| XS (по умолчанию) | 16dp | 44dp |
| S | 24dp | 44dp |
| M | 40dp | 44dp |
| L | 56dp | 68dp |
| XL | 96dp | 108dp |

Ручка шириной 4dp, при нажатии и фокусе 2dp, форма `corner.full`. Активный трек и ручка
`primary`, неактивный трек `secondaryContainer`. Источник: `md.comp.slider.*`, `SliderTokens.kt`.

## Состояния и движение
При касании или перетаскивании ручка сужается с 4 до 2dp и появляется значение
(Accessibility → Interaction & style). Трек меняет форму у края (Overview → Previous updates).

## Доступность
- Начальный фокус на ручке. Tab — к ручке, стрелки — на шаг или остановку, Home/End — к первому
  или последнему значению.
- Конец неактивного трека должен иметь контраст с фоном не ниже 3:1: индикатор остановки или
  иконки.
- Доступное имя = подпись рядом, роль slider.

## В приложении
Не используется.

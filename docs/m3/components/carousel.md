# Карусель (Carousel)

Статус в приложении: — не используется

## Источники
- Guidelines / Specs / Accessibility: https://m3.material.io/components/carousel/guidelines,
  https://m3.material.io/components/carousel/specs, https://m3.material.io/components/carousel/accessibility
  (выгрузка: `.m3-guidelines/components__carousel.md`)
- Compose API: https://developer.android.com/reference/kotlin/androidx/compose/material3/package-summary —
  `HorizontalMultiBrowseCarousel`, `HorizontalUncontainedCarousel`, `HorizontalCenteredHeroCarousel`,
  `rememberCarouselState`, `CarouselItemScope.maskClip`, `CarouselDefaults.singleAdvanceFlingBehavior` /
  `multiBrowseFlingBehavior` / `noSnapFlingBehavior`
- Compose исходник: `carousel/Carousel.kt`, `carousel/Strategy.kt`, `carousel/Keylines.kt`,
  `carousel/CarouselItemScope.kt`, пример `samples/CarouselSamples.kt`
- MDC: https://github.com/material-components/material-components-android/blob/master/docs/components/Carousel.md
  (multi-browse, uncontained, hero, full-screen)
- Flutter: `CarouselView`, `CarouselView.weighted` (`packages/flutter/lib/src/material/carousel.dart`)

## Когда использовать
- Набор визуальных элементов (изображения, видео) с необязательной подписью. Раскладки:
  multi-browse, uncontained, uncontained multi-aspect ratio, hero, center-aligned hero, full-screen.
- Элементы меняют размер при прокрутке. У изображений внутри параллакс, элементы доводятся до
  позиции.

## Размеры, формы, цвета
| Элемент | Значение | Источник |
|---|---|---|
| Элемент | `surface`, форма `corner.extra-large` (28dp), elevation 0 (hover level1) | `md.comp.carousel-item.container.*` |
| Обводка (вариант) | 1dp `outline` | `md.comp.carousel-item.with-outline.*` |
| Disabled | прозрачность 0.38 | `md.comp.carousel-item.disabled.container.opacity` |

## В приложении
- Не используется: визуальных наборов (фото, обложек) нет. `DaySelector` (`lib/widgets/day_selector.dart`)
  — ряд выбора дня, а не карусель.

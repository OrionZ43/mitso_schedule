package com.z43studios.mitso_schedule.wear

import androidx.wear.protolayout.DeviceParametersBuilders
import androidx.wear.protolayout.LayoutElementBuilders
import androidx.wear.protolayout.ResourceBuilders
import androidx.wear.protolayout.TimelineBuilders
import androidx.wear.protolayout.material3.MaterialScope
import androidx.wear.protolayout.material3.Typography
import androidx.wear.protolayout.material3.materialScope
import androidx.wear.protolayout.material3.primaryLayout
import androidx.wear.protolayout.material3.text
import androidx.wear.protolayout.types.layoutString
import androidx.wear.tiles.RequestBuilders
import androidx.wear.tiles.TileBuilders
import androidx.wear.tiles.TileService
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * Плитка «Ближайшая пара»: что идёт сейчас или будет следующим.
 *
 * Слоты `primaryLayout` сами расставляют поля под размер экрана: сверху
 * подпись («Сейчас» или «Дальше»), в середине предмет, снизу время и
 * аудитория. Данные — те же, что у приложения (последнее расписание с
 * телефона), поэтому плитка работает и без телефона рядом.
 */
class ScheduleTileService : TileService() {

    override fun onTileRequest(
        requestParams: RequestBuilders.TileRequest,
    ): ListenableFuture<TileBuilders.Tile> {
        val tile = TileBuilders.Tile.Builder()
            .setResourcesVersion(RESOURCES_VERSION)
            // Раз в десять минут плитка перечитывает расписание: пары
            // сменяются нечасто, а будить часы лишний раз незачем.
            .setFreshnessIntervalMillis(10 * 60 * 1000L)
            .setTileTimeline(
                TimelineBuilders.Timeline.Builder()
                    .addTimelineEntry(
                        TimelineBuilders.TimelineEntry.Builder()
                            .setLayout(
                                LayoutElementBuilders.Layout.Builder()
                                    .setRoot(tileLayout(requestParams.deviceConfiguration))
                                    .build(),
                            )
                            .build(),
                    )
                    .build(),
            )
            .build()
        return Futures.immediateFuture(tile)
    }

    override fun onTileResourcesRequest(
        requestParams: RequestBuilders.ResourcesRequest,
    ): ListenableFuture<ResourceBuilders.Resources> = Futures.immediateFuture(
        ResourceBuilders.Resources.Builder().setVersion(RESOURCES_VERSION).build(),
    )

    private fun tileLayout(
        device: DeviceParametersBuilders.DeviceParameters,
    ): LayoutElementBuilders.LayoutElement = materialScope(this, device) {
        val content = tileContent()

        primaryLayout(
            titleSlot = { label(content.label) },
            mainSlot = { title(content.title) },
            bottomSlot = content.details
                ?.let { details -> { label(details) } },
        )
    }

    private fun MaterialScope.label(value: String): LayoutElementBuilders.LayoutElement =
        text(value.layoutString, typography = Typography.LABEL_MEDIUM, maxLines = 1)

    private fun MaterialScope.title(value: String): LayoutElementBuilders.LayoutElement =
        text(value.layoutString, typography = Typography.TITLE_MEDIUM, maxLines = 3)

    /** Что показать: подпись сверху, предмет и строка подробностей. */
    private fun tileContent(): TileContent {
        val schedule = ScheduleStore.load(this) ?: return TileContent(
            label = "Расписание",
            title = "Откройте приложение на телефоне",
            details = null,
        )
        val now = LocalDateTime.now()
        val lessonNow = schedule.lessonNow(now)
        if (lessonNow != null) {
            return TileContent(
                label = "Сейчас",
                title = lessonNow.title,
                details = listOfNotNull(
                    "до ${lessonNow.end}",
                    lessonNow.room,
                ).joinToString(" · "),
            )
        }
        val next = schedule.nextLesson(now) ?: return TileContent(
            label = "Расписание",
            title = "Пар впереди нет",
            details = null,
        )
        val (day, lesson) = next
        return TileContent(
            label = "Дальше",
            title = lesson.title,
            details = listOfNotNull(
                whenLabel(day, lesson, now),
                lesson.room,
            ).joinToString(" · "),
        )
    }

    private data class TileContent(
        val label: String,
        val title: String,
        val details: String?,
    )

    /** «через 25 мин», «в 11:15», «завтра в 8:30», «Пн, 21 сент., 11:15». */
    private fun whenLabel(day: Day, lesson: Lesson, now: LocalDateTime): String {
        val today = now.toLocalDate()
        val minutes = now.hour * 60 + now.minute
        return when {
            day.date == today -> {
                val left = lesson.startMinutes - minutes
                if (left in 0..59) "через $left мин" else "в ${lesson.start}"
            }
            day.date == today.plusDays(1) -> "завтра в ${lesson.start}"
            else -> day.date
                .format(DateTimeFormatter.ofPattern("EEE, d MMM", Locale("ru")))
                .replaceFirstChar { it.uppercase() } + ", ${lesson.start}"
        }
    }

    private companion object {
        const val RESOURCES_VERSION = "1"
    }
}

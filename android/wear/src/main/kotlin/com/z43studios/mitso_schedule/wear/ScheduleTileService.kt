package com.z43studios.mitso_schedule.wear

import androidx.wear.protolayout.DeviceParametersBuilders
import androidx.wear.protolayout.LayoutElementBuilders
import androidx.wear.protolayout.ResourceBuilders
import androidx.wear.protolayout.TimelineBuilders
import androidx.wear.protolayout.material3.MaterialScope
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
 * Данные — те же, что у приложения (последнее расписание с телефона), поэтому
 * плитка работает и без телефона рядом.
 */
class ScheduleTileService : TileService() {

    override fun onTileRequest(
        requestParams: RequestBuilders.TileRequest,
    ): ListenableFuture<TileBuilders.Tile> {
        val layout = tileLayout(requestParams.deviceConfiguration)
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
                                    .setRoot(layout)
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
        val schedule = ScheduleStore.load(this@ScheduleTileService)
        val now = LocalDateTime.now()
        val lessonNow = schedule?.lessonNow(now)
        val next = schedule?.nextLesson(now)

        val title: String
        val subtitle: String
        when {
            schedule == null -> {
                title = "Нет расписания"
                subtitle = "Откройте приложение на телефоне"
            }
            lessonNow != null -> {
                title = lessonNow.title
                subtitle = "Сейчас · до ${lessonNow.end}" +
                    (lessonNow.room?.let { " · $it" } ?: "")
            }
            next != null -> {
                val (day, lesson) = next
                title = lesson.title
                subtitle = whenLabel(day, lesson, now) +
                    (lesson.room?.let { " · $it" } ?: "")
            }
            else -> {
                title = "Пар впереди нет"
                subtitle = ""
            }
        }

        primaryLayout(
            mainSlot = {
                column {
                    setWidth(androidx.wear.protolayout.DimensionBuilders.expand())
                    addContent(bodyText(title))
                    if (subtitle.isNotEmpty()) addContent(labelText(subtitle))
                }
            },
        )
    }

    private fun MaterialScope.bodyText(value: String): LayoutElementBuilders.LayoutElement =
        text(value.layoutString, maxLines = 3)

    private fun MaterialScope.labelText(value: String): LayoutElementBuilders.LayoutElement =
        text(value.layoutString, maxLines = 2)

    private fun column(
        builder: LayoutElementBuilders.Column.Builder.() -> Unit,
    ): LayoutElementBuilders.Column =
        LayoutElementBuilders.Column.Builder().apply(builder).build()

    /** «Завтра в 8:30», «Пн, 21 сент., 11:15» или «через 25 мин». */
    private fun whenLabel(day: Day, lesson: Lesson, now: LocalDateTime): String {
        val today = now.toLocalDate()
        val minutes = now.hour * 60 + now.minute
        return when {
            day.date == today -> {
                val left = lesson.startMinutes - minutes
                if (left < 60) "через $left мин" else "в ${lesson.start}"
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

package com.z43studios.mitso_schedule.wear

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.wear.compose.foundation.lazy.TransformingLazyColumn
import androidx.wear.compose.foundation.lazy.rememberTransformingLazyColumnState
import androidx.wear.compose.material3.AppScaffold
import androidx.wear.compose.material3.CardDefaults
import androidx.wear.compose.material3.CircularProgressIndicator
import androidx.wear.compose.material3.ListHeader
import androidx.wear.compose.material3.MaterialTheme
import androidx.wear.compose.material3.ScreenScaffold
import androidx.wear.compose.material3.SurfaceTransformation
import androidx.wear.compose.material3.Text
import androidx.wear.compose.material3.TitleCard
import androidx.wear.compose.material3.lazy.rememberTransformationSpec
import androidx.wear.compose.material3.lazy.transformedHeight
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.Wearable
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale

/** Расписание на часах: день, который идёт или наступит ближайшим. */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { ScheduleApp() }
    }
}

@Composable
fun ScheduleApp() {
    val context = LocalContext.current
    var schedule by remember { mutableStateOf(ScheduleStore.load(context)) }
    var loading by remember { mutableStateOf(schedule == null) }

    // При каждом открытии берём последнее, что положил телефон: часы могли
    // проспать событие Data Layer.
    LaunchedEffect(Unit) {
        Wearable.getDataClient(context).dataItems
            .addOnSuccessListener { items ->
                val item = items.firstOrNull { it.uri.path == ScheduleStore.DATA_PATH }
                val payload = item?.let {
                    DataMapItem.fromDataItem(it)
                        .dataMap
                        .getString(ScheduleStore.DATA_KEY_PAYLOAD)
                }
                if (payload != null) {
                    ScheduleStore.save(context, payload)
                    schedule = Schedule.parse(payload)
                }
                items.release()
                loading = false
            }
            .addOnFailureListener { loading = false }
    }

    // AppScaffold держит часы (TimeText) на месте при переходах внутри
    // приложения, ScreenScaffold — полосу прокрутки и отступы под круглый
    // экран (образцы ScaffoldSample и ListHeaderSample из Wear Compose).
    MaterialTheme {
        AppScaffold {
            val listState = rememberTransformingLazyColumnState()
            val transformationSpec = rememberTransformationSpec()

            ScreenScaffold(scrollState = listState) { contentPadding ->
                val now = LocalDateTime.now()
                val day = schedule?.dayToShow(now)
                val lessonNow = schedule?.lessonNow(now)

                if (day == null) {
                    Message(
                        text = when {
                            loading -> null
                            schedule == null -> "Откройте расписание на телефоне"
                            else -> "Пар впереди нет"
                        },
                    )
                } else {
                    TransformingLazyColumn(
                        state = listState,
                        contentPadding = contentPadding,
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(4.dp),
                        modifier = Modifier.fillMaxSize(),
                    ) {
                        item {
                            ListHeader(
                                transformation = SurfaceTransformation(
                                    transformationSpec,
                                ),
                                modifier = Modifier.transformedHeight(
                                    this,
                                    transformationSpec,
                                ),
                            ) {
                                Text(dayTitle(day.date, now.toLocalDate()))
                            }
                        }
                        items(day.lessons.size) { index ->
                            val lesson = day.lessons[index]
                            LessonCard(
                                lesson = lesson,
                                isNow = lesson === lessonNow,
                                transformation = SurfaceTransformation(
                                    transformationSpec,
                                ),
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .transformedHeight(this, transformationSpec),
                            )
                        }
                    }
                }
            }
        }
    }
}

/**
 * Пара: время в углу, предмет крупно, подробности строкой ниже. Идущая —
 * на ролях primary container, как выделенная карточка на телефоне.
 */
@Composable
private fun LessonCard(
    lesson: Lesson,
    isNow: Boolean,
    transformation: SurfaceTransformation,
    modifier: Modifier = Modifier,
) {
    val colors = if (isNow) {
        CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.primaryContainer,
            contentColor = MaterialTheme.colorScheme.onPrimaryContainer,
            titleColor = MaterialTheme.colorScheme.onPrimaryContainer,
            subtitleColor = MaterialTheme.colorScheme.onPrimaryContainer,
            timeColor = MaterialTheme.colorScheme.onPrimaryContainer,
        )
    } else {
        CardDefaults.cardColors()
    }

    TitleCard(
        title = {
            Text(
                lesson.title,
                maxLines = 3,
                overflow = TextOverflow.Ellipsis,
            )
        },
        subtitle = {
            Text(
                subtitleOf(lesson, isNow),
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
        },
        time = { Text("${lesson.start}–${lesson.end}") },
        colors = colors,
        transformation = transformation,
        modifier = modifier,
    )
}

/** «Идёт до 11:05», «Лекция · 71», «Лаб · 62 (к) · 2 подгруппа». */
private fun subtitleOf(lesson: Lesson, isNow: Boolean): String {
    if (isNow) return "Идёт до ${lesson.end}"
    return listOfNotNull(
        lesson.typeLabel.takeIf { it.isNotEmpty() },
        lesson.room,
        lesson.subgroup?.let { "$it подгруппа" },
    ).joinToString(" · ")
}

/** Сообщение посреди экрана; `null` — ещё грузим. */
@Composable
private fun Message(text: String?) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            // Поля круглого экрана: у краёв текст обрезает стекло.
            .padding(horizontal = 24.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        if (text == null) {
            CircularProgressIndicator()
        } else {
            Text(
                text = text,
                textAlign = TextAlign.Center,
                style = MaterialTheme.typography.bodyLarge,
            )
        }
    }
}

/** «Сегодня», «Завтра» или «Пн, 21 сент.». */
private fun dayTitle(date: LocalDate, today: LocalDate): String = when (date) {
    today -> "Сегодня"
    today.plusDays(1) -> "Завтра"
    else -> date.format(DateTimeFormatter.ofPattern("EEE, d MMM", Locale("ru")))
        .replaceFirstChar { it.uppercase() }
}

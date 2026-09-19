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
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.material3.AppScaffold
import androidx.wear.compose.material3.Card
import androidx.wear.compose.material3.CardDefaults
import androidx.wear.compose.material3.CircularProgressIndicator
import androidx.wear.compose.material3.ListHeader
import androidx.wear.compose.material3.MaterialTheme
import androidx.wear.compose.material3.ScreenScaffold
import androidx.wear.compose.material3.Text
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

    MaterialTheme {
        AppScaffold {
            val listState = rememberScalingLazyListState()
            ScreenScaffold(scrollState = listState) { contentPadding ->
                val now = LocalDateTime.now()
                val day = schedule?.dayToShow(now)

                if (day == null) {
                    Message(
                        text = when {
                            loading -> null
                            schedule == null ->
                                "Откройте расписание на телефоне — часы возьмут его оттуда"
                            else -> "Пар впереди нет"
                        },
                    )
                } else {
                    ScalingLazyColumn(
                        state = listState,
                        contentPadding = contentPadding,
                        modifier = Modifier.fillMaxSize(),
                    ) {
                        item { ListHeader { Text(dayTitle(day.date, now.toLocalDate())) } }
                        items(day.lessons.size) { index ->
                            val lesson = day.lessons[index]
                            LessonCard(
                                lesson = lesson,
                                isNow = schedule?.lessonNow(now) === lesson,
                            )
                        }
                    }
                }
            }
        }
    }
}

/** Пара: время, название, аудитория. Идущая выделена цветом. */
@Composable
private fun LessonCard(lesson: Lesson, isNow: Boolean) {
    Card(
        onClick = {},
        colors = if (isNow) {
            CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.primaryContainer,
                contentColor = MaterialTheme.colorScheme.onPrimaryContainer,
            )
        } else {
            CardDefaults.cardColors()
        },
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column {
            Text(
                text = "${lesson.start}–${lesson.end}" +
                    (lesson.room?.let { " · $it" } ?: ""),
                style = MaterialTheme.typography.labelSmall,
            )
            Text(
                text = lesson.title,
                style = MaterialTheme.typography.bodyMedium,
                maxLines = 3,
                overflow = TextOverflow.Ellipsis,
            )
            val details = listOfNotNull(
                lesson.typeLabel.takeIf { it.isNotEmpty() },
                lesson.subgroup?.let { "$it подгруппа" },
            ).joinToString(" · ")
            if (details.isNotEmpty()) {
                Text(
                    text = details,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

/** Сообщение посреди экрана; `null` — ещё грузим. */
@Composable
private fun Message(text: String?) {
    Column(
        modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        if (text == null) {
            CircularProgressIndicator()
        } else {
            Text(
                text = text,
                textAlign = TextAlign.Center,
                style = MaterialTheme.typography.bodyMedium,
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

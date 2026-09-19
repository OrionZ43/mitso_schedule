package com.z43studios.mitso_schedule.wear

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate
import java.time.LocalDateTime

/** Одна строка расписания. */
data class Lesson(
    val start: String,
    val end: String,
    val title: String,
    val typeLabel: String,
    val teacher: String?,
    val room: String?,
    val subgroup: Int?,
) {
    val startMinutes: Int get() = minutesOf(start)
    val endMinutes: Int get() = minutesOf(end)

    companion object {
        fun minutesOf(hhmm: String): Int {
            val parts = hhmm.split(":")
            if (parts.size != 2) return 0
            return (parts[0].toIntOrNull() ?: 0) * 60 + (parts[1].toIntOrNull() ?: 0)
        }
    }
}

/** День с парами. */
data class Day(val date: LocalDate, val lessons: List<Lesson>)

/**
 * Расписание, пришедшее с телефона.
 *
 * Разбирается из того же JSON, который телефон хранит у себя в кэше, —
 * отдельного формата для часов нет.
 */
data class Schedule(val group: String, val days: List<Day>) {

    /** Пара, которая идёт прямо сейчас. */
    fun lessonNow(now: LocalDateTime): Lesson? {
        val today = days.firstOrNull { it.date == now.toLocalDate() } ?: return null
        val minutes = now.hour * 60 + now.minute
        return today.lessons.firstOrNull {
            minutes >= it.startMinutes && minutes < it.endMinutes
        }
    }

    /** Ближайшая пара впереди: сегодня или в следующий учебный день. */
    fun nextLesson(now: LocalDateTime): Pair<Day, Lesson>? {
        val minutes = now.hour * 60 + now.minute
        for (day in days) {
            if (day.date.isBefore(now.toLocalDate())) continue
            val isToday = day.date == now.toLocalDate()
            val lesson = day.lessons.firstOrNull { !isToday || it.startMinutes > minutes }
            if (lesson != null) return day to lesson
        }
        return null
    }

    /**
     * День, который стоит показать: сегодняшний, пока в нём есть что впереди,
     * иначе ближайший следующий с парами.
     */
    fun dayToShow(now: LocalDateTime): Day? {
        val minutes = now.hour * 60 + now.minute
        val today = days.firstOrNull { it.date == now.toLocalDate() }
        if (today != null && today.lessons.any { it.endMinutes > minutes }) return today
        return days.firstOrNull {
            it.date.isAfter(now.toLocalDate()) && it.lessons.isNotEmpty()
        }
    }

    companion object {
        fun parse(json: String): Schedule? = try {
            val root = JSONObject(json)
            val days = mutableListOf<Day>()
            val weeks = root.optJSONArray("weeks") ?: JSONArray()
            for (w in 0 until weeks.length()) {
                val weekDays = weeks.getJSONObject(w).optJSONArray("days") ?: continue
                for (d in 0 until weekDays.length()) {
                    val day = weekDays.getJSONObject(d)
                    val date = LocalDate.parse(day.getString("date").substring(0, 10))
                    val lessons = day.optJSONArray("lessons") ?: JSONArray()
                    days += Day(
                        date = date,
                        lessons = (0 until lessons.length()).map { i ->
                            val lesson = lessons.getJSONObject(i)
                            Lesson(
                                start = lesson.getString("start"),
                                end = lesson.getString("end"),
                                title = lesson.getString("title"),
                                typeLabel = lesson.optString("typeLabel", ""),
                                teacher = lesson.optStringOrNull("teacher"),
                                room = lesson.optStringOrNull("room"),
                                subgroup = if (lesson.isNull("subgroup")) {
                                    null
                                } else {
                                    lesson.optInt("subgroup")
                                },
                            )
                        },
                    )
                }
            }
            Schedule(group = root.optString("group", ""), days = days.sortedBy { it.date })
        } catch (error: Exception) {
            null
        }
    }
}

private fun JSONObject.optStringOrNull(key: String): String? =
    if (isNull(key)) null else optString(key).takeIf { it.isNotEmpty() }

/**
 * Последнее расписание с телефона.
 *
 * Хранится на часах, чтобы приложение и плитка показывали пары сразу, не
 * дожидаясь телефона, — и работали, когда его нет рядом.
 */
object ScheduleStore {
    private const val PREFS = "mitso.wear"
    private const val KEY_PAYLOAD = "schedule.payload"
    private const val KEY_UPDATED = "schedule.updatedAt"

    const val DATA_PATH = "/mitso/schedule"
    const val DATA_KEY_PAYLOAD = "payload"

    fun save(context: Context, payload: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_PAYLOAD, payload)
            .putLong(KEY_UPDATED, System.currentTimeMillis())
            .apply()
    }

    fun load(context: Context): Schedule? {
        val payload = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_PAYLOAD, null) ?: return null
        return Schedule.parse(payload)
    }

    fun updatedAt(context: Context): Long =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getLong(KEY_UPDATED, 0)
}

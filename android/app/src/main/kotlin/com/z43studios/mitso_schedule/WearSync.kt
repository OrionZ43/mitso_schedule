package com.z43studios.mitso_schedule

import android.content.Context
import android.util.Log
import com.google.android.gms.wearable.Node
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable

/**
 * Расписание для часов.
 *
 * Телефон кладёт его в Data Layer, а система сама доставляет на часы —
 * и когда приложение на них закрыто. Свежесть в самом JSON не хранится:
 * одинаковое расписание должно давать одинаковый DataItem, тогда Data Layer
 * не гоняет по Bluetooth то, что уже там есть.
 */
object WearSync {
    private const val TAG = "WearSync"
    private const val PATH = "/mitso/schedule"
    private const val KEY_PAYLOAD = "payload"

    /** Верхняя граница DataItem — 100 КБ; с запасом. */
    private const val MAX_BYTES = 90 * 1024

    /** Названия подключённых часов; пустой список — часов рядом нет. */
    fun connectedWatches(context: Context, onResult: (List<String>) -> Unit) {
        Wearable.getNodeClient(context).connectedNodes
            .addOnSuccessListener { nodes: List<Node> ->
                onResult(nodes.filter { it.isNearby }.map { it.displayName })
            }
            .addOnFailureListener { error ->
                Log.w(TAG, "Не удалось спросить о часах", error)
                onResult(emptyList())
            }
    }

    fun push(context: Context, payload: String): Boolean {
        if (payload.toByteArray().size > MAX_BYTES) {
            Log.w(TAG, "Расписание слишком большое для часов, не отправляю")
            return false
        }
        val request = PutDataMapRequest.create(PATH).apply {
            dataMap.putString(KEY_PAYLOAD, payload)
        }
        Wearable.getDataClient(context)
            .putDataItem(request.asPutDataRequest().setUrgent())
            .addOnFailureListener { error ->
                Log.w(TAG, "Не удалось отправить расписание на часы", error)
            }
        return true
    }
}

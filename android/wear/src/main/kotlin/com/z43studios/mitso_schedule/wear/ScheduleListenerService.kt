package com.z43studios.mitso_schedule.wear

import androidx.wear.tiles.TileService
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.WearableListenerService

/**
 * Расписание с телефона: телефон кладёт его в Data Layer, часы забирают —
 * даже когда приложение на часах закрыто. Сразу после этого обновляется
 * плитка.
 */
class ScheduleListenerService : WearableListenerService() {
    override fun onDataChanged(events: DataEventBuffer) {
        var changed = false
        for (event in events) {
            if (event.type != DataEvent.TYPE_CHANGED) continue
            val item = event.dataItem
            if (item.uri.path != ScheduleStore.DATA_PATH) continue
            val payload = DataMapItem.fromDataItem(item)
                .dataMap
                .getString(ScheduleStore.DATA_KEY_PAYLOAD) ?: continue
            ScheduleStore.save(this, payload)
            changed = true
        }
        if (changed) {
            TileService.getUpdater(this).requestUpdate(ScheduleTileService::class.java)
        }
    }
}

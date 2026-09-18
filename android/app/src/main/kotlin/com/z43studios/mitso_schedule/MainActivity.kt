package com.z43studios.mitso_schedule

import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mitso/system_colors")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "roles" -> result.success(systemColorRoles())
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mitso/app_icon")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "current" -> result.success(currentIcon())
                    "select" -> {
                        val name = call.argument<String>("name") ?: ""
                        if (aliases.containsKey(name)) {
                            selectIcon(name)
                            result.success(null)
                        } else {
                            result.error("unknown_icon", "Нет значка $name", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Значки приложения: имя варианта → activity-alias в манифесте.
     *
     * Значок меняется включением одного алиаса и выключением остальных
     * (`PackageManager.setComponentEnabledSetting`) — другого способа поменять
     * иконку в лаунчере у Android нет. Сначала включается новый алиас, потом
     * выключаются старые: иначе приложение на мгновение осталось бы без
     * значка совсем.
     */
    private val aliases = mapOf(
        "" to ".MainActivityDefault",
        "cap" to ".MainActivityCap",
        "clock" to ".MainActivityClock",
        "card" to ".MainActivityCard",
    )

    private fun component(alias: String) = ComponentName(packageName, packageName + alias)

    private fun currentIcon(): String {
        for ((name, alias) in aliases) {
            val state = packageManager.getComponentEnabledSetting(component(alias))
            if (state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) return name
        }
        // Ни один не переключали — включён тот, что enabled="true" в манифесте.
        return ""
    }

    private fun selectIcon(name: String) {
        val target = aliases.getValue(name)
        packageManager.setComponentEnabledSetting(
            component(target),
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP,
        )
        for ((other, alias) in aliases) {
            if (other == name) continue
            packageManager.setComponentEnabledSetting(
                component(alias),
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP,
            )
        }
    }

    /**
     * Цветовые роли динамической схемы Android 14+.
     *
     * Соответствие ролей системным ресурсам — как в MDC-Android
     * `color/res/values-v34/tokens.xml` (`m3_sys_color_dynamic_*`): система сама
     * учитывает обои и уровень контраста. На Android 12–13 таких ресурсов нет —
     * возвращается null.
     */
    private fun systemColorRoles(): Map<String, Map<String, Int>>? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return null
        fun c(id: Int): Int = resources.getColor(id, theme)
        val r = android.R.color::class.java
        fun id(name: String): Int = r.getField(name).getInt(null)

        fun scheme(suffix: String, inverse: String): Map<String, Int> = mapOf(
            "primary" to c(id("system_primary_$suffix")),
            "onPrimary" to c(id("system_on_primary_$suffix")),
            "primaryContainer" to c(id("system_primary_container_$suffix")),
            "onPrimaryContainer" to c(id("system_on_primary_container_$suffix")),
            "secondary" to c(id("system_secondary_$suffix")),
            "onSecondary" to c(id("system_on_secondary_$suffix")),
            "secondaryContainer" to c(id("system_secondary_container_$suffix")),
            "onSecondaryContainer" to c(id("system_on_secondary_container_$suffix")),
            "tertiary" to c(id("system_tertiary_$suffix")),
            "onTertiary" to c(id("system_on_tertiary_$suffix")),
            "tertiaryContainer" to c(id("system_tertiary_container_$suffix")),
            "onTertiaryContainer" to c(id("system_on_tertiary_container_$suffix")),
            "error" to c(id("system_error_$suffix")),
            "onError" to c(id("system_on_error_$suffix")),
            "errorContainer" to c(id("system_error_container_$suffix")),
            "onErrorContainer" to c(id("system_on_error_container_$suffix")),
            "surface" to c(id("system_surface_$suffix")),
            "onSurface" to c(id("system_on_surface_$suffix")),
            "surfaceVariant" to c(id("system_surface_variant_$suffix")),
            "onSurfaceVariant" to c(id("system_on_surface_variant_$suffix")),
            "surfaceContainerHighest" to c(id("system_surface_container_highest_$suffix")),
            "surfaceContainerHigh" to c(id("system_surface_container_high_$suffix")),
            "surfaceContainer" to c(id("system_surface_container_$suffix")),
            "surfaceContainerLow" to c(id("system_surface_container_low_$suffix")),
            "surfaceContainerLowest" to c(id("system_surface_container_lowest_$suffix")),
            "surfaceBright" to c(id("system_surface_bright_$suffix")),
            "surfaceDim" to c(id("system_surface_dim_$suffix")),
            // Инверсные роли MDC берёт из противоположной темы.
            "inverseSurface" to c(id("system_surface_$inverse")),
            "onInverseSurface" to c(id("system_on_surface_$inverse")),
            "inversePrimary" to c(id("system_primary_$inverse")),
            "outline" to c(id("system_outline_$suffix")),
            "outlineVariant" to c(id("system_outline_variant_$suffix")),
            "primaryFixed" to c(id("system_primary_fixed")),
            "primaryFixedDim" to c(id("system_primary_fixed_dim")),
            "onPrimaryFixed" to c(id("system_on_primary_fixed")),
            "onPrimaryFixedVariant" to c(id("system_on_primary_fixed_variant")),
            "secondaryFixed" to c(id("system_secondary_fixed")),
            "secondaryFixedDim" to c(id("system_secondary_fixed_dim")),
            "onSecondaryFixed" to c(id("system_on_secondary_fixed")),
            "onSecondaryFixedVariant" to c(id("system_on_secondary_fixed_variant")),
            "tertiaryFixed" to c(id("system_tertiary_fixed")),
            "tertiaryFixedDim" to c(id("system_tertiary_fixed_dim")),
            "onTertiaryFixed" to c(id("system_on_tertiary_fixed")),
            "onTertiaryFixedVariant" to c(id("system_on_tertiary_fixed_variant")),
        )

        return mapOf("light" to scheme("light", "dark"), "dark" to scheme("dark", "light"))
    }
}

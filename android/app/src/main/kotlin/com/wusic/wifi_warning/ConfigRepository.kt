package com.wusic.wifi_warning

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

object ConfigRepository {
    private const val PREFS = "wifi_warning_config"
    private const val KEY_CONFIG = "config_json"

    fun loadRaw(context: Context): String? =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_CONFIG, null)

    fun load(context: Context): JSONObject {
        val raw = loadRaw(context) ?: return defaultConfig()
        return runCatching { JSONObject(raw) }.getOrElse { defaultConfig() }
    }

    fun save(context: Context, raw: String) {
        val parsed = JSONObject(raw)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_CONFIG, parsed.toString())
            .apply()
    }

    fun defaultConfig(): JSONObject = JSONObject()
        .put("schemaVersion", 1)
        .put("backgroundMonitoring", false)
        .put("startAtLogin", false)
        .put("overlayEnabled", false)
        .put("firstRunCompleted", false)
        .put("networkRules", JSONArray())
        .put("timeRules", JSONArray())
        .put(
            "proxyProcessPatterns",
            JSONArray(
                listOf(
                    "clash", "mihomo", "v2ray", "xray", "sing-box",
                    "wireguard", "openvpn", "tailscale", "zerotier",
                    "softether", "proxifier"
                )
            )
        )
}

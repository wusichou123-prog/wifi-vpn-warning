package com.wusic.wifi_warning

import org.json.JSONObject
import java.util.Calendar

data class RuleEvaluation(
    val shouldAlert: Boolean,
    val protectedLinkActive: Boolean,
    val networkMatched: Boolean,
    val timeMatched: Boolean
)

object RuleEvaluator {
    fun evaluate(config: JSONObject, snapshot: JSONObject): RuleEvaluation {
        val protectedLinkActive = snapshot.optBoolean("vpnActive") ||
            snapshot.optBoolean("proxyActive")
        val networkMatched = matchesNetwork(config, snapshot)
        val timeMatched = matchesTime(config)
        return RuleEvaluation(
            shouldAlert = protectedLinkActive && (networkMatched || timeMatched),
            protectedLinkActive = protectedLinkActive,
            networkMatched = networkMatched,
            timeMatched = timeMatched
        )
    }

    private fun matchesNetwork(config: JSONObject, snapshot: JSONObject): Boolean {
        if (!snapshot.optBoolean("wifiAvailable")) return false
        val ssid = snapshot.optString("wifiSsid", "").trim()
        if (ssid.isEmpty()) return false
        val rules = config.optJSONArray("networkRules") ?: return false
        for (index in 0 until rules.length()) {
            val rule = rules.optJSONObject(index) ?: continue
            if (!rule.optBoolean("enabled", true)) continue
            if (rule.optString("ssid", "").trim().equals(ssid, ignoreCase = true)) {
                return true
            }
        }
        return false
    }

    private fun matchesTime(config: JSONObject): Boolean {
        val rules = config.optJSONArray("timeRules") ?: return false
        val now = Calendar.getInstance()
        val minute = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        val currentDay = when (now.get(Calendar.DAY_OF_WEEK)) {
            Calendar.MONDAY -> 1
            Calendar.TUESDAY -> 2
            Calendar.WEDNESDAY -> 3
            Calendar.THURSDAY -> 4
            Calendar.FRIDAY -> 5
            Calendar.SATURDAY -> 6
            else -> 7
        }
        val previousDay = if (currentDay == 1) 7 else currentDay - 1
        for (index in 0 until rules.length()) {
            val rule = rules.optJSONObject(index) ?: continue
            if (!rule.optBoolean("enabled", true)) continue
            val days = rule.optJSONArray("weekdays") ?: continue
            val selected = (0 until days.length()).any { days.optInt(it) == currentDay }
            val selectedPrevious =
                (0 until days.length()).any { days.optInt(it) == previousDay }
            val start = rule.optInt("startMinutes")
            val end = rule.optInt("endMinutes")
            val matches = when {
                start == end -> selected
                start < end -> selected && minute >= start && minute < end
                else -> (selected && minute >= start) ||
                    (selectedPrevious && minute < end)
            }
            if (matches) return true
        }
        return false
    }
}

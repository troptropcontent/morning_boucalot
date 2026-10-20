package com.morningboucalot.offload.settings

import android.content.Context
import com.morningboucalot.offload.core.OffloadApi
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.OkHttpClient
import java.util.concurrent.TimeUnit

/** The app's few persisted choices: card folder, server URL, token (encrypted), Wi-Fi only. */
class Settings(context: Context, private val secrets: SecretBox = SecretBox()) {
    private val prefs = context.applicationContext.getSharedPreferences("offload", Context.MODE_PRIVATE)

    var serverUrl: String
        get() = prefs.getString(KEY_SERVER_URL, "") ?: ""
        set(value) = prefs.edit().putString(KEY_SERVER_URL, value).apply()

    var token: String
        get() = prefs.getString(KEY_TOKEN, null)?.let(secrets::decrypt) ?: ""
        set(value) = prefs.edit().putString(KEY_TOKEN, if (value.isEmpty()) null else secrets.encrypt(value)).apply()

    var wifiOnly: Boolean
        get() = prefs.getBoolean(KEY_WIFI_ONLY, true)
        set(value) = prefs.edit().putBoolean(KEY_WIFI_ONLY, value).apply()

    var lastUploadError: String?
        get() = prefs.getString(KEY_LAST_ERROR, null)
        set(value) = prefs.edit().putString(KEY_LAST_ERROR, value).apply()

    /** Null until a valid https server URL and a token have been saved. */
    fun api(): OffloadApi? {
        val url = serverUrl.toHttpUrlOrNull()?.takeIf { it.isHttps } ?: return null
        val token = token.takeIf { it.isNotEmpty() } ?: return null

        // Generous timeouts: a RAF over a slow connection takes a while to write.
        val client = OkHttpClient.Builder()
            .connectTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(2, TimeUnit.MINUTES)
            .readTimeout(2, TimeUnit.MINUTES)
            .build()
        return OffloadApi(url, token, client)
    }

    private companion object {
        const val KEY_SERVER_URL = "server_url"
        const val KEY_TOKEN = "token"
        const val KEY_WIFI_ONLY = "wifi_only"
        const val KEY_LAST_ERROR = "last_upload_error"
    }
}

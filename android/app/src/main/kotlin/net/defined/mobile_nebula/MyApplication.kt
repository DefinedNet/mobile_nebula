package net.defined.mobile_nebula

import io.flutter.embedding.engine.loader.FlutterLoader
import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import androidx.work.Configuration
import androidx.work.WorkManager

class MyApplication : Application() {
    companion object {
        const val VPN_CHANNEL_ID = "vpn_foreground"
    }

    override fun onCreate() {
        super.onCreate()

        // In order to use the WorkManager from the nebulaVpnBg process (i.e. NebulaVpnService)
        // we must explicitly initialize this rather than using the default initializer.
        val myConfig = Configuration.Builder().build()
        WorkManager.initialize(this, myConfig)
        //TODO: change to https://developer.android.com/develop/background-work/background-tasks/persistent/configuration/custom-configuration#implement-configuration-provider

        FlutterLoader().startInitialization(applicationContext)

        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            VPN_CHANNEL_ID,
            "VPN Status",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Shows when the Nebula VPN tunnel is active"
        }
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(channel)
    }
}
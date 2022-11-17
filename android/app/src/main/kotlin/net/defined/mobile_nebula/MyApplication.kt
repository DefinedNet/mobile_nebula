package net.defined.mobile_nebula

import io.flutter.view.FlutterMain
import android.app.Application
import androidx.work.Configuration
import androidx.work.WorkManager

class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        // In order to use the WorkManager from the nebulaVpnBg process (i.e. NebulaVpnService)
        // we must explicitly initialize this rather than using the default initializer.
        val myConfig = Configuration.Builder().build()
        WorkManager.initialize(this, myConfig)

        FlutterMain.startInitialization(applicationContext)
    }
}
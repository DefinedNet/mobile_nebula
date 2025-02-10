package net.defined.mobile_nebula

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.util.Log

class StopVpnActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        Log.d(TAG, "!!! StopVpnActivity onCreate")
        super.onCreate(savedInstanceState)

        val intent =
                Intent(this, NebulaVpnService::class.java).apply {
                    action = NebulaVpnService.ACTION_STOP
                }
        Log.d(TAG, "!!! startService ACTION_STOP")
        var ret = startService(intent)
        Log.d(TAG, "!!! startService ACTION_STOP: ${ret}")

        finish()
    }

    override fun finish() {
        Log.d(TAG, "!!! StopVpnActivity finish")
        super.finish()
    }
}

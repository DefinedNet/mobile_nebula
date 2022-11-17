package net.defined.mobile_nebula

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.os.Build

class PackageInfo(private val context: Context) {
    private val pInfo: PackageInfo =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU)
            context.packageManager.getPackageInfo(context.packageName, PackageManager.PackageInfoFlags.of(0))
        else
            @Suppress("DEPRECATION")
            context.packageManager.getPackageInfo(context.packageName, 0)

    private val appInfo: ApplicationInfo = context.applicationInfo

    fun getVersion(): String {
        val version: String = pInfo.versionName
        val build: Long = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P)
            pInfo.longVersionCode
        else
            @Suppress("DEPRECATION")
            pInfo.versionCode.toLong()
        return "%s-%d".format(version, build)
    }

    fun getName(): String {
        val stringId = appInfo.labelRes
        return if (stringId == 0) appInfo.nonLocalizedLabel.toString() else context.getString(stringId)
    }

    fun getSystemVersion(): String {
        return Build.VERSION.RELEASE
    }
}
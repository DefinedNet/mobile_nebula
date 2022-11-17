package net.defined.mobile_nebula

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.content.pm.PackageInfo
import android.os.Build

class PackageInfo(val context: Context) {
    private val pInfo: PackageInfo = context.getPackageManager().getPackageInfo(context.getPackageName(), 0)
    private val appInfo: ApplicationInfo = context.getApplicationInfo()

    fun getVersion(): String {
        val version: String = pInfo.versionName
        val build: Int = pInfo.versionCode
        return "%s-%d".format(version, build)
    }

    fun getName(): String {
        val stringId = appInfo.labelRes
        return if (stringId == 0) appInfo.nonLocalizedLabel.toString() else context.getString(stringId)
    }

    fun getSystemVersion(): String {
        return Build.VERSION.RELEASE;
    }
}
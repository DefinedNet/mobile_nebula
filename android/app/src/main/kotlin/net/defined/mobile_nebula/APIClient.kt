package net.defined.mobile_nebula

import android.content.Context
import android.util.Log
import com.google.gson.Gson

class InvalidCredentialsException(): Exception("Invalid credentials")

class APIClient(context: Context) {
    private val packageInfo = PackageInfo(context)
    private val client = mobileNebula.MobileNebula.newAPIClient(
        "%s/%s (Android %s)".format(
                packageInfo.getName(),
                packageInfo.getVersion(),
                packageInfo.getSystemVersion(),
        ))
    private val gson = Gson()

    fun enroll(code: String): IncomingSite {
        val res = client.enroll(code)
        return decodeIncomingSite(res.site)
    }

    fun tryUpdate(siteName: String, hostID: String, privateKey: String, counter: Long, trustedKeys: String): IncomingSite? {
        val res: mobileNebula.TryUpdateResult
        try {
            res = client.tryUpdate(siteName, hostID, privateKey, counter, trustedKeys)
        } catch (e: Exception) {
            // type information from Go is not available, use string matching instead
            if (e.message == "invalid credentials") {
                throw InvalidCredentialsException()
            }

            throw e
        }

        if (res.fetchedUpdate) {
            return decodeIncomingSite(res.site)
        }

        return null
    }

    private fun decodeIncomingSite(jsonSite: String): IncomingSite {
        return gson.fromJson(jsonSite, IncomingSite::class.java)
    }
}
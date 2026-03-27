package net.defined.mobile_nebula

class InvalidCredentialsException: Exception("Invalid credentials")

class APIClient(context: android.content.Context) {
    private val packageInfo = PackageInfo(context)
    private val client = mobileNebula.MobileNebula.newAPIClient(
        "MobileNebula/%s (Android %s)".format(
                packageInfo.getVersion(),
                packageInfo.getSystemVersion(),
        ))

    fun enroll(code: String): String {
        val res = client.enroll(code)
        return res.site
    }

    fun tryUpdate(siteName: String, hostID: String, privateKey: String, counter: Long, trustedKeys: String, nebulaCert: String, nebulaKey: String): String? {
        val res: mobileNebula.TryUpdateResult
        try {
            res = client.tryUpdate(siteName, hostID, privateKey, counter, trustedKeys, nebulaCert, nebulaKey)
        } catch (e: Exception) {
            // type information from Go is not available, use string matching instead
            if (e.message == "invalid credentials") {
                throw InvalidCredentialsException()
            }

            throw e
        }

        if (res.fetchedUpdate) {
            return res.site
        }

        return null
    }
}

package net.defined.mobile_nebula

import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.io.Closeable
import java.nio.channels.FileChannel
import java.nio.file.Paths
import java.nio.file.StandardOpenOption

class DNUpdateWorker(ctx: Context, params: WorkerParameters) : Worker(ctx, params) {

    companion object {
        private const val TAG = "DNUpdateWorker"
    }

    private val context = applicationContext
    private val apiClient: APIClient = APIClient(ctx)
    private val updater = DNSiteUpdater(context, apiClient)
    private val sites = SiteList(context)

    override fun doWork(): Result {
        var failed = false

        sites.getSites().values.forEach { site ->
            try {
                updateSite(site)
            } catch (e: Exception) {
                failed = true
                Log.e(TAG, "Error while updating site ${site.id}: ${e.stackTraceToString()}")
                return@forEach
            }
        }

        return if (failed) Result.failure() else Result.success()
    }

    private fun updateSite(site: Site) {
        try {
            DNUpdateLock(site).use {
                val res = updater.updateSite(site)

                // Reload Nebula if this is the currently active site
                if (res == DNSiteUpdater.Result.CONFIG_UPDATED) {
                    Intent().also { intent ->
                        intent.setPackage(context.getPackageName())
                        intent.action = NebulaVpnService.ACTION_RELOAD
                        intent.putExtra("id", site.id)
                        context.sendBroadcast(intent)
                    }
                }

                // Update the UI on any change
                if (res != DNSiteUpdater.Result.NOOP) {
                    Intent().also { intent ->
                        intent.setPackage(context.getPackageName())
                        intent.action = MainActivity.ACTION_REFRESH_SITES
                        context.sendBroadcast(intent)
                    }
                }
            }
        } catch (e: java.nio.channels.OverlappingFileLockException) {
            Log.w(TAG, "Can't lock site ${site.name}, skipping it...")
        }
    }
}

class DNUpdateLock(site: Site): Closeable {
    private val fileChannel = FileChannel.open(
            Paths.get(site.path+"/update.lock"),
            StandardOpenOption.CREATE,
            StandardOpenOption.WRITE,
    )
    private val fileLock = fileChannel.tryLock()

    override fun close() {
        fileLock.close()
        fileChannel.close()
    }
}

class DNSiteUpdater(
        private val context: Context,
        private val apiClient: APIClient,
) {
    enum class Result {
        CONFIG_UPDATED, CREDENTIALS_UPDATED, NOOP
    }

    fun updateSite(site: Site): Result {
        if (!site.managed) {
            return Result.NOOP
        }

        val credentials = site.getDNCredentials(context)

        val newSite: IncomingSite?
        try {
            newSite = apiClient.tryUpdate(
                    site.name,
                    credentials.hostID,
                    credentials.privateKey,
                    credentials.counter.toLong(),
                    credentials.trustedKeys,
            )
        } catch (e: InvalidCredentialsException) {
            if (!credentials.invalid) {
                site.invalidateDNCredentials(context)
                Log.d(TAG, "Invalidated credentials in site ${site.name}")
                return Result.CREDENTIALS_UPDATED
            }
            return Result.NOOP
        }

        if (newSite != null) {
            newSite.save(context)
            Log.d(TAG, "Updated site ${site.id}: ${site.name}")
            return Result.CONFIG_UPDATED
        }

        if (credentials.invalid) {
            site.validateDNCredentials(context)
            Log.d(TAG, "Revalidated credentials in site ${site.id}: ${site.name}")
            return Result.CREDENTIALS_UPDATED
        }

        return Result.NOOP
    }
}
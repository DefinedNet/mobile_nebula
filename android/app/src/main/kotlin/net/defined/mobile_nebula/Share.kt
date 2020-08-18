package net.defined.mobile_nebula

import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class Share {
    companion object {
        fun share(call: MethodCall, result: MethodChannel.Result) {
            val title = call.argument<String>("title")
            val text = call.argument<String>("text")
            val filename = call.argument<String>("filename")

            if (filename == null || filename.isEmpty()) {
                return result.error("filename was not provided", null, null)
            }

            try {
                val context = MainActivity!!.getContext()!!
                val cacheDir = context.cacheDir.resolve("share")
                cacheDir.deleteRecursively()
                cacheDir.mkdir()
                val newFile = cacheDir.resolve(filename!!)
                newFile.delete()
                newFile.writeText(text ?: "")
                pop(title, newFile, result)

            } catch (err: Exception) {
                Log.println(Log.ERROR, "", "Share: Error")
                result.error(err.message, null, null)
            }
        }

        fun shareFile(call: MethodCall, result: MethodChannel.Result) {
            val title = call.argument<String>("title")
            val filename = call.argument<String>("filename")
            val filePath = call.argument<String>("filePath")

            if (filename == null || filename.isEmpty()) {
                result.error("filename was not provided", null, null)
                return
            }

            if (filePath == null || filePath.isEmpty()) {
                result.error("filePath was not provided", null, null)
                return
            }

            val file = File(filePath)

            try {
                val context = MainActivity!!.getContext()!!
                val cacheDir = context.cacheDir.resolve("share")
                cacheDir.deleteRecursively()
                cacheDir.mkdir()
                val newFile = cacheDir.resolve(filename!!)
                newFile.delete()
                file.copyTo(newFile)

                pop(title, newFile, result)

            } catch (err: Exception) {
                Log.println(Log.ERROR, "", "Share: Error")
                result.error(err.message, null, null)
            }
        }

        private fun pop(title: String?, file: File, result: MethodChannel.Result) {
            if (title == null || title.isEmpty()) {
                result.error("title was not provided", null, null)
                return
            }

            try {
                val context = MainActivity!!.getContext()!!

                val fileUri = FileProvider.getUriForFile(context, context.applicationContext.packageName + ".provider", file)
                val intent = Intent()

                intent.flags = Intent.FLAG_ACTIVITY_CLEAR_TOP
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                intent.action = Intent.ACTION_SEND
                intent.type = "text/plain"

                intent.putExtra(Intent.EXTRA_SUBJECT, title)
                intent.putExtra(Intent.EXTRA_STREAM, fileUri)
                intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)

                val chooserIntent = Intent.createChooser(intent, title)
                chooserIntent.flags = Intent.FLAG_ACTIVITY_CLEAR_TOP
                chooserIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK

                val resInfoList: List<ResolveInfo> = context.packageManager.queryIntentActivities(chooserIntent, PackageManager.MATCH_DEFAULT_ONLY)
                for (resolveInfo in resInfoList) {
                    val packageName: String = resolveInfo.activityInfo.packageName
                    context.grantUriPermission(packageName, fileUri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }

                context.startActivity(chooserIntent)

            } catch (err: Exception) {
                Log.println(Log.ERROR, "", "Share: Error")
                return result.error(err.message, null, null)
            }

            result.success(true)
        }
    }
}
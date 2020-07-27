package net.defined.mobile_nebula

import android.content.Context
import androidx.security.crypto.EncryptedFile
import androidx.security.crypto.MasterKeys
import java.io.*

class EncFile(var context: Context) {
    private val scheme = EncryptedFile.FileEncryptionScheme.AES256_GCM_HKDF_4KB
    private val master: String = MasterKeys.getOrCreate(MasterKeys.AES256_GCM_SPEC)

    fun openRead(file: File): BufferedReader {
        val eFile = EncryptedFile.Builder(file, context, master, scheme).build()
        return eFile.openFileInput().bufferedReader()
    }

    fun openWrite(file: File): BufferedWriter {
        val eFile = EncryptedFile.Builder(file, context, master, scheme).build()
        return eFile.openFileOutput().bufferedWriter()
    }

}
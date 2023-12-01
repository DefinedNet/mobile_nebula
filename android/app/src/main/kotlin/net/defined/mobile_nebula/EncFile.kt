package net.defined.mobile_nebula

import android.content.Context
import android.util.Log
import androidx.security.crypto.EncryptedFile
import androidx.security.crypto.MasterKeys
import java.io.*
import java.security.KeyStore

class EncFile(private val context: Context) {
    companion object {
        // Borrowed from androidx.security.crypto.MasterKeys
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"

        // Borrowed from androidx.security.crypto.EncryptedFile
        private const val KEYSET_PREF_NAME = "__androidx_security_crypto_encrypted_file_pref__"
    }

    private val scheme = EncryptedFile.FileEncryptionScheme.AES256_GCM_HKDF_4KB
    private val spec = MasterKeys.AES256_GCM_SPEC
    private var master: String = MasterKeys.getOrCreate(spec)

    fun openRead(file: File): BufferedReader {
        // We may fail to decrypt the file, in which case we'll raise an exception.
        // Callers should handle this exception by deleting the invalid file.
        return build(file).openFileInput().bufferedReader()
    }

    fun openWrite(file: File): BufferedWriter {
        return try {
            build(file).openFileOutput().bufferedWriter()
        } catch (e: Exception) {
            // If we fail to open the file, it's likely because the master key no longer works.
            // We'll try to reset the master key and try again.
            resetMasterKey()

            build(file).openFileOutput().bufferedWriter()
        }
    }

    private fun build(file: File): EncryptedFile {
        return EncryptedFile.Builder(file, context, master, scheme).build()
    }

    fun resetMasterKey() {
        // Reset the master key
        KeyStore.getInstance(ANDROID_KEYSTORE).apply {
            load(null)
            deleteEntry(master)
        }
        // And reset the shared preference containing the file encryption key
        context.deleteSharedPreferences(KEYSET_PREF_NAME)

        // Re-create the master key now so future calls don't fail
        master = MasterKeys.getOrCreate(spec)
    }
}
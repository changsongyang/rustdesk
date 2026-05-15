package com.carriez.flutter_hbb

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import android.util.Log
import androidx.annotation.RequiresApi
import java.io.File

/**
 * Storage Access Framework (SAF) helper class
 * Used as an alternative to MANAGE_EXTERNAL_STORAGE permission
 * Provides secure file access
 */
class StorageAccessFrameworkHelper(private val context: Context) {

    companion object {
        private const val TAG = "SAFHelper"
        const val REQUEST_CODE_PICK_FILE = 10001
        const val REQUEST_CODE_PICK_MULTIPLE_FILES = 10002
        const val REQUEST_CODE_PICK_DIRECTORY = 10003
        const val REQUEST_CODE_CREATE_FILE = 10004
    }

    /**
     * Open single file picker
     */
    fun openFilePicker(activity: Activity, mimeType: String = "*/*") {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }
        activity.startActivityForResult(intent, REQUEST_CODE_PICK_FILE)
    }

    /**
     * Open multiple file picker
     */
    fun openMultipleFilePicker(activity: Activity, mimeType: String = "*/*") {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }
        activity.startActivityForResult(intent, REQUEST_CODE_PICK_MULTIPLE_FILES)
    }

    /**
     * Open directory picker
     */
    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    fun openDirectoryPicker(activity: Activity) {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }
        activity.startActivityForResult(intent, REQUEST_CODE_PICK_DIRECTORY)
    }

    /**
     * Open create file picker
     */
    fun openCreateFilePicker(activity: Activity, mimeType: String = "*/*", fileName: String = "file") {
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType
            putExtra(Intent.EXTRA_TITLE, fileName)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }
        activity.startActivityForResult(intent, REQUEST_CODE_CREATE_FILE)
    }

    /**
     * Take persistable URI permission
     */
    fun takePersistableUriPermission(uri: Uri, modeFlags: Int) {
        try {
            context.contentResolver.takePersistableUriPermission(uri, modeFlags)
            Log.d(TAG, "Persistable permission taken for: $uri")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to take persistable permission: ${e.message}")
        }
    }

    /**
     * Release persistable URI permission
     */
    fun releasePersistableUriPermission(uri: Uri, modeFlags: Int) {
        try {
            context.contentResolver.releasePersistableUriPermission(uri, modeFlags)
            Log.d(TAG, "Persistable permission released for: $uri")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to release persistable permission: ${e.message}")
        }
    }

    /**
     * Get app-specific download directory
     * This is the recommended storage location, no special permission needed
     */
    fun getAppDownloadDirectory(): File {
        val dir = File(context.getExternalFilesDir(android.os.Environment.DIRECTORY_DOWNLOADS), "RustDesk")
        if (!dir.exists()) {
            dir.mkdirs()
        }
        return dir
    }

    /**
     * Get app-specific cache directory
     */
    fun getAppCacheDirectory(): File {
        val dir = File(context.externalCacheDir, "transfers")
        if (!dir.exists()) {
            dir.mkdirs()
        }
        return dir
    }

    /**
     * Get app-specific files directory
     */
    fun getAppFilesDirectory(): File {
        return context.filesDir
    }

    /**
     * Check if URI has persistable permission
     */
    fun hasPersistablePermission(uri: Uri): Boolean {
        val persistedUris = context.contentResolver.persistedUriPermissions
        return persistedUris.any { it.uri == uri }
    }

    /**
     * Get file name from URI
     */
    fun getFileName(uri: Uri): String? {
        var result: String? = null
        if (uri.scheme == "content") {
            val cursor = context.contentResolver.query(uri, null, null, null, null)
            cursor?.use {
                if (it.moveToFirst()) {
                    val nameIndex = it.getColumnIndex(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
                    if (nameIndex >= 0) {
                        result = it.getString(nameIndex)
                    }
                }
            }
        }
        if (result == null) {
            result = uri.path
            val cut = result?.lastIndexOf('/')
            if (cut != -1) {
                result = result?.substring(cut!! + 1)
            }
        }
        return result
    }

    /**
     * Handle onActivityResult
     */
    fun handleActivityResult(requestCode: Int, resultCode: Int, data: Intent?, callback: (SAFResult) -> Unit) {
        if (resultCode != Activity.RESULT_OK) {
            callback(SAFResult.Cancelled)
            return
        }

        when (requestCode) {
            REQUEST_CODE_PICK_FILE -> {
                data?.data?.let { uri ->
                    takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    callback(SAFResult.FilePicked(uri))
                } ?: callback(SAFResult.Failed("No URI returned"))
            }
            REQUEST_CODE_PICK_MULTIPLE_FILES -> {
                val uris = mutableListOf<Uri>()
                data?.clipData?.let { clipData ->
                    for (i in 0 until clipData.itemCount) {
                        val uri = clipData.getItemAt(i).uri
                        takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        uris.add(uri)
                    }
                } ?: data?.data?.let { uri ->
                    takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    uris.add(uri)
                }
                if (uris.isNotEmpty()) {
                    callback(SAFResult.MultipleFilesPicked(uris))
                } else {
                    callback(SAFResult.Failed("No URIs returned"))
                }
            }
            REQUEST_CODE_PICK_DIRECTORY -> {
                data?.data?.let { uri ->
                    val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                    takePersistableUriPermission(uri, flags)
                    callback(SAFResult.DirectoryPicked(uri))
                } ?: callback(SAFResult.Failed("No URI returned"))
            }
            REQUEST_CODE_CREATE_FILE -> {
                data?.data?.let { uri ->
                    takePersistableUriPermission(uri, Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                    callback(SAFResult.FileCreated(uri))
                } ?: callback(SAFResult.Failed("No URI returned"))
            }
            else -> {
                callback(SAFResult.UnknownRequestCode)
            }
        }
    }

    /**
     * SAF operation result
     */
    sealed class SAFResult {
        object Cancelled : SAFResult()
        object UnknownRequestCode : SAFResult()
        data class Failed(val message: String) : SAFResult()
        data class FilePicked(val uri: Uri) : SAFResult()
        data class MultipleFilesPicked(val uris: List<Uri>) : SAFResult()
        data class DirectoryPicked(val uri: Uri) : SAFResult()
        data class FileCreated(val uri: Uri) : SAFResult()
    }
}